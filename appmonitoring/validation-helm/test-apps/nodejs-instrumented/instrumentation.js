// instrumentation.js - OpenTelemetry instrumentation setup
const { diag, DiagConsoleLogger, DiagLogLevel } = require('@opentelemetry/api');
diag.setLogger(new DiagConsoleLogger(), DiagLogLevel.DEBUG);


// Set environment variables programmatically only if not already set
if (!process.env.OTEL_SERVICE_NAME) {
  process.env.OTEL_SERVICE_NAME = 'nodejs-instrumented-test-app';
}
if (!process.env.OTEL_SERVICE_VERSION) {
  process.env.OTEL_SERVICE_VERSION = '1.0.0';
}
if (!process.env.OTEL_ENVIRONMENT) {
  process.env.OTEL_ENVIRONMENT = 'development';
}

process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT || "http://localhost:4318/v1/traces";
process.env.OTEL_EXPORTER_OTLP_TRACES_PROTOCOL = process.env.OTEL_EXPORTER_OTLP_TRACES_PROTOCOL || "http/protobuf" // http/protobuf, grpc
process.env.OTEL_EXPORTER_OTLP_TRACES_INSECURE = process.env.OTEL_EXPORTER_OTLP_TRACES_INSECURE || "true";

process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT || "http://localhost:56682/v1/logs";
process.env.OTEL_EXPORTER_OTLP_LOGS_PROTOCOL = process.env.OTEL_EXPORTER_OTLP_LOGS_PROTOCOL || "http/protobuf" // http/protobuf, grpc
process.env.OTEL_EXPORTER_OTLP_LOGS_INSECURE = process.env.OTEL_EXPORTER_OTLP_LOGS_INSECURE || "true";

process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT || "http://localhost:56682/v1/metrics";
process.env.OTEL_EXPORTER_OTLP_METRICS_PROTOCOL = process.env.OTEL_EXPORTER_OTLP_METRICS_PROTOCOL || "http/protobuf" // http/protobuf, grpc
process.env.OTEL_EXPORTER_OTLP_METRICS_INSECURE = process.env.OTEL_EXPORTER_OTLP_METRICS_INSECURE || "true";


const { NodeSDK } = require('@opentelemetry/sdk-node');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { LoggerProvider, BatchLogRecordProcessor } = require('@opentelemetry/sdk-logs');

// Create OTLP trace exporter based on protocol
let traceExporter;

if(process.env.OTEL_EXPORTER_OTLP_TRACES_PROTOCOL === "http/protobuf") {
  const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-proto');
  traceExporter = new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT,
    headers: {}
  });
  console.log(`Using OTLPTraceExporter with protobuf format: ${process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT}`);
} else if(process.env.OTEL_EXPORTER_OTLP_TRACES_PROTOCOL === "grpc") {
  const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
  traceExporter = new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT
  });
  console.log(`Using OTLPTraceExporter with gRPC format: ${process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT}`);
} else {
  console.error('Unsupported OTLP traces protocol:', process.env.OTEL_EXPORTER_OTLP_TRACES_PROTOCOL);
  process.exit(1);
}

// Create OTLP log exporter based on protocol
let logExporter;

if(process.env.OTEL_EXPORTER_OTLP_LOGS_PROTOCOL === "http/protobuf") {
  const { OTLPLogExporter } = require('@opentelemetry/exporter-logs-otlp-proto');
  logExporter = new OTLPLogExporter({
    url: process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT,
    headers: {}
  });

  console.log(`Using OTLPLogExporter with protobuf format: ${process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT}`);
} else if(process.env.OTEL_EXPORTER_OTLP_LOGS_PROTOCOL === "grpc") {
  const { OTLPLogExporter } = require('@opentelemetry/exporter-logs-otlp-grpc');
  logExporter = new OTLPLogExporter({
    url: process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT
  });
  console.log(`Using OTLPLogExporter with gRPC format: ${process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT}`);
} else {
  console.error('Unsupported OTLP logs protocol:', process.env.OTEL_EXPORTER_OTLP_LOGS_PROTOCOL);
  process.exit(1);
}

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
  traceExporter,
  metricReader
});

// Start the SDK
sdk.start();

console.log('OpenTelemetry instrumentation initialized successfully');

// Log the resource attributes for debugging after SDK starts
let loggerOtel;
setTimeout(() => {
  const resource = sdk['_resource']; // Access the SDK's internal resource
  if (resource) {
    console.log('Resource attributes being used:', JSON.stringify(resource.attributes, null, 2));
  }

  const loggerProvider = new LoggerProvider({ 
    resource,
    logRecordProcessors: [new BatchLogRecordProcessor(logExporter)]
  });
  const loggerName = "nodejs-instrumented-1";
  const loggerVersion = "1.0.0";
  loggerOtel = loggerProvider.getLogger(loggerName, loggerVersion);
}, 500);

if (process.env.OTEL_RESOURCE_ATTRIBUTES) {
  console.log('OTEL_RESOURCE_ATTRIBUTES environment variable detected:', process.env.OTEL_RESOURCE_ATTRIBUTES);
} else {
  console.log('OTEL_RESOURCE_ATTRIBUTES environment variable not set');
}

// Graceful shutdown
process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('OpenTelemetry terminated'))
    .catch((error) => console.log('Error terminating OpenTelemetry', error))
    .finally(() => process.exit(0));
});

module.exports = { sdk, loggerOtel };
