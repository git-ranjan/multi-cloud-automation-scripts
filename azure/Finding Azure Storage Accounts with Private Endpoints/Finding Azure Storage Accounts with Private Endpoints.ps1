#Using Azure PowerShell
# Connect to Azure
Connect-AzAccount

# Get all storage accounts with private endpoints
$storageAccounts = Get-AzStorageAccount
$report = @()

foreach ($sa in $storageAccounts) {
    $privateEndpoints = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $sa.Id
    if ($privateEndpoints) {
        $report += [PSCustomObject]@{
            StorageAccountName = $sa.StorageAccountName
            ResourceGroupName = $sa.ResourceGroupName
            Location = $sa.Location
            PrivateEndpointCount = $privateEndpoints.Count
            PrivateEndpointNames = ($privateEndpoints.Name -join ", ")
        }
    }
}

# Export to CSV
$report | Export-Csv -Path "StorageAccountsWithPrivateEndpoints.csv" -NoTypeInformation

# Download the file (if needed)
Write-Host "Download the report from: https://shell.azure.com/powershell#blade/Microsoft_Azure_Storage/ContainerMenuBlade/container/cloudshell/path/PrivateEndpointStorageReport.csv"
