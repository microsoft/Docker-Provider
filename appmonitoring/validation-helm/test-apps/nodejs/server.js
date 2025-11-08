// Simple Node.js test server
const express = require('express');
const axios = require('axios');
const winston = require('winston');
const  { metrics, trace, SpanStatusCode } = require('@opentelemetry/api');

const app = express();
const PORT = process.env.PORT || 3001;
const TARGET_URL = process.env.TARGET_URL || 'https://bing.com'; // Change as needed

const meter = metrics.getMeter('nodejs-test-app', '1.0.0');

const cowsSoldCounter = meter.createCounter('cows_sold_total', {
  description: 'Total number of cows sold',
});

// Winston logger setup
const logger = winston.createLogger({
  level: 'debug',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.printf(({ timestamp, level, message }) => {
      return `[${timestamp}] ${level.toUpperCase()}: ${message}`;
    })
  ),
  transports: [new winston.transports.Console()]
});

// Endpoint that calls another app's endpoint
app.get('/call-target', async (req, res) => {
  try {
    cowsSoldCounter.add(1, { cow_type: 'Holstein', endpoint: process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT, protocol: process.env.OTEL_EXPORTER_OTLP_METRICS_PROTOCOL });
  
    // Occasionally simulate an error (40% chance)
    if (Math.random() < 0.4) {
      const error = new Error('Simulated error - this will be recorded in OTel but not crash the app');
      logger.error(`Simulated error at /call-target: ${error.message}`);
      
      // Get the current active span (auto-created by OTel instrumentation) and record the error
      const span = trace.getActiveSpan();
      if (span) {
        span.recordException(error);
        span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
      }
      
      // Respond to the client
      res.status(500).json({ message: 'Error triggered', error: error.message });
      return;
    }
    
    const response = await axios.get(TARGET_URL);
    logger.info(`Successfully called target: ${TARGET_URL}`);
    res.json({ message: 'Success', data: response.data });
  } catch (error) {
    logger.error(`Error calling target: ${error.message}`);
    
    // Record the exception in the active span
    const span = trace.getActiveSpan();
    if (span) {
      span.recordException(error);
      span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
    }
    
    res.status(500).json({ message: 'Error calling target', error: error.message });
  }
});

app.get('/', (req, res) => {
  logger.info('Root endpoint hit');

  cowsSoldCounter.add(1, { cow_type: 'Holstein', endpoint: process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT, protocol: process.env.OTEL_EXPORTER_OTLP_METRICS_PROTOCOL });
    
  res.send('Node.js test server is running.');
});

app.listen(PORT, () => {
  logger.info(`Server listening on port ${PORT}`);
});
