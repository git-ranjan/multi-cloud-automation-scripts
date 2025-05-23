@REM #Using Azure CLI
@REM # Login to Azure
az login

@REM # For more detailed output in JSON format
az storage account list --query "[?privateEndpointConnections!=null]" -o json > storage_with_pe.json
