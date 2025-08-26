// Import instrumentation first - this must be at the top
require('./instrumentation');

// OpenTelemetry API imports
const { trace, metrics, context, SpanStatusCode } = require('@opentelemetry/api');
const express = require('express');
const axios = require('axios');
const winston = require('winston');

const app = express();
const PORT = process.env.PORT || 3001;
const TARGET_URL = process.env.TARGET_URL || 'http://localhost:3001/';

// Get tracer and meter instances
const tracer = trace.getTracer('nodejs-instrumented-test-app', '1.0.0');
const meter = metrics.getMeter('nodejs-instrumented-test-app', '1.0.0');

// Create custom metrics
const requestCounter = meter.createCounter('http_requests_total', {
  description: 'Total number of HTTP requests',
});

const requestDuration = meter.createHistogram('http_request_duration_ms', {
  description: 'Duration of HTTP requests in milliseconds',
});

const errorCounter = meter.createCounter('http_errors_total', {
  description: 'Total number of HTTP errors',
});

const cowsSoldCounter = meter.createCounter('cows_sold_total', {
  description: 'Total number of cows sold',
});

// Winston logger setup with correlation IDs
const logger = winston.createLogger({
  level: 'debug',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.printf(({ timestamp, level, message }) => {
      const span = trace.getActiveSpan();
      const traceId = span?.spanContext().traceId || 'no-trace';
      const spanId = span?.spanContext().spanId || 'no-span';
      return `[${timestamp}] ${level.toUpperCase()}: [trace_id=${traceId}] [span_id=${spanId}] ${message}`;
    })
  ),
  transports: [new winston.transports.Console()]
});

// Middleware to add custom attributes to spans
app.use((req, res, next) => {
  const span = trace.getActiveSpan();
  if (span) {
    span.setAttributes({
      'http.user_agent': req.get('User-Agent') || 'unknown',
      'http.remote_addr': req.ip,
      'custom.endpoint': req.path,
    });
  }
  next();
});

// Middleware to track request metrics
app.use((req, res, next) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    const labels = {
      method: req.method,
      route: req.route?.path || req.path,
      status_code: res.statusCode.toString(),
    };
    
    cowsSoldCounter.add(1, { cow_type: 'Holstein', endpoint: process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT, protocol: process.env.OTEL_EXPORTER_OTLP_METRICS_PROTOCOL });
    requestCounter.add(1, labels);
    requestDuration.record(duration, labels);
    
    if (res.statusCode >= 400) {
      errorCounter.add(1, labels);
    }
  });
  
  next();
});

// Health check endpoint (not traced to reduce noise)
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Metrics endpoint for Prometheus scraping
app.get('/metrics', async (req, res) => {
  // This could be enhanced to return actual Prometheus formatted metrics
  res.json({ message: 'Metrics endpoint - integrate with Prometheus exporter as needed' });
});

// Root endpoint
app.get('/', (req, res) => {
  const span = trace.getActiveSpan();
  
  // Add custom span attributes
  if (span) {
    span.addEvent('Processing root request');
    span.setAttributes({
      'custom.operation': 'root_endpoint',
      'custom.user_type': 'test_user',
    });
  }
  
  logger.info('Root endpoint hit');
  res.json({ 
    message: 'Node.js instrumented test server is running',
    traceId: span?.spanContext().traceId || 'no-trace',
    timestamp: new Date().toISOString()
  });
});

