param LoadTestTargetUrl string = 'https://apim-icecream-con-hccfwz6y5uwio.azure-api.net/Products/GetProducts'
param LoadTestResourceName string = 'ratings-test'
param LoadTestName string = 'GetProducts'
param utcValue string = utcNow()
param JmxBaseFileUrl string = 'https://github.com/Gordonby/Snippets/blob/master/Jmeter/SimpleGetBase.xml?raw=true'
param location string =resourceGroup().location

resource AddLoadTestFromJmx 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'AddLoadTest-${LoadTestName}'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${loadTestRunner.id}': {}
    }
  }
  properties: {
    forceUpdateTag: utcValue
    azPowerShellVersion: '6.4'
    arguments: '-LoadTestResourceName ${LoadTestResourceName} -ResourceGroup ${resourceGroup().name} -TestName ${LoadTestName} -TestUrl ${LoadTestTargetUrl} -JmxBaseFileUrl ${JmxBaseFileUrl}'
    primaryScriptUri: 'https://github.com/Gordonby/Snippets/blob/master/Powershell/AzureDeploymentScripts/LoadTestJmx.ps1?raw=true'
    timeout: 'PT10M'
    cleanupPreference: 'Always'
    retentionInterval: 'PT15M'
  }
  dependsOn: [
    //UaiContributorRoleAssignment
  ]
}
output pwshResultObj object = AddLoadTestFromJmx.properties.outputs

param UaiRunnerName string = 'LoadTestHelper'
resource loadTestRunner 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: UaiRunnerName
}
