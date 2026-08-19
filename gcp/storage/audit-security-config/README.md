# Audit Cloud Storage Bucket Security Configuration

Report the state of the foundational bucket hardening controls across a
project and flag buckets that are **fully hardened**.

---

## Files in this Module

| File Name | Language / Type | Description |
| :--- | :--- | :--- |
| [`audit_bucket_security.py`](audit_bucket_security.py) | Python (`google-cloud-storage`) | Full audit matrix with CSV/JSON export, `--only-hardened` filter. |
| [`audit-security-config.sh`](audit-security-config.sh) | Bash / `gcloud` + `gsutil` | CLI-first audit with `jq`, table or JSON output. |

---

## Controls Evaluated

| Control | Description |
| :--- | :--- |
| **Uniform bucket-level access** | Access governed solely by IAM (ACLs disabled). |
| **Public access prevention** | Must be `enforced` (not inherited/unspecified). |
| **Public IAM bindings** | No `allUsers` / `allAuthenticatedUsers` members. |

A bucket is reported as **hardened** only when all three controls are in place.

---

## Quick Start

### Python

```bash
pip install -r ../../requirements.txt

# Full compliance matrix to CSV
python audit_bucket_security.py --output-file compliance.csv

# Only fully hardened buckets, JSON output
python audit_bucket_security.py --project my-project --only-hardened --format json --output-file hardened.json
```

### Bash / gcloud + gsutil

```bash
# Table output on stdout
./audit-security-config.sh table

# JSON report to file for a specific project
GCP_PROJECT=my-project ./audit-security-config.sh json compliance.json
```

---

## Permissions

Read-only project-level access is sufficient: list buckets, read bucket IAM
policies, and read bucket metadata (e.g. **Storage Object Viewer** plus
`storage.buckets.list` and `storage.buckets.getIamPolicy`).
