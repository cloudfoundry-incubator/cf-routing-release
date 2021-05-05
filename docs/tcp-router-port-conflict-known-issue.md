# Known Issue: TCP Router Fails when Port Conflicts with Local Process

## Affected Versions

## Context

Each TCP route requires one port on the TCP Router VM. Ports for TCP routes are managed via [router groups](https://github.com/cloudfoundry/routing-api/blob/main/docs/api_docs.md#create-router-groups). Each router group has a list of `reservable_ports`. 
The [Cloud Foundry documentation for "Enabling and Configuring TCP Routing"](https://docs.cloudfoundry.org/adminguide/enabling-tcp-routing.html#-modify-tcp-port-reservations) has the following warning and suggestions for valid port ranges:

> Do not enter reservable_ports that conflict with other TCP router instances or ephemeral port ranges. Cloud Foundry recommends using port ranges within 1024-2047 and 18000-32767 on default installations.

These port suggestions do not overlap with any ports used by system components.
However, there is nothing (until now) preventing users from expanding this range into ports that *do* overlap with ports used by system components.

This port conflict can result in two different buggy outcomes.

## Variation 1 - TCP Router claims the port first

### Symptoms
1. Some bosh job on the TCP Router VM fails to start. This will likely cause a deployment to fail.
2. There are logs for the failing job that say it was unable to bind to its port. 
```
2020/10/13 22:12:20 Metrics server closing: listen tcp :14726: bind: address already in use
2020/10/13 22:12:20 stopping metrics-agent
```
3. Run `netstat -tlpn | grep PORT` and see that haproxy is running on the port that the bosh job tried to bind to.

### Explanation
If a TCP route gets the port before the bosh job, then the job will fail to bind to its port.


## Variation 2 - Internal component claims the port first

### Symptoms
1. You created a tcp route, but it doesnt work.
2. Check the TCP Router logs and see that it failed to bind to the port for the tcp route.
```
{"timestamp":"2020-10-01T21:23:17.526206817Z","level":"info","source":"tcp-router","message":"tcp-router.writing-config","data":{"num-bytes":826}}
{"timestamp":"2020-10-01T21:23:17.526332658Z","level":"info","source":"tcp-router","message":"tcp-router.running-script","data":{}}
{"timestamp":"2020-10-01T21:23:19.581306843Z","level":"info","source":"tcp-router","message":"tcp-router.running-script","data":{"output":"[ALERT] 274/212317 (43) : Starting proxy listen_cfg_2822: cannot bind socket [0.0.0.0:2822]\n"}}
{"timestamp":"2020-10-01T21:23:19.581361142Z","level":"error","source":"tcp-router","message":"tcp-router.failed-to-run-script","data":{"error":"exit status 1"}}
```
3. Run `netstat -tlpn | grep PORT` and see that some other process is running on the port that the TCP route is trying to use.

### Explanation
The TCP Router will fail to load the new config with the new TCP route, because something it bound to the conflicting port. This prevents _ALL_ new TCP routes from working as long as the conflicting port is in the config. This will not cause the bosh job for TCP Router to fail. This bug is dangerous because it is easy to miss and can affect many users.


## Fix

### Overview
The fix for this issues focuses on preventing the creation of router groups that conflict with system component ports. We have done this via: 
* a runtime check for creating and updating router groups
* a deploytime check for exising router groups
 
These fixes are available in routing release XYZ+.

### New Bosh Properties

| Bosh Property | Description | Default |
| --- | ----------- | ----------- |
| routing_api.reserved_system_component_ports |   Array of ports that are reserved for system components. Users will not be able to create router_groups with ports that overlap with this value. See Appendix A in this document to see what system components use these ports. If you run anything else on your TCP Router VM you must add its port to this list, or else you run the risk of still running into this bug.  | See Appendix A |
| tcp_router.fail_on_router_port_conflicts | Fail the TCP Router if routing_api.reserved_system_component_ports conflict with ports in existing router groups. We suggest giving your users a chance to update their router groups before turning it to true. | false |

### Runtime Check Details

When a user tries to create or update a router group to include a port in `routing_api.reserved_system_component_ports` then they will get the following error: 
```
TODO
```

### Deploytime Check Details

When the TCP Router starts it will check all existing router groups against the `routing_api.reserved_system_component_ports` property. To re-run this check you can monit restart the tcp router.

You will see the following in the TCP Router logs...

**If there are invalid router groups and is tcp_router.fail_on_router_port_conflicts is false**
1. You will see `tcp-router.router-group-port-checker-error: WARNING! In the future this will cause a deploy failure.` 
2. Plus you will see a list of which router groups contain the conflicting ports.

```
{
  "timestamp": "2021-05-03T20:59:43.127270911Z",
  "level": "error",
  "source": "tcp-router",
  "message": "tcp-router.router-group-port-checker-error: WARNING! In the future this will cause a deploy failure.",
  "data": {
    "error": "The reserved ports for router group 'group-1' contains the following reserved system component port(s): '14726, 14727, 14821, 14822, 14823, 14824, 14829, 15821, 17002'. Please update your router group accordingly.\nThe reserved ports for router group 'group-2' contains the following reserved system component port(s): '40177'. Please update your router group accordingly."
  }
}

```
**If there are invalid router groups and is tcp_router.fail_on_router_port_conflicts is true**
1. You will see `tcp-router.router-group-port-checker-error: Exiting now.`
2. Plus you will see a list of which router groups contain the conflicting ports.
3. Then monit will report the tcp router as failing

```
{
  "timestamp": "2021-05-03T21:04:02.507129979Z",
  "level": "error",
  "source": "tcp-router",
  "message": "tcp-router.router-group-port-checker-error: Exiting now.",
  "data": {
    "error": "The reserved ports for router group 'group-1' contains the following reserved system component port(s): '14726, 14727, 14821, 14822, 14823, 14824, 14829, 15821, 17002'. Please update your router group accordingly.\nThe reserved ports for router group 'group-2' contains the following reserved system component port(s): '40177'. Please update your router group accordingly."
  }
}
```

**If there are no invalid router groups**
1. You will see `tcp-router.router-group-port-checker-success: No conflicting router group ports.`
```
{
  "timestamp": "2021-05-03T21:08:32.733453194Z",
  "level": "info",
  "source": "tcp-router",
  "message": "tcp-router.router-group-port-checker-success: No conflicting router group ports.",
  "data": {}
}

```

## FAQ

## Appendix A: Default System Component Ports

This is a list of all of the system components that run on the TCP Router VM and their ports. These are the default ports used for the `routing_api.reserved_system_component_ports` property.

Some of these ports are configurable and may not match what is running on your deployment. You are responsible for checking this list against what is running on your deployment.


Configurable. See bosh property [here]( 

| Port | System Component | Note |
| --- | ----------- |  ---- | 
| 2822 | monit | |
| 2825 | bosh agent | | 
| 3458 | forwarder-agent | Configurable. See bosh property [here](https://github.com/cloudfoundry/loggregator-agent-release/blob/acfbb6b015d897c11f715ac9e1a226eb5b96875c/jobs/loggregator_agent/spec#L44-L46). | 
| 3459 | loggregator-agent | configurable | 
| 3460 | syslog-agent | ??? |
| 3461 | metrics-agent | Configurable. See bosh property [here](https://github.com/cloudfoundry/metrics-discovery-release/blob/e8ee61e329b916f0a71274f85fc8b8fcfb8df470/jobs/metrics-agent/spec#L23-L25)|
| 8853 | bosh-dns-health | Configurable. See bosh property [here](https://github.com/cloudfoundry/bosh-dns-release/blob/e8f5ba4233a5fb4b16b5c4ebb203c644fa82db4d/jobs/bosh-dns/spec#L148-L150)|
| 9100 | system-metrics- | (for TAS 2.7) |
| 14726 | metrics-agent | Configurable. See bosh property [here](https://github.com/cloudfoundry/metrics-discovery-release/blob/e8ee61e329b916f0a71274f85fc8b8fcfb8df470/jobs/metrics-agent/spec#L45-L47) |
| 14727 | metrics-agent | Configurable. See bosh property [here](https://github.com/cloudfoundry/metrics-discovery-release/blob/e8ee61e329b916f0a71274f85fc8b8fcfb8df470/jobs/metrics-agent/spec#L48-L50)|
| 14821 | prom-scaper | Configurable. See bosh property [here](https://github.com/cloudfoundry/loggregator-agent-release/blob/acfbb6b015d897c11f715ac9e1a226eb5b96875c/jobs/prom_scraper/spec#L52-L54)|
| 14822 | syslog-agent | Configurable. See bosh property [here](https://github.com/cloudfoundry/loggregator-agent-release/blob/acfbb6b015d897c11f715ac9e1a226eb5b96875c/jobs/loggr-syslog-agent/spec#L139-L141)  |
| 14823 | loggregator-agent | ?? |
| 14824 | loggregator-agent | Configurable. See bosh property [here](https://github.com/cloudfoundry/loggregator-agent-release/blob/acfbb6b015d897c11f715ac9e1a226eb5b96875c/jobs/loggregator_agent/spec#L78-L80) |
| 14829 | udp-forwarder | Configurable. See bosh property [here](https://github.com/cloudfoundry/loggregator-agent-release/blob/acfbb6b015d897c11f715ac9e1a226eb5b96875c/jobs/loggr-udp-forwarder/spec#L44-L46) |
| 15821 | discovery-registrar | |
| 17002 | cf-tcp-router | Configurable. See bosh property [here](https://github.com/cloudfoundry/routing-release/blob/8b00b8ff9ec68802d86425d3ffdcc3e8611aee93/jobs/tcp_router/spec#L32-L34) |
| 35095 | system-metrics- | |
| 39873 | udp-forwarder | ?? |
| 40177 | system-metrics- | |
| 42393 | udp-forwarder | ?? |
| 46567 | udp-forwarder | ?? |
| 53035 | system-metrics-  |(for TAS 2.8+) |
| 53080 | bosh dns| Configurable. See bosh property [here](https://github.com/cloudfoundry/bosh-dns-release/blob/e8f5ba4233a5fb4b16b5c4ebb203c644fa82db4d/jobs/bosh-dns/spec#L52-L54)|



