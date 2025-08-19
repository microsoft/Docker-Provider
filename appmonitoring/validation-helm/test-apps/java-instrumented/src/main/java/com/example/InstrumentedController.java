package com.example;

import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.metrics.LongHistogram;
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanKind;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.api.trace.Tracer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ThreadLocalRandom;

@RestController
public class InstrumentedController {

    private static final Logger logger = LoggerFactory.getLogger(InstrumentedController.class);
    
    private final Tracer tracer;
    private final Meter meter;
    private final LongCounter requestCounter;
    private final LongHistogram requestDuration;
    private final LongCounter errorCounter;
    private final LongCounter cowsSoldCounter;
    private final WebClient webClient;

    @Value("${target.url:http://localhost:8080/}")
    private String targetUrl;

    @Value("${otel.exporter.otlp.metrics.endpoint:http://localhost:56682/v1/metrics}")
    private String metricsEndpoint;

    @Value("${otel.exporter.otlp.metrics.protocol:http/protobuf}")
    private String metricsProtocol;

    @Autowired
    public InstrumentedController(OpenTelemetry openTelemetry, Meter meter, WebClient webClient) {
        this.tracer = openTelemetry.getTracer("java-instrumented-test-app", "1.0.0");
        this.meter = meter;
        this.webClient = webClient;
        
        // Initialize metrics
        this.requestCounter = meter.counterBuilder("http_requests_total")
            .setDescription("Total number of HTTP requests")
            .build();
            
        this.requestDuration = meter.histogramBuilder("http_request_duration_ms")
            .setDescription("Duration of HTTP requests in milliseconds")
            .ofLongs()
            .build();
            
        this.errorCounter = meter.counterBuilder("http_errors_total")
            .setDescription("Total number of HTTP errors")
            .build();
            
        this.cowsSoldCounter = meter.counterBuilder("cows_sold_total")
            .setDescription("Total number of cows sold")
            .build();
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "healthy");
        response.put("timestamp", Instant.now().toString());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/metrics")
    public ResponseEntity<Map<String, String>> metrics() {
        Map<String, String> response = new HashMap<>();
        response.put("message", "Metrics endpoint - integrate with Prometheus exporter as needed");
        return ResponseEntity.ok(response);
    }

    @GetMapping("/")
    public ResponseEntity<Map<String, Object>> root() {
        long startTime = System.currentTimeMillis();
        Span span = Span.current();
        
        // Add custom span attributes
        span.addEvent("Processing root request");
        span.setAllAttributes(Attributes.of(
            io.opentelemetry.api.common.AttributeKey.stringKey("custom.operation"), "root_endpoint",
            io.opentelemetry.api.common.AttributeKey.stringKey("custom.user_type"), "test_user"
        ));

        // Add tracing information to logs
        String traceId = span.getSpanContext().getTraceId();
        String spanId = span.getSpanContext().getSpanId();
        
        MDC.put("trace_id", traceId);
        MDC.put("span_id", spanId);
        
        logger.info("Root endpoint hit");

        // Record metrics
        long duration = System.currentTimeMillis() - startTime;
        Attributes metricLabels = Attributes.of(
            io.opentelemetry.api.common.AttributeKey.stringKey("method"), "GET",
            io.opentelemetry.api.common.AttributeKey.stringKey("route"), "/",
            io.opentelemetry.api.common.AttributeKey.stringKey("status_code"), "200"
        );

        cowsSoldCounter.add(1, Attributes.of(
            io.opentelemetry.api.common.AttributeKey.stringKey("cow_type"), "Holstein",
            io.opentelemetry.api.common.AttributeKey.stringKey("endpoint"), metricsEndpoint,
            io.opentelemetry.api.common.AttributeKey.stringKey("protocol"), metricsProtocol
        ));
        requestCounter.add(1, metricLabels);
        requestDuration.record(duration, metricLabels);

        Map<String, Object> response = new HashMap<>();
        response.put("message", "Java instrumented test server is running");
        response.put("traceId", traceId.isEmpty() ? "no-trace" : traceId);
        response.put("timestamp", Instant.now().toString());

        MDC.clear();
        return ResponseEntity.ok(response);
    }

