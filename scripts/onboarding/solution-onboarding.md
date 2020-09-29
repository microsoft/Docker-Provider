# How to add 'AzureMonitor-Containers' solution to a Azure Loganalytics workspace

You can either use the Azure Powershell or Azure cli to deploy the solution.

## Create Deployment files
If you are not familiar with the concepts of deploying resources using a template with PowerShell, see [Deploy resources with Resource Manager templates and Azure PowerShell](https://review.docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-deploy)

1. Get the below template files to your local computer.
   - Template file [azuremonitor-containerSolution.json](https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/templates/azuremonitor-containerSolution.json)
   - TemplateParams file [azuremonitor-containerSolutionParams.json](https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/templates/azuremonitor-containerSolutionParams.json)
2. Edit the TemplateParams file in your local computer.
   * workspaceResourceId parameter :
       - Replace `<SubscriptionId>` with Azure subscriptionID for your Workspace
       - Replace `<ResourceGroup>` with Azure ResourceGroup name for your Workspace
       - Replace `<workspaceName>` with Azure Log Analytics Workspace name for your Workspace
   * workspaceRegion parameter :
       - Replace `<workspaceRegion>` with your Azure Log Analytics Workspace region

## Deploy using Powershell
- Use the following PowerShell commands from the folder containing the template files:

``` sh
# configure and login to the cloud of log analytics workspace.Specify the corresponding cloud environment of your workspace to below command.
Connect-AzureRmAccount -Environment <AzureCloud | AzureChinaCloud | AzureUSGovernment>
# set the context of the subscription of log analytics workspace
Set-AzureRmContext -SubscriptionId <subscription id of log analytics workspace>
# execute deployment command to add container insights solution to the specified log analytics workspace
New-AzureRmResourceGroupDeployment -Name OnboardCluster -ResourceGroupName <resource group of log analytics workspace> -TemplateFile .\azuremonitor-containerSolution.json -TemplateParameterFile .\azuremonitor-containerSolutionParams.json
```

The configuration change can take a few minutes to complete. When it finishes, you see a message similar to the following that includes the result:

``` sh
provisioningState       : Succeeded
```

## Deploy using Azure CLI on Linux
- Run the following command from the folder containing the template files:

``` sh
# configure the cloud of log analytics workspace.Specify the corresponding cloud environment of your workspace to below command.
az cloud set --name <AzureCloud | AzureChinaCloud | AzureUSGovernment>
az login
az account set --subscription "<Subscription Id or name of your Log Analytics Workspace>"
# execute deployment command to add container insights solution to the specified log analytics workspace
az group deployment create --resource-group <resource group of log analytics workspace> --template-file ./azuremonitor-containerSolution.json --parameters @./azuremonitor-containerSolutionParams.json
```

The configuration change can take a few minutes to complete. When it finishes, you see a message similar to the following that includes the result:

``` sh
provisioningState       : Succeeded
```

After monitoring is enabled, it can take around 15 minutes before you are able to see operational data for the cluster.