package main

import (
	"context"
	"encoding/json"
	"fmt"
	stdlog "log"
	"math/rand"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploghttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/log"
	"go.opentelemetry.io/otel/log/global"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/propagation"
	sdklog "go.opentelemetry.io/otel/sdk/log"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"

	"github.com/gorilla/mux"
)

var (
	// OpenTelemetry instruments
	tracer trace.Tracer
	meter  metric.Meter
	logger log.Logger

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
)

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// initOpenTelemetry initializes OpenTelemetry with OTLP exporters
// The SDK automatically reads OTEL_EXPORTER_OTLP_* environment variables
func initOpenTelemetry(ctx context.Context) (*sdkmetric.MeterProvider, *sdktrace.TracerProvider, *sdklog.LoggerProvider, error) {
	// Create resource with service information
	// resource.WithFromEnv() automatically handles OTEL_RESOURCE_ATTRIBUTES
	res, err := resource.New(ctx,
		resource.WithFromEnv(), // This automatically reads OTEL_RESOURCE_ATTRIBUTES
		resource.WithProcessPID(),
		resource.WithProcessExecutableName(),
		resource.WithProcessCommandArgs(),
	)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("failed to create resource: %w", err)
	}

	// Initialize Trace Provider with HTTP exporter (SDK reads OTEL_EXPORTER_OTLP_TRACES_* env vars)
	traceExporter, err := otlptracehttp.New(ctx)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("failed to create OTLP trace exporter: %w", err)
	}

	traceProvider := sdktrace.NewTracerProvider(
		sdktrace.WithResource(res),
		sdktrace.WithBatcher(traceExporter),
	)

	// Set global trace provider
	otel.SetTracerProvider(traceProvider)

	// Initialize Metric Provider with HTTP exporter (SDK reads OTEL_EXPORTER_OTLP_METRICS_* env vars)
	metricExporter, err := otlpmetrichttp.New(ctx)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("failed to create OTLP metric exporter: %w", err)
	}

	meterProvider := sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(res),
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(
			metricExporter,
			sdkmetric.WithInterval(5*time.Second),
		)),
	)

	// Set global meter provider
	otel.SetMeterProvider(meterProvider)

	// Set global propagator
	otel.SetTextMapPropagator(propagation.TraceContext{})

	// Initialize Log Provider with HTTP exporter (SDK reads OTEL_EXPORTER_OTLP_LOGS_* env vars)
	logExporter, err := otlploghttp.New(ctx)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("failed to create OTLP log exporter: %w", err)
	}

	processor := sdklog.NewBatchProcessor(logExporter)
	logProvider := sdklog.NewLoggerProvider(
		sdklog.WithProcessor(processor),
		sdklog.WithResource(res),
	)

	// Set global logger provider
	global.SetLoggerProvider(logProvider)

	fmt.Println("OpenTelemetry initialized successfully with OTLP exporters")
	return meterProvider, traceProvider, logProvider, nil
}

