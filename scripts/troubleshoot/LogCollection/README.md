# Container Insights Log Collector

This tool will collect:
* Agent logs from Linux ds (ama-logs-) and rs (ama-logs-rs-) pods
* Agent logs from Windows pod if enabled
* Cluster/node info, pod deployment, configMap, process logs etc.
* Note: Script can collect logs from both AKS Clusters as well as ARO Clusters

## Prerequisites
* kubectl: az aks install-cli
* tar (installed by default)
* All nodes should be on AKS or running ARO
* OpenShift CLI (For ARO Clusters Only) https://learn.microsoft.com/en-us/azure/openshift/tutorial-connect-cluster#install-the-openshift-cli
* Container Insights is enabled: https://docs.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-onboard

Otherwise, script will report error message and exit.

## How to run on AKS Cluster
```
az login --use-device-code # login to azure
az account set --subscription <subscriptionIdOftheCluster>
az aks get-credentials --resource-group <clusterResourceGroup> --name <clusterName> --file ~/ClusterKubeConfig
export KUBECONFIG=~/ClusterKubeConfig

wget https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/troubleshoot/LogCollection/AgentLogCollection.sh && bash ./AgentLogCollection.sh
```

## How to run on ARO Cluster From Azure Cloud Shell
```
#Retrieve server API address
apiServer=$(az aro show -g $RESOURCEGROUP -n $CLUSTER --query apiserverProfile.url -o tsv)

#login
oc login $apiServer -u kubeadmin -p <kubeadmin password>

wget https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/troubleshoot/LogCollection/AgentLogCollection.sh && bash ./AgentLogCollection.sh
```

Output:
```
Preparing for log collection...
Prerequistes check is done, all good
Saving cluster information
cluster info saved to Tool.log
Collecting logs from ama-logs-5kwzn...
Defaulted container "ama-logs" out of: ama-logs, ama-logs-prometheus
Complete log collection from ama-logs-5kwzn!
Collecting logs from ama-logs-windows-krcpv, windows pod will take several minutes for log collection, please dont exit forcely...
If your log size are too large, log collection of windows node may fail. You can reduce log size by re-creating windows pod 
Complete log collection from ama-logs-windows-krcpv!
Collecting logs from ama-logs-rs-6fc95c45cf-qjsdb...
Complete log collection from ama-logs-rs-6fc95c45cf-qjsdb!
Collecting onboard logs...
configMap named container-azm-ms-agentconfig is not found, if you created configMap for ama-logs, please use command to save your custom configMap of ama-logs: kubectl get configmaps <configMap name> --namespace=kube-system -o yaml > configMap.yaml
Complete onboard log collection!

Archiving logs...
log files have been written to AKSInsights-logs.1649655490.ubuntu1804.tgz in current folder
```
