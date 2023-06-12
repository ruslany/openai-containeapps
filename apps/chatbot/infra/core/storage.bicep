param name string
param location string
param tags object = {}
param storageSKU string = 'Premium_LRS'
param shareName string = '${name}redisfiles'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: storageSKU
  }
  kind: 'FileStorage'
  properties: {
    supportsHttpsTrafficOnly: true
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' = {
  name: '${name}/default/${shareName}'
  dependsOn: [
    storageAccount
  ]
}

output storageName string = name
output shareName string = shareName
