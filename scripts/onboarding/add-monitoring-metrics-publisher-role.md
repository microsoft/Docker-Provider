# How to add 'Monitoring Metrics Publisher' role assignment to the AKS cluster(s)

Monitoring Metrics Publishers role assignment required for AKS Monitoring agent (i.e. omsagent) to push the custom metrics to Azure Monitor for the cluster resource.

Custom metrics can be used to alert and also the pining the charts of these metrics to the azure portal dashboard.

For more details on custom metrics, read [custom-metrics-azure-monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/metrics-custom-overview)

You can either use the Azure CLI  or Powershell to add the role assignment to one or more existing AKS clusters which were onboarded to AKS Monitoring.

> Note: For adding role assignment, you must have access to the 'Microsoft.Authorization/roleAssignments/write' permission on the AKS cluster resource scope.
Of the built-in roles, only Owner and User Access Administrator are granted access to this permission. If you prefer granular level access to grant, recommended to go custom roles https://docs.microsoft.com/en-us/azure/role-based-access-control/custom-roles.

## Add the role assignment using Azure CLI

### For single AKS cluster using Azure CLI

``` sh
curl -sL https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/aks/mdmonboarding/mdm_onboarding.sh | bash -s <subscriptionId> <clusterResourceGroup> <clusterName>
```

The configuration change can take a few minutes to complete. When it finishes, you see a message similar to the following that includes the result:

``` sh
completed the role assignment
```

### For all AKS clusters in the specified subscription using Azure CLI

``` sh
curl -sL https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/aks/mdmonboarding/mdm_onboarding_atscale.sh | bash -s <subscriptionId>
```

The configuration change can take a few minutes to complete. When it finishes, you see a message similar to the following that includes the result:

``` sh
completed role assignments for all AKS clusters in subscription: <subscriptionId>
```

## Add the role assignment using Powershell

### For single AKS cluster using Powershell

Get the below powershell script files to your local computer.

- Powershell script file [mdm_onboarding.ps1](https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/aks/mdmonboarding/mdm_onboarding.ps1)
- Execute the mdm_onboarding.ps1 by passing the SubscriptionId, ResourceGroupName and clusterName of the AKS cluster

``` sh
.\mdm_onboarding.ps1 -SubscriptionId <AksClusterSubscriptionId> -ResourceGroupName <aksClusterResourceGroupName> -clusterName <aksClusterName>
```

The configuration change can take a few minutes to complete. When it finishes, you see a message similar to the following that includes the result:

``` sh
Successfully added Monitoring Metrics Publisher role assignment to cluster : <aksClusterName>
```

### For all AKS clusters in the specified subscription using Powershell

Get the below powershell script files to your local computer.

- Powershell script file [mdm_onboarding_atscale.ps1](https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/aks/mdmonboarding/mdm_onboarding_atscale.ps1)
- Execute the mdm_onboarding_atscale.ps1 by passing the SubscriptionId where are the AKS clusters in.

``` sh
.\mdm_onboarding_atscale.ps1 -SubscriptionId <AksClusterSubscriptionId>
```

The configuration change can take a few minutes to complete. When it finishes, you see a message similar to the following that includes the result:

``` sh
Completed adding role assignment for the aks clusters in subscriptionId : <AksClusterSubscriptionId>
```

After role assignment is enabled and cluster onboarded to monitoring addon already, then metrics should be visible in around 5 minutes also.
