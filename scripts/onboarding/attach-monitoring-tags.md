# How to add Monitoring onboarding tags to AKS-engine (or ACS-Engine) Cluster
You can either use the Azure Powershell or Azure cli Bash script to attach the Azure Resource Id of the Log Analytics workspace and clusterName tag to AKS-Engine ( or ACS-Engine Kubernetes) master nodes or VMSSes.
ClusterName should be match with what's configured on the omsagent for omsagent.env.clusterName as part of the omsagent installation.
Log Analytics workspace ResourceId tag on the K8s master node(s) or VMSS(es) used to determine whether the specified cluster is onboarded to monitoring or not.

These  tags required for the Azure Monitor for Containers Ux experience (https://docs.microsoft.com/en-us/azure/monitoring/monitoring-container-insights-overview )

If you are not familiar with the concepts of azure resource tags (https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-using-tags)

## Attach tags using Powershell

Get the below powershell script files to your local computer.
   - Powershell script file [AddMonitoringWorkspaceTags.ps1](https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/aksengine/kubernetes/AddMonitoringWorkspaceTags.ps1)
   - Refer for updating the Powershell execution policy (https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-6)
   - Log analytics workspace resource Id can retrieved either Azure CLI or Powershell or Azure Portal
      Azure CLI

      ``` sh
      az cloud set --name <AzureCloud | AzureChinaCloud | AzureUSGovernment>
      az login
      az resource list --resource-type Microsoft.OperationalInsights/workspaces
                  OR
      az resource show -g `<resource group of the workspace>` -n `<name of the workspace>` --resource-type Microsoft.OperationalInsights/workspaces
      ```
      Powershell

      https://docs.microsoft.com/en-us/powershell/module/azurerm.operationalinsights/get-azurermoperationalinsightsworkspace?view=azurermps-6.11.0

     Azure Portal

     From the Portal URL when the Log Analytics Workspace selected,see below for the format of the Log Analytics Workspace Resource Id

     /subscriptions/`<subId>`/resourceGroups/`<rgName>`/providers/Microsoft.OperationalInsights/workspaces/`<workspaceName>`


- Use the following PowerShell command from the folder containing the Powershell script file:

``` sh
 # Specify Cloud Environment of the AKS-Engine (or ACS-Engine Kubernetes) cluster.
.\AddMonitoringWorkspaceTags.ps1 -NameoftheCloud <AzureCloud | AzureChinaCloud> -SubscriptionId <Cluster SubscriptionId> -ResourceGroupName <Cluster ResourceGroup>
 -LogAnalyticsWorkspaceResourceId <WorkspaceResourceId> -ClusterName <name of the cluster>

```

The configuration change can take a few minutes to complete. When it finishes, you see a message something like this 'Successfully added logAnalyticsWorkspaceResourceId tag to K8s master VMs':

## Attach tags using Azure CLI

- Run the below bash script to attach required monitoring onboarding tags such as log analytics workspace resource id and clusterName tags to K8s master nodes or vmsses

``` sh

curl -sL https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/aksengine/kubernetes/AddMonitoringOnboardingTags.sh | bash -s <nameoftheCloud> <subscriptionId> <clusterResourceGroup> <logAnalyticsWorkspaceResourceId> <clusterName>

Example for AKS-Engine clusters in Azure Public cloud

curl -sL https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/aksengine/kubernetes/AddMonitoringOnboardingTags.sh | bash -s "AzureCloud" "00000000-0000-0000-0000-000000000000"  "my-aks-engine-cluster-rg"  "/subscriptions/<SubscriptionId>/resourceGroups/workspaceRg/providers/Microsoft.OperationalInsights/workspaces/workspaceName" "my-aks-engine-cluster"

Example for AKS-Engine clusters in Azure China cloud

curl -sL https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/aksengine/kubernetes/AddMonitoringOnboardingTags.sh | bash -s "AzureChinaCloud" "00000000-0000-0000-0000-000000000000"  "my-aks-engine-cluster-rg"  "/subscriptions/<SubscriptionId>/resourceGroups/workspaceRg/providers/Microsoft.OperationalInsights/workspaces/workspaceName" "my-aks-engine-cluster"

```
