@description('The Azure region where resources will be deployed.')
param location string = resourceGroup().location

@description('The name of the Key Vault. Must be globally unique.')
param keyVaultName string

@description('Tags to apply to all resources.')
param tags object = {}

@description('The name of the virtual network.')
param vnetName string

@description('The resource group of the virtual network.')
param vnetResourceGroup string

@description('The name of the private endpoints subnet.')
param privateEndpointSubnetName string

@description('The tenant ID for the Key Vault.')
param tenantId string = subscription().tenantId

@description('Soft delete retention in days (7-90).')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

// ============================================================================
// Key Vault - Configured for disk encryption with RBAC authorization
// ============================================================================
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    // Enable RBAC authorization instead of access policies
    enableRbacAuthorization: true
    // Enable features required for disk encryption
    enabledForDiskEncryption: true
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    // Soft delete enabled, purge protection disabled for dev/test flexibility
    enableSoftDelete: false
//    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: false
    // Disable public network access - only accessible via private endpoint
    publicNetworkAccess: 'Disabled'
    // Network ACLs - deny all public access, allow Azure services bypass
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

// ============================================================================
// Existing VNet and Subnet references
// ============================================================================
resource existingVnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroup)
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  parent: existingVnet
  name: privateEndpointSubnetName
}

// ============================================================================
// Private DNS Zone for Key Vault
// ============================================================================
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
  properties: {}
}

// ============================================================================
// Virtual Network Link - Connect DNS zone to VNet
// ============================================================================
resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'link-to-vnet'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: existingVnet.id
    }
  }
}

// ============================================================================
// Private Endpoint for Key Vault
// ============================================================================
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: 'pe-${keyVaultName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: existingSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${keyVaultName}'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

// ============================================================================
// Private DNS Zone Group - Register private endpoint in DNS zone
// ============================================================================
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================
@description('The resource ID of the Key Vault.')
output keyVaultId string = keyVault.id

@description('The name of the Key Vault.')
output keyVaultName string = keyVault.name

@description('The URI of the Key Vault.')
output keyVaultUri string = keyVault.properties.vaultUri

@description('The resource ID of the private endpoint.')
output privateEndpointId string = privateEndpoint.id

@description('The resource ID of the private DNS zone.')
output privateDnsZoneId string = privateDnsZone.id
