#!/bin/bash

AI_RES_ID=$1
NAMESPACE=$2


POD_JAVA_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$JAVA_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)
POD_NODEJS_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$NODEJS_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)


# Get an access token
result_rsp=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://api.applicationinsights.io&mi_res_id=/subscriptions/66010356-d8a5-42d3-8593-6aaa3aeb1c11/resourceGroups/rambhatt-rnd-v2/providers/Microsoft.ManagedIdentity/userAssignedIdentities/rambhatt-agentpool-es-identity' -H Metadata:true -s)
# echo "Result: $result_rsp"
access_token=$(echo $result_rsp | jq -r '.access_token')

echo "$AI_RES_ID"

# Define your variables
url="https://api.loganalytics.io/v1$AI_RES_ID/query"

verify_AI_telemetry() {
    local pod_name="$1"
    local app_type="$2"
    local queries=("requests" "dependencies" "exceptions")
    local found_any=0

    for table in "${queries[@]}"; do
        json_body="{
            \"query\": \"$table | where timestamp > ago(15m) | where cloud_RoleInstance == '$pod_name' | count\",
            \"options\": {
                \"truncationMaxSize\": 67108864
            },
            \"maxRows\": 30001,
            \"workspaceFilters\": {
                \"regions\": []
            }
        }"

        echo "Validating $table telemetry for $pod_name ($app_type)..."
        response=$(curl -s -X POST $url \
            -H "Authorization: Bearer $access_token" \
            -H "Content-Type: application/json" \
            -d "$json_body")

        count_val=$(echo $response | jq '.tables[0].rows[0][0]')

        if (( count_val > 0 )); then
            echo "$table telemetry found: $count_val"
            found_any=1
        else
            echo "No $table telemetry found for $pod_name ($app_type)" >&2
            echo "Validation for $app_type pods failed: No $table telemetry found" >&2
            exit 1
        fi
    done
}

verify_AI_telemetry "$POD_JAVA_NAME" "java"
verify_AI_telemetry "$POD_NODEJS_NAME" "nodejs"

