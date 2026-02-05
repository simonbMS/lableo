@description('The principal ID of the Disk Encryption Set.')
param principalId string

@description('The name of the Key Vault.')
param keyVaultName string

// Key Vault Crypto Service Encryption User role definition ID
// This role provides: keys/get, keys/wrapKey, keys/unwrapKey
var roleDefinitionId = 'e147488a-f6f5-4113-8e2d-b22465e65bf6'

resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource desKeyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(existingKeyVault.id, principalId, 'Key Vault Crypto Service Encryption User')
  scope: existingKeyVault
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
}
