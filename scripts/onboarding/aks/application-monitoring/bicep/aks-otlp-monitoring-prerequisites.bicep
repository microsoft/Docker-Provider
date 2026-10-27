@description('Full resource ID of an existing AKS cluster that has not already been onboarded to Managed Prometheus or Container Insights.')
param clusterResourceId string

@description('Azure region of the AKS cluster.')
param clusterLocation string

@description('Azure region for the infrastructure Azure Monitor and Log Analytics workspaces. This can differ from the AKS region when both resource types and the Container Insights region mapping support the selected region.')
param monitoringWorkspaceLocation string

param createAzureMonitorWorkspace bool = true
param azureMonitorWorkspaceName string = 'aks-infrastructure-amw'

@description('Existing infrastructure Azure Monitor workspace resource ID when createAzureMonitorWorkspace is false. The workspace must be in this deployment\'s resource group and monitoringWorkspaceLocation.')
param azureMonitorWorkspaceResourceId string = ''

param createLogAnalyticsWorkspace bool = true
param logAnalyticsWorkspaceName string = 'aks-container-insights-law'

@description('Existing Log Analytics workspace resource ID when createLogAnalyticsWorkspace is false. The workspace must be in monitoringWorkspaceLocation.')
param logAnalyticsWorkspaceResourceId string = ''

@minValue(30)
@maxValue(730)
param logAnalyticsWorkspaceRetentionInDays int = 30

@description('Name for a new, dedicated Azure Managed Grafana resource.')
@minLength(2)
@maxLength(23)
param managedGrafanaName string

@description('Azure region for Azure Managed Grafana. This can differ from monitoringWorkspaceLocation when Grafana is unavailable in the workspace region.')
param managedGrafanaLocation string

param managedGrafanaSku string = 'Standard'

@description('Optional object ID of a user, group, service principal, or managed identity to grant Grafana Admin on the new Grafana resource.')
param grafanaAdminPrincipalId string = ''

@description('Microsoft Entra principal type for grafanaAdminPrincipalId. Use ServicePrincipal for managed identities.')
@allowed([
  'ForeignGroup'
  'Group'
  'ServicePrincipal'
  'User'
])
param grafanaAdminPrincipalType string = 'User'

param metricLabelsAllowlist string = ''
param metricAnnotationsAllowList string = ''
param enableControlPlaneMetrics bool = false
param containerInsightsStreams array = [
  'Microsoft-ContainerInsights-Group-Default'
]
param containerInsightsCollectionInterval string = '1m'

@description('Read and preserve the existing AKS tags when the Container Insights onboarding template updates the cluster.')
param preserveClusterTags bool = true

@description('Explicit AKS tags to use when preserveClusterTags is false.')
param clusterTags object = {}

param tags object = {}

var clusterSubscriptionId = split(clusterResourceId, '/')[2]
var clusterResourceGroup = split(clusterResourceId, '/')[4]
var effectiveAzureMonitorWorkspaceResourceId = createAzureMonitorWorkspace
  ? resourceId('Microsoft.Monitor/accounts', azureMonitorWorkspaceName)
  : azureMonitorWorkspaceResourceId
var effectiveLogAnalyticsWorkspaceResourceId = createLogAnalyticsWorkspace
  ? resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
  : logAnalyticsWorkspaceResourceId
var managedGrafanaResourceId = resourceId('Microsoft.Dashboard/grafana', managedGrafanaName)
var grafanaAdminRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '22926164-76b3-42b3-bc55-97df8dab3e41'
)
var managedPrometheusDeploymentName = 'enable-managed-prometheus-${uniqueString(clusterResourceId)}'
var containerInsightsDeploymentName = 'enable-container-insights-${uniqueString(clusterResourceId)}'
var managedPrometheusModuleName = 'application-monitoring-prometheus-${uniqueString(clusterResourceId)}'
var containerInsightsModuleName = 'application-monitoring-container-insights-${uniqueString(clusterResourceId)}'
var unusedPrivateLinkScopeResourceId = '/subscriptions/${clusterSubscriptionId}/resourceGroups/${clusterResourceGroup}/providers/Microsoft.Insights/privateLinkScopes/not-used'
var managedPrometheusTemplateUri = 'https://raw.githubusercontent.com/Azure/prometheus-collector/71a784f49d633b9f182a50c878c6dd48c75fd58d/AddonArmTemplate/FullAzureMonitorMetricsProfile.json'
var containerInsightsTemplateUri = 'https://raw.githubusercontent.com/microsoft/Docker-Provider/804bfb6d7eec35d04312fd5713559c65ab1fa548/scripts/onboarding/aks/onboarding-using-msi-auth/existingClusterOnboarding.json'
var clusterState = reference(clusterResourceId, '2026-06-01', 'Full')
var existingClusterTags = contains(clusterState, 'tags')
  ? empty(clusterState.tags)
    ? {}
    : clusterState.tags
  : {}
