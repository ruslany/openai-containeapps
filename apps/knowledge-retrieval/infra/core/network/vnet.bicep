param name string
param nsgName string = '${name}-nsg'
param location string = resourceGroup().location
param tags object = {}

param addressPrefix string = '10.0.0.0/16'
param infraSubnetPrefix string = '10.0.0.0/24'
param defaultSubnetPrefix string = '10.0.1.0/24'

var infraSubnetName = 'infra-subnet'

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-ssh'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'allow-https-inbound'
        properties: {
          priority: 101
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [      
      {
        name: infraSubnetName
        properties: {
          addressPrefix: infraSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          delegations: [
            {
              name: 'Microsoft.App.Environments'
              id: resourceId('Microsoft.Network/virtualNetworks/subnets/delegations', name, infraSubnetName, 'Microsoft.App.Environments')
            }
          ]
        }
      }
      {
        name: 'default'
        properties: {
          addressPrefix: defaultSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

output vnetName string = name
output vnetId string = virtualNetwork.id
