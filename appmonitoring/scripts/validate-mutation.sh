#!/bin/bash

# Define the pod name and namespace
DEPLOYMENT_JAVA_NAME=$1
DEPLOYMENT_NODEJS_NAME=$2
NAMESPACE=$3

# Define the property to check for
PROPERTY="APPLICATIONINSIGHTS_CONNECTION_STRING"

JAVA_DEPLOYMENT_NAME=$(kubectl get deployment -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name | grep "$DEPLOYMENT_JAVA_NAME")
NODEJS_DEPLOYMENT_NAME=$(kubectl get deployment -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name | grep "$DEPLOYMENT_NODEJS_NAME")

checkMutation() {
    local deploymentName="$1"  # The first argument to the function is stored in 'name'
    DEPLOYMENT_YAML=$(kubectl get deployment "$deploymentName" -n "$NAMESPACE" -o yaml)

    # Check for the property
    if echo "$DEPLOYMENT_YAML" | grep -q "$PROPERTY"; then
        echo "Property $PROPERTY found in deployment $deploymentName"
        # You can add additional commands here to process the property
    else
        echo "Property $PROPERTY not found in pdeploymentod $deploymentName"
    fi
}

checkMutation "$DEPLOYMENT_JAVA_NAME" 
checkMutation "$DEPLOYMENT_NODEJS_NAME" 
