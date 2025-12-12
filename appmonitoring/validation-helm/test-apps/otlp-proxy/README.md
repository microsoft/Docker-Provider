# OTLP Proxy

A simple OpenTelemetry Protocol (OTLP) proxy that intercepts, logs, and forwards telemetry data.

## Purpose

This proxy is designed to intercept OTLP exports from applications that use auto-instrumentation (via environment variables) to see what metrics, traces, and logs are being sent. It specifically filters and logs cow-related metrics for validation purposes.

## Features

- **Intercepts OTLP HTTP exports** on port 4318
- **Logs cow-related metrics** to console in JSON format
- **Forwards all telemetry** to a configurable downstream endpoint
- **Supports both JSON and Protobuf** formats
- **Passthrough for traces and logs** (metrics are logged)

## Usage

### Environment Variables

- `PORT` - Port to listen on (default: 4318)
- `FORWARD_ENDPOINT` - Downstream OTLP endpoint to forward to (default: http://localhost:56682)

### Running Locally

```bash
npm install
PORT=4318 FORWARD_ENDPOINT=http://your-collector:4318 node server.js
```

### Running with Docker

```bash
docker build -t otlp-proxy .
docker run -p 4318:4318 -e FORWARD_ENDPOINT=http://collector:4318 otlp-proxy
```

### Kubernetes Deployment

Deploy as a sidecar container alongside apps that need metric inspection:

```yaml
- name: otlp-proxy
  image: appmonitoring.azurecr.io/otlp-proxy:latest
  ports:
  - containerPort: 4318
  env:
  - name: FORWARD_ENDPOINT
    value: "http://actual-collector:4318"
```

Then configure your app to send metrics to the proxy:

```yaml
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: "http://localhost:4318"
```

## Output Format

When cow-related metrics are detected, the proxy logs:

```json
{
  "k8s.pod.name": "my-app-pod-xyz",
  "cow_metrics": [
    {
      "name": "cows_sold_total",
      "description": "Total number of cows sold",
      "unit": "",
      "data": { /* metric data points */ }
    }
  ]
}
```

## Endpoints

- `POST /v1/metrics` - Intercepts, logs, and forwards metrics
- `POST /v1/traces` - Passthrough for traces
- `POST /v1/logs` - Passthrough for logs
- `GET /health` - Health check endpoint
- `GET /` - Status page
