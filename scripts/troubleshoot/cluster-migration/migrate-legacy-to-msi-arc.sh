#!/bin/bash
#
# Script to migrate Arc-enabled Kubernetes clusters from service principal to managed identity authentication
# 
# Usage:
#   1. Create a text file listing your clusters (e.g., clusters.txt):
#      ResourceGroup,ClusterName
#      myRG-prod,cluster-prod
#
#   2. Run the script:
#      ./migrate-to-msi-arc.sh clusters.txt
#

if [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ -z "$1" ]; then
    echo "Migrates Arc-enabled Kubernetes clusters to managed identity authentication"
    echo ""
    echo "Usage: $0 <clusters-file>"
    echo "The clusters file should contain one cluster per line in format: resource-group,cluster-name"
    echo ""
    echo "Example clusters file content:"
    echo "myResourceGroup1,myCluster1"
    echo "myResourceGroup2,myCluster2"
    exit 0
fi

clusters_file=$1
if [ ! -f "$clusters_file" ]; then
    echo "[Error] Clusters file not found: $clusters_file"
    exit 1
fi

# Clean and normalize line endings
temp_file=$(mktemp)
sed 's/\r$//' "$clusters_file" | sed '/^[[:space:]]*$/d' > "$temp_file" # Remove Windows-style line endings and empty lines
mv "$temp_file" "$clusters_file"

# Check login status
if ! az account show &> /dev/null; then
    echo "[Error] Please run 'az login' first"
    exit 1
fi

# Arrays to track cluster status
successful_clusters=()
failed_clusters=()

# Process each cluster
while IFS=, read -r resource_group cluster_name || [ -n "$resource_group" ]; do
    # Skip empty lines and trim whitespace
    [ -z "$resource_group" ] && continue
    resource_group=$(echo "$resource_group" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    cluster_name=$(echo "$cluster_name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # Skip if either resource_group or cluster_name is empty after trimming
    if [ -z "$resource_group" ] || [ -z "$cluster_name" ]; then
        continue
    fi

    echo "[$(date)] Processing cluster: $cluster_name"

    # Get workspace ID
    echo "[$(date)] Getting workspace ID for $cluster_name"
    workspace_info=$(az k8s-extension show --name azuremonitor-containers --cluster-name "$cluster_name" \
                    --resource-group "$resource_group" --cluster-type connectedClusters \
                    -n azuremonitor-containers --query 'configurationSettings.logAnalyticsWorkspaceResourceID' -o tsv)
    if [ $? -ne 0 ]; then
        echo "[Error] Failed to get workspace ID"
        echo "[$(date)] Skipping cluster $cluster_name due to workspace ID error"
        echo "----------------------------------------"
        failed_clusters+=("$cluster_name - Failed to get workspace ID")
        continue
    fi

    workspace_id=$(echo "$workspace_info" | tr -d '"')
    if [ -z "$workspace_id" ]; then
        echo "[Error] Could not extract workspace ID for $cluster_name"
        echo "[$(date)] Skipping cluster $cluster_name due to workspace ID extraction error"
        echo "----------------------------------------"
        failed_clusters+=("$cluster_name - Could not extract workspace ID")
        continue
    fi
    echo "[$(date)] Found workspace ID: $workspace_id"

    # Delete existing extension
    echo "[$(date)] Deleting monitoring extension for $cluster_name"
    az k8s-extension delete --name azuremonitor-containers --cluster-name "$cluster_name" \
                           --resource-group "$resource_group" --cluster-type connectedClusters --yes
    if [ $? -ne 0 ]; then
        echo "[Error] Failed to delete monitoring extension"
        echo "[$(date)] Skipping cluster $cluster_name due to extension deletion error"
        echo "----------------------------------------"
        failed_clusters+=("$cluster_name - Failed to delete monitoring extension")
        continue
    fi

    # Wait for extension deletion to complete
    echo "[$(date)] Waiting for extension deletion to complete..."
    sleep 30

    # Create new extension with managed identity
    echo "[$(date)] Re-creating monitoring extension with managed identity for $cluster_name"
    az k8s-extension create --name azuremonitor-containers --cluster-name "$cluster_name" \
                           --resource-group "$resource_group" --cluster-type connectedClusters \
                           --extension-type Microsoft.AzureMonitor.Containers \
                           --configuration-settings "amalogs.useAADAuth=true" \
                           "logAnalyticsWorkspaceResourceID=$workspace_id"
    if [ $? -ne 0 ]; then
        echo "[Error] Failed to create monitoring extension"
        echo "[$(date)] Skipping cluster $cluster_name due to extension creation error"
        echo "----------------------------------------"
        failed_clusters+=("$cluster_name - Failed to create monitoring extension")
        continue
    fi

    echo "[$(date)] Completed migration for $cluster_name"
    echo "----------------------------------------"
    successful_clusters+=("$cluster_name")
done < "$clusters_file"

echo "[$(date)] Migration Summary:"
echo "Successful clusters (${#successful_clusters[@]}):"
for cluster in "${successful_clusters[@]}"; do
    echo "  ✓ $cluster"
done

echo "Failed clusters (${#failed_clusters[@]}):"
for failure in "${failed_clusters[@]}"; do
    echo "  ✗ $failure"
done
