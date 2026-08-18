<#
.SYNOPSIS
    Audits Azure Storage Accounts that have Private Endpoints configured.

.DESCRIPTION
    This script queries Azure Storage Accounts across one or all accessible subscriptions
    and extracts metadata for Storage Accounts configured with Private Endpoints.
    Outputs the result to CSV or JSON format.

.PARAMETER SubscriptionId
    Optional. The specific Azure Subscription ID to audit. If omitted, audits all accessible subscriptions.

.PARAMETER OutputPath
    Optional. The file path to save the generated audit report. Defaults to "StorageAccountsWithPrivateEndpoints.csv".

.PARAMETER ExportFormat
    Optional. The output format: 'CSV' or 'JSON'. Defaults to 'CSV'.

.EXAMPLE
    .\audit-storage-with-pe.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000" -OutputPath "PE_Audit.csv"

.EXAMPLE
    .\audit-storage-with-pe.ps1 -ExportFormat JSON -OutputPath "PE_Audit.json"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "StorageAccountsWithPrivateEndpoints.csv",

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

            if ($peConnections -and $peConnections.Count -gt 0) {
                $peNames = ($peConnections.Name -join ", ")
                $peStates = ($peConnections.PrivateLinkServiceConnectionState.Status -join ", ")

                $report.Add([PSCustomObject]@{
                    SubscriptionId       = $sub.Id
                    SubscriptionName     = $sub.Name
                    ResourceGroupName    = $sa.ResourceGroupName
                    StorageAccountName   = $sa.StorageAccountName
                    Location             = $sa.Location
                    SKU                  = $sa.Sku.Name
                    PrivateEndpointCount = $peConnections.Count
                    PrivateEndpointNames = $peNames
                    ConnectionStatus     = $peStates
                })
            }
        }
    } catch {
        Write-Warning "Failed to query storage accounts in subscription $($sub.Name): $_"
    }
}

# Export Results
if ($report.Count -eq 0) {
    Write-Host "No storage accounts with Private Endpoints were found." -ForegroundColor Yellow
} else {
    if ($ExportFormat -eq "CSV") {
        $report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "Audit report successfully exported to CSV: $OutputPath" -ForegroundColor Green
    } else {
        $report | ConvertTo-Json -Depth 4 | Set-Content -Path $OutputPath -Encoding UTF8
        Write-Host "Audit report successfully exported to JSON: $OutputPath" -ForegroundColor Green
    }
}
