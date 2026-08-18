#!/usr/bin/env python3
"""Audit the security configuration of Cloud Storage buckets.

Reports the state of the key bucket-level hardening controls for every bucket
in a project:

    1. Uniform bucket-level access - access governed solely by IAM
    2. Public access prevention    - enforced / inherited / unspecified
    3. Public IAM bindings         - allUsers / allAuthenticatedUsers

A bucket is considered fully hardened when uniform bucket-level access is
enabled, public access prevention is enforced, and no public bindings exist.
Output is written as CSV or JSON. Read-only.

Dependencies: google-cloud-storage  (pip install -r requirements.txt)
"""

from __future__ import annotations

import argparse
import csv
import json
import sys

from google.api_core import exceptions
from google.auth import exceptions as auth_exceptions
from google.cloud import storage

PUBLIC_MEMBERS = frozenset(("allUsers", "allAuthenticatedUsers"))

COLUMNS = (
    "project_id",
    "bucket",
    "location",
    "uniform_bucket_level_access",
    "public_access_prevention",
    "public",
    "hardened",
    "error",
)


def audit_bucket(bucket) -> dict:
    project = bucket.project
    iam_config = getattr(bucket, "iam_configuration", {}) or {}

    uniform = bool(
        (iam_config.get("uniformBucketLevelAccess") or {}).get("enabled", False)
    )
    pap = iam_config.get("publicAccessPrevention", "unspecified")

    try:
        policy = bucket.get_iam_policy()
    except (exceptions.Forbidden, exceptions.NotFound, exceptions.PermissionDenied) as exc:
        return {
            "project_id": project,
            "bucket": bucket.name,
            "location": getattr(bucket, "location", ""),
            "uniform_bucket_level_access": uniform,
            "public_access_prevention": pap,
            "public": None,
            "hardened": False,
            "error": str(exc),
        }

    public = any(
        member in PUBLIC_MEMBERS
        for binding in policy.bindings
        for member in binding.get("members", [])
    )

    hardened = uniform and pap == "enforced" and not public

    return {
        "project_id": project,
        "bucket": bucket.name,
        "location": getattr(bucket, "location", ""),
        "uniform_bucket_level_access": uniform,
        "public_access_prevention": pap,
        "public": public,
        "hardened": hardened,
        "error": "",
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
        description="Audit Cloud Storage bucket security configuration.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--project", help="GCP project ID (defaults to application credentials)")
    parser.add_argument("--bucket", action="append", help="Restrict to specific bucket(s); repeatable")
    parser.add_argument("--only-hardened", action="store_true", help="Report only fully hardened buckets")
    parser.add_argument("--format", choices=("csv", "json"), default="csv", help="Report format")
    parser.add_argument("--output-file", help="Write report to file instead of stdout")
    args = parser.parse_args()

    try:
        client = storage.Client(project=args.project)
        buckets = list(client.list_buckets(project=args.project))
    except auth_exceptions.DefaultCredentialsError as exc:
        print(f"Error: no application default credentials found ({exc}).", file=sys.stderr)
        return 2
    except (exceptions.Forbidden, exceptions.PermissionDenied) as exc:
        print(f"Error: insufficient permission to list buckets ({exc}).", file=sys.stderr)
        return 2

    if args.bucket:
        requested = set(args.bucket)
        buckets = [b for b in buckets if b.name in requested]
        missing = requested - {b.name for b in buckets}
        if missing:
            print(f"Warning: bucket(s) not found: {', '.join(sorted(missing))}", file=sys.stderr)

    rows = [audit_bucket(bucket) for bucket in buckets]
    if args.only_hardened:
        rows = [row for row in rows if row["hardened"]]

    write_report(rows, args.format, args.output_file)
    hardened = sum(1 for r in rows if r["hardened"])
    print(f"Audited {len(buckets)} bucket(s), {hardened} fully hardened.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
