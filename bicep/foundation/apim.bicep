//Automation Note: APIM has softdelete protection on by default. You need to explicitly delete, if redeploying with the same name. az rest --method delete --header "Accept=applicaiton/json" -u 'https://management.azure.com/subscriptions/{subId}/providers/Microsoft.ApiManagement/locations/{region}/deletedservices/{apim}?api-version=2020-06-01-preview'
@description('Used in the naming of Az resources')
@minLength(3)
param nameSeed string

@description('Azure region where the resources will be deployed')
param location string = resourceGroup().location

@description('The name of the owner of the service')
@minLength(1)
param publisherName string = 'Gobyers'

@description('The pricing tier of this API Management service')
@allowed([
  'Developer'
  'Premium'
  'Consumption'
])
param sku string = 'Consumption'

param useRedisCache bool = true

@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string = 'gdogg@microsoft.com'

@description('The instance size of this API Management service.This should be in multiple of zones getting deployed.')
param skuCount int = 1

@description('Zone numbers e.g. 1,2,3.')
param availabilityZones array = [
  '1'
  '2'
  '3'
]

@description('Log Analytics ResourceId')
param logId string

param AppInsightsName string = ''


var apiManagementServiceName = 'apim-${nameSeed}-${substring(sku,0,3)}-${uniqueString(resourceGroup().id, nameSeed)}'

resource apim 'Microsoft.ApiManagement/service@2022-09-01-preview' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: sku
    capacity: sku=='Consumption' ? 0 :  skuCount
  }
  zones: ((length(availabilityZones) == 0 || sku!='Premium') ? null : availabilityZones)
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${apiUai.id}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}
output ApimName string = apim.name

resource apimPolicy 'Microsoft.ApiManagement/service/policies@2022-09-01-preview' = {
  name: 'policy'
  parent: apim
  properties:{
    format: 'rawxml'
    value: '<policies><inbound /><backend><forward-request /></backend><outbound /><on-error /></policies>'
  }
}

resource apiUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-apim-${nameSeed}'
  location: location
}
output apimUaiName string = apiUai.name


resource AppInsights 'Microsoft.Insights/components@2020-02-02' existing = if(!empty(AppInsightsName)) {
  name: AppInsightsName
}

var redisName = 'redis-${nameSeed}'
module redis 'redis.bicep' = if(useRedisCache) {
  name: 'redis-apim-${nameSeed}'
  params: {
    nameSeed: nameSeed
    redisName: redisName
    logId: logId
    location: location
  }
}

@description('We need to use a module for the config to ensure both Redis and APIM have been created to avoid both prematurely invoking ListKeys, and to avoid using outputs for keys/secrets')
module apimRedisCacheConfig 'apim-cacheconfig.bicep' = if(useRedisCache) {
  name: 'cacheconfig-apim-${nameSeed}'
  params: {
    redisName: useRedisCache ? redis.outputs.name : ''
    apimName: apim.name
    location: location
  }
}

// Create Logger and link logger
param createLogger bool = true
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2022-09-01-preview' = if(createLogger) {
  name: '${apim.name}-logger'
  parent: apim
  properties:{
    resourceId: AppInsights.id
    loggerType: 'applicationInsights'
    credentials:{
      instrumentationKey: AppInsights.properties.InstrumentationKey
    }
    description: 'APIM logger for Application Insights'
  }
}
output loggerId string = createLogger ? apimLogger.id : ''
