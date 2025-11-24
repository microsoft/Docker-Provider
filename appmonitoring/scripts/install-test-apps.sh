#!/bin/bash

set -euo pipefail

require_env() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "Error: ${name} environment variable is required"
    exit 1
  fi
}

# Delete existing test apps if they exist (installed via Helm/OCI)
require_env TEST_NS
require_env ACR_NAME
require_env TEST_APP_SOURCE_NAME
require_env JAVA_TEST_APP_NAME
require_env NODEJS_TEST_APP_NAME
require_env PYTHON_TEST_APP_NAME
require_env DOTNET_TEST_APP_NAME
require_env GO_TEST_APP_NAME
require_env NODEJS_CALLER_APP_NAME
require_env JAVA_TEST_IMAGE_NAME
require_env NODEJS_TEST_IMAGE_NAME
require_env PYTHON_TEST_IMAGE_NAME
require_env DOTNET_TEST_IMAGE_NAME
require_env GO_TEST_IMAGE_NAME

if ! command -v envsubst >/dev/null 2>&1; then
  echo "Error: envsubst command not found"
  exit 1
fi

CHART_VERSION="${CHART_VERSION:-0.1.0}"

SOURCE_RELEASE_NAME=${TEST_APP_SOURCE_NAME}
JAVA_RELEASE_NAME=${JAVA_TEST_APP_NAME}
NODEJS_RELEASE_NAME=${NODEJS_TEST_APP_NAME}
PYTHON_RELEASE_NAME=${PYTHON_TEST_APP_NAME}
DOTNET_RELEASE_NAME=${DOTNET_TEST_APP_NAME}
GO_RELEASE_NAME=${GO_TEST_APP_NAME}
CALLER_RELEASE_NAME=${NODEJS_CALLER_APP_NAME}

JAVA_SERVICE_HOST="${JAVA_RELEASE_NAME}-service.${TEST_NS}.svc.cluster.local"
NODEJS_SERVICE_HOST="${NODEJS_RELEASE_NAME}-service.${TEST_NS}.svc.cluster.local"
PYTHON_SERVICE_HOST="${PYTHON_RELEASE_NAME}-service.${TEST_NS}.svc.cluster.local"
DOTNET_SERVICE_HOST="${DOTNET_RELEASE_NAME}-service.${TEST_NS}.svc.cluster.local"
GO_SERVICE_HOST="${GO_RELEASE_NAME}-service.${TEST_NS}.svc.cluster.local"
SOURCE_SERVICE_URL="http://${SOURCE_RELEASE_NAME}-service.${TEST_NS}.svc.cluster.local:3001"

# Delete existing test apps if they exist - TEMPORARY - WILL BE REMOVED LATER
cat ../validation-helm/test-apps/testappsource/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/java/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/nodejs/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/python/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/dotnet/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/go-instrumented/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/testappcaller/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found


echo "Uninstalling test apps..."
helm uninstall -n ${TEST_NS} "${SOURCE_RELEASE_NAME}" --ignore-not-found --wait 2>/dev/null || true
helm uninstall -n ${TEST_NS} "${JAVA_RELEASE_NAME}" --ignore-not-found --wait 2>/dev/null || true
helm uninstall -n ${TEST_NS} "${NODEJS_RELEASE_NAME}" --ignore-not-found --wait 2>/dev/null || true
helm uninstall -n ${TEST_NS} "${PYTHON_RELEASE_NAME}" --ignore-not-found --wait 2>/dev/null || true
helm uninstall -n ${TEST_NS} "${DOTNET_RELEASE_NAME}" --ignore-not-found --wait 2>/dev/null || true
helm uninstall -n ${TEST_NS} "${GO_RELEASE_NAME}" --ignore-not-found --wait 2>/dev/null || true
helm uninstall -n ${TEST_NS} "${CALLER_RELEASE_NAME}" --ignore-not-found --wait 2>/dev/null || true


echo "Wait for 20s for everything to clear up..."
sleep 20

if ! kubectl get namespace "${TEST_NS}" >/dev/null 2>&1; then
  kubectl create namespace "${TEST_NS}"
fi

cat appmonitoring-cr.yaml | envsubst | kubectl apply -f -
echo "Wait for 10s for CR to be applied and picked up..."
sleep 10

# ACR and chart version
echo "Installing test apps from OCI registry..."

