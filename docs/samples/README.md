# Sample Audit Reports

Illustrative, redacted outputs produced by the audit modules. The account IDs,
subscription IDs, bucket names, and project IDs here are **fabricated** — they
exist so you can see the report shape before running anything against your own
environment.

| Sample File | Produced By | Format |
| :--- | :--- | :--- |
| [`aws-public-buckets.csv`](aws-public-buckets.csv) | `aws/s3/audit-public-buckets/` | CSV |
| [`aws-public-buckets.json`](aws-public-buckets.json) | `aws/s3/audit-public-buckets/` | JSON |
| [`aws-security-config.csv`](aws-security-config.csv) | `aws/s3/audit-security-config/` | CSV |
| [`gcp-public-buckets.csv`](gcp-public-buckets.csv) | `gcp/storage/audit-public-buckets/` | CSV |
| [`gcp-security-config.csv`](gcp-security-config.csv) | `gcp/storage/audit-security-config/` | CSV |
| [`azure-missing-private-endpoints.csv`](azure-missing-private-endpoints.csv) | `azure/storage/audit-missing-private-endpoints/` | CSV |

## Reading the Findings

Every module exposes a boolean "finding" flag as the signal you act on:

- **AWS**: `is_public` (public buckets) and `hardened` (security config).
- **GCP**: `public` (public IAM exposure) and `hardened` (security config).
- **Azure**: `PrivateEndpointCount` equal to `0` on the missing-private-endpoints
  report.

Rows where the finding flag is `true` (or the count is `0` in the Azure case) are
the ones worth opening a ticket for.

## Generating Real Reports

Point each module at your environment to produce the same shape with live data.
The Quick Start sections in the module READMEs show the exact commands:

```bash
# AWS - public bucket exposure
python aws/s3/audit-public-buckets/audit_public_buckets.py --only-public --format csv

# GCP - security configuration
python gcp/storage/audit-security-config/audit_bucket_security.py --project my-project

# Azure - missing private endpoints
./azure/storage/audit-missing-private-endpoints/audit-storage-without-pe.ps1 -OutputPath exposed.csv
```

For the full field-by-field contract, see [`../report-format.md`](../report-format.md).
