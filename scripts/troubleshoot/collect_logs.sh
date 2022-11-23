#!/bin/bash

# This script pulls logs from the replicaset agent pod and a random daemonset pod. This script is to make troubleshooting faster

CYAN='\033[0;36m'
NC='\033[0m' # No Color

mkdir azure-monitor-logs-tmp
cd azure-monitor-logs-tmp

export ds_pod=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name | grep -E ama-logs-[a-z0-9]{5} | head -n 1)
export ds_win_pod=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name | grep -E ama-logs-windows-[a-z0-9]{5} | head -n 1)
export rs_pod=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name | grep -E ama-logs-rs-[a-z0-9]{5} | head -n 1)

echo -e "Collecting logs from ${ds_pod}, ${ds_win_pod}, and ${rs_pod}"
echo -e "${CYAN}Note: some errors about pods and files not existing are expected in clusters without windows nodes or sidecar prometheus scraping. They can safely be disregarded ${NC}"

# grab `kubectl describe` and `kubectl log`
echo "collecting kubectl describe and kubectl log output"

kubectl describe pod ${ds_pod} --namespace=kube-system > describe_${ds_pod}.txt
kubectl logs ${ds_pod} --container ama-logs --namespace=kube-system > logs_${ds_pod}.txt
kubectl logs ${ds_pod} --container ama-logs-prometheus --namespace=kube-system > logs_${ds_pod}_prom.txt

kubectl describe pod ${ds_win_pod} --namespace=kube-system > describe_${ds_win_pod}.txt
kubectl logs ${ds_win_pod} --container ama-logs-windows --namespace=kube-system > logs_${ds_win_pod}.txt

kubectl describe pod ${rs_pod} --namespace=kube-system > describe_${rs_pod}.txt
kubectl logs ${rs_pod} --container ama-logs --namespace=kube-system > logs_${rs_pod}.txt


# now collect log files from in containers
echo "Collecting log files from inside agent containers"

kubectl cp ${ds_pod}:/var/opt/microsoft/docker-cimprov/log ama-logs-daemonset --namespace=kube-system --container ama-logs
kubectl cp ${ds_pod}:/var/opt/microsoft/linuxmonagent/log ama-logs-daemonset-mdsd --namespace=kube-system --container ama-logs
kubectl cp ${ds_pod}:/etc/mdsd.d/config-cache/configchunks/ ama-logs-daemonset-dcr --namespace=kube-system --container ama-logs >/dev/null 2>&1

kubectl cp ${ds_pod}:/var/opt/microsoft/docker-cimprov/log ama-logs-prom-daemonset --namespace=kube-system --container ama-logs-prometheus
kubectl cp ${ds_pod}:/var/opt/microsoft/linuxmonagent/log ama-logs-prom-daemonset-mdsd --namespace=kube-system --container ama-logs-prometheus

# for some reason copying logs out of /etc/amalogswindows doesn't work (gives a permission error), but exec then cat does work.
# skip collecting these logs for now, would be good to come back and fix this next time a windows support case comes up
# kubectl cp ${ds_win_pod}:/etc/amalogswindows ama-logs-windows-daemonset --namespace=kube-system
kubectl cp ${ds_win_pod}:/etc/fluent-bit ama-logs-windows-daemonset-fbit --namespace=kube-system

kubectl cp ${rs_pod}:/var/opt/microsoft/docker-cimprov/log ama-logs-replicaset --namespace=kube-system
kubectl cp ${rs_pod}:/var/opt/microsoft/linuxmonagent/log ama-logs-replicaset-mdsd --namespace=kube-system

zip -r -q ../azure-monitor-logs.zip *

cd ..
rm -rf azure-monitor-logs-tmp
echo
echo "log files have been written to azure-monitor-logs.zip"
