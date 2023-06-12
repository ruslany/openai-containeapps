param name string
param storageName string
param shareName string
param location string = resourceGroup().location
param tags object = {}

param logAnalyticsWorkspaceName string
param vnetName string

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-11-01-preview' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }      
    }    
    vnetConfiguration:{
      infrastructureSubnetId: vnet.properties.subnets[0].id
    }
    workloadProfiles: [
      {
        workloadProfileType: 'Consumption'
        name: 'Consumption'
      }
    ]
  }
}

resource redisstoragemount 'Microsoft.App/managedEnvironments/storages@2022-11-01-preview' = {
  parent: containerAppsEnvironment
  name: 'redisstoragemount'
  properties: {
    azureFile: {
      accountName: storage.name
      shareName: shareName
      accountKey: storageAccountKey
      accessMode: 'ReadWrite'
    }
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: vnetName
}

resource storage 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageName
}

var storageAccountKey = storage.listKeys().keys[0].value

output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
output name string = containerAppsEnvironment.name
output redisStorageMountName string = redisstoragemount.name
