# .NET Instrumented Test Application

This is a .NET 8.0 web application instrumented with OpenTelemetry SDK that mirrors the functionality of the nodejs-instrumented test application.

## Features

- **OpenTelemetry Metrics**: Exports metrics using OTLP (OpenTelemetry Protocol)
- **Configurable Endpoint**: Metrics endpoint configurable via `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` environment variable
- **Configurable Protocol**: Protocol configurable via `OTEL_EXPORTER_OTLP_METRICS_PROTOCOL` environment variable (supports `http/protobuf` and `grpc`)
- **Resource Attributes**: Respects `OTEL_RESOURCE_ATTRIBUTES` environment variable automatically via the OpenTelemetry .NET SDK
- **Custom Metrics**: Includes HTTP request counters, duration histograms, error counters, and business metrics (cows sold)
- **Health Check**: Provides `/health` endpoint for container health checks
- **Load Generation**: Provides `/generate-load` endpoint for testing

## Environment Variables

### Required OpenTelemetry Configuration
- `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`: Metrics export endpoint (default: `http://localhost:56682/v1/metrics`)
- `OTEL_EXPORTER_OTLP_METRICS_PROTOCOL`: Export protocol (`http/protobuf` or `grpc`, default: `http/protobuf`)

### Optional Configuration
- `OTEL_RESOURCE_ATTRIBUTES`: Additional resource attributes (comma-separated key=value pairs)
- `OTEL_SERVICE_NAME`: Service name (default: `dotnet-instrumented-test-app`)
- `OTEL_SERVICE_VERSION`: Service version (default: `1.0.0`)
- `OTEL_ENVIRONMENT`: Environment name (default: `development`)
- `TARGET_URL`: Target URL for `/call-target` and `/generate-load` endpoints
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
- `http_request_duration_ms`: Histogram for HTTP request duration
- `http_errors_total`: Counter for HTTP errors (4xx/5xx responses)
- `cows_sold_total`: Business metric counter (example custom metric)

All metrics include relevant labels such as method, route, status_code, etc.

## Building and Running

### Local Development
```bash
dotnet restore
dotnet run
```

### Docker
```bash
docker build -t dotnet-instrumented-test-app .
docker run -p 3001:3001 \
  -e OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://your-collector:4318/v1/metrics \
  -e OTEL_EXPORTER_OTLP_METRICS_PROTOCOL=http/protobuf \
  -e OTEL_RESOURCE_ATTRIBUTES="deployment.environment=production,service.version=1.0.0" \
  dotnet-instrumented-test-app
```

### Kubernetes
```bash
kubectl apply -f chart.yaml
```

## Comparison with nodejs-instrumented

This .NET application provides equivalent functionality to the nodejs-instrumented application:

1. **Same Metrics**: Implements the same custom metrics with similar naming and labels
2. **Same Configuration**: Uses the same environment variables for endpoint and protocol configuration
3. **Same Endpoints**: Provides equivalent REST endpoints
4. **Resource Attributes**: The OpenTelemetry .NET SDK automatically respects the `OTEL_RESOURCE_ATTRIBUTES` environment variable via the `ResourceBuilder.AddEnvironmentVariableDetector()` method
5. **Protocol Support**: Supports both HTTP/Protobuf and gRPC protocols for OTLP export

The main differences are:
- Uses .NET 8.0 runtime instead of Node.js
- Uses ASP.NET Core for HTTP server instead of Express.js
- Uses .NET OpenTelemetry SDK instead of Node.js OpenTelemetry SDK
- Native .NET logging integration instead of Winston logger
