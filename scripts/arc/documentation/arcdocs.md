
# Enable monitoring of Azure Arc enabled Kubernetes cluster

[Azure Monitor for containers](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-overview) provides rich monitoring experience for Azure Arc enabled Kubernetes clusters.

> **Retirement Notice:** The script-based version of Azure Monitor for Arc enabled Kubernetes (preview) is being replaced with the extension model. Users will have until June 2021 to upgrade to the extension model. Details on how to enable monitoring via the extension model are detailed below.

This article describes how to [create](#create-azure-monitor-extension-instance), [display configuration settings](#display-configuration-settings) and [delete](#delete-extension-instance) the Azure Monitor for containers extension.

## Supported configurations

Azure Monitor for containers supports monitoring Azure Arc enabled Kubernetes (preview) as described in the [Overview](container-insights-overview.md) article, except for the following features:

- Live Data (preview)
- Users are not required to have [Owner](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner) permissions to [enable metrics](https://docs.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-update-metrics)


The following is officially supported with Azure Monitor for containers:

- Versions of Kubernetes and support policy are the same as versions of Azure Arc

- The following container runtimes are supported: Docker, Moby, and CRI compatible runtimes such CRI-O and ContainerD.

- Linux OS release for master and worker nodes supported are: Ubuntu (18.04 LTS and 16.04 LTS).

## Prerequisites

Before you start, make sure that you have the following:

- A Log Analytics workspace.

    Azure Monitor for containers supports a Log Analytics workspace in the regions listed in Azure [Products by region](https://azure.microsoft.com/global-infrastructure/services/?regions=all&products=monitor). To create your own workspace, it can be created through [Azure Resource Manager](../samples/resource-manager-workspace.md), through [PowerShell](../scripts/powershell-sample-create-workspace.md?toc=%2fpowershell%2fmodule%2ftoc.json), or in the [Azure portal](../learn/quick-create-workspace.md).

- To enable and access the features in Azure Monitor for containers, at a minimum you need to be a member of the Azure *Contributor* role in the Azure subscription, and a member of the [*Log Analytics Contributor*](../platform/manage-access.md#manage-access-using-azure-permissions) role of the Log Analytics workspace configured with Azure Monitor for containers.

- You are a member of the [Contributor](../../role-based-access-control/built-in-roles.md#contributor) role on the Azure Arc cluster resource.

- To view the monitoring data, you are a member of the [*Log Analytics reader*](../platform/manage-access.md#manage-access-using-azure-permissions) role permission with the Log Analytics workspace configured with Azure Monitor for containers.

- The following proxy and firewall configuration information is required for the containerized version of the Log Analytics agent for Linux to communicate with Azure Monitor:

    |Agent Resource|Ports |
    |------|---------|
    |`*.ods.opinsights.azure.com` |Port 443 |
    |`*.oms.opinsights.azure.com` |Port 443 |
    |`*.dc.services.visualstudio.com` |Port 443 |

- The containerized agent requires Kubelet's `cAdvisor secure port: 10250` or `unsecure port :10255` to be opened on all nodes in the cluster to collect performance metrics. We recommend you configure `secure port: 10250` on the Kubelet's cAdvisor if it's not configured already.

- The containerized agent requires the following environmental variables to be specified on the container in order to communicate with the Kubernetes API service within the cluster to collect inventory data - `KUBERNETES_SERVICE_HOST` and `KUBERNETES_PORT_443_TCP_PORT`.

    >[!IMPORTANT]
    >The minimum agent version supported for monitoring Arc-enabled Kubernetes clusters is ciprod04162020 or later.

- [PowerShell Core](/powershell/scripting/install/installing-powershell?view=powershell-6&preserve-view=true) is required if configuring proxy endpoint via Powershell.

- [Bash version 4](https://www.gnu.org/software/bash/)  is required if configuring proxy endpoint via Bash.



## Identify workspace resource ID

To enable monitoring of your cluster with an existing Log Analytics workspace, perform the following steps to first identify the full resource ID of your Log Analytics workspace. This is required for the `logAnalyticsWorkspaceResourceID` parameter when you run the command to enable the monitoring extension against the specified workspace.  This information can be found in the _Overview_ blade of your Log Analytics workspace through the Azure Portal or using the following steps via CLI.

1. List all the subscriptions that you have access to using the following command:

    ```azurecli
    az account list --all -o table
    ```

    The output will resemble the following:

    ```azurecli
    Name                                  CloudName    SubscriptionId                        State    IsDefault
    ------------------------------------  -----------  ------------------------------------  -------  -----------
    Microsoft Azure                       AzureCloud   0fb60ef2-03cc-4290-b595-e71108e8f4ce  Enabled  True
    ```

    Copy the value for **SubscriptionId**.

2. Switch to the subscription hosting the Log Analytics workspace using the following command:

    ```azurecli
    az account set -s <subscriptionId of the workspace>
    ```

3. The following example displays the list of workspaces in your subscriptions in the default JSON format.

    ```
    az resource list --resource-type Microsoft.OperationalInsights/workspaces -o json
    ```

    In the output, find the workspace name, and then copy the full resource ID of that Log Analytics workspace under the field **ID**.


## Migrate to the Extension Model

If you had previously deployed Azure Monitor for containers on this cluster using Helm directly without extensions, follow the instructions listed [here](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-optout-hybrid) to delete this Helm chart. Once the deletion is done, you can then proceed to subsequent sections on creating an extension instance for Azure Monitor for containers.


### Create Azure Monitor extension instance

Please check the [prerequisites](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-enable-arc-enabled-clusters#prerequisites) to verify you have the required permissions to enable container insights extension on your Azure Arc enabled Kubernetes clusters.

#### Onboarding via Portal

1.) In the Azure Portal, select the Arc enabled Kubernetes cluster that you wish to monitor.

2.) Select the Insights (preview) item under the Monitoring section
![](./Images/ArcResourceBlade.png)

3.) On the onboarding page, select the Configure Azure Monitor button
![](./Images/Onboarding.png)

4.) This will open up a context menu in the side, where you can select the [Log Analytics workspace](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/quick-create-workspace) to send your data to as well as your (optional) Arc proxy information.
![](./Images/OnboardingContext.png)

5.) To finish select the Configure button to start begin deploying the monitoring for your Arc enabled k8s.

#### Using Azure CLI

##### Option 1 - Create Azure Monitor for containers extension with default values

This option uses the following defaults:

- Creates or uses existing default log analytics workspace corresponding to the region of the cluster
- Auto-upgrade is enabled
- No Proxy configuration is done

Run the following command to create Microsoft.AzureMonitor.Containers extension with the default settings:

```console
az k8s-extension create --cluster-name <cluster-name> --resource-group <resource-group> --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --name azuremonitor-containers
```

##### Option 2 - Create Azure Monitor for containers extension *using existing Azure Log Analytics Workspace

Using this option, you can use an existing Azure Log Analytics workspace which can be in any subscription on which you have Contributor or a more permissive role assignment.

Run the following command to create azuremonitor-containers extension:

```console
az k8s-extension create --cluster-name <cluster-name> --resource-group <resource-group> --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --name azuremonitor-containers --configuration-settings logAnalyticsWorkspaceResourceID=<armResourceIdOfExistingWorkspace>
```

##### Option 3 - Create Azure Monitor for containers extension with forward proxy configuration and other defaults

With this option, you can set outbound proxy configuration by passing the endpoint in the **configuration protected settings**.

Run the following command to create extension with outbound proxy configuration:

```console
az k8s-extension create --cluster-name <cluster-name> --resource-group <resource-group> --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --name azuremonitor-containers --configuration-protected-settings proxyEndpoint=<proxyEndPoint>
```

Please refer to [the supported outbound proxy configuration](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-enable-arc-enabled-clusters#configure-proxy-endpoint) for more details.

##### Option 4 - Create Azure Monitor for containers extension with advanced configuration

The default requests and  limits should work for majority of the scenarios. But in case you want to tweak the resource requests and limits because your are running on clusters with a small footprint like IOT edge based clusters, you can use the advanced configurations settings to do so.

Run the following command to create extension with advanced configuration:

```console
az k8s-extension create --cluster-name <cluster-name> --resource-group <resource-group> --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --name azuremonitor-containers --configuration-settings  omsagent.resources.daemonset.limits.cpu=150m omsagent.resources.daemonset.limits.memory=600m omsagent.resources.deployment.limits.cpu=1 omsagent.resources.deployment.limits.memory=750m
```

Please refer to [resource requests and limits section of Helm chart](https://github.com/helm/charts/blob/master/incubator/azuremonitor-containers/values.yaml#L87) for the supported configuration settings related to resource constraints.

##### Option 5 - Create Azure Monitor for containers extension on Azure Stack Edge

Kubernetes clusters on [Azure Stack Edge](https://azure.microsoft.com/products/azure-stack/edge/#benefits) require custom mount path `/home/data/docker` for container logs.

Run the following command to create extension with configuration setting to indicate a custom mount path:

```bash
az k8s-extension create --cluster-name <cluster-name> --resource-group <resource-group> --cluster-type connectedClusters --extension-type Microsoft.AzureMonitor.Containers --name azuremonitor-containers --configuration-settings  omsagent.logsettings.custommountpath=/home/data/docker
```
#### Using Azure Resource Manager (ARM) Template
 
```bash
# 1. download arm template and parameter file
curl -L https://aka.ms/arc-k8s-azmon-extension-arm-template -o arc-k8s-azmon-extension-arm-template.json
curl -L https://aka.ms/arc-k8s-azmon-extension-arm-template-params -o  arc-k8s-azmon-extension-arm-template-params.json
# 2. update parameter values in arc-k8s-azmon-extension-arm-template-params.json file.For Azure Public cloud, value of workspaceDomain is `opinsights.azure.com`
# 3. deploy the arm template to create Azure Monitor for containers extension 
az login
az account set --subscription "Subscription Name"
az deployment group create --resource-group <clusterResourceGroup> --template-file ./arc-k8s-azmon-extension-arm-template.json --parameters @./arc-k8s-azmon-extension-arm-template-params.json
```

### **Delete existing Azure Monitor for containers extension**

[Deletion of the extension instance](./k8s-extensions.md#delete-extension-instance) only deletes the extension, but doesn't delete the Log Analytics workspace. The data intact within the Log Analytics resource is left intact.

## Configure proxy endpoint

With the containerized agent for Azure Monitor for containers, you can configure a proxy endpoint to allow it to communicate through your proxy server. Communication between the containerized agent and Azure Monitor can be an HTTP or HTTPS proxy server, and both anonymous and basic authentication (username/password) are supported.

The proxy configuration value has the following syntax: `[protocol://][user:password@]proxyhost[:port]`

> [!NOTE]
>If your proxy server does not require authentication, you still need to specify a psuedo username/password. This can be any username or password.

|Property| Description |
|--------|-------------|
|Protocol | http or https |
|user | Optional username for proxy authentication |
|password | Optional password for proxy authentication |
|proxyhost | Address or FQDN of the proxy server |
|port | Optional port number for the proxy server |

For example: `http://user01:password@proxy01.contoso.com:3128`

If you specify the protocol as **http**, the HTTP requests are created using SSL/TLS secure connection. Your proxy server must support SSL/TLS protocols.

### Configure using PowerShell

Specify the username and password, IP address or FQDN, and port number for the proxy server. For example:

```powershell
$proxyEndpoint = https://<user>:<password>@<proxyhost>:<port>
```

### Configure using bash

Specify the username and password, IP address or FQDN, and port number for the proxy server. For example:

```bash
export proxyEndpoint=https://<user>:<password>@<proxyhost>:<port>
```


### Known issue(s)

Currently, Azure Arc enabled Kubernetes cluster doesnt show up under Monitored clusters tab in  containers view of Azure Monitor even after creating the Azure Monitor for containers extension and this is known issue, we are planning to enable this integration in the next release.
Until then, the workaround is to attach  the `logAnalyticsWorkspaceResourceID` tag with fully qualified azure resource id of the Azure Log analytics worskpace which was used during the extension creation.

Here are the commands to attach the `logAnalyticsWorkspaceResourceID` tag on to your Azure Arc enabled Kubernetes cluster resource which has Azure Monitor for containers extension

```console
# set the cluster's subscription  for azure cli
az account set -s <subscriptionIdOftheArcConnectedCluster>

# get the extension config of azure monitor for containers
azmonextensionconfig=$(az k8s-extension show --cluster-name <clusterNameOftheCluster> --resource-group <resourceGroupOftheCluster> --cluster-type connectedClusters --name azuremonitor-containers)

# get the value of logAnalyticsWorkspaceResourceID which is  enabled during extension creation
logAnalyticsWorkspaceResourceID=$(echo $extensionconfig | jq -r '.configurationSettings.logAnalyticsWorkspaceResourceID')

# attach the tag  on to Azure Arc enabled Kubernetes cluster resource
clusterResourceId="/subscriptions/${clusterSubscriptionId}/resourceGroups/${clusterResourceGroup}/providers/Microsoft.Kubernetes/connectedClusters/${clusterName}"

# attach the logAnalyticsWorkspaceResourceID
az tag update --resource-id  $clusterResourceId  --operation merge --tags logAnalyticsWorkspaceResourceID=${logAnalyticsWorkspaceResourceID}
```

#### Disconnected Cluster Scenario
In some situations, your Arc enabled k8s may become disconnected from Azure. When the cluster is disconnected from Azure for over 48 hours, Azure Resource Graph will not have information on your cluster. The Insights blade itself may display incorrect information about your cluster state in this situation.


## Next steps

- With monitoring enabled to collect health and resource utilization of your Arc-enabled Kubernetes cluster and workloads running on them, learn [how to use](container-insights-analyze.md) Azure Monitor for containers.

- By default, the containerized agent collects the stdout/ stderr container logs of all the containers running in all the namespaces except kube-system. To configure container log collection specific to particular namespace or namespaces, review [Container Insights agent configuration](container-insights-agent-config.md) to configure desired data collection settings to your ConfigMap configurations file.

- To scrape and analyze Prometheus metrics from your cluster, review [Configure Prometheus metrics scraping](container-insights-prometheus-integration.md)

- To learn how to stop monitoring your Arc enabled Kubernetes cluster with Azure Monitor for containers, see [How to stop monitoring your hybrid cluster](container-insights-optout-hybrid.md#how-to-stop-monitoring-on-arc-enabled-kubernetes).