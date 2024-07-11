#!/bin/bash

az account set --subscription 5a3b3ba4-3a42-42ae-b2cb-f882345803bc
az aks get-credentials --resource-group aks-appmonitoring-pipeline --name appmonitoring-webhook-testbed

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

