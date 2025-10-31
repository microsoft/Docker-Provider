#!/bin/bash

AI_RES_ID=$1
NAMESPACE=$2

echo "Finding pods in namespace: $NAMESPACE for Java App $JAVA_TEST_APP_NAME, NodeJS App $NODEJS_TEST_APP_NAME, Python App $PYTHON_TEST_APP_NAME, and Dotnet App $DOTNET_TEST_APP_NAME"
POD_JAVA_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$JAVA_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)
POD_NODEJS_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$NODEJS_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)
POD_PYTHON_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$PYTHON_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)
POD_DOTNET_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$DOTNET_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)


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
    local skip_exceptions="$3"
    local queries=("requests" "dependencies", "customMetrics")
    local found_any=0

    if [[ "$skip_exceptions" != "true" ]]; then
        queries+=("exceptions")
    fi

    echo "Validating telemetry for $pod_name ($app_type)..."
    if [[ -z "$pod_name" ]]; then
        echo "Pod name is empty. Validation failed for $app_type pod $pod_name."
        exit 1
    fi

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
            return 1
        fi
    done
}

max_retries=10
retry_interval=30

for app in "java" "nodejs" "python" "dotnet"; do
  skip_exceptions="false"
  if [ "$app" = "java" ]; then
    pod_name="$POD_JAVA_NAME"
  elif [ "$app" = "nodejs" ]; then
    pod_name="$POD_NODEJS_NAME"
  elif [ "$app" = "python" ]; then
    pod_name="$POD_PYTHON_NAME"
  elif [ "$app" = "dotnet" ]; then
    pod_name="$POD_DOTNET_NAME"
    skip_exceptions="true"
  else
    echo "Unsupported application type: $app"
    exit 1
  fi

  attempt=1
  success=0
  while [ $attempt -le $max_retries ]; do
    echo "Attempt $attempt/$max_retries: Validating telemetry for $pod_name ($app)..."
    if verify_AI_telemetry "$pod_name" "$app" "$skip_exceptions"; then
      echo "Telemetry validation succeeded for $pod_name ($app)"
      success=1
      break
    else
      echo "Telemetry validation failed for $pod_name ($app) on attempt $attempt"
      if [ $attempt -eq $max_retries ]; then
        echo "Telemetry validation failed for $pod_name ($app) after $max_retries attempts"
        exit 1
      fi
      echo "Waiting $retry_interval seconds before retrying..."
      sleep $retry_interval
    fi
    attempt=$((attempt + 1))
  done
done
