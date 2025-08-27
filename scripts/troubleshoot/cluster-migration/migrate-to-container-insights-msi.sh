#!/bin/bash
#
# Script to migrate container insights monitoring to managed identity authentication
#
# High Level Steps:
# 1. Prerequisites Check:
#    - Validate Azure CLI and login status
#    - Verify subscription access
#    - Check cluster identity type
#    - Verify container insights MSI status
#    - Check cluster health
#
# 2. Cluster Discovery:
#    - Scan specified subscriptions
#    - Filter by cluster types (AKS/Arc)
#    - List eligible clusters
#
# 3. Migration Process:
#    - Get Log Analytics workspace ID
#    - Disable monitoring addon
#    - Re-enable with MSI auth
#
# Usage:
#   ./migrate-to-container-insights-msi.sh -s <subscriptionIds> -c <clusterTypes>
#
# Example:
#   ./migrate-to-container-insights-msi.sh -s "sub1,sub2" -c "aks,arc"
#

# Function to display usage
usage() {
    echo "Usage: $0 -s <subscriptionIds> -c <clusterTypes>"
    echo "  -s : Comma-separated list of subscription IDs"
    echo "  -c : Comma-separated list of cluster types (aks,arc)"
    echo "Example:"
    echo "  $0 -s \"subId1,subId2\" -c \"aks,arc\""
    exit 1
}

# Function to check prerequisites for a cluster
check_prerequisites() {
    local cluster_type=$1
    local resource_group=$2
    local name=$3

    if [ "$cluster_type" = "aks" ]; then
        # 1. Check AKS cluster health first
        local provisioning_state=$(az aks show -g "$resource_group" -n "$name" --query "provisioningState" -o tsv)
        if [ "$provisioning_state" != "Succeeded" ]; then
            echo "Cluster not ready (current state: $provisioning_state)" >&2
            return 1
        fi

        # 2. Check if cluster uses managed identity
        local identity_type=$(az aks show -g "$resource_group" -n "$name" --query "identity.type" -o tsv)
        if [ "$identity_type" != "SystemAssigned" ] && [ "$identity_type" != "UserAssigned" ]; then
            echo "Current identity type: $identity_type (requires SystemAssigned or UserAssigned)" >&2
            echo "To migrate to managed identity, visit: https://learn.microsoft.com/en-us/azure/aks/use-managed-identity" >&2
            echo "Please migrate to managed identity and then rerun this script" >&2
            return 1
        fi

        # 3. Check if monitoring is enabled
        local monitoring_enabled=$(az aks show -g "$resource_group" -n "$name" --query "addonProfiles.omsagent.enabled" -o tsv)
        if [ "$monitoring_enabled" != "true" ]; then
            echo "Container insights not enabled on this cluster" >&2
            return 1
        fi

        # 4. Check if monitoring is already using MSI
        local auth_mode=$(az aks show -g "$resource_group" -n "$name" --query "addonProfiles.omsagent.config.useAADAuth" -o tsv)
        if [ "$auth_mode" = "true" ]; then
            echo "Monitoring already using MSI authentication" >&2
            return 1
        fi
    
    elif [ "$cluster_type" = "arc" ]; then
        # 1. Check Arc cluster health first
        local cluster_state=$(az connectedk8s show -g "$resource_group" -n "$name" --query "provisioningState" -o tsv)
        if [ "$cluster_state" != "Succeeded" ]; then
            echo "Arc cluster not ready (current state: $cluster_state)" >&2
            return 1
        fi

        # 2. Check if cluster uses managed identity
        local identity_type=$(az connectedk8s show -g "$resource_group" -n "$name" --query "identity.type" -o tsv)
        if [ "$identity_type" != "SystemAssigned" ] && [ "$identity_type" != "UserAssigned" ]; then
            echo "Current identity type: $identity_type (requires SystemAssigned or UserAssigned)" >&2
            echo "Arc-enabled clusters require managed identity for monitoring. Current authentication method: Service Principal" >&2
            echo "To use managed identity:" >&2
            echo "1. Offboard monitoring" >&2
            echo "2. Delete and re-register Arc connection using managed identity" >&2
            echo "3. Re-onboard monitoring with the new identity" >&2
            echo "Please migrate to managed identity and then rerun this script" >&2
            return 1
        fi

        # 3. Check if extension exists and its state
        local extension_exists=$(az k8s-extension show --name azuremonitor-containers \
                              --cluster-name "$name" \
                              --resource-group "$resource_group" \
                              --cluster-type connectedClusters 2>/dev/null)
        if [ -z "$extension_exists" ]; then
            echo "Container insights extension not installed" >&2
            return 1
        fi
        local extension_state=$(echo "$extension_exists" | jq -r '.provisioningState')
        if [ "$extension_state" != "Succeeded" ]; then
            echo "Container insights extension not ready (current state: $extension_state)" >&2
            return 1
        fi

        # 4. Check if already using MSI authentication
        local use_aad_auth=$(az k8s-extension show --name azuremonitor-containers \
                            --cluster-name "$name" \
                            --resource-group "$resource_group" \
                            --cluster-type connectedClusters \
                            --query "configurationSettings.\"amalogs.useAADAuth\"" -o tsv)
        if [ "$use_aad_auth" = "true" ]; then
            echo "Monitoring already using MSI authentication" >&2
            return 1
        fi
    fi

    return 0
}

