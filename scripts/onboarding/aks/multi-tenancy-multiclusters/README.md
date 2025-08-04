# Multi-Tenant Container Insights Setup with Shared DCR/DCE

This guide explains how to set up Container Insights monitoring for multiple AKS clusters using a shared Data Collection Rule (DCR) and Data Collection Endpoint (DCE).

## Setup Process

### 1. Deploy Shared DCR and DCE

First, deploy the shared DCR and DCE using the `existingClusterOnboarding.json` template. This creates the core monitoring infrastructure that will be shared across multiple clusters.

```bash
az deployment group create \
  --name shared-monitoring-setup \
  --resource-group <resource-group-name> \
  --template-file existingClusterOnboarding.json \
  --parameters existingClusterParam.json 
```
After deployment, note the DCR ID from the output. You'll need this to connect clusters.

### 2. Connect AKS Clusters to the Shared DCR

After deploying the DCR/DCE setup, you'll need to connect your AKS clusters. Below are simple commands to connect multiple clusters:

#### For Multiple Clusters (Bash)

```bash
# Store the DCR ID
DCR_ID="/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Insights/dataCollectionRules/<dcr-name>"

# If using private link, store the Config DCE ID
CONFIG_DCE_ID="/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Insights/dataCollectionEndpoints/<dce-name>"

# Loop through your clusters
for cluster in \
  "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.ContainerService/managedClusters/<cluster1-name>" \
  "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.ContainerService/managedClusters/<cluster2-name>"; do
  echo "Connecting cluster: $cluster"
  
  # Create DCR association
  az monitor data-collection rule association create \
    --name "aks-dcr-association" \
    --rule-id "$DCR_ID" \
    --resource "$cluster"

  # If using private link, create Config DCE association
  if [ ! -z "$CONFIG_DCE_ID" ]; then
    az monitor data-collection rule association create \
      --name "configurationAccessEndpoint" \
      --endpoint-id "$CONFIG_DCE_ID" \
      --resource "$cluster"
  fi
done
```

### Notes

1. The shared DCR/DCE setup needs to be done only once. After that, you can connect multiple clusters to the same DCR.

2. Each cluster needs:
   - DCR Association (always required)
   - Config DCE Association (only required when using private link)

3. Parameters explanation:
   - `subscriptionId`: The subscription where DCR/DCE will be created
   - `resourceGroupName`: Resource group for DCR/DCE resources
   - `location`: Location for the config DCE (only used with private link)
   - `workspaceRegion`: Region of the Log Analytics workspace
   - `workspaceResourceId`: Full resource ID of the Log Analytics workspace
   - `k8sNamespaces`: Array of Kubernetes namespaces to collect logs from
   - `transformKql`: Optional KQL query for log transformation
   - `useAzureMonitorPrivateLinkScope`: Whether to use private link scope
   - `azureMonitorPrivateLinkScopeResourceId`: Resource ID of private link scope (if used)
   - `resourceTagValues`: Tags to apply to the created resources

4. To list existing DCRAs for a cluster:
```bash
az monitor data-collection rule association list --resource "<aks-cluster-resource-id>"
```

5. To remove a DCRA:
```bash
az monitor data-collection rule association delete \
  --name "aks-dcr-association" \
  --resource "<aks-cluster-resource-id>"
```
