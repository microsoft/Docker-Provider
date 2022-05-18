# Container Insights Log collector

This tool will collect:
* agent logs from linux ds and rs pods;
* agent logs from windows pod if enabled;
* cluster/node info, pod deployment, configMap, process logs etc..

## Prerequisites
* kubectl: az aks install-cli
* tar (installed by default)
* all nodes should be running on AKS
* AKS Insights are enabled: https://docs.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-onboard

Otherwise, script will report error message and exit.

## How to run
```
az login --use-device-code # login to azure
az account set --subscription <subscriptionIdOftheCluster>
az aks get-credentials --resource-group <clusterResourceGroup> --name <clusterName> --file ~/ClusterKubeConfig
export KUBECONFIG=~/ClusterKubeConfig

wget https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_dev/scripts/troubleshoot/LogCollection/AgentLogCollection.sh && bash ./AgentLogCollection.sh
```

Output:
```
Preparing for log collection...
Prerequistes check is done, all good
Saving cluster information
cluster info saved to Tool.log
Collecting logs from omsagent-5kwzn...
Defaulted container "omsagent" out of: omsagent, omsagent-prometheus
Complete log collection from omsagent-5kwzn!
Collecting logs from omsagent-win-krcpv, windows pod will take several minutes for log collection, please dont exit forcely...
If your log size are too large, log collection of windows node may fail. You can reduce log size by re-creating windows pod 
Complete log collection from omsagent-win-krcpv!
Collecting logs from omsagent-rs-6fc95c45cf-qjsdb...
Complete log collection from omsagent-rs-6fc95c45cf-qjsdb!
Collecting onboard logs...
configMap named container-azm-ms-agentconfig is not found, if you created configMap for omsagent, please use command to save your custom configMap of omsagent: kubectl get configmaps <configMap name> --namespace=kube-system -o yaml > configMap.yaml
Complete onboard log collection!

Archiving logs...
log files have been written to AKSInsights-logs.1649655490.ubuntu1804.tgz in current folder
```
