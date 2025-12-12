# Go Instrumented Test Application

This is a Go web application instrumented with OpenTelemetry SDK that mirrors the functionality of the nodejs-instrumented test application.

## Features

- **OpenTelemetry Metrics**: Exports metrics using OTLP (OpenTelemetry Protocol)
- **Console Metrics Export**: Outputs metrics containing "cow" in their name to stdout for debugging
- **Configurable Endpoint**: Metrics endpoint configurable via `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` environment variable
- **Configurable Protocol**: Protocol configurable via `OTEL_EXPORTER_OTLP_METRICS_PROTOCOL` environment variable (supports `http/protobuf` and `grpc`)
- **Resource Attributes**: Respects `OTEL_RESOURCE_ATTRIBUTES` environment variable automatically via the OpenTelemetry Go SDK
- **Custom Metrics**: Includes HTTP request counters, duration histograms, error counters, and business metrics (cows sold)
- **HTTP Instrumentation**: Automatic instrumentation of HTTP requests using `otelhttp`
- **Health Check**: Provides `/health` endpoint for container health checks
- **Load Generation**: Provides `/generate-load` endpoint for testing

## Environment Variables

### Required OpenTelemetry Configuration
- `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`: Metrics export endpoint (default: `http://localhost:56682/v1/metrics`)
- `OTEL_EXPORTER_OTLP_METRICS_PROTOCOL`: Export protocol (`http/protobuf` or `grpc`, default: `http/protobuf`)

### Optional Configuration
- `OTEL_RESOURCE_ATTRIBUTES`: Additional resource attributes (comma-separated key=value pairs)
- `OTEL_SERVICE_NAME`: Service name (default: `go-instrumented-test-app`)
- `OTEL_SERVICE_VERSION`: Service version (default: `1.0.0`)
- `OTEL_ENVIRONMENT`: Environment name (default: `development`)
- `TARGET_URL`: Target URL for `/call-target` and `/generate-load` endpoints
- `PORT`: Server port (default: `3001`)
- `OTEL_LOG_LEVEL`: Logging level for OpenTelemetry

## Endpoints

- `GET /`: Returns application status and information
- `GET /health`: Health check endpoint
- `GET /metrics`: Metrics endpoint information
- `GET /call-target`: Makes HTTP call to `TARGET_URL`
- `GET /generate-load?iterations=N`: Generates load by making N requests to `TARGET_URL`

## Custom Metrics

The application exports the following custom metrics:

- `http_requests_total`: Counter for total HTTP requests
- `http_request_duration_ms`: Histogram for HTTP request duration in milliseconds
- `http_errors_total`: Counter for HTTP errors (4xx/5xx responses)
- `cows_sold_total`: Business metric counter (example custom metric)

All metrics include relevant labels such as method, route, status_code, etc.

## Console Metrics Export (Debugging Feature)

The application includes a console exporter that outputs metrics containing "cow" in their name to stdout. This feature runs in parallel with the OTLP exporter and is useful for:

- **Debugging**: Quickly verify that custom business metrics (like `cows_sold_total`) are being generated
- **Development**: See metric values in real-time without needing to query a metrics backend
- **Testing**: Validate metric instrumentation during development

The console output is formatted in a pretty-print JSON style and updates every 5 seconds. This exporter filters metrics at export time, so all metrics are still sent to the OTLP endpoint - only the console output is filtered.

The console output includes full metric details:
- **Temporality**: Counter and histogram metrics show `"Temporality": "CumulativeTemporality"` or `"DeltaTemporality"`
- **Histogram Type**: Histogram structure reveals if it's explicit buckets (with `"Bounds"` array) or exponential (with `"Scale"`, `"ZeroCount"`, etc.)
- **Data Points**: Full data point values with attributes and timestamps

