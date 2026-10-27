@description('Name of the existing AKS cluster. Deploy this template to the cluster resource group.')
@minLength(1)
param clusterName string

@description('Azure region of the AKS cluster.')
param clusterLocation string

@description('DataCollectionRuleResourceId returned by the OTLP-enabled Application Insights component.')
@minLength(1)
param dataCollectionRuleResourceId string

@description('Optional association name. A deterministic name is generated from the DCR resource ID when omitted.')
param associationName string = ''

var effectiveAssociationName = empty(associationName)
  ? 'appmon-${uniqueString(dataCollectionRuleResourceId)}'
  : associationName

#disable-next-line BCP081
resource cluster 'Microsoft.ContainerService/managedClusters@2026-06-01' existing = {
  name: clusterName
}

#disable-next-line BCP081
resource association 'Microsoft.Insights/dataCollectionRuleAssociations@2025-05-11' = {
  name: effectiveAssociationName
  scope: cluster
  location: clusterLocation
  properties: {
    description: 'Associates the Application Insights OTLP data collection rule with the AKS cluster.'
    dataCollectionRuleId: dataCollectionRuleResourceId
  }
}

output associationName string = effectiveAssociationName
output associationResourceId string = association.id
