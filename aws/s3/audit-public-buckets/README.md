# Audit S3 Buckets For Public Accessibility

Identify and report on S3 buckets that are publicly reachable across any of the
three exposure vectors: Public Access Block, bucket policy, and ACL grants.
Helps enforce the [AWS Well-Architected](https://aws.amazon.com/architecture/well-architected/)
and [S3 security best practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html).

---

## Files in this Module

| File Name | Language / Type | Description |
| :--- | :--- | :--- |
| [`audit_public_buckets.py`](audit_public_buckets.py) | Python (`boto3`) | Full audit with per-region clients, CSV/JSON export, `--only-public` filter. |
| [`audit-public-buckets.sh`](audit-public-buckets.sh) | Bash / AWS CLI | CLI-first audit with `jq`, table or JSON output. |

---

## Detection Logic

A bucket is flagged **public** when any of the following is true:

1. **Public Access Block** is not fully enabled (all four settings must be on;
   a missing configuration is treated as unblocked legacy behavior).
2. **Bucket policy** status reports `IsPublic = true`.
3. **ACL** grants access to `AllUsers` or `AuthenticatedUsers`.

---

## Quick Start

### Python (boto3)

```bash
pip install -r ../../requirements.txt

# Report every bucket to a CSV (read-only)
python audit_public_buckets.py --output-file report.csv

# Only buckets flagged public, as JSON
python audit_public_buckets.py --only-public --format json --output-file public_buckets.json

# Restrict to specific buckets or use a named profile
python audit_public_buckets.py --bucket prod-data --profile security-audit
```

### Bash / AWS CLI

```bash
# Table output on stdout
./audit-public-buckets.sh table

# JSON report to file
./audit-public-buckets.sh json public_buckets.json
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
                "s3:GetBucketPolicyStatus",
                "s3:GetBucketAcl",
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
