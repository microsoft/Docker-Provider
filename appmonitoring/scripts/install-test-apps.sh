cat java-test-app.yaml | envsubst | kubectl delete -f -
cat node-test-app.yaml | envsubst | kubectl delete -f -
cat appmonitoring-cr.yaml | envsubst | kubectl delete -f -

echo "Wait for 10s for everything to clear up..."
sleep 10

kubectl create namespace $TEST_NS

cat appmonitoring-cr.yaml | envsubst | kubectl apply -f -
echo "Wait for 10s for CR to be applied and picked up..."
sleep 10

cat java-test-app.yaml | envsubst | kubectl apply -f -
cat node-test-app.yaml | envsubst | kubectl apply -f -

echo "Wait for 60s for charts to be applied..."
sleep 60