DEPLOYMENT_deployment#!/bin/bash

# Define the pod name and namespace
DEPLOYMENT_DOTNET_NAME=$1
DEPLOYMENT_JAVA_NAME=$2
DEPLOYMENT_NODEJS_NAME=$3
NAMESPACE=$4

# Define the property to check for
PROPERTY="APPLICATIONINSIGHTS_CONNECTION_STRING"

DOTNET_DEPLOYMENT_NAME=$(kubectl get deployment -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name | grep "$DEPLOYMENT_DOTNET_NAME")
JAVA_DEPLOYMENT_NAME=$(kubectl get deployment -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name | grep "$DEPLOYMENT_JAVA_NAME")
NODEJS_DEPLOYMENT_NAME=$(kubectl get deployment -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name | grep "$DEPLOYMENT_NODEJS_NAME")

checkit() {
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

checkit "$DEPLOYMENT_DOTNET_NAME" 
checkit "$DEPLOYMENT_JAVA_NAME" 
checkit "$DEPLOYMENT_NODEJS_NAME" 