// initMetrics initializes custom metrics and logger
func initMetrics() error {
	// Get tracer, meter, and logger instances
	tracer = otel.Tracer(serviceName, trace.WithInstrumentationVersion(serviceVersion))
	meter = otel.Meter(serviceName, metric.WithInstrumentationVersion(serviceVersion))
	logger = global.GetLoggerProvider().Logger(serviceName, log.WithInstrumentationVersion(serviceVersion))

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
		))

		// Create a custom span for cow sold tracking
		ctx := r.Context()
		_, callSpan := tracer.Start(ctx, "cow-sold-once")
		defer callSpan.End()
		// Add custom attributes
		callSpan.SetAttributes(
			attribute.String("cow_type", "Holstein"),
		)

		record := log.Record{}
		record.SetSeverity(log.SeverityError)
		record.SetBody(log.StringValue("cow-sold-once-log"))
		record.AddAttributes(
			log.String("cow_type", "Holstein"),
		)
		logger.Emit(ctx, record)

		stdlog.Printf("Logs emitted")

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

	// Log incoming request
	record := log.Record{}
	record.SetSeverity(log.SeverityInfo)
	record.SetBody(log.StringValue("Root endpoint accessed"))
	record.AddAttributes(
		log.String("method", r.Method),
		log.String("path", r.URL.Path),
		log.String("user_agent", r.Header.Get("User-Agent")),
		log.String("remote_addr", r.RemoteAddr),
	)
	logger.Emit(ctx, record)

	// Add custom span attributes
	span.SetAttributes(
		attribute.String("http.user_agent", r.Header.Get("User-Agent")),
		attribute.String("http.remote_addr", r.RemoteAddr),
		attribute.String("custom.endpoint", r.URL.Path),
	)

	response := map[string]interface{}{
		"message":   "Go instrumented application is running!",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
		"service":   serviceName,
		"version":   serviceVersion,
		"trace_id":  span.SpanContext().TraceID().String(),
		"span_id":   span.SpanContext().SpanID().String(),
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
	ctx := r.Context()
	span := trace.SpanFromContext(ctx)

	// Create a custom span for this operation
	_, callSpan := tracer.Start(ctx, "call-target-operation")
	defer callSpan.End()

	// Add custom attributes
	callSpan.SetAttributes(
		attribute.String("target.url", targetURL),
		attribute.String("operation", "call-target"),
	)

	// Simulate random errors like nodejs-instrumented
	if rand.Float64() < 0.4 {
		callSpan.SetAttributes(attribute.Bool("error", true))
		callSpan.RecordError(fmt.Errorf("simulated random error"))

		// Log the error using OpenTelemetry
		errorRecord := log.Record{}
		errorRecord.SetSeverity(log.SeverityError)
		errorRecord.SetBody(log.StringValue("Simulated random error occurred"))
		errorRecord.AddAttributes(
			log.String("operation", "call-target"),
			log.String("error.type", "random"),
		)
		logger.Emit(ctx, errorRecord)

		http.Error(w, `{"error": "An unexpected error occurred"}`, http.StatusInternalServerError)
		return
	}

	if targetURL == "" {
		callSpan.SetAttributes(attribute.Bool("error", true))
		callSpan.RecordError(fmt.Errorf("TARGET_URL environment variable not set"))

		// Log the configuration error
		configErrorRecord := log.Record{}
		configErrorRecord.SetSeverity(log.SeverityError)
		configErrorRecord.SetBody(log.StringValue("TARGET_URL environment variable not set"))
		configErrorRecord.AddAttributes(
			log.String("operation", "call-target"),
			log.String("error.type", "config"),
		)
		logger.Emit(ctx, configErrorRecord)

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
		callSpan.SetAttributes(attribute.Bool("error", true))
		callSpan.RecordError(err)
		errorResponse := map[string]interface{}{
			"error": fmt.Sprintf("Failed to reach %s: %s", targetURL, err.Error()),
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(errorResponse)
		return
	}
	defer resp.Body.Close()

	callSpan.SetAttributes(
		attribute.Int("http.response.status_code", resp.StatusCode),
		attribute.Bool("success", true),
	)

	// Log successful call
	successRecord := log.Record{}
	successRecord.SetSeverity(log.SeverityInfo)
	successRecord.SetBody(log.StringValue("Successfully called target URL"))
	successRecord.AddAttributes(
		log.String("operation", "call-target"),
		log.String("target.url", targetURL),
		log.Int("response.status_code", resp.StatusCode),
		log.String("trace_id", span.SpanContext().TraceID().String()),
	)
	logger.Emit(ctx, successRecord)

	response := map[string]interface{}{
		"target_url": targetURL,
		"status":     resp.StatusCode,
		"timestamp":  time.Now().UTC().Format(time.RFC3339),
		"trace_id":   span.SpanContext().TraceID().String(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(resp.StatusCode)
	json.NewEncoder(w).Encode(response)
}

func generateLoadHandler(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	span := trace.SpanFromContext(ctx)

	// Create a custom span for the entire load generation
	_, loadSpan := tracer.Start(ctx, "generate-load-operation")
	defer loadSpan.End()

	// Get iterations parameter
	iterationsStr := r.URL.Query().Get("iterations")
	iterations := 10
	if iterationsStr != "" {
		if parsed, err := strconv.Atoi(iterationsStr); err == nil {
			iterations = parsed
		}
	}

	loadSpan.SetAttributes(
		attribute.Int("load.iterations", iterations),
		attribute.String("target.url", targetURL),
	)

	startTime := time.Now()
	results := make([]map[string]interface{}, 0, iterations)

	// Create HTTP client with OpenTelemetry instrumentation
	client := &http.Client{
		Transport: otelhttp.NewTransport(http.DefaultTransport),
		Timeout:   30 * time.Second,
	}

	for i := 0; i < iterations; i++ {
		// Create a span for each iteration
		_, iterSpan := tracer.Start(ctx, fmt.Sprintf("load-iteration-%d", i+1))
		iterationStart := time.Now()

		resp, err := client.Get(targetURL)
		if err != nil {
			iterSpan.SetAttributes(
				attribute.Bool("error", true),
				attribute.Int("iteration", i+1),
			)
			iterSpan.RecordError(err)
			results = append(results, map[string]interface{}{
				"iteration": i + 1,
				"error":     err.Error(),
				"success":   false,
			})
		} else {
			resp.Body.Close()
			iterationDuration := time.Since(iterationStart).Milliseconds()

			iterSpan.SetAttributes(
				attribute.Int("iteration", i+1),
				attribute.Int("http.response.status_code", resp.StatusCode),
				attribute.Int64("duration_ms", iterationDuration),
				attribute.Bool("success", resp.StatusCode >= 200 && resp.StatusCode < 400),
			)

			results = append(results, map[string]interface{}{
				"iteration":   i + 1,
				"status_code": resp.StatusCode,
				"duration_ms": iterationDuration,
				"success":     resp.StatusCode >= 200 && resp.StatusCode < 400,
			})
		}

		iterSpan.End()

		// Add delay between requests
		time.Sleep(100 * time.Millisecond)
	}

	totalDuration := time.Since(startTime).Milliseconds()

	loadSpan.SetAttributes(
		attribute.Int64("total_duration_ms", totalDuration),
		attribute.Bool("load_generation_complete", true),
	)

	response := map[string]interface{}{
		"message":           fmt.Sprintf("Load generation completed with %d iterations", iterations),
		"total_duration_ms": totalDuration,
		"target_url":        targetURL,
		"results":           results,
		"timestamp":         time.Now().UTC().Format(time.RFC3339),
		"trace_id":          span.SpanContext().TraceID().String(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func main() {
	ctx := context.Background()

	// Initialize OpenTelemetry
	meterProvider, traceProvider, logProvider, err := initOpenTelemetry(ctx)
	if err != nil {
		stdlog.Fatalf("Failed to initialize OpenTelemetry: %v", err)
	}
	defer func() {
		if err := meterProvider.Shutdown(ctx); err != nil {
			stdlog.Printf("Error shutting down meter provider: %v", err)
		}
		if err := traceProvider.Shutdown(ctx); err != nil {
			stdlog.Printf("Error shutting down trace provider: %v", err)
		}
		if err := logProvider.Shutdown(ctx); err != nil {
			stdlog.Printf("Error shutting down log provider: %v", err)
		}
	}()

	// Initialize metrics
	if err := initMetrics(); err != nil {
		stdlog.Fatalf("Failed to initialize metrics: %v", err)
	}

	stdlog.Println("OpenTelemetry instrumentation initialized successfully")

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
		stdlog.Printf("Server starting on port %s", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			stdlog.Fatalf("Failed to start server: %v", err)
		}
	}()

	<-quit
	stdlog.Println("Server shutting down...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		stdlog.Fatalf("Server forced to shutdown: %v", err)
	}

	stdlog.Println("Server exited")
}