# This app will be called by all the instrumented test apps to generate dependency telemetry for us to test
echo "Installing ${SOURCE_RELEASE_NAME}..."
if ! helm install "${SOURCE_RELEASE_NAME}" oci://${ACR_NAME}/helm/testapps/testappsource --version "${CHART_VERSION}" -n "${TEST_NS}" \
  --set-string appName="${SOURCE_RELEASE_NAME}" \
  --wait --timeout 5m; then
  echo "Error: ${SOURCE_RELEASE_NAME} installation failed"
  exit 1
fi

# this is the instrumented java app
echo "Installing ${JAVA_RELEASE_NAME}..."
if ! helm install "${JAVA_RELEASE_NAME}" oci://${ACR_NAME}/helm/testapps/java-test-app --version "${CHART_VERSION}" -n "${TEST_NS}" \
  --set-string appName="${JAVA_RELEASE_NAME}" \
  --set-string image="${JAVA_TEST_IMAGE_NAME}" \
  --set-string targetUrl="${SOURCE_SERVICE_URL}" \
  --wait --timeout 5m; then
  echo "Error: ${JAVA_RELEASE_NAME} installation failed"
  exit 1
fi

# this is the instrumented nodejs app
echo "Installing ${NODEJS_RELEASE_NAME}..."
if ! helm install "${NODEJS_RELEASE_NAME}" oci://${ACR_NAME}/helm/testapps/nodejs-test-app --version "${CHART_VERSION}" -n "${TEST_NS}" \
  --set-string appName="${NODEJS_RELEASE_NAME}" \
  --set-string image="${NODEJS_TEST_IMAGE_NAME}" \
  --set-string targetUrl="${SOURCE_SERVICE_URL}" \
  --wait --timeout 5m; then
  echo "Error: ${NODEJS_RELEASE_NAME} installation failed"
  exit 1
fi

# this is the instrumented python app
echo "Installing ${PYTHON_RELEASE_NAME}..."
if ! helm install "${PYTHON_RELEASE_NAME}" oci://${ACR_NAME}/helm/testapps/python-test-app --version "${CHART_VERSION}" -n "${TEST_NS}" \
  --set-string appName="${PYTHON_RELEASE_NAME}" \
  --set-string image="${PYTHON_TEST_IMAGE_NAME}" \
  --set-string targetUrl="${SOURCE_SERVICE_URL}" \
  --wait --timeout 5m; then
  echo "Error: ${PYTHON_RELEASE_NAME} installation failed"
  exit 1
fi

# this is the instrumented dotnet app
echo "Installing ${DOTNET_RELEASE_NAME}..."
if ! helm install "${DOTNET_RELEASE_NAME}" oci://${ACR_NAME}/helm/testapps/dotnet-test-app --version "${CHART_VERSION}" -n "${TEST_NS}" \
  --set-string appName="${DOTNET_RELEASE_NAME}" \
  --set-string image="${DOTNET_TEST_IMAGE_NAME}" \
  --set-string targetUrl="${SOURCE_SERVICE_URL}" \
  --wait --timeout 5m; then
  echo "Error: ${DOTNET_RELEASE_NAME} installation failed"
  exit 1
fi

# this is the instrumented go app
echo "Installing ${GO_RELEASE_NAME}..."
if ! helm install "${GO_RELEASE_NAME}" oci://${ACR_NAME}/helm/testapps/go-instrumented-test-app --version "${CHART_VERSION}" -n "${TEST_NS}" \
  --set-string appName="${GO_RELEASE_NAME}" \
  --set-string image="${GO_TEST_IMAGE_NAME}" \
  --set-string targetUrl="${SOURCE_SERVICE_URL}" \
  --wait --timeout 5m; then
  echo "Error: ${GO_RELEASE_NAME} installation failed"
  exit 1
fi

# this is the app that will periodically call the instrumented apps to generate request telemetry
echo "Installing ${CALLER_RELEASE_NAME}..."
if ! helm install "${CALLER_RELEASE_NAME}" oci://${ACR_NAME}/helm/testapps/testappcaller --version "${CHART_VERSION}" -n "${TEST_NS}" \
  --set-string appName="${CALLER_RELEASE_NAME}" \
  --set-string javaHost="${JAVA_SERVICE_HOST}" \
  --set-string nodejsHost="${NODEJS_SERVICE_HOST}" \
  --set-string pythonHost="${PYTHON_SERVICE_HOST}" \
  --set-string dotnetHost="${DOTNET_SERVICE_HOST}" \
  --set-string goHost="${GO_SERVICE_HOST}" \
  --wait --timeout 5m; then
  echo "Error: ${CALLER_RELEASE_NAME} installation failed"
  exit 1
fi

echo "All test apps installed successfully!"
