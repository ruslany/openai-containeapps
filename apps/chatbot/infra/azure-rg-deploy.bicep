targetScope = 'resourceGroup'

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param name string

@minLength(1)
@description('Tag of the container image of the chatbot app')
param chatBotImageTag string

@minLength(1)
@description('Location for all resources')
param location string = resourceGroup().location

//@description('Id of the user or app to assign application roles')
//param principalId string = ''

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

// Container apps
module containerApps 'core/container-apps.bicep' = {
  name: 'aca-redis'
  params: {
    name: replace('${take(prefix,19)}', '--', '-')
    location: location
    tags: tags
    chatbotImageTag: chatBotImageTag
    identityName: '${prefix}-id-aca'
    containerAppsEnvironmentName: containerAppsEnvironment.outputs.name
    containerRegistryName: containerRegistry.outputs.name
    storageMountName: containerAppsEnvironment.outputs.redisStorageMountName
  }
}

// module openAiRoleUser 'core/role.bicep' = {
//   name: 'openai-role-user'
//   params: {
//     principalId: principalId
//     roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
//     principalType: 'User'
//   }
// }


// module openAiRoleBackend 'core/role.bicep' = {
//   name: 'openai-role-backend'
//   params: {
//     principalId: containerApps.outputs.identityPrincipalId
//     roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
//     principalType: 'ServicePrincipal'
//   }
// }
