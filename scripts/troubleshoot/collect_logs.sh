#!/bin/bash

export ds_pod=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name | grep -E omsagent-[a-z0-9]{5} | head -n 1)
export rs_pod=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name | grep -E omsagent-rs-[a-z0-9]{5} | head -n 1)

echo "collecting logs from ${ds_pod} and ${rs_pod}"

kubectl cp ${ds_pod}:/var/opt/microsoft/docker-cimprov/log omsagent-daemonset-log --namespace=kube-system

kubectl cp ${ds_pod}:/var/opt/microsoft/linuxmonagent/log omsagent-daemonset-mdsd-log --namespace=kube-system

kubectl cp ${rs_pod}:/var/opt/microsoft/docker-cimprov/log omsagent-replicaset-log --namespace=kube-system

kubectl cp ${rs_pod}:/var/opt/microsoft/linuxmonagent/log omsagent-replicaset-mdsd-log --namespace=kube-system

zip -r azure-monitor-logs.zip omsagent-daemonset-log omsagent-daemonset-mdsd-log omsagent-replicaset-log omsagent-replicaset-mdsd-log

rm -rf omsagent-daemonset-log omsagent-daemonset-mdsd-log omsagent-replicaset-log omsagent-replicaset-mdsd-log

echo
echo "log files have been written to azure-monitor-logs.zip"
