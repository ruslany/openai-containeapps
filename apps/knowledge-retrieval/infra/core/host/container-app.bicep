param name string
param location string = resourceGroup().location
param tags object = {}

param containerAppsEnvironmentName string
param containerName string = 'main'
param containerRegistryName string

@description('Minimum number of replicas to run')
@minValue(1)
param containerMinReplicas int = 1
@description('Maximum number of replicas to run')
@minValue(1)
param containerMaxReplicas int = 10

param secrets array = []
param env array = []
param external bool = true
param imageName string
param targetPort int = 80
param exposedPort int = 80

@description('User assigned identity name')
param identityName string

@description('Enabled Ingress for container app')
param ingressEnabled bool = true

@description('CPU cores allocated to a single container instance, e.g. 0.5')
param containerCpuCoreCount string = '0.5'

@description('Memory allocated to a single container instance, e.g. 1Gi')
param containerMemory string = '1.0Gi'

param storageMountName string = ''
param storageVolumeName string = ''
param storageMountPath string = ''

resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: identityName
}

module containerRegistryAccess '../security/registry-access.bicep' = {
  name: '${deployment().name}-registry-access'
  params: {
    containerRegistryName: containerRegistryName
    principalId: userIdentity.properties.principalId
  }
}

resource app 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: name
  location: location
  tags: tags
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
      activeRevisionsMode: 'single'
      ingress: ingressEnabled ? {
        external: external
        targetPort: targetPort
        exposedPort: external ? null : exposedPort
        transport: external ? 'auto' : 'TCP'
      } : null
      dapr: { enabled: false }
      secrets: secrets
      registries: [
        {
          server: '${containerRegistry.name}.azurecr.io'
          identity: userIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          image: !empty(imageName) ? imageName : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: containerName
          env: env
          resources: {
            cpu: json(containerCpuCoreCount)
            memory: containerMemory
          }
          volumeMounts: !empty(storageMountName) ? [
            {
              volumeName: storageVolumeName
              mountPath: storageMountPath
            }
          ] : null
        }
      ]
      scale: {
        minReplicas: containerMinReplicas
        maxReplicas: containerMaxReplicas
      }
      volumes: !empty(storageMountName) ? [
        {
          name: storageVolumeName
          storageName: storageMountName
          storageType: 'AzureFile'
        }
      ] : null
    }
  }
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: containerAppsEnvironmentName
}

// 2022-02-01-preview needed for anonymousPullEnabled
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: containerRegistryName
}

output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
output imageName string = imageName
output name string = app.name
output uri string = 'https://${app.properties.configuration.ingress.fqdn}'
