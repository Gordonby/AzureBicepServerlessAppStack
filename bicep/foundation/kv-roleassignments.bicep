@minLength(1)
@description('Pass an array of UAI names to give the GET secret access policy')
param UaiSecretReaderNames array

resource uais 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing =  [for uai in UaiSecretReaderNames : {
  name: uai
}]

param kvName string

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing =  {
  name: kvName
}

@description('Read secret contents. https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-user')
var keyVaultSecretsUserRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

resource kvAppGwSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for (uai, index) in UaiSecretReaderNames : {
  name: guid(uais[index].id, keyVault.id, keyVaultSecretsUserRole)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole
    principalType: 'ServicePrincipal'
    principalId: uais[index].properties.principalId
  }
  scope: keyVault
}]
