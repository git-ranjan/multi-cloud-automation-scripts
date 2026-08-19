# Report Format

Every audit module in this repository writes machine-readable reports in CSV or
JSON, so findings can be diffed, imported into a dashboard, or piped into a
remediation pipeline regardless of which cloud produced them.

This document is the contract. If a module ever diverges from it, that is a bug.

## Common Conventions

- **Formats**: every module supports `csv` and `json` output (Azure modules
  default to CSV and accept `-ExportFormat JSON`).
- **Finding flag**: each report includes a boolean column that marks the rows you
  should act on. Name it consistently per module:
  - `is_public` — AWS public bucket exposure.
  - `hardened` — AWS and GCP security configuration.
  - `public` — GCP public IAM exposure.
  - `PrivateEndpointCount` — Azure; a value of `0` is the finding.
- **Empty fields**: Python modules emit an empty string for unset values; the GCP
  modules also carry an `error` column for per-bucket failures so one broken
  bucket never aborts the audit.
- **Summaries go to stderr**: a one-line human summary ("Audited N bucket(s), M
  flagged public.") is written to stderr, keeping stdout clean for automation.
- **Non-destructive**: no module creates, modifies, or deletes resources.

## AWS

### S3 Public Buckets — `aws/s3/audit-public-buckets/`

| Column | Meaning |
| :--- | :--- |
| `account_id` | AWS account identifier. |
| `bucket` | Bucket name. |
| `region` | Bucket region. |
| `public_access_block_enabled` | True only when all four PAB settings are enabled. |
| `policy_public` | True when the bucket policy status is `IsPublic`. |
| `acl_public` | True when an ACL grant targets AllUsers / AuthenticatedUsers. |
| `acl_public_permissions` | Comma-joined public ACL permissions (e.g. `READ`). |
| `is_public` | **Finding** — True when any exposure vector is present. |

### S3 Security Config — `aws/s3/audit-security-config/`

| Column | Meaning |
| :--- | :--- |
| `account_id`, `bucket`, `region` | Identity columns (see above). |
| `public_access_block_enabled` | True only when all four PAB settings are enabled. |
| `default_encryption` | True when SSE-S3 or SSE-KMS is configured. |
| `encryption_type` | `AES256`, `aws:kms (key ARN)`, or `NONE`. |
| `versioning_enabled` | True when bucket versioning is `Enabled`. |
| `hardened` | **Finding** — True only when all three controls are in place. |

## GCP

### Cloud Storage Public Buckets — `gcp/storage/audit-public-buckets/`

| Column | Meaning |
| :--- | :--- |
| `project_id` | GCP project identifier. |
| `bucket` | Bucket name. |
| `location` | Bucket location (e.g. `us-east1`). |
| `storage_class` | Bucket storage class. |
| `public` | **Finding** — True when a public IAM binding exists. |
| `public_roles` | Comma-joined roles granted to public members. |
| `public_members` | Comma-joined public members (`allUsers`, `allAuthenticatedUsers`). |
| `error` | Per-bucket error message, empty on success. |

### Cloud Storage Security Config — `gcp/storage/audit-security-config/`

| Column | Meaning |
| :--- | :--- |
| `project_id`, `bucket`, `location` | Identity columns (see above). |
| `uniform_bucket_level_access` | True when UBLA is enabled. |
| `public_access_prevention` | `enforced`, `inherited`, or `unspecified`. |
| `public` | True when a public IAM binding exists. |
| `hardened` | **Finding** — True only when UBLA is on, PAP is enforced, and no public bindings exist. |
| `error` | Per-bucket error message, empty on success. |

## Azure

### Storage Without Private Endpoints — `azure/storage/audit-missing-private-endpoints/`

| Column | Meaning |
| :--- | :--- |
| `SubscriptionId` | Azure subscription identifier. |
| `SubscriptionName` | Subscription display name. |
| `ResourceGroupName` | Resource group containing the account. |
| `StorageAccountName` | Storage account name. |
| `Location` | Account region. |
| `SKU` | Replication tier (e.g. `Standard_LRS`). |
| `PublicNetworkAccess` | `Enabled`, `Disabled`, or `Unknown`. |
| `AllowBlobPublicAccess` | Whether anonymous blob access is permitted. |
| `MinTlsVersion` | Minimum TLS version (e.g. `TLS1_2`). |
| `RequireSecureTransfer` | Whether HTTPS-only is enforced. |
| `PrivateEndpointCount` | **Finding** — `0` means no private endpoint is linked. |

Azure uses PascalCase column names (PowerShell `Export-Csv` convention); the
Python modules use snake_case. Column names otherwise follow the same contract.
