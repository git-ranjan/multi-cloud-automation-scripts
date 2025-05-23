@REM #Using Azure CLI
@REM # Login to Azure
az login

@REM # Get list of storage accounts with private endpoints
az storage account list --query "[?privateEndpointConnections!=null].{name:name, resourceGroup:resourceGroup, location:location, privateEndpointCount:length(privateEndpointConnections), privateEndpoints:privateEndpointConnections[].privateEndpoint.id}" -o table
