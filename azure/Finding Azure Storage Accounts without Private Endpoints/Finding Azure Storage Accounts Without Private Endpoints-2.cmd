@REM Using Azure Resource Graph (Most efficient for large environments)

az graph query -q "
resources
| where type == 'microsoft.storage/storageaccounts'
| where isnull(properties.privateEndpointConnections)
| project name, resourceGroup, location, sku=sku.name
" -o table