#!/bin/bash
set -e

echo "==================================================================="
echo "Testkube Test Execution Script"
echo "==================================================================="

# Parse arguments
LINUX_IMAGE_TAG=""
WINDOWS_IMAGE_TAG=""

for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)
   VALUE=$(echo $ARGUMENT | cut -f2 -d=)

   case "$KEY" in
           LinuxImageTag) LINUX_IMAGE_TAG=$VALUE ;;
           WindowsImageTag) WINDOWS_IMAGE_TAG=$VALUE ;;
           *)
    esac
done

echo "Configuration:"
echo "  Linux Image Tag: $LINUX_IMAGE_TAG"
echo "  Windows Image Tag: $WINDOWS_IMAGE_TAG"
echo ""

# Step 1: Install Testkube CLI
echo "==================================================================="
echo "Step 1: Installing Testkube CLI"
echo "==================================================================="
wget -qO - https://repo.testkube.io/key.pub | sudo apt-key add -
echo "deb https://repo.testkube.io/linux linux main" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get install -y testkube

echo "Testkube CLI installed:"
kubectl testkube version
echo ""

# Step 2: Install Testkube on cluster
echo "==================================================================="
echo "Step 2: Installing Testkube on cluster"
echo "==================================================================="
helm repo add kubeshop https://kubeshop.github.io/helm-charts
helm repo update
helm upgrade --install --create-namespace testkube kubeshop/testkube -n testkube

echo "Waiting for Testkube to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=api-server -n testkube --timeout=300s
echo "Testkube installed successfully"
echo ""

# Step 3: Create and run test
echo "==================================================================="
echo "Step 3: Creating and running basic container status test"
echo "==================================================================="

cat <<'EOF' | kubectl apply -f -
apiVersion: tests.testkube.io/v3
kind: Test
metadata:
  name: ama-logs-status-check
  namespace: testkube
spec:
  type: k6/script
  content:
    type: string
    data: |
      import http from 'k6/http';
      import { check } from 'k6';
      
      export default function () {
        console.log('Checking ama-logs pod status...');
        console.log('This is a placeholder test - replace with actual validation logic');
      }
  executionRequest:
    executePostRunScriptBeforeScraping: false
EOF

echo "Waiting for test to be created..."
sleep 10

echo "Running test..."
kubectl testkube run test ama-logs-status-check --verbose

# Get the execution ID
execution_id=$(kubectl testkube get executions --test ama-logs-status-check --limit 1 | grep ama-logs-status-check | awk '{print $1}')
echo "Execution ID: $execution_id"

# Watch the execution
echo "Watching test execution..."
kubectl testkube watch execution $execution_id || true

# Get test results
echo ""
echo "==================================================================="
echo "Test Results"
echo "==================================================================="
kubectl testkube get execution $execution_id

echo ""
echo "==================================================================="
echo "Testkube test execution completed!"
echo "==================================================================="
