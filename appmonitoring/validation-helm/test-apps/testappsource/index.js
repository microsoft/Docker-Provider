const http = require('http');

const PORT = process.env.PORT || 3001;
const MESSAGE = process.env.MESSAGE || 'Hello from testappsource Node.js app!';

const server = http.createServer((req, res) => {
  console.warn('source app called'); // Log warning
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end(MESSAGE);
});

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
