@REM #Using Azure CLI
@REM # Login to Azure
az login

@REM # Get list of storage accounts with private endpoints (Alternative Command)
az storage account list --query "[?privateEndpointConnections!=null].{name:name, resourceGroup:resourceGroup, privateEndpoints:privateEndpointConnections[].privateEndpoint.id}" -o table