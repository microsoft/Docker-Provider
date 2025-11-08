#!/bin/bash

AMW_QUERY_ENDPOINT=$1
NAMESPACE=$2
APPS_TO_VALIDATE=$3  # Comma-separated list of apps (e.g., "java,nodejs,python,dotnet" or "go")
shift 3  # Remove first 3 arguments

# Validate that required parameters are provided
if [[ -z "$AMW_QUERY_ENDPOINT" ]]; then
    echo "Error: AMW_QUERY_ENDPOINT parameter is required (1st argument)" >&2
    echo "Usage: $0 <AMW_QUERY_ENDPOINT> <NAMESPACE> <APPS_TO_VALIDATE>" >&2
    exit 1
fi

if [[ -z "$APPS_TO_VALIDATE" ]]; then
    echo "Error: APPS_TO_VALIDATE parameter is required (3rd argument)" >&2
    echo "Usage: $0 <AMW_QUERY_ENDPOINT> <NAMESPACE> <APPS_TO_VALIDATE>" >&2
    exit 1
fi

echo "Finding pods in namespace: $NAMESPACE for Java App $JAVA_TEST_APP_NAME, NodeJS App $NODEJS_TEST_APP_NAME, Python App $PYTHON_TEST_APP_NAME, Dotnet App $DOTNET_TEST_APP_NAME, and Go App $GO_TEST_APP_NAME"
POD_JAVA_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$JAVA_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)
POD_NODEJS_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$NODEJS_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)
POD_PYTHON_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$PYTHON_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)
POD_DOTNET_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$DOTNET_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)
POD_GO_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=$GO_TEST_APP_NAME --no-headers -o custom-columns=":metadata.name" | head -n 1)

# Get an access token for Azure Monitor
result_rsp=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://prometheus.monitor.azure.com&mi_res_id=/subscriptions/66010356-d8a5-42d3-8593-6aaa3aeb1c11/resourceGroups/rambhatt-rnd-v2/providers/Microsoft.ManagedIdentity/userAssignedIdentities/rambhatt-agentpool-es-identity' -H Metadata:true -s)
access_token=$(echo $result_rsp | jq -r '.access_token')
client_id=$(echo $result_rsp | jq -r '.client_id')

echo "=========================================="
echo "ACCESS TOKEN DETAILS:"
echo "Using identity with client_id: $client_id"

# Decode JWT token (access_token is in format: header.payload.signature)
# Extract the payload (second part)
token_payload=$(echo "$access_token" | cut -d '.' -f 2)

