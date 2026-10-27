targetScope = 'resourceGroup'

param linkedDeploymentName string
param templateUri string
param templateParameters object

#disable-next-line no-deployments-resources
resource linkedDeployment 'Microsoft.Resources/deployments@2022-09-01' = {
  name: linkedDeploymentName
  properties: {
    mode: 'Incremental'
    templateLink: {
      uri: templateUri
      contentVersion: '1.0.0.0'
    }
    parameters: templateParameters
  }
}
