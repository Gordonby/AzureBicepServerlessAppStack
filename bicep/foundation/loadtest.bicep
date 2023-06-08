
param loadtestname string
param location string = resourceGroup().location

@description('The Url that you wish to target the load tests against')
param LoadTestTargetUrl string

@description('The object id of a user')
param loadTestOwnerUser string = ''

@description('The object id of a Service Principal that will be used to create/run load tests')
param loadTestContributorSP string = ''

#disable-next-line BCP081
resource loadtest 'Microsoft.LoadTestService/loadtests@2021-09-01-preview' = {
  name: loadtestname
  location: location
  tags: {
    testTargetResourceId: LoadTestTargetUrl
  }

}

var LoadTestOwnerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '45bb0b16-2f0c-4e78-afaa-a07599b003f6')
resource loadTestOwnerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if(!empty(loadTestOwnerUser))  {
  scope: loadtest
  name: guid(loadtestname, LoadTestOwnerRoleId, loadTestOwnerUser)
  properties: {
    principalId: loadTestOwnerUser
    roleDefinitionId: LoadTestOwnerRoleId
    principalType: 'User'
  }
}

var LoadTestContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '749a398d-560b-491b-bb21-08924219302e')
resource loadTestContribAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =  if(!empty(loadTestContributorSP)) {
  scope: loadtest
  name: guid(loadtestname, LoadTestContributorRoleId, loadTestContributorSP)
  properties: {
    principalId: loadTestContributorSP
    roleDefinitionId: LoadTestContributorRoleId
    principalType: 'ServicePrincipal'
  }
}

@description('This identity is used when adding tests to the load test resource from within Bicep IaC')
param UaiRunnerName string = 'LoadTestHelper'
resource loadTestRunner 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: UaiRunnerName
  location: location
}

resource UaiContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: loadtest
  name: guid(loadtestname, LoadTestContributorRoleId, UaiRunnerName)
  properties: {
    principalId: loadTestRunner.properties.principalId
    roleDefinitionId: LoadTestContributorRoleId
    principalType: 'ServicePrincipal'
  }
}
