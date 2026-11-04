#!/bin/bash
#
# Execute this directly in Azure Cloud Shell (https://shell.azure.com) by pasting (SHIFT+INS on Windows, CTRL+V on Mac or Linux)
# the following line (beginning with curl...) at the command prompt and then replacing the args:
#  This script adds the 'Monitoring Metrics Publisher' role assignment for all the AKS clusters
#  in specified subscription
#  Note: 'Microsoft.Authorization/roleAssignments/write'  permission required on the  each cluster resource to add the role assignment.
#  Of the built-in roles, only Owner and User Access Administrator are granted access to this permission.
# Prerequisites :
#     Azure CLI:  https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
#           jq : sudo apt-get install jq
#  curl -sL https://git.io/aks-mdm-onboarding-atscale | bash -s subscriptionId
#
#  [Required]  ${1}  subscriptionId    subscriptionId  of the AKS cluster
#
#  For example:
#
#  https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/aks/mdmonboarding/mdm_onboarding_atscale.sh | bash -s "00000000-0000-0000-0000-000000000000"
#

echo "subscriptionId"= ${1}

# login to azure interactively
az login || exit 1

# set the account with specified subscriptionId
az account set -s "${1}" || exit 1

# get all the aks clusters in specified subscription
CLUSTERS_LIST=$(az aks list --query '[].{clusterId:id, name:name, rg:resourceGroup}' -o json) || exit 1
failed_assignments=0

for cluster in $(echo $CLUSTERS_LIST | jq -c '.[]'); do
    export clusterRG=$(echo $cluster | jq -r  '.rg')
    export clusterName=$(echo $cluster | jq -r  '.name')
    export clusterId=$(echo $cluster | jq -r  '.clusterId')

    # get the clientId of cluster service principal if it exists, else get msi
    SP_ID=$(az aks show -g "$clusterRG" -n "$clusterName" --query servicePrincipalProfile.clientId -o tsv) || exit 1

    if [ -z "$SP_ID" ] || [ "$SP_ID" = "msi" ]; then
        echo "Cannot infer the Container Insights collector identity for $clusterName from Azure Monitor Profile. MSI ingestion needs no Monitoring Metrics Publisher role. Grant legacy custom-metrics permissions to the known collector object ID or migrate to MSI authentication." >&2
        failed_assignments=1
        continue
    else
        echo "Found service principal for the cluster" = $SP_ID
        assignee_args=(--assignee "$SP_ID")
    fi

    echo "adding role assignment for aks cluster $clusterName"
    if az role assignment create "${assignee_args[@]}" --scope "$clusterId" --role "Monitoring Metrics Publisher"; then
        echo "role assignment completed for aks cluster $clusterName"
    else
        failed_assignments=1
    fi
done

if [ "$failed_assignments" -ne 0 ]; then
    echo "Some role assignments failed in subscription: ${1}" >&2
    exit 1
fi

echo "completed role assignments for all AKS clusters in subscription: ${1}"

