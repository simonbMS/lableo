@description('The Azure region where resources will be deployed.')
param location string = resourceGroup().location

@description('The name of the virtual machine.')
param vmName string

@description('The admin username for the VM.')
param adminUsername string

@description('The admin password for the VM. Ignored if adminPasswordKeyVaultSecretName is specified.')
@secure()
param adminPassword string = ''

@description('The name of the Key Vault containing the admin password secret. Defaults to keyVaultName if not specified.')
param adminPasswordKeyVaultName string = ''

@description('The resource group of the Key Vault containing the admin password secret. Defaults to keyVaultResourceGroup if not specified.')
param adminPasswordKeyVaultResourceGroup string = ''

@description('The name of the secret in Key Vault containing the admin password. If specified, this takes precedence over adminPassword.')
param adminPasswordKeyVaultSecretName string = ''

@description('Tags to apply to all resources.')
param tags object = {}

@description('The name of the virtual network.')
param vnetName string

@description('The resource group of the virtual network.')
param vnetResourceGroup string

@description('The name of the subnet to attach the VM.')
param subnetName string = 'subnet-1'

@description('The name of the Key Vault containing the disk encryption key.')
param keyVaultName string

@description('The resource group of the Key Vault.')
param keyVaultResourceGroup string

@description('The name of the disk encryption key in Key Vault.')
param diskEncryptionKeyName string = 'disk-encryption-key'

@description('The VM size for confidential computing.')
param vmSize string = 'Standard_DC1s_v3'

@description('The OS image for the VM.')
param imageReference object = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2022-datacenter-smalldisk-g2'
  version: 'latest'
}

// ============================================================================
// Existing Resources
// ============================================================================
resource existingVnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroup)
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  parent: existingVnet
  name: subnetName
}

resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultResourceGroup)
}

resource existingKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' existing = {
  parent: existingKeyVault
  name: diskEncryptionKeyName
}

// Key Vault for admin password (may be same as disk encryption Key Vault or different)
var passwordKeyVaultName = !empty(adminPasswordKeyVaultSecretName) 
  ? (!empty(adminPasswordKeyVaultName) ? adminPasswordKeyVaultName : keyVaultName)
  : ''
var passwordKeyVaultResourceGroup = !empty(adminPasswordKeyVaultSecretName)
  ? (!empty(adminPasswordKeyVaultResourceGroup) ? adminPasswordKeyVaultResourceGroup : keyVaultResourceGroup)
  : ''

resource passwordKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (!empty(adminPasswordKeyVaultSecretName)) {
  name: passwordKeyVaultName
  scope: resourceGroup(passwordKeyVaultResourceGroup)
}

// ============================================================================
// User Assigned Managed Identity for Disk Encryption Set
// ============================================================================
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-des-${vmName}'
  location: location
  tags: tags
}

// ============================================================================
// RBAC: Grant Managed Identity access to Key Vault BEFORE creating DES
// Key Vault Crypto Service Encryption User role (deployed to Key Vault's resource group)
// ============================================================================
module desKeyVaultRoleAssignment 'modules/des-keyvault-rbac.bicep' = {
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    principalId: managedIdentity.properties.principalId
    keyVaultName: keyVaultName
  }
}

// ============================================================================
// RBAC: Grant Confidential VM Orchestrator access to Key Vault
// Key Vault Crypto Service Release User role - required for CVM with CMK
// ============================================================================
module cvmOrchestratorRoleAssignment 'modules/cvm-orchestrator-rbac.bicep' = {
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    keyVaultName: keyVaultName
  }
}

// ============================================================================
// Disk Encryption Set for Confidential VM with CMK
// ============================================================================
resource diskEncryptionSet 'Microsoft.Compute/diskEncryptionSets@2023-10-02' = {
  name: 'des-${vmName}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    activeKey: {
      sourceVault: {
        id: existingKeyVault.id
      }
      keyUrl: existingKey.properties.keyUriWithVersion
    }
    encryptionType: 'ConfidentialVmEncryptedWithCustomerKey'
  }
  dependsOn: [
    desKeyVaultRoleAssignment
  ]
}

// ============================================================================
// Confidential Virtual Machine (using Key Vault password)
// ============================================================================
module vmWithKeyVaultPassword 'modules/confidential-vm.bicep' = if (!empty(adminPasswordKeyVaultSecretName)) {
  name: 'deploy-${vmName}-kv'
  params: {
    location: location
    vmName: vmName
    adminUsername: adminUsername
    adminPassword: passwordKeyVault.getSecret(adminPasswordKeyVaultSecretName)
    tags: tags
    vmSize: vmSize
    imageReference: imageReference
    subnetId: existingSubnet.id
    diskEncryptionSetId: diskEncryptionSet.id
  }
  dependsOn: [
    desKeyVaultRoleAssignment
    cvmOrchestratorRoleAssignment
  ]
}

// ============================================================================
// Confidential Virtual Machine (using plain text password)
// ============================================================================
module vmWithPlainPassword 'modules/confidential-vm.bicep' = if (empty(adminPasswordKeyVaultSecretName)) {
  name: 'deploy-${vmName}-plain'
  params: {
    location: location
    vmName: vmName
    adminUsername: adminUsername
    adminPassword: adminPassword
    tags: tags
    vmSize: vmSize
    imageReference: imageReference
    subnetId: existingSubnet.id
    diskEncryptionSetId: diskEncryptionSet.id
  }
  dependsOn: [
    desKeyVaultRoleAssignment
    cvmOrchestratorRoleAssignment
  ]
}

// ============================================================================
// Outputs
// ============================================================================
@description('The resource ID of the virtual machine.')
output vmId string = !empty(adminPasswordKeyVaultSecretName) ? vmWithKeyVaultPassword.outputs.vmId : vmWithPlainPassword.outputs.vmId

@description('The name of the virtual machine.')
output vmName string = !empty(adminPasswordKeyVaultSecretName) ? vmWithKeyVaultPassword.outputs.vmName : vmWithPlainPassword.outputs.vmName

@description('The private IP address of the VM.')
output privateIpAddress string = !empty(adminPasswordKeyVaultSecretName) ? vmWithKeyVaultPassword.outputs.privateIpAddress : vmWithPlainPassword.outputs.privateIpAddress

@description('The resource ID of the Disk Encryption Set.')
output diskEncryptionSetId string = diskEncryptionSet.id
