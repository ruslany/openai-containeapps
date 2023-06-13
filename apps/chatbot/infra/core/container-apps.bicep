param name string
param location string
param tags object = {}

param chatbotImageTag string = ''
param containerAppsEnvironmentName string
param identityName string
param containerRegistryName string
param storageMountName string


resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: containerAppsEnvironmentName
}

// 2022-02-01-preview needed for anonymousPullEnabled
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: containerRegistryName
}

resource openAIAccount 'Microsoft.CognitiveServices/accounts@2022-10-01' existing = {
  name: 'ruslany-openai'
  scope: resourceGroup('openai-cookbook')
}

var openAIAccountEndpoint = openAIAccount.properties.endpoint
var openAIAccountKey = openAIAccount.listKeys().key1

module containerRegistryAccess 'registry-access.bicep' = {
  name: '${deployment().name}-registry-access'
  params: {
    containerRegistryName: containerRegistryName
    principalId: userIdentity.properties.principalId
  }
}

var chatAppName = '${name}-chat'
resource chatApp 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: chatAppName
  location: location
  tags: union(tags, { 'azd-service-name': 'aca' })
  // It is critical that the identity is granted ACR pull access before the app is created
  // otherwise the container app will throw a provision error
  // This also forces us to use an user assigned managed identity since there would no way to
  // provide the system assigned identity with the ACR pull access before the app is created
  dependsOn: [ containerRegistryAccess ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${userIdentity.id}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      secrets: [
        {
          name: 'azureai-key'
          value: openAIAccountKey
        }
      ]
      activeRevisionsMode: 'single'
      ingress: {
        external: true
        targetPort: 8501
      }
      registries: [
        {
          server: '${containerRegistry.name}.azurecr.io'
          identity: userIdentity.id
        }
      ]
      maxInactiveRevisions: 5
    }
    template: {
      containers: [
        {
          image: !empty(chatbotImageTag) ? '${containerRegistry.name}.azurecr.io/openai-capps/chatbot:${chatbotImageTag}' : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: chatAppName
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
          env: [
            {
              name: 'AZURE_OPENAI_BASE_URL'
              value: openAIAccountEndpoint
            }
            {
              name: 'AZURE_OPENAI_API_KEY'
              secretRef: 'azureai-key'
            }
            {
              name: 'AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME'
              value: 'text-embedding-ada-002'
            }
            {
              name: 'AZURE_OPENAI_CHAT_DEPLOYMENT_NAME'
              value: 'gpt-35-turbo'
            }
            {
              name: 'AZURE_OPENAI_COMPLETIONS_DEPLOYMENT_NAME'
              value: 'text-davinci-003'
            }
            {
              name: 'REDIS_HOST'
              value: redisapp.name
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

var redisAppName = '${name}-redis'
var storageVolumeName = 'redisstoragevol'
resource redisapp 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: redisAppName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'single'
      ingress: {
        external: true
        targetPort: 6379
        exposedPort: 6379
        transport: 'TCP'
      }
      maxInactiveRevisions: 5
    }
    template: {
      containers: [
        {
          image: 'redis/redis-stack-server:latest'
          name: redisAppName
          resources: {
            cpu: json('2.0')
            memory: '4.0Gi'
          }
          volumeMounts: [
            {
              volumeName: storageVolumeName
              mountPath: '/data'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
        {
          name: storageVolumeName
          storageName: storageMountName
          storageType: 'AzureFile'
        }
      ]
    }
  }
}

output uri string = 'https://${chatApp.properties.configuration.ingress.fqdn}'
output identityPrincipalId string = userIdentity.properties.principalId
