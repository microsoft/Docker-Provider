1. Create AKS cluster in canary region
2. Create Application Insights in eastus2euap
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
3.Associate Managed DCR to the AKS cluster created in step 1
az monitor data-collection rule association create --name "otel-test-2-ai" --rule-id "/subscriptions/<subscriptionId> /resourceGroups/<managedResourceGroup>/providers/microsoft.insights/dataCollectionRules/<dcrName> " --resource "/subscriptions/<subscriptionId> /resourcegroups/<resourceGroup>/providers/Microsoft.ContainerService/managedClusters/<clusterName>"
4. Deploy the CI Addon with backdoor and image tag should be used is - mcr.microsoft.com/azuremonitor/containerinsights/cidev:3.1.28-24-g10402783c-20250908135555
5. Deploy the test app with following details:
Add a custom attribute:"microsoft.applicationId=<AppIdFromStep1> "
Add following env vars:
env:
    - name: NODE_IP
      valueFrom:
        fieldRef:
          fieldPath: status.hostIP
    - name: OTEL_EXPORTER_OTLP_ENDPOINT
      value: "http://$NODE_IP:28331"
6. Following tables should be flowing - OTelLogs, OTelSpans, OTelEvents and OTelResources