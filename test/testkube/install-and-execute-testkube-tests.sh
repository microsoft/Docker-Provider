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

echo "Checking for existing Testkube installation..."    
if helm list -n testkube 2>/dev/null | grep -q testkube; then
    echo "Found existing Testkube installation. Cleaning up..."
    helm uninstall testkube -n testkube || true
    echo "Deleting testkube namespace..."
    kubectl delete namespace testkube --wait=true --timeout=120s || true
    echo "Waiting for namespace to fully terminate..."
    sleep 30
    echo "Cleanup complete!"
else
    echo "No existing Testkube installation found."
fi

echo "Install testkube on the cluster"
helm repo add kubeshop https://kubeshop.github.io/helm-charts
helm repo update
helm upgrade --install --create-namespace testkube kubeshop/testkube -n testkube -f ./helm-testkube-values.yaml

echo "Install testkube CRIs"
export AZURE_CLIENT_ID=$AzureClientId
export AZURE_TENANT_ID=$AzureTenantId
export WEBHOOK_URI=$TeamsWebhookUri
export GENEVA_INTEGRATION=$GenevaIntegration
kubectl apply -f ./api-server-permissions.yaml
envsubst < ./testkube-test-crs.yaml > ./testkube-test-crs-updated.yaml
kubectl apply -f ./testkube-test-crs-updated.yaml

echo "Wait for cluster to be ready"
sleep 200

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