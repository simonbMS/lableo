#Requires -Version 7.0
<#
.SYNOPSIS
    Creates a disk encryption key in the Key Vault with temporary access.

.DESCRIPTION
    This script temporarily:
    1. Enables public network access on the Key Vault
    2. Adds the current user's IP to the firewall
    3. Grants the current user Key Vault Crypto Officer role
    4. Creates the disk encryption key
    5. Restores all security settings

.PARAMETER KeyVaultName
    The name of the Key Vault.

.PARAMETER ResourceGroupName
    The resource group containing the Key Vault.

.PARAMETER KeyName
    The name of the key to create. Default: disk-encryption-key

.EXAMPLE
    .\create-disk-encryption-key.ps1 -KeyVaultName "kv-msmigtst-001" -ResourceGroupName "kvault-rg"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$KeyName = "disk-encryption-key"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Disk Encryption Key Creation Script ===" -ForegroundColor Cyan
Write-Host ""

# Get current user information
Write-Host "Getting current user information..." -ForegroundColor Yellow
$currentUser = az ad signed-in-user show --query id -o tsv
if (-not $currentUser) {
    Write-Error "Failed to get current user. Make sure you are logged in with 'az login'."
    exit 1
}
Write-Host "Current user object ID: $currentUser" -ForegroundColor Green

# Get Key Vault resource ID
Write-Host "Getting Key Vault information..." -ForegroundColor Yellow
$keyVaultId = az keyvault show --name $KeyVaultName --resource-group $ResourceGroupName --query id -o tsv
if (-not $keyVaultId) {
    Write-Error "Failed to get Key Vault. Make sure it exists."
    exit 1
}
Write-Host "Key Vault ID: $keyVaultId" -ForegroundColor Green

# Get current public IP
Write-Host "Getting your public IP address..." -ForegroundColor Yellow
try {
    $myIp = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 10)
    Write-Host "Your public IP: $myIp" -ForegroundColor Green
}
catch {
    Write-Error "Failed to get public IP. Check your internet connection."
    exit 1
}

$roleAssignmentId = $null
$ipRuleAdded = $false
$publicAccessEnabled = $false

try {
    # Step 1: Enable public network access
    Write-Host ""
    Write-Host "Step 1: Enabling public network access on Key Vault..." -ForegroundColor Yellow
    az keyvault update --name $KeyVaultName --resource-group $ResourceGroupName --public-network-access Enabled --output none
    $publicAccessEnabled = $true
    Write-Host "Public network access enabled." -ForegroundColor Green

    # Step 2: Add current IP to firewall
    Write-Host ""
    Write-Host "Step 2: Adding your IP to Key Vault firewall..." -ForegroundColor Yellow
    az keyvault network-rule add --name $KeyVaultName --resource-group $ResourceGroupName --ip-address "$myIp/32" --output none
    $ipRuleAdded = $true
    Write-Host "IP rule added for $myIp" -ForegroundColor Green

    # Step 3: Grant Key Vault Crypto Officer role to current user
    Write-Host ""
    Write-Host "Step 3: Granting Key Vault Crypto Officer role..." -ForegroundColor Yellow
    $roleAssignment = az role assignment create `
        --assignee $currentUser `
        --role "Key Vault Crypto Officer" `
        --scope $keyVaultId `
        --query id -o tsv 2>$null
    
    if ($roleAssignment) {
        $roleAssignmentId = $roleAssignment
        Write-Host "Role assignment created: $roleAssignmentId" -ForegroundColor Green
    }
    else {
        Write-Host "Role may already exist or was created. Continuing..." -ForegroundColor Yellow
    }

    # Wait for RBAC propagation
    Write-Host ""
    Write-Host "Waiting 30 seconds for RBAC and network rules to propagate..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30

    # Step 4: Create the disk encryption key
    Write-Host ""
    Write-Host "Step 4: Creating disk encryption key '$KeyName'..." -ForegroundColor Yellow
    az keyvault key create `
        --vault-name $KeyVaultName `
        --name $KeyName `
        --kty RSA `
        --size 4096 `
        --ops encrypt decrypt wrapKey unwrapKey `
        --output none
    
    Write-Host "Key '$KeyName' created successfully!" -ForegroundColor Green

    # Get and display the key ID
    $keyId = az keyvault key show --vault-name $KeyVaultName --name $KeyName --query key.kid -o tsv
    Write-Host ""
    Write-Host "Key ID: $keyId" -ForegroundColor Cyan

}
catch {
    Write-Host ""
    Write-Error "An error occurred: $_"
}
finally {
    Write-Host ""
    Write-Host "=== Restoring Security Settings ===" -ForegroundColor Cyan

    # Step 5: Remove RBAC role assignment
    if ($roleAssignmentId) {
        Write-Host "Removing Key Vault Crypto Officer role assignment..." -ForegroundColor Yellow
        az role assignment delete --ids $roleAssignmentId --output none 2>$null
        Write-Host "Role assignment removed." -ForegroundColor Green
    }

    # Step 6: Remove IP from firewall
    if ($ipRuleAdded) {
        Write-Host "Removing your IP from Key Vault firewall..." -ForegroundColor Yellow
        az keyvault network-rule remove --name $KeyVaultName --resource-group $ResourceGroupName --ip-address "$myIp/32" --output none 2>$null
        Write-Host "IP rule removed." -ForegroundColor Green
    }

    # Step 7: Disable public network access
    if ($publicAccessEnabled) {
        Write-Host "Disabling public network access..." -ForegroundColor Yellow
        az keyvault update --name $KeyVaultName --resource-group $ResourceGroupName --public-network-access Disabled --output none 2>$null
        Write-Host "Public network access disabled." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "=== Security Restored ===" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Done! The key '$KeyName' is ready for use with Disk Encryption Set." -ForegroundColor Green