Example console output for a counter:
```json
{
  "Resource": {...},
  "ScopeMetrics": [{
    "Scope": {"Name": "go-instrumented-test-app", "Version": "1.0.0"},
    "Metrics": [{
      "Name": "cows_sold_total",
      "Description": "Total number of cows sold",
      "Data": {
        "DataPoints": [{
          "Attributes": [{"Key": "cow_type", "Value": "Holstein"}],
          "StartTime": "2024-01-01T00:00:00Z",
          "Time": "2024-01-01T00:00:05Z",
          "Value": 42
        }],
        "Temporality": "CumulativeTemporality",
        "IsMonotonic": true
      }
    }]
  }]
}
```

Example for an explicit histogram (default):
```json
{
  "Name": "http_request_duration_ms",
  "Data": {
    "DataPoints": [{
      "Attributes": [...],
      "StartTime": "2024-01-01T00:00:00Z",
      "Time": "2024-01-01T00:00:05Z",
      "Count": 100,
      "Sum": 1234.5,
      "Bounds": [0, 5, 10, 25, 50, 75, 100, 250, 500, 1000],
      "BucketCounts": [0, 10, 20, 30, 15, 10, 8, 5, 2, 0, 0]
    }],
    "Temporality": "CumulativeTemporality"
  }
}
```

Example for an exponential histogram:
```json
{
  "Name": "http_request_duration_ms",
  "Data": {
    "DataPoints": [{
      "Attributes": [...],
      "StartTime": "2024-01-01T00:00:00Z",
      "Time": "2024-01-01T00:00:05Z",
      "Count": 100,
      "Sum": 1234.5,
      "Scale": 0,
      "ZeroCount": 0,
      "PositiveBucket": {
        "Offset": 0,
        "BucketCounts": [10, 20, 30, 25, 15]
      }
    }],
    "Temporality": "DeltaTemporality"
  }
}
```

## Dependencies

- **OpenTelemetry Go SDK**: Core OpenTelemetry functionality
- **OTLP Exporters**: HTTP and gRPC exporters for OTLP protocol
- **Stdout Metric Exporter**: Console exporter for debugging metrics
- **otelhttp**: HTTP instrumentation middleware
- **Gorilla Mux**: HTTP router and URL matcher
- **Logrus**: Structured logging

## Building and Running

### Local Development
```bash
go mod tidy
go run main.go
```

### Docker
```bash
docker build -t go-instrumented-test-app .
docker run -p 3001:3001 \
  -e OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://your-collector:4318/v1/metrics \
  -e OTEL_EXPORTER_OTLP_METRICS_PROTOCOL=http/protobuf \
  -e OTEL_RESOURCE_ATTRIBUTES="deployment.environment=production,service.version=1.0.0" \
  go-instrumented-test-app
```

### Kubernetes
```bash
kubectl apply -f chart.yaml
```

## Comparison with nodejs-instrumented

This Go application provides equivalent functionality to the nodejs-instrumented application:

1. **Same Metrics**: Implements the same custom metrics with similar naming and labels
2. **Same Configuration**: Uses the same environment variables for endpoint and protocol configuration
3. **Same Endpoints**: Provides equivalent REST endpoints
4. **Resource Attributes**: The OpenTelemetry Go SDK automatically respects the `OTEL_RESOURCE_ATTRIBUTES` environment variable via the `resource.WithFromEnv()` function
5. **Protocol Support**: Supports both HTTP/Protobuf and gRPC protocols for OTLP export

The main differences are:
- Uses Go runtime instead of Node.js
- Uses Gorilla Mux for HTTP routing instead of Express.js
- Uses Go OpenTelemetry SDK instead of Node.js OpenTelemetry SDK
- Uses Logrus for structured logging instead of Winston
- Compiled binary instead of interpreted JavaScript
- Generally lower memory footprint and faster startup time

## Architecture

The application follows Go best practices:

- **Graceful Shutdown**: Handles SIGINT/SIGTERM signals properly
- **Context Propagation**: Uses Go context for request lifecycle and OpenTelemetry trace propagation
- **Error Handling**: Proper error handling with structured logging
- **Middleware Pattern**: Uses middleware for metrics collection and OpenTelemetry instrumentation
- **Resource Management**: Proper cleanup of OpenTelemetry resources on shutdown
