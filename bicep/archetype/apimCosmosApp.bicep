/*
  A single function app that uses CosmosDb, fronted by APIM.
  Key Vault for secrets management
  LoadTesting and Web Tests are configured

  As an Archetype there is no specific application information, just the right configuration for a standard App deployment.
*/

@description('The name seed for your functionapp. Check outputs for the actual name and url')
param appName string

@description('The name seed for all your other resources.')
param resNameSeed string

@allowed([
  'Developer'
  'Premium'
  'Consumption'
])
@description('The Sku of APIM thats appropriate for the App')
param apiManagementSku string = 'Consumption'

@description('Restricts inbound traffic to your functionapp, to just from APIM')
param restrictTrafficToJustAPIM bool = false

@description('Soft Delete protects your Vault contents and should be used for serious environments')
param enableKeyVaultSoftDelete bool = true

param location string = resourceGroup().location

@description('Needs to be unique as ends up as a public endpoint')
var webAppName = 'app-${appName}-${uniqueString(resourceGroup().id, appName)}'

// --------------------App Identity-------------------
//Creating the function App identity here as otherwise it'll cause circular problems in the modules
@description('The Azure Managed Identity Name assigned to the FunctionApp')
param fnAppIdentityName string = 'id-app-${appName}-${uniqueString(resourceGroup().id, appName)}'

resource fnAppUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: fnAppIdentityName
  location: location
}

// --------------------Function App-------------------
@description('The ful publicly accessible external Git(Hub) repo url')
param AppGitRepoUrl string

param AppGitRepoProdBranch string = 'main'
param AppGitRepoStagingBranch string = ''

param AppSettings array = []

@description('Grabbing the KeyVault Connectionstring secret uri')
//var kv_cosmosconnectionstring = '@Microsoft.KeyVault(SecretUri=${cosmos.outputs.connstrSecretUriWithVersion})'
var CosmosAppSettings = [
  {
    name: 'COSMOS_CONNECTION_STRING'
    value: '@Microsoft.KeyVault(SecretUri=${cosmos.outputs.connstrSecretUriWithVersion})'
  }
]
module functionApp '../foundation/functionapp.bicep' = {
  name: 'functionApp-${appName}-${resNameSeed}'
  params: {
    appName: appName
    webAppName: webAppName
    location: location
    AppInsightsName: appInsights.outputs.name
    additionalAppSettings: length(AppSettings) == 0 ? CosmosAppSettings : concat(AppSettings,CosmosAppSettings)
    restrictTrafficToJustAPIM: restrictTrafficToJustAPIM
    fnAppIdentityName: fnAppUai.name
    repoUrl: AppGitRepoUrl
    repoBranchProduction: AppGitRepoProdBranch
    repoBranchStaging: AppGitRepoStagingBranch
  }
}
@description('The raw ')
output ApplicationUrl string = functionApp.outputs.appUrl

// --------------------App Insights-------------------
module appInsights '../foundation/appinsights.bicep' = {
  name: 'appinsights-${resNameSeed}'
  params: {
    appName: webAppName
    logAnalyticsId: logAnalyticsResourceId
    location: location
  }
}
output AppInsightsName string = appInsights.outputs.name

// --------------------Log Analytics-------------------
@description('If you have an existing log analytics workspace in this region that you prefer, set the full resourceId here')
param centralLogAnalyticsId string = ''
module log '../foundation/loganalytics.bicep' = if(empty(centralLogAnalyticsId)) {
  name: 'log-${resNameSeed}'
  params: {
    resNameSeed: resNameSeed
    retentionInDays: 30
    location: location
  }
}
var logAnalyticsResourceId =  !empty(centralLogAnalyticsId) ? centralLogAnalyticsId : log.outputs.id

// --------------CosmosDb-----------------------
@description('Name of the CosmosDb Account')
param cosmosDbAccountName string = 'db-${resNameSeed}-${uniqueString(resourceGroup().id, appName)}'
var cleanCosmosDbName = toLower(cosmosDbAccountName)
param cosmosDbResourceGroupName string = resourceGroup().name

param cosmosDbDatabaseName string
param cosmosDbCollectionName string
param cosmosDbPartitionKey string

@allowed([
  'Provisioned'
  'Serverless'
])
param cosmosDbCapacityMode string = 'Serverless'
param cosmosDbFreeTier bool = false

module cosmos '../foundation/cosmos-sql.bicep' = {
  name: 'cosmosDb-${resNameSeed}'
  scope: resourceGroup(cosmosDbResourceGroupName)
  params: {
    databaseAccountName: cleanCosmosDbName
    location: location
    databaseName: cosmosDbDatabaseName
    collectionName: cosmosDbCollectionName
    partitionkey: cosmosDbPartitionKey
    AppIdentityName: fnAppUai.name
    AppIdentityRG: resourceGroup().name
    capacityMode: cosmosDbCapacityMode
    freeTier: cosmosDbFreeTier
    keyvaultName: akv.outputs.name
    keyvaultConnectionStringSecretName: '${appName}CosmosDbConnectionString'
  }
}

module akv '../foundation/kv.bicep' = {
  name: 'keyvault-${resNameSeed}'
  params: {
    nameSeed: resNameSeed
    enableSoftDelete: enableKeyVaultSoftDelete
    tenantId: subscription().tenantId
    location: location
  }
}

module akvAssignments '../foundation/kv-roleassignments.bicep' = {
  name: 'roles-keyvault-${resNameSeed}'
  params: {
    kvName: akv.outputs.name
    UaiSecretReaderNames: [
      fnAppUai.name
      apim.outputs.apimUaiName
    ]
  }
}

// --------------API Management-----------------------
module apim '../foundation/apim.bicep' =  {
  name: 'apim-${resNameSeed}'
  params: {
    nameSeed: resNameSeed
    location: location
    AppInsightsName: appInsights.outputs.name
    sku: apiManagementSku
    logId: logAnalyticsResourceId
  }
}
output ApimName string = apim.outputs.ApimName
output ApimLoggerId string = apim.outputs.loggerId

// --------------------Load testing-------------------
param createLoadTests bool = false
param loadTestOwnerObjectId string = ''
module loadtest '../foundation/loadtest.bicep' = if(createLoadTests) {
  name: 'loadtest-${resNameSeed}'
  params: {
    loadtestname: '${appName}-test'
    LoadTestTargetUrl: functionApp.outputs.appUrl
    location: location
    loadTestOwnerUser: loadTestOwnerObjectId
  }
}
