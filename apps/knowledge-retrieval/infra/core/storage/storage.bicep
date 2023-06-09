param name string
param tags object = {}
param storageSKU string = 'Premium_LRS'
param shareName string = '${name}redisfiles'
param location string

resource storage_account 'Microsoft.Storage/storageAccounts@2021-09-01' = {
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

resource file_share 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' = {
  name: '${name}/default/${shareName}'
  dependsOn: [
    storage_account
  ]
}

output storageName string = name
output shareName string = shareName
