package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
	"go.opentelemetry.io/otel/trace"

	"github.com/gorilla/mux"
	"github.com/sirupsen/logrus"
)

var (
	// OpenTelemetry instruments
	tracer trace.Tracer
	meter  metric.Meter

	// Custom metrics (same as nodejs-instrumented)
	httpRequestsTotal   metric.Int64Counter
	httpRequestDuration metric.Float64Histogram
	httpErrorsTotal     metric.Int64Counter
	cowsSoldTotal       metric.Int64Counter

	// Configuration
	serviceName    = getEnv("OTEL_SERVICE_NAME", "go-instrumented-test-app")
	serviceVersion = getEnv("OTEL_SERVICE_VERSION", "1.0.0")
	environment    = getEnv("OTEL_ENVIRONMENT", "development")
	port           = getEnv("PORT", "3001")
	targetURL      = getEnv("TARGET_URL", "http://localhost:3001/")

	// OTLP configuration
	metricsEndpoint = getEnv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT", "http://localhost:56682")
	metricsProtocol = getEnv("OTEL_EXPORTER_OTLP_METRICS_PROTOCOL", "http/protobuf")

	logger *logrus.Logger
)

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// initOpenTelemetry initializes OpenTelemetry with configurable OTLP exporter
func initOpenTelemetry(ctx context.Context) (*sdkmetric.MeterProvider, error) {
	fmt.Printf("OpenTelemetry Metrics Endpoint: %s\n", metricsEndpoint)
	fmt.Printf("OpenTelemetry Metrics Protocol: %s\n", metricsProtocol)

	// Create resource with service information
	// resource.WithFromEnv() automatically handles OTEL_RESOURCE_ATTRIBUTES
	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(serviceName),
			semconv.ServiceVersion(serviceVersion),
			attribute.String("deployment.environment", environment),
		),
		resource.WithFromEnv(), // This automatically reads OTEL_RESOURCE_ATTRIBUTES
		resource.WithProcessPID(),
		resource.WithProcessExecutableName(),
		resource.WithProcessCommandArgs(),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create resource: %w", err)
	}

	// Try to create OTLP metric exporter, fall back to no-op if it fails
	var metricExporter sdkmetric.Exporter
	var meterProvider *sdkmetric.MeterProvider

	// Create OTLP metric exporter based on protocol
	if metricsProtocol == "grpc" {
		// For gRPC, we need to remove the http:// prefix and /v1/metrics path
		endpoint := metricsEndpoint
		endpoint = strings.TrimPrefix(endpoint, "http://")
		endpoint = strings.TrimPrefix(endpoint, "https://")
		endpoint = strings.TrimSuffix(endpoint, "/v1/metrics")

		fmt.Printf("Attempting gRPC connection to: %s\n", endpoint)
		metricExporter, err = otlpmetricgrpc.New(ctx,
			otlpmetricgrpc.WithEndpoint(endpoint),
			otlpmetricgrpc.WithInsecure(),
		)
		if err != nil {
			fmt.Printf("Failed to create gRPC OTLP exporter: %v\n", err)
			fmt.Println("Falling back to no-op meter provider")
			meterProvider = sdkmetric.NewMeterProvider(sdkmetric.WithResource(res))
		} else {
			fmt.Println("Using gRPC protocol for OTLP metrics export")
			meterProvider = sdkmetric.NewMeterProvider(
				sdkmetric.WithResource(res),
				sdkmetric.WithReader(sdkmetric.NewPeriodicReader(
					metricExporter,
					sdkmetric.WithInterval(5*time.Second),
				)),
			)
		}
	} else if metricsProtocol == "http/protobuf" {
		// For HTTP, remove /v1/metrics if present (the exporter adds it automatically)
		endpoint := metricsEndpoint
		endpoint = strings.TrimSuffix(endpoint, "/v1/metrics")

		fmt.Printf("Attempting HTTP connection to: %s\n", endpoint)
		metricExporter, err = otlpmetrichttp.New(ctx,
			otlpmetrichttp.WithEndpointURL(endpoint),
			otlpmetrichttp.WithInsecure(),
		)
		if err != nil {
			fmt.Printf("Failed to create HTTP OTLP exporter: %v\n", err)
			fmt.Println("Falling back to no-op meter provider")
			meterProvider = sdkmetric.NewMeterProvider(sdkmetric.WithResource(res))
		} else {
			fmt.Println("Using HTTP/Protobuf protocol for OTLP metrics export")
			meterProvider = sdkmetric.NewMeterProvider(
				sdkmetric.WithResource(res),
				sdkmetric.WithReader(sdkmetric.NewPeriodicReader(
					metricExporter,
					sdkmetric.WithInterval(5*time.Second),
				)),
			)
		}
	} else {
		fmt.Printf("Unsupported OTLP metrics protocol: %s, using no-op provider\n", metricsProtocol)
		meterProvider = sdkmetric.NewMeterProvider(sdkmetric.WithResource(res))
	}

	// Set global meter provider
	otel.SetMeterProvider(meterProvider)

	// Set global propagator
	otel.SetTextMapPropagator(propagation.TraceContext{})

	return meterProvider, nil
}

