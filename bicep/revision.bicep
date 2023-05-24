param baseUrl string = 'https://serverlessohapi.azurewebsites.net/api/'
param servicename string = 'Users'
param serviceApimPath string = 'users'
param serviceDisplayName string = servicename
param apimSubscriptionRequired bool = false

param apimName string = 'apim-icecr3-Con-3s5udypqhqmcm'

param revision string = '3'

resource apim 'Microsoft.ApiManagement/service@2021-01-01-preview' existing = {
  name: apimName
}

resource apimService 'Microsoft.ApiManagement/service/apis@2021-04-01-preview' = {
  name: '${servicename};rev=${revision}'
  parent: apim
  properties: {
    path: serviceApimPath
    displayName: serviceDisplayName
    serviceUrl: baseUrl
    protocols: [
      'https'
    ]
    subscriptionRequired: apimSubscriptionRequired
    apiRevision: revision
    apiRevisionDescription: 'Updated by bicep'
  }
}
