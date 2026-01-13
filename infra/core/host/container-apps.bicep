metadata description = 'Creates an Azure Container Apps environment and references an existing Container Registry.'
param name string
param location string = resourceGroup().location
param tags object = {}

param containerAppsEnvironmentName string
param containerRegistryName string

module containerAppsEnvironment 'container-apps-environment.bicep' = {
  name: '${name}-container-apps-environment'
  params: {
    name: containerAppsEnvironmentName
    location: location
    tags: tags
  }
}

// Reference existing container registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2024-11-01-preview' existing = if (!empty(containerRegistryName)) {
  name: containerRegistryName
}

output defaultDomain string = containerAppsEnvironment.outputs.defaultDomain
output environmentName string = containerAppsEnvironment.outputs.name
output environmentId string = containerAppsEnvironment.outputs.id

output registryLoginServer string = !empty(containerRegistryName) ? containerRegistry.properties.loginServer : ''
output registryName string = !empty(containerRegistryName) ? containerRegistry.name : ''
