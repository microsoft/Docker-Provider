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

@description('Array of allowed syslog levels')
param syslogLevels array

@description('Array of allowed syslog facilities')
param syslogFacilities array

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

@description('An array of Container Insights Streams for Data collection')
param streams array

@description('The flag for enable containerlogv2 schema')
param enableContainerLogV2 bool

var clusterSubscriptionId = split(aksResourceId, '/')[2]
var clusterResourceGroup = split(aksResourceId, '/')[4]
var clusterName = split(aksResourceId, '/')[8]
var workspaceLocation = replace(workspaceRegion, ' ', '')
var dcrNameFull = 'MSCI-${workspaceLocation}-${clusterName}'
var dcrName = ((length(dcrNameFull) > 64) ? substring(dcrNameFull, 0, 64) : dcrNameFull)
var associationName = 'ContainerInsightsExtension'
var dataCollectionRuleId = resourceId(clusterSubscriptionId, clusterResourceGroup, 'Microsoft.Insights/dataCollectionRules', dcrName)

resource aks_monitoring_msi_dcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: dcrName
  location: workspaceRegion
  tags: resourceTagValues
  kind: 'Linux'
  properties: {
    dataSources: {
      syslog: [
        {
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: syslogFacilities
          logLevels: syslogLevels
          name: 'sysLogsDataSource'
        }
      ]
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
      {
        streams: [
          'Microsoft-Syslog'
        ]
        destinations: [
          'ciworkspace'
        ]
      }
    ]
  }
}

resource aks_monitoring_msi_addon 'Microsoft.ContainerService/managedClusters@2018-03-31' = {
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
