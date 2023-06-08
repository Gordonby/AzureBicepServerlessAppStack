
param resNameSeed string
param apimName string
param apimLoggerId string
param appInsightsName string
param ratingsApiBaseUrl string
param apimProductNames array = [
  'Mobile Users'
  'Internal Users'
  'ExternalPartners'
]

@description('Enforces requirement for an api subscription key')
param requireSubscriptionForApis bool = true

param location string = resourceGroup().location

@description('Creating a proper reference to APIM')
resource apim 'Microsoft.ApiManagement/service@2022-09-01-preview' existing = {
  name: apimName
}

@description('[LOOP] Creating all products from an array')
resource products 'Microsoft.ApiManagement/service/products@2022-09-01-preview' = [ for product in apimProductNames : {
  name: replace(product,' ', '')
  parent: apim
  properties: {
    approvalRequired: true
    subscriptionRequired: true
    displayName: product
    state: 'published'
  }
}]

@description('Using a module to uniformly create simple users Api/methods/web-tests')
module userApi '../foundation/apim-api.bicep' = {
  name: 'userApi-apim-${resNameSeed}'
  params: {
    apimName: apimName
    location: location
    apimLoggerId: apimLoggerId
    AppInsightsName: appInsightsName
    servicename: 'Users'
    baseUrl: 'https://serverlessohapi.azurewebsites.net/api/'
    serviceApimPath: 'users'
    serviceDisplayName: 'Users API'
    apimSubscriptionRequired: requireSubscriptionForApis
    apis: [
      {
        method: 'GET'
        urlTemplate: '/GetUsers'
        displayName : 'Get Users'
        name: 'GetUsers'
      }
      {
        method: 'GET'
        urlTemplate: '/GetUser'
        displayName : 'Get User'
        name: 'GetUser'
      }
    ]
  }
}

@description('Using a module to uniformly create simple product Api/methods/web-tests')
module productApi '../foundation/apim-api.bicep' = {
  name: 'productApi-apim-${resNameSeed}'
  params: {
    apimName: apimName
    location: location
    apimLoggerId: apimLoggerId
    AppInsightsName: appInsightsName
    servicename: 'Product'
    baseUrl: 'https://serverlessohapi.azurewebsites.net/api/'
    serviceApimPath: 'products'
    serviceDisplayName: 'Products API'
    apimSubscriptionRequired: requireSubscriptionForApis
    apis: [
      {
        method: 'GET'
        urlTemplate: '/GetProducts'
        displayName : 'Get Prodcuts'
        name: 'GetProducts'
      }
      {
        method: 'GET'
        urlTemplate: '/GetProducts?randomqs=true'
        displayName : 'Get Products cache demo'
        name: 'GetProductsCacheDemo'
        enableCache: true
      }
      {
        method: 'GET'
        urlTemplate: '/GetProduct'
        displayName : 'Get Prodcut'
        name: 'GetProduct'
      }
    ]

  }
}

/*
The Ratings API uses URLTemplate Parameters and starts becoming to specific to leverage in a generic module
*/
var ApiLoggingProperties = {
  alwaysLog: 'allErrors'
  httpCorrelationProtocol: 'Legacy'
  verbosity: 'information'
  logClientIp: true
  loggerId: apimLoggerId
  sampling: {
    samplingType: 'fixed'
    percentage: 100
  }
}

resource RatingsApi 'Microsoft.ApiManagement/service/apis@2022-09-01-preview' = {
  name: 'Ratings'
  parent: apim
  properties: {
    path: 'ratings'
    displayName: 'Ratings API'
    serviceUrl: ratingsApiBaseUrl
    protocols: [
      'https'
    ]
    subscriptionRequired: requireSubscriptionForApis
  }
}

resource RatingsApiDiags 'Microsoft.ApiManagement/service/apis/diagnostics@2022-09-01-preview' = {
  name: 'applicationinsights'
  parent: RatingsApi
  properties: ApiLoggingProperties
}

resource GetRatingsMethod 'Microsoft.ApiManagement/service/apis/operations@2022-09-01-preview' = {
  name: 'GetRatings'
  parent: RatingsApi
  properties: {
    displayName: 'Get Ratings'
    method: 'GET'
    urlTemplate: '/GetRatings/{userid}'
    description: 'Get all of the ratings'
    templateParameters: [
      {
        name: 'userid'
        defaultValue: 'cc20a6fb-a91f-4192-874d-132493685376'
        type: ''
      }
    ]
  }
}

resource GetRatingMethod 'Microsoft.ApiManagement/service/apis/operations@2022-09-01-preview' = {
  name: 'GetRating'
  parent: RatingsApi
  properties: {
    displayName: 'Get Rating'
    method: 'GET'
    urlTemplate: '/GetRating/{ratingsId}'
    description: 'Get all of the ratings'
    templateParameters: [
      {
        name: 'ratingsId'
        defaultValue: '79c2779e-dd2e-43e8-803d-ecbebed8972c'
        type: ''
      }
    ]
  }
}

resource RatingsAdminApi 'Microsoft.ApiManagement/service/apis@2022-09-01-preview' = {
  name: 'RatingsAdmin'
  parent: apim
  properties: {
    path: 'ratingsadmin'
    displayName: 'Ratings Admin API'
    serviceUrl: ratingsApiBaseUrl
    protocols: [
      'https'
    ]
    subscriptionRequired: requireSubscriptionForApis
  }
}

resource CreateRatingsMethod 'Microsoft.ApiManagement/service/apis/operations@2022-09-01-preview' = {
  name: 'CreateRatings'
  parent: RatingsAdminApi
  properties: {
    displayName: 'Create Ratings'
    method: 'POST'
    urlTemplate: '/CreateRatings'
    description: 'Create a ratings'
  }
}
