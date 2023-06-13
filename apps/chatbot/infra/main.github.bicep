targetScope = 'resourceGroup'

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param name string

@description('Name of the container image of the chatbot app.')
param chatBotImageName string = ''

@minLength(1)
@description('Location for all resources')
param location string = resourceGroup().location

param exists bool = false

param tags object = {}

var resourceToken = toLower(uniqueString(subscription().id, name, location))

var prefix = '${name}-${resourceToken}'

// Deploy log analytics
module logAnalyticsWorkspace 'core/loganalytics.bicep' = {
  name: 'loganalytics'
  params: {
    name: '${prefix}-loganalytics'
    location: location
    tags: tags
  }
}

// Deploy a virtual network
module vnet 'core/vnet.bicep' = {
  name: 'virtual-network'
  params: {
    name: '${prefix}-vnet'
    location: location
    tags: tags
  }
}

// Deploy storage
module storage 'core/storage.bicep' = {
  name: 'storage'
  params: {
    name: '${replace(resourceToken, '-', '')}storage'
    location: location
    tags: tags
  }
}

// Container registry
module containerRegistry 'core/container-registry.bicep' = {
  name: 'container-registry'
  params: {
    name: '${replace(prefix, '-', '')}registry'
    location: location
    tags: tags
  }
}

// Container apps environment and container registry
module containerAppsEnvironment 'core/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  params: {
    name: '${prefix}-containerapps-env'
    location: location
    tags: tags
    logAnalyticsWorkspaceName: logAnalyticsWorkspace.outputs.name
    vnetName: vnet.outputs.vnetName
    storageName: storage.outputs.storageName
    shareName: storage.outputs.shareName
  }
}

var cappsprefix = replace('${take(prefix,19)}', '--', '-')
var chatBotAppName = '${cappsprefix}-chat'
resource existingChatBotApp 'Microsoft.App/containerApps@2022-03-01' existing = if (exists) {
  name: chatBotAppName
}

var chatBotImage = exists ? existingChatBotApp.properties.template.containers[0].image : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
var chatBotImageFinal = !empty(chatBotImageName) ? '${containerRegistry.name}.azurecr.io/${chatBotImageName}' : chatBotImage

// Container apps
module containerApps 'core/container-apps.bicep' = {
  name: 'container-apps'
  params: {
    name: cappsprefix
    location: location
    tags: tags
    chatBotImageName: chatBotImageFinal
    identityName: '${prefix}-id-aca'
    containerAppsEnvironmentName: containerAppsEnvironment.outputs.name
    containerRegistryName: containerRegistry.outputs.name
    storageMountName: containerAppsEnvironment.outputs.redisStorageMountName
  }
}

output SERVICE_ACACHAT_NAME string = chatBotAppName
output SERVICE_ACACHAT_IMAGE_NAME string = chatBotImageFinal

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string =containerRegistry.outputs.name
