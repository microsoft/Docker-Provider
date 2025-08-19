// instrumentation.js - OpenTelemetry instrumentation setup
const { diag, DiagConsoleLogger, DiagLogLevel } = require('@opentelemetry/api');
diag.setLogger(new DiagConsoleLogger(), DiagLogLevel.DEBUG);


// Set environment variables programmatically
process.env.OTEL_SERVICE_NAME = 'nodejs-instrumented-test-app';
process.env.OTEL_SERVICE_VERSION = '1.0.0';
process.env.OTEL_ENVIRONMENT = 'development';
//process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = 'http://localhost:4318/v1/traces';

process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT || "http://localhost:56682/v1/metrics";
process.env.OTEL_EXPORTER_OTLP_METRICS_PROTOCOL = process.env.OTEL_EXPORTER_OTLP_METRICS_PROTOCOL || "http/protobuf" // http/protobuf, grpc
process.env.OTEL_EXPORTER_OTLP_METRICS_INSECURE = process.env.OTEL_EXPORTER_OTLP_METRICS_INSECURE || "true";

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');

// Create OTLP metric exporter based on protocol
let metricExporter;

if(process.env.OTEL_EXPORTER_OTLP_METRICS_PROTOCOL === "http/protobuf") {
  const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-proto');
  metricExporter = new OTLPMetricExporter({
    url: process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT,
    headers: {}
  });
  console.log(`Using OTLPMetricExporter with protobuf format: ${process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT}`);
} else if(process.env.OTEL_EXPORTER_OTLP_METRICS_PROTOCOL === "grpc") {
  const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-grpc');
  metricExporter = new OTLPMetricExporter({
    url: process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT
  });
  console.log(`Using OTLPMetricExporter with gRPC format: ${process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT}`);
} else {
  console.error('Unsupported OTLP metrics protocol:', process.env.OTEL_EXPORTER_OTLP_METRICS_PROTOCOL);
  process.exit(1);
}

// Create a metric reader
 const metricReader = new PeriodicExportingMetricReader({
   exporter: metricExporter,
   exportIntervalMillis: 5000, // Export metrics every 5 seconds
 });

 // Initialize the SDK with resource information and instrumentations
const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'nodejs-instrumented-test-app',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.OTEL_SERVICE_VERSION || '1.0.0',
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.OTEL_ENVIRONMENT || 'development',
  }),
  metricReader,
});

// Start the SDK
sdk.start();

console.log('OpenTelemetry instrumentation initialized successfully');

// Graceful shutdown
process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('OpenTelemetry terminated'))
    .catch((error) => console.log('Error terminating OpenTelemetry', error))
    .finally(() => process.exit(0));
});

module.exports = sdk;