var effectiveClusterTags = preserveClusterTags ? existingClusterTags : clusterTags

resource azureMonitorWorkspace 'Microsoft.Monitor/accounts@2025-10-03' = if (createAzureMonitorWorkspace) {
  name: azureMonitorWorkspaceName
  location: monitoringWorkspaceLocation
  tags: tags
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = if (createLogAnalyticsWorkspace) {
  name: logAnalyticsWorkspaceName
  location: monitoringWorkspaceLocation
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logAnalyticsWorkspaceRetentionInDays
  }
}

resource managedGrafana 'Microsoft.Dashboard/grafana@2025-08-01' = {
  name: managedGrafanaName
  location: managedGrafanaLocation
  sku: {
    name: managedGrafanaSku
  }
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {}
}

module managedPrometheusDeployment './linked-template-deployment.bicep' = {
  name: managedPrometheusModuleName
  params: {
    linkedDeploymentName: managedPrometheusDeploymentName
    templateUri: managedPrometheusTemplateUri
    templateParameters: {
      azureMonitorWorkspaceResourceId: {
        value: effectiveAzureMonitorWorkspaceResourceId
      }
      azureMonitorWorkspaceLocation: {
        value: monitoringWorkspaceLocation
      }
      clusterResourceId: {
        value: clusterResourceId
      }
      clusterLocation: {
        value: clusterLocation
      }
      metricLabelsAllowlist: {
        value: metricLabelsAllowlist
      }
      metricAnnotationsAllowList: {
        value: metricAnnotationsAllowList
      }
      enableControlPlaneMetrics: {
        value: enableControlPlaneMetrics
      }
      grafanaResourceId: {
        value: managedGrafanaResourceId
      }
      grafanaLocation: {
        value: managedGrafanaLocation
      }
      grafanaSku: {
        value: managedGrafanaSku
      }
      roleNameGuid: {
        value: guid(effectiveAzureMonitorWorkspaceResourceId, managedGrafanaResourceId, 'Monitoring Data Reader')
      }
    }
  }
  dependsOn: [
    azureMonitorWorkspace
    managedGrafana
  ]
}

resource grafanaAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(grafanaAdminPrincipalId)) {
  name: guid(managedGrafanaResourceId, grafanaAdminPrincipalId, grafanaAdminRoleDefinitionId)
  scope: managedGrafana
  properties: {
    roleDefinitionId: grafanaAdminRoleDefinitionId
    principalId: grafanaAdminPrincipalId
    principalType: grafanaAdminPrincipalType
  }
  dependsOn: [
    managedPrometheusDeployment
  ]
}

module containerInsightsDeployment './linked-template-deployment.bicep' = {
  name: containerInsightsModuleName
  scope: resourceGroup(clusterSubscriptionId, clusterResourceGroup)
  params: {
    linkedDeploymentName: containerInsightsDeploymentName
    templateUri: containerInsightsTemplateUri
    templateParameters: {
      aksResourceId: {
        value: clusterResourceId
      }
      aksResourceLocation: {
        value: clusterLocation
      }
      resourceTagValues: {
        value: effectiveClusterTags
      }
      workspaceRegion: {
        value: monitoringWorkspaceLocation
      }
      workspaceResourceId: {
        value: effectiveLogAnalyticsWorkspaceResourceId
      }
      streams: {
        value: containerInsightsStreams
      }
      enableContainerLogV2: {
        value: true
      }
      enableSyslog: {
        value: false
      }
      syslogLevels: {
        value: []
      }
      syslogFacilities: {
        value: []
      }
      dataCollectionInterval: {
        value: containerInsightsCollectionInterval
      }
      namespaceFilteringModeForDataCollection: {
        value: 'Off'
      }
      namespacesForDataCollection: {
        value: []
      }
      useAzureMonitorPrivateLinkScope: {
        value: false
      }
      azureMonitorPrivateLinkScopeResourceId: {
        value: unusedPrivateLinkScopeResourceId
      }
    }
  }
  dependsOn: [
    logAnalyticsWorkspace
    managedPrometheusDeployment
  ]
}

output infrastructureAzureMonitorWorkspaceResourceId string = effectiveAzureMonitorWorkspaceResourceId
output containerInsightsLogAnalyticsWorkspaceResourceId string = effectiveLogAnalyticsWorkspaceResourceId
output managedGrafanaResourceId string = managedGrafanaResourceId
