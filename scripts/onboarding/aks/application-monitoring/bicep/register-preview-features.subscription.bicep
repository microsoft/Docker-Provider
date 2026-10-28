targetScope = 'subscription'

@description('Register Microsoft.ContainerService/AzureMonitorAppMonitoringPreview in the AKS subscription.')
param registerAksApplicationMonitoringFeature bool = true

@description('Register Microsoft.Insights/OtlpApplicationInsights in the Application Insights subscription.')
param registerApplicationInsightsOtlpFeature bool = true

resource aksApplicationMonitoringFeature 'Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01' = if (registerAksApplicationMonitoringFeature) {
  name: 'Microsoft.ContainerService/AzureMonitorAppMonitoringPreview'
  properties: {}
}

resource applicationInsightsOtlpFeature 'Microsoft.Features/featureProviders/subscriptionFeatureRegistrations@2021-07-01' = if (registerApplicationInsightsOtlpFeature) {
  name: 'Microsoft.Insights/OtlpApplicationInsights'
  properties: {}
}

output aksApplicationMonitoringFeatureResourceId string = registerAksApplicationMonitoringFeature
  ? subscriptionResourceId(
      'Microsoft.Features/featureProviders/subscriptionFeatureRegistrations',
      'Microsoft.ContainerService',
      'AzureMonitorAppMonitoringPreview'
    )
  : ''

output applicationInsightsOtlpFeatureResourceId string = registerApplicationInsightsOtlpFeature
  ? subscriptionResourceId(
      'Microsoft.Features/featureProviders/subscriptionFeatureRegistrations',
      'Microsoft.Insights',
      'OtlpApplicationInsights'
    )
  : ''
