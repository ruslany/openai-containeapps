param name string
param location string = resourceGroup().location
param tags object = {}

param identityName string
param containerAppsEnvironmentName string
param containerRegistryName string
param serviceName string = 'aca'
param imageName string = ''

param storageMountName string = ''
param storageVolumeName string = ''
param storageMountPath string = ''

param targetPort int = 80
param exposedPort int = 80
param external bool = true

resource acaIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

module app 'core/host/container-app.bicep' = {
  name: '${serviceName}-container-app-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    identityName: acaIdentity.name
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    imageName: imageName
    targetPort: targetPort
    exposedPort: exposedPort
    external: external
    storageMountName: storageMountName
    storageVolumeName: storageVolumeName
    storageMountPath: storageMountPath
  }
}

output SERVICE_ACA_IDENTITY_PRINCIPAL_ID string = acaIdentity.properties.principalId
output SERVICE_ACA_NAME string = app.outputs.name
output SERVICE_ACA_URI string = app.outputs.uri
output SERVICE_ACA_IMAGE_NAME string = app.outputs.imageName
