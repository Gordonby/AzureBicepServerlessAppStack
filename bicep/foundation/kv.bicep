@description('Used in the naming of Az resources')
@minLength(3)
param nameSeed string

@description('The Azure Active Directory Tenant Id')
param tenantId string

@description('Soft delete provides protection for Key Vault secrets')
param enableSoftDelete bool = true

param location string = resourceGroup().location

var kvRawName = replace('kv-${nameSeed}-${uniqueString(resourceGroup().id, nameSeed)}','-','')
var kvName = length(kvRawName) > 24 ? substring(kvRawName,0,23) : kvRawName

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' =  {
  name: kvName
  location: location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: tenantId
    accessPolicies: []
    enableRbacAuthorization: true
    enableSoftDelete: enableSoftDelete
  }
}
output name string = kvName
