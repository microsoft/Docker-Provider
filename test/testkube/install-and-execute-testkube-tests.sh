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

# Remove stale CRDs that block Helm ownership
stale_crds=(
    "testworkflowexecutions.testworkflows.testkube.io"
    "testworkflows.testkube.io"
    "testworkflows.testworkflows.testkube.io"
    "testworkflowtemplates.testworkflows.testkube.io"
)

echo "Checking for stale Testkube CRDs"
for crd in "${stale_crds[@]}"; do
    if kubectl get crd "$crd" >/dev/null 2>&1; then
        owner=$(kubectl get crd "$crd" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}')
        if [[ "$owner" != "Helm" ]]; then
            echo "Deleting CRD $crd with unmanaged owner: ${owner:-none}"
            kubectl delete crd "$crd" --wait=true || true
        fi
    fi
done

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

echo "Install testkube TestWorkflows"
export AZURE_CLIENT_ID=$AzureClientId
export AZURE_TENANT_ID=$AzureTenantId
export WEBHOOK_URI=$TeamsWebhookUri
export GENEVA_INTEGRATION=$GenevaIntegration

envsubst < "./testkube-test-crs.yaml" > "./testkube-test-crs-updated.yaml"
kubectl apply -f ./api-server-permissions.yaml
kubectl apply -f ./testkube-test-crs-updated.yaml

echo "Wait for cluster to be ready"
sleep 300

echo "Run testkube testworkflows"
workflows=()
failed_workflows=()
successful_workflows=()
if [[ $LinuxTestsOnly == "true" ]]; then
    echo "Running Linux tests only"
    workflows=("containerstatus-linux" "querylogs")
else
    echo "Running all tests"
    workflows=("containerstatus-linux" "containerstatus-windows" "querylogs")
fi

for wf in "${workflows[@]}"; do
    echo "Running workflow: $wf"
    kubectl testkube run testworkflow "$wf"

    echo "Waiting for execution to be created..."
    sleep 5

    echo "Fetching testworkflow executions for $wf..."
    kubectl testkube get testworkflowexecution
    execution_id=$(kubectl testkube get testworkflowexecution | grep -i "$wf" | head -n 1 | awk '{print $1}')

    echo "Execution ID: $execution_id"

    # Check if execution_id is empty
    if [[ -z "$execution_id" ]]; then
        echo "Error: Could not find execution ID for $wf"
        exit 1
    fi

    # Watch until the testworkflow finishes
    kubectl testkube watch testworkflowexecution $execution_id

    # Get the results as a formatted json file
    kubectl testkube get testworkflowexecution $execution_id --output json > "testkube-results-${wf}.json"

    # Verify the JSON is valid
    if ! jq empty "testkube-results-${wf}.json" 2>/dev/null; then
        echo "Error: Failed to get valid JSON results from testkube for $wf"
        echo "Contents of testkube-results-${wf}.json:"
        cat "testkube-results-${wf}.json"
        exit 1
    fi

    # For any test that has failed, print out the logs
    if [[ $(jq -r '.result.status' "testkube-results-${wf}.json") == "failed" ]]; then

        echo "TestWorkflow failed. Execution ID: $execution_id"

        # Get the logs of the testworkflow execution
        kubectl testkube get testworkflowexecution $execution_id --logs-only > "execution-${wf}.log" 2>&1

        # Display the logs
        cat "execution-${wf}.log"

        # Extract meaningful error information (only the ginkgo failure summary lines, any failure count)
        result=$(awk 'BEGIN{inblock=0} /Summarizing [0-9]+ Failure/{inblock=1} {
            if(inblock){
                gsub(/\x1B\[[0-9;]*[mK]/, "");
                if($0 ~ /^FAIL$/ || $0 ~ /^Ginkgo ran/ || $0 ~ /^Test Suite Failed/){exit};
                print;
            }
        }' "execution-${wf}.log")

        result_json=$(printf '%s' "$result" | jq -Rs .)

        payload=$(cat <<EOF
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "0076D7",
    "summary": "Test run failed",
    "sections": [{
        "activityTitle": "TestWorkflow Execution Failed",
        "activitySubtitle": "CI Test Automation",
        "activityImage": "https://adaptivecards.io/content/cats/1.png",
        "facts": [{
            "name": "Cluster",
            "value": "**$cluster**"
        },{
            "name": "TestWorkflow",
            "value": "**$wf**"
        }, {
            "name": "Execution Id",
            "value": "$execution_id"
        }, {
            "name": "Result",
            "value": ${result_json}
        }],
        "markdown": true
    }]
}
EOF
)
        curl -X POST -H "Content-Type: application/json" -d "$payload" $WEBHOOK_URI

        # Track the failed workflow for summary reporting
        failed_workflows+=("${wf} (execution: ${execution_id})")
    else
        successful_workflows+=("${wf} (execution: ${execution_id})")
    fi
done

echo "\n========== TestWorkflow Summary =========="
if [[ ${#failed_workflows[@]} -gt 0 ]]; then
    echo "Failed workflows:"
    for wf in "${failed_workflows[@]}"; do
        echo "- $wf"
    done
    if [[ ${#successful_workflows[@]} -gt 0 ]]; then
        echo "Successful workflows:"
        for wf in "${successful_workflows[@]}"; do
            echo "- $wf"
        done
    fi
    echo "========================================"
    exit 1
else
    echo "All workflows completed successfully."
    echo "Successful workflows:"
    for wf in "${successful_workflows[@]}"; do
        echo "- $wf"
    done
    echo "========================================"
fi

echo "Cleaning up Testkube installation..."
helm uninstall testkube -n testkube || true
kubectl delete namespace testkube --wait=true --timeout=120s || true
echo "Cleanup complete."