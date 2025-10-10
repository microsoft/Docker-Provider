# Delete existing test apps if they exist (installed via Helm/OCI)
echo "Uninstalling test apps..."
helm uninstall -n ${TEST_NS} testappsource --ignore-not-found 2>/dev/null || true
helm uninstall -n ${TEST_NS} java-test-app --ignore-not-found 2>/dev/null || true
helm uninstall -n ${TEST_NS} nodejs-test-app --ignore-not-found 2>/dev/null || true
helm uninstall -n ${TEST_NS} python-test-app --ignore-not-found 2>/dev/null || true
helm uninstall -n ${TEST_NS} dotnet-test-app --ignore-not-found 2>/dev/null || true
helm uninstall -n ${TEST_NS} testappcaller --ignore-not-found 2>/dev/null || true


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
echo "Installing testappsource..."
if ! helm install testappsource oci://${ACR_NAME}/helm/testapps/testappsource --version ${CHART_VERSION} -n ${TEST_NS}; then
  echo "Error: testappsource installation failed"
  exit 1
fi

# this is the instrumented java app
echo "Installing java-test-app..."
if ! helm install java-test-app oci://${ACR_NAME}/helm/testapps/java-test-app --version ${CHART_VERSION} -n ${TEST_NS}; then
  echo "Error: java-test-app installation failed"
  exit 1
fi

# this is the instrumented nodejs app
echo "Installing nodejs-test-app..."
if ! helm install nodejs-test-app oci://${ACR_NAME}/helm/testapps/nodejs-test-app --version ${CHART_VERSION} -n ${TEST_NS}; then
  echo "Error: nodejs-test-app installation failed"
  exit 1
fi

# this is the instrumented python app (if available, skip if not)
echo "Installing python-test-app..."
helm install python-test-app oci://${ACR_NAME}/helm/testapps/python-test-app --version ${CHART_VERSION} -n ${TEST_NS} 2>/dev/null || echo "Python test app not available, skipping..."

# this is the instrumented dotnet app
echo "Installing dotnet-test-app..."
if ! helm install dotnet-test-app oci://${ACR_NAME}/helm/testapps/dotnet-test-app --version ${CHART_VERSION} -n ${TEST_NS}; then
  echo "Error: dotnet-test-app installation failed"
  exit 1
fi

# this is the app that will periodically call the instrumented apps to generate request telemetry
echo "Installing testappcaller..."
if ! helm install testappcaller oci://${ACR_NAME}/helm/testapps/testappcaller --version ${CHART_VERSION} -n ${TEST_NS}; then
  echo "Error: testappcaller installation failed"
  exit 1
fi

echo "All test apps installed successfully!"