// Endpoint that calls another service
app.get('/call-target', async (req, res) => {
  // Create a custom span for this operation
  const span = tracer.startSpan('call-target-operation');
  
  try {
    // Set span attributes
    span.setAttributes({
      'custom.operation': 'external_call',
      'custom.target_url': TARGET_URL,
      'custom.retry_count': 1,
    });
    
    // Simulate some processing time
    await new Promise(resolve => setTimeout(resolve, Math.random() * 100));
    
    // Occasionally throw an error (30% chance)
    if (Math.random() < 0.3) {
      span.recordException(new Error('Simulated error at /call-target'));
      span.setStatus({ code: SpanStatusCode.ERROR, message: 'Simulated error' });
      
      logger.error('Simulated error at /call-target');
      
      // Create a separate span for the async error handling
      const errorSpan = tracer.startSpan('async-error-handler', { parent: span });
      setImmediate(() => {
        try {
          errorSpan.addEvent('Handling async error');
          throw new Error('Unhandled async error - server should continue');
        } catch (asyncError) {
          errorSpan.recordException(asyncError);
          errorSpan.setStatus({ code: SpanStatusCode.ERROR, message: 'Async error handled' });
          logger.error(`Async error handled: ${asyncError.message}`);
        } finally {
          errorSpan.end();
        }
      });
      
      res.status(500).json({ 
        message: 'Error triggered asynchronously',
        traceId: span.spanContext().traceId,
        timestamp: new Date().toISOString()
      });
      return;
    }
    
    // Add an event before making the external call
    span.addEvent('Making external HTTP request', {
      'http.url': TARGET_URL,
      'http.method': 'GET',
    });
    
    const response = await axios.get(TARGET_URL, {
      timeout: 5000,
      headers: {
        'User-Agent': 'nodejs-instrumented-test-app/1.0.0',
      }
    });
    
    // Add successful call event
    span.addEvent('External HTTP request completed', {
      'http.status_code': response.status,
      'response.size': JSON.stringify(response.data).length,
    });
    
    span.setStatus({ code: SpanStatusCode.OK });
    logger.info(`Successfully called target: ${TARGET_URL}`);
    
    res.json({ 
      message: 'Success', 
      data: response.data,
      traceId: span.spanContext().traceId,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    // Record the exception in the span
    span.recordException(error);
    span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
    
    logger.error(`Error calling target: ${error.message}`);
    res.status(500).json({ 
      message: 'Error calling target', 
      error: error.message,
      traceId: span.spanContext().traceId,
      timestamp: new Date().toISOString()
    });
  } finally {
    span.end();
  }
});

// Endpoint to generate load for testing
app.get('/generate-load', async (req, res) => {
  const span = tracer.startSpan('generate-load-operation');
  const iterations = parseInt(req.query.iterations) || 10;
  
  span.setAttributes({
    'custom.operation': 'load_generation',
    'custom.iterations': iterations,
  });
  
  try {
    const results = [];
    
    for (let i = 0; i < iterations; i++) {
      const childSpan = tracer.startSpan(`load-iteration-${i}`, { parent: span });
      
      try {
        // Simulate some work
        await new Promise(resolve => setTimeout(resolve, Math.random() * 50));
        
        childSpan.setAttributes({
          'custom.iteration': i,
          'custom.work_duration': Math.random() * 50,
        });
        
        results.push({ iteration: i, status: 'success' });
        childSpan.setStatus({ code: SpanStatusCode.OK });
      } catch (error) {
        childSpan.recordException(error);
        childSpan.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
        results.push({ iteration: i, status: 'error', error: error.message });
      } finally {
        childSpan.end();
      }
    }
    
    span.addEvent('Load generation completed', {
      'custom.total_iterations': iterations,
      'custom.successful_iterations': results.filter(r => r.status === 'success').length,
    });
    
    span.setStatus({ code: SpanStatusCode.OK });
    logger.info(`Load generation completed: ${iterations} iterations`);
    
    res.json({
      message: 'Load generation completed',
      iterations,
      results,
      traceId: span.spanContext().traceId,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    span.recordException(error);
    span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
    logger.error(`Error during load generation: ${error.message}`);
    res.status(500).json({
      message: 'Error during load generation',
      error: error.message,
      traceId: span.spanContext().traceId,
      timestamp: new Date().toISOString()
    });
  } finally {
    span.end();
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  const span = trace.getActiveSpan();
  if (span) {
    span.recordException(error);
    span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
  }
  
  logger.error(`Unhandled error: ${error.message}`);
  res.status(500).json({ 
    message: 'Internal server error',
    traceId: span?.spanContext().traceId || 'no-trace',
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, () => {
  logger.info(`OpenTelemetry instrumented server listening on port ${PORT}`);
  logger.info(`Service: ${process.env.OTEL_SERVICE_NAME || 'nodejs-instrumented-test-app'}`);
  logger.info(`Environment: ${process.env.OTEL_ENVIRONMENT || 'development'}`);
  logger.info(`OTEL_EXPORTER_OTLP_TRACES_ENDPOINT: ${process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT}`);
  logger.info(`OTEL_EXPORTER_OTLP_LOGS_ENDPOINT: ${process.env.OTEL_EXPORTER_OTLP_LOGS_ENDPOINT}`);
  logger.info(`OTEL_EXPORTER_OTLP_METRICS_ENDPOINT: ${process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT}`);
  logger.info(`OTEL_EXPORTER_OTLP_METRICS_PROTOCOL: ${process.env.OTEL_EXPORTER_OTLP_METRICS_PROTOCOL}`);
  logger.info(`OTEL_EXPORTER_OTLP_METRICS_INSECURE: ${process.env.OTEL_EXPORTER_OTLP_METRICS_INSECURE}`);
});
