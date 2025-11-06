# Comparison: Manual Instrumentation vs Java Agent

This document compares the `java-instrumented` and `java-instrumented-agent` test applications.

## Architecture Comparison

### java-instrumented (Manual SDK Instrumentation)
- **Approach**: Manual integration of OpenTelemetry SDK
- **Dependencies**: ~10 OpenTelemetry libraries in pom.xml
- **Configuration**: Requires `OpenTelemetryConfig.java` class
- **Code Changes**: Extensive - tracer/meter injection, manual span creation
- **File Count**: 3 Java classes (App, Config, Controller)

### java-instrumented-agent (Zero-code Agent)
- **Approach**: Automatic instrumentation via Java agent
- **Dependencies**: 1 OpenTelemetry API library (optional, for custom metrics)
- **Configuration**: Pure environment variables
- **Code Changes**: Minimal - only for custom metrics
- **File Count**: 2 Java classes (App, Controller)

## Code Differences

### pom.xml Dependencies

**Manual (java-instrumented)**:
```xml
<!-- Multiple OpenTelemetry dependencies -->
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-api</artifactId>
</dependency>
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-sdk</artifactId>
</dependency>
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-sdk-extension-autoconfigure</artifactId>
</dependency>
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-exporter-otlp</artifactId>
</dependency>
<!-- ... more dependencies -->
```

**Agent (java-instrumented-agent)**:
```xml
<!-- Single optional dependency for custom metrics -->
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-api</artifactId>
    <version>1.36.0</version>
</dependency>
```

### Configuration

**Manual (java-instrumented)**:
- Requires `OpenTelemetryConfig.java` class (~70 lines)
- Manual setup of SDK, exporters, and resource attributes
- Configuration beans for OpenTelemetry and Meter

**Agent (java-instrumented-agent)**:
- No configuration class needed
- All configuration via environment variables
- Agent handles SDK initialization automatically

### Controller Code

**Manual (java-instrumented)**:
```java
@Autowired
public InstrumentedController(OpenTelemetry openTelemetry, Meter meter, WebClient webClient) {
    this.tracer = openTelemetry.getTracer("java-instrumented-test-app", "1.0.0");
    this.meter = meter;
    this.webClient = webClient;
    
    // Manual metric initialization
    this.requestCounter = meter.counterBuilder("http_requests_total")...
    this.requestDuration = meter.histogramBuilder("http_request_duration_ms")...
    this.errorCounter = meter.counterBuilder("http_errors_total")...
}
```

**Agent (java-instrumented-agent)**:
```java
@Autowired
public AgentController(WebClient webClient) {
    this.webClient = webClient;
    
    // Access GlobalOpenTelemetry (auto-configured by agent)
    this.tracer = GlobalOpenTelemetry.getTracer("java-instrumented-agent-app", "1.0.0");
    this.meter = GlobalOpenTelemetry.getMeter("java-instrumented-agent-app");
    
    // Only custom metrics need to be defined
    // HTTP metrics are automatically created by the agent
    this.cowsSoldCounter = meter.counterBuilder("cows_sold_total")...
}
```

### Dockerfile

**Manual (java-instrumented)**:
```dockerfile
# Runtime stage - standard Java application
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
COPY --from=build /app/target/java-instrumented-test-app-1.0.0.jar app.jar

# Start normally
CMD ["java", "-jar", "app.jar"]
```

**Agent (java-instrumented-agent)**:
```dockerfile
# Runtime stage - includes agent download
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# Download OpenTelemetry Java agent
ARG OTEL_AGENT_VERSION=2.10.0
RUN curl -L https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_AGENT_VERSION}/opentelemetry-javaagent.jar \
    -o /app/opentelemetry-javaagent.jar

COPY --from=build /app/target/java-instrumented-agent-app-1.0.0.jar app.jar

# Start with agent attached
CMD ["java", "-javaagent:/app/opentelemetry-javaagent.jar", "-jar", "app.jar"]
```

