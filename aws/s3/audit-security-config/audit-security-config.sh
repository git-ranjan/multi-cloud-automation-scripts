#!/usr/bin/env bash
# ==============================================================================
# Script:    audit-security-config.sh
# Purpose:   Audit S3 bucket security configuration (Public Access Block,
#            default encryption, versioning) using the AWS CLI.
# Requires:  AWS CLI (aws) and jq. Read-only.
# Usage:     ./audit-security-config.sh [table|json] [output-file]
#            Env: AWS_PROFILE, AWS_REGION (AWS CLI standard)
# ==============================================================================

set -euo pipefail

OUTPUT_FORMAT="${1:-table}"
OUTPUT_FILE="${2:-}"

echo "======================================================================"
echo " Auditing S3 bucket security configuration (AWS CLI)"
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

encryption_enabled() {
    local bucket="$1"
    if output="$(aws s3api get-bucket-encryption --bucket "$bucket" \
            --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
            --output json 2>/dev/null)"; then
        if [[ "$output" == 'null' ]]; then printf 'false'; else printf '%s' "$output"; fi
    else
        printf 'false'
    fi
}

versioning_enabled() {
    local bucket="$1"
    if output="$(aws s3api get-bucket-versioning --bucket "$bucket" \
            --query 'Status' --output json 2>/dev/null)"; then
        if [[ "$output" == '"Enabled"' ]]; then printf 'true'; else printf 'false'; fi
    else
        printf 'false'
    fi
}

# --- Audit --------------------------------------------------------------------
JSON_ROWS="[]"
HARDENED_COUNT=0
TOTAL=0

for bucket in $BUCKETS; do
    pab="$(public_block_enabled "$bucket")"
    enc="$(encryption_enabled "$bucket")"
    ver="$(versioning_enabled "$bucket")"

    hardened="false"
    if [[ "$pab" == "true" && "$enc" != "false" && "$ver" == "true" ]]; then
        hardened="true"
        HARDENED_COUNT=$((HARDENED_COUNT + 1))
    fi
    TOTAL=$((TOTAL + 1))

    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        row="$(jq -n \
            --arg account "$ACCOUNT" \
            --arg bucket "$bucket" \
            --argjson pab "$pab" \
            --arg enc "$enc" \
            --argjson ver "$ver" \
            --argjson hardened "$hardened" \
            '{account_id:$account,bucket:$bucket,public_access_block_enabled:$pab,default_encryption:($enc!="false"),encryption_type:$enc,versioning_enabled:$ver,hardened:$hardened}')"
        JSON_ROWS="$(printf '%s' "$JSON_ROWS" | jq --argjson row "$row" '. + [$row]')"
    else
        printf '%-6s %-45s pab=%-5s enc=%-8s versioning=%-5s\n' \
            "$([ "$hardened" == "true" ] && echo HARDENED || echo REVIEW)" \
            "$bucket" "$pab" "$enc" "$ver"
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

echo "Audited $TOTAL bucket(s), $HARDENED_COUNT fully hardened." >&2