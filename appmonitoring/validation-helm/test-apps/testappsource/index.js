const http = require('http');

const SERVICE_HOST = process.env.TARGET_SERVICE_HOST || 'test-app-nodejs-service';
const SERVICE_PORT = process.env.TARGET_SERVICE_PORT || 8080;
const INTERVAL_MS = process.env.CALL_INTERVAL_MS || 10000;

function callService() {
  const options = {
    hostname: SERVICE_HOST,
    port: SERVICE_PORT,
    path: '/',
    method: 'GET',
    timeout: 5000,
  };

  const req = http.request(options, (res) => {
    let data = '';
    res.on('data', (chunk) => { data += chunk; });
    res.on('end', () => {
      console.log(`[${new Date().toISOString()}] Service response:`, data);
    });
  });

  req.on('error', (e) => {
    console.error(`[${new Date().toISOString()}] Error calling service:`, e.message);
  });

  req.end();
}

console.log('Node.js periodic service caller started.');
setInterval(callService, INTERVAL_MS);