# Get all storage accounts without private endpoints
$storageAccounts = Get-AzStorageAccount
$noPrivateEndpoint = @()

foreach ($sa in $storageAccounts) {
    $privateEndpoints = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $sa.Id -ErrorAction SilentlyContinue
    if (-not $privateEndpoints) {
        $noPrivateEndpoint += [PSCustomObject]@{
            StorageAccountName = $sa.StorageAccountName
            ResourceGroupName = $sa.ResourceGroupName
            Location = $sa.Location
            SKU = $sa.Sku.Name
        }
    }
}

# Display results
$noPrivateEndpoint | Format-Table

# Export to CSV
$noPrivateEndpoint | Export-Csv -Path "StorageWithoutPrivateEndpoints.csv" -NoTypeInformation