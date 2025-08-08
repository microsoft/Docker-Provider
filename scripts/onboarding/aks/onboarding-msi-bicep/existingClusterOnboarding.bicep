@description('AKS Cluster Resource ID')
param aksResourceId string

@description('Location of the AKS resource e.g. "East US"')
param aksResourceLocation string

@description('Existing or new tags to use on AKS, ContainerInsights and DataCollectionRule Resources')
param resourceTagValues object

@description('Workspace Region for data collection rule')
param workspaceRegion string

@description('Full Resource ID of the log analitycs workspace that will be used for data destination. For example /subscriptions/00000000-0000-0000-0000-0000-00000000/resourceGroups/ResourceGroupName/providers/Microsoft.operationalinsights/workspaces/ws_xyz')
param workspaceResourceId string

@description('Data collection interval e.g. "5m" for metrics and inventory. Supported value range from 1m to 30m')
param dataCollectionInterval string

@description('Data collection Filtering Mode for the namespaces')
@allowed([
  'Off'
  'Include'
  'Exclude'
])
param namespaceFilteringModeForDataCollection string = 'Off'

@description('An array of Kubernetes namespaces for the data collection of inventory, events and metrics')
param namespacesForDataCollection array

@description('The flag for enable containerlogv2 schema')
param enableContainerLogV2 bool

@description('An array of Container Insights Streams for Data collection')
param streams array

@description('Enable Retina Network Flow Logs in omsagent addon profile')
param enableRetinaNetworkFlowLogs bool = false

@description('Flag to indicate if Azure Monitor Private Link Scope should be used or not')
param useAzureMonitorPrivateLinkScope bool

@description('Specify the Resource Id of the Azure Monitor Private Link Scope.')
param azureMonitorPrivateLinkScopeResourceId string

var clusterSubscriptionId = split(aksResourceId, '/')[2]
var clusterResourceGroup = split(aksResourceId, '/')[4]
var clusterName = split(aksResourceId, '/')[8]
var workspaceLocation = replace(workspaceRegion, ' ', '')
var dcrNameFull = 'MSCI-${workspaceLocation}-${clusterName}'
var dcrName = ((length(dcrNameFull) > 64) ? substring(dcrNameFull, 0, 64) : dcrNameFull)
var associationName = 'ContainerInsightsExtension'
var dataCollectionRuleId = resourceId(clusterSubscriptionId, clusterResourceGroup, 'Microsoft.Insights/dataCollectionRules', dcrName)

var enableHighLogScaleMode = contains(streams, 'Microsoft-ContainerLogV2-HighScale') || enableRetinaNetworkFlowLogs
var ingestionDceNameFull = 'MSCI-ingest-${workspaceLocation}-${clusterName}'
var ingestionDceName = (length(ingestionDceNameFull) > 43) ? substring(ingestionDceNameFull, 0, 43) : ingestionDceNameFull
var ingestionDce = endsWith(ingestionDceName, '-') ? substring(ingestionDceName, 0, 42) : ingestionDceName
var clusterLocation = replace(aksResourceLocation, ' ', '')
var configDceNameFull = 'MSCI-config-${clusterLocation}-${clusterName}'
var configDceName = (length(configDceNameFull) > 43) ? substring(configDceNameFull, 0, 43) : configDceNameFull
var configDce = endsWith(configDceName, '-') ? substring(configDceName, 0, 42) : configDceName
var configDceAssociationName = 'configurationAccessEndpoint'
var configDataCollectionEndpointId = resourceId(clusterSubscriptionId, clusterResourceGroup, 'Microsoft.Insights/dataCollectionEndpoints', configDce)
var privateLinkScopeName = split(azureMonitorPrivateLinkScopeResourceId, '/')[8]

var ingestionDataCollectionEndpointId = resourceId(clusterSubscriptionId, clusterResourceGroup, 'Microsoft.Insights/dataCollectionEndpoints', ingestionDce)

