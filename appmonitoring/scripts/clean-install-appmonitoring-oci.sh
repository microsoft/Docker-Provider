#!/bin/bash

# This script uninstalls the existing app-monitoring release and reinstalls it using the provided image tag from OCI registry.

IMAGE_TAG=$1
namespace=kube-system
secrets_installer_job=app-monitoring-secrets-installer
webhook_deployment=app-monitoring-webhook
ACR_NAME=${ACR_NAME:-appmonitoringaddontestacr.azurecr.io}
CHART_VERSION=${CHART_VERSION:-1.0.0-beta.7}

echo "Image Tag: $IMAGE_TAG"
echo "ACR: $ACR_NAME"
echo "Chart Version: $CHART_VERSION"

echo "Uninstalling appmonitoring addon helm..."
if ! helm uninstall -n kube-system appmonitoring-addon --ignore-not-found; then
  echo "Error: helm uninstall failed."
else
    echo "Uninstall complete."
fi

echo "Deleting appmonitoring CRD..."
if ! kubectl delete crd instrumentations.azmonitoring.microsoft.com --ignore-not-found; then
  echo "CRD deletion skipped or failed."
else
    echo "CRD deletion complete."
fi

echo "Installing appmonitoring addon from OCI with image tag: $IMAGE_TAG"
if ! helm install -n kube-system appmonitoring-addon oci://${ACR_NAME}/helm/app-monitoring-extension --version ${CHART_VERSION} --set AppmonitoringAgent.imageTag=$IMAGE_TAG --set AppmonitoringAgent.replicas=2; then
  echo "Error: helm install from OCI failed."
  exit 1
fi
echo "helm Installation from OCI complete."
