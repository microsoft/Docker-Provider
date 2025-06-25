# Delete existing test apps if they exist
cat ../validation-helm/test-apps/testappsource/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/java/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/nodejs/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/python/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/dotnet/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found
cat ../validation-helm/test-apps/testappcaller/chart.yaml | envsubst | kubectl delete -f - --ignore-not-found


echo "Wait for 20s for everything to clear up..."
sleep 20

kubectl create namespace $TEST_NS

cat appmonitoring-cr.yaml | envsubst | kubectl apply -f -
echo "Wait for 10s for CR to be applied and picked up..."
sleep 10

# This app will be called by all the instrumented test apps to generate dependency telemtry for us to test
cat ../validation-helm/test-apps/testappsource/chart.yaml | envsubst | kubectl apply -f -

# this is the instrumented java app
cat ../validation-helm/test-apps/java/chart.yaml | envsubst | kubectl apply -f -

# this is the instrumented nodejs app
cat ../validation-helm/test-apps/nodejs/chart.yaml | envsubst | kubectl apply -f -

# this is the instrumented python app
cat ../validation-helm/test-apps/python/chart.yaml | envsubst | kubectl apply -f -

# this is the instrumented dotnet app
cat ../validation-helm/test-apps/dotnet/chart.yaml | envsubst | kubectl apply -f -

# this is the app that will periodically call the instrumented apps to generate request telemetry
cat ../validation-helm/test-apps/testappcaller/chart.yaml | envsubst | kubectl apply -f -
