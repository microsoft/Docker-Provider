#!/bin/bash
#
# Execute this directly in Azure Cloud Shell (https://shell.azure.com) by pasting (SHIFT+INS on Windows, CTRL+V on Mac or Linux)
# the following line (beginning with curl...) at the command prompt and then replacing the args:
#  This scripts Onboards AKS cluster to mdm alerts private preview
#      1. Installs Azure Monitor for containers mdm alerts private preview HELM chart to the K8s cluster in Kubeconfig
#      2. Associates cluster with the LA workspace
# Prerequisites :
#     Azure CLI:  https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
#     Helm3 : https://helm.sh/docs/intro/install/
#
# bash onboarding_azuremonitor_for_containers.sh <azureSubscriptionId of the cluster> <azureRegionforLogAnalyticsWorkspace> <clusterName> <kubeconfigContextNameOftheCluster>
# For example:
# bash ./cluster-ws-link.sh 00000000-0000-0000-0000-000000000000 <clusterResourceId> <wsResourceId>

if [ $# -le 2 ]
then
  echo "Error: This should be invoked with 6 arguments - clustersubscriptionId, clusterResourceId, workspaceSubscriptionId, workspaceResourceId"
  exit 1
fi

echo "clusterSubscriptionId:"${1}
echo "clusterResourceId:"${2}
echo "workspaceSubscriptionId:" ${3}
echo "workspaceResourceId:" ${4}

clusterSubscriptionId=${1}
clusterResourceId=${2}
workspaceSubscriptionId=${3}
workspaceResourceId=${4}


echo "Set AzureCloud as active cloud for az cli"
az cloud set -n AzureCloud

echo "login to the azure interactively"
az login

echo "setting the subscription id of the cluster: ${clusterSubscriptionId}"
az account set -s ${clusterSubscriptionId}

echo "getting cluster resource group"
export clusterResourceGroup=$(az resource show --ids $clusterResourceId --query resourceGroup)
clusterResourceGroup=$(echo $clusterResourceGroup | tr -d '"')
echo $clusterResourceGroup

echo "getting cluster name"
export clusterName=$(az resource show --ids $clusterResourceId --query name)
clusterName=$(echo $clusterName | tr -d '"')
echo $clusterName

echo "Disabling monitoring on the cluster"
az aks disable-addons -a monitoring -g $clusterResourceGroup -n $clusterName

echo "setting the subscription id of the workspace: ${workspaceSubscriptionId}"
az account set -s ${workspaceSubscriptionId}

echo "getting workspace Guid"
export workspaceGuid=$(az resource show --ids $workspaceResourceId --resource-type Microsoft.OperationalInsights/workspaces --query properties.customerId)
workspaceGuid=$(echo $workspaceGuid | tr -d '"')
echo $workspaceGuid | base64

echo "getting workspace primaryshared key"
workspaceKey=$(az rest --method post --uri $workspaceResourceId/sharedKeys?api-version=2015-11-01-preview --query primarySharedKey)
workspaceKey=$(echo $workspaceKey | tr -d '"')
echo $workspaceKey | base64

# echo "installing Azure Monitor for containers HELM chart for MDM alerts preview..."

# echo "adding azmon-preview repo"
# # helm repo add ci-mdm-alert https://rashmichandrashekar.github.io/azure-monitor-containers-helm-chart-private/
# helm repo add ci-mdm-alert https://github.com/rashmichandrashekar/azure-monitor-containers-helm-charts-private/blob/master
# echo "updating helm repo to get latest charts"
# helm repo update

# helm upgrade azmon-containers-ci-mdm-alert ci-mdm-alert/azuremonitor-containers --install --set amalogs.secret.wsid=$workspaceGuid,amalogs.secret.key=$workspaceKey,amalogs.env.clusterId=${3},amalogs.env.clusterRegion=${4} --kubeconfig ${6}
# echo "chart installation completed."

echo "setting the subscription id of the cluster: ${clusterSubscriptionId}"
az account set -s ${clusterSubscriptionId}

echo "getting cluster object"
clusterGetResponse=$(az rest --method get --uri "${clusterResourceId}?api-version=2026-07-01") || exit 1

printf '%s\n' "$clusterGetResponse" | jq -e --arg workspaceResourceId "$workspaceResourceId" \
  'if (.properties.azureMonitorProfile.containerInsights.enabled | type) == "boolean" then
     .properties.azureMonitorProfile.containerInsights.logAnalyticsWorkspaceResourceId = $workspaceResourceId
   else error("Cluster has no valid Container Insights profile") end' > putrequestbody.json || exit 1

az rest --method put --uri "${clusterResourceId}?api-version=2026-07-01" --body @putrequestbody.json --headers Content-Type=application/json