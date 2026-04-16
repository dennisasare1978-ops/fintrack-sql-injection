@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Unique suffix to prevent naming conflicts')
param suffix string = uniqueString(resourceGroup().id)

@description('SQL admin password')
param sqlAdminPassword string = 'Password123!'

var sqlServerName      = 'fintrack-sql-${suffix}'
var sqlDatabaseName    = 'finance-db'
var storageAccountName = 'fintrackst${take(suffix, 8)}'

// ── SQL Server ────────────────────────────────────────────────────────────────

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: sqlAdminPassword
    publicNetworkAccess: 'Enabled'
    version: '12.0'
  }
}

resource firewallAllowAll 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAll'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

resource firewallAllowAzureServices 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

// ── Storage Account ───────────────────────────────────────────────────────────

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_0'
    supportsHttpsTrafficOnly: false
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource financeReportsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'finance-reports'
  properties: {
    publicAccess: 'Blob'
  }
}

resource dbBackupsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'db-backups'
  properties: {
    publicAccess: 'Container'
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

output sqlServerFqdn      string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseName    string = sqlDatabase.name
output storageAccountName string = storageAccount.name
output storageAccountKey  string = storageAccount.listKeys().keys[0].value
