# Multi-Tenant Container Insights Setup with Shared DCR/DCE

This guide explains how to set up Container Insights monitoring for multiple AKS clusters using a shared Data Collection Rule (DCR) and Data Collection Endpoints (DCE).

## Important Note About Config DCE for private link scenarios

The Configuration Data Collection Endpoint (Config DCE) is required ONLY for private link scenarios. When using private links, the Config DCE must be created in a one-to-one relationship with each AKS cluster and deployed in the same region as the cluster. The Config DCE is not included in the shared template and must be created separately for each cluster that needs private link access.

## Setup Process

### Standard Setup (Non-Private Link)

1. Deploy Shared DCR and DCE

First, deploy the shared DCR and DCE using the `existingClusterOnboarding.json` template. This creates the core monitoring infrastructure that will be shared across multiple clusters.

```bash
az deployment group create \
  --name shared-monitoring-setup \
  --resource-group <resource-group-name> \
  --template-file existingClusterOnboarding.json \
  --parameters existingClusterParam.json
```

After deployment, note the DCR ID from the output. You'll need this to associate clusters.

2. Associate shared DCR and DCE to all AKS Clusters
   ```bash
   az monitor data-collection rule association create \
     --name "aks-dcr-<cluster-name>" \
     --rule-id "<dcr-id>" \
     --resource "<cluster-resource-id>"
   ```

### Private Link Setup

For clusters requiring private link access, complete these additional steps after the standard setup:

1. Prerequisites
   - Azure Monitor Private Link Scope (AMPLS)
   - Properly configured virtual network
   - Network security group rules ready

2. Create Config DCE for Each Private Link Cluster
   ```bash
   az monitor data-collection endpoint create \
     --name "MSCI-config-<region>-<cluster-name>" \
     --resource-group <resource-group-name> \
     --location <same-as-cluster-region> \
   ```
   - Important: Location parameter MUST match the cluster's region exactly
   - Each private link cluster requires its own dedicated Config DCE
   - Do not share Config DCEs between clusters

3. Configure Private Link
   1. Set Config DCE `publicNetworkAccess` to "Disabled"
   2. Link Config DCE to AMPLS
   3. Create private endpoint in cluster's VNet
   4. Update network security group rules
   5. Verify DNS resolution works

4. Create Config DCE Association
   ```bash
   az monitor data-collection endpoint association create \
     --name "MSCI-config-<cluster-name>" \
     --endpoint-id "<config-dce-id>" \
     --resource "<cluster-resource-id>"

## Resource Management

View associations:
```bash
az monitor data-collection rule association list --resource "<aks-cluster-resource-id>"
```

Remove association:
```bash
az monitor data-collection rule association delete --name "<association-name>" --resource "<aks-cluster-resource-id>"
```