# Function to get AMPLS ID for private cluster
get_ampls_id() {
    local workspace_id=$1
    
    # Parse workspace details
    local workspace_name=$(echo "$workspace_id" | cut -d'/' -f9)
    local workspace_rg=$(echo "$workspace_id" | cut -d'/' -f5)
    
    # Get AMPLS ID
    az monitor log-analytics workspace show \
      --workspace-name "$workspace_name" \
      --resource-group "$workspace_rg" \
      --query "privateLinkScopedResources[0].resourceId" -o tsv | sed 's|/scopedresources/.*||'
}

# Function to discover clusters
discover_clusters() {
    local subscription_id=$1
    local cluster_type=$2
    
    case $cluster_type in
        "aks")
            az aks list --query "[].{name:name,resourceGroup:resourceGroup}" -o tsv
            ;;
        "arc")
            az connectedk8s list --query "[].{name:name,resourceGroup:resourceGroup}" -o tsv
            ;;
        *)
            echo "[Error] Invalid cluster type: $cluster_type (must be aks or arc)"
            echo ""
            ;;
    esac
}

# Function to perform migration
perform_migration() {
    local cluster_type=$1
    local resource_group=$2
    local name=$3
    local workspace_id=$4
    local max_attempts=3
    local attempt=1

    # 1. Disable monitoring with retries
    echo "[$(date)] Disabling monitoring for $name"
    while [ $attempt -le $max_attempts ]; do
        if [ "$cluster_type" = "aks" ]; then
            az aks disable-addons -a monitoring -g "$resource_group" -n "$name"
            
            # Wait for 3 minutes
            echo "[$(date)] Waiting 3 minutes for disable operation to complete (attempt $attempt/$max_attempts)..."
            sleep 180

            # Check if monitoring is actually disabled
            local monitoring_state=$(az aks show -g "$resource_group" -n "$name" --query "addonProfiles.omsagent.enabled" -o tsv)
            if [ "$monitoring_state" != "true" ]; then
                echo "[$(date)] Successfully disabled monitoring"
                break
            else
                echo "[$(date)] Monitoring is still enabled after attempt $attempt"
                if [ $attempt -eq $max_attempts ]; then
                    echo "[Error] Failed to disable monitoring after $max_attempts attempts"
                    return 1
                fi
                attempt=$((attempt + 1))
            fi
        else
            az k8s-extension delete --name azuremonitor-containers -g "$resource_group" -c "$name" --cluster-type connectedClusters --yes && break
            
            if [ $attempt -eq $max_attempts ]; then
                echo "[Error] Could not disable monitoring after $max_attempts attempts"
                return 1
            fi
            attempt=$((attempt + 1))
            echo "[$(date)] Retrying disable operation (attempt $attempt/$max_attempts)..."
            sleep 180
        fi
    done

    # 2. Re-enable monitoring with MSI
    echo "[$(date)] Re-enabling monitoring with MSI for $name"
    if [ "$cluster_type" = "aks" ]; then
        # Check if private cluster
        local is_private=$(az aks show -g "$resource_group" -n "$name" \
          --query "apiServerAccessProfile.enablePrivateCluster" -o tsv)

        if [ "$is_private" = "true" ]; then
            echo "[$(date)] Private cluster detected, preserving AMPLS configuration"
            # For private clusters, get AMPLS ID
            local ampls_id=$(get_ampls_id "$workspace_id")
            if [ -n "$ampls_id" ]; then
                echo "[$(date)] Using AMPLS: $ampls_id"
                az aks enable-addons -a monitoring -g "$resource_group" -n "$name" \
                  --workspace-resource-id "$workspace_id" \
                  --ampls-resource-id "$ampls_id" || {
                    echo "[Error] Could not enable monitoring with MSI and AMPLS"
                    return 1
                }
            else
                echo "[Error] Could not get AMPLS ID for private cluster"
                return 1
            fi
        else
            echo "[$(date)] Non-private cluster, proceeding without AMPLS"
            # For non-private clusters, proceed without AMPLS
            az aks enable-addons -a monitoring -g "$resource_group" -n "$name" \
              --workspace-resource-id "$workspace_id" || {
                echo "[Error] Could not enable monitoring with MSI"
                return 1
            }
        fi
        
        # Verify MSI auth is enabled
        local auth_mode=$(az aks show -g "$resource_group" -n "$name" --query "addonProfiles.omsagent.config.useAADAuth" -o tsv)
        [ "$auth_mode" = "true" ] || {
            echo "[Error] MSI authentication not enabled after configuration"
            return 1
        }
    else
        az k8s-extension create --name azuremonitor-containers \
          -g "$resource_group" -c "$name" \
          --cluster-type connectedClusters \
          --extension-type Microsoft.AzureMonitor.Containers \
          --configuration-settings logAnalyticsWorkspaceResourceID="$workspace_id" \
          --configuration-settings useManagedIdentityForAuth="true" || {
            echo "[Error] Could not configure monitoring with MSI"
            return 1
        }
    fi

    return 0
}

