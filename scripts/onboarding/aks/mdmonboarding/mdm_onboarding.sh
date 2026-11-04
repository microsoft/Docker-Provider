#!/bin/bash
#
# Execute this directly in Azure Cloud Shell (https://shell.azure.com) by pasting (SHIFT+INS on Windows, CTRL+V on Mac or Linux)
# the following line (beginning with curl...) at the command prompt and then replacing the args:
# This script adds the Monitoring Metrics Publisher role assignment to specified AKS cluster
#  Note: 'Microsoft.Authorization/roleAssignments/write'  permission required on the  cluster resource to add the role assignment.
#  Of the built-in roles, only Owner and User Access Administrator are granted access to this permission.
# Prerequisites :
#     Azure CLI:  https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
# curl -sL https://git.io/aks-mdm-onboarding | bash -s subscriptionId clusterResourceGroup clusterName
#
#   [Required]  ${1}  subscriptionId    subscriptionId  of the AKS cluster
#   [Required]  ${2}  clusterResourceGroup      resource group of the AKS cluster
#   [Required]  ${3}  clusterName           name of the AKS cluster
#
# For example:
#
# https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/aks/mdmonboarding/mdm_onboarding.sh | bash -s "00000000-0000-0000-0000-000000000000" "MyAKSClusterRG" "MyAKSCluster"
#

echo "subscriptionId"= ${1}
echo "clusterResourceGroup" = ${2}
echo "clusterName" = ${3}

# login to azure
az login || exit 1

# set the account with specified subscriptionId
az account set -s "${1}" || exit 1

# get the cluster resource id

CLUSTER_RESOURCE_ID=$(az aks show -g "${2}" -n "${3}" --query id -o tsv) || exit 1
if [ -z "$CLUSTER_RESOURCE_ID" ] || [ "$CLUSTER_RESOURCE_ID" = "null" ]; then
    echo "No cluster resource ID found" >&2
    exit 1
fi
echo "clusterResourceId" = $CLUSTER_RESOURCE_ID

# get the clientId of cluster service principal if it exists, else get msi
SP_ID=$(az aks show -g "${2}" -n "${3}" --query servicePrincipalProfile.clientId -o tsv) || exit 1

if [ -z "$SP_ID" ] || [ "$SP_ID" = "msi" ]; then
      echo "Azure Monitor Profile does not expose the Container Insights collector identity. MSI ingestion needs no Monitoring Metrics Publisher role. For legacy custom metrics, grant the role to the known collector object ID or migrate to MSI authentication." >&2
      exit 1
else
      echo "Found service principal for the cluster" = $SP_ID
      assignee_args=(--assignee "$SP_ID")
fi

echo " - Running .."

# This explicit custom-metrics grant is not needed for Container Insights MSI ingestion.
az role assignment create "${assignee_args[@]}" --scope "$CLUSTER_RESOURCE_ID" --role "Monitoring Metrics Publisher" || exit 1

echo "completed the role assignment"