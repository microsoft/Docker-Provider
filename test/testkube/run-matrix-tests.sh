#!/bin/bash
# run-matrix-tests.sh
# Reads configmap-test-matrix.yaml and runs all cases sequentially.
# Each case: apply configmap, wait, run workflows with merged params.
#
# Usage: ./run-matrix-tests.sh [--matrix <path>] [--repo-root <path>]

set -euo pipefail

MATRIX_FILE="./configmap-test-matrix.yaml"
REPO_ROOT="${BUILD_SOURCESDIRECTORY:-$(cd ../.. && pwd)}"

# ── Parse arguments ──────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --matrix)   MATRIX_FILE="$2"; shift 2 ;;
        --repo-root) REPO_ROOT="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

# ── Ensure yq is available ───────────────────────────────────
if ! command -v yq &>/dev/null; then
    echo "Installing yq..."
    sudo wget -qO /usr/local/bin/yq \
        https://github.com/mikefarah/yq/releases/download/v4.44.1/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
fi

echo "Matrix file: ${MATRIX_FILE}"
echo "Repo root:   ${REPO_ROOT}"
echo ""

# ── Read defaults ────────────────────────────────────────────
default_params=$(yq -o=json '.defaults.params // {}' "$MATRIX_FILE")
case_count=$(yq '.cases | length' "$MATRIX_FILE")

if [[ "$case_count" -eq 0 ]]; then
    echo "No cases found in ${MATRIX_FILE}"
    exit 1
fi

# ── Track overall results ────────────────────────────────────
all_failed=()
all_passed=()

# ── Run a single workflow ────────────────────────────────────
run_workflow() {
    local wf_name="$1"
    local config_flags="$2"

    echo "  Running workflow: ${wf_name}"
    echo "    Config: ${config_flags}"
    kubectl testkube run testworkflow "${wf_name}" ${config_flags} --verbose

    echo "  Waiting for execution to be created..."
    sleep 5

    local execution_id
    execution_id=$(kubectl testkube get testworkflowexecution | grep -i "${wf_name}" | head -n 1 | awk '{print $1}')
    echo "  Execution ID: ${execution_id}"

    if [[ -z "${execution_id}" ]]; then
        echo "  Error: Could not find execution ID for ${wf_name}"
        return 1
    fi

    kubectl testkube watch testworkflowexecution "${execution_id}"

    kubectl testkube get testworkflowexecution "${execution_id}" --output json > "testkube-results-${wf_name}.json"

    if ! jq empty "testkube-results-${wf_name}.json" 2>/dev/null; then
        echo "  Error: Failed to get valid JSON results for ${wf_name}"
        cat "testkube-results-${wf_name}.json"
        return 1
    fi

    local result_status
    result_status=$(jq -r '.result.status' "testkube-results-${wf_name}.json")
    if [[ "${result_status}" == "failed" ]]; then
        echo "  TestWorkflow FAILED: ${wf_name} (execution: ${execution_id})"
        kubectl testkube get testworkflowexecution "${execution_id}" --logs-only || true
        return 1
    else
        echo "  TestWorkflow PASSED: ${wf_name} (execution: ${execution_id})"
        return 0
    fi
}

# ── Iterate over cases ───────────────────────────────────────
for (( c=0; c<case_count; c++ )); do
    case_name=$(yq ".cases[${c}].name" "$MATRIX_FILE")
    configmap=$(yq ".cases[${c}].configmap // \"\"" "$MATRIX_FILE")
    case_params=$(yq -o=json ".cases[${c}].params // {}" "$MATRIX_FILE")
    wf_count=$(yq ".cases[${c}].workflows | length" "$MATRIX_FILE")

    echo ""
    echo "=========================================="
    echo "Case: ${case_name}"
    echo "=========================================="

    # Apply configmap if specified
    if [[ -n "$configmap" ]]; then
        local_path="${REPO_ROOT}/${configmap}"
        echo "Applying configmap: ${local_path}"
        kubectl apply -f "${local_path}"
        echo "Waiting 60s for ama-logs to detect configmap change..."
        sleep 60
    fi

    case_failed=()
    case_passed=()

    for (( w=0; w<wf_count; w++ )); do
        wf_name=$(yq ".cases[${c}].workflows[${w}].name" "$MATRIX_FILE")
        wf_params=$(yq -o=json ".cases[${c}].workflows[${w}].params // {}" "$MATRIX_FILE")

        # Merge: defaults < case < workflow (rightmost wins)
        merged=$(echo "$default_params" "$case_params" "$wf_params" | jq -s '.[0] * .[1] * .[2]')

        # Build --config flags
        config_flags=""
        while IFS= read -r key; do
            val=$(echo "$merged" | jq -r --arg k "$key" '.[$k]')
            config_flags+=" --config ${key}=${val}"
        done < <(echo "$merged" | jq -r 'keys[]')

        if run_workflow "$wf_name" "$config_flags"; then
            case_passed+=("$wf_name")
            all_passed+=("${case_name}/${wf_name}")
        else
            case_failed+=("$wf_name")
            all_failed+=("${case_name}/${wf_name}")
        fi
    done

    echo ""
    echo "--- Case Summary: ${case_name} ---"
    if [[ ${#case_passed[@]} -gt 0 ]]; then
        echo "Passed:"
        for wf in "${case_passed[@]}"; do echo "  - $wf"; done
    fi
    if [[ ${#case_failed[@]} -gt 0 ]]; then
        echo "Failed:"
        for wf in "${case_failed[@]}"; do echo "  - $wf"; done
    fi
done

# ── Overall summary ──────────────────────────────────────────
echo ""
echo "=========================================="
echo "Overall Matrix Summary"
echo "=========================================="
if [[ ${#all_passed[@]} -gt 0 ]]; then
    echo "Passed:"
    for item in "${all_passed[@]}"; do echo "  - $item"; done
fi
if [[ ${#all_failed[@]} -gt 0 ]]; then
    echo "Failed:"
    for item in "${all_failed[@]}"; do echo "  - $item"; done
    echo "=========================================="
    exit 1
fi
echo "All cases passed."
echo "=========================================="
