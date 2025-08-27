# Node.js Instrumented Test Application

This is a sample Node.js application instrumented with the latest OpenTelemetry SDK for distributed tracing, metrics, and logging.

## Features

- **OpenTelemetry Instrumentation**: Comprehensive tracing and metrics collection
- **Auto-Instrumentation**: Automatic instrumentation for HTTP, Express, Winston, and other popular libraries
- **Resource Attributes**: Respects `OTEL_RESOURCE_ATTRIBUTES` environment variable automatically via the OpenTelemetry Node.js SDK
- **Custom Spans**: Manual span creation for business logic
- **Custom Metrics**: Counter, histogram, and gauge metrics
- **Distributed Tracing**: Correlation IDs in logs and proper trace propagation
- **Error Handling**: Exception recording and error span status
- **Health Checks**: Kubernetes-ready health and readiness probes
- **Load Testing**: Built-in endpoint for generating test load

## OpenTelemetry Components Used

- `@opentelemetry/sdk-node`: Core OpenTelemetry SDK for Node.js
- `@opentelemetry/auto-instrumentations-node`: Auto-instrumentation for popular libraries
- `@opentelemetry/exporter-otlp-http`: OTLP HTTP exporter for traces and metrics
- `@opentelemetry/resources`: Resource semantic conventions
- `@opentelemetry/api`: OpenTelemetry API for manual instrumentation

## Endpoints

- `GET /` - Root endpoint with basic response
- `GET /health` - Health check endpoint (not traced)
- `GET /metrics` - Metrics endpoint for monitoring
- `GET /call-target` - Calls another service (demonstrates distributed tracing)
- `GET /generate-load?iterations=N` - Generates load for testing (creates multiple spans)

## Environment Variables

