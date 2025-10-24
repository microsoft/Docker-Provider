# Delete existing test apps if they exist (installed via Helm/OCI)
if [ -z "${TEST_APP_SOURCE_NAME}" ]; then
  echo "Error: TEST_APP_SOURCE_NAME environment variable is required"
  exit 1
fi

if [ -z "${JAVA_TEST_APP_NAME}" ]; then
  echo "Error: JAVA_TEST_APP_NAME environment variable is required"
  exit 1
fi

if [ -z "${NODEJS_TEST_APP_NAME}" ]; then
  echo "Error: NODEJS_TEST_APP_NAME environment variable is required"
  exit 1
fi

if [ -z "${PYTHON_TEST_APP_NAME}" ]; then
  echo "Error: PYTHON_TEST_APP_NAME environment variable is required"
  exit 1
fi

if [ -z "${DOTNET_TEST_APP_NAME}" ]; then
  echo "Error: DOTNET_TEST_APP_NAME environment variable is required"
  exit 1
fi

if [ -z "${NODEJS_CALLER_APP_NAME}" ]; then
  echo "Error: NODEJS_CALLER_APP_NAME environment variable is required"
  exit 1
fi

SOURCE_RELEASE_NAME=${TEST_APP_SOURCE_NAME}
JAVA_RELEASE_NAME=${JAVA_TEST_APP_NAME}
NODEJS_RELEASE_NAME=${NODEJS_TEST_APP_NAME}
PYTHON_RELEASE_NAME=${PYTHON_TEST_APP_NAME}
DOTNET_RELEASE_NAME=${DOTNET_TEST_APP_NAME}
CALLER_RELEASE_NAME=${NODEJS_CALLER_APP_NAME}

JAVA_SERVICE_HOST="${JAVA_RELEASE_NAME}-service.${TEST_NS}.svc.cluster.local"
NODEJS_SERVICE_HOST="${NODEJS_RELEASE_NAME}-service.${TEST_NS}.svc.cluster.local"
PYTHON_SERVICE_HOST="${PYTHON_RELEASE_NAME}-service.${TEST_NS}.svc.cluster.local"
DOTNET_SERVICE_HOST="${DOTNET_RELEASE_NAME}-service.${TEST_NS}.svc.cluster.local"
SOURCE_SERVICE_URL="http://${SOURCE_RELEASE_NAME}-service.${TEST_NS}.svc.cluster.local:3001"

# Delete existing test apps if they exist - TEMPORARY - WILL BE REMOVED LATER
cat ../validation-helm/test-apps/testappsource/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/java/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/nodejs/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/python/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/dotnet/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/testappcaller/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found


echo "Uninstalling test apps..."
helm uninstall -n ${TEST_NS} "${SOURCE_RELEASE_NAME}" --ignore-not-found 2>/dev/null || true
helm uninstall -n ${TEST_NS} "${JAVA_RELEASE_NAME}" --ignore-not-found 2>/dev/null || true
helm uninstall -n ${TEST_NS} "${NODEJS_RELEASE_NAME}" --ignore-not-found 2>/dev/null || true
helm uninstall -n ${TEST_NS} "${PYTHON_RELEASE_NAME}" --ignore-not-found 2>/dev/null || true
helm uninstall -n ${TEST_NS} "${DOTNET_RELEASE_NAME}" --ignore-not-found 2>/dev/null || true
helm uninstall -n ${TEST_NS} "${CALLER_RELEASE_NAME}" --ignore-not-found 2>/dev/null || true


echo "Wait for 20s for everything to clear up..."
sleep 20

kubectl create namespace $TEST_NS

cat appmonitoring-cr.yaml | envsubst | kubectl apply -f -
echo "Wait for 10s for CR to be applied and picked up..."
sleep 10

# ACR and chart version
CHART_VERSION="0.1.0"
echo "Installing test apps from OCI registry..."

# This app will be called by all the instrumented test apps to generate dependency telemetry for us to test
echo "Installing ${SOURCE_RELEASE_NAME}..."
if ! helm install "${SOURCE_RELEASE_NAME}" oci://${ACR_NAME}/helm/testapps/testappsource --version ${CHART_VERSION} -n ${TEST_NS} \
  --set appName=${SOURCE_RELEASE_NAME}; then
  echo "Error: ${SOURCE_RELEASE_NAME} installation failed"
  exit 1
fi

# this is the instrumented java app
echo "Installing ${JAVA_RELEASE_NAME}..."
if ! helm install "${JAVA_RELEASE_NAME}" oci://${ACR_NAME}/helm/testapps/java-test-app --version ${CHART_VERSION} -n ${TEST_NS} \
  --set appName=${JAVA_RELEASE_NAME} \
  --set image=${JAVA_TEST_IMAGE_NAME} \
  --set-string targetUrl=${SOURCE_SERVICE_URL}; then
  echo "Error: ${JAVA_RELEASE_NAME} installation failed"
  exit 1
fi

# this is the instrumented nodejs app
echo "Installing ${NODEJS_RELEASE_NAME}..."
if ! helm install "${NODEJS_RELEASE_NAME}" oci://${ACR_NAME}/helm/testapps/nodejs-test-app --version ${CHART_VERSION} -n ${TEST_NS} \
  --set appName=${NODEJS_RELEASE_NAME} \
  --set image=${NODEJS_TEST_IMAGE_NAME} \
  --set-string targetUrl=${SOURCE_SERVICE_URL}; then
  echo "Error: ${NODEJS_RELEASE_NAME} installation failed"
  exit 1
fi

# this is the instrumented python app
echo "Installing ${PYTHON_RELEASE_NAME}..."
if ! helm install "${PYTHON_RELEASE_NAME}" oci://${ACR_NAME}/helm/testapps/python-test-app --version ${CHART_VERSION} -n ${TEST_NS} \
  --set appName=${PYTHON_RELEASE_NAME} \
  --set image=${PYTHON_TEST_IMAGE_NAME} \
  --set-string targetUrl=${SOURCE_SERVICE_URL}; then
  echo "Error: ${PYTHON_RELEASE_NAME} installation failed"
  exit 1
fi

# this is the instrumented dotnet app
echo "Installing ${DOTNET_RELEASE_NAME}..."
if ! helm install "${DOTNET_RELEASE_NAME}" oci://${ACR_NAME}/helm/testapps/dotnet-test-app --version ${CHART_VERSION} -n ${TEST_NS} \
  --set appName=${DOTNET_RELEASE_NAME} \
  --set image=${DOTNET_TEST_IMAGE_NAME} \
  --set-string targetUrl=${SOURCE_SERVICE_URL}; then
  echo "Error: ${DOTNET_RELEASE_NAME} installation failed"
  exit 1
fi

# this is the app that will periodically call the instrumented apps to generate request telemetry
echo "Installing ${CALLER_RELEASE_NAME}..."
if ! helm install "${CALLER_RELEASE_NAME}" oci://${ACR_NAME}/helm/testapps/testappcaller --version ${CHART_VERSION} -n ${TEST_NS} \
  --set appName=${CALLER_RELEASE_NAME} \
  --set javaHost=${JAVA_SERVICE_HOST} \
  --set nodejsHost=${NODEJS_SERVICE_HOST} \
  --set pythonHost=${PYTHON_SERVICE_HOST} \
  --set dotnetHost=${DOTNET_SERVICE_HOST}; then
  echo "Error: ${CALLER_RELEASE_NAME} installation failed"
  exit 1
fi

echo "All test apps installed successfully!"
