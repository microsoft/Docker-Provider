# Troubleshoot Guide for Azure Monitor for containers

# Azure Kubernetes Service (AKS)
The table below summarizes known issues you may face while using Azure Monitor for containers .

| Issues and Error Messages  | Action |
| ---- | --- |
| Error Message `No data for selected filters`  | It may take some time to establish monitoring data flow for newly created clusters. Please allow at least 10-15 minutes for data to appear for your cluster. |
| Error Message `Error retrieving data` | While Azure Kubenetes Service cluster is setting up for health and performance monitoring, a connection is established between the cluster and Azure Log Analytics workspace. Log Analytics workspace is used to store all monitoring data for your cluster. This error may occurr when your Log Analytics workspace has been deleted or lost. Please check whether your Log Analytics workspace is available. To find your Log Analytics workspace go [here.](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-manage-access) and your workspace is available. If the workspace is missing, you will need to re-onboard Container Health to your cluster. To re-onboard, you will need to [opt out](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-optout) of monitoring for the cluster and [onboard](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-enable-existing-clusters) again to Container Health. |
| `Error retrieving data` after adding Container Health through az aks cli | When onboarding using az aks cli, very seldom, Container Health may not be properly onboarded. Please check whether the Container Insights Solution is onboarded. To do this, go to your [Log Analytics workspace](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-manage-access) and see if Container Insights Solution is available by going to the "Solutions" tab under General. To resolve this issue, you will need to redeploy the Container Insights Solution. Please follow the instructions on [how to deploy Azure Monitor - container health solution to your Log Analytics workspace. ](https://github.com/microsoft/Docker-Provider/blob/ci_prod/scripts/onboarding/solution-onboarding.md) |
| Failed to `Enable fast alerting experience on basic metrics for this Azure Kubernetes Services cluster`  | The action is trying to grant the Monitoring Metrics Publisher role assignment on the cluster resource. The user initiating the process must have access to the **Microsoft.Authorization/roleAssignments/write** permission on the AKS cluster resource scope. Only members of the **Owner** and **User Access Administrator** built-in roles are granted access to this permission. If your security policies require assigning granular level permissions, we recommend you view [custom roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/custom-roles) and assign it to the users who require it. |

# Azure Red Hat OpenShift Service (ARO)
The table below summarizes known issues you may face while using Azure Monitor for containers .

| Issues and Error Messages  | Action |
| ---- | --- |
| Error Message `No data for selected filters`  | It may take some time to establish monitoring data flow for newly created clusters. Please allow at least 10-15 minutes for data to appear for your cluster. |
| Error Message `Error retrieving data` | While ARO cluster is setting up for health and performance monitoring, a connection is established between the cluster and Azure Log Analytics workspace. Log Analytics workspace is used to store all monitoring data for your cluster. This error may occurr when your Log Analytics workspace has been deleted or lost. Please check whether your Log Analytics workspace is available. To find your Log Analytics workspace go [here.](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-manage-access) and your workspace is available. If the workspace is missing, you will need to re-onboard Container Health to your cluster. To re-onboard, you will need to [opt out](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-optout) of monitoring for the cluster and [onboard](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-azure-redhat-setup) again to Container Health. |

# AKS-engine Kubernetes

The table below summarizes known issues you may face while using Azure Monitor for containers .

| Issues and Error Messages  | Action |
| ---- | --- |
| Error Message `No data for selected filters`  | It may take some time to establish monitoring data flow for newly created clusters. Please allow at least 10-15 minutes for data to appear for your cluster. |
| Error Message `Error retrieving data` | While Aks-Engine cluster is setting up for health and performance monitoring, a connection is established between the cluster and Azure Log Analytics workspace. Log Analytics workspace is used to store all monitoring data for your cluster. This error may occurr when your Log Analytics workspace has been deleted or lost. Please check whether your Log Analytics workspace is available. To find your Log Analytics workspace go [here.](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-manage-access) and your workspace is available. If the workspace is missing, you will need to re-onboard Container Health to your cluster. To re-onboard, you will need to [onboard](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-enable-existing-clusters) again to Container Health. |


# Troubleshooting script

Prequisites:
- For AKS or ARO Cluster, Collect ResourceId of the cluster
- For AKS-Engine Cluster, Collect SubscriptionId and ResourceGroupName of the cluster where are resources exists

# AKS or ARO

You can use the troubleshooting script provided [here](https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/troubleshoot/TroubleshootError.ps1) to diagnose the problem.

Steps:
- Open powershell using the [cloudshell](https://docs.microsoft.com/en-us/azure/cloud-shell/overview) in the azure portal.
 > Note: This script supported on any Powershell supported environment: Windows and Non-Windows.
 For Linux, refer [Install-Powershell-On-Linux](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-6) and
 For Mac OS, refer [install-powershell-core-on-mac](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos?view=powershell-6) how to install powershell
- Make sure that you're using powershell (selected by default)
- Run the following command to change home directory - `cd ~`
- Run the following command to download the script - `curl -LO https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/troubleshoot/TroubleshootError.ps1`
 > Note: In some versions of Powershell above CURL command may not work in such cases, you can try  `curl https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/troubleshoot/TroubleshootError.ps1 -O TroubleshootError.ps1`
- Run the following command to execute the script - `./TroubleshootError.ps1 -ClusterResourceId <resourceIdoftheCluster>`
    > Note: For AKS, resourceIdoftheCluster should be in this format `/subscriptions/<subId>/resourceGroups/<rgName>/providers/Microsoft.ContainerService/managedClusters/<clusterName>`.For ARO, should be in this format `/subscriptions/<subId>/resourceGroups/<rgName>/providers/Microsoft.ContainerService/openShiftManagedClusters/<clusterName>`.
- This script will generate a TroubleshootDump.txt which collects detailed information about container health onboarding.
- Please send this file to [AskCoin](mailto:askcoin@microsoft.com). We will respond back to you.

# Aks-Engine Kubernetes

You can use the troubleshooting script provided [here](https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/troubleshoot/TroubleshootError_AcsEngine.ps1) to diagnose the problem.

Steps:
- Download [TroubleshootError_AcsEngine.ps1](https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/troubleshoot/TroubleshootError_AcsEngine.ps1), [ContainerInsightsSolution.json](https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/troubleshoot/ContainerInsightsSolution.json)
- Collect Subscription ID, Resource group name of the Aks-Engine Kubernetes cluster
- Use the following command to run the script : `.\TroubleshootError_AcsEngine.ps1 -SubscriptionId <subId> -ResourceGroupName <rgName>`.
This script will generate a TroubleshootDump.txt which collects detailed information about container health onboarding.
Please send this file to [AskCoin](mailto:askcoin@microsoft.com). We will respond back to you.
- Please remember to 'Set-ExecutionPolicy' to what it was previously(from the value stored in the file) after you've run the script

For more details on Azure Resource Manager template deployment via cli refer to [this documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-deploy-cli).

If steps above did not help to resolve your issue, you can use either of the following methods to contact us for help:
*	File a [GitHub Issue](https://github.com/Microsoft/OMS-docker/issues)
*	Email [AskCoin](mailto:askcoin@microsoft.com) : Please attach the TroubleshootErrorDump.txt in the email generated by the troubleshooting script if you had tried running the script to solve your problem.