# Add padding if needed (JWT base64 encoding may not be padded)
padding_length=$((4 - ${#token_payload} % 4))
if [ $padding_length -ne 4 ]; then
    token_payload="${token_payload}$(printf '%*s' $padding_length | tr ' ' '=')"
fi

# Decode the base64 payload
decoded_token=$(echo "$token_payload" | base64 -d 2>/dev/null)

echo "Decoded Token Payload:"
echo "$decoded_token" | jq '.' 2>/dev/null || echo "$decoded_token"
echo "=========================================="
echo ""
echo "AMW Query Endpoint: $AMW_QUERY_ENDPOINT"

verify_amw_metrics() {
    local pod_name="$1"
    local app_type="$2"
    
    echo "Validating AMW metrics for $pod_name ($app_type)..."
    if [[ -z "$pod_name" ]]; then
        echo "Pod name is empty. Validation failed for $app_type pod $pod_name."
        exit 1
    fi

    # Query for cows_sold_total metric with specific pod name
    # Using Prometheus query syntax for Azure Monitor Workspace
    # Using service.instance.id label which typically contains the pod name
    query="cows_sold_total{\"service.instance.id\"=\"$pod_name\"}"
    
    # Calculate time range (last 15 minutes)
    end_time=$(date -u +%s)
    start_time=$((end_time - 900))  # 15 minutes = 900 seconds
    
    echo "=========================================="
    echo "REQUEST DETAILS:"
    echo "Endpoint: $AMW_QUERY_ENDPOINT/api/v1/query"
    echo "Query: $query"
    echo "Time: $end_time ($(date -u -d @$end_time +%Y-%m-%dT%H:%M:%SZ))"
    echo "Time range: $(date -u -d @$start_time +%Y-%m-%dT%H:%M:%SZ) to $(date -u -d @$end_time +%Y-%m-%dT%H:%M:%SZ)"
    echo "Authorization: Bearer <token>"
    echo "=========================================="
    
    # Query the Azure Monitor Workspace for Prometheus metrics
    response=$(curl -s -w "\n%{http_code}" -G "$AMW_QUERY_ENDPOINT/api/v1/query" \
        --data-urlencode "query=$query" \
        --data-urlencode "time=$end_time" \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: application/json")

    http_code=$(echo "$response" | tail -n 1)
    response_body=$(echo "$response" | sed '$d')

    echo "HTTP Status: $http_code"
    
    if [[ "$http_code" != "200" ]]; then
        echo "Failed to query AMW. HTTP Status: $http_code" >&2
        echo "Response: $response_body" >&2
        return 1
    fi

    # Parse the Prometheus response
    status=$(echo "$response_body" | jq -r '.status')
    
    if [[ "$status" != "success" ]]; then
        echo "Query failed with status: $status" >&2
        echo "Response: $response_body" >&2
        return 1
    fi

    # Check if we have results
    result_type=$(echo "$response_body" | jq -r '.data.resultType')
    results_count=$(echo "$response_body" | jq '.data.result | length')
    
    echo "Result type: $result_type, Results count: $results_count"
    
    if [[ "$results_count" -eq 0 ]]; then
        echo "No cows_sold_total metrics found for pod $pod_name ($app_type)" >&2
        echo "Full response: $response_body" >&2
        return 1
    fi

    # Get the metric value
    metric_value=$(echo "$response_body" | jq -r '.data.result[0].value[1]')
    metric_labels=$(echo "$response_body" | jq -c '.data.result[0].metric')
    
    echo "Found cows_sold_total metric for $pod_name ($app_type)"
    echo "  Value: $metric_value"
    echo "  Labels: $metric_labels"
    
    return 0
}

max_retries=30
retry_interval=10

# Convert comma-separated list to array
IFS=',' read -ra APPS_ARRAY <<< "$APPS_TO_VALIDATE"

for app in "${APPS_ARRAY[@]}"; do
  if [ "$app" = "java" ]; then
    pod_name="$POD_JAVA_NAME"
  elif [ "$app" = "nodejs" ]; then
    pod_name="$POD_NODEJS_NAME"
  elif [ "$app" = "python" ]; then
    pod_name="$POD_PYTHON_NAME"
  elif [ "$app" = "dotnet" ]; then
    pod_name="$POD_DOTNET_NAME"
  elif [ "$app" = "go" ]; then
    pod_name="$POD_GO_NAME"
  else
    echo "Unsupported application type: $app"
    exit 1
  fi

  attempt=1
  success=0
  while [ $attempt -le $max_retries ]; do
    echo "Attempt $attempt/$max_retries: Validating AMW metrics for $pod_name ($app)..."
    if verify_amw_metrics "$pod_name" "$app"; then
      echo "AMW metrics validation succeeded for $pod_name ($app)"
      success=1
      break
    else
      echo "AMW metrics validation failed for $pod_name ($app) on attempt $attempt"
      if [ $attempt -eq $max_retries ]; then
        echo "AMW metrics validation failed for $pod_name ($app) after $max_retries attempts"
        exit 1
      fi
      echo "Waiting $retry_interval seconds before retrying..."
      sleep $retry_interval
    fi
    attempt=$((attempt + 1))
  done
done

echo "✓ All AMW metrics validation checks passed!"
