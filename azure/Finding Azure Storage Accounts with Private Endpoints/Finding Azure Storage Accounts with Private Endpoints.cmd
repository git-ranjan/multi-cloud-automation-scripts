#Using Azure CLI
# Login to Azure
az login

# Get list of storage accounts with private endpoints
az storage account list --query "[?privateEndpointConnections!=null].{name:name, resourceGroup:resourceGroup, location:location, privateEndpointCount:length(privateEndpointConnections), privateEndpoints:privateEndpointConnections[].privateEndpoint.id}" -o table

# For more detailed output in JSON format
az storage account list --query "[?privateEndpointConnections!=null]" -o json > storage_with_pe.json