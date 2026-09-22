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
           PerNodeLogCoverage) PerNodeLogCoverage=$VALUE ;;
           AgentTelemetryResourceId) AgentTelemetryResourceId=$VALUE ;;
           AgentTelemetryVersion) AgentTelemetryVersion=$VALUE ;;
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
export PER_NODE_LOG_COVERAGE=$PerNodeLogCoverage
export AGENT_TELEMETRY_RESOURCE_ID=$AgentTelemetryResourceId
export AGENT_TELEMETRY_VERSION=$AgentTelemetryVersion
kubectl apply -f ./api-server-permissions.yaml
kubectl apply -f ./testkube-test-crs.yaml

echo "Wait for cluster to be ready"
sleep 300

echo "Run testkube testworkflows"
workflows=("querylogs")
failed_workflows=()
successful_workflows=()

for wf in "${workflows[@]}"; do
    echo "Running workflow: $wf"
    kubectl testkube run testworkflow "$wf" \
        --config GENEVA_INTEGRATION="$GENEVA_INTEGRATION" \
        --config PER_NODE_LOG_COVERAGE="$PER_NODE_LOG_COVERAGE" \
        --config AGENT_TELEMETRY_RESOURCE_ID="$AGENT_TELEMETRY_RESOURCE_ID" \
        --config AGENT_TELEMETRY_VERSION="$AGENT_TELEMETRY_VERSION" \
        --config AZURE_TENANT_ID="$AZURE_TENANT_ID" \
        --config AZURE_CLIENT_ID="$AZURE_CLIENT_ID" \
        --config GOTOOLCHAIN="auto" \
        --verbose

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

    # Watch until the testworkflow finishes. The exit code is the authoritative result:
    # the CLI returns non-zero when the execution fails.
    kubectl testkube watch testworkflowexecution $execution_id
    watch_rc=$?

    # Get the results as a formatted json file.
    # The execution status is not necessarily final the moment `watch` returns, so poll briefly
    # for a terminal one instead of reading a status that is still "running" and mistaking it
    # for a result. An empty file satisfies `jq empty`, so the document is also confirmed to be
    # an object before any field is read out of it. The poll is kept short because the status is
    # only ever corroboration: it can add a failure, never clear one.
    wf_status=""
    for attempt in $(seq 1 10); do
        kubectl testkube get testworkflowexecution $execution_id --output json > "testkube-results-${wf}.json"
        if [[ -s "testkube-results-${wf}.json" ]] && jq -e 'type == "object"' "testkube-results-${wf}.json" >/dev/null 2>&1; then
            wf_status=$(jq -r '.result.status // empty' "testkube-results-${wf}.json")
        fi
        case "$wf_status" in
            passed|failed|aborted|canceled) break ;;
        esac
        sleep 1
    done
    echo "TestWorkflow $wf finished with exit code $watch_rc and status '${wf_status:-unknown}'"

    # The status only decides the outcome once it is terminal. When it never became terminal,
    # or no usable JSON was returned at all, the exit code of `watch` is the only signal left,
    # and it is what stops a failing workflow from being reported as a successful one.
    status_failed=0
    case "$wf_status" in
        failed|aborted|canceled) status_failed=1 ;;
    esac

    if [[ $watch_rc -ne 0 || $status_failed -eq 1 ]]; then

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
        # curl -X POST -H "Content-Type: application/json" -d "$payload" $WEBHOOK_URI

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