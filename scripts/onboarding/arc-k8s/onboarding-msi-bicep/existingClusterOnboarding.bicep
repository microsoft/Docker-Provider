@description('Azure Arc Connected (Kubernetes) Cluster Resource ID')
param clusterResourceId string

@description('Location of the Azure Arc Connected Cluster e.g. "East US"')
param clusterRegion string

@description('Existing or new tags to use on Connected Cluster, ContainerInsights and DataCollectionRule Resources')
param resourceTagValues object

@description('Workspace Region for data collection rule')
param workspaceRegion string

@description('Full Resource ID of the log analytics workspace that will be used for data destination. For example /subscriptions/00000000-0000-0000-0000-0000-00000000/resourceGroups/ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/ws_xyz')
param workspaceResourceId string

@description('Azure Monitor Log Analytics Workspace Domain e.g. opinsights.azure.com')
@allowed([
  'opinsights.azure.com'
  'opinsights.azure.cn'
  'opinsights.azure.us'
  'opinsights.azure.eaglex.ic.gov'
  'opinsights.azure.microsoft.scloud'
  'opinsights.sovcloud-api.fr'
])
param workspaceDomain string = 'opinsights.azure.com'

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

@description('Enable Syslog data collection from the cluster')
param enableSyslog bool = false

@description('Array of allowed syslog levels (used when enableSyslog is true)')
param syslogLevels array = [
  'Debug'
  'Info'
  'Notice'
  'Warning'
  'Error'
  'Critical'
  'Alert'
  'Emergency'
]

@description('Array of allowed syslog facilities (used when enableSyslog is true)')
param syslogFacilities array = [
  'auth'
  'authpriv'
  'cron'
  'daemon'
  'mark'
  'kern'
  'local0'
  'local1'
  'local2'
  'local3'
  'local4'
  'local5'
  'local6'
  'local7'
  'lpr'
  'mail'
  'news'
  'syslog'
  'user'
  'uucp'
]

@description('An array of Container Insights Streams for Data collection')
param streams array

@description('Flag to indicate if Azure Monitor Private Link Scope should be used or not')
param useAzureMonitorPrivateLinkScope bool = false

@description('Specify the Resource Id of the Azure Monitor Private Link Scope (only used when useAzureMonitorPrivateLinkScope is true).')
param azureMonitorPrivateLinkScopeResourceId string = ''

var clusterSubscriptionId = split(clusterResourceId, '/')[2]
var clusterResourceGroup = split(clusterResourceId, '/')[4]
var clusterName = split(clusterResourceId, '/')[8]
var clusterLocation = replace(clusterRegion, ' ', '')

var workspaceLocation = replace(workspaceRegion, ' ', '')
var workspaceName = split(workspaceResourceId, '/')[8]
var workspaceSubscriptionId = split(workspaceResourceId, '/')[2]
var workspaceResourceGroup = split(workspaceResourceId, '/')[4]

var dcrNameFull = 'MSCI-${workspaceLocation}-${clusterName}'
var dcrName = ((length(dcrNameFull) > 64) ? substring(dcrNameFull, 0, 64) : dcrNameFull)
var associationName = 'ContainerInsightsExtension'
var dataCollectionRuleId = resourceId(clusterSubscriptionId, clusterResourceGroup, 'Microsoft.Insights/dataCollectionRules', dcrName)

var enableHighLogScaleMode = contains(streams, 'Microsoft-ContainerLogV2-HighScale')
var ingestionDceNameFull = 'MSCI-ingest-${workspaceLocation}-${clusterName}'
var ingestionDceName = (length(ingestionDceNameFull) > 43) ? substring(ingestionDceNameFull, 0, 43) : ingestionDceNameFull
var ingestionDce = endsWith(ingestionDceName, '-') ? substring(ingestionDceName, 0, 42) : ingestionDceName
var ingestionDataCollectionEndpointId = resourceId(clusterSubscriptionId, clusterResourceGroup, 'Microsoft.Insights/dataCollectionEndpoints', ingestionDce)

