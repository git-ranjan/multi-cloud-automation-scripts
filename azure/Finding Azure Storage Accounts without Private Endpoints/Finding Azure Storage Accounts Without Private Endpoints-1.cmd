@REM # Using Azure CLI
# List all storage accounts without private endpoints
az storage account list \
  --query "[?privateEndpointConnections==null].{Name:name, ResourceGroup:resourceGroup, Location:location, SKU:sku.name}" \
  -o table

@REM # Export to JSON file
az storage account list \
  --query "[?privateEndpointConnections==null]" \
  -o json > storage_without_private_endpoints.json

@REM Additional Filters You Might Want:

@REM Add subscription filter:
@REM az storage account list --subscription "Your-Sub-ID" --query [...]

@REM Filter by network configuration (public vs private):
@REM az storage account list --query "[?privateEndpointConnections==null && networkRuleSet.defaultAction=='Allow'].{Name:name, PublicAccess:networkRuleSet.defaultAction}" -o table

@REM Check for storage accounts with public blob access:
@REM az storage account list --query "[?privateEndpointConnections==null && allowBlobPublicAccess==true].{Name:name, PublicAccess:allowBlobPublicAccess}" -o table