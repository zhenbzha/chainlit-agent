metadata description = 'Creates an Azure AI Foundry resource with project, model deployments, and connections.'

@description('Name of the AI Foundry resource')
param name string

@description('Name of the AI Foundry project')
param projectName string

@description('Location for the resources')
param location string = resourceGroup().location

@description('Tags for the resources')
param tags object = {}

@description('SKU name for the AI Foundry resource')
param skuName string = 'S0'

@description('Model deployments configuration')
param deployments array = []

@allowed(['Enabled', 'Disabled'])
@description('Public network access setting')
param publicNetworkAccess string = 'Enabled'

@description('Disable local authentication')
param disableLocalAuth bool = true

@description('Azure AI Search service name for connection')
param searchServiceName string = ''

@description('Azure AI Search connection name')
param searchConnectionName string = 'search-connection'

@description('Principal ID to grant access to the AI Foundry resource')
param principalId string = ''

// AI Foundry resource (CognitiveServices account with AIServices kind)
resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: name
  location: location
  tags: tags
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: skuName
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: name
    publicNetworkAccess: publicNetworkAccess
    disableLocalAuth: disableLocalAuth
  }
}

// AI Foundry Project
resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  name: projectName
  parent: aiFoundry
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

// Model deployments
@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for deploy in deployments: {
  parent: aiFoundry
  name: deploy.name
  sku: deploy.?sku ?? {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: deploy.model
    raiPolicyName: deploy.?raiPolicyName ?? null
  }
}]

// Azure AI Search connection (if search service is provided)
resource searchConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = if (!empty(searchServiceName)) {
  name: searchConnectionName
  parent: aiFoundry
  properties: {
    category: 'CognitiveSearch'
    authType: 'AAD'
    target: 'https://${searchServiceName}.search.windows.net'
    isSharedToAll: true
    metadata: {}
  }
}

// Role assignments for managed identity on AI Foundry resource
// Azure AI Developer role - for agents/write permission
resource aiDeveloperRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(aiFoundry.id, principalId, '64702f94-c441-49e6-a78b-ef80e0188fee')
  scope: aiFoundry
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '64702f94-c441-49e6-a78b-ef80e0188fee')
  }
}

// Cognitive Services OpenAI Contributor role
resource openAiContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(aiFoundry.id, principalId, 'a001fd3d-188f-4b5d-821b-7da978bf7442')
  scope: aiFoundry
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a001fd3d-188f-4b5d-821b-7da978bf7442')
  }
}

// Cognitive Services User role - for OpenAI API access
resource cognitiveServicesUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(aiFoundry.id, principalId, 'a97b65f3-24c7-4388-baec-2e87135dc908')
  scope: aiFoundry
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
  }
}

// Outputs
output id string = aiFoundry.id
output name string = aiFoundry.name
output endpoint string = aiFoundry.properties.endpoint
output principalId string = aiFoundry.identity.principalId

output projectId string = aiProject.id
output projectName string = aiProject.name
output projectPrincipalId string = aiProject.identity.principalId