var configDceNameFull = 'MSCI-config-${clusterLocation}-${clusterName}'
var configDceName = (length(configDceNameFull) > 43) ? substring(configDceNameFull, 0, 43) : configDceNameFull
var configDce = endsWith(configDceName, '-') ? substring(configDceName, 0, 42) : configDceName
var configDceAssociationName = 'configurationAccessEndpoint'
var configDataCollectionEndpointId = resourceId(clusterSubscriptionId, clusterResourceGroup, 'Microsoft.Insights/dataCollectionEndpoints', configDce)

var privateLinkScopeName = useAzureMonitorPrivateLinkScope ? split(azureMonitorPrivateLinkScopeResourceId, '/')[8] : ''

// Existing workspace reference is required for customerId lookup. The azuremonitor-containers
// helm chart still gates DaemonSet/Deployment rendering on amalogs.secret.wsid being set even
// under MSI/AAD auth. customerId is a non-secret property (workspaces/read only).
// amalogs.secret.key is dummied below: USING_AAD_MSI_AUTH=true at runtime makes the agent
// ignore KEY, and the chart gate only checks that KEY != "<your_workspace_key>".
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: workspaceName
  scope: resourceGroup(workspaceSubscriptionId, workspaceResourceGroup)
}

resource connectedCluster 'Microsoft.Kubernetes/connectedClusters@2024-01-01' existing = {
  name: clusterName
}

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

resource arc_k8s_monitoring_msi_dcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: dcrName
  location: workspaceRegion
  tags: resourceTagValues
  kind: 'Linux'
  properties: {
    dataSources: {
      syslog: enableSyslog ? [
        {
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: syslogFacilities
          logLevels: syslogLevels
          name: 'sysLogsDataSource'
        }
      ] : []
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
    dataFlows: enableSyslog ? [
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
    ] : [
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
resource arc_k8s_monitoring_msi_dcra_config 'Microsoft.Kubernetes/connectedClusters/providers/dataCollectionRuleAssociations@2022-06-01' = if (useAzureMonitorPrivateLinkScope) {
  name: '${clusterName}/microsoft.insights/${configDceAssociationName}'
  properties: {
    description: 'Association of data collection rule endpoint. Deleting this association will break the data collection endpoint for this Arc K8s Cluster.'
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
  name: '${privateLinkScopeName}/${workspaceName}-connection'
  properties: {
    linkedResourceId: workspaceResourceId
  }
}

#disable-next-line BCP174
resource arc_k8s_monitoring_msi_dcra 'Microsoft.Kubernetes/connectedClusters/providers/dataCollectionRuleAssociations@2022-06-01' = {
  name: '${clusterName}/microsoft.insights/${associationName}'
  properties: {
    description: 'Association of data collection rule. Deleting this association will break the data collection for this Arc K8s Cluster.'
    dataCollectionRuleId: dataCollectionRuleId
  }
  dependsOn: [
    arc_k8s_monitoring_msi_dcr
  ]
}

resource arc_k8s_ci_extension 'Microsoft.KubernetesConfiguration/extensions@2022-11-01' = {
  name: 'azuremonitor-containers'
  scope: connectedCluster
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    extensionType: 'Microsoft.AzureMonitor.Containers'
    autoUpgradeMinorVersion: true
    releaseTrain: 'Stable'
    scope: {
      cluster: {
        releaseNamespace: 'azuremonitor-containers'
      }
    }
    configurationSettings: {
      logAnalyticsWorkspaceResourceID: workspaceResourceId
      'amalogs.domain': workspaceDomain
      'amalogs.useAADAuth': 'true'
    }
    configurationProtectedSettings: {
      'amalogs.secret.wsid': workspace.properties.customerId
      'amalogs.secret.key': 'aad-msi-auth-no-key-needed'
    }
  }
  dependsOn: [
    arc_k8s_monitoring_msi_dcra
  ]
}
