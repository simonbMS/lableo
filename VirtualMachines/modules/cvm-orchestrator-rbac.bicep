@description('The name of the Key Vault.')
param keyVaultName string

// Confidential VM Orchestrator App Object ID
var confidentialVmOrchestratorObjectId = '9ea1fda1-2253-4317-ab35-6979d7aeee2f'

// Key Vault Crypto Service Release User role definition ID
var roleDefinitionId = '08bbd89e-9f13-488c-ac41-acfcb10c90ab'

resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource ckvOrchestratorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(existingKeyVault.id, confidentialVmOrchestratorObjectId, 'Key Vault Crypto Service Release User')
  scope: existingKeyVault
  properties: {
    principalId: confidentialVmOrchestratorObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
}
