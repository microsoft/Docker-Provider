#!/bin/bash
set -euo pipefail

# Generic script for running a single configmap test scenario.
# Usage:
#   ./run-configtest-scenario.sh \
#     --configmap <path-to-configmap-yaml> \
#     --crs <path-to-testkube-crs-yaml> \
#     --scenario <scenario-name> \
#     --branch <git-branch>
#
# Steps:
#   1. Apply the configmap variant
#   2. Rollout restart ama-logs workloads
#   3. Wait for rollout to complete
#   4. Apply the TestKube workflow CRD
#   5. Run the testworkflow and collect results

CONFIGMAP=""
CRS=""
SCENARIO=""
BRANCH="ci_prod"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --configmap) CONFIGMAP="$2"; shift 2 ;;
        --crs) CRS="$2"; shift 2 ;;
        --scenario) SCENARIO="$2"; shift 2 ;;
        --branch) BRANCH="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "$CONFIGMAP" || -z "$CRS" || -z "$SCENARIO" ]]; then
    echo "Error: --configmap, --crs, and --scenario are required"
    exit 1
fi

WORKFLOW_NAME="config-test-${SCENARIO}"

echo "========== ConfigTest Scenario: ${SCENARIO} =========="

# Step 1: Apply configmap variant
echo "Applying configmap: ${CONFIGMAP}"
kubectl apply -f "${CONFIGMAP}"

# Step 2: Rollout restart ama-logs workloads
echo "Restarting ama-logs workloads..."
kubectl rollout restart ds/ama-logs -n kube-system
kubectl rollout restart deploy/ama-logs-rs -n kube-system
kubectl rollout restart ds/ama-logs-windows -n kube-system 2>/dev/null || echo "ama-logs-windows daemonset not found (may not exist on this cluster), skipping"

# Step 3: Wait for rollout to complete
echo "Waiting for rollouts to complete..."
kubectl rollout status ds/ama-logs -n kube-system --timeout=5m
kubectl rollout status deploy/ama-logs-rs -n kube-system --timeout=5m
kubectl rollout status ds/ama-logs-windows -n kube-system --timeout=5m 2>/dev/null || echo "ama-logs-windows rollout status skipped"

# Step 4: Apply the TestKube workflow CRD
echo "Applying TestKube workflow CRD: ${CRS}"
kubectl apply -f "${CRS}"

# Step 5: Run the testworkflow
echo "Running testworkflow: ${WORKFLOW_NAME}"
kubectl testkube run testworkflow "${WORKFLOW_NAME}" \
    --config GOTOOLCHAIN="auto" \
    --verbose

echo "Waiting for execution to be created..."
sleep 5

echo "Fetching testworkflow executions for ${WORKFLOW_NAME}..."
kubectl testkube get testworkflowexecution
execution_id=$(kubectl testkube get testworkflowexecution | grep -i "${WORKFLOW_NAME}" | head -n 1 | awk '{print $1}')

echo "Execution ID: ${execution_id}"

if [[ -z "${execution_id}" ]]; then
    echo "Error: Could not find execution ID for ${WORKFLOW_NAME}"
    exit 1
fi

# Watch until the testworkflow finishes
kubectl testkube watch testworkflowexecution "${execution_id}"

# Get the results as a formatted JSON file
kubectl testkube get testworkflowexecution "${execution_id}" --output json > "testkube-results-${SCENARIO}.json"

# Verify the JSON is valid
if ! jq empty "testkube-results-${SCENARIO}.json" 2>/dev/null; then
    echo "Error: Failed to get valid JSON results for scenario ${SCENARIO}"
    echo "Contents of testkube-results-${SCENARIO}.json:"
    cat "testkube-results-${SCENARIO}.json"
    exit 1
fi

# Check result status
result_status=$(jq -r '.result.status' "testkube-results-${SCENARIO}.json")
if [[ "${result_status}" == "failed" ]]; then
    echo "TestWorkflow FAILED for scenario: ${SCENARIO} (execution: ${execution_id})"
    kubectl testkube get testworkflowexecution "${execution_id}" --logs-only > "execution-${SCENARIO}.log" 2>&1
    cat "execution-${SCENARIO}.log"
    exit 1
else
    echo "TestWorkflow PASSED for scenario: ${SCENARIO} (execution: ${execution_id})"
fi

echo "========== Scenario ${SCENARIO} complete =========="
