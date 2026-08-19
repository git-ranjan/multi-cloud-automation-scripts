#!/usr/bin/env python3
"""Audit the security configuration of S3 buckets.

Reports the state of the three foundational S3 hardening controls for every
bucket in the account:

    1. Public Access Block   - all four settings enabled
    2. Default encryption    - SSE-S3 or SSE-KMS configured
    3. Versioning            - bucket versioning enabled

A bucket is considered fully hardened when all three controls are in place.
Output is written as CSV or JSON. Read-only.

Dependencies: boto3  (pip install -r requirements.txt)
"""

from __future__ import annotations

import argparse
import csv
import json
import sys

import boto3
from botocore.exceptions import ClientError, NoCredentialsError

PAB_SETTINGS = (
    "BlockPublicAcls",
    "IgnorePublicAcls",
    "BlockPublicPolicy",
    "RestrictPublicBuckets",
)

COLUMNS = (
    "account_id",
    "bucket",
    "region",
    "public_access_block_enabled",
    "default_encryption",
    "encryption_type",
    "versioning_enabled",
    "hardened",
)


def resolve_account(session: boto3.Session) -> str:
    return session.client("sts").get_caller_identity()["Account"]


def bucket_region(s3, bucket: str) -> str:
    try:
        location = s3.get_bucket_location(Bucket=bucket).get("LocationConstraint")
    except ClientError:
        return "us-east-1"
    return location or "us-east-1"


def public_block_enabled(s3, bucket: str) -> bool:
    try:
        config = s3.get_public_access_block(Bucket=bucket).get(
            "PublicAccessBlockConfiguration", {}
        )
    except ClientError:
        return False
    return all(config.get(setting, False) for setting in PAB_SETTINGS)


def default_encryption(s3, bucket: str) -> tuple[bool, str]:
    try:
        rule = s3.get_bucket_encryption(Bucket=bucket).get(
            "ServerSideEncryptionConfiguration", {}
        ).get("Rules", [{}])[0].get("ApplyServerSideEncryptionByDefault", {})
    except ClientError:
        return False, "NONE"
    sse = rule.get("SSEAlgorithm", "UNKNOWN")
    key = rule.get("KMSMasterKeyID", "")
    detail = f"{sse}" + (f" ({key})" if key else "")
    return True, detail


def versioning_enabled(s3, bucket: str) -> bool:
    try:
        status = s3.get_bucket_versioning(Bucket=bucket).get("Status")
    except ClientError:
        return False
    return status == "Enabled"


def audit_bucket(s3, account: str, bucket: str) -> dict:
    region = bucket_region(s3, bucket)
    regional = s3.meta.session.client("s3", region_name=region)

    pab = public_block_enabled(regional, bucket)
    enc, enc_type = default_encryption(regional, bucket)
    versioning = versioning_enabled(regional, bucket)

    return {
        "account_id": account,
        "bucket": bucket,
        "region": region,
        "public_access_block_enabled": pab,
        "default_encryption": enc,
        "encryption_type": enc_type,
        "versioning_enabled": versioning,
        "hardened": pab and enc and versioning,
    }


def write_report(rows: list[dict], output_format: str, output_file: str | None) -> None:
    if output_format == "csv":
        handle = open(output_file, "w", newline="", encoding="utf-8") if output_file else sys.stdout
        writer = csv.DictWriter(handle, fieldnames=COLUMNS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
        if output_file:
            handle.close()
    else:
        payload = json.dumps(rows, indent=2, default=str)
        if output_file:
            with open(output_file, "w", encoding="utf-8") as handle:
                handle.write(payload + "\n")
        else:
            print(payload)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Audit S3 bucket security configuration.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--profile", help="AWS CLI profile to use")
    parser.add_argument("--region", default="us-east-1", help="Default region for control calls")
    parser.add_argument("--bucket", action="append", help="Restrict to specific bucket(s); repeatable")
    parser.add_argument(
        "--only-hardened", action="store_true", help="Report only fully hardened buckets"
    )
    parser.add_argument("--format", choices=("csv", "json"), default="csv", help="Report format")
    parser.add_argument("--output-file", help="Write report to file instead of stdout")
    args = parser.parse_args()

    try:
        session = boto3.Session(profile_name=args.profile, region_name=args.region)
        account = resolve_account(session)
    except (NoCredentialsError, ClientError) as exc:
        print(f"Error: unable to authenticate to AWS ({exc}).", file=sys.stderr)
        return 2

    s3 = session.client("s3")
    try:
        buckets = [b["Name"] for b in s3.list_buckets().get("Buckets", [])]
    except ClientError as exc:
        print(f"Error: failed to list buckets ({exc}).", file=sys.stderr)
        return 2

    if args.bucket:
        requested = set(args.bucket)
        missing = requested - set(buckets)
        if missing:
            print(
                f"Warning: bucket(s) not found in this account: {', '.join(sorted(missing))}",
                file=sys.stderr,
            )
        buckets = [b for b in buckets if b in requested]

    rows = [audit_bucket(s3, account, bucket) for bucket in buckets]
    if args.only_hardened:
        rows = [row for row in rows if row["hardened"]]

    write_report(rows, args.format, args.output_file)
    print(
        f"Audited {len(buckets)} bucket(s), {sum(1 for r in rows if r['hardened'])} fully hardened.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
