#!/bin/bash

for ARGUMENT in "$@"
do
   KEY=$(echo $ARGUMENT | cut -f1 -d=)
   VALUE=$(echo $ARGUMENT | cut -f2 -d=)

   case "$KEY" in
           AzureClientId) AzureClientId=$VALUE ;;
           AzureTenantId) AzureTenantId=$VALUE ;;
           TeamsWebhookUri) TeamsWebhookUri=$VALUE ;;
           *)
    esac
done

echo "Install testkube CLI"
wget -qO - https://repo.testkube.io/key.pub | sudo apt-key add -
echo "deb https://repo.testkube.io/linux linux main" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get install -y testkube

echo "Install testkube on the cluster"
helm repo add kubeshop https://kubeshop.github.io/helm-charts
helm repo update
helm upgrade --install --create-namespace testkube kubeshop/testkube -n testkube -f ./helm-testkube-values.yaml

echo "Install testkube CRIs"
export AZURE_CLIENT_ID=$AzureClientId
export AZURE_TENANT_ID=$AzureTenantId
export WEBHOOK_URI=$TeamsWebhookUri
envsubst < ./testkube-teams-integration.yaml > ./testkube-teams-integration-updated.yaml
kubectl apply -f ./testkube-teams-integration-updated.yaml
kubectl apply -f ./api-server-permissions.yaml
envsubst < ./testkube-test-crs.yaml > ./testkube-test-crs-updated.yaml
kubectl apply -f ./testkube-test-crs-updated.yaml

echo "Wait for cluster to be ready"
sleep 120

echo "Run testkube tests"
# Run the full test suite
kubectl testkube run testsuite e2e-tests-merge --job-template ./custom-job-template.yaml --verbose

# Get the current id of the test suite now running
execution_id=$(kubectl testkube get testsuiteexecutions --test-suite e2e-tests-merge --limit 1 | grep e2e-tests | awk '{print $1}')

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
    done

    # Explicitly fail the ADO task since at least one test failed
    exit 1
fi