### OpenTelemetry Configuration
- `OTEL_SERVICE_NAME`: Service name (default: nodejs-instrumented-test-app)
- `OTEL_SERVICE_VERSION`: Service version (default: 1.0.0)
- `OTEL_ENVIRONMENT`: Deployment environment (default: development)
- `OTEL_RESOURCE_ATTRIBUTES`: Additional resource attributes (comma-separated key=value pairs)
- `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`: OTLP traces endpoint (default: http://localhost:4318/v1/traces)
- `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`: OTLP metrics endpoint (default: http://localhost:4318/v1/metrics)
- `OTEL_LOG_LEVEL`: OpenTelemetry log level (default: info)

### Application Configuration
- `PORT`: Server port (default: 3001)
- `TARGET_URL`: URL for the /call-target endpoint to call (default: http://localhost:3001/)
- `NODE_ENV`: Node.js environment (default: development)

## Running Locally

### Prerequisites
- Node.js 20 or later
- OpenTelemetry Collector or compatible backend (Jaeger, Zipkin, etc.)

### Installation
```bash
npm install
```

### Start the application
```bash
npm start
```

### With OpenTelemetry Collector
1. Start an OpenTelemetry Collector on port 4318
2. Configure the collector to export to your preferred backend (Jaeger, Zipkin, etc.)
3. Start the application

Example collector configuration:
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:

exporters:
  jaeger:
    endpoint: http://jaeger:14250
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [jaeger]
```

## Running in Docker

### Build the image
```bash
docker build -t nodejs-instrumented-test-app .
```

### Run the container
```bash
docker run -p 3001:3001 \
  -e OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://host.docker.internal:4318/v1/traces \
  -e OTEL_RESOURCE_ATTRIBUTES="deployment.environment=production,service.version=1.0.0" \
  nodejs-instrumented-test-app
```

## Running in Kubernetes

### Deploy to Kubernetes
```bash
# Replace variables in chart.yaml with actual values
export NODEJS_INSTRUMENTED_TEST_APP_NAME=nodejs-instrumented-test-app
export TEST_NS=default
export TEST_APP_SOURCE_NAME=test-app-source

# Apply the chart
envsubst < chart.yaml | kubectl apply -f -
```

### Verify deployment
```bash
kubectl get pods -l app=nodejs-instrumented-test-app
kubectl logs -l app=nodejs-instrumented-test-app
```

## Observability Features

### Traces
- HTTP request/response traces
- Database query traces (if database is used)
- External service call traces
- Custom business logic traces
- Error and exception traces

### Metrics
- `http_requests_total`: Counter of HTTP requests by method, route, and status
- `http_request_duration_ms`: Histogram of HTTP request durations
- `http_errors_total`: Counter of HTTP errors by method, route, and status

### Logs
- Structured logging with Winston
- Correlation IDs (trace ID and span ID) in all log entries
- Error logging with stack traces
- Request/response logging

### Custom Instrumentation Examples

The application demonstrates several OpenTelemetry patterns:

1. **Manual Span Creation**:
```javascript
const span = tracer.startSpan('custom-operation');
try {
  // Your business logic
  span.setAttributes({ 'custom.attribute': 'value' });
  span.addEvent('Important event happened');
} catch (error) {
  span.recordException(error);
  span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
} finally {
  span.end();
}
```

2. **Custom Metrics**:
```javascript
const counter = meter.createCounter('custom_counter');
counter.add(1, { 'label': 'value' });
```

3. **Log Correlation**:
```javascript
const span = trace.getActiveSpan();
const traceId = span?.spanContext().traceId;
logger.info(`Message with trace ID: ${traceId}`);
```

## Testing

### Generate test traffic
```bash
# Basic request
curl http://localhost:3001/

# Test external calls
curl http://localhost:3001/call-target

# Generate load
curl "http://localhost:3001/generate-load?iterations=10"

# Check health
curl http://localhost:3001/health
```

### View traces
- Open your tracing backend (Jaeger, Zipkin, etc.)
- Search for traces from service `nodejs-instrumented-test-app`
- Explore distributed traces and span details

## Integration with Azure Monitor

To send telemetry to Azure Monitor, update the OpenTelemetry configuration:

```javascript
// Use Azure Monitor exporter
const { AzureMonitorTraceExporter } = require('@azure/monitor-opentelemetry-exporter');

const traceExporter = new AzureMonitorTraceExporter({
  connectionString: process.env.APPLICATIONINSIGHTS_CONNECTION_STRING
});
```

## Troubleshooting

1. **No traces appearing**: Check that the OTLP endpoint is reachable and the collector is running
2. **Missing spans**: Verify that auto-instrumentation is enabled for the libraries you're using
3. **Performance issues**: Adjust sampling rates and batch sizes in the SDK configuration
4. **Memory usage**: Monitor the application for memory leaks, especially in high-traffic scenarios

## Performance Considerations

- The OpenTelemetry SDK adds minimal overhead (typically <5% CPU and memory)
- Sampling can be configured to reduce trace volume in production
- Batch processing reduces the frequency of exports
- Resource attributes are set once at startup to avoid overhead

## Architecture

### Resource Attributes Handling

The Node.js OpenTelemetry SDK automatically respects the `OTEL_RESOURCE_ATTRIBUTES` environment variable using the built-in resource detection system. This includes:

1. **Environment Variable Detection**: The `EnvDetector` automatically parses `OTEL_RESOURCE_ATTRIBUTES` and includes all specified attributes in the resource
2. **Standard Attribute Support**: Standard OpenTelemetry environment variables like `OTEL_SERVICE_NAME` are automatically detected
3. **Automatic Merging**: Custom attributes from `OTEL_RESOURCE_ATTRIBUTES` are merged with service information and system-detected attributes (process, host information)
4. **Universal Application**: These resource attributes are automatically attached to all traces, metrics, and logs exported by the application

This ensures that metadata like deployment environment, service version, team ownership, and custom business attributes are consistently applied across all telemetry data without requiring code changes.

## Security Considerations

- Sensitive data should not be included in span attributes or events
- Use appropriate authentication for OTLP endpoints
- Consider using TLS for all telemetry exports in production
- Regularly update OpenTelemetry dependencies for security patches
