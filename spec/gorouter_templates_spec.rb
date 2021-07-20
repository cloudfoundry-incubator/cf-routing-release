# rubocop:disable LineLength
# rubocop:disable BlockLength
require 'rspec'
require 'yaml'
require 'json'
require 'bosh/template/test'
require 'bosh/template/evaluation_context'
require 'spec_helper'

TEST_CERT = 'some

multiline

cert'.freeze

TEST_KEY = 'some

multi line key'.freeze

ROUTE_SERVICES_CLIENT_TEST_CERT = 'route services

multiline

cert'.freeze

ROUTE_SERVICES_CLIENT_TEST_KEY = 'route services

multi line key'.freeze

describe 'gorouter' do
  let(:release_path) { File.join(File.dirname(__FILE__), '..') }
  let(:release) { Bosh::Template::Test::ReleaseDir.new(release_path) }
  let(:job) { release.job('gorouter') }

  describe 'gorouter.yml.erb' do
    let(:deployment_manifest_fragment) do
      {
        'router' => {
          'status' => {
            'port' => 80,
            'user' => 'test',
            'password' => 'pass'
          },
          'enable_ssl' => true,
          'tls_port' => 443,
          'client_cert_validation' => 'none',
          'logging_level' => 'info',
          'tracing' => {
            'enable_zipkin' => false,
            'enable_w3c' => false,
            'w3c_tenant_id' => nil
          },
          'ssl_skip_validation' => false,
          'port' => 80,
          'offset' => 0,
          'number_of_cpus' => 0,
          'trace_key' => 'key',
          'debug_address' => '127.0.0.1',
          'secure_cookies' => false,
          'write_access_logs_locally' => true,
          'access_log' => {
            'enable_streaming' => false
          },
          'drain_wait' => 10,
          'drain_timeout' => 300,
          'healthcheck_user_agent' => 'test-agent',
          'requested_route_registration_interval_in_seconds' => 10,
          'load_balancer_healthy_threshold' => 10,
          'balancing_algorithm' => 'round-robin',
          'disable_log_forwarded_for' => true,
          'disable_log_source_ip' => true,
          'tls_pem' => [
            {
              'cert_chain' => 'test-chain',
              'private_key' => 'test-key'
            },
            {
              'cert_chain' => 'test-chain2',
              'private_key' => 'test-key2'
            }
          ],
          'min_tls_version' => 'TLSv1.2',
          'max_tls_version' => 'TLSv1.2',
          'disable_http' => false,
          'ca_certs' => 'test-certs',
          'cipher_suites' => 'test-suites',
          'forwarded_client_cert' => ['test-cert'],
          'isolation_segments' => '[is1]',
          'routing_table_sharding_mode' => 'sharding',
          'route_services_timeout' => 10,
          'route_services_secret' => 'secret',
          'route_services_secret_decrypt_only' => 'secret',
          'route_services_recommend_https' => false,
          'extra_headers_to_log' => 'test-header',
          'enable_proxy' => false,
          'force_forwarded_proto_https' => false,
          'sanitize_forwarded_proto' => false,
          'suspend_pruning_if_nats_unavailable' => false,
          'max_idle_connections' => 100,
          'keep_alive_probe_interval' => '1s',
          'backends' => {
            'max_conns' => 100,
            'cert_chain' => TEST_CERT,
            'private_key' => TEST_KEY
          },
          'route_services' => {
            'cert_chain' => ROUTE_SERVICES_CLIENT_TEST_CERT,
            'private_key' => ROUTE_SERVICES_CLIENT_TEST_KEY
          },
          'frontend_idle_timeout' => 5,
          'ip_local_port_range' => '1024 65535',
          'per_request_metrics_reporting' => true,
          'send_http_start_stop_server_event' => true,
          'send_http_start_stop_client_event' => true
        },
        'request_timeout_in_seconds' => 100,
        'routing_api' => {
          'enabled' => false,
          'port' => '23423',
          'ca_certs' => "CA CERTS\n",
          'private_key' => 'PRIVATE KEY',
          'cert_chain' => 'CERT CHAIN'
        },
        'uaa' => {
          'ca_cert' => 'blah-cert',
          'ssl' => {
            'port' => 900
          },
          'clients' => {
            'gorouter' => {
              'secret' => 'secret'
            }
          },
          'token_endpoint' => 'uaa.token_endpoint'
        },
        'nats' => {
          'machines' => ['127.0.0.1'],
          'port' => 8080,
          'user' => 'test',
          'password' => 'test_pass',
          'tls_enabled' => true,
          'ca_certs' => 'test_ca_cert',
          'cert_chain' => 'test_cert_chain',
          'private_key' => 'test_private_key'
        },
        'metron' => {
          'port' => 3745
        },
        'for_backwards_compatibility_only' => {
          'empty_pool_response_code_503' => true
        }
      }
    end

    let(:template) { job.template('config/gorouter.yml') }
    let(:rendered_template) { template.render(deployment_manifest_fragment) }
    subject(:parsed_yaml) { YAML.safe_load(rendered_template) }

    context 'given a generally valid manifest' do
      describe 'keep alives' do
        context 'max_idle_connections is set' do
          context 'using default values' do
            it 'should not disable keep alives' do
              expect(parsed_yaml['disable_keep_alives']).to eq(false)
            end
            it 'should set endpoint_keep_alive_probe_interval' do
              expect(parsed_yaml['endpoint_keep_alive_probe_interval']).to eq('1s')
            end
            it 'should set max_idle_conns' do
              expect(parsed_yaml['max_idle_conns']).to eq(100)
              expect(parsed_yaml['max_idle_conns_per_host']).to eq(100)
            end
          end
          context 'using custom values' do
            before do
              deployment_manifest_fragment['router']['max_idle_connections'] = 2500
              deployment_manifest_fragment['router']['keep_alive_probe_interval'] = '500ms'
            end
            it 'should not disable keep alives' do
              expect(parsed_yaml['disable_keep_alives']).to eq(false)
            end
            it 'should set endpoint_keep_alive_probe_interval' do
              expect(parsed_yaml['endpoint_keep_alive_probe_interval']).to eq('500ms')
            end
            it 'should set max_idle_conns' do
              expect(parsed_yaml['max_idle_conns']).to eq(2500)
              expect(parsed_yaml['max_idle_conns_per_host']).to eq(100)
            end
            it 'should not enable zipkin' do
              expect(parsed_yaml.dig('tracing', 'enable_zipkin')).to eq(false)
            end
            it 'should not enable w3c' do
              expect(parsed_yaml.dig('tracing', 'enable_w3c')).to eq(false)
            end
          end
        end

        context 'min_tls_version' do
          context 'when it is set to an invalid version' do
            before do
              deployment_manifest_fragment['router']['min_tls_version'] = 'TLSv2.7'
            end

            it 'fails' do
              expect { raise parsed_yaml }.to raise_error(RuntimeError, 'router.min_tls_version must be "TLSv1.0", "TLSv1.1", "TLSv1.2" or "TLSv1.3"')
            end
          end
        end

        context 'max_tls_version' do
          context 'when it is set to an invalid version' do
            before do
              deployment_manifest_fragment['router']['max_tls_version'] = 'TLSv2.7'
            end

            it 'fails' do
              expect { raise parsed_yaml }.to raise_error(RuntimeError, 'router.max_tls_version must be "TLSv1.2" or "TLSv1.3"')
            end
          end
        end

        context 'max_idle_connections is not set' do
          before do
            deployment_manifest_fragment['router']['max_idle_connections'] = 0
          end
          it 'should disable keep alives' do
            expect(parsed_yaml['disable_keep_alives']).to eq(true)
          end
          it 'should not set endpoint_keep_alive_probe_interval' do
            expect(parsed_yaml['endpoint_keep_alive_probe_interval']).to eq(nil)
          end
          it 'should not set max_idle_conns' do
            expect(parsed_yaml['max_idle_conns']).to eq(nil)
            expect(parsed_yaml['max_idle_conns_per_host']).to eq(nil)
          end
        end
      end
      describe 'sticky_session_cookies' do
        context 'when no value is provided' do
          it 'should use JSESSIONID' do
            expect(parsed_yaml['sticky_session_cookie_names']).to match_array(['JSESSIONID'])
          end
        end
        context 'when multiple cookies are provided' do
          before do
            deployment_manifest_fragment['router']['sticky_session_cookie_names'] = %w[meow bark]
          end
          it 'should use all of the cookies in the config' do
            expect(parsed_yaml['sticky_session_cookie_names']).to match_array(%w[meow bark])
          end
        end
      end
      describe 'client_cert_validation' do
        context 'when no override is provided' do
          it 'should default to none' do
            expect(parsed_yaml['client_cert_validation']).to eq('none')
          end
        end

        context 'when the value is not valid' do
          before do
            deployment_manifest_fragment['router']['client_cert_validation'] = 'meow'
          end
          it 'should error' do
            expect { raise parsed_yaml }.to raise_error(RuntimeError, 'router.client_cert_validation must be "none", "request", or "require"')
          end
        end
      end

      context 'route_services_internal_lookup' do
        it 'defaults to false' do
          expect(parsed_yaml['route_services_hairpinning']).to eq(false)
        end

        context 'when enabled' do
          before do
            deployment_manifest_fragment['router']['route_services_internal_lookup'] = true
          end

          it 'parses to true' do
            expect(parsed_yaml['route_services_hairpinning']).to eq(true)
          end
        end
      end

      context 'html_error_template' do
        it 'is not set by default' do
          expect(parsed_yaml['html_error_template_file']).to be_nil
        end

        context 'when enabled' do
          before do
            deployment_manifest_fragment['router']['html_error_template'] = '<html>...goes here...</html>'
          end

          it 'sets the template path to the templated file' do
            expect(parsed_yaml['html_error_template_file']).to eq('/var/vcap/jobs/gorouter/config/error.html')
          end
        end
      end

      context 'tls_pem' do
        context 'when correct tls_pem is provided' do
          it 'should configure the property' do
            expect(parsed_yaml['tls_pem'].length).to eq(2)
            expect(parsed_yaml['tls_pem'][0]).to eq('cert_chain' => 'test-chain',
                                                    'private_key' => 'test-key')
            expect(parsed_yaml['tls_pem'][1]).to eq('cert_chain' => 'test-chain2',
                                                    'private_key' => 'test-key2')
          end
        end

        context 'when an incorrect tls_pem value is provided with missing cert' do
          before do
            deployment_manifest_fragment['router']['tls_pem'] = [{ 'private_key' => 'test-key' }]
          end
          it 'should error' do
            expect { raise parsed_yaml }.to raise_error(RuntimeError, 'must provide cert_chain and private_key with tls_pem')
          end
        end

        context 'when an incorrect tls_pem value is provided with missing key' do
          before do
            deployment_manifest_fragment['router']['tls_pem'] = [{ 'cert_chain' => 'test-chain' }]
          end
          it 'should error' do
            expect { raise parsed_yaml }.to raise_error(RuntimeError, 'must provide cert_chain and private_key with tls_pem')
          end
        end

        context 'when an incorrect tls_pem value is provided as wrong format' do
          before do
            deployment_manifest_fragment['router']['tls_pem'] = ['cert']
          end
          it 'should error' do
            expect { raise parsed_yaml }.to raise_error(RuntimeError, 'must provide cert_chain and private_key with tls_pem')
          end
        end
      end

      describe 'drain' do
        it 'should configure properly' do
          expect(parsed_yaml['drain_wait']).to eq('10s')
          expect(parsed_yaml['drain_timeout']).to eq('300s')
        end
      end

      describe 'route_services' do
        context 'when both cert_chain and private_key are provided' do
          it 'should configure the property' do
            expect(parsed_yaml['route_services']['cert_chain']).to eq(ROUTE_SERVICES_CLIENT_TEST_CERT)
            expect(parsed_yaml['route_services']['private_key']).to eq(ROUTE_SERVICES_CLIENT_TEST_KEY)
          end
        end
        context 'when cert_chain is provided but not private_key' do
          before do
            deployment_manifest_fragment['router']['route_services']['private_key'] = nil
          end
          it 'should error' do
            expect { raise parsed_yaml }.to raise_error(RuntimeError, 'route_services.cert_chain and route_services.private_key must be both provided or not at all')
          end
        end
        context 'when private_key is provided but not cert_chain' do
          before do
            deployment_manifest_fragment['router']['route_services']['cert_chain'] = nil
          end
          it 'should error' do
            expect { raise parsed_yaml }.to raise_error(RuntimeError, 'route_services.cert_chain and route_services.private_key must be both provided or not at all')
          end
        end
        context 'when neither cert_chain nor private_key are provided' do
          before do
            deployment_manifest_fragment['router']['route_services']['cert_chain'] = nil
            deployment_manifest_fragment['router']['route_services']['private_key'] = nil
          end
          it 'should not error and should not configure the properties' do
            expect(parsed_yaml['route_services']['cert_chain']).to eq('')
            expect(parsed_yaml['route_services']['private_key']).to eq('')
          end
        end
      end

      describe 'backends' do
        context 'when both cert_chain and private_key are provided' do
          it 'should configure the property' do
            expect(parsed_yaml['backends']['cert_chain']).to eq(TEST_CERT)
            expect(parsed_yaml['backends']['private_key']).to eq(TEST_KEY)
          end
        end
        context 'when cert_chain is provided but not private_key' do
          before do
            deployment_manifest_fragment['router']['backends']['private_key'] = nil
          end
          it 'should error' do
            expect { raise parsed_yaml }.to raise_error(RuntimeError, 'backends.cert_chain and backends.private_key must be both provided or not at all')
          end
        end
        context 'when private_key is provided but not cert_chain' do
          before do
            deployment_manifest_fragment['router']['backends']['cert_chain'] = nil
          end
          it 'should error' do
            expect { raise parsed_yaml }.to raise_error(RuntimeError, 'backends.cert_chain and backends.private_key must be both provided or not at all')
          end
        end
        context 'when neither cert_chain nor private_key are provided' do
          before do
            deployment_manifest_fragment['router']['backends']['cert_chain'] = nil
            deployment_manifest_fragment['router']['backends']['private_key'] = nil
          end
          it 'should not error and should not configure the properties' do
            expect(parsed_yaml['backends']['cert_chain']).to eq('')
            expect(parsed_yaml['backends']['private_key']).to eq('')
          end
        end
      end

      context 'certficate authorities' do
        context 'client_ca_certs' do
          context 'are not provided' do
            before do
              deployment_manifest_fragment['router']['only_trust_client_ca_certs'] = true
            end
            it 'renders the manifest with a default of nothing' do
              expect(parsed_yaml['client_ca_certs']).to eq('')
            end
          end

          context 'are provided' do
            context 'when only_trust_client_ca_certs is true' do
              before do
                deployment_manifest_fragment['router']['client_ca_certs'] = 'cool potato'
                deployment_manifest_fragment['router']['ca_certs'] = 'lame rhutabega'
                deployment_manifest_fragment['router']['only_trust_client_ca_certs'] = true
              end

              it 'client_ca_certs do not contain ca_certs' do
                expect(parsed_yaml['client_ca_certs']).to eq('cool potato')
              end

              it 'sets only_trust_client_ca_certs to true' do
                expect(parsed_yaml['only_trust_client_ca_certs']).to equal(true)
              end
            end

            context 'when only_trust_client_ca_certs is false' do
              before do
                deployment_manifest_fragment['router']['client_ca_certs'] = 'cool potato'
                deployment_manifest_fragment['router']['ca_certs'] = 'lame rhutabega'
                deployment_manifest_fragment['router']['only_trust_client_ca_certs'] = false
              end

              it 'client_ca_certs do contain ca_certs' do
                expect(parsed_yaml['client_ca_certs']).to include('cool potato')
                expect(parsed_yaml['client_ca_certs']).to include('lame rhutabega')
              end

              it 'sets only_trust_client_ca_certs to false' do
                expect(parsed_yaml['only_trust_client_ca_certs']).to equal(false)
              end
            end
          end
        end

        context 'ca_certs' do
          context 'when correct ca_certs is provided' do
            it 'should configure the property' do
              expect(parsed_yaml['ca_certs']).to eq('test-certs')
            end
          end

          context 'when ca_certs is blank' do
            before do
              deployment_manifest_fragment['router']['ca_certs'] = nil
            end
            it 'returns a helpful error message' do
              expect { parsed_yaml }.to raise_error(/Can\'t find property \'\[\"router.ca_certs\"\]\'/)
            end
          end

          context 'when a simple array is provided' do
            before do
              deployment_manifest_fragment['router']['ca_certs'] = ['some-tls-cert']
            end
            it 'raises error' do
              expect { parsed_yaml }.to raise_error(RuntimeError, 'ca_certs must be provided as a single string block')
            end
          end

          context 'when an empty array is provided' do
            before do
              deployment_manifest_fragment['router']['ca_certs'] = []
            end
            it 'raises error' do
              expect { parsed_yaml }.to raise_error(RuntimeError, 'ca_certs must be provided as a single string block')
            end
          end

          context 'when set to a multi-line string' do
            let(:test_certs) do
              '
    some
    multi
    line

    string
    with lots

    of

    whitespace

              '
            end

            before do
              deployment_manifest_fragment['router']['ca_certs'] = test_certs
            end
            it 'suceessfully configures the property' do
              expect(parsed_yaml['ca_certs']).to eq(test_certs)
            end
          end
        end
      end

      # ca_certs, private_key, cert_chain
      context 'routing-api' do
        context 'when the routing API is disabled' do
          before do
            deployment_manifest_fragment['routing_api']['enabled'] = false
          end

          context 'when ca_certs is not set' do
            before do
              deployment_manifest_fragment['routing_api']['ca_certs'] = 'nice'
            end

            it 'is happy' do
              expect { parsed_yaml }.not_to raise_error
            end
          end
        end

        context 'when the routing API is enabled' do
          let(:property_value) { ('a'..'z').to_a.shuffle.join }
          let(:link_value) { ('a'..'z').to_a.shuffle.join }

          before do
            deployment_manifest_fragment['routing_api']['enabled'] = true
          end

          describe 'routing API port' do
            it_behaves_like 'overridable_link', LinkConfiguration.new(
              description: 'Routing API port',
              property: 'routing_api.port',
              link_path: 'routing_api.mtls_port',
              parsed_yaml_property: 'routing_api.port'
            )
          end

          describe 'ca_certs' do
            let(:ca_certs) { parsed_yaml['routing_api']['ca_certs'] }

            context 'when a simple array is provided' do
              before do
                deployment_manifest_fragment['routing_api']['ca_certs'] = ['some-tls-cert']
              end

              it 'raises error' do
                expect { parsed_yaml }.to raise_error(RuntimeError, 'routing_api.ca_certs must be provided as a single string block')
              end
            end

            context 'when set to a multi-line string' do
              let(:str) { "some   \nmulti\nline\n  string" }

              before do
                deployment_manifest_fragment['routing_api']['ca_certs'] = str
              end

              it 'successfully configures the property' do
                expect(ca_certs).to eq(str)
              end
            end

            context 'when containing dashes' do
              let(:str) { '---some---string------with--dashes' }

              before do
                deployment_manifest_fragment['routing_api']['ca_certs'] = str
              end

              it 'successfully configures the property' do
                expect(ca_certs).to eq(str)
              end
            end

            it_behaves_like 'overridable_link', LinkConfiguration.new(
              description: 'Routing API server CA certificate',
              property: 'routing_api.ca_certs',
              link_path: 'routing_api.mtls_ca',
              parsed_yaml_property: 'routing_api.ca_certs'
            )
          end

          describe 'private_key' do
            context 'when set to a multi-line string' do
              let(:str) { "some   \nmulti\nline\n  string" }

              before do
                deployment_manifest_fragment['routing_api']['private_key'] = str
              end

              it 'successfully configures the property' do
                expect(parsed_yaml['routing_api']['private_key']).to eq(str)
              end
            end

            it_behaves_like 'overridable_link', LinkConfiguration.new(
              description: 'Routing API client private key',
              property: 'routing_api.private_key',
              link_path: 'routing_api.mtls_client_key',
              parsed_yaml_property: 'routing_api.private_key'
            )
          end

          describe 'cert_chain' do
            context 'when a simple array is provided' do
              before do
                deployment_manifest_fragment['routing_api']['cert_chain'] = ['some-tls-cert']
              end

              it 'raises error' do
                expect { parsed_yaml }.to raise_error(RuntimeError, 'routing_api.cert_chain must be provided as a single string block')
              end
            end

            context 'when set to a multi-line string' do
              let(:str) { "some   \nmulti\nline\n  string" }

              before do
                deployment_manifest_fragment['routing_api']['cert_chain'] = str
              end

              it 'successfully configures the property' do
                expect(parsed_yaml['routing_api']['cert_chain']).to eq(str)
              end
            end

            it_behaves_like 'overridable_link', LinkConfiguration.new(
              description: 'Routing API client certificate',
              property: 'routing_api.cert_chain',
              link_path: 'routing_api.mtls_client_cert',
              parsed_yaml_property: 'routing_api.cert_chain'
            )
          end
        end
      end

      context 'nats' do
        let(:property_value) { ('a'..'z').to_a.shuffle.join }
        let(:link_value) { ('a'..'z').to_a.shuffle.join }

        describe 'NATS port' do
          it_behaves_like 'overridable_link', LinkConfiguration.new(
            description: 'NATS server port number',
            property: 'nats.port',
            link_path: 'nats.port',
            link_namespace: 'nats-tls',
            parsed_yaml_property: 'nats.hosts.0.port'
          )
        end

        describe 'ca_certs' do
          let(:ca_certs) { parsed_yaml['nats']['ca_certs'] }

          context 'when a simple array is provided' do
            before do
              deployment_manifest_fragment['nats']['ca_certs'] = ['some-tls-cert']
            end

            it 'raises error' do
              expect { parsed_yaml }.to raise_error(RuntimeError, 'nats.ca_certs must be provided as a single string block')
            end
          end

          context 'when set to a multi-line string' do
            let(:str) { "some   \nmulti\nline\n  string" }

            before do
              deployment_manifest_fragment['nats']['ca_certs'] = str
            end

            it 'successfully configures the property' do
              expect(ca_certs).to eq(str)
            end
          end

          context 'when containing dashes' do
            let(:str) { '---some---string------with--dashes' }

            before do
              deployment_manifest_fragment['nats']['ca_certs'] = str
            end

            it 'successfully configures the property' do
              expect(ca_certs).to eq(str)
            end
          end

          it_behaves_like 'overridable_link', LinkConfiguration.new(
            description: 'NATS server CA certificate',
            property: 'nats.ca_certs',
            link_path: 'nats.external.tls.ca',
            link_namespace: 'nats-tls',
            parsed_yaml_property: 'nats.ca_certs'
          )
        end

        describe 'private_key' do
          context 'when set to a multi-line string' do
            let(:str) { "some   \nmulti\nline\n  string" }

            before do
              deployment_manifest_fragment['nats']['private_key'] = str
            end

            it 'successfully configures the property' do
              expect(parsed_yaml['nats']['private_key']).to eq(str)
            end
          end
        end

        describe 'cert_chain' do
          context 'when a simple array is provided' do
            before do
              deployment_manifest_fragment['nats']['cert_chain'] = ['some-tls-cert']
            end

            it 'raises error' do
              expect { parsed_yaml }.to raise_error(RuntimeError, 'nats.cert_chain must be provided as a single string block')
            end
          end

          context 'when set to a multi-line string' do
            let(:str) { "some   \nmulti\nline\n  string" }

            before do
              deployment_manifest_fragment['nats']['cert_chain'] = str
            end

            it 'successfully configures the property' do
              expect(parsed_yaml['nats']['cert_chain']).to eq(str)
            end
          end
        end
      end

      context 'logging' do
        context 'when timestamp format is not provided' do
          it 'it defaults to rfc3339' do
            expect(parsed_yaml['logging']['format']['timestamp']).to eq('rfc3339')
          end
        end

        context 'when timestamp format is provided' do
          before do
            deployment_manifest_fragment['router']['logging'] = { 'format' => { 'timestamp' => 'unix-epoch' } }
          end

          it 'it sets the value correctly' do
            expect(parsed_yaml['logging']['format']['timestamp']).to eq('unix-epoch')
          end
        end

        fcontext 'when the timestamp format is set to deprecated' do
          before do
            deployment_manifest_fragment['router']['logging'] = { 'format' => { 'timestamp' => 'deprecated' } }
          end

          it 'sets the value to be unix-epoch' do
            expect(parsed_yaml['logging']['format']['timestamp']).to eq('unix-epoch')
          end
        end

        context 'when an invalid timestamp format is provided' do
          before do
            deployment_manifest_fragment['router']['logging'] = { 'format' => { 'timestamp' => 'meow' } }
          end

          it 'raises error' do
            expect { parsed_yaml }.to raise_error(RuntimeError, "'meow' is not a valid timestamp format for the property 'router.logging.format.timestamp'. Valid options are: 'rfc3339', 'deprecated', and 'unix-epoch'.")
          end
        end
      end

      context 'tracing' do
        context 'when zipkin is enabled' do
          before do
            deployment_manifest_fragment['router']['tracing']['enable_zipkin'] = true
          end

          it 'is happy' do
            expect { parsed_yaml }.not_to raise_error
          end

          it 'should enable zipkin' do
            expect(parsed_yaml['tracing']['enable_zipkin']).to eq(true)
          end
        end

        context 'when w3c is enabled' do
          before do
            deployment_manifest_fragment['router']['tracing']['enable_w3c'] = true
          end

          it 'is happy' do
            expect { parsed_yaml }.not_to raise_error
          end

          it 'should enable w3c tracing' do
            expect(parsed_yaml['tracing']['enable_w3c']).to eq(true)
          end

          it 'should not set the w3c tenant ID' do
            expect(parsed_yaml['tracing']['w3c_tenant_id']).to eq(nil)
          end

          context 'when w3c is enabled' do
            before do
              deployment_manifest_fragment['router']['tracing']['w3c_tenant_id'] = 'tid'
            end

            it 'is happy' do
              expect { parsed_yaml }.not_to raise_error
            end

            it 'should set wc3_tenant_id' do
              expect(parsed_yaml['tracing']['w3c_tenant_id']).to eq('tid')
            end
          end
        end
      end

      context 'backwards compatible properties' do
        context 'empty_pool_response_code_503' do
          context 'when it is not set' do
            it 'is happy' do
              expect { parsed_yaml }.not_to raise_error
              expect(parsed_yaml['empty_pool_response_code_503']).to eq(true)
            end
          end

          context 'when it is true' do
            before do
              deployment_manifest_fragment['for_backwards_compatibility_only']['empty_pool_response_code_503'] = true
            end
            it 'is set to true' do
              expect(parsed_yaml['empty_pool_response_code_503']).to eq(true)
            end
          end

          context 'when it is false' do
            before do
              deployment_manifest_fragment['for_backwards_compatibility_only']['empty_pool_response_code_503'] = false
            end
            it 'is set to false' do
              expect(parsed_yaml['empty_pool_response_code_503']).to eq(false)
            end
          end
        end
      end
    end
  end

  describe 'indicators.yml' do
    let(:template) { job.template('config/indicators.yml') }
    let(:rendered_template) { template.render({}) }
    subject(:parsed_yaml) { YAML.safe_load(rendered_template) }

    it 'populates metadata deployment name' do
      expect(parsed_yaml['metadata']['labels']['deployment']).to eq('my-deployment')
    end

    it 'contains indicators' do
      expect(parsed_yaml['spec']['indicators']).to_not be_empty
    end
  end

  describe 'error.html' do
    let(:template) { job.template('config/error.html') }
    let(:rendered_template) do
      template.render('router' => { 'html_error_template' => html })
    end

    context 'by default' do
      let(:html) { '' }

      it 'is empty' do
        expect(rendered_template).to eq("\n")
      end
    end

    context 'when an error template is defined' do
      let(:html) { '<html>error</html>' }

      it 'consists of the rendered template' do
        expect(rendered_template).to eq("<html>error</html>\n")
      end
    end
  end
end
