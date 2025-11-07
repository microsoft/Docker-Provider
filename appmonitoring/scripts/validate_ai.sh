#!/bin/bash

WS_RES_ID=$1
NAMESPACE=$2
ROLE_INSTANCE_FIELD=$3
shift 3  # Remove first 3 arguments
QUERIES=("$@")  # Remaining arguments are the queries

echo "Finding pods in namespace: $NAMESPACE for Java App $JAVA_TEST_APP_NAME, NodeJS App $NODEJS_TEST_APP_NAME, Python App $PYTHON_TEST_APP_NAME, Dotnet App $DOTNET_TEST_APP_NAME, and Go App $GO_TEST_APP_NAME"
POD_JAVA_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$JAVA_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)
POD_NODEJS_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$NODEJS_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)
POD_PYTHON_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$PYTHON_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)
POD_DOTNET_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$DOTNET_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)
POD_GO_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$GO_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)


# Get an access token
result_rsp=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://api.applicationinsights.io&mi_res_id=/subscriptions/66010356-d8a5-42d3-8593-6aaa3aeb1c11/resourceGroups/rambhatt-rnd-v2/providers/Microsoft.ManagedIdentity/userAssignedIdentities/rambhatt-agentpool-es-identity' -H Metadata:true -s)
# echo "Result: $result_rsp"
access_token=$(echo $result_rsp | jq -r '.access_token')
client_id=$(echo $result_rsp | jq -r '.client_id')

echo "Using identity with client_id: $client_id"
echo "Workspace: $WS_RES_ID"
echo "Role instance field: $ROLE_INSTANCE_FIELD"

# Define your variables
url="https://api.loganalytics.io/v1$WS_RES_ID/query"

verify_AI_telemetry() {
    local pod_name="$1"
    local app_type="$2"
    local skip_exceptions="$3"
    local tables=("${QUERIES[@]}")
    local found_any=0

    # Remove AppExceptions from tables if skip_exceptions is true
    if [[ "$skip_exceptions" == "true" ]]; then
        tables=("${tables[@]/AppExceptions/}")
    fi

    echo "Validating telemetry for $pod_name ($app_type)..."
    if [[ -z "$pod_name" ]]; then
        echo "Pod name is empty. Validation failed for $app_type pod $pod_name."
        exit 1
    fi

    for table in "${tables[@]}"; do
        # Skip empty entries (from removed AppExceptions)
        [[ -z "$table" ]] && continue
        
        query="$table | where TimeGenerated > ago(15m) | where $ROLE_INSTANCE_FIELD == '$pod_name' | count"
        
        json_body="{
            \"query\": \"$query\",
            \"options\": {
                \"truncationMaxSize\": 67108864
            },
            \"maxRows\": 30001,
            \"workspaceFilters\": {
                \"regions\": []
            }
        }"

        echo "Validating $table telemetry for $pod_name ($app_type)..."
        response=$(curl -s -w "\n%{http_code}" -X POST $url \
            -H "Authorization: Bearer $access_token" \
            -H "Content-Type: application/json" \
            -d "$json_body")

        http_code=$(echo "$response" | tail -n 1)
        response_body=$(echo "$response" | sed '$d')

        count_val=$(echo $response_body | jq '.tables[0].rows[0][0]')

        if (( count_val > 0 )); then
            echo "$table telemetry found: $count_val"

            found_any=1
        else
            echo "No $table telemetry found for $pod_name ($app_type) [HTTP $http_code]" >&2
            echo "Validation for $app_type pods failed: No $table telemetry found" >&2
            return 1
        fi
    done
}

max_retries=30
retry_interval=10

for app in "java" "nodejs" "python" "dotnet" "go"; do
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
  elif [ "$app" = "go" ]; then
    pod_name="$POD_GO_NAME"
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