resource configDataCollectionEndpoint 'Microsoft.Insights/dataCollectionEndpoints@2022-06-01' = if (useAzureMonitorPrivateLinkScope) {
  name: configDce
  location: clusterLocation
  tags: resourceTagValues
  kind: 'Linux'
  properties: {
    networkAcls: {
      publicNetworkAccess: useAzureMonitorPrivateLinkScope ? 'Disabled' : 'Enabled'
    }
  }
}

resource ingestionDataCollectionEndpoint 'Microsoft.Insights/dataCollectionEndpoints@2022-06-01' = if (enableHighLogScaleMode) {
  name: ingestionDce
  location: workspaceRegion
  tags: resourceTagValues
  kind: 'Linux'
  properties: {
    networkAcls: {
      publicNetworkAccess: useAzureMonitorPrivateLinkScope ? 'Disabled' : 'Enabled'
    }
  }
}

resource aks_monitoring_msi_dcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: dcrName
  location: workspaceRegion
  tags: resourceTagValues
  kind: 'Linux'
  properties: {
    dataSources: {
      extensions: [
        {
          name: 'ContainerInsightsExtension'
          streams: streams
          extensionSettings: {
            dataCollectionSettings: {
              interval: dataCollectionInterval
              namespaceFilteringMode: namespaceFilteringModeForDataCollection
              namespaces: namespacesForDataCollection
              enableContainerLogV2: enableContainerLogV2
            }
          }
          extensionName: 'ContainerInsights'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: workspaceResourceId
          name: 'ciworkspace'
        }
      ]
    }
    dataFlows: [
      {
        streams: streams
        destinations: [
          'ciworkspace'
        ]
      }
    ]
    dataCollectionEndpointId: enableHighLogScaleMode ? ingestionDataCollectionEndpointId : null
  }
}

#disable-next-line BCP174
resource aks_monitoring_msi_dcra_config 'Microsoft.ContainerService/managedClusters/providers/dataCollectionRuleAssociations@2022-06-01' = if (useAzureMonitorPrivateLinkScope) {
  name: '${clusterName}/microsoft.insights/${configDceAssociationName}'
  properties: {
    description: 'Association of data collection rule endpoint. Deleting this association will break the data collection endpoint for this AKS Cluster.'
    dataCollectionEndpointId: configDataCollectionEndpointId
  }
  dependsOn: [
    configDataCollectionEndpoint
  ]
}

resource privateLinkScope_config 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = if (useAzureMonitorPrivateLinkScope) {
  name: '${privateLinkScopeName}/${configDce}-connection'
  properties: {
    linkedResourceId: configDataCollectionEndpointId
  }
  dependsOn: [
    configDataCollectionEndpoint
  ]
}

resource privateLinkScope_ingestion 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = if (useAzureMonitorPrivateLinkScope && enableHighLogScaleMode) {
  name: '${privateLinkScopeName}/${ingestionDce}-connection'
  properties: {
    linkedResourceId: ingestionDataCollectionEndpointId
  }
  dependsOn: [
    ingestionDataCollectionEndpoint
  ]
}

resource privateLinkScope_workspace 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = if (useAzureMonitorPrivateLinkScope) {
  name: '${privateLinkScopeName}/${split(workspaceResourceId, '/')[8]}-connection'
  properties: {
    linkedResourceId: workspaceResourceId
  }
}

resource aks_monitoring_msi_addon 'Microsoft.ContainerService/managedClusters@2023-04-01' = {
  name: clusterName
  location: aksResourceLocation
  tags: resourceTagValues
  properties: {
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: workspaceResourceId
          useAADAuth: 'true'
          enableRetinaNetworkFlags: enableRetinaNetworkFlowLogs ? 'true' : 'false'
        }
      }
    }
  }
  dependsOn: [
    aks_monitoring_msi_dcra
  ]
}

#disable-next-line BCP174
resource aks_monitoring_msi_dcra 'Microsoft.ContainerService/managedClusters/providers/dataCollectionRuleAssociations@2022-06-01' = {
  name: '${clusterName}/microsoft.insights/${associationName}'
  properties: {
    description: 'Association of data collection rule. Deleting this association will break the data collection for this AKS Cluster.'
    dataCollectionRuleId: dataCollectionRuleId
  }
  dependsOn: [
    aks_monitoring_msi_dcr
  ]
}
