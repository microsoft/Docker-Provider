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
az  login

# set the account with specified subscriptionId
az account set -s ${1}

# get the cluster resource id

export CLUSTER_RESOURCE_ID=$(az aks show -g ${2} -n ${3} --query id -o tsv)
echo "clusterResourceId" = $CLUSTER_RESOURCE_ID

# get the clientId of cluster service principal if it exists, else get msi
export SP_ID=$(az aks show -g  ${2} -n ${3} --query servicePrincipalProfile.clientId -o tsv)

if [ -z $SP_ID ]; then
      export MSI_ID=$(az aks show -g  ${2} -n ${3} --query addonProfiles.omsagent.identity.clientId -o tsv)
      if [ -z $MSI_ID ]; then
          echo "No service principal or msi found"
      else
          echo "Found msi for the cluster" = $MSI_ID
          export CLIENT_ID=$MSI_ID
      fi
else
      echo "Found service principal for the cluster" = $SP_ID
      export CLIENT_ID=$SP_ID
fi

if [ ! -z $CLIENT_ID ]; then
    echo " - Running .."

    #  assign the cluster spn with Monitoring Metrics Publisher role to the cluster resource
    az role assignment create --assignee $CLIENT_ID --scope $CLUSTER_RESOURCE_ID --role "Monitoring Metrics Publisher"

    # completed the role assignment
    echo "completed the role assignment"
fi