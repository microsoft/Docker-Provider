If you are deploying a new AKS cluster using Terraform with ama logs addon enabled, follow the steps below.

1. Please download all files under https://aka.ms/enable-monitoring-msi-terraform.
2. Update variables.tf to replace values in "<>".
3. Run `terraform init -upgrade` to initialize the Terraform deployment.
4. Run `terraform plan -out main.tfplan` to initialize the Terraform deployment.
5. Run `terraform apply main.tfplan` to apply the execution plan to your cloud infrastructure.

**NOTE**
- Please edit the main.tf file appropriately before running the terraform template
- If resource group already exists, please run `terraform import azurerm_resource_group.rg /subscriptions/<Subscription_ID>/resourceGroups/<Resource_Group_Name>` before terraform plan
- Data will start flowing after 10 minutes since the cluster needs to be ready first
- Workspace ID needs to match format '/subscriptions/12345678-1234-9876-4563-123456789012/resourceGroups/example-resource-group/providers/Microsoft.OperationalInsights/workspaces/workspaceValue'
- The AKS cluster is managed by AzAPI through `azureMonitorProfile.containerInsights` using the GA `2026-07-01` API. AzureRM continues to manage the monitoring resources and read the cluster credentials.
- If you already applied an older version of this template, migrate the existing cluster's Terraform state before applying this version. Back up the state securely, then run the commands below. This changes Terraform ownership, not the Azure cluster; do not run `terraform apply` between removing and importing the state entry.

```sh
terraform init -upgrade
terraform state rm azurerm_kubernetes_cluster.k8s
terraform import azapi_resource.k8s "<AKS_RESOURCE_ID>?api-version=2026-07-01"
terraform plan -out main.tfplan
```

Review the plan and confirm it does not destroy or replace the existing cluster.
