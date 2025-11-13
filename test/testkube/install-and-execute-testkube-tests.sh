#!/bin/bash

for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)
   VALUE=$(echo $ARGUMENT | cut -f2 -d=)

   case "$KEY" in
           AzureClientId) AzureClientId=$VALUE ;;
           AzureTenantId) AzureTenantId=$VALUE ;;
           TeamsWebhookUri) TeamsWebhookUri=$VALUE ;;
           LinuxTestsOnly) LinuxTestsOnly=$VALUE ;;
           GenevaIntegration) GenevaIntegration=$VALUE ;;
           *)
    esac
done

cluster="$(kubectl config current-context)"
echo "Current cluster: $cluster"

echo "Install testkube CLI"
wget -qO - https://repo.testkube.io/key.pub | sudo apt-key add -
echo "deb https://repo.testkube.io/linux linux main" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get install -y testkube

echo "Install testkube on the cluster"
helm repo add kubeshop https://kubeshop.github.io/helm-charts
helm repo update

echo "Installing testkube (this may take up to 10 minutes)..."
if ! helm upgrade --install --create-namespace testkube kubeshop/testkube \
  -n testkube \
  -f ./helm-testkube-values.yaml \
  --wait \
  --timeout 10m; then
  
  echo "❌ ERROR: Helm install failed!"
  echo ""
  echo "Helm release status:"
  helm status testkube -n testkube 2>&1 || echo "No release found"
  echo ""
  echo "Pods in testkube namespace:"
  kubectl get pods -n testkube -o wide 2>&1 || echo "No pods found"
  echo ""
  echo "Events in testkube namespace (last 20):"
  kubectl get events -n testkube --sort-by='.lastTimestamp' | tail -20 2>&1 || echo "No events found"
  echo ""
  echo "Describe failed pods (if any):"
  kubectl get pods -n testkube --field-selector=status.phase!=Running --field-selector=status.phase!=Succeeded -o name 2>/dev/null | while read pod; do
    echo "--- $pod ---"
    kubectl describe -n testkube $pod | tail -30
  done
  
  exit 1
fi

echo "✓ Testkube installed successfully"

echo "Install testkube CRIs"
export AZURE_CLIENT_ID=$AzureClientId
export AZURE_TENANT_ID=$AzureTenantId
export WEBHOOK_URI=$TeamsWebhookUri
export GENEVA_INTEGRATION=$GenevaIntegration
kubectl apply -f ./api-server-permissions.yaml
envsubst < ./testkube-test-crs.yaml > ./testkube-test-crs-updated.yaml
kubectl apply -f ./testkube-test-crs-updated.yaml

echo "Wait for testkube-api-server to be ready"

# Method 1: Use kubectl wait (preferred)
echo "Waiting for testkube-api-server pods to be ready..."
if kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=testkube-api-server \
  -n testkube \
  --timeout=300s; then
  echo "✓ Pods are ready"
else
  echo "⚠ kubectl wait timed out or failed, checking pod status..."
  kubectl get pods -n testkube -l app.kubernetes.io/name=testkube-api-server
  kubectl describe pod -l app.kubernetes.io/name=testkube-api-server -n testkube | tail -20
fi

# Method 2: Verify API endpoint is responding
echo "Verifying testkube API server endpoint..."
MAX_ATTEMPTS=30
ATTEMPT=0
API_READY=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  
  # Try to hit the health endpoint
  if kubectl run -n testkube api-health-check-$ATTEMPT \
    --image=curlimages/curl:latest \
    --rm -i --restart=Never \
    --command -- curl -f -s http://testkube-api-server:8088/health >/dev/null 2>&1; then
    echo "✓ Testkube API server is responding!"
    API_READY=true
    break
  fi
  
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: API server not ready yet, waiting 10s..."
  sleep 10
done

if [ "$API_READY" != "true" ]; then
  echo "❌ ERROR: Testkube API server did not become ready after $MAX_ATTEMPTS attempts"
  echo "Pod status:"
  kubectl get pods -n testkube
  echo "Service endpoints:"
  kubectl get endpoints testkube-api-server -n testkube
  echo "API server logs:"
  kubectl logs -n testkube -l app.kubernetes.io/name=testkube-api-server --tail=50
  exit 1
fi

echo "Run testkube tests"
execution_id=""
if [[ $LinuxTestsOnly == "true" ]]; then
    echo "Running Linux tests only"
    kubectl testkube run testsuite e2e-tests-linux --job-template ./custom-job-template.yaml --verbose
    execution_id=$(kubectl testkube get testsuiteexecutions --test-suite e2e-tests-linux --limit 1 | grep e2e-tests | awk '{print $1}')
else
    echo "Running all tests"
    kubectl testkube run testsuite e2e-tests-all --job-template ./custom-job-template.yaml --verbose
    execution_id=$(kubectl testkube get testsuiteexecutions --test-suite e2e-tests-all --limit 1 | grep e2e-tests | awk '{print $1}')
fi

# Watch until the all the tests in the test suite finish
kubectl testkube watch testsuiteexecution $execution_id

# Get the results as a formatted json file
kubectl testkube get testsuiteexecution $execution_id --output json > testkube-results.json

# For any test that has failed, print out the Ginkgo logs
if [[ $(jq -r '.status' testkube-results.json) == "failed" ]]; then

    # Get each test name and id that failed
    jq -r '.executeStepResults[].execute[] | select(.execution.executionResult.status=="failed") | "\(.execution.testName) \(.execution.id)"' testkube-results.json | while read line; do
    testName=$(echo $line | cut -d ' ' -f 1)
    id=$(echo $line | cut -d ' ' -f 2)
    echo "Test $testName failed. Test ID: $id"

    # Get the Ginkgo logs of the test
    kubectl testkube get execution $id > out 2>error.log

    # Remove superfluous logs of everything before the last occurence of 'go downloading'.
    # The actual errors can be viewed from the ADO run, instead of needing to view the testkube dashboard.
    cat error.log | tac | awk '/go: downloading/ {exit} 1' | tac

    result=$(cat error.log | tac | awk '/------------------------------/ {exit} 1' | tac | awk '{gsub(/\x1B\[[0-9;]*[mK]/, ""); print}')

    payload=$(cat <<EOF
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "0076D7",
    "summary": "Test run failed",
    "sections": [{
        "activityTitle": "Test Execution Failed",
        "activitySubtitle": "CI Test Automation",
        "activityImage": "https://adaptivecards.io/content/cats/1.png",
        "facts": [{
            "name": "Cluster",
            "value": "**$cluster**"
        },{
            "name": "Test",
            "value": "**$testName**"
        }, {
            "name": "Execution Id",
            "value": "$id"
        }, {
            "name": "Result",
            "value": "$result"
        }],
        "markdown": true
    }]
}
EOF
)

    curl -X POST -H "Content-Type: application/json" -d "$payload" $WEBHOOK_URI

    done

    # Explicitly fail the ADO task since at least one test failed
    exit 1
fi
