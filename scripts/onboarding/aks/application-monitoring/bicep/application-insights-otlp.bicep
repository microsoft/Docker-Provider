@description('Name of the OTLP-enabled Application Insights component.')
@minLength(1)
param applicationInsightsName string

@description('Azure region for Application Insights and its workspaces.')
param location string = resourceGroup().location

@description('Let Application Insights create managed Log Analytics and Azure Monitor workspaces.')
param useManagedWorkspaces bool = true

@description('Resource ID of an existing Log Analytics workspace when useManagedWorkspaces is false.')
param logAnalyticsWorkspaceResourceId string = ''

@description('Resource ID of an existing Azure Monitor workspace when useManagedWorkspaces is false.')
param azureMonitorWorkspaceResourceId string = ''

param tags object = {}

var baseProperties = {
  Application_Type: 'web'
  AzureMonitorWorkspaceIngestionMode: 'Enabled'
  Flow_Type: 'Bluefield'
  Request_Source: 'rest'
}

var customerManagedWorkspaceProperties = {
  WorkspaceResourceId: logAnalyticsWorkspaceResourceId
  AzureMonitorWorkspaceResourceId: azureMonitorWorkspaceResourceId
}

var componentProperties = union(
  baseProperties,
  useManagedWorkspaces ? {} : customerManagedWorkspaceProperties
)

#disable-next-line BCP081
resource applicationInsights 'Microsoft.Insights/components@2025-01-23-preview' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: componentProperties
}

output applicationInsightsResourceId string = applicationInsights.id
output logAnalyticsWorkspaceResourceId string = applicationInsights.properties.WorkspaceResourceId
output azureMonitorWorkspaceResourceId string = applicationInsights.properties.AzureMonitorWorkspaceResourceId
output dataCollectionRuleResourceId string = applicationInsights.properties.DataCollectionRuleResourceId
output otlpLogsEndpoint string = applicationInsights.properties.OTLPLogsEndpoint
output otlpMetricsEndpoint string = applicationInsights.properties.OTLPMetricsEndpoint
output otlpTracesEndpoint string = applicationInsights.properties.OTLPTracesEndpoint
