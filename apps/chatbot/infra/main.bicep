targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param exists bool = false

var tags = { 'azd-env-name': environmentName }

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${environmentName}-rg'
  location: location
  tags: tags
}

module main 'main.github.bicep' = {
  name: 'azure-rg-deployment'
  scope: resourceGroup
  params: {
    name: environmentName
    location: location
    tags: tags
    chatBotImageName: ''
    exists: exists
  }
}

output SERVICE_ACA_NAME string = main.outputs.SERVICE_ACA_NAME
output SERVICE_ACA_IMAGE_NAME string = main.outputs.SERVICE_ACA_IMAGE_NAME

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = main.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output AZURE_CONTAINER_REGISTRY_NAME string = main.outputs.AZURE_CONTAINER_REGISTRY_NAME
