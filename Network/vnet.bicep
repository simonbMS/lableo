@description('The Azure region where the virtual network will be deployed.')
param location string = resourceGroup().location

@description('The name of the virtual network.')
param vnetName string = 'vnet-main'

@description('Tags to apply to the virtual network.')
param tags object = {}

@description('The address space for the virtual network.')
var vnetAddressSpace = '10.33.0.0/16'

@description('Subnet configurations with Microsoft-required names and sizes.')
var subnets = [
  {
    name: 'subnet-1'
    addressPrefix: '10.33.0.0/24'
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
  }
  {
    name: 'subnet-2'
    addressPrefix: '10.33.1.0/24'
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
  }
  {
    name: 'subnet-3'
    addressPrefix: '10.33.2.0/24'
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
  }
  {
    name: 'privateendpoints'
    addressPrefix: '10.33.3.0/24'
    delegations: []
    // Disable network policies to allow private endpoints
    privateEndpointNetworkPolicies: 'Disabled'
  }
  {
    // Azure Firewall requires a subnet named 'AzureFirewallSubnet' with minimum /26
    name: 'AzureFirewallSubnet'
    addressPrefix: '10.33.4.0/24'
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
  }
  {
    // Azure Bastion requires a subnet named 'AzureBastionSubnet' with minimum /26, /24 recommended
    name: 'AzureBastionSubnet'
    addressPrefix: '10.33.5.0/24'
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
  }
  {
    // DNS Resolver inbound endpoint subnet - requires delegation to Microsoft.Network/dnsResolvers
    name: 'snet-dnsresolver-inbound'
    addressPrefix: '10.33.6.0/24'
    delegations: [
      {
        name: 'Microsoft.Network.dnsResolvers'
        properties: {
          serviceName: 'Microsoft.Network/dnsResolvers'
        }
      }
    ]
    privateEndpointNetworkPolicies: 'Enabled'
  }
  {
    // DNS Resolver outbound endpoint subnet - requires delegation to Microsoft.Network/dnsResolvers
    name: 'snet-dnsresolver-outbound'
    addressPrefix: '10.33.7.0/24'
    delegations: [
      {
        name: 'Microsoft.Network.dnsResolvers'
        properties: {
          serviceName: 'Microsoft.Network/dnsResolvers'
        }
      }
    ]
    privateEndpointNetworkPolicies: 'Enabled'
  }
  {
    // Application Gateway subnet - dedicated subnet required, no specific naming convention
    name: 'snet-appgateway'
    addressPrefix: '10.33.8.0/24'
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
  }
]

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
    subnets: [
      for subnet in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.addressPrefix
          delegations: subnet.delegations
          privateEndpointNetworkPolicies: subnet.privateEndpointNetworkPolicies
        }
      }
    ]
  }
}

@description('The resource ID of the virtual network.')
output vnetId string = virtualNetwork.id

@description('The name of the virtual network.')
output vnetName string = virtualNetwork.name

@description('The address space of the virtual network.')
output vnetAddressSpace string = vnetAddressSpace

@description('Subnet resource IDs mapped by name.')
output subnetIds object = reduce(
  virtualNetwork.properties.subnets,
  {},
  (acc, subnet) => union(acc, { '${subnet.name}': subnet.id })
)
