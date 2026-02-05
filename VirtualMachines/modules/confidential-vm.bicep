@description('The Azure region where resources will be deployed.')
param location string

@description('The name of the virtual machine.')
param vmName string

@description('The admin username for the VM.')
param adminUsername string

@description('The admin password for the VM.')
@secure()
param adminPassword string

@description('Tags to apply to all resources.')
param tags object = {}

@description('The VM size for confidential computing.')
param vmSize string

@description('The OS image for the VM.')
param imageReference object

@description('The resource ID of the subnet to attach the VM.')
param subnetId string

@description('The resource ID of the Disk Encryption Set.')
param diskEncryptionSetId string

// ============================================================================
// Network Interface
// ============================================================================
resource networkInterface 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: 'nic-${vmName}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

// ============================================================================
// Confidential Virtual Machine
// ============================================================================
resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        name: 'osdisk-${vmName}'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
          securityProfile: {
            securityEncryptionType: 'DiskWithVMGuestState'
            diskEncryptionSet: {
              id: diskEncryptionSetId
            }
          }
        }
        deleteOption: 'Delete'
      }
      dataDisks: []
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    securityProfile: {
      securityType: 'ConfidentialVM'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================
@description('The resource ID of the virtual machine.')
output vmId string = virtualMachine.id

@description('The name of the virtual machine.')
output vmName string = virtualMachine.name

@description('The private IP address of the VM.')
output privateIpAddress string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress
