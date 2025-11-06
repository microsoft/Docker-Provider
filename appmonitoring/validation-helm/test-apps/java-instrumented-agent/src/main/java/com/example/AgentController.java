package com.example;

import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.metrics.LongHistogram;
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.Tracer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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
public class AgentController {

    private static final Logger logger = LoggerFactory.getLogger(AgentController.class);
    
    // Access OpenTelemetry via GlobalOpenTelemetry (auto-configured by the agent)
    private final Tracer tracer;
    private final Meter meter;
    private final LongCounter cowsSoldCounter;
    private final WebClient webClient;

    @Value("${target.url:http://localhost:8080/}")
    private String targetUrl;

    @Autowired
    public AgentController(WebClient webClient) {
        this.webClient = webClient;
        
        // Get tracer and meter from GlobalOpenTelemetry (configured by the agent)
        this.tracer = GlobalOpenTelemetry.getTracer("java-instrumented-agent-app", "1.0.0");
        this.meter = GlobalOpenTelemetry.getMeter("java-instrumented-agent-app");
        
        // Initialize custom metrics
        // Note: HTTP request metrics are automatically created by the agent
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
        response.put("message", "Metrics are automatically collected by OpenTelemetry Java agent");
        response.put("agent", "OpenTelemetry Java Agent");
        return ResponseEntity.ok(response);
    }

    @GetMapping("/")
    public ResponseEntity<Map<String, Object>> root() {
        long startTime = System.currentTimeMillis();
        Span span = Span.current();
        
        // Add custom span attributes (agent handles most instrumentation automatically)
        span.addEvent("Processing root request");
        span.setAllAttributes(Attributes.of(
            io.opentelemetry.api.common.AttributeKey.stringKey("custom.operation"), "root_endpoint",
            io.opentelemetry.api.common.AttributeKey.stringKey("custom.user_type"), "test_user"
        ));
        
        try {
            Map<String, Object> response = new HashMap<>();
            response.put("message", "Hello from Java Instrumented Agent App!");
            response.put("app", "java-instrumented-agent-app");
            response.put("instrumentation", "OpenTelemetry Java Agent (Zero-code)");
            response.put("timestamp", Instant.now().toString());
            response.put("version", "1.0.0");
            
            long duration = System.currentTimeMillis() - startTime;
            response.put("duration_ms", duration);
            
            logger.info("Root endpoint called - duration: {}ms", duration);
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("Error processing root request", e);
            span.recordException(e);
            throw e;
        }
    }

    @GetMapping("/sell-cows")
    public ResponseEntity<Map<String, Object>> sellCows(@RequestParam(defaultValue = "1") int count) {
        Span span = Span.current();
        span.setAttribute("cows.count", count);
        
        // Increment custom counter
        cowsSoldCounter.add(count);
        
        Map<String, Object> response = new HashMap<>();
        response.put("cows_sold", count);
        response.put("timestamp", Instant.now().toString());
        response.put("message", String.format("Successfully sold %d cow(s)", count));
        
        logger.info("Sold {} cow(s)", count);
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/call-target")
    public ResponseEntity<Map<String, Object>> callTarget() {
        long startTime = System.currentTimeMillis();
        Span span = Span.current();
        
        span.addEvent("Starting external HTTP call");
        span.setAttribute("target.url", targetUrl);
        
        try {
            // Simulate 30% error rate
            if (ThreadLocalRandom.current().nextInt(100) < 30) {
                logger.warn("Simulating error condition");
                throw new RuntimeException("Simulated error (30% chance)");
            }
            
            // Make HTTP call (automatically instrumented by the agent)
            String result = webClient.get()
                .uri(targetUrl)
                .retrieve()
                .bodyToMono(String.class)
                .timeout(Duration.ofSeconds(5))
                .block();
            
            long duration = System.currentTimeMillis() - startTime;
            
            Map<String, Object> response = new HashMap<>();
            response.put("target_url", targetUrl);
            response.put("status", "success");
            response.put("duration_ms", duration);
            response.put("timestamp", Instant.now().toString());
            
            span.addEvent("External call completed successfully");
            logger.info("External call to {} completed in {}ms", targetUrl, duration);
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            long duration = System.currentTimeMillis() - startTime;
            
            logger.error("Error calling target: {}", e.getMessage());
            span.recordException(e);
            
            Map<String, Object> response = new HashMap<>();
            response.put("target_url", targetUrl);
            response.put("status", "error");
            response.put("error", e.getMessage());
            response.put("duration_ms", duration);
            response.put("timestamp", Instant.now().toString());
            
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }

    @GetMapping("/generate-load")
    public ResponseEntity<Map<String, Object>> generateLoad(@RequestParam(defaultValue = "10") int iterations) {
        long overallStart = System.currentTimeMillis();
        Span span = Span.current();
        
        span.setAttribute("load.iterations", iterations);
        logger.info("Starting load generation with {} iterations", iterations);
        
        int successCount = 0;
        int errorCount = 0;
        List<Long> durations = new ArrayList<>();
        
        for (int i = 0; i < iterations; i++) {
            long iterStart = System.currentTimeMillis();
            
            try {
                // Call the target endpoint
                webClient.get()
                    .uri(targetUrl)
                    .retrieve()
                    .bodyToMono(String.class)
                    .timeout(Duration.ofSeconds(5))
                    .block();
                
                successCount++;
                
                // Randomly sell cows (50% chance)
                if (ThreadLocalRandom.current().nextBoolean()) {
                    int cowsToSell = ThreadLocalRandom.current().nextInt(1, 6);
                    cowsSoldCounter.add(cowsToSell);
                    logger.debug("Iteration {}: Sold {} cows", i + 1, cowsToSell);
                }
                
            } catch (Exception e) {
                errorCount++;
                logger.debug("Iteration {}: Error - {}", i + 1, e.getMessage());
            }
            
            long iterDuration = System.currentTimeMillis() - iterStart;
            durations.add(iterDuration);
            
            // Small delay between iterations
            try {
                Thread.sleep(ThreadLocalRandom.current().nextInt(10, 50));
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
        
        long overallDuration = System.currentTimeMillis() - overallStart;
        long avgDuration = durations.stream().mapToLong(Long::longValue).sum() / durations.size();
        
        Map<String, Object> response = new HashMap<>();
        response.put("iterations", iterations);
        response.put("success_count", successCount);
        response.put("error_count", errorCount);
        response.put("overall_duration_ms", overallDuration);
        response.put("average_request_duration_ms", avgDuration);
        response.put("timestamp", Instant.now().toString());
        
        span.addEvent("Load generation completed");
        logger.info("Load generation completed: {} iterations, {} success, {} errors, {}ms total", 
                   iterations, successCount, errorCount, overallDuration);
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/error")
    public ResponseEntity<Map<String, Object>> simulateError() {
        Span span = Span.current();
        span.setAttribute("error.type", "simulated");
        
        logger.error("Simulating error endpoint");
        
        RuntimeException exception = new RuntimeException("This is a simulated error for testing");
        span.recordException(exception);
        
        throw exception;
    }
}
