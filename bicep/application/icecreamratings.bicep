@description('The name seed for all your other resources.')
param resNameSeed string = 'icecr4'

@description('The short application name of the Function App')
param appName string = 'ratings'

@allowed([
  'dev' //Small scale, no protection or backup
  'pre-prod' //Large scale, no protection or backup
  'prod' //Large scale, with production and backup
])
@description('The type of environment being deployed')
param environment string = 'dev'

@description('The name of the CosmosDb collection to create for the app')
param cosmosDbCollecionName string = appName

@description('The collection partitionkey')
param cosmosDbPartitionKey string = 'productId'

param location string =resourceGroup().location

@description('Logic to leverage environment protection like SoftDelete')
var environmentProtectionAndBackup = environment == 'prod'

@description('Creating the serverless app stack')
module serverlessapp '../archetype/apimCosmosApp.bicep' = {
  name: 'serverlessapp-${resNameSeed}'
  params: {
    resNameSeed: resNameSeed
    appName: appName
    apiManagementSku: 'Consumption'
    AppGitRepoUrl: 'https://github.com/oh-sless-t2/ice-cream-rating-api'
    AppGitRepoStagingBranch: 'staging'
    enableKeyVaultSoftDelete: environmentProtectionAndBackup
    cosmosDbDatabaseName: 'icecream'
    cosmosDbCollectionName: cosmosDbCollecionName
    cosmosDbPartitionKey: cosmosDbPartitionKey
    restrictTrafficToJustAPIM: environment != 'dev'
    location: location
  }
}

@description('Create a web test on the functionApp itself, will only work if functionApp is not APIM IP restricted (dev environment)')
module webTest '../foundation/appinsightswebtest.bicep' = if(environment == 'dev') {
  name: 'WebTest-${appName}'
  params: {
    Name: appName
    AppInsightsName: serverlessapp.outputs.AppInsightsName
    WebTestUrl:  'https://${ serverlessapp.outputs.ApplicationUrl}/api/GetRatings/cc20a6fb-a91f-4192-874d-132493685376'
    location: location
  }
}

@description('Creating application specific APIM configuration')
module apis 'icecreamratings-apimspec.bicep' = {
  name: 'apim-apis'
  params: {
    resNameSeed: resNameSeed
    apimName: serverlessapp.outputs.ApimName
    appInsightsName: serverlessapp.outputs.AppInsightsName
    apimLoggerId: serverlessapp.outputs.ApimLoggerId
    ratingsApiBaseUrl: 'https://${ serverlessapp.outputs.ApplicationUrl}/api/'
    location: location
  }
}
