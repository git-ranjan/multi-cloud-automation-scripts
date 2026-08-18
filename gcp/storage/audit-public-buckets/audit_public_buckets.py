#!/usr/bin/env python3
"""Audit Cloud Storage buckets for public IAM exposure.

Checks every bucket in a project for IAM bindings that grant access to
allUsers (anonymous) or allAuthenticatedUsers (any authenticated Google
identity), which makes the bucket publicly readable or writable.

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
    "storage_class",
    "public",
    "public_roles",
    "public_members",
    "error",
)


def audit_bucket(bucket) -> dict:
    project = bucket.project
    try:
        policy = bucket.get_iam_policy()
    except (exceptions.Forbidden, exceptions.NotFound, exceptions.PermissionDenied) as exc:
        return {
            "project_id": project,
            "bucket": bucket.name,
            "location": getattr(bucket, "location", ""),
            "storage_class": getattr(bucket, "storage_class", ""),
            "public": None,
            "public_roles": "",
            "public_members": "",
            "error": str(exc),
        }

    public_bindings = []
    for binding in policy.bindings:
        members = binding.get("members", [])
        exposed = sorted(member for member in members if member in PUBLIC_MEMBERS)
        if exposed:
            public_bindings.append({"role": binding.get("role", ""), "members": exposed})

    public = bool(public_bindings)
    return {
        "project_id": project,
        "bucket": bucket.name,
        "location": getattr(bucket, "location", ""),
        "storage_class": getattr(bucket, "storage_class", ""),
        "public": public,
        "public_roles": ",".join(b["role"] for b in public_bindings),
        "public_members": ",".join(
            member for b in public_bindings for member in b["members"]
        ),
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
        description="Audit Cloud Storage buckets for public IAM exposure.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--project", help="GCP project ID (defaults to application credentials)")
    parser.add_argument("--bucket", action="append", help="Restrict to specific bucket(s); repeatable")
    parser.add_argument("--only-public", action="store_true", help="Report only public buckets")
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
    if args.only_public:
        rows = [row for row in rows if row["public"]]

    write_report(rows, args.format, args.output_file)
    flagged = sum(1 for r in rows if r["public"])
    print(f"Audited {len(buckets)} bucket(s), {flagged} public.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
