using 'vm-confidential.bicep'

param vmName = 'vm-conf-001'

param adminUsername = 'azureadmin'

param adminPasswordKeyVaultSecretName = 'cvm-admin-password'

param vnetName = 'vnet-main'

param vnetResourceGroup = 'network-rg'

param subnetName = 'subnet-1'

param keyVaultName = 'kv-msmigtst-001'

param keyVaultResourceGroup = 'kvault-rg'

param diskEncryptionKeyName = 'disk-encryption-key'

param vmSize = 'Standard_DC2as_v5'

param tags = {
  confidential: 'true'
}
