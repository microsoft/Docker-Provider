#!/bin/bash

# This script uninstalls the existing app-monitoring release and reinstalls it using the provided image tag.

IMAGE_TAG=$1
namespace=kube-system
secrets_installer_job=app-monitoring-secrets-installer
webhook_deployment=app-monitoring-webhook


echo $IMAGE_TAG 

cd ../validation-helm
echo "Uninstalling appmonitoring addon helm..."
if ! helm uninstall -n kube-system appmonitoring-addon; then
  echo "Error: helm uninstall failed."
else
    echo "Uninstall complete."
fi

echo "Deleting appmonitoring CRD..."
if ! kubectl delete -f ./app-monitoring-addon/crds/app-monitoring-crd-v2.yaml; then
  echo "Error: CRD deletion failed."
else
    echo "CRD deletion complete."
fi

echo "Installing appmonitoring addon with image tag: $IMAGE_TAG"
if ! helm install -n kube-system appmonitoring-addon ./app-monitoring-addon --set AppmonitoringAgent.imageTag=$IMAGE_TAG --set AppmonitoringAgent.replicas=2; then
  echo "Error: helm install failed."
  exit 1
fi
echo "helm Installation  complete."
