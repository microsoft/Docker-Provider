#!/bin/bash
#
# Execute this directly in Azure Cloud Shell (https://shell.azure.com) by pasting (SHIFT+INS on Windows, CTRL+V on Mac or Linux)
# the following line (beginning with curl...) at the command prompt and then replacing the args:
#  This scripts Onboards Azure Monitor for containers to Openshift v4 clusters hosted in on-prem or any cloud environment
#
#      1. Creates the Default Azure log analytics workspace if doesn't exist one in specified azure subscription and region
#      2. Adds the ContainerInsights solution to the Azure log analytics workspace
#      3. Installs Azure Monitor for containers HELM chart to the K8s cluster in Kubeconfig
# Prerequisites :
#     Azure CLI:  https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
#     Helm3 : https://helm.sh/docs/intro/install/
#
# bash onboarding_azuremonitor_for_containers.sh <azureSubscriptionId> <azureRegionforLogAnalyticsWorkspace> <clusterName> <kubeconfigContextNameOftheCluster>
# For example:
# bash ./onboarding_azuremonitor_for_containers.sh 00000000-0000-0000-0000-000000000000 eastus myocp42 admin

if [ $# -le 3 ]
then
  echo "Error: This should be invoked with 4 arguments, azureSubscriptionId, azureRegionforLogAnalyticsWorkspace, clusterName and kubeContext name"
  exit 1
fi

echo "subscriptionId:"${1}
echo "azureRegionforLogAnalyticsWorkspace:"${2}
echo "clusterName:"${3}
echo "kubeconfig context:"${4}

subscriptionId=${1}
logAnalyticsWorkspaceRegion=${2}
clusterName=${3}

echo "Azure SubscriptionId:" $subscriptionId
echo "Azure Region for Log Analytics Workspace:" $logAnalyticsWorkspaceRegion
echo "cluster Name:" $clusterName

echo "Set AzureCloud as active cloud for az cli"
az cloud set -n AzureCloud

echo "login to the azure interactively"
az login

echo "set the subscription id: ${subscriptionId}"
az account set -s ${subscriptionId}

# mapping fors for default Azure Log Analytics workspace
declare -A AzureCloudLocationToOmsRegionCodeMap=(
[australiasoutheast]=ASE
[australiaeast]=EAU
[australiacentral]=CAU
[canadacentral]=CCA
[centralindia]=CIN
[centralus]=CUS
[eastasia]=EA
[eastus]=EUS
[eastus2]=EUS2
[eastus2euap]=EAP
[francecentral]=PAR
[japaneast]=EJP
[koreacentral]=SE
[northeurope]=NEU
[southcentralus]=SCUS
[southeastasia]=SEA
[uksouth]=SUK
[usgovvirginia]=USGV
[westcentralus]=EUS
[westeurope]=WEU
[westus]=WUS
[westus2]=WUS2
)

declare -A AzureCloudRegionToOmsRegionMap=(
[australiacentral]=australiacentral
[australiacentral2]=australiacentral
[australiaeast]=australiaeast
[australiasoutheast]=australiasoutheast
[brazilsouth]=southcentralus
[canadacentral]=canadacentral
[canadaeast]=canadacentral
[centralus]=centralus
[centralindia]=centralindia
[eastasia]=eastasia
[eastus]=eastus
[eastus2]=eastus2
[francecentral]=francecentral
[francesouth]=francecentral
[japaneast]=japaneast
[japanwest]=japaneast
[koreacentral]=koreacentral
[koreasouth]=koreacentral
[northcentralus]=eastus
[northeurope]=northeurope
[southafricanorth]=westeurope
[southafricawest]=westeurope
[southcentralus]=southcentralus
[southeastasia]=southeastasia
[southindia]=centralindia
[uksouth]=uksouth
[ukwest]=uksouth
[westcentralus]=eastus
[westeurope]=westeurope
[westindia]=centralindia
[westus]=westus
[westus2]=westus2
)

export workspaceRegionCode="EUS"
export workspaceRegion="eastus"

if [ -n "${AzureCloudRegionToOmsRegionMap[$logAnalyticsWorkspaceRegion]}" ];
then
   workspaceRegion=${AzureCloudRegionToOmsRegionMap[$logAnalyticsWorkspaceRegion]}
fi
echo "Workspace Region:"$workspaceRegion

if [ -n "${AzureCloudLocationToOmsRegionCodeMap[$workspaceRegion]}" ];
then
   workspaceRegionCode=${AzureCloudLocationToOmsRegionCodeMap[$workspaceRegion]}
fi
echo "Workspace Region Code:"$workspaceRegionCode

export defaultWorkspaceResourceGroup="DefaultResourceGroup-"$workspaceRegionCode
export isRGExists=$(az group exists -g $defaultWorkspaceResourceGroup)
export defaultWorkspaceName="DefaultWorkspace-"$subscriptionId"-"$workspaceRegionCode

if $isRGExists
then echo "using existing default resource group:"$defaultWorkspaceResourceGroup
else
  az group create -g $defaultWorkspaceResourceGroup -l $workspaceRegion
fi

export workspaceList=$(az resource list -g $defaultWorkspaceResourceGroup -n $defaultWorkspaceName  --resource-type Microsoft.OperationalInsights/workspaces)
if [ "$workspaceList" = "[]" ];
then
# create new default workspace since no mapped existing default workspace
echo '{"location":"'"$workspaceRegion"'", "properties":{"sku":{"name": "standalone"}}}' > WorkspaceProps.json
cat WorkspaceProps.json
workspace=$(az resource create -g $defaultWorkspaceResourceGroup -n $defaultWorkspaceName --resource-type Microsoft.OperationalInsights/workspaces --is-full-object -p @WorkspaceProps.json)
else
  echo "using existing default workspace:"$defaultWorkspaceName
fi

workspaceResourceId=$(az resource show -g $defaultWorkspaceResourceGroup -n $defaultWorkspaceName  --resource-type Microsoft.OperationalInsights/workspaces --query id)
workspaceResourceId=$(echo $workspaceResourceId | tr -d '"')

# get the workspace guid
export workspaceGuid=$(az resource show -g $defaultWorkspaceResourceGroup -n $defaultWorkspaceName  --resource-type Microsoft.OperationalInsights/workspaces --query properties.customerId)
workspaceGuid=$(echo $workspaceGuid | tr -d '"')

echo "workspaceResourceId:"$workspaceResourceId
echo "workspaceGuid:"$workspaceGuid

echo "adding containerinsights solution to workspace"
solution=$(az group deployment create -g $defaultWorkspaceResourceGroup --template-uri https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/templates/azuremonitor-containerSolution.json --parameters workspaceResourceId=$workspaceResourceId --parameters workspaceRegion=$workspaceRegion)

echo "getting workspace primaryshared key"
workspaceKey=$(az rest --method post --uri $workspaceResourceId/sharedKeys?api-version=2015-11-01-preview --query primarySharedKey)
workspaceKey=$(echo $workspaceKey | tr -d '"')
echo $workspaceKey

echo "installing Azure Monitor for containers HELM chart ..."

echo "adding azmon-preview repo"
helm repo add azmon-preview https://ganga1980.github.io/azuremonitor-containers-helm-charts/
echo "updating helm repo to get latest charts"
helm repo update

helm upgrade --install azmon-containers-release-1 --set omsagent.secret.wsid=$workspaceGuid,omsagent.secret.key=$workspaceKey,omsagent.env.clusterName=${3} azmon-preview/azuremonitor-containers --kube-context ${4}
echo "chart installation completed."

echo "Proceed to https://aka.ms/azmon-containers-hybrid to view health of your newly onboarded OpenshiftV4 cluster"
