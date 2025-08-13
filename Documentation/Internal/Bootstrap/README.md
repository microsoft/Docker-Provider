
# 1. Create DCR and DCE resources in Public cloud
Note > DCE resources created only when enableRetinaNetworkFlowLogs or Microsoft-ContainerLogV2-HighScale or useAzureMonitorPrivateLinkScope enabled.
```sh
 az login --use-device-code --tenant
 az account -s <subscriptionId> # replace <subscriptionId> with value of the azure log analytics subscription Id
 # Download the ARM template and paramater file to create the ContainerInsights DCR
 curl -LO https://raw.githubusercontent.com/microsoft/Docker-Provider/refs/heads/ci_prod/Documentation/Internal/Bootstrap/dcr/containerInsightsDCR.json
 curl -LO https://raw.githubusercontent.com/microsoft/Docker-Provider/refs/heads/ci_prod/Documentation/Internal/Bootstrap/dcr/containerInsightsDCRParam.json
 # update the parameter values in containerInsightsDCRParam.json
 az group deployment create --resource-group <logAnalyticsWorkspaceRG> --template-file ./containerInsightsDCR.json --parameters @./containerInsightsDCRParam.json
 ```
 Azure Monitor Data Collection Rule resource created under the resource group Azure Log analytics workspace and get the azure resource id of the DCR.


# 2. Associate the DCR and DCEs to the AKS cluster in Bleu Cloud
```sh
 az login --use-device-code --tenant
 az account -s <subscriptionId> # replace <subscriptionId> with value of the AKS cluster subscription Id
 export DCR_RESOURCE_ID="<dcrResourceId>" # get the DCR resource id created in step #1
 export AKS_RESOURCE_ID="<aksResourceId>"
 az monitor data-collection rule association create \
    --name "ContainerInsightsExtension" \
    --rule-id "$DCR_RESOURCE_ID" \
    --resource "$AKS_RESOURCE_ID"
```

# 3. Enable the ContainerInsights Monitoring Addon
Note >
```sh
 # download the ARM template and parameter files to enable the containerinsights addon
 curl -LO https://raw.githubusercontent.com/microsoft/Docker-Provider/refs/heads/ci_prod/Documentation/Internal/Bootstrap/addon/existingClusterOnboarding.json
 curl -LO https://raw.githubusercontent.com/microsoft/Docker-Provider/refs/heads/ci_prod/Documentation/Internal/Bootstrap/addon/existingClusterParam.json
 # update the parameter values in existingClusterParam.json and then run below command
 az group deployment create --resource-group <aksClusterRG> --template-file ./existingClusterOnboarding.json --parameters @./existingClusterParam.json
```
# 4. Validatation

# 4.1. Check health of ama-logs pods
  ``` sh
    kubectl get pods -n kube-system -o wide | grep ama-logs # verify the pods are up and running
    kubectl logs <ama-logs-pod-name> -n kube-system -c ama-logs # verify the logs of the pods to ensure no errors
  ```
# 4.2. Check the data flow
 Navigate to configured Azure Log Analytics workspace in Bleu cloud and verify all the tables such as KubePodInventory, KubeNodeInventory and ContainerLogV2 etc.
 
