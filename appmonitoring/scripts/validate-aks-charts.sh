#!/bin/bash

az account set --subscription 66010356-d8a5-42d3-8593-6aaa3aeb1c11
az aks get-credentials --resource-group aks-appmonitoring-pipeline --name aks-pipeline-validation-ai

DEPLOYMENT=app-monitoring-webhook-deployment
SECRET_STORE=app-monitoring-webhook-cert
MWHC=app-monitoring-webhook
NAMESPACE=kube-system

if kubectl get deployment "$DEPLOYMENT" --namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "Deployment '$DEPLOYMENT' exists in namespace '$NAMESPACE'."
else
    echo "Deployment '$DEPLOYMENT' does not exist in namespace '$NAMESPACE'."
    exit 1
fi

if kubectl get secret "$SECRET_STORE" --namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "Secret '$SECRET_STORE' exists in namespace '$NAMESPACE'."
else
    echo "Secret '$SECRET_STORE' does not exist in namespace '$NAMESPACE'."
    exit 1
fi

if kubectl get mutatingwebhookconfiguration "$MWHC"  >/dev/null 2>&1; then
    echo "Mutating Webhook Configuration '$MWHC' exists."
else
    echo "Mutating Webhook Configuration '$MWHC' does not exist."
    exit 1
fi

