# AWS S3 Security & Governance

Companion modules to the Azure storage auditing suite, applied to Amazon S3.

| Module | Description | Formats |
| :--- | :--- | :--- |
| **[Audit Public Buckets](audit-public-buckets/)** | Detect S3 buckets reachable via Public Access Block, bucket policy, or ACL exposure. | Python, Bash |
| **[Audit Security Config](audit-security-config/)** | Compliance matrix for Public Access Block, default encryption, and versioning. | Python, Bash |

## Dependencies

- **Python**: `pip install -r aws/requirements.txt` (boto3)
- **Bash**: AWS CLI (`aws`) and `jq`

## Security Model

All scripts are read-only and require only the granular read permissions listed
in each module's README. They follow AWS Well-Architected security guidance.
