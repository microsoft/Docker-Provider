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
    envVariables=$(jq -r '.spec.template.spec.containers[0].env' <<< $DEPLOYMENT)
    echo "Checking for Expected Environment Variables in deployment $deploymentName"
    for expectedVar in "${EXPECTED_ENV_VARS[@]}"; do
        currentVar=$(echo "$envVariables" | jq -r --arg var "$expectedVar" '.[] | select(.name == $var)')

        if [[ -n "$currentVar" ]]; then
            echo "Found expected env var: $expectedVar"
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
            echo "Found expected init container: $initContainer"
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
