// Simple Node.js test server
const express = require('express');
const axios = require('axios');
const winston = require('winston');

const app = express();
const PORT = process.env.PORT || 3001;
const TARGET_URL = process.env.TARGET_URL || 'http://localhost:3001/'; // Change as needed

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
  // Occasionally throw an error (20% chance)
  if (Math.random() < 0.4) {
    logger.error('Simulated error at /call-target');
    throw new Error('Simulated random error at /call-target');
  }
  try {
    const response = await axios.get(TARGET_URL);
    logger.info(`Successfully called target: ${TARGET_URL}`);
    res.json({ message: 'Success', data: response.data });
  } catch (error) {
    logger.error(`Error calling target: ${error.message}`);
    res.status(500).json({ message: 'Error calling target', error: error.message });
  }
});

app.get('/', (req, res) => {
  logger.info('Root endpoint hit');
  res.send('Node.js test server is running.');
});

app.listen(PORT, () => {
  logger.info(`Server listening on port ${PORT}`);
});
