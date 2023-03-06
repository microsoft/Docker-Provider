@description('Name of the alert')
@minLength(1)
param alertName string

@description('Description of alert')
param alertDescription string = ''

@description('Severity of alert {0,1,2,3,4}')
@allowed([
  0
  1
  2
  3
  4
])
param alertSeverity int = 3

@description('Specifies whether the alert is enabled')
param isEnabled bool = true

@description('Full Resource ID of the kubernetes cluster emitting the metric that will be used for the comparison. For example /subscriptions/00000000-0000-0000-0000-0000-00000000/resourceGroups/ResourceGroupName/providers/Microsoft.ContainerService/managedClusters/cluster-xyz')
@minLength(1)
param clusterResourceId string

@description('Operator comparing the current value with the threshold value.')
@allowed([
  'Equals'
  'NotEquals'
  'GreaterThan'
  'GreaterThanOrEqual'
  'LessThan'
  'LessThanOrEqual'
])
param operator string = 'GreaterThan'

@description('The threshold value at which the alert is activated.')
@minValue(1)
@maxValue(100)
param threshold int = 80

@description('How the data that is collected should be combined over time.')
@allowed([
  'Average'
  'Minimum'
  'Maximum'
  'Total'
  'Count'
])
param timeAggregation string = 'Average'

@description('Period of time used to monitor alert activity based on the threshold. Must be between one minute and one day. ISO 8601 duration format.')
@allowed([
  'PT1M'
  'PT5M'
  'PT15M'
  'PT30M'
  'PT1H'
  'PT6H'
  'PT12H'
  'PT24H'
])
param windowSize string = 'PT5M'

@description('how often the metric alert is evaluated represented in ISO 8601 duration format')
@allowed([
  'PT1M'
  'PT5M'
  'PT15M'
  'PT30M'
  'PT1H'
])
param evaluationFrequency string = 'PT1M'

@description('The ID of the action group that is triggered when the alert is activated or deactivated')
param actionGroupId string = ''

resource alert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertName
  location: 'global'
  tags: {
  }
  properties: {
    description: alertDescription
    severity: alertSeverity
    enabled: isEnabled
    scopes: [
      clusterResourceId
    ]
    evaluationFrequency: evaluationFrequency
    windowSize: windowSize
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: '1st criterion'
          criterionType: 'StaticThresholdCriterion'
          metricName: 'memoryWorkingSetPercentage'
          metricNamespace: 'Insights.Container/nodes'
          dimensions: [
            {
              name: 'host'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          operator: operator
          threshold: threshold
          timeAggregation: timeAggregation
          skipMetricValidation: true
        }
      ]
    }
    actions: (empty(actionGroupId) ? json('null') : json('[{"actionGroupId": "${actionGroupId}"}]'))
  }
}
