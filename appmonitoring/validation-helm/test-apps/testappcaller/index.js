const axios = require('axios');

const TARGETS = [
  {
    name: 'testapp-java',
    host: process.env.TARGET_JAVA_HOST || 'java-test-app-service.test-ns.svc.cluster.local',
    port: process.env.TARGET_JAVA_PORT || 8080,
    path: process.env.TARGET_JAVA_PATH || '/call-target',
  },
  {
    name: 'testapp-nodejs',
    host: process.env.TARGET_NODEJS_HOST || 'nodejs-test-app-service.test-ns.svc.cluster.local',
    port: process.env.TARGET_NODEJS_PORT || 3001,
    path: process.env.TARGET_NODEJS_PATH || '/call-target',
  },
  {
    name: 'testapp-python',
    host: process.env.TARGET_PYTHON_HOST || 'python-test-app-service.test-ns.svc.cluster.local',
    port: process.env.TARGET_PYTHON_PORT || 3001,
    path: process.env.TARGET_PYTHON_PATH || '/call-target',
  },
  {
    name: 'testapp-dotnet',
    host: process.env.TARGET_DOTNET_HOST || 'dotnet-test-app-service.test-ns.svc.cluster.local',
    port: process.env.TARGET_DOTNET_PORT || 3001,
    path: process.env.TARGET_DOTNET_PATH || '/call-target',
  }
];

const INTERVAL_MS = process.env.INTERVAL_MS || 5000;
const RUN_DURATION_MS = 2 * 60 * 60 * 1000; // 2 hours

function getUrl(target) {
  return `http://${target.host}:${target.port}${target.path}`;
}

async function callTarget(target) {
  const url = getUrl(target);
  try {
    const res = await axios.get(url);
    console.log(`[${new Date().toISOString()}] [${target.name}] Success:`, res.status, res.data);
  } catch (err) {
    console.error(`[${new Date().toISOString()}] [${target.name}] Error:`, err.message);
  }
}

console.log(`Starting periodic calls to:`);
TARGETS.forEach(t => console.log(`- ${t.name}: ${getUrl(t)} every ${INTERVAL_MS}ms`));

const intervalId = setInterval(() => {
  TARGETS.forEach(callTarget);
}, INTERVAL_MS);

setTimeout(() => {
  clearInterval(intervalId);
  console.log('2 hours elapsed. Exiting.');
  process.exit(0);
}, RUN_DURATION_MS);

// Keep the process alive
setInterval(() => {}, 1000);