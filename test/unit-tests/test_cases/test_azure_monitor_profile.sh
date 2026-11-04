#!/bin/bash

source "$(dirname "$0")/../test_framework.sh"

REPO_ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
MDM_SCRIPT="$REPO_ROOT/scripts/onboarding/aks/mdmonboarding/mdm_onboarding.sh"
MDM_SCALE_SCRIPT="$REPO_ROOT/scripts/onboarding/aks/mdmonboarding/mdm_onboarding_atscale.sh"
MIGRATION_SCRIPT="$REPO_ROOT/scripts/troubleshoot/cluster-migration/migrate-to-container-insights-msi.sh"
WORKSPACE_LINK_SCRIPT="$REPO_ROOT/scripts/preview/mdm-alerts/cluster-ws-link.sh"

az() {
    local command="$1 ${2-}"
    local query="" name="" uri="" method=""
    local args=("$@")
    for ((i = 0; i < ${#args[@]}; i++)); do
        case "${args[$i]}" in
            --query) query="${args[$((i + 1))]}" ;;
            -n|--name) name="${args[$((i + 1))]}" ;;
            --uri) uri="${args[$((i + 1))]}" ;;
            --method) method="${args[$((i + 1))]}" ;;
        esac
    done

    case "$command" in
        "login "|"account set"|"account show"|"cloud set") return 0 ;;
        "account list") echo "test-sub" ;;
        "version --query") echo "2.99.0" ;;
        "resource show")
            case "$query" in
                resourceGroup) echo '"test-rg"' ;;
                name) echo '"first"' ;;
                properties.customerId) echo '"mock-workspace-guid"' ;;
                *) echo "Unexpected resource query: $query" >&2; return 1 ;;
            esac
            ;;
        "aks list")
            if [[ "$query" == *clusterId* ]]; then
                echo '[{"clusterId":"/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.ContainerService/managedClusters/first","name":"first","rg":"test-rg"},{"clusterId":"/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.ContainerService/managedClusters/second","name":"second","rg":"test-rg"}]'
            else
                printf 'first\ttest-rg\n'
            fi
            ;;
        "aks show")
            case "$query" in
                id) echo "/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.ContainerService/managedClusters/$name" ;;
                provisioningState) echo "Succeeded" ;;
                identity.type) echo "SystemAssigned" ;;
                servicePrincipalProfile.clientId)
                    if [ "$MOCK_MODE" = "spn" ] || { [ "$MOCK_MODE" = "mixed-identities" ] && [ "$name" = "first" ]; }; then
                        echo "spn-client"
                    else
                        echo "msi"
                    fi
                    ;;
                identity.principalId*)
                    echo "control-plane-principal"
                    ;;
                apiServerAccessProfile.enablePrivateCluster) echo "false" ;;
                "")
                    if [ "$MOCK_MODE" = "missing-auth-metadata" ]; then echo '{}'; return 0; fi
                    local auth=false
                    if [ "$MOCK_MODE" = "already-msi" ] || [ "$MOCK_PHASE" = "enabled" ]; then auth=true; fi
                    printf '{"addonProfiles":{"omSagent":{"config":{"useaadauth":"%s"}}}}\n' "$auth"
                    ;;
                *) echo "Unexpected AKS query: $query" >&2; return 1 ;;
            esac
            ;;
        "rest --method")
            if [ "$method" = "post" ]; then
                echo '"mock-workspace-key"'
                return 0
            fi
            [[ "$uri" == *"?api-version=2026-07-01" ]] || return 1
            if [ "$method" = "put" ]; then
                echo "PROFILE_PUT"
                return 0
            fi
            if [ "$MOCK_MODE" = "profile-error" ]; then return 1; fi
            case "$query" in
                "")
                    if [ "$MOCK_MODE" = "missing-profile" ]; then
                        echo '{"properties":{}}'
                    else
                        echo '{"properties":{"azureMonitorProfile":{"containerInsights":{"enabled":false,"logAnalyticsWorkspaceResourceId":"old-workspace"}}},"tags":{"keep":"tag"}}'
                    fi
                    ;;
                properties.azureMonitorProfile.containerInsights.enabled)
                    if [ "$MOCK_PHASE" = "disabled" ]; then
                        if [ "$MOCK_MODE" = "invalid-disabled" ]; then echo "null"; else echo "False"; fi
                    else
                        echo "True"
                    fi
                    ;;
                properties.azureMonitorProfile.containerInsights.logAnalyticsWorkspaceResourceId)
                    echo "/subscriptions/test-sub/resourceGroups/Monitoring/providers/Microsoft.OperationalInsights/workspaces/CaseSensitive"
                    ;;
                *) echo "Unexpected profile query: $query" >&2; return 1 ;;
            esac
            ;;
        "aks disable-addons") export MOCK_PHASE=disabled; echo "MONITORING_DISABLED" ;;
        "aks enable-addons") export MOCK_PHASE=enabled; echo "MONITORING_ENABLED $*" ;;
        "role assignment") echo "ROLE_ASSIGNMENT $*" ;;
        *) echo "Unexpected Azure command: $*" >&2; return 1 ;;
    esac
}

