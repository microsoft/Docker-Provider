#!/bin/bash
set -euo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-and-execute-testkube-tests.sh"
temp_dir=$(mktemp -d)
trap 'rm -f "$temp_dir/output.log" "$temp_dir/calls.log" "$temp_dir/testkube-results-containerstatus-linux.json" "$temp_dir/testkube-results-querylogs.json"; rmdir "$temp_dir"' EXIT
export CALLS_LOG="$temp_dir/calls.log"
export EXPECTED_REVISION=0123456789abcdef0123456789abcdef01234567
export EXPECTED_START=2026-11-11T08:58:00Z

git() { echo "$EXPECTED_REVISION"; }
sleep() { :; }
wget() { :; }
sudo() { :; }
helm() { :; }
curl() { :; }
jq() {
    if [[ "$1" == "-r" ]]; then
        echo passed
    fi
}
kubectl() {
    printf '%s\n' "$*" >> "$CALLS_LOG"
    case "$*" in
        "config current-context") echo test-cluster ;;
        "get crd "*) return 1 ;;
        "apply -f ./testkube-test-crs.yaml") return "${APPLY_EXIT:-0}" ;;
        "apply -f ./api-server-permissions.yaml") ;;
        "delete namespace "*) ;;
        "testkube run testworkflow "*)
            [[ "$*" == *"--config TEST_SOURCE_REVISION=$EXPECTED_REVISION"* ]] || return 90
            [[ "$*" == *"--config AGENT_DEPLOYMENT_START_TIME=$EXPECTED_START"* ]] || return 91
            return "${RUN_EXIT:-0}"
            ;;
        "testkube get testworkflowexecution")
            printf 'linux-execution containerstatus-linux\nquery-execution querylogs\n'
            ;;
        "testkube get testworkflowexecution "*" --output json")
            echo '{"result":{"status":"passed"}}'
            ;;
        "testkube watch testworkflowexecution "*) ;;
        *) echo "Unexpected kubectl call: $*" >&2; return 92 ;;
    esac
}
export -f git sleep wget sudo helm curl jq kubectl

cd "$temp_dir"
args=(LinuxTestsOnly=true AgentTelemetryResourceId=test-resource AgentTelemetryVersion=test-version)

if bash "$script" "${args[@]}" > output.log 2>&1; then
    echo "Expected a missing deployment timestamp to fail" >&2
    exit 1
fi
grep -q "AgentDeploymentStartTime are required" output.log
[[ ! -e "$CALLS_LOG" ]]

args+=("AgentDeploymentStartTime=$EXPECTED_START")
export APPLY_EXIT=1
if bash "$script" "${args[@]}" > output.log 2>&1; then
    echo "Expected a failed workflow apply to fail the runner" >&2
    exit 1
fi
! grep -q "testkube run" "$CALLS_LOG"

export APPLY_EXIT=0 RUN_EXIT=1
: > "$CALLS_LOG"
if bash "$script" "${args[@]}" > output.log 2>&1; then
    echo "Expected a failed workflow launch to fail the runner" >&2
    exit 1
fi
! grep -q "testkube watch" "$CALLS_LOG"

export RUN_EXIT=0
: > "$CALLS_LOG"
bash "$script" "${args[@]}" > output.log 2>&1
grep -q "All workflows completed successfully" output.log
[[ $(grep -c "testkube run testworkflow" "$CALLS_LOG") -eq 2 ]]
echo "Testkube runner configuration and fail-closed checks passed"
