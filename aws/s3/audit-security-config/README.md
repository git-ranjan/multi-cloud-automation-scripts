# Audit S3 Bucket Security Configuration

Report the state of the foundational S3 hardening controls across all buckets
in an account and flag buckets that are **fully hardened**.

---

## Files in this Module

| File Name | Language / Type | Description |
| :--- | :--- | :--- |
| [`audit_bucket_security.py`](audit_bucket_security.py) | Python (`boto3`) | Full audit matrix with per-region clients, CSV/JSON export, `--only-hardened` filter. |
| [`audit-security-config.sh`](audit-security-config.sh) | Bash / AWS CLI | CLI-first audit with `jq`, table or JSON output. |

---

## Controls Evaluated

| Control | Description |
| :--- | :--- |
| **Public Access Block** | All four settings (`BlockPublicAcls`, `IgnorePublicAcls`, `BlockPublicPolicy`, `RestrictPublicBuckets`) must be enabled. |
| **Default encryption** | SSE-S3 or SSE-KMS configured at the bucket level. |
| **Versioning** | Bucket versioning must be `Enabled`. |

A bucket is reported as **hardened** only when all three controls are in place.

---

## Quick Start

### Python (boto3)

```bash
pip install -r ../../requirements.txt

# Full compliance matrix to CSV
python audit_bucket_security.py --output-file compliance.csv

# Only fully hardened buckets, JSON output
python audit_bucket_security.py --only-hardened --format json --output-file hardened.json
```

### Bash / AWS CLI

```bash
# Table output on stdout
./audit-security-config.sh table

# JSON report to file
./audit-security-config.sh json compliance.json
```

---

## Permissions

Read-only access is sufficient. Inline policy example:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets",
                "s3:GetBucketPublicAccessBlock",
                "s3:GetBucketEncryption",
                "s3:GetBucketVersioning",
                "s3:GetBucketLocation"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "sts:GetCallerIdentity",
            "Resource": "*"
        }
    ]
}
```