sleep() { return 0; }
export -f az sleep

run_case() {
    export MOCK_MODE=$1 MOCK_PHASE=initial
    shift
    RESULT=$(bash "$@" 2>&1)
    STATUS=$?
}

run_case system "$MDM_SCRIPT" test-sub test-rg first
assert_equals 1 "$STATUS" "collector identity cannot be inferred from the new profile"
assert_equals 0 "$(printf '%s\n' "$RESULT" | grep -c ROLE_ASSIGNMENT)" "never substitute the control-plane identity for the collector identity"

run_case spn "$MDM_SCRIPT" test-sub test-rg first
assert_equals 0 "$STATUS" "existing service-principal flow"
assert_equals 1 "$(printf '%s\n' "$RESULT" | grep -c -- '--assignee spn-client')" "preserve service-principal assignment"

run_case mixed-identities "$MDM_SCALE_SCRIPT" test-sub
assert_equals 1 "$STATUS" "report clusters whose collector identity is unavailable"
assert_equals 1 "$(printf '%s\n' "$RESULT" | grep -c ROLE_ASSIGNMENT)" "do not reuse the first cluster identity or grant the second cluster's control-plane identity"

run_case legacy "$MIGRATION_SCRIPT" -s test-sub -c aks
assert_equals 0 "$STATUS" "legacy authentication migration"
assert_equals 1 "$(printf '%s\n' "$RESULT" | grep -c 'MONITORING_ENABLED.*--workspace-resource-id /subscriptions/test-sub/resourceGroups/Monitoring/')" "read the workspace from Azure Monitor Profile without changing its casing"
assert_equals 1 "$(printf '%s\n' "$RESULT" | grep -c 'Successful clusters (1)')" "recognize case-insensitive legacy flags and profile booleans"

run_case already-msi "$MIGRATION_SCRIPT" -s test-sub -c aks
assert_equals 0 "$STATUS" "already-migrated cluster"
assert_equals 0 "$(printf '%s\n' "$RESULT" | grep -c MONITORING_DISABLED)" "never restart monitoring for an MSI cluster"

run_case invalid-disabled "$MIGRATION_SCRIPT" -s test-sub -c aks
assert_equals 0 "$(printf '%s\n' "$RESULT" | grep -c MONITORING_ENABLED)" "a missing enabled flag is not a successful disable"
assert_equals 1 "$(printf '%s\n' "$RESULT" | grep -c 'Failed clusters (1)')" "report invalid profile responses"

run_case profile-error "$MIGRATION_SCRIPT" -s test-sub -c aks
assert_equals 0 "$(printf '%s\n' "$RESULT" | grep -c MONITORING_DISABLED)" "do not mutate monitoring after a profile API failure"

run_case missing-auth-metadata "$MIGRATION_SCRIPT" -s test-sub -c aks
assert_equals 0 "$(printf '%s\n' "$RESULT" | grep -c MONITORING_DISABLED)" "do not infer legacy authentication when its source metadata is missing"
assert_equals 1 "$(printf '%s\n' "$RESULT" | grep -c 'Could not read legacy authentication mode')" "report missing legacy metadata explicitly"

setup_test_env
original_directory=$PWD
cd "$TEST_DIR" || exit 1
workspace="/subscriptions/test-sub/resourceGroups/Monitoring/providers/Microsoft.OperationalInsights/workspaces/CaseSensitive"
cluster="/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.ContainerService/managedClusters/first"

run_case workspace-link "$WORKSPACE_LINK_SCRIPT" test-sub "$cluster" test-sub "$workspace"
assert_equals 0 "$STATUS" "workspace-linking request"
assert_equals "$workspace" "$(jq -r '.properties.azureMonitorProfile.containerInsights.logAnalyticsWorkspaceResourceId' putrequestbody.json)" "write the requested workspace through the new profile"
assert_equals "false/tag" "$(jq -r '[.properties.azureMonitorProfile.containerInsights.enabled | tostring] + [.tags.keep] | join("/")' putrequestbody.json)" "preserve the disabled state and unrelated cluster metadata"

run_case missing-profile "$WORKSPACE_LINK_SCRIPT" test-sub "$cluster" test-sub "$workspace"
assert_equals 1 "$STATUS" "reject incomplete profile metadata"
assert_equals 0 "$(printf '%s\n' "$RESULT" | grep -c PROFILE_PUT)" "never PUT an incomplete Container Insights profile"

cd "$original_directory" || exit 1
cleanup_test_env

print_test_summary