// initMetrics initializes custom metrics
func initMetrics() error {
	// Get tracer and meter instances
	tracer = otel.Tracer(serviceName, trace.WithInstrumentationVersion(serviceVersion))
	meter = otel.Meter(serviceName, metric.WithInstrumentationVersion(serviceVersion))

	var err error

	// Create custom metrics (same as nodejs-instrumented)
	httpRequestsTotal, err = meter.Int64Counter("http_requests_total",
		metric.WithDescription("Total number of HTTP requests"))
	if err != nil {
		return fmt.Errorf("failed to create http_requests_total counter: %w", err)
	}

	httpRequestDuration, err = meter.Float64Histogram("http_request_duration_ms",
		metric.WithDescription("Duration of HTTP requests in milliseconds"))
	if err != nil {
		return fmt.Errorf("failed to create http_request_duration_ms histogram: %w", err)
	}

	httpErrorsTotal, err = meter.Int64Counter("http_errors_total",
		metric.WithDescription("Total number of HTTP errors"))
	if err != nil {
		return fmt.Errorf("failed to create http_errors_total counter: %w", err)
	}

	cowsSoldTotal, err = meter.Int64Counter("cows_sold_total",
		metric.WithDescription("Total number of cows sold"))
	if err != nil {
		return fmt.Errorf("failed to create cows_sold_total counter: %w", err)
	}

	return nil
}

// setupLogger initializes the logger
func setupLogger() {
	logger = logrus.New()
	logger.SetLevel(logrus.DebugLevel)
	logger.SetFormatter(&logrus.TextFormatter{
		TimestampFormat: time.RFC3339,
		FullTimestamp:   true,
	})
}

// metricsMiddleware tracks request metrics
func metricsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		startTime := time.Now()

		// Wrap response writer to capture status code
		wrappedWriter := &responseWriter{ResponseWriter: w, statusCode: 200}

		// Call next handler
		next.ServeHTTP(wrappedWriter, r)

		// Calculate duration and record metrics
		duration := float64(time.Since(startTime).Nanoseconds()) / 1e6 // Convert to milliseconds

		labels := []attribute.KeyValue{
			attribute.String("method", r.Method),
			attribute.String("route", r.URL.Path),
			attribute.String("status_code", strconv.Itoa(wrappedWriter.statusCode)),
		}

		// Record metrics
		httpRequestsTotal.Add(r.Context(), 1, metric.WithAttributes(labels...))
		httpRequestDuration.Record(r.Context(), duration, metric.WithAttributes(labels...))

		// Record cows sold metric (same as nodejs-instrumented)
		cowsSoldTotal.Add(r.Context(), 1, metric.WithAttributes(
			attribute.String("cow_type", "Holstein"),
			attribute.String("endpoint", metricsEndpoint),
			attribute.String("protocol", metricsProtocol),
		))

		// Record error metrics for 4xx and 5xx status codes
		if wrappedWriter.statusCode >= 400 {
			httpErrorsTotal.Add(r.Context(), 1, metric.WithAttributes(labels...))
		}
	})
}

// responseWriter wraps http.ResponseWriter to capture status code
type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}

// HTTP handlers (same endpoints as nodejs-instrumented)

func rootHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	span := trace.SpanFromContext(ctx)

	// Add custom span attributes
	span.SetAttributes(
		attribute.String("http.user_agent", r.Header.Get("User-Agent")),
		attribute.String("http.remote_addr", r.RemoteAddr),
		attribute.String("custom.endpoint", r.URL.Path),
	)

	logger.WithFields(logrus.Fields{
		"trace_id": span.SpanContext().TraceID().String(),
		"span_id":  span.SpanContext().SpanID().String(),
	}).Info("Go instrumented application is running!")

	response := map[string]interface{}{
		"message":   "Go instrumented application is running!",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
		"service":   serviceName,
		"version":   serviceVersion,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	response := map[string]interface{}{
		"status":    "healthy",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func metricsHandler(w http.ResponseWriter, r *http.Request) {
	response := map[string]interface{}{
		"message": "Metrics endpoint - integrate with Prometheus exporter as needed",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func callTargetHandler(w http.ResponseWriter, r *http.Request) {
	// Simulate random errors like nodejs-instrumented
	if rand.Float64() < 0.4 {
		http.Error(w, `{"error": "An unexpected error occurred"}`, http.StatusInternalServerError)
		return
	}

	if targetURL == "" {
		http.Error(w, `{"error": "TARGET_URL environment variable not set"}`, http.StatusInternalServerError)
		return
	}

	// Create HTTP client with OpenTelemetry instrumentation
	client := &http.Client{
		Transport: otelhttp.NewTransport(http.DefaultTransport),
		Timeout:   30 * time.Second,
	}

	resp, err := client.Get(targetURL)
	if err != nil {
		logger.WithError(err).Errorf("Failed to reach target URL: %s", targetURL)
		errorResponse := map[string]interface{}{
			"error": fmt.Sprintf("Failed to reach %s: %s", targetURL, err.Error()),
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(errorResponse)
		return
	}
	defer resp.Body.Close()

	logger.WithFields(logrus.Fields{
		"target_url":  targetURL,
		"status_code": resp.StatusCode,
	}).Info("Successfully called target URL")

	response := map[string]interface{}{
		"target_url": targetURL,
		"status":     resp.StatusCode,
		"timestamp":  time.Now().UTC().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(resp.StatusCode)
	json.NewEncoder(w).Encode(response)
}

func generateLoadHandler(w http.ResponseWriter, r *http.Request) {
	// Get iterations parameter
	iterationsStr := r.URL.Query().Get("iterations")
	iterations := 10
	if iterationsStr != "" {
		if parsed, err := strconv.Atoi(iterationsStr); err == nil {
			iterations = parsed
		}
	}

	logger.WithFields(logrus.Fields{
		"iterations": iterations,
		"target_url": targetURL,
	}).Info("Starting load generation")

	startTime := time.Now()
	results := make([]map[string]interface{}, 0, iterations)

	// Create HTTP client with OpenTelemetry instrumentation
	client := &http.Client{
		Transport: otelhttp.NewTransport(http.DefaultTransport),
		Timeout:   30 * time.Second,
	}

	for i := 0; i < iterations; i++ {
		iterationStart := time.Now()

		resp, err := client.Get(targetURL)
		if err != nil {
			logger.WithError(err).Errorf("Error in iteration %d", i+1)
			results = append(results, map[string]interface{}{
				"iteration": i + 1,
				"error":     err.Error(),
				"success":   false,
			})
		} else {
			resp.Body.Close()
			iterationDuration := time.Since(iterationStart).Milliseconds()

			results = append(results, map[string]interface{}{
				"iteration":   i + 1,
				"status_code": resp.StatusCode,
				"duration_ms": iterationDuration,
				"success":     resp.StatusCode >= 200 && resp.StatusCode < 400,
			})
		}

		// Add delay between requests
		time.Sleep(100 * time.Millisecond)
	}

	totalDuration := time.Since(startTime).Milliseconds()

	response := map[string]interface{}{
		"message":           fmt.Sprintf("Load generation completed with %d iterations", iterations),
		"total_duration_ms": totalDuration,
		"target_url":        targetURL,
		"results":           results,
		"timestamp":         time.Now().UTC().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func main() {
	setupLogger()

	ctx := context.Background()

	// Initialize OpenTelemetry
	meterProvider, err := initOpenTelemetry(ctx)
	if err != nil {
		log.Fatalf("Failed to initialize OpenTelemetry: %v", err)
	}
	defer func() {
		if err := meterProvider.Shutdown(ctx); err != nil {
			logger.WithError(err).Error("Error shutting down meter provider")
		}
	}()

	// Initialize metrics
	if err := initMetrics(); err != nil {
		log.Fatalf("Failed to initialize metrics: %v", err)
	}

	logger.Info("OpenTelemetry instrumentation initialized successfully")

	// Setup router
	router := mux.NewRouter()

	// Apply metrics middleware and OpenTelemetry HTTP instrumentation
	router.Use(metricsMiddleware)
	router.Use(func(next http.Handler) http.Handler {
		return otelhttp.NewHandler(next, "go-instrumented-test-app")
	})

	// Register routes
	router.HandleFunc("/", rootHandler).Methods("GET")
	router.HandleFunc("/health", healthHandler).Methods("GET")
	router.HandleFunc("/metrics", metricsHandler).Methods("GET")
	router.HandleFunc("/call-target", callTargetHandler).Methods("GET")
	router.HandleFunc("/generate-load", generateLoadHandler).Methods("GET")

	// Setup HTTP server
	server := &http.Server{
		Addr:    ":" + port,
		Handler: router,
	}

	// Handle graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		logger.Infof("Server starting on port %s", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	<-quit
	logger.Info("Server shutting down...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	logger.Info("Server exited")
}
