@description('AKS Cluster Resource ID')
param aksResourceId string

@description('Location of the AKS resource e.g. "East US"')
param aksResourceLocation string

@description('Workspace Region for data collection rule')
param workspaceRegion string

@description('Full Resource ID of the log analitycs workspace that will be used for data destination')
param workspaceResourceId string

@description('Existing or new tags to use on AKS, ContainerInsights and DataCollectionRule Resources')
param resourceTagValues object

@description('An array of Kubernetes namespaces for Multi-tenancy logs filtering')
param k8sNamespaces array

@description('KQL filter for ingestion transformation')
param transformKql string

var clusterSubscriptionId = split(aksResourceId, '/')[2]
var clusterResourceGroup = split(aksResourceId, '/')[4]
var clusterName = split(aksResourceId, '/')[8]
var clusterLocation = replace(aksResourceLocation, ' ', '')
var workspaceLocation = replace(workspaceRegion, ' ', '')
var dcrNameFull = 'MSCI-multi-tenancy-${workspaceLocation}-${uniqueString(workspaceResourceId)}'
var dcrName = length(dcrNameFull) > 64 ? substring(dcrNameFull, 0, 64) : dcrNameFull
var associationName = 'ContainerLogV2Extension-${uniqueString(workspaceResourceId)}'
var dataCollectionRuleId = resourceId(clusterSubscriptionId, clusterResourceGroup, 'Microsoft.Insights/dataCollectionRules', dcrName)
var ingestionDCENameFull = 'MSCI-multi-tenancy-${workspaceLocation}-${uniqueString(workspaceResourceId)}'
var ingestionDCEName = length(ingestionDCENameFull) > 43 ? substring(ingestionDCENameFull, 0, 43) : ingestionDCENameFull
var ingestionDCE = endsWith(ingestionDCEName, '-') ? substring(ingestionDCEName, 0, 42) : ingestionDCEName
var ingestionDataCollectionEndpointId = resourceId(clusterSubscriptionId, clusterResourceGroup, 'Microsoft.Insights/dataCollectionEndpoints', ingestionDCE)

resource ingestionDataCollectionEndpoint 'Microsoft.Insights/dataCollectionEndpoints@2023-03-11' = {
  name: ingestionDCE
  location: workspaceLocation
  tags: resourceTagValues
  kind: 'Linux'
  properties: {}
}

resource aks_monitoring_msi_dcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: dcrName
  location: workspaceRegion
  tags: resourceTagValues
  kind: 'Linux'
  properties: {
    dataSources: {
      extensions: [
        {
          name: 'ContainerLogV2Extension'
          streams: [
            'Microsoft-ContainerLogV2-HighScale'
          ]
          extensionSettings: {
            dataCollectionSettings: {
              namespaces: k8sNamespaces
            }
          }
          extensionName: 'ContainerLogV2Extension'
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
        streams: [
          'Microsoft-ContainerLogV2-HighScale'
        ]
        destinations: [
          'ciworkspace'
        ]
        transformKql: empty(transformKql) ? null : transformKql
      }
    ]
    dataCollectionEndpointId: ingestionDataCollectionEndpointId
  }
}

#disable-next-line BCP174
resource aks_monitoring_msi_dcra 'Microsoft.ContainerService/managedClusters/providers/dataCollectionRuleAssociations@2023-03-11' = {
  name: '${clusterName}/microsoft.insights/${associationName}'
  properties: {
    description: 'Association of Logs Multi-tenancy collection rule. Deleting this association will break the Multi-tenancy logs data collection for this AKS Cluster.'
    dataCollectionRuleId: dataCollectionRuleId
  }
  dependsOn: [
    aks_monitoring_msi_dcr
  ]
}
