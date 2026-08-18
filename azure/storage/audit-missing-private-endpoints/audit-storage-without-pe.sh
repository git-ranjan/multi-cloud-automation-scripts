#!/usr/bin/env bash
# ==============================================================================
# Script:    audit-storage-without-pe.sh
# Purpose:   Audit Azure Storage Accounts LACKING Private Endpoints to surface
#            potential public exposure, using Azure Resource Graph.
# Requires:  Azure CLI (az) + resource-graph extension. Read-only.
# Usage:     ./audit-storage-without-pe.sh [table|json|tsv] [output-file]
#            Env: SUBSCRIPTION_ID (restrict to a single subscription),
#                 PAGE_SIZE (rows per page, default 1000)
# ==============================================================================

set -euo pipefail

OUTPUT_FORMAT="${1:-table}"
OUTPUT_FILE="${2:-}"
PAGE_SIZE="${PAGE_SIZE:-1000}"

echo "======================================================================"
echo " Auditing Azure Storage Accounts WITHOUT Private Endpoints (Azure CLI)"
echo "======================================================================"

# --- Pre-flight checks -------------------------------------------------------
if ! command -v az >/dev/null 2>&1; then
    echo "Error: Azure CLI (az) is not installed." >&2
    exit 1
fi

if ! az account show >/dev/null 2>&1; then
    echo "Error: Not logged into Azure CLI. Please run 'az login' first." >&2
    exit 1
fi

# --- Query --------------------------------------------------------------------
KQL_QUERY="
resources
| where type =~ 'microsoft.storage/storageaccounts'
| extend peCount = array_length(properties.privateEndpointConnections)
| where peCount == 0 or isnull(peCount)
| project subscriptionId, resourceGroup, name, location, sku=sku.name,
          publicNetworkAccess=properties.publicNetworkAccess,
          allowBlobPublicAccess=properties.allowBlobPublicAccess
| sort by resourceGroup asc
"

SCOPE_ARGS=()
if [[ -n "${SUBSCRIPTION_ID:-}" ]]; then
    SCOPE_ARGS=(--subscriptions "$SUBSCRIPTION_ID")
fi

# --- Execute ------------------------------------------------------------------
if [[ -n "$OUTPUT_FILE" ]]; then
    # Paginated export (complete data without truncation). Uses tsv so rows are
    # stable and mergeable regardless of the chosen display format.
    : > "$OUTPUT_FILE"
    offset=0
    total=0

    while :; do
        page="$(az graph query -q "$KQL_QUERY" "${SCOPE_ARGS[@]}" \
                --first "$PAGE_SIZE" --skip "$offset" --output tsv || true)"

        if [[ -z "$page" ]]; then
            break
        fi

        printf '%s\n' "$page" >> "$OUTPUT_FILE"
        rows="$(printf '%s\n' "$page" | wc -l | tr -d ' ')"
        total=$((total + rows))
        offset=$((offset + rows))

        if [[ "$rows" -lt "$PAGE_SIZE" ]]; then
            break
        fi
    done

    echo "Report saved to $OUTPUT_FILE ($total record(s))"
else
    echo "Executing Resource Graph query..."
    az graph query -q "$KQL_QUERY" "${SCOPE_ARGS[@]}" --output "$OUTPUT_FORMAT"
fi