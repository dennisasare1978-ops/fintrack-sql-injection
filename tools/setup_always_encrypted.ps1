# setup_always_encrypted.ps1
# Configures Always Encrypted for CreditCardNumber and CVV columns.
# Run this in Azure Cloud Shell (PowerShell) or any PowerShell 7+ session.
#
# Usage:
#   ./setup_always_encrypted.ps1 \
#       -SqlServer "fintrack-sql-xxxxx.database.windows.net" \
#       -KeyVaultName "your-keyvault-name"

param(
    [Parameter(Mandatory)] [string] $SqlServer,
    [Parameter(Mandatory)] [string] $KeyVaultName,
    [string] $Database      = "finance-db",
    [string] $SqlUser       = "sqladmin",
    [string] $SqlPassword   = "Password123!",
    [string] $CmkName       = "CMK_FinTrack",
    [string] $CekName       = "CEK_FinTrack"
)

$ErrorActionPreference = "Stop"

# ── Install / import modules ────────────────────────────────────────────────
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Write-Host "Installing SqlServer module..."
    Install-Module SqlServer -Scope CurrentUser -Force -AllowClobber
}
Import-Module SqlServer

if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Install-Module Az.Accounts -Scope CurrentUser -Force
}
Import-Module Az.Accounts

# ── Authenticate to Azure (Cloud Shell is already logged in) ─────────────
$context = Get-AzContext
if (-not $context) {
    Write-Host "Not logged in to Azure. Running Connect-AzAccount..."
    Connect-AzAccount
}

# ── Create Column Master Key in Key Vault ────────────────────────────────
$keyVaultUrl = "https://${KeyVaultName}.vault.azure.net/"
$cmkKeyName  = "always-encrypted-cmk"

Write-Host "`n[1/4] Creating CMK key in Key Vault..."
$cmkSettings = New-SqlAzureKeyVaultColumnMasterKeySettings -KeyUrl "${keyVaultUrl}keys/${cmkKeyName}"

# Create the key in Key Vault if it doesn't exist
$existingKey = az keyvault key show --vault-name $KeyVaultName --name $cmkKeyName 2>$null | ConvertFrom-Json
if (-not $existingKey) {
    az keyvault key create --vault-name $KeyVaultName --name $cmkKeyName --kty RSA --size 2048 --output none
    Write-Host "  Created RSA key '${cmkKeyName}' in Key Vault"
} else {
    Write-Host "  Key '${cmkKeyName}' already exists"
}

# Get the full key URL (with version)
$keyInfo = az keyvault key show --vault-name $KeyVaultName --name $cmkKeyName | ConvertFrom-Json
$keyUrl  = $keyInfo.key.kid
$cmkSettings = New-SqlAzureKeyVaultColumnMasterKeySettings -KeyUrl $keyUrl

# ── Connect to SQL Database ──────────────────────────────────────────────
Write-Host "`n[2/4] Connecting to SQL Database..."
$connStr = "Server=tcp:${SqlServer},1433;Database=${Database};User ID=${SqlUser};Password=${SqlPassword};Encrypt=True;TrustServerCertificate=False;"
$db = Get-SqlDatabase -ConnectionString $connStr

# ── Create CMK and CEK metadata in the database ─────────────────────────
Write-Host "`n[3/4] Creating CMK and CEK metadata..."

# Check if CMK already exists
$existingCmk = $db.ColumnMasterKeys | Where-Object { $_.Name -eq $CmkName }
if (-not $existingCmk) {
    New-SqlColumnMasterKey -Name $CmkName -InputObject $db -ColumnMasterKeySettings $cmkSettings
    Write-Host "  Created Column Master Key: ${CmkName}"
} else {
    Write-Host "  Column Master Key '${CmkName}' already exists"
}

# Get Azure access token for Key Vault operations
$token = (Get-AzAccessToken -ResourceUrl "https://vault.azure.net").Token
$vaultProvider = New-SqlAzureKeyVaultColumnMasterKeySettings -KeyUrl $keyUrl

# Check if CEK already exists
$existingCek = $db.ColumnEncryptionKeys | Where-Object { $_.Name -eq $CekName }
if (-not $existingCek) {
    New-SqlColumnEncryptionKey -Name $CekName -InputObject $db -ColumnMasterKeyName $CmkName `
        -KeyVaultAccessToken $token
    Write-Host "  Created Column Encryption Key: ${CekName}"
} else {
    Write-Host "  Column Encryption Key '${CekName}' already exists"
}

# ── Encrypt columns ─────────────────────────────────────────────────────
Write-Host "`n[4/4] Encrypting CreditCardNumber and CVV columns..."

$encryptionChanges = @()
$encryptionChanges += New-SqlColumnEncryptionSettings -ColumnName "dbo.CustomerTransactions.CreditCardNumber" `
    -EncryptionType "Randomized" -EncryptionKey $CekName
$encryptionChanges += New-SqlColumnEncryptionSettings -ColumnName "dbo.CustomerTransactions.CVV" `
    -EncryptionType "Randomized" -EncryptionKey $CekName

Set-SqlColumnEncryption -InputObject $db -ColumnEncryptionSettings $encryptionChanges `
    -KeyVaultAccessToken $token

Write-Host "`n=== Done ==="
Write-Host "CreditCardNumber and CVV are now encrypted with Always Encrypted (Randomized)."
Write-Host "Column Master Key is stored in Key Vault: ${keyUrl}"
Write-Host "`nVerify by running in the Azure Portal Query Editor:"
Write-Host "  SELECT CustomerName, CreditCardNumber, CVV FROM CustomerTransactions"
Write-Host "  (You should see encrypted binary values)"
