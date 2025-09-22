package com.example;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestTemplate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
//import io.micrometer.core.instrument.Counter;
//import io.micrometer.core.instrument.MeterRegistry;

import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.metrics.Meter;

import java.util.Random;

@RestController
public class HelloController {
    private static final Logger logger = LoggerFactory.getLogger(HelloController.class);
    Meter meter = GlobalOpenTelemetry.getMeter("OTEL.AzureMonitor.Demo");
    private String targetUrl = "https://bing.com";

    private final RestTemplate restTemplate = new RestTemplate();
    private final Random random = new Random();
    private final LongCounter cowsSoldCounter;

    public HelloController(/*MeterRegistry meterRegistry*/) {
        this.cowsSoldCounter = meter
                .counterBuilder("cows_sold_total")
                .build();
    }

    @GetMapping("/")
    public String hello() {
        logger.info("Received request at root endpoint '/'");
        logger.debug("Responding with static hello message");
        
        // Increment cows sold counter
        cowsSoldCounter.add(1, Attributes.of(AttributeKey.stringKey("name"), "cow", AttributeKey.stringKey("color"), "white"));
        logger.debug("Incremented cows_sold_total metric");
        
        return "Hello from Java test app!";
    }

    @GetMapping("/call-target")
    public String callTarget() {
        logger.info("Received request at '/call-target' endpoint");
        logger.debug("TARGET_URL value: {}", targetUrl);
        
        // Increment cows sold counter
        cowsSoldCounter.add(1, Attributes.of(AttributeKey.stringKey("name"), "cow", AttributeKey.stringKey("color"), "white"));
        
        logger.debug("Incremented cows_sold_total metric");
        
        // Occasionally throw an error
        if (random.nextInt(10) >= 7) { // 20% chance
            logger.error("Simulated error at '/call-target' endpoint");
            throw new RuntimeException("Simulated random error at call-target endpoint");
        }
        if (targetUrl == null || targetUrl.isEmpty()) {
            logger.warn("TARGET_URL not set or empty");
            return "TARGET_URL not set";
        }
        try {
            logger.info("Attempting to call target URL: {}", targetUrl);
            String response = restTemplate.getForObject(targetUrl, String.class);
            logger.info("Received response from target: {}", response);
            return "Response from target: " + response;
        } catch (Exception e) {
            logger.error("Error calling target URL: {}", targetUrl, e);
            return "Error calling target: " + e.getMessage();
        }
    }
}