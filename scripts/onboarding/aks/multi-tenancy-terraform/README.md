# Multi-tenancy AKS Monitoring Configuration

This Terraform configuration enables multi-tenancy monitoring for an existing AKS cluster by creating and configuring:
- Data Collection Endpoint
- Data Collection Rule
- Data Collection Rule Association

## Prerequisites

1. An existing AKS cluster
2. Azure Log Analytics workspace
3. [Terraform](https://www.terraform.io/downloads.html) installed (version >= 1.0.0)
4. Azure CLI installed and logged in

## Usage

1. Clone this repository and navigate to this directory:
   ```bash
   cd scripts/onboarding/aks/multi-tenancy-terraform
   ```

2. Create a `terraform.tfvars` file with your configuration values:
   ```hcl
   aksResourceId         = "/subscriptions/<SubscriptionId>/resourcegroups/<ResourceGroup>/providers/Microsoft.ContainerService/managedClusters/<ClusterName>"
   aksResourceLocation   = "<aksClusterLocation>"
   workspaceResourceId   = "/subscriptions/<SubscriptionId>/resourceGroups/<ResourceGroup>/providers/Microsoft.OperationalInsights/workspaces/<WorkspaceName>"
   workspaceRegion       = "<workspaceRegion>"
   k8sNamespaces        = ["namespace1", "namespace2"]
   resourceTagValues     = {
     "environment" = "production"
     "owner"       = "team-name"
   }
   transformKql         = "" # Optional: Add your KQL transformation query
   ```

3. Initialize Terraform:
   ```bash
   terraform init
   ```

4. Review the planned changes:
   ```bash
   terraform plan
   ```

5. Apply the configuration:
   ```bash
   terraform apply
   ```

## Important Notes

1. This configuration only manages the monitoring components for an existing AKS cluster. It does not create or modify the AKS cluster itself.

2. The following resources will be created:
   - Data Collection Endpoint for ingestion
   - Data Collection Rule for multi-tenancy logging
   - Data Collection Rule Association linking the DCR to your AKS cluster

3. Terraform state will only track the monitoring components, not the existing AKS cluster.

## Variables

| Variable | Description | Required |
|----------|-------------|----------|
| aksResourceId | Full resource ID of the existing AKS cluster | Yes |
| aksResourceLocation | Location of the AKS resource (e.g., "eastus") | Yes |
| workspaceResourceId | Full resource ID of the Log Analytics workspace | Yes |
| workspaceRegion | Region of the Log Analytics workspace | Yes |
| k8sNamespaces | Array of Kubernetes namespaces to monitor | Yes |
| resourceTagValues | Map of tags to apply to created resources | No |
| transformKql | KQL transformation query for log ingestion | No |

## Example terraform.tfvars

```hcl
aksResourceId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourcegroups/my-rg/providers/Microsoft.ContainerService/managedClusters/my-aks"
aksResourceLocation = "eastus"
workspaceResourceId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-rg/providers/Microsoft.OperationalInsights/workspaces/my-workspace"
workspaceRegion = "eastus"
k8sNamespaces = [
  "default",
  "kube-system"
]
resourceTagValues = {
  "environment" = "production"
  "managed-by" = "terraform"
}
transformKql = ""
```

## Cleanup

To remove the monitoring configuration:
```bash
terraform destroy
```

This will remove all monitoring components but will not affect the AKS cluster itself.
