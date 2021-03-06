### Context
To read more about the problem that this doc is fixing, see the [release notes for routing-release 0.209.0](https://github.com/cloudfoundry/routing-release/releases/tag/0.209.0).

### Fixing your apps
In general, to resolve this issue you need to review applications experiencing these errors and make code changes to ensure that multiple or duplicate transfer-encoding headers are not being returned to Gorouter. This is not a change or fix that can be made on the platform itself.

1. For streaming results from the server to a client, use Spring's built-in support for this. Using a ResponseBodyEmitter or a SseEmitter, you can easily stream content back to your clients and Spring & Tomcat will ensure that the transfer-encoding header is set correctly.

2. If you created a route service based on this example code, https://github.com/nebhale/route-service-example (no longer published due to this bug), you will be impacted as the example code was copying all response headers, include transfer-encoding headers from the proxied response to the client response (see the 👈 line below).
```
        return this.webClient
            .method(request.getMethod())
            .uri(forwardedUrl)
            .headers(headers -> headers.putAll(forwardedHttpHeaders))
            .body((outputMessage, context) -> outputMessage.writeWith(request.getBody()))
            .exchange()
            .map(response -> {
                this.logger.info("Outgoing Response: {}", formatResponse(response.statusCode(), response.headers().asHttpHeaders()));

                return ResponseEntity
                    .status(response.statusCode())
                    .headers(response.headers().asHttpHeaders()) 👈👈👈
                    .body(response.bodyToFlux(DataBuffer.class));
            });
```
To implement correctly, you will need to strip out the transfer-encoding header, like in this example.
```
return this.webClient
            .method(request.getMethod())
            .uri(forwardedUrl)
            .headers(headers -> headers.putAll(forwardedHttpHeaders))
            .body((outputMessage, context) -> outputMessage.writeWith(request.getBody()))
            .exchange()
            .map(response -> {
                HttpHeaders headers = getResponseHeaders(response.headers().asHttpHeaders()); 👈👈👈

                this.logger.info("Outgoing Response: {}", formatResponse(response.statusCode(), headers));

                return ResponseEntity
                    .status(response.statusCode())
                    .headers(headers)
                    .body(response.bodyToFlux(DataBuffer.class));
            });
    }
```
Where the getResponseHeaders function looks like this:
```
private HttpHeaders getResponseHeaders(HttpHeaders headers) {
    return headers.entrySet().stream()
        .filter(entry -> !entry.getKey().equalsIgnoreCase(TRANSFER_ENCODING))
        .collect(HttpHeaders::new, (httpHeaders, entry) -> httpHeaders.addAll(entry.getKey(), entry.getValue()), HttpHeaders::putAll);
}
```
As an additional note beyond the context of this issue, it is not good practice to copy every header when proxying traffic. The example above strips out a few request headers and the transfer-encoding header on the response, but you would want to be more restrictive for production applications to prohibit clients from sending headers to manipulate backend applications in ways they should not be able to do (like the HTTPoxy vulnerability) and to prohibit information, like CORS headers, from leaking out of backend services to clients.

3. Situation #3 above, can be mitigated by not directly returning ResponseEntity objects from RestTemplate.exchange. You need to first remove the transfer-encoding header, if it's present. You could directly modify that object in your Controller before returning it, but that could get repetitive across many methods and many controllers. A less invasive way of doing this would be with a RestTemplate interceptor.

4. Another option is to utilize Spring WebClient. You may use WebClient in both Spring MVC (Servlet) and Spring Webflux apps. With WebClient, you can return a Flux and that will trigger a streamed response (i.e. transfer-encoding chunked). In this situation, the transfer-encoding header will only be set once.

5. If you are manually adding any Transfer-Encoding headers, remove them. How you add headers will vary from one language/framework to another. An example in Java would be using HttpServletResponse.addHeader to add a transfer-encoding header.
