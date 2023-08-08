#!/bin/bash

## This is to clean up the jobs created by deploy script
## define N value to match with deploy script to clean up the resources created by deploy script

N=5

for ((i=1; i <= N; i++))
do
   kubectl delete ns test"$i"
done