    @GetMapping("/call-target")
    public Mono<ResponseEntity<Map<String, Object>>> callTarget() {
        return Mono.fromCallable(() -> {
            long startTime = System.currentTimeMillis();
            Span span = tracer.spanBuilder("call-target-operation")
                .setSpanKind(SpanKind.CLIENT)
                .startSpan();

            String traceId = span.getSpanContext().getTraceId();
            MDC.put("trace_id", traceId);
            MDC.put("span_id", span.getSpanContext().getSpanId());

            try {
                // Set span attributes
                span.setAllAttributes(Attributes.of(
                    io.opentelemetry.api.common.AttributeKey.stringKey("custom.operation"), "external_call",
                    io.opentelemetry.api.common.AttributeKey.stringKey("custom.target_url"), targetUrl,
                    io.opentelemetry.api.common.AttributeKey.longKey("custom.retry_count"), 1L
                ));

                // Simulate some processing time
                Thread.sleep((long) (Math.random() * 100));

                // Occasionally throw an error (30% chance)
                if (Math.random() < 0.3) {
                    RuntimeException error = new RuntimeException("Simulated error at /call-target");
                    span.recordException(error);
                    span.setStatus(StatusCode.ERROR, "Simulated error");
                    
                    logger.error("Simulated error at /call-target");

                    // Simulate async error handling
                    new Thread(() -> {
                        Span errorSpan = tracer.spanBuilder("async-error-handler")
                            .setParent(io.opentelemetry.context.Context.current().with(span))
                            .startSpan();
                        try {
                            errorSpan.addEvent("Handling async error");
                            throw new RuntimeException("Unhandled async error - server should continue");
                        } catch (Exception asyncError) {
                            errorSpan.recordException(asyncError);
                            errorSpan.setStatus(StatusCode.ERROR, "Async error handled");
                            logger.error("Async error handled: {}", asyncError.getMessage());
                        } finally {
                            errorSpan.end();
                        }
                    }).start();

                    Map<String, Object> errorResponse = new HashMap<>();
                    errorResponse.put("message", "Error triggered asynchronously");
                    errorResponse.put("traceId", traceId);
                    errorResponse.put("timestamp", Instant.now().toString());

                    long duration = System.currentTimeMillis() - startTime;
                    recordMetrics("GET", "/call-target", "500", duration);

                    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
                }

                // Add an event before making the external call
                span.addEvent("Making external HTTP request", Attributes.of(
                    io.opentelemetry.api.common.AttributeKey.stringKey("http.url"), targetUrl,
                    io.opentelemetry.api.common.AttributeKey.stringKey("http.method"), "GET"
                ));

                return webClient.get()
                    .uri(targetUrl)
                    .retrieve()
                    .bodyToMono(String.class)
                    .timeout(Duration.ofSeconds(5))
                    .map(responseBody -> {
                        // Add successful call event
                        span.addEvent("External HTTP request completed", Attributes.of(
                            io.opentelemetry.api.common.AttributeKey.stringKey("http.status_code"), "200",
                            io.opentelemetry.api.common.AttributeKey.longKey("response.size"), (long) responseBody.length()
                        ));

                        span.setStatus(StatusCode.OK);
                        logger.info("Successfully called target: {}", targetUrl);

                        Map<String, Object> response = new HashMap<>();
                        response.put("message", "Success");
                        response.put("data", responseBody);
                        response.put("traceId", traceId);
                        response.put("timestamp", Instant.now().toString());

                        long duration = System.currentTimeMillis() - startTime;
                        recordMetrics("GET", "/call-target", "200", duration);

                        return ResponseEntity.ok(response);
                    })
                    .onErrorResume(error -> {
                        span.recordException((Throwable) error);
                        span.setStatus(StatusCode.ERROR, error.getMessage());
                        
                        logger.error("Error calling target: {}", error.getMessage());
                        
                        Map<String, Object> errorResponse = new HashMap<>();
                        errorResponse.put("message", "Error calling target");
                        errorResponse.put("error", error.getMessage());
                        errorResponse.put("traceId", traceId);
                        errorResponse.put("timestamp", Instant.now().toString());

                        long duration = System.currentTimeMillis() - startTime;
                        recordMetrics("GET", "/call-target", "500", duration);

                        return Mono.just(ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse));
                    })
                    .block();

            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                span.recordException(e);
                span.setStatus(StatusCode.ERROR, e.getMessage());
                
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("message", "Request interrupted");
                errorResponse.put("error", e.getMessage());
                errorResponse.put("traceId", traceId);
                errorResponse.put("timestamp", Instant.now().toString());

                long duration = System.currentTimeMillis() - startTime;
                recordMetrics("GET", "/call-target", "500", duration);

                return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
            } finally {
                span.end();
                MDC.clear();
            }
        });
    }

    @GetMapping("/generate-load")
    public ResponseEntity<Map<String, Object>> generateLoad(
            @RequestParam(value = "iterations", defaultValue = "10") int iterations) {
        
        long startTime = System.currentTimeMillis();
        Span span = tracer.spanBuilder("generate-load-operation").startSpan();
        
        String traceId = span.getSpanContext().getTraceId();
        MDC.put("trace_id", traceId);
        MDC.put("span_id", span.getSpanContext().getSpanId());

        span.setAllAttributes(Attributes.of(
            io.opentelemetry.api.common.AttributeKey.stringKey("custom.operation"), "load_generation",
            io.opentelemetry.api.common.AttributeKey.longKey("custom.iterations"), (long) iterations
        ));

        try {
            List<Map<String, Object>> results = new ArrayList<>();

            for (int i = 0; i < iterations; i++) {
                Span childSpan = tracer.spanBuilder("load-iteration-" + i)
                    .setParent(io.opentelemetry.context.Context.current().with(span))
                    .startSpan();

                try {
                    // Simulate some work
                    long workDuration = (long) (Math.random() * 50);
                    Thread.sleep(workDuration);

                    childSpan.setAllAttributes(Attributes.of(
                        io.opentelemetry.api.common.AttributeKey.longKey("custom.iteration"), (long) i,
                        io.opentelemetry.api.common.AttributeKey.longKey("custom.work_duration"), workDuration
                    ));

                    Map<String, Object> result = new HashMap<>();
                    result.put("iteration", i);
                    result.put("status", "success");
                    results.add(result);
                    
                    childSpan.setStatus(StatusCode.OK);
                } catch (Exception error) {
                    childSpan.recordException(error);
                    childSpan.setStatus(StatusCode.ERROR, error.getMessage());
                    
                    Map<String, Object> result = new HashMap<>();
                    result.put("iteration", i);
                    result.put("status", "error");
                    result.put("error", error.getMessage());
                    results.add(result);
                } finally {
                    childSpan.end();
                }
            }

            long successfulIterations = results.stream()
                .mapToLong(r -> "success".equals(r.get("status")) ? 1 : 0)
                .sum();

            span.addEvent("Load generation completed", Attributes.of(
                io.opentelemetry.api.common.AttributeKey.longKey("custom.total_iterations"), (long) iterations,
                io.opentelemetry.api.common.AttributeKey.longKey("custom.successful_iterations"), successfulIterations
            ));

            span.setStatus(StatusCode.OK);
            logger.info("Load generation completed: {} iterations", iterations);

            Map<String, Object> response = new HashMap<>();
            response.put("message", "Load generation completed");
            response.put("iterations", iterations);
            response.put("results", results);
            response.put("traceId", traceId);
            response.put("timestamp", Instant.now().toString());

            long duration = System.currentTimeMillis() - startTime;
            recordMetrics("GET", "/generate-load", "200", duration);

            return ResponseEntity.ok(response);

        } catch (Exception error) {
            span.recordException(error);
            span.setStatus(StatusCode.ERROR, error.getMessage());
            logger.error("Error during load generation: {}", error.getMessage());
            
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("message", "Error during load generation");
            errorResponse.put("error", error.getMessage());
            errorResponse.put("traceId", traceId);
            errorResponse.put("timestamp", Instant.now().toString());

            long duration = System.currentTimeMillis() - startTime;
            recordMetrics("GET", "/generate-load", "500", duration);

            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        } finally {
            span.end();
            MDC.clear();
        }
    }

    private void recordMetrics(String method, String route, String statusCode, long duration) {
        Attributes labels = Attributes.of(
            io.opentelemetry.api.common.AttributeKey.stringKey("method"), method,
            io.opentelemetry.api.common.AttributeKey.stringKey("route"), route,
            io.opentelemetry.api.common.AttributeKey.stringKey("status_code"), statusCode
        );

        cowsSoldCounter.add(1, Attributes.of(
            io.opentelemetry.api.common.AttributeKey.stringKey("cow_type"), "Holstein",
            io.opentelemetry.api.common.AttributeKey.stringKey("endpoint"), metricsEndpoint,
            io.opentelemetry.api.common.AttributeKey.stringKey("protocol"), metricsProtocol
        ));
        requestCounter.add(1, labels);
        requestDuration.record(duration, labels);

        if (Integer.parseInt(statusCode) >= 400) {
            errorCounter.add(1, labels);
        }
    }
}
