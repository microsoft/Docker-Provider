#!/bin/bash

# Define the pod name and namespace
DEPLOYMENT_JAVA_NAME=$1
DEPLOYMENT_NODEJS_NAME=$2
NAMESPACE=$3

# Define the property to check for
PROPERTY="APPLICATIONINSIGHTS_CONNECTION_STRING"

JAVA_DEPLOYMENT_NAME=$(kubectl get deployment -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name | grep "$DEPLOYMENT_JAVA_NAME")
NODEJS_DEPLOYMENT_NAME=$(kubectl get deployment -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name | grep "$DEPLOYMENT_NODEJS_NAME")
EXPECTED_ENV_VARS=(
  "NODE_NAME"
  "POD_NAMESPACE"
  "POD_NAME"
  "POD_UID"
  "OTEL_RESOURCE_ATTRIBUTES"
  "AKS_ARM_NAMESPACE_ID"
  "APPLICATIONINSIGHTS_CONNECTION_STRING"
  "JAVA_TOOL_OPTIONS"
  "APPLICATIONINSIGHTS_INSTRUMENTATION_LOGGING_ENABLED"
  "NODE_OPTIONS"
  "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT"
)

EXPECTED_INIT_CONTAINERS=(
    "azure-monitor-auto-instrumentation-java"
    "azure-monitor-auto-instrumentation-nodejs"
)

checkMutation() {
    local deploymentName="$1"  # The first argument to the function is stored in 'name'
    echo "Checking deployment: $deploymentName"
    DEPLOYMENT=$(kubectl get deployment "$deploymentName" -n "$NAMESPACE" -o json)
    
    # Check if deployment pods are running and ready
    echo "Checking if pods for deployment $deploymentName are running and ready..."
    rollout_status=$(kubectl rollout status deployment "$deploymentName" -n "$NAMESPACE" --timeout=60s)
    if [[ $? -ne 0 ]]; then
        echo "FATAL ERROR: Deployment $deploymentName is not successfully rolled out."
        echo "$rollout_status"
        exit 1
    fi
    pod_status=$(kubectl get pods -n "$NAMESPACE" -l app="$deploymentName" -o json)
    not_ready=$(echo "$pod_status" | jq '[.items[] | select(.status.phase != "Running" or (.status.containerStatuses[]?.ready != true))] | length')
    if [[ "$not_ready" -ne 0 ]]; then
        echo "FATAL ERROR: One or more pods for deployment $deploymentName are not running and ready."
        kubectl describe pods -n "$NAMESPACE" -l app="$deploymentName"
        exit 1
    else
        echo "All pods for deployment $deploymentName are running and ready."
    fi

    envVariables=$(jq -r '.spec.template.spec.containers[0].env' <<< $DEPLOYMENT)
    echo "Checking for Expected Environment Variables in deployment $deploymentName"
    for expectedVar in "${EXPECTED_ENV_VARS[@]}"; do
        currentVar=$(echo "$envVariables" | jq -r --arg var "$expectedVar" '.[] | select(.name == $var)')

        if [[ -n "$currentVar" ]]; then
            echo "Success! Found expected env var: $expectedVar"
        else
            echo "FATAL ERROR: Expected env var $expectedVar not found in deployment $deploymentName"
            exit 1
        fi
    done

    echo "Checking for Expected Init Containers in deployment $deploymentName"
    initContainers=$(jq -r '.spec.template.spec.initContainers' <<< $DEPLOYMENT)
    for initContainer in "${EXPECTED_INIT_CONTAINERS[@]}"; do
        currentInitContainer=$(echo "$initContainers" | jq -r --arg container "$initContainer" '.[] | select(.name == $container)')
        if [[ -n "$currentInitContainer" ]]; then
            echo "Success! Found expected init container: $initContainer"
        else
            echo "FATAL ERROR: Expected init container $initContainer not found in deployment $deploymentName"
            exit 1
        fi
    done
    
}

if ! checkMutation "$DEPLOYMENT_JAVA_NAME"; then
    echo "FATAL ERROR: checkMutation failed for $DEPLOYMENT_JAVA_NAME"
    exit 1
fi

if ! checkMutation "$DEPLOYMENT_NODEJS_NAME"; then
    echo "FATAL ERROR: checkMutation failed for $DEPLOYMENT_NODEJS_NAME"
    exit 1
fi
