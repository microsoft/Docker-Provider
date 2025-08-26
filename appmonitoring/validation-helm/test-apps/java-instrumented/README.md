# Java Instrumented Test App

A Java Spring Boot application instrumented with OpenTelemetry SDK for testing application monitoring capabilities.

## Overview

This application is designed to test OpenTelemetry integration in Java applications. It provides:

- **OpenTelemetry SDK Integration**: Manual instrumentation with traces, metrics, and logs
- **Custom Metrics**: Including the `cows_sold_total` metric sent via OTLP
- **Configurable Protocol Support**: Supports both HTTP/Protobuf and gRPC protocols via environment variables
- **Configurable Endpoint**: OTLP endpoint can be configured via environment variables
- **Multiple Endpoints**: Various HTTP endpoints for testing different scenarios
- **Correlation IDs**: Distributed tracing with trace and span ID correlation in logs

## Features

### Metrics
- `cows_sold_total`: Custom counter metric for testing purposes
- `http_requests_total`: HTTP request counter
- `http_request_duration_ms`: HTTP request duration histogram  
- `http_errors_total`: HTTP error counter

### Endpoints
- `GET /`: Root endpoint with basic response and tracing
- `GET /health`: Health check endpoint (Spring Boot Actuator)
- `GET /actuator/health`: Detailed health check endpoint
- `GET /metrics`: Metrics endpoint placeholder
- `GET /call-target`: Makes external HTTP calls with error simulation (30% chance)
- `GET /generate-load?iterations=N`: Generate load with N iterations for testing

### Tracing
- All endpoints are automatically instrumented
- Custom spans for specific operations
- Exception recording and error status setting
- Event recording for important operations
- Custom attributes and correlation IDs in logs

## Configuration

### Environment Variables

#### OpenTelemetry Configuration
- `OTEL_SERVICE_NAME`: Service name (default: `java-instrumented-test-app`)
- `OTEL_SERVICE_VERSION`: Service version (default: `1.0.0`)
- `OTEL_ENVIRONMENT`: Environment name (default: `development`)

#### OTLP Metrics Configuration
- `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`: OTLP metrics endpoint (default: `http://localhost:56682/v1/metrics`)
- `OTEL_EXPORTER_OTLP_METRICS_PROTOCOL`: Protocol - `http/protobuf` or `grpc` (default: `http/protobuf`)
- `OTEL_EXPORTER_OTLP_METRICS_INSECURE`: Use insecure connection (default: `true`)

#### Application Configuration  
- `SERVER_PORT`: HTTP server port (default: `8080`)
- `TARGET_URL`: Target URL for `/call-target` endpoint (default: `http://localhost:8080/`)

## Building and Running

### Local Development
```bash
# Build the application
mvn clean package

# Run the application
java -jar target/java-instrumented-test-app-1.0.0.jar

# Or run with Maven
mvn spring-boot:run
```

### Docker
```bash
# Build Docker image
docker build -t java-instrumented-app .

# Run with Docker
docker run -p 8080:8080 \
  -e OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://your-collector:4318/v1/metrics \
  -e OTEL_EXPORTER_OTLP_METRICS_PROTOCOL=http/protobuf \
  java-instrumented-app
```

### Kubernetes
```bash
# Deploy to Kubernetes
kubectl apply -f chart.yaml
```

## Testing

### Basic Health Check
```bash
curl http://localhost:8080/health
curl http://localhost:8080/actuator/health
```

### Test Endpoints
```bash
# Root endpoint
curl http://localhost:8080/

# External call (with 30% error rate)
curl http://localhost:8080/call-target

# Load generation
curl "http://localhost:8080/generate-load?iterations=5"
```

### Protocol Testing

#### HTTP/Protobuf Protocol
```bash
docker run -p 8080:8080 \
  -e OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://collector:4318/v1/metrics \
  -e OTEL_EXPORTER_OTLP_METRICS_PROTOCOL=http/protobuf \
  java-instrumented-app
```

#### gRPC Protocol  
```bash
docker run -p 8080:8080 \
  -e OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://collector:4317 \
  -e OTEL_EXPORTER_OTLP_METRICS_PROTOCOL=grpc \
  java-instrumented-app
```

## Dependencies

- Spring Boot 3.2.5
- OpenTelemetry Java SDK 1.36.0
- OpenTelemetry Spring Boot Starter 2.2.0
- Java 17+
- Maven 3.9+

## Comparison with Node.js Version

This Java application provides equivalent functionality to the Node.js instrumented test app:

| Feature | Node.js | Java |
|---------|---------|------|
| Framework | Express | Spring Boot |
| Port | 3001 | 8080 |
| Health Check | `/health` | `/health`, `/actuator/health` |
| Custom Metrics | ✓ | ✓ |
| Protocol Support | ✓ | ✓ |
| Tracing | ✓ | ✓ |
| Error Simulation | ✓ | ✓ |
| Load Generation | ✓ | ✓ |
| Correlation IDs | ✓ | ✓ |

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   HTTP Client   │───▶│  Spring Boot App │───▶│ OpenTelemetry   │
│                 │    │                  │    │ Collector       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │     Metrics      │
                       │ (cows_sold_total │
                       │  http_requests   │
                       │    errors, etc)  │
                       └──────────────────┘
```
