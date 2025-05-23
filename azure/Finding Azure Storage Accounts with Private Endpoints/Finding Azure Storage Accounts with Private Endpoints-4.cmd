@REM #Using Azure CLI
@REM # Login to Azure
az login

@REM #Using Azure Resource Graph Explorer
@REM # Alternative: Use Azure Resource Graph (KQL) in Cloud Shell or Azure CLI
@REM # If you have Resource Graph permissions, you can run a more efficient query: 

az graph query -q "resources | where type == 'microsoft.storage/storageaccounts' | where isnotempty(properties.privateEndpointConnections) | project name, resourceGroup, location, privateEndpointCount=array_length(properties.privateEndpointConnections), privateEndpoints=properties.privateEndpointConnections[].{id:privateEndpoint.id, status=privateLinkServiceConnectionState.status} | sort by privateEndpointCount desc" -o table
