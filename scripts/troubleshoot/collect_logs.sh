#!/bin/bash


# This script pulls logs from the replicaset agent pod and a random daemonset pod. This script is to make troubleshooting faster

export ds_pod=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name | grep -E omsagent-[a-z0-9]{5} | head -n 1)
export ds_win_pod=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name | grep -E omsagent-win-[a-z0-9]{5} | head -n 1)
export rs_pod=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name | grep -E omsagent-rs-[a-z0-9]{5} | head -n 1)

echo "collecting logs from ${ds_pod}, ${ds_win_pod}, and ${rs_pod}"
echo "    note: some erros are expected for clusters without windows nodes, they can safely be disregarded (filespec must match the canonical format:, zip warning: name not matched: omsagent-win-daemonset-fbit)"

kubectl cp ${ds_pod}:/var/opt/microsoft/docker-cimprov/log omsagent-daemonset --namespace=kube-system --container omsagent
kubectl cp ${ds_pod}:/var/opt/microsoft/linuxmonagent/log omsagent-daemonset-mdsd --namespace=kube-system --container omsagent

kubectl cp ${ds_pod}:/var/opt/microsoft/docker-cimprov/log omsagent-prom-daemonset --namespace=kube-system --container omsagent-prometheus
kubectl cp ${ds_pod}:/var/opt/microsoft/linuxmonagent/log omsagent-prom-daemonset-mdsd --namespace=kube-system --container omsagent-prometheus

# for some reason copying logs out of /etc/omsagentwindows doesn't work (gives a permission error), but exec then cat does work.
# skip collecting these logs for now, would be good to come back and fix this next time a windows support case comes up
# kubectl cp ${ds_win_pod}:/etc/omsagentwindows omsagent-win-daemonset --namespace=kube-system
kubectl cp ${ds_win_pod}:/etc/fluent-bit omsagent-win-daemonset-fbit --namespace=kube-system

kubectl cp ${rs_pod}:/var/opt/microsoft/docker-cimprov/log omsagent-replicaset --namespace=kube-system
kubectl cp ${rs_pod}:/var/opt/microsoft/linuxmonagent/log omsagent-replicaset-mdsd --namespace=kube-system

zip -r azure-monitor-logs.zip omsagent-daemonset omsagent-daemonset-mdsd omsagent-prom-daemonset omsagent-prom-daemonset-mdsd omsagent-win-daemonset-fbit omsagent-replicaset omsagent-replicaset-mdsd

rm -rf omsagent-daemonset omsagent-daemonset-mdsd omsagent-prom-daemonset omsagent-prom-daemonset-mdsd omsagent-win-daemonset-fbit omsagent-replicaset omsagent-replicaset-mdsd

echo
echo "log files have been written to azure-monitor-logs.zip"
