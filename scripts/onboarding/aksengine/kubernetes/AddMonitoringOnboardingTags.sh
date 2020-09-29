#!/bin/bash
#
# Execute this directly in Azure Cloud Shell (https://shell.azure.com) by pasting (SHIFT+INS on Windows, CTRL+V on Mac or Linux)
# the following line (beginning with curl...) at the command prompt and then replacing the args:
# This script adds the required monitoring onboarding tags like logAnalyticsWorkspaceResourceId and clusterName to the k8s master VMSSes or VMs of the AKS-Engine or ACS-Engine cluster
# in specified group and subscription
# Prerequisites :
#     Azure CLI:  https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
#
#  [Required]  ${1} nameoftheCloud                    name of the cloud where AKS-Engine or ACS-Engine cluster in (AzureCloud or AzureChinaCloud or AzureUSGovernment)
#  [Required]  ${2} subscriptionId                    subscriptionId  of the AKS-Engine or ACS-Engine cluster
#  [Required]  ${3} resourceGroupName                 azure resource group AKS-Engine or ACS-Engine cluster is in
#  [Required]  ${4} logAnalyticsWorkspaceResourceId   azure resource of the Log Analytics. This should be the same as the one configured on the omsAgent of specified acs-engine Kubernetes cluster during agent installation
#  [Required]  ${5} clusterName                       Name of the cluster configured on the omsAgent (for omsagent.env.clusterName) of specified acs-engine Kubernetes cluster
#
#  For example
# https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/aksengine/kubernetes/AddMonitoringOnboardingTags.sh | bash -s "name of the cloud" "00000000-0000-0000-0000-000000000000"  "Resource Group Name of AKS-Engine cluster"  "/subscriptions/<SubscriptionId>/resourceGroups/<resourceGroup>/providers/Microsoft.OperationalInsights/workspaces/<workspaceName>" "clusterName of AKS-Engine cluster"
#

nameoftheCloud=${1}
subscriptionId=${2}
clusterResourceGroup=${3}
workspaceResourceId=${4}
clusterName=${5}

echo "nameoftheCloud"=$nameoftheCloud
echo "subscriptionId"=$subscriptionId
echo "clusterResourceGroup" = $clusterResourceGroup
echo "logAnalyticsWorkspaceResourceId" = $workspaceResourceId
echo "clusterName" = $clusterName

# set the provided cloud name
az cloud set -n $nameoftheCloud

# login
az login

# set subscription of the AKS-Engine or ACS-Engine resource group
az account set -s $subscriptionId

# check whether specified rg exists or not
rg=$(az group show --name $clusterResourceGroup --subscription $subscriptionId)

if [ -z "$rg" ]; then
  echo "resource group does not exist in specified subscription":$clusterResourceGroup
  exit 1
fi

# check whether log analytics workspace resource exists or not
az resource show --ids $workspaceResourceId

# get the all existing k8s master nodes
resources=$(az resource list -g $clusterResourceGroup --resource-type "Microsoft.Compute/virtualMachines" --query "[?starts_with(name,'k8s-master')].id" --output tsv)

if [ -z $resources ]; then
  # if no k8-master nodes, get all k8s-master VMSSes if exists
  resources=$(az resource list -g $clusterResourceGroup --resource-type "Microsoft.Compute/virtualMachineScaleSets" --query "[?starts_with(name,'k8s-master')].id" --output tsv)
fi

if [ -z $resources ]; then
  echo "No k8s-master VMs or VMSSes found in the specified resource group":$clusterResourceGroup
  exit 1
else
  # attach logAnalyticsWorkspaceResourceId and clusterName tags to all K8s master VMs or VMSSes
  for resid in $resources; do
    jsonrtag=$(az resource show --id $resid --query tags)
    rt=$(echo $jsonrtag | tr -d '"{},' | sed 's/: /=/g')
    az resource tag --tags $rt logAnalyticsWorkspaceResourceId=$workspaceResourceId clusterName=$clusterName --id $resid
  done
fi

echo "successfully added required monitoring tags. Please navigate to https://aka.ms/azmon-containers to view and monitor your Kubernetes cluster"
