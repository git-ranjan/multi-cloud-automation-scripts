<#
.SYNOPSIS
    Audits Azure Storage Accounts that do NOT have Private Endpoints configured.

.DESCRIPTION
    Queries Azure Storage Accounts across one or all accessible subscriptions and
    flags accounts lacking Private Endpoint connections, highlighting potential
    public network exposure. Includes public network access, blob public access,
    TLS version and secure-transfer posture for triage.
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
    .\audit-storage-without-pe.ps1 -OutputPath "ExposedStorage.csv"

.EXAMPLE
    .\audit-storage-without-pe.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000" -ExportFormat JSON -OutputPath "ExposedStorage.json"

.NOTES
    Subscriptions are processed sequentially. The Azure context is process-global, so
    parallel runspaces would need re-authentication per runspace; sequential iteration
    keeps the audit deterministic and avoids context races.

.LINK
    https://learn.microsoft.com/azure/storage/common/storage-network-security
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

# ---------------------------------------------------------------------------
# Pre-flight: Az module
# ---------------------------------------------------------------------------
if (-not (Get-Module -Name Az.Accounts -ListAvailable) -or -not (Get-Module -Name Az.Storage -ListAvailable)) {
    throw "The Azure PowerShell modules (Az.Accounts, Az.Storage) are required. Install with 'Install-Module -Name Az -Scope CurrentUser -Force'."
}

# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------
$context = Get-AzContext
if (-not $context) {
    if ($NoAuthPrompt) {
        throw "No active Azure context and -NoAuthPrompt was specified. Authenticate first (e.g. Connect-AzAccount) or remove -NoAuthPrompt."
    }
    Write-Host "No active Azure session found. Initiating login..." -ForegroundColor Yellow
    Connect-AzAccount -Environment $Environment -ErrorAction Stop | Out-Null
}

# ---------------------------------------------------------------------------
# Subscription selection
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Output path resolution
# ---------------------------------------------------------------------------
if (-not $PSBoundParameters.ContainsKey('OutputPath')) {
    $extension = if ($ExportFormat -eq 'JSON') { 'json' } else { 'csv' }
    $OutputPath = "StorageAccountsWithoutPrivateEndpoints_$(Get-Date -Format 'yyyyMMdd_HHmmss').$extension"
}
$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
    $null = New-Item -ItemType Directory -Path $outputDirectory -Force
}

# ---------------------------------------------------------------------------
# Audit
# ---------------------------------------------------------------------------
$report = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($sub in $subscriptions) {
    Write-Host "Auditing subscription: $($sub.Name) ($($sub.Id))..." -ForegroundColor Cyan
    $null = Set-AzContext -SubscriptionId $sub.Id -ErrorAction SilentlyContinue

    try {
        $storageAccounts = Get-AzStorageAccount -ErrorAction Stop

        foreach ($sa in $storageAccounts) {
            $peConnections = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $sa.Id -ErrorAction SilentlyContinue

            if (-not $peConnections -or $peConnections.Count -eq 0) {
                $report.Add([PSCustomObject]@{
                    SubscriptionId        = $sub.Id
                    SubscriptionName      = $sub.Name
                    ResourceGroupName     = $sa.ResourceGroupName
                    StorageAccountName    = $sa.StorageAccountName
                    Location              = $sa.Location
                    SKU                   = $sa.Sku.Name
                    PublicNetworkAccess   = if ($null -ne $sa.PublicNetworkAccess) { $sa.PublicNetworkAccess } else { 'Enabled' }
                    AllowBlobPublicAccess = if ($null -ne $sa.AllowBlobPublicAccess) { $sa.AllowBlobPublicAccess } else { $true }
                    MinTlsVersion         = if ($null -ne $sa.MinimumTlsVersion) { $sa.MinimumTlsVersion } else { 'Unknown' }
                    RequireSecureTransfer = $sa.EnableHttpsTrafficOnly
                    PrivateEndpointCount  = 0
                })
            }
        }
    } catch {
        Write-Warning "Failed to query storage accounts in subscription '$($sub.Name)': $_"
    }
}

# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------
if ($report.Count -eq 0) {
    Write-Host "All storage accounts have Private Endpoints configured." -ForegroundColor Green
    return
}

if ($ExportFormat -eq 'CSV') {
    $report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
} else {
    $report | ConvertTo-Json -Depth 4 | Set-Content -Path $OutputPath -Encoding UTF8
}

Write-Host "Audit report exported ($($report.Count) exposed storage account(s)): $OutputPath" -ForegroundColor Green
