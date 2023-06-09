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

var resourceToken = toLower(uniqueString(subscription().id, name, location))
var tags = { 'azd-env-name': name }

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${name}-rg'
  location: location
  tags: tags
}

var prefix = '${name}-${resourceToken}'

// Deploy log analytics
module logAnalyticsWorkspace 'core/monitor/loganalytics.bicep' = {
  name: 'loganalytics'
  scope: resourceGroup
  params: {
    name: '${prefix}-loganalytics'
    location: location
    tags: tags
  }
}

// Deploy a virtual network
module vnet 'core/network/vnet.bicep' = {
  name: 'virtual-network'
  scope: resourceGroup
  params: {
    name: '${prefix}-vnet'
    location: location
    tags: tags
  }
}

// Deploy storage
module storage 'core/storage/storage.bicep' = {
  name: 'storage'
  scope: resourceGroup
  params: {
    name: '${replace(resourceToken, '-', '')}storage'
    location: location
    tags: tags
  }
}

// Container apps environment and container registry
module containerApps 'core/host/container-apps.bicep' = {
  name: 'container-apps'
  scope: resourceGroup
  params: {
    name: 'app'
    location: location
    tags: tags
    containerAppsEnvironmentName: '${prefix}-containerapps-env'
    containerRegistryName: '${replace(prefix, '-', '')}registry'
    logAnalyticsWorkspaceName: logAnalyticsWorkspace.outputs.name
    vnetName: vnet.outputs.vnetName
    storageName: storage.outputs.storageName
    shareName: storage.outputs.shareName
  }
}

// // Container app
// module aca 'aca.bicep' = {
//   name: 'aca'
//   scope: resourceGroup
//   params: {
//     name: replace('${take(prefix,19)}-ca', '--', '-')
//     location: location
//     tags: tags
//     identityName: '${prefix}-id-aca'
//     containerAppsEnvironmentName: containerApps.outputs.environmentName
//     containerRegistryName: containerApps.outputs.registryName
//     imageName: ''
//   }
// }

// Container app
module acaRedis 'aca.bicep' = {
  name: 'aca-redis'
  scope: resourceGroup
  params: {
    name: replace('${take(prefix,19)}-redis', '--', '-')
    location: location
    tags: tags
    identityName: '${prefix}-id-aca'
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    containerRegistryName: containerApps.outputs.registryName
    imageName: 'redis/redis-stack-server:latest'
    external: false
    targetPort: 6379
    exposedPort: 6379
    storageVolumeName: 'redisstoragevol'
    storageMountPath: '/data'
    storageMountName: containerApps.outputs.redisStorageMountName
  }
}

module openAiRoleUser 'core/security/role.bicep' = {
  scope: resourceGroup
  name: 'openai-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'User'
  }
}


module openAiRoleBackend 'core/security/role.bicep' = {
  scope: resourceGroup
  name: 'openai-role-backend'
  params: {
    principalId: acaRedis.outputs.SERVICE_ACA_IDENTITY_PRINCIPAL_ID
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'ServicePrincipal'
  }
}

output AZURE_LOCATION string = location

output SERVICE_ACA_IDENTITY_PRINCIPAL_ID string = acaRedis.outputs.SERVICE_ACA_IDENTITY_PRINCIPAL_ID
output SERVICE_ACA_NAME string = acaRedis.outputs.SERVICE_ACA_NAME
output SERVICE_ACA_URI string = acaRedis.outputs.SERVICE_ACA_URI
output SERVICE_ACA_IMAGE_NAME string = acaRedis.outputs.SERVICE_ACA_IMAGE_NAME

output AZURE_CONTAINER_ENVIRONMENT_NAME string = containerApps.outputs.environmentName
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerApps.outputs.registryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerApps.outputs.registryName
