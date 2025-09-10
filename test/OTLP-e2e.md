1. Create AKS cluster in canary region
2. Register following feature on subscription if not registered already
``` sh
  az feature register --name Amcs20240311 --namespace Microsoft.Insights
  az provider register -n Microsoft.Insights
```
2. Create Application Insights in eastus2euap
``` sh
az rest --method put \
    --url "https://management.azure.com/subscriptions/<subId>/resourceGroups/<rgName>/providers/microsoft.insights/components/<aiResourceName>?api-version=2025-01-23-preview" \
    --body '{
      "location": "eastus2euap",
      "kind": "web",
      "properties": {
            "Application_Type": "web",
            "Flow_Type": "Bluefield",
            "Request_Source": "rest",
            "AzureMonitorWorkspaceIngestionMode": "Enabled",
            "CustomMetricsExclusivelyToAzureMonitorWorkspace": false
        }
    }'
 ```
3.Associate Managed DCR to the AKS cluster created in step 1
 ``` sh
az monitor data-collection rule association create --name "otel-test-2-ai" --rule-id "/subscriptions/<subscriptionId>/resourceGroups/<managedResourceGroup>/providers/microsoft.insights/dataCollectionRules/<dcrName> " --resource "/subscriptions/<subscriptionId>/resourcegroups/<resourceGroup>/providers/Microsoft.ContainerService/managedClusters/<clusterName>"
```
4. Deploy the CI Addon with backdoor and image tag should be used is - mcr.microsoft.com/azuremonitor/containerinsights/cidev:3.1.28-24-g10402783c-20250908135555
5. Deploy the test app with following details:
 > Note:  1. Add a custom attribute:"microsoft.applicationId=<AppIdFromStep1>" # This MUST be App Id of Application Insights Resource and Managed DCR of this AI resource associated with the cluster
 2. update other Key-value pairs of OTEL_RESOURCE_ATTRIBUTES values
Add following env vars:
``` sh
env:
  - name: NODE_IP
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
  - name: OTEL_EXPORTER_OTLP_TRACES_ENDPOINT
    value: "http://$(NODE_IP):28331"
  - name: OTEL_EXPORTER_OTLP_LOGS_ENDPOINT
   value: "http://$(NODE_IP):28331"
  - name: OTEL_EXPORTER_OTLP_TRACES_PROTOCOL
    value: "http/protobuf"
  - name: OTEL_EXPORTER_OTLP_LOGS_PROTOCOL
    value: "http/protobuf"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "microsoft.applicationId=<appId>,service.name=go-instrumented-test-app,service.instance.id=instance-1,service.version=1.0,deployment.environment=testing"
```
6. Following tables should be flowing - OTelLogs, OTelSpans, OTelEvents and OTelResources