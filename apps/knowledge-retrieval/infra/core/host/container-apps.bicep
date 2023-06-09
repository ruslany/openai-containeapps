param name string
param location string = resourceGroup().location
param tags object = {}

param containerAppsEnvironmentName string
param containerRegistryName string
param logAnalyticsWorkspaceName string
param vnetName string
param storageName string
param shareName string

module containerAppsEnvironment 'container-apps-environment.bicep' = {
  name: '${name}-container-apps-environment'
  params: {
    name: containerAppsEnvironmentName
    location: location
    tags: tags
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    vnetName: vnetName
    storageName: storageName
    shareName: shareName
  }
}

module containerRegistry 'container-registry.bicep' = {
  name: '${name}-container-registry'
  params: {
    name: containerRegistryName
    location: location
    tags: tags
  }
}

output defaultDomain string = containerAppsEnvironment.outputs.defaultDomain
output environmentName string = containerAppsEnvironment.outputs.name
output registryLoginServer string = containerRegistry.outputs.loginServer
output registryName string = containerRegistry.outputs.name
output redisStorageMountName string = containerAppsEnvironment.outputs.redisStorageMountName