# Parse command line arguments
while getopts "s:c:h" opt; do
    case $opt in
        s) subscription_ids="$OPTARG" ;;
        c) cluster_types="$OPTARG" ;;
        h) usage ;;
        ?) usage ;;
    esac
done

# Validate required parameters
if [ -z "$subscription_ids" ] || [ -z "$cluster_types" ]; then
    echo "[Error] Missing required parameters"
    usage
fi

# Arrays to track cluster status
successful_clusters=()
skipped_clusters=()
failed_clusters=()

echo "=== STEP 1: Prerequisites Check ==="
# Check Azure CLI installation
command -v az > /dev/null || {
    echo "[Error] Azure CLI not found. Please install Azure CLI"
    exit 1
}

# Check Azure CLI version
az_version=$(az version --query \"azure-cli\" -o tsv)
if [ "$(printf '%s\n' "2.49.0" "$az_version" | sort -V | head -n1)" != "2.49.0" ]; then
    echo "[Error] Azure CLI version must be 2.49.0 or higher (current version: $az_version)"
    exit 1
fi

# Check login status and verify subscriptions
az account show > /dev/null || {
    echo "[Error] Azure login required. Run 'az login'"
    exit 1
}

# Verify all subscriptions exist and are accessible
IFS=',' read -ra SUBS <<< "$subscription_ids"
available_subs=$(az account list --query "[].id" -o tsv)

for sub in "${SUBS[@]}"; do
    sub=$(echo "$sub" | xargs)
    echo "$available_subs" | grep -q "^$sub$" || {
        echo "[Error] Cannot access subscription: $sub"
        exit 1
    }
done

echo "=== STEP 2: Cluster Discovery ==="
# Process each subscription
IFS=',' read -ra SUBS <<< "$subscription_ids"
for subscription_id in "${SUBS[@]}"; do
    subscription_id=$(echo "$subscription_id" | xargs)
    echo "[$(date)] Processing subscription: $subscription_id"
    
    # Set subscription
    az account set -s "$subscription_id" || {
        echo "[Error] Cannot access subscription: $subscription_id"
        continue
    }

    # Process each cluster type
    IFS=',' read -ra TYPES <<< "$cluster_types"
    for cluster_type in "${TYPES[@]}"; do
        cluster_type=$(echo "$cluster_type" | xargs | tr '[:upper:]' '[:lower:]')
        
        # Discover clusters
        clusters=$(discover_clusters "$subscription_id" "$cluster_type")

        echo "=== STEP 3: Migration Process ==="
        # Process each discovered cluster
        while IFS=$'\t' read -r name resource_group; do
            [ -z "$name" ] && continue
            
            echo "[$(date)] Processing $cluster_type cluster: $name"

            # Check prerequisites
            prereq_result=$(check_prerequisites "$cluster_type" "$resource_group" "$name" 2>&1)
            if [ $? -ne 0 ]; then
                skipped_clusters+=("$name - Prerequisites failed: $prereq_result")
                continue
            fi

            # Get workspace ID
            echo "[$(date)] Getting workspace ID for $name"
            if [ "$cluster_type" = "aks" ]; then
                workspace_id=$(az aks show -g "$resource_group" -n "$name" --query "addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID" -o tsv)
            else
                workspace_id=$(az connectedk8s show -g "$resource_group" -n "$name" --query "extendedProperties.logAnalyticsWorkspaceResourceId" -o tsv)
            fi

            if [ -z "$workspace_id" ] || [ "$workspace_id" = "null" ]; then
                echo "[Skip] No workspace ID found for $name"
                skipped_clusters+=("$name - No workspace ID configured")
                continue
            fi

            # Perform migration
            if perform_migration "$cluster_type" "$resource_group" "$name" "$workspace_id"; then
                echo "[$(date)] Successfully migrated $name"
                successful_clusters+=("$name")
            else
                echo "[$(date)] Failed to migrate $name"
                failed_clusters+=("$name")
            fi
        done <<< "$clusters"
    done
done

# Print summary
echo -e "\n[$(date)] Migration Summary:"

echo -e "\nSuccessful clusters (${#successful_clusters[@]}):"
for cluster in "${successful_clusters[@]}"; do
    echo "  ✓ $cluster"
done

echo -e "\nSkipped clusters (${#skipped_clusters[@]}):"
for cluster in "${skipped_clusters[@]}"; do
    echo "  ⚠ $cluster"
done

echo -e "\nFailed clusters (${#failed_clusters[@]}):"
for cluster in "${failed_clusters[@]}"; do
    echo "  ✗ $cluster"
done
