#!/bin/bash

# This script uninstalls the existing app-monitoring release and reinstalls it using the provided image tag from OCI registry.

IMAGE_TAG=$1
namespace=kube-system
secrets_installer_job=app-monitoring-secrets-installer
webhook_deployment=app-monitoring-webhook

if [[ -z "$TEST_CHART_REPO" ]]; then
  echo "Error: TEST_CHART_REPO must be set"
  exit 1
fi

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

cd ../validation-helm
echo "Uninstalling appmonitoring addon helm..."
if ! helm uninstall -n kube-system appmonitoring-addon --wait; then
  echo "Error: helm uninstall failed."
else
    echo "Uninstall complete."
fi

echo "Uninstalling app-monitoring extension helm..."
if ! helm uninstall -n kube-system app-monitoring-extension --ignore-not-found --wait; then
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

if ! helm install -n kube-system app-monitoring-extension oci://${TEST_CHART_REPO}/app-monitoring-extension --version ${TEST_CHART_VERSION} \
  --debug \
  --wait \
  --timeout 5m \
  --set Azure.Cluster.Cloud=ValidationCluster \
  --set Azure.Cluster.ResourceId="/subscriptions/5a3b3ba4-3a42-42ae-b2cb-f882345803bc/resourceGroups/aks-appmonitoring-pipeline/providers/Microsoft.ContainerService/managedClusters/appmonitoring-webhook-testbed" \
  --set Azure.Cluster.Region="westus2" \
  --set AppmonitoringAgent.imageTag=$IMAGE_TAG \
  --set AppmonitoringAgent.imageRelativePath=$TEST_IMAGE_RELATIVE_PATH; then
  echo "Error: helm install from OCI failed."
  exit 1
fi
echo "helm Installation from OCI complete."
