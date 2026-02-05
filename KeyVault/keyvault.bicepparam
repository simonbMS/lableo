using 'keyvault.bicep'

param keyVaultName = 'kv-msmigtst-001'

param vnetName = 'vnet-main'

param vnetResourceGroup = 'network-rg'

param privateEndpointSubnetName = 'privateendpoints'

param tags = {
  environment: 'production'
  purpose: 'disk-encryption'
}
