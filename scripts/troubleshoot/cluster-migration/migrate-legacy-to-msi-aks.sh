#!/bin/bash
#
# Script to migrate AKS clusters from service principal to managed identity authentication
#
# Usage:
#   1. Create a text file listing your clusters (e.g., clusters.txt):
#      ResourceGroup,ClusterName
#      myRG-prod,cluster-prod
#
#   2. Run the script:
#      ./migrate-legacy-to-msi-aks.sh clusters.txt
#

if [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ -z "$1" ]; then
    echo "Migrates AKS clusters to managed identity authentication"
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

    echo "[$(date)] Processing cluster: $cluster_name"

    # Get workspace ID using exact command
    echo "[$(date)] Getting workspace ID for $cluster_name"
    workspace_line=$(az aks show -g "$resource_group" -n "$cluster_name" | grep -i "logAnalyticsWorkspaceResourceID")
    if [ $? -ne 0 ]; then
        echo "[Error] Failed to get workspace ID"
        echo "[$(date)] Skipping cluster $cluster_name due to workspace ID error"
        echo "----------------------------------------"
        failed_clusters+=("$cluster_name - Failed to get workspace ID")
        continue
    fi
    echo "[$(date)] Found workspace info: $workspace_line"

    # Extract workspace ID
    workspace_id=$(echo "$workspace_line" | cut -d'"' -f4)
    if [ -z "$workspace_id" ]; then
        echo "[Error] Could not extract workspace ID for $cluster_name"
        echo "[$(date)] Skipping cluster $cluster_name due to workspace ID extraction error"
        echo "----------------------------------------"
        failed_clusters+=("$cluster_name - Could not extract workspace ID")
        continue
    fi

    # Disable monitoring using exact command
    echo "[$(date)] Disabling monitoring for $cluster_name"
    az aks disable-addons -a monitoring -g "$resource_group" -n "$cluster_name"
    if [ $? -ne 0 ]; then
        echo "[Error] Failed to disable monitoring"
        echo "[$(date)] Skipping cluster $cluster_name due to monitoring disable error"
        echo "----------------------------------------"
        failed_clusters+=("$cluster_name - Failed to disable monitoring")
        continue
    fi

    # Update to managed identity using exact command
    echo "[$(date)] Updating $cluster_name to managed identity"
    az aks update -g "$resource_group" -n "$cluster_name" --enable-managed-identity
    if [ $? -ne 0 ]; then
        echo "[Error] Failed to enable managed identity"
        echo "[$(date)] Skipping cluster $cluster_name due to managed identity enable error"
        echo "----------------------------------------"
        failed_clusters+=("$cluster_name - Failed to enable managed identity")
        continue
    fi

    # Enable monitoring using exact command
    echo "[$(date)] Re-enabling monitoring for $cluster_name with workspace ID: $workspace_id"
    az aks enable-addons -a monitoring -g "$resource_group" -n "$cluster_name" --workspace-resource-id "$workspace_id"
    if [ $? -ne 0 ]; then
        echo "[Error] Failed to re-enable monitoring"
        echo "[$(date)] Skipping cluster $cluster_name due to monitoring re-enable error"
        echo "----------------------------------------"
        failed_clusters+=("$cluster_name - Failed to re-enable monitoring")
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
