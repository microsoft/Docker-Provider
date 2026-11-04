#!/bin/bash
#
# Execute this directly in Azure Cloud Shell (https://shell.azure.com) by pasting (SHIFT+INS on Windows, CTRL+V on Mac or Linux)
# the following line (beginning with curl...) at the command prompt and then replacing the args:
#  This scripts Onboards AKS cluster to mdm alerts private preview
#      1. Disables monitoring on cluster
#      2. Installs Azure Monitor for containers mdm alerts private preview HELM chart to the K8s cluster in Kubeconfig
#      3. Associates cluster with the LA workspace
# Prerequisites :
#     Azure CLI:  https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
#     Helm3 : https://helm.sh/docs/intro/install/
#
# For example:
# bash private-preview-onboard.sh <clusterResourceId> <workspaceResourceId>

if [ $# -le 1 ]
then
  echo "Error: This should be invoked with 2 arguments - clusterResourceId, workspaceResourceId"
  exit 1
fi

echo "clusterResourceId:"${1}
echo "workspaceResourceId:" ${2}

clusterResourceId=${1}
workspaceResourceId=${2}

clusterSubscriptionId="$(cut -d'/' -f3 <<<$clusterResourceId)"
clusterResourceGroup="$(cut -d'/' -f5 <<<$clusterResourceId)"
clusterName="$(cut -d'/' -f9 <<<$clusterResourceId)"
workspaceSubscriptionId="$(cut -d'/' -f3 <<<$workspaceResourceId)"


echo "Set AzureCloud as active cloud for az cli"
az cloud set -n AzureCloud

echo "setting the subscription id of the cluster: ${clusterSubscriptionId}"
az account set -s ${clusterSubscriptionId}

echo "getting aks cluster credentials"
az aks get-credentials -g $clusterResourceGroup -n $clusterName

echo "getting cluster region"
export clusterRegion=$(az resource show --ids $clusterResourceId --query location)
clusterRegion=$(echo $clusterRegion | tr -d '"')
echo $clusterRegion

echo "getting cluster service principal"
export clusterSP=$(az resource show --ids $clusterResourceId --query properties.servicePrincipalProfile.clientId)
clusterSP=$(echo $clusterSP | tr -d '"')
echo $clusterSP

echo "Disabling monitoring on the cluster"
az aks disable-addons -a monitoring -g $clusterResourceGroup -n $clusterName

echo "Cleaning up resources that are not cleaned up by disable monitoring"
kubectl config use-context $clusterName
kubectl delete serviceaccount ama-logs -n kube-system
kubectl delete clusterrole ama-logs-reader
kubectl delete clusterrolebinding amalogsclusterrolebinding
kubectl delete customresourcedefinition healthstates.azmon.container.insights

echo "Adding permissions to the Service principal"
az role assignment create --assignee $clusterSP --scope $clusterResourceId --role "Monitoring Metrics Publisher"

echo "setting the subscription id of the workspace: ${workspaceSubscriptionId}"
az account set -s ${workspaceSubscriptionId}

echo "getting workspace Guid"
export workspaceGuid=$(az resource show --ids $workspaceResourceId --resource-type Microsoft.OperationalInsights/workspaces --query properties.customerId)
workspaceGuid=$(echo $workspaceGuid | tr -d '"')
echo $workspaceGuid

echo "getting workspace primaryshared key"
workspaceKey=$(az rest --method post --uri $workspaceResourceId/sharedKeys?api-version=2015-11-01-preview --query primarySharedKey)
workspaceKey=$(echo $workspaceKey | tr -d '"')
echo $workspaceKey

echo "installing Azure Monitor for containers HELM chart for MDM alerts preview..."

echo "adding azmon-preview repo"
helm repo add azmon-preview-mdm-alert https://rashmichandrashekar.github.io/azuremonitor-containers-charts/
echo "updating helm repo to get latest charts"
helm repo update

echo "uninstalling existing release if any for azmon-containers-ci-mdm-alert-release"
helm uninstall azmon-containers-ci-mdm-alert-release

helm upgrade --install azmon-containers-ci-mdm-alert-release --set amalogs.secret.wsid=$workspaceGuid,amalogs.secret.key=$workspaceKey,amalogs.env.clusterId=$clusterResourceId,amalogs.env.clusterRegion=$clusterRegion azmon-preview-mdm-alert/azuremonitor-containers --kube-context $clusterName
echo "chart installation completed."

echo "setting the subscription id of the cluster: ${clusterSubscriptionId}"
az account set -s ${clusterSubscriptionId}

echo "getting cluster object"
clusterGetResponse=$(az rest --method get --uri "${clusterResourceId}?api-version=2026-07-01") || exit 1

printf '%s\n' "$clusterGetResponse" | jq -e --arg workspaceResourceId "$workspaceResourceId" \
  'if (.properties.azureMonitorProfile.containerInsights.enabled | type) == "boolean" then
     .properties.azureMonitorProfile.containerInsights.logAnalyticsWorkspaceResourceId = $workspaceResourceId
   else error("Cluster has no valid Container Insights profile") end' > putrequestbody.json || exit 1

az rest --method put --uri "${clusterResourceId}?api-version=2026-07-01" --body @putrequestbody.json --headers Content-Type=application/json