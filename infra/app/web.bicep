param name string
param location string = resourceGroup().location
param tags object = {}

param identityName string
param identityId string
param containerAppsEnvironmentName string
param containerRegistryName string
param serviceName string = 'web'
param aifoundryProjName string
param apiUrl string

var env = [
  // AZURE_CLIENT_ID is needed for DefaultAzureCredential
  {
    name: 'AZURE_CLIENT_ID'
    value: identityId
  }
  {
    name: 'API_URL'
    value: apiUrl
  }
  {
    name: 'AZURE_LOCATION'
    value: location
  }
  {
    name: 'AZURE_SUBSCRIPTION_ID'
    value: subscription().subscriptionId
  }
  {
    name: 'AZURE_RESOURCE_GROUP'
    value: resourceGroup().name
  }
  {
    name: 'AZURE_AI_FOUNDRY_PROJECT_NAME'
    value: aifoundryProjName
  }
  {
    name: 'ENVIRONMENT'
    value: 'azure'
  }
]

module app '../core/host/container-app-upsert.bicep' = {
  name: '${serviceName}-container-app-module'
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    identityName: identityName
    identityType: 'UserAssigned'
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    env: env
    targetPort: 80
  }
}

output SERVICE_WEB_NAME string = app.outputs.name
output SERVICE_WEB_URI string = app.outputs.uri
output SERVICE_WEB_IMAGE_NAME string = app.outputs.imageName
