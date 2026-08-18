<#
.SYNOPSIS
    Audits Azure Storage Accounts lacking Private Endpoints to identify potential security exposures.

.DESCRIPTION
    This script queries Azure Storage Accounts across one or all accessible subscriptions
    and flags Storage Accounts that DO NOT have Private Endpoints configured.
    It inspects public network access settings and blob public access configurations.

.PARAMETER SubscriptionId
    Optional. Target Azure Subscription ID. If omitted, audits all accessible subscriptions.

.PARAMETER OutputPath
    Optional. File path for the generated audit report. Defaults to "StorageAccountsWithoutPrivateEndpoints.csv".

.PARAMETER ExportFormat
    Optional. The output format: 'CSV' or 'JSON'. Defaults to 'CSV'.

.EXAMPLE
    .\audit-storage-without-pe.ps1 -OutputPath "ExposedStorageReport.csv"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "StorageAccountsWithoutPrivateEndpoints.csv",

    [Parameter(Mandatory = $false)]
    [ValidateSet("CSV", "JSON")]
    [string]$ExportFormat = "CSV"
)

# Ensure Az module is available
if (-not (Get-Module -Name Az.Accounts -ListAvailable)) {
    Write-Error "The Azure PowerShell module (Az) is not installed. Please install it using 'Install-Module -Name Az'."
    return
}

# Verify Azure context
$context = Get-AzContext
if (-not $context) {
    Write-Host "No active Azure session found. Initiating Login..." -ForegroundColor Yellow
    Connect-AzAccount | Out-Null
}

# Select target subscriptions
if ($SubscriptionId) {
    $subscriptions = Get-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop
} else {
    $subscriptions = Get-AzSubscription -ErrorAction Stop
}

$report = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($sub in $subscriptions) {
    Write-Host "Auditing Subscription: $($sub.Name) ($($sub.Id))..." -ForegroundColor Cyan
    $null = Set-AzContext -SubscriptionId $sub.Id -ErrorAction SilentlyContinue

    try {
        $storageAccounts = Get-AzStorageAccount -ErrorAction Stop

        foreach ($sa in $storageAccounts) {
            $peConnections = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $sa.Id -ErrorAction SilentlyContinue

            if (-not $peConnections -or $peConnections.Count -eq 0) {
                $publicAccess = if ($sa.PublicNetworkAccess) { $sa.PublicNetworkAccess } else { "Enabled" }
                $blobPublicAccess = if ($null -ne $sa.AllowBlobPublicAccess) { $sa.AllowBlobPublicAccess } else { $true }

                $report.Add([PSCustomObject]@{
                    SubscriptionId       = $sub.Id
                    SubscriptionName     = $sub.Name
                    ResourceGroupName    = $sa.ResourceGroupName
                    StorageAccountName   = $sa.StorageAccountName
                    Location             = $sa.Location
                    SKU                  = $sa.Sku.Name
                    PublicNetworkAccess  = $publicAccess
                    AllowBlobPublicAccess= $blobPublicAccess
                    PrivateEndpointCount = 0
                })
            }
        }
    } catch {
        Write-Warning "Failed to query storage accounts in subscription $($sub.Name): $_"
    }
}

# Export Results
if ($report.Count -eq 0) {
    Write-Host "All storage accounts have Private Endpoints configured!" -ForegroundColor Green
} else {
    if ($ExportFormat -eq "CSV") {
        $report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "Audit report successfully exported to CSV: $OutputPath" -ForegroundColor Green
    } else {
        $report | ConvertTo-Json -Depth 4 | Set-Content -Path $OutputPath -Encoding UTF8
        Write-Host "Audit report successfully exported to JSON: $OutputPath" -ForegroundColor Green
    }
}
