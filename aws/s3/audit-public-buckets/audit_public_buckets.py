#!/usr/bin/env python3
"""Audit S3 buckets for public accessibility.

Evaluates every bucket in the account against the three exposure vectors that
can make an S3 bucket publicly reachable:

    1. Public Access Block  - all four settings must be enabled
    2. Bucket policy        - PolicyStatus.IsPublic == true
    3. Bucket ACL           - grants to AllUsers / AuthenticatedUsers

Any bucket failing one of the checks is flagged. Output is written as CSV or
JSON. Read-only; requires s3:ListAllMyBuckets plus Get* on the evaluated
controls (read-only S3 permissions are sufficient).

Dependencies: boto3  (pip install -r requirements.txt)
"""

from __future__ import annotations

import argparse
import csv
import json
import sys

import boto3
from botocore.exceptions import ClientError, NoCredentialsError

PUBLIC_GRANTEE_URIS = frozenset(
    (
        "http://acs.amazonaws.com/groups/global/AllUsers",
        "http://acs.amazonaws.com/groups/global/AuthenticatedUsers",
    )
)

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
    "policy_public",
    "acl_public",
    "acl_public_permissions",
    "is_public",
)


def resolve_account(session: "boto3.Session") -> str:
    """Return the account ID of the current caller."""
    return session.client("sts").get_caller_identity()["Account"]


def bucket_region(s3, bucket: str) -> str:
    """Resolve a bucket's region (None location implies us-east-1)."""
    try:
        location = s3.get_bucket_location(Bucket=bucket).get("LocationConstraint")
    except ClientError:
        return "us-east-1"
    return location or "us-east-1"


def public_block_enabled(s3, bucket: str) -> bool:
    """True only when all four Public Access Block settings are on.

    A bucket without a Public Access Block configuration is treated as
    unblocked (legacy behavior) so it is always reported as a finding.
    """
    try:
        config = s3.get_public_access_block(Bucket=bucket).get(
            "PublicAccessBlockConfiguration", {}
        )
    except ClientError:
        return False
    return all(config.get(setting, False) for setting in PAB_SETTINGS)


def policy_is_public(s3, bucket: str) -> bool:
    """True when the bucket policy allows anonymous/other-account access."""
    try:
        status = s3.get_bucket_policy_status(Bucket=bucket).get("PolicyStatus", {})
    except ClientError:
        return False
    return bool(status.get("IsPublic", False))


def acl_public(s3, bucket: str) -> tuple[bool, list[str]]:
    """Return (public?, permissions) based on ACL grants to public groups."""
    try:
        grants = s3.get_bucket_acl(Bucket=bucket).get("Grants", [])
    except ClientError:
        return False, []
    public = [
        grant.get("Permission")
        for grant in grants
        if grant.get("Grantee", {}).get("URI") in PUBLIC_GRANTEE_URIS
    ]
    return bool(public), public


def audit_bucket(s3, account: str, bucket: str) -> dict:
    region = bucket_region(s3, bucket)
    # The S3 control-plane APIs must target the bucket's home region.
    regional = s3.meta.session.client("s3", region_name=region)

    pab = public_block_enabled(regional, bucket)
    ppub = policy_is_public(regional, bucket)
    apub, permissions = acl_public(regional, bucket)

    return {
        "account_id": account,
        "bucket": bucket,
        "region": region,
        "public_access_block_enabled": pab,
        "policy_public": ppub,
        "acl_public": apub,
        "acl_public_permissions": ",".join(sorted(permissions)),
        "is_public": (not pab) or ppub or apub,
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
        description="Audit S3 buckets for public accessibility.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--profile", help="AWS CLI profile to use")
    parser.add_argument("--region", default="us-east-1", help="Default region for STS/control calls")
    parser.add_argument("--bucket", action="append", help="Restrict to specific bucket(s); repeatable")
    parser.add_argument(
        "--only-public", action="store_true", help="Report only buckets flagged as public"
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
    if args.only_public:
        rows = [row for row in rows if row["is_public"]]

    write_report(rows, args.format, args.output_file)
    print(
        f"Audited {len(buckets)} bucket(s), {sum(1 for r in rows if r['is_public'])} flagged public.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
