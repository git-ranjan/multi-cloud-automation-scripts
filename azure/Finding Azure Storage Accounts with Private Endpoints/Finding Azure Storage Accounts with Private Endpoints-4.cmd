#Using Azure CLI
# Login to Azure
az login

#Using Azure Resource Graph Explorer
# Alternative: Use Azure Resource Graph (KQL) in Cloud Shell or Azure CLI
# If you have Resource Graph permissions, you can run a more efficient query: 

az graph query -q "resources | where type == 'microsoft.storage/storageaccounts' | where isnotempty(properties.privateEndpointConnections) | project name, resourceGroup, location, privateEndpointCount=array_length(properties.privateEndpointConnections), privateEndpoints=properties.privateEndpointConnections[].{id:privateEndpoint.id, status=privateLinkServiceConnectionState.status} | sort by privateEndpointCount desc" -o table
