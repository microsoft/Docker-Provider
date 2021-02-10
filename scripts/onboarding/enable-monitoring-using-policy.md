# How to enable AKS Monitoring Addon via Azure Policy
This doc describes how to enable AKS Monitoring Addon using Azure Custom Policy.Monitoring Addon Custom Policy can be assigned  
either at subscription or resource group scope. If Azure Log Analytics workspace and AKS cluster are in different subscriptions then Managed Identity used by Policy assignnment has to have required role permissions on both the subscriptions or least on the resource of the Azure Log Aalytics workspace. Similarly, If the policy scoped to Resource Group, then Managed Identity should have required role permissions on the Log Analytics workspace if the workspace not in the selected Resource Group scope.

Monitoring Addon require following roles on the Managed Identity used by Azure Policy
 - [azure-kubernetes-service-contributor-role](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-kubernetes-service-contributor-role)
 - [log-analytics-contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#log-analytics-contributor)

## Create and Assign Policy definition using Azure Portal

### Create Policy Definition

1. Download the Azure Custom Policy definition to enable AKS Monitoring Addon
``` sh
 curl -o azurepolicy.json -L https://aka.ms/aks-enable-monitoring-custom-policy
```
2. Navigate to https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyMenuBlade/Definitions and  create policy definition  with the following details in the Policy definition  create dialogue box
 
 - Pick any Azure Subscription where you want to store Policy Definition
 - Name - '(Preview)AKS-Monitoring-Addon'
 - Description - 'Azure Custom Policy to enable Monitoring Addon onto Azure Kubernetes Cluster(s) in specified scope'
 - Category - Choose "use existing" and pick 'Kubernetes' from drop down
 - Remove the existing sample rules and copy the contents of azurepolicy.json downloaded in step #1 above

### Assign Policy Definition to Specified Scope

> Note: Managed Identity will be created automatically and assigned specified roles in the Policy definition.

3. Navigate to https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyMenuBlade/Definitions and select the Policy Definition 'AKS Monitoring Addon'
4. Click an Assignment and select Scope, Exclusions (if any)
5. Provide the Resource Id of the Azure Log Analytics Workspace. The Resource Id should be in this format `/subscriptions/<SubscriptionId>/resourceGroups/<ResourceGroup>/providers/Microsoft.OperationalInsights/workspaces/<workspaceName>`
6. Create Remediation task in case if you want apply to policy to existing AKS clusters in selected scope
7. Click and Review & Create Option to create Policy Assignment
   
## Create and Assign Policy definition using Azure CLI

### Create Policy Definition

1. Download the Azure Custom Policy definition rules and parameters files
    ``` sh
    curl -o azurepolicy.rules.json -L https://aka.ms/aks-enable-monitoring-custom-policy-rules
    curl -o azurepolicy.parameters.json -L https://aka.ms/aks-enable-monitoring-custom-policy-parameters
    ```
2. Create policy definition using below command 

  ``` sh
  az cloud set -n <AzureCloud | AzureChinaCloud | AzureUSGovernment> # set the Azure cloud
  az login # login to cloud environment 
  az account set -s <subscriptionId>
  az policy definition create --name "(Preview)AKS-Monitoring-Addon" --display-name "(Preview)AKS-Monitoring-Addon" --mode Indexed --metadata version=1.0.0 category=Kubernetes --rules azurepolicy.rules.json --params azurepolicy.parameters.json
  ```
### Assign Policy Definition to Specified Scope

3. Create policy assignment 

``` sh
az policy assignment create --name aks-monitoring-addon --policy "(Preview)AKS-Monitoring-Addon" --assign-identity --identity-scope /subscriptions/<subscriptionId> --role Contributor --scope /subscriptions/<subscriptionId> --location <locatio> --role Contributor --scope /subscriptions/<subscriptionId> -p "{ \"workspaceResourceId\": { \"value\":  \"/subscriptions/<subscriptionId>/resourcegroups/<resourceGroupName>/providers/microsoft.operationalinsights/workspaces/<workspaceName>\" } }"
```

## References
- https://docs.microsoft.com/en-us/azure/governance/policy/
- https://docs.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources#how-remediation-security-works
- https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
- https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-overview