package com.example;

import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.sdk.autoconfigure.AutoConfiguredOpenTelemetrySdk;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenTelemetryConfig {
    
    private static final Logger logger = LoggerFactory.getLogger(OpenTelemetryConfig.class);

    @Value("${otel.exporter.otlp.metrics.endpoint:http://localhost:56682/v1/metrics}")
    private String metricsEndpoint;

    @Value("${otel.exporter.otlp.metrics.protocol:http/protobuf}")
    private String metricsProtocol;

    @Bean
    public OpenTelemetry openTelemetry() {
        logger.info("Initializing OpenTelemetry with auto-configuration:");
        logger.info("Metrics Endpoint: {}", metricsEndpoint);
        logger.info("Metrics Protocol: {}", metricsProtocol);
        logger.info("SDK will automatically respect OTEL_RESOURCE_ATTRIBUTES environment variable");

        // Use auto-configured SDK which automatically respects OTEL_RESOURCE_ATTRIBUTES
        AutoConfiguredOpenTelemetrySdk autoConfiguredSdk = AutoConfiguredOpenTelemetrySdk.builder()
            .addPropertiesSupplier(() -> {
                // Override specific properties if needed
                java.util.Map<String, String> props = new java.util.HashMap<>();
                props.put("otel.exporter.otlp.metrics.endpoint", metricsEndpoint);
                props.put("otel.exporter.otlp.metrics.protocol", metricsProtocol);
                props.put("otel.metric.export.interval", "5000"); // 5 seconds
                return props;
            })
            .build();

        OpenTelemetry openTelemetry = autoConfiguredSdk.getOpenTelemetrySdk();
        
        logger.info("OpenTelemetry initialized successfully with auto-configuration");
        logger.info("SDK will automatically parse OTEL_RESOURCE_ATTRIBUTES and attach to all metrics");
        
        // Shutdown hook
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            logger.info("Shutting down OpenTelemetry...");
            if (openTelemetry instanceof OpenTelemetrySdk) {
                ((OpenTelemetrySdk) openTelemetry).close();
            }
            logger.info("OpenTelemetry shutdown completed");
        }));

        return openTelemetry;
    }

    @Bean
    public Meter meter(OpenTelemetry openTelemetry) {
        // Use a static instrumentation name since service name is now in OTEL_RESOURCE_ATTRIBUTES
        return openTelemetry.getMeter("java-instrumented-test-app");
    }
}
