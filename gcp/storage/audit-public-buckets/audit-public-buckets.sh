#!/usr/bin/env bash
# ==============================================================================
# Script:    audit-public-buckets.sh
# Purpose:   Audit Cloud Storage buckets for public IAM bindings (allUsers /
#            allAuthenticatedUsers) using gsutil.
# Requires:  Google Cloud SDK (gsutil) and jq. Read-only.
# Usage:     ./audit-public-buckets.sh [table|json] [output-file]
#            Env: GCP_PROJECT (optional; defaults to gcloud configured project)
# ==============================================================================

set -euo pipefail

OUTPUT_FORMAT="${1:-table}"
OUTPUT_FILE="${2:-}"
PROJECT="${GCP_PROJECT:-}"

echo "======================================================================"
echo " Auditing Cloud Storage buckets for public IAM exposure (gsutil)"
echo "======================================================================"

# --- Pre-flight checks -------------------------------------------------------
for tool in gsutil jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: required tool '$tool' is not installed." >&2
        exit 1
    fi
done

if ! gsutil ls >/dev/null 2>&1; then
    echo "Error: not authenticated with Google Cloud. Please run 'gcloud auth login' and 'gcloud config set project'." >&2
    exit 1
fi

PROJECT_ARGS=()
if [[ -n "$PROJECT" ]]; then
    PROJECT_ARGS=(-p "$PROJECT")
fi

# --- Audit --------------------------------------------------------------------
JSON_ROWS="[]"
PUBLIC_COUNT=0
TOTAL=0

while IFS= read -r uri; do
    bucket="${uri%/}"

    policy="$(gsutil "${PROJECT_ARGS[@]}" iam get "$bucket" 2>/dev/null || true)"

    if [[ -z "$policy" ]]; then
        # IAM not readable -> record as unknown, do not drop silently
        is_public="unknown"
    else
        is_public="$(printf '%s' "$policy" | jq -r \
            'if ([.bindings[].members[]] | index("allUsers")) or ([.bindings[].members[]] | index("allAuthenticatedUsers")) then "true" else "false" end')"
    fi

    if [[ "$is_public" == "true" ]]; then
        PUBLIC_COUNT=$((PUBLIC_COUNT + 1))
    fi
    TOTAL=$((TOTAL + 1))

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        row="$(jq -n \
            --arg bucket "$bucket" \
            --argjson public "$( [ "$is_public" == "true" ] && echo true || echo false )" \
            '{bucket:$bucket,public:$public}')"
        JSON_ROWS="$(printf '%s' "$JSON_ROWS" | jq --argjson row "$row" '. + [$row]')"
    else
        printf '%-6s %s\n' \
            "$([ "$is_public" == "true" ] && echo PUBLIC || echo OK)" \
            "$bucket"
    fi
done < <(gsutil "${PROJECT_ARGS[@]}" ls)

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    if [[ -n "$OUTPUT_FILE" ]]; then
        printf '%s\n' "$JSON_ROWS" > "$OUTPUT_FILE"
        echo "Report saved to $OUTPUT_FILE"
    else
        printf '%s\n' "$JSON_ROWS"
    fi
fi

echo "Audited $TOTAL bucket(s), $PUBLIC_COUNT public." >&2