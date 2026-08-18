# Audit Cloud Storage Buckets For Public IAM Exposure

Identify buckets in a project with IAM bindings that grant access to
`allUsers` (anonymous access) or `allAuthenticatedUsers` (any authenticated
Google identity) — a leading cause of unintended public data exposure.

Aligns with the [GCP security best practices](https://cloud.google.com/storage/docs/using-public-access-prevention).

---

## Files in this Module

| File Name | Language / Type | Description |
| :--- | :--- | :--- |
| [`audit_public_buckets.py`](audit_public_buckets.py) | Python (`google-cloud-storage`) | Full audit with CSV/JSON export, `--only-public` filter. |
| [`audit-public-buckets.sh`](audit-public-buckets.sh) | Bash / `gsutil` | CLI-first audit with `jq`, table or JSON output. |

---

## Detection Logic

For every bucket the IAM policy is inspected. A bucket is flagged **public**
when any binding contains one of:

- `allUsers` — anonymous, unauthenticated access
- `allAuthenticatedUsers` — any authenticated Google identity

The affected roles (e.g. `roles/storage.objectViewer`) are reported for triage.

---

## Quick Start

### Python

```bash
pip install -r ../../requirements.txt

# Audit the default project to CSV
python audit_public_buckets.py --output-file report.csv

# Only public buckets as JSON, explicit project
python audit_public_buckets.py --project my-project --only-public --format json --output-file public.json
```

### Bash / gsutil

```bash
# Table output on stdout
./audit-public-buckets.sh table

# JSON report to file for a specific project
GCP_PROJECT=my-project ./audit-public-buckets.sh json public.json
```

---

## Permissions

The service account or user must be able to list buckets and read IAM policies
at the project level, e.g. `storage.buckets.getIamPolicy` and
`storage.buckets.list`. Read-only roles such as **Storage Object Viewer** with
project-level list access are sufficient.