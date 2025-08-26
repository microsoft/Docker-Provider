# docker buildx build --platform linux/amd64,linux/arm64 -t appmonitoring.azurecr.io/demoaks-go-instrumented-app:latest --push .

# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY main.go ./

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o go-instrumented-test-app .

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests and curl for health checks
RUN apk --no-cache add ca-certificates curl

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/go-instrumented-test-app .

# Set OpenTelemetry environment variables
ENV OTEL_SERVICE_NAME=go-instrumented-test-app
ENV OTEL_SERVICE_VERSION=1.0.0
ENV OTEL_ENVIRONMENT=production
ENV OTEL_LOG_LEVEL=info

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3001/health || exit 1

# Start the application
CMD ["./go-instrumented-test-app"]
