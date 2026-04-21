#!/bin/bash
# run-matrix-tests.sh
# Reads a single case from configmap-test-matrix.yaml, applies its configmap,
# and runs all workflows for that case with merged params.
#
# Usage: ./run-matrix-tests.sh --case <name> [--matrix <path>] [--repo-root <path>]

set -euo pipefail

MATRIX_FILE="./configmap-test-matrix.yaml"
REPO_ROOT="${BUILD_SOURCESDIRECTORY:-$(cd ../.. && pwd)}"
CASE_NAME=""

# ── Parse arguments ──────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --matrix)    MATRIX_FILE="$2"; shift 2 ;;
        --repo-root) REPO_ROOT="$2"; shift 2 ;;
        --case)      CASE_NAME="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "$CASE_NAME" ]]; then
    echo "Error: --case is required"
    exit 1
fi

# ── Ensure yq is available ───────────────────────────────────
if ! command -v yq &>/dev/null; then
    echo "Installing yq..."
    sudo wget -qO /usr/local/bin/yq \
        https://github.com/mikefarah/yq/releases/download/v4.44.1/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
fi

echo "Matrix file: ${MATRIX_FILE}"
echo "Repo root:   ${REPO_ROOT}"
echo "Case:        ${CASE_NAME}"
echo ""

# ── Find the case ───────────────────────────────────────────
case_index=$(yq ".cases | to_entries | .[] | select(.value.name == \"${CASE_NAME}\") | .key" "$MATRIX_FILE")
if [[ -z "$case_index" ]]; then
    echo "Error: case '${CASE_NAME}' not found in ${MATRIX_FILE}"
    echo "Available cases:"
    yq '.cases[].name' "$MATRIX_FILE"
    exit 1
fi

# ── Read case data ──────────────────────────────────────────
default_params=$(yq -o=json '.defaults.params // {}' "$MATRIX_FILE")
configmap=$(yq ".cases[${case_index}].configmap // \"\"" "$MATRIX_FILE")
case_params=$(yq -o=json ".cases[${case_index}].params // {}" "$MATRIX_FILE")
wf_count=$(yq ".cases[${case_index}].workflows | length" "$MATRIX_FILE")

echo "=========================================="
echo "Case: ${CASE_NAME}"
echo "=========================================="

# ── Apply configmap if specified ────────────────────────────
if [[ -n "$configmap" ]]; then
    local_path="${REPO_ROOT}/${configmap}"
    echo "Applying configmap: ${local_path}"
    kubectl apply -f "${local_path}"
    echo "Waiting 60s for ama-logs to detect configmap change..."
    sleep 60
fi

# ── Run workflows ───────────────────────────────────────────
failed=()
passed=()

for (( w=0; w<wf_count; w++ )); do
    wf_name=$(yq ".cases[${case_index}].workflows[${w}].name" "$MATRIX_FILE")
    wf_params=$(yq -o=json ".cases[${case_index}].workflows[${w}].params // {}" "$MATRIX_FILE")

    # Merge: defaults < case < workflow (rightmost wins)
    merged=$(echo "$default_params" "$case_params" "$wf_params" | jq -s '.[0] * .[1] * .[2]')

    # Build --config flags
    config_flags=""
    while IFS= read -r key; do
        val=$(echo "$merged" | jq -r --arg k "$key" '.[$k]')
        config_flags+=" --config ${key}=${val}"
    done < <(echo "$merged" | jq -r 'keys[]')

    echo ""
    echo "  Running workflow: ${wf_name}"
    echo "    Config: ${config_flags}"
    kubectl testkube run testworkflow "${wf_name}" ${config_flags} --verbose

    echo "  Waiting for execution to be created..."
    sleep 5

    execution_id=$(kubectl testkube get testworkflowexecution | grep -i "${wf_name}" | head -n 1 | awk '{print $1}')
    echo "  Execution ID: ${execution_id}"

    if [[ -z "${execution_id}" ]]; then
        echo "  Error: Could not find execution ID for ${wf_name}"
        failed+=("$wf_name")
        continue
    fi

    kubectl testkube watch testworkflowexecution "${execution_id}"
    kubectl testkube get testworkflowexecution "${execution_id}" --output json > "testkube-results-${wf_name}.json"

    if ! jq empty "testkube-results-${wf_name}.json" 2>/dev/null; then
        echo "  Error: Failed to get valid JSON results for ${wf_name}"
        cat "testkube-results-${wf_name}.json"
        failed+=("$wf_name")
        continue
    fi

    result_status=$(jq -r '.result.status' "testkube-results-${wf_name}.json")
    if [[ "${result_status}" == "failed" ]]; then
        echo "  FAILED: ${wf_name} (execution: ${execution_id})"
        kubectl testkube get testworkflowexecution "${execution_id}" --logs-only || true
        failed+=("$wf_name")
    else
        echo "  PASSED: ${wf_name} (execution: ${execution_id})"
        passed+=("$wf_name")
    fi
done

# ── Summary ─────────────────────────────────────────────────
echo ""
echo "--- ${CASE_NAME} Summary ---"
if [[ ${#passed[@]} -gt 0 ]]; then
    echo "Passed:"
    for wf in "${passed[@]}"; do echo "  - $wf"; done
fi
if [[ ${#failed[@]} -gt 0 ]]; then
    echo "Failed:"
    for wf in "${failed[@]}"; do echo "  - $wf"; done
    exit 1
fi
echo "All workflows passed."
