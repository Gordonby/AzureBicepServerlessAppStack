@description('Name of the CosmosDb Account')
@minLength(3)
@maxLength(44)
param databaseAccountName string

param location string = resourceGroup().location
param databaseName string
param collectionName string
param partitionkey string

param zoneRedundant bool = false

@allowed([
  'Provisioned'
  'Serverless'
])
@description('')
param capacityMode string = 'Serverless'

@description('Leverage the free tier (Provisioned capacity tier only) (One per subscription!)')
param freeTier bool = false

@description('The User Assigned Identity of an App to be given Read/Write RBAC')
param AppIdentityName string = ''
param AppIdentityRG string = resourceGroup().name //In the next version of Bicep we'll be able to pass resources between modules - so Name/Rg will get refactored to 1 param

@description('The principalId of a user who can also be provided RBAC access to CosmosDb')
param UserRolePrincipalId string = ''

resource fnAppUai 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = if(!empty(AppIdentityName)) {
  name: AppIdentityName
  scope:  resourceGroup(AppIdentityRG)
}

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  kind: 'GlobalDocumentDB'
  name: databaseAccountName
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    capabilities: capacityMode=='Serverless' ? [
      {
        name: 'EnableServerless'
      }
    ] : []
    enableFreeTier: capacityMode=='Provisioned' && freeTier
    createMode: 'Default'
    // capacity: {
    //   totalThroughputLimit: 4000
    // }
    locations: [
      {
        locationName: location
        failoverPriority:0
        isZoneRedundant: zoneRedundant
      }
    ]
  }

  resource cosmosDbDatabase 'sqlDatabases' = {
    name: databaseName
    properties: {
      resource: {
        id: databaseName
      }
    }

    resource container 'containers' = {
      name: collectionName
      properties: {
        resource: {
          id: collectionName
          partitionKey: {
            paths: [
              '/${partitionkey}'
            ]
            kind: 'Hash'
          }
        }
      }
    }
  }

  resource cosmosReadWriteRoleDefinition 'sqlRoleDefinitions' = {
    name: guid(cosmosDbAccount.name, 'ReadWriteRole')
    properties: {
      assignableScopes: [
        cosmosDbAccount.id
      ]
      permissions: [
        {
          dataActions: [
            'Microsoft.DocumentDB/databaseAccounts/readMetadata'
            'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
            'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
          ]
          notDataActions: []
        }
      ]
      roleName: 'Reader Writer'
      type: 'CustomRole'
    }
  }

  //REF: https://joonasw.net/view/access-data-in-cosmos-db-with-managed-identities
  resource cosmosReadWriteAppAssignment 'sqlRoleAssignments' = if(!empty(AppIdentityName)) {
    name: guid(cosmosDbAccount.name, 'ReadWriteRole', 'App')
    properties: {
      principalId: fnAppUai.properties.principalId
      roleDefinitionId: cosmosReadWriteRoleDefinition.id
      scope: cosmosDbAccount.id
    }
  }

  resource userRole 'sqlRoleAssignments' = if (!empty(UserRolePrincipalId)) {
    name: guid(cosmosReadWriteRoleDefinition.id, UserRolePrincipalId, cosmosDbAccount.id)
    properties: {
      principalId: UserRolePrincipalId
      roleDefinitionId: cosmosReadWriteRoleDefinition.id
      scope: cosmosDbAccount.id
    }
  }
}
output databaseAccountId string = cosmosDbAccount.id
output documentEndpoint string = cosmosDbAccount.properties.documentEndpoint
output accountName string = cosmosDbAccount.name

//KeyVault - Adding ConnectionString as secret
param keyvaultName string = ''
param keyvaultConnectionStringSecretName string = ''

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = if (!empty(keyvaultName) && !empty(keyvaultConnectionStringSecretName)) {
  name: keyvaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = if (!empty(keyvaultName) && !empty(keyvaultConnectionStringSecretName)) {
  name: keyvaultConnectionStringSecretName
  parent: keyVault
  properties: {
    value: first(cosmosDbAccount.listConnectionStrings().connectionStrings).connectionString
  }
}

output connstrSecretUriWithVersion string = secret.properties.secretUriWithVersion
output connstrSecretUri string = secret.properties.secretUri
