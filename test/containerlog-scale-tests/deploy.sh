#!/bin/bash

## each job generates  1K logs/sec rate
## define N value, 10K logs/sec (each log line size 1KB), N value be 10 and similarly if its 50K logs/sec, N value must be 50
N=5

for ((i=1; i <= N; i++))
do
  kubectl create ns test"$i"
  kubectl apply -f log-generator-job-app.yaml -n test"$i"
done

