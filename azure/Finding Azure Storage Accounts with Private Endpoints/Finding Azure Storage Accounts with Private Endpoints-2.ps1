# Get all private endpoints in the subscription
$allPrivateEndpoints = Get-AzPrivateEndpoint

# Filter for those connected to storage accounts
$storagePEs = $allPrivateEndpoints | Where-Object {
    $_.PrivateLinkServiceConnections.PrivateLinkServiceId -like "*Microsoft.Storage/storageAccounts*"
}

# Display results
$storagePEs | ForEach-Object {
    $storageAccountId = $_.PrivateLinkServiceConnections.PrivateLinkServiceId
    $storageAccountName = $storageAccountId.Split('/')[-1]
    
    [PSCustomObject]@{
        PrivateEndpointName = $_.Name
        StorageAccountName = $storageAccountName
        ResourceGroup = $_.ResourceGroupName
        VNET = $_.Subnet.Id.Split('/')[8]
        ConnectionState = $_.PrivateLinkServiceConnections[0].PrivateLinkServiceConnectionState.Status
    }
}