<#
.SYNOPSIS
    Audits Azure Storage Accounts configured with Private Endpoints.

.DESCRIPTION
    Queries Azure Storage Accounts across one or all accessible subscriptions and
    reports metadata for accounts that have at least one Private Endpoint connection.
    Results are exported to CSV or JSON.

    This script is strictly read-only and requires at least the Reader role on every
    subscription it audits.

.PARAMETER SubscriptionId
    One or more Azure Subscription IDs to audit. If omitted, all accessible
    subscriptions are audited.

.PARAMETER Environment
    The Azure cloud environment to connect to. Defaults to AzureCloud.

.PARAMETER NoAuthPrompt
    Prevents the script from launching an interactive browser login. When no Azure
    context is available and this switch is set, the script fails fast with an
    actionable error. Use this in CI or with an existing service principal context.

.PARAMETER OutputPath
    Path where the audit report is written. When omitted a timestamped file is
    generated in the current directory.

.PARAMETER ExportFormat
    Output format: 'CSV' or 'JSON'. Defaults to 'CSV'.

.EXAMPLE
    .\audit-storage-with-pe.ps1 -OutputPath "PE_Audit.csv"

.EXAMPLE
    .\audit-storage-with-pe.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000","11111111-1111-1111-1111-111111111111" -ExportFormat JSON -OutputPath "PE_Audit.json"

.EXAMPLE
    # Run in CI with an already established service principal context
    .\audit-storage-with-pe.ps1 -NoAuthPrompt -OutputPath "PE_Audit.json" -ExportFormat JSON

.NOTES
    Subscriptions are processed sequentially. The Azure context is process-global, so
    parallel runspaces would need re-authentication per runspace; sequential iteration
    keeps the audit deterministic and avoids context races.

.LINK
    https://learn.microsoft.com/azure/private-link/private-endpoint-overview
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string[]]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [ValidateSet('AzureCloud', 'AzureUSGovernment', 'AzureChinaCloud', 'AzureGermanyCloud')]
    [string]$Environment = 'AzureCloud',

    [Parameter(Mandatory = $false)]
    [switch]$NoAuthPrompt,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('CSV', 'JSON')]
    [string]$ExportFormat = 'CSV'
)

Set-StrictMode -Version Latest
$InformationPreference = 'Continue'

# Make sure the Az modules are available before anything else.
if (-not (Get-Module -Name Az.Accounts -ListAvailable) -or -not (Get-Module -Name Az.Storage -ListAvailable)) {
    throw "The Azure PowerShell modules (Az.Accounts, Az.Storage) are required. Install with 'Install-Module -Name Az -Scope CurrentUser -Force'."
}

# Ensure we have an authenticated context before trying to enumerate anything.
$context = Get-AzContext
if (-not $context) {
    if ($NoAuthPrompt) {
        throw "No active Azure context and -NoAuthPrompt was specified. Authenticate first (e.g. Connect-AzAccount) or remove -NoAuthPrompt."
    }
    Write-Information "No active Azure session found. Initiating login..."
    Connect-AzAccount -Environment $Environment -ErrorAction Stop | Out-Null
}

# Resolve which subscriptions we're auditing: explicit IDs or all accessible ones.
$allSubscriptions = Get-AzSubscription -ErrorAction Stop

if ($SubscriptionId) {
    $matched = foreach ($id in $SubscriptionId) {
        $allSubscriptions | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    }
    $subscriptions = @($matched | Where-Object { $_ })

    if ($SubscriptionId.Count -ne $subscriptions.Count) {
        Write-Warning "One or more SubscriptionId values did not match an accessible subscription and were skipped."
    }
    if ($subscriptions.Count -eq 0) {
        throw "No matching subscriptions found for the provided SubscriptionId parameter(s)."
    }
} else {
    $subscriptions = $allSubscriptions
}

# Build a default output file name when the caller didn't pass one.
if (-not $PSBoundParameters.ContainsKey('OutputPath')) {
    $extension = if ($ExportFormat -eq 'JSON') { 'json' } else { 'csv' }
    $OutputPath = "StorageAccountsWithPrivateEndpoints_$(Get-Date -Format 'yyyyMMdd_HHmmss').$extension"
}
$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
    $null = New-Item -ItemType Directory -Path $outputDirectory -Force
}

# Walk each subscription and collect accounts that have private endpoints.
$report = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($sub in $subscriptions) {
    Write-Information "Auditing subscription: $($sub.Name) ($($sub.Id))..."
    $null = Set-AzContext -SubscriptionId $sub.Id -ErrorAction SilentlyContinue

    try {
        $storageAccounts = Get-AzStorageAccount -ErrorAction Stop

        foreach ($sa in $storageAccounts) {
            $peConnections = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $sa.Id -ErrorAction SilentlyContinue

            if ($peConnections -and $peConnections.Count -gt 0) {
                $report.Add([PSCustomObject]@{
                    SubscriptionId       = $sub.Id
                    SubscriptionName     = $sub.Name
                    ResourceGroupName    = $sa.ResourceGroupName
                    StorageAccountName   = $sa.StorageAccountName
                    Location             = $sa.Location
                    SKU                  = $sa.Sku.Name
                    PublicNetworkAccess  = if ($null -ne $sa.PublicNetworkAccess) { $sa.PublicNetworkAccess } else { 'Unknown' }
                    RequireSecureTransfer = $sa.EnableHttpsTrafficOnly
                    PrivateEndpointCount = $peConnections.Count
                    PrivateEndpointNames = ($peConnections.Name -join ', ')
                    ConnectionStatus     = ($peConnections.PrivateLinkServiceConnectionState.Status -join ', ')
                })
            }
        }
    } catch {
        Write-Warning "Failed to query storage accounts in subscription '$($sub.Name)': $_"
    }
}

# Export the findings, or report an empty result.
if ($report.Count -eq 0) {
    Write-Information "No storage accounts with Private Endpoints were found."
    return
}

if ($ExportFormat -eq 'CSV') {
    $report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
} else {
    $report | ConvertTo-Json -Depth 4 | Set-Content -Path $OutputPath -Encoding UTF8
}

Write-Information "Audit report exported ($($report.Count) storage account(s)): $OutputPath"
