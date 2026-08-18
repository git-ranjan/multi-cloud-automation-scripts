#!/usr/bin/env bash
# ==============================================================================
# Script:    audit-public-buckets.sh
# Purpose:   Audit S3 buckets for public accessibility using the AWS CLI.
# Requires:  AWS CLI (aws) and jq. Read-only.
# Usage:     ./audit-public-buckets.sh [table|json] [output-file]
#            Env: AWS_PROFILE, AWS_REGION (AWS CLI standard)
# ==============================================================================

set -euo pipefail

OUTPUT_FORMAT="${1:-table}"
OUTPUT_FILE="${2:-}"

echo "======================================================================"
echo " Auditing S3 buckets for public accessibility (AWS CLI)"
echo "======================================================================"

# --- Pre-flight checks -------------------------------------------------------
for tool in aws jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: required tool '$tool' is not installed." >&2
        exit 1
    fi
done

if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "Error: not authenticated with AWS. Please run 'aws configure' or set credentials." >&2
    exit 1
fi

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
BUCKETS="$(aws s3api list-buckets --query 'Buckets[].Name' --output text)"

# --- Per-bucket evaluation helpers -------------------------------------------
# Each helper returns "true"/"false". Missing configuration is reported as
# false (i.e. an exposure) so legacy buckets are never silently skipped.

public_block_enabled() {
    local bucket="$1"
    if output="$(aws s3api get-public-access-block --bucket "$bucket" \
            --query 'PublicAccessBlockConfiguration' --output json 2>/dev/null)"; then
        printf '%s' "$output" | jq -r \
            'if (.BlockPublicAcls and .IgnorePublicAcls and .BlockPublicPolicy and .RestrictPublicBuckets) then "true" else "false" end'
    else
        printf 'false'
    fi
}

policy_public() {
    local bucket="$1"
    if output="$(aws s3api get-bucket-policy-status --bucket "$bucket" \
            --query 'PolicyStatus.IsPublic' --output json 2>/dev/null)"; then
        printf '%s' "$output"
    else
        printf 'false'
    fi
}

acl_public() {
    local bucket="$1"
    if output="$(aws s3api get-bucket-acl --bucket "$bucket" \
            --query 'Grants[?Grantee.URI!=`null`].Permission' --output json 2>/dev/null)"; then
        printf '%s' "$output" | jq -r '
            if (any(. == "FULL_CONTROL" or . == "WRITE" or . == "READ" or . == "WRITE_ACP" or . == "READ_ACP")) then "true" else "false" end'
    else
        printf 'false'
    fi
}

# --- Audit --------------------------------------------------------------------
JSON_ROWS="[]"
PUBLIC_COUNT=0
TOTAL=0

for bucket in $BUCKETS; do
    pab="$(public_block_enabled "$bucket")"
    ppub="$(policy_public "$bucket")"
    apub="$(acl_public "$bucket")"

    is_public="false"
    if [[ "$pab" == "false" || "$ppub" == "true" || "$apub" == "true" ]]; then
        is_public="true"
        PUBLIC_COUNT=$((PUBLIC_COUNT + 1))
    fi
    TOTAL=$((TOTAL + 1))

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        row="$(jq -n \
            --arg account "$ACCOUNT" \
            --arg bucket "$bucket" \
            --argjson pab "$pab" \
            --argjson ppub "$ppub" \
            --argjson apub "$apub" \
            --argjson isPublic "$is_public" \
            '{account_id:$account,bucket:$bucket,public_access_block_enabled:$pab,policy_public:$ppub,acl_public:$apub,is_public:$isPublic}')"
        JSON_ROWS="$(printf '%s' "$JSON_ROWS" | jq --argjson row "$row" '. + [$row]')"
    else
        printf '%-6s %-45s pab=%-5s policy=%-5s acl=%-5s\n' \
            "$([ "$is_public" == "true" ] && echo PUBLIC || echo OK)" \
            "$bucket" "$pab" "$ppub" "$apub"
    fi
done

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    if [[ -n "$OUTPUT_FILE" ]]; then
        printf '%s\n' "$JSON_ROWS" > "$OUTPUT_FILE"
        echo "Report saved to $OUTPUT_FILE"
    else
        printf '%s\n' "$JSON_ROWS"
    fi
fi

echo "Audited $TOTAL bucket(s), $PUBLIC_COUNT flagged public." >&2