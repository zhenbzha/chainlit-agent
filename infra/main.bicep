targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

param containerRegistryName string = ''
param aiFoundryName string = ''
@description('The Azure AI Foundry project name. If omitted will be generated')
param aiProjectName string = ''

@description('The Azure Search connection name. If omitted will use a default value')
param searchConnectionName string = ''
var abbrs = loadJsonContent('./abbreviations.json')
param useContainerRegistry bool = true
param useSearch bool = true
var aiConfig = loadYamlContent('./ai.yaml')

@description('The API version of the OpenAI resource')
param openAiApiVersion string = '2025-03-01-preview'

@description('The type of the OpenAI resource')
param openAiType string = 'azure'

@description('The name of the search service')
param searchServiceName string = ''

@description('The name of the OpenAI embedding deployment')
param openAiEmbeddingDeploymentName string = 'text-embedding-3-large'

@description('The name of the AI search index')
param aiSearchIndexName string

// this needs to align with the model defined in ai.yaml
@description('The name of the OpenAI deployment')
param openAiDeploymentName string = 'gpt-4o'

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('Whether the deployment is running on GitHub Actions')
param runningOnGh string = ''

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

var prefix = toLower('${environmentName}-${resourceToken}')

// USER ROLES
var principalType = empty(runningOnGh) ? 'User' : 'ServicePrincipal'

module managedIdentity 'core/security/managed-identity.bicep' = {
  name: 'managed-identity'
  scope: resourceGroup
  params: {
    name: 'id-${resourceToken}'
    location: location
    tags: tags
  }
}

// Azure AI Search
module searchService 'core/search/search-services.bicep' = if (useSearch) {
  name: 'search'
  scope: resourceGroup
  params: {
    name: !empty(searchServiceName) ? searchServiceName : '${abbrs.searchSearchServices}${resourceToken}'
    location: location
    semanticSearch: 'standard'
  }
}

// AI Foundry (replaces hub + project + cognitiveservices)
module aiFoundry 'core/ai/ai-foundry.bicep' = {
  name: 'ai-foundry'
  scope: resourceGroup
  params: {
    name: !empty(aiFoundryName) ? aiFoundryName : 'aif-${resourceToken}'
    projectName: !empty(aiProjectName) ? aiProjectName : 'aif-proj-${resourceToken}'
    location: location
    tags: tags
    deployments: array(aiConfig.?deployments ?? [])
    searchServiceName: useSearch ? searchService.outputs.name : ''
    searchConnectionName: !empty(searchConnectionName) ? searchConnectionName : 'search-service-connection'
    principalId: managedIdentity.outputs.managedIdentityPrincipalId
  }
}

// Container Registry
module containerRegistry 'core/host/container-registry.bicep' = if (useContainerRegistry) {
  name: 'container-registry'
  scope: resourceGroup
  params: {
    name: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
  }
}

// Container apps host
module containerApps 'core/host/container-apps.bicep' = {
  name: 'container-apps'
  scope: resourceGroup
  params: {
    name: 'app'
    location: location
    tags: tags
    containerAppsEnvironmentName: '${prefix}-containerapps-env'
    containerRegistryName: useContainerRegistry ? containerRegistry.outputs.name : ''
  }
}

module api 'app/api.bicep' = {
  name: 'api'
  scope: resourceGroup
  params: {
    name: replace('${take(prefix, 19)}-api', '--', '-')
    location: location
    tags: tags
    identityName: managedIdentity.outputs.managedIdentityName
    identityId: managedIdentity.outputs.managedIdentityClientId
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    containerRegistryName: containerApps.outputs.registryName
    openAiDeploymentName: openAiDeploymentName
    openAiEmbeddingDeploymentName: openAiEmbeddingDeploymentName
    openAiEndpoint: aiFoundry.outputs.endpoint
    openAiType: openAiType
    openAiApiVersion: openAiApiVersion
    aiSearchEndpoint: useSearch ? 'https://${searchService.outputs.name}.search.windows.net' : ''
    aiSearchIndexName: aiSearchIndexName
    aifoundryProjName: aiFoundry.outputs.projectName
  }
}

module web 'app/web.bicep' = {
  name: 'web'
  scope: resourceGroup
  params: {
    name: replace('${take(prefix, 19)}-web', '--', '-')
    location: location
    tags: tags
    identityName: managedIdentity.outputs.managedIdentityName
    identityId: managedIdentity.outputs.managedIdentityClientId
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    containerRegistryName: containerApps.outputs.registryName
    aifoundryProjName: aiFoundry.outputs.projectName
    apiUrl: api.outputs.SERVICE_API_URI
  }
}

// RBAC Role Assignments
module aiSearchRole 'core/security/role.bicep' = if (useSearch) {
  scope: resourceGroup
  name: 'ai-search-index-data-contributor'
  params: {
    principalId: managedIdentity.outputs.managedIdentityPrincipalId
    roleDefinitionId: '8ebe5a00-799e-43f5-93ac-243d3dce84a7' // Search Index Data Contributor
    principalType: 'ServicePrincipal'
  }
}

module userAiSearchRole 'core/security/role.bicep' = if (!empty(principalId) && useSearch) {
  scope: resourceGroup
  name: 'user-ai-search-index-data-contributor'
  params: {
    principalId: principalId
    roleDefinitionId: '8ebe5a00-799e-43f5-93ac-243d3dce84a7' // Search Index Data Contributor
    principalType: principalType
  }
}

module openaiRoleUser 'core/security/role.bicep' = if (!empty(principalId)) {
  scope: resourceGroup
  name: 'user-openai-user'
  params: {
    principalId: principalId
    roleDefinitionId: 'a001fd3d-188f-4b5d-821b-7da978bf7442' // Cognitive Services OpenAI Contributor
    principalType: principalType
  }
}

module aiDeveloperRoleUser 'core/security/role.bicep' = {
  scope: resourceGroup
  name: 'user-azure-ai-developer'
  params: {
    principalId: managedIdentity.outputs.managedIdentityPrincipalId
    roleDefinitionId: '64702f94-c441-49e6-a78b-ef80e0188fee' // Azure AI Developer
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = resourceGroup.name

output MANAGED_IDENTITY_CLIENT_ID string = managedIdentity.outputs.managedIdentityClientId

output AZURE_OPENAI_CHAT_DEPLOYMENT string = openAiDeploymentName
output AZURE_OPENAI_API_VERSION string = openAiApiVersion
output AZURE_OPENAI_ENDPOINT string = aiFoundry.outputs.endpoint
output AZURE_OPENAI_NAME string = aiFoundry.outputs.name
output AZURE_AI_FOUNDRY_PROJECT_NAME string = aiFoundry.outputs.projectName

output SERVICE_API_NAME string = api.outputs.SERVICE_API_NAME
output SERVICE_API_URI string = api.outputs.SERVICE_API_URI
output SERVICE_API_IMAGE_NAME string = api.outputs.SERVICE_API_IMAGE_NAME

output SERVICE_WEB_NAME string = web.outputs.SERVICE_WEB_NAME
output SERVICE_WEB_URI string = web.outputs.SERVICE_WEB_URI
output SERVICE_WEB_IMAGE_NAME string = web.outputs.SERVICE_WEB_IMAGE_NAME

output AZURE_CONTAINER_ENVIRONMENT_NAME string = containerApps.outputs.environmentName
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerApps.outputs.registryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerApps.outputs.registryName

output OPENAI_TYPE string = 'azure'
output AZURE_EMBEDDING_NAME string = openAiEmbeddingDeploymentName

output AZURE_SEARCH_ENDPOINT string = useSearch ? 'https://${searchService.outputs.name}.search.windows.net' : ''
output AZURE_SEARCH_NAME string = useSearch ? searchService.outputs.name : ''

output AZURE_SEARCH_INDEX string = aiSearchIndexName
