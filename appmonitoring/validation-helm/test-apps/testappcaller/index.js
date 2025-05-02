const axios = require('axios');
const http = require('http');

const TARGET_HOST = process.env.TARGET_HOST || 'test-app-nodejs-service.test-ns.svc.cluster.local';
const TARGET_PORT = process.env.TARGET_PORT || 8080;
const INTERVAL_MS = process.env.INTERVAL_MS || 5000;
const SERVER_PORT = process.env.SERVER_PORT || 3000;

const url = `http://${TARGET_HOST}:${TARGET_PORT}/`;

async function callTarget() {
  try {
    const res = await axios.get(url);
    console.log(`[${new Date().toISOString()}] Success:`, res.status, res.data);
  } catch (err) {
    console.error(`[${new Date().toISOString()}] Error:`, err.message);
  }
}

// Start a simple HTTP server to keep the pod running
http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('Caller app is running\n');
}).listen(SERVER_PORT, () => {
  console.log(`Server listening on port ${SERVER_PORT}`);
  console.log(`Starting periodic calls to ${url} every ${INTERVAL_MS}ms`);
  setInterval(callTarget, INTERVAL_MS);
});