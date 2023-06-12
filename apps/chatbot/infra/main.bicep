targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param name string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''

var tags = { 'azd-env-name': name }

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${name}-rg'
  location: location
  tags: tags
}

module azureRGDeployment 'azure-rg-deploy.bicep' = {
  name: 'azureRGDeployment'
  scope: resourceGroup
  params: {
    name: name
    location: location
    tags: tags
    //principalId: principalId
  }
}