## Automatic vs Manual Instrumentation

### Automatically Instrumented by Agent
- ✅ HTTP server requests (Spring Web, Servlets)
- ✅ HTTP client requests (WebClient, RestTemplate, Apache HttpClient, OkHttp)
- ✅ JDBC database calls
- ✅ JVM metrics (memory, GC, threads)
- ✅ Standard HTTP metrics (request count, duration, status codes)
- ✅ Logging with trace correlation
- ✅ Distributed context propagation

### Requires Manual Code (Both Approaches)
- Custom business metrics (e.g., `cows_sold_total`)
- Custom span attributes specific to business logic
- Custom events within spans

## Environment Variables

### Manual (java-instrumented)
```yaml
env:
- name: OTEL_SERVICE_NAME
  value: "java-instrumented-test-app"
- name: OTEL_EXPORTER_OTLP_METRICS_ENDPOINT
  value: "http://localhost:56682/v1/metrics"
- name: OTEL_EXPORTER_OTLP_METRICS_PROTOCOL
  value: "http/protobuf"
```

### Agent (java-instrumented-agent)
```yaml
env:
- name: OTEL_SERVICE_NAME
  value: "java-instrumented-agent-app"
- name: OTEL_RESOURCE_ATTRIBUTES
  value: "deployment.environment=production,service.namespace=ns1"
- name: OTEL_TRACES_EXPORTER
  value: "otlp"
- name: OTEL_METRICS_EXPORTER
  value: "otlp"
- name: OTEL_LOGS_EXPORTER
  value: "otlp"
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: "http/protobuf"
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "http://localhost:4318"
```

## Metrics Generated

### Manual Instrumentation
- Custom: `cows_sold_total`, `http_requests_total`, `http_request_duration_ms`, `http_errors_total`
- JVM metrics: Requires additional manual setup

### Agent Instrumentation
- Custom: `cows_sold_total`
- Automatic HTTP metrics: `http.server.request.duration`, `http.client.request.duration`, etc.
- Automatic JVM metrics: Memory, GC, threads, classes
- Database metrics (if database is used)

## When to Use Each Approach

### Use Manual Instrumentation (`java-instrumented`) When:
- You need fine-grained control over instrumentation
- You want to instrument specific code paths only
- You're building a library that needs embedded telemetry
- You need custom instrumentation not supported by the agent
- You want to minimize runtime overhead

### Use Agent (`java-instrumented-agent`) When:
- You want zero-code or minimal-code instrumentation
- You need broad, automatic instrumentation across frameworks
- You want standardized telemetry across multiple services
- You prefer configuration via environment variables
- You want to add instrumentation to existing apps without code changes
- You need to instrument third-party libraries automatically

## Performance Considerations

### Manual Instrumentation
- Lower overhead (only instruments what you code)
- More control over sampling and filtering
- Smaller runtime footprint

### Agent Instrumentation
- Slightly higher overhead (instruments all supported libraries)
- Agent adds ~5-10% overhead in most cases
- Larger JVM startup time (agent initialization)
- More comprehensive telemetry by default

## Maintenance

### Manual Instrumentation
- Update OpenTelemetry dependencies in pom.xml
- Update configuration code if API changes
- Add new instrumentation as libraries are updated

### Agent Instrumentation
- Update agent JAR version in Dockerfile
- No code changes needed for new library support
- Agent updates include new instrumentation automatically

## Summary

| Aspect | Manual | Agent |
|--------|--------|-------|
| Setup Effort | High | Low |
| Code Complexity | High | Low |
| Dependencies | Many | Few |
| Automatic Coverage | Limited | Comprehensive |
| Flexibility | Maximum | Standard |
| Maintenance | Moderate | Low |
| Best For | Custom needs | Standard applications |

Both approaches produce high-quality telemetry. The choice depends on your specific requirements for control, simplicity, and coverage.
