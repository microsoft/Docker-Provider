// Simple Node.js test server
const express = require('express');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3000;
const TARGET_URL = process.env.TARGET_URL || 'http://localhost:8080/'; // Change as needed

// Endpoint that calls another app's endpoint
app.get('/call-other', async (req, res) => {
  try {
    const response = await axios.get(TARGET_URL);
    res.json({ message: 'Success', data: response.data });
  } catch (error) {
    res.status(500).json({ message: 'Error calling target', error: error.message });
  }
});

app.get('/', (req, res) => {
  res.send('Node.js test server is running.');
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
