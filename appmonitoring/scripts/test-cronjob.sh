#!/bin/bash

housekeeper_cronjob=appmonitoring-cert-housekeeper-hook
namespace=kube-system

echo "Breaking the secret store..."
kubectl apply -f ../validation-helm/appmonitoring-broken-secret.yaml

echo "Run the housekeeper cronjob now to fix the secret store after being repaired by the cronjob..."
randomString=$(head /dev/urandom | tr -dc a-z0-9 | head -c 5)
test_cronjob_pod=$(echo $housekeeper_cronjob-$randomString)
kubectl create job -n $namespace --from=cronjob/app-monitoring-cert-housekeeper-hook $test_cronjob_pod

echo "Waiting for the cronjob to complete..."

# Wait for the job to finish (up to 60 seconds)
kubectl wait --for=condition=complete job/$test_cronjob_pod -n "$namespace" --timeout=60s

# Check the first pod in that job
completionStatus=$(kubectl get pods -n "$namespace" --selector=job-name=$test_cronjob_pod \
  -o jsonpath='{.items[0].status.phase}')

if [[ "$completionStatus" == "Succeeded" ]]; then
  echo "Pod completed successfully"
else
  echo "Pod is not completed, something went wrong"
  exit 1
fi

kubectl get jobs -n $namespace $test_cronjob_pod
kubectl get pods -n $namespace --selector=job-name=$test_cronjob_pod
echo "Validating the secret store..."
../scripts/validate-certs.sh


echo "Breaking the Mutating Webhook Configuration..."
kubectl apply -f ../validation-helm/appmonitoring-broken-mwhc.yaml

echo "Run the housekeeper cronjob now to fix the Mutating Webhook Configuration..."
test_cronjob_pod=$(echo $housekeeper_cronjob-$randomString-1)
kubectl create job -n $namespace --from=cronjob/app-monitoring-cert-housekeeper-hook $test_cronjob_pod

echo "Waiting for the cronjob to complete..."

# Wait for the job to finish (up to 60 seconds)
kubectl wait --for=condition=complete job/$test_cronjob_pod -n "$namespace" --timeout=60s

# Check the first pod in that job
completionStatus=$(kubectl get pods -n "$namespace" --selector=job-name=$test_cronjob_pod \
  -o jsonpath='{.items[0].status.phase}')

if [[ "$completionStatus" == "Succeeded" ]]; then
  echo "Pod completed successfully"
else
  echo "Pod is not completed, something went wrong"
  exit 1
fi

sleep 10
echo "Validating the Mutating Webhook Configuration after being repaired by the cronjob..."
../scripts/validate-certs.sh