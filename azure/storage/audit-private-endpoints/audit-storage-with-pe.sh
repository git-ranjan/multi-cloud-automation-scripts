#!/usr/bin/env bash
# ==============================================================================
# Script: audit-storage-with-pe.sh
# Description: Audit Azure Storage Accounts configured with Private Endpoints using Azure CLI / Resource Graph.
# ==============================================================================

set -euo pipefail

OUTPUT_FORMAT="${1:-table}"
OUTPUT_FILE="${2:-}"

echo "======================================================================"
echo " Auditing Azure Storage Accounts with Private Endpoints (Azure CLI)"
echo "======================================================================"

# Verify Azure CLI login status
if ! az account show >/dev/null 2>&1; then
    echo "Error: Not logged into Azure CLI. Please run 'az login' first." >&2
    exit 1
fi

KQL_QUERY="
resources
| where type =~ 'microsoft.storage/storageaccounts'
| extend peCount = array_length(properties.privateEndpointConnections)
| where peCount > 0
| project subscriptionId, resourceGroup, name, location, sku=sku.name, peCount
| sort by peCount desc
"

if [[ -n "$OUTPUT_FILE" ]]; then
    echo "Executing Resource Graph Query and exporting to $OUTPUT_FILE..."
    az graph query -q "$KQL_QUERY" --output "$OUTPUT_FORMAT" > "$OUTPUT_FILE"
    echo "Report saved to $OUTPUT_FILE"
else
    echo "Executing Resource Graph Query..."
    az graph query -q "$KQL_QUERY" --output "$OUTPUT_FORMAT"
fi
