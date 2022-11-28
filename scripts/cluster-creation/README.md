# Create Kubernetes Clusters

This document shows various options to run scripts for creating default Kubernetes clusters with basic defaults.

## On-Premises Kubernetes Cluster

On-prem cluster can be created on any VM or physical machine using kind:

```
bash onprem-k8s.sh --cluster-name <name-of-the-cluster>
```


## Azure Kubernetes-Engine Cluster

AKS-Engine is an unmanaged cluster in Azure, and you can use below command to create the cluster in azure:

```

# Either you can reuse existing service principal or create one with below instructions
subscriptionId="<subscription id>"
az account set -s ${subscriptionId}
sp=$(az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/${subscriptionId}")
# get the appId (i.e. clientid) and password (i.e. clientSecret)
echo $sp

clientId=$(echo $sp | jq '.appId')
clientSecret=$(echo $sp | jq '.password')

# create the aks-engine
bash aks-engine.sh --subscription-id "<subscriptionId>" --client-id "<clientId>" --client-secret "<clientSecret>" --dns-prefix "<clusterDnsPrefix>" --location "<location>"
```


## Azure RedHat Openshift v4 Cluster

Azure Redhat Openshift v4 cluster can be created with below command:

> Note: Because of the cleanup policy on internal subscriptions, cluster creation can fail if you dont change cleanup service to none on the subnets of aro vnet before creation.
```
bash aro-v4.sh --subscription-id "<subscriptionId>" --resource-group "<rgName>" --cluster-name "<clusterName>" --location "<location>"
```

### Connecting
To connect to the ARO Kubernetes cluster, follow the [ARO Tutorial - Connect Cluster](https://learn.microsoft.com/en-us/azure/openshift/tutorial-connect-cluster).


## Azure Arc Kubernetes Cluster

You can connect any of the above clusters to Arc via the below command:
```
bash arc-k8s-cluster.sh --subscription-id "<subId>" --resource-group "<rgName>" --cluster-name "<clusterName>" --location "<location>" --kube-context "<contextofexistingcluster>"
```

