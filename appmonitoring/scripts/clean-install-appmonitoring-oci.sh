#!/bin/bash

# This script uninstalls the existing app-monitoring release and reinstalls it using the provided image tag from OCI registry.

IMAGE_TAG=$1
namespace=kube-system
secrets_installer_job=app-monitoring-secrets-installer
webhook_deployment=app-monitoring-webhook
TEST_CHART_REPO=${CHART_REPO:-appmonitoringaddontestacr.azurecr.io/test/azuremonitor/applicationinsights/helm}
TEST_CHART_VERSION=${CHART_VERSION}

if [[ -z "$TEST_CHART_VERSION" ]]; then
  echo "Error: TEST_CHART_VERSION must be set"
  exit 1
fi

if [[ -z "$TEST_IMAGE_RELATIVE_PATH" ]]; then
  echo "Error: TEST_IMAGE_RELATIVE_PATH must be set"
  exit 1
fi

echo "Image Tag: $IMAGE_TAG"
echo "Chart Repo: $TEST_CHART_REPO"
echo "Chart Version: $TEST_CHART_VERSION"
echo "Test Image Relative Path: $TEST_IMAGE_RELATIVE_PATH"

echo "Uninstalling appmonitoring extension helm..."
if ! helm uninstall -n kube-system appmonitoring-extension --ignore-not-found; then
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

echo "Installing appmonitoring extension from OCI with image tag: $IMAGE_TAG"
if ! helm install -n kube-system appmonitoring-extension oci://${TEST_CHART_REPO}/appmonitoring-extension --version ${TEST_CHART_VERSION} \
  -f ./oci-values.yaml \
  --set AppmonitoringAgent.imageTag=$IMAGE_TAG \
  --set AppmonitoringAgent.imageRelativePath=$TEST_IMAGE_RELATIVE_PATH; then
  echo "Error: helm install from OCI failed."
  exit 1
fi
echo "helm Installation from OCI complete."
