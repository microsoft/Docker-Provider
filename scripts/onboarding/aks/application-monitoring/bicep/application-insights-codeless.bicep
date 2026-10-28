@description('Name of the Application Insights component.')
@minLength(1)
param applicationInsightsName string

@description('Azure region for the resources.')
param location string = resourceGroup().location

@description('Create the Log Analytics workspace in this deployment.')
param createLogAnalyticsWorkspace bool = true

@description('Name of the Log Analytics workspace when createLogAnalyticsWorkspace is true.')
param logAnalyticsWorkspaceName string = 'app-monitoring-law'

@description('Resource ID of an existing Log Analytics workspace when createLogAnalyticsWorkspace is false.')
param logAnalyticsWorkspaceResourceId string = ''

@description('Log Analytics workspace retention in days.')
@minValue(30)
@maxValue(730)
param workspaceRetentionInDays int = 30

param tags object = {}

var effectiveLogAnalyticsWorkspaceResourceId = createLogAnalyticsWorkspace
  ? resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
  : logAnalyticsWorkspaceResourceId

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = if (createLogAnalyticsWorkspace) {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: workspaceRetentionInDays
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: effectiveLogAnalyticsWorkspaceResourceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  dependsOn: [
    logAnalyticsWorkspace
  ]
}

output applicationInsightsResourceId string = applicationInsights.id
output logAnalyticsWorkspaceResourceId string = effectiveLogAnalyticsWorkspaceResourceId
