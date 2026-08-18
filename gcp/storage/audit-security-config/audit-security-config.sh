#!/usr/bin/env bash
# ==============================================================================
# Script:    audit-security-config.sh
# Purpose:   Audit Cloud Storage bucket security configuration (uniform bucket
#            level access, public access prevention, public IAM bindings).
# Requires:  Google Cloud SDK (gcloud, gsutil) and jq. Read-only.
# Usage:     ./audit-security-config.sh [table|json] [output-file]
#            Env: GCP_PROJECT (optional; defaults to gcloud configured project)
# ==============================================================================

set -euo pipefail

OUTPUT_FORMAT="${1:-table}"
OUTPUT_FILE="${2:-}"

echo "======================================================================"
echo " Auditing Cloud Storage bucket security configuration (gcloud/gsutil)"
echo "======================================================================"

# --- Pre-flight checks -------------------------------------------------------
for tool in gcloud gsutil jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: required tool '$tool' is not installed." >&2
        exit 1
    fi
done

if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | grep -q .; then
    echo "Error: not authenticated with Google Cloud. Please run 'gcloud auth login'." >&2
    exit 1
fi

PROJECT="${GCP_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"

GCLOUD_ARGS=()
GSUTIL_ARGS=()
if [[ -n "$PROJECT" ]]; then
    GCLOUD_ARGS=(--project "$PROJECT")
    GSUTIL_ARGS=(-p "$PROJECT")
fi

# --- Audit --------------------------------------------------------------------
JSON_ROWS="[]"
HARDENED_COUNT=0
TOTAL=0

while IFS= read -r bucket; do
    uri="gs://$bucket"

    describe="$(gcloud storage buckets describe "$uri" \
        "${GCLOUD_ARGS[@]}" --format=json 2>/dev/null || true)"

    if [[ -z "$describe" ]]; then
        uniform="false"
        pap="unknown"
    else
        uniform="$(printf '%s' "$describe" | jq -r \
            '.iamConfiguration.uniformBucketLevelAccess.enabled // false')"
        pap="$(printf '%s' "$describe" | jq -r '.iamConfiguration.publicAccessPrevention // "unspecified"')"
    fi

    policy="$(gsutil "${GSUTIL_ARGS[@]}" iam get "$uri" 2>/dev/null || true)"
    if [[ -n "$policy" ]]; then
        is_public="$(printf '%s' "$policy" | jq -r \
            'if ([.bindings[].members[]] | index("allUsers")) or ([.bindings[].members[]] | index("allAuthenticatedUsers")) then "true" else "false" end')"
    else
        is_public="unknown"
    fi

    hardened="false"
    if [[ "$uniform" == "true" && "$pap" == "enforced" && "$is_public" == "false" ]]; then
        hardened="true"
        HARDENED_COUNT=$((HARDENED_COUNT + 1))
    fi
    TOTAL=$((TOTAL + 1))

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        row="$(jq -n \
            --arg bucket "$bucket" \
            --argjson uniform "$uniform" \
            --arg pap "$pap" \
            --argjson public "$( [ "$is_public" == "true" ] && echo true || echo false )" \
            --argjson hardened "$hardened" \
            '{bucket:$bucket,uniform_bucket_level_access:$uniform,public_access_prevention:$pap,public:$public,hardened:$hardened}')"
        JSON_ROWS="$(printf '%s' "$JSON_ROWS" | jq --argjson row "$row" '. + [$row]')"
    else
        printf '%-8s %-40s uniform=%-5s pap=%-12s public=%-5s\n' \
            "$([ "$hardened" == "true" ] && echo HARDENED || echo REVIEW)" \
            "$bucket" "$uniform" "$pap" "$is_public"
    fi
done < <(gcloud storage buckets list "${GCLOUD_ARGS[@]}" --format='value(name)')

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    if [[ -n "$OUTPUT_FILE" ]]; then
        printf '%s\n' "$JSON_ROWS" > "$OUTPUT_FILE"
        echo "Report saved to $OUTPUT_FILE"
    else
        printf '%s\n' "$JSON_ROWS"
    fi
fi

echo "Audited $TOTAL bucket(s), $HARDENED_COUNT fully hardened." >&2