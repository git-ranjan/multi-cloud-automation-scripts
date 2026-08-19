# GCP Cloud Storage Security & Governance

Companion modules to the Azure storage auditing suite, applied to Google Cloud Storage.

| Module | Description | Formats |
| :--- | :--- | :--- |
| **[Audit Public Buckets](audit-public-buckets/)** | Detect buckets with public IAM bindings (`allUsers` / `allAuthenticatedUsers`). | Python, Bash |
| **[Audit Security Config](audit-security-config/)** | Compliance matrix for uniform bucket-level access, public access prevention, and public bindings. | Python, Bash |

## Dependencies

- **Python**: `pip install -r gcp/requirements.txt` (google-cloud-storage)
- **Bash**: Google Cloud SDK (`gcloud`, `gsutil`) and `jq`

## Security Model

All scripts are read-only and require only the granular read permissions listed
in each module's README. They follow Google Cloud security best practices.
