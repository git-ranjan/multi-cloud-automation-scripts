# Multi-Cloud Automation Scripts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/git-ranjan/multi-cloud-automation-scripts/actions/workflows/ci.yml/badge.svg)](.github/workflows/ci.yml)
[![Azure](https://img.shields.io/badge/Provider-Microsoft%20Azure-blue.svg)](https://azure.microsoft.com/)
[![AWS](https://img.shields.io/badge/Provider-Amazon%20Web%20Services-orange.svg)](https://aws.amazon.com/)
[![GCP](https://img.shields.io/badge/Provider-Google%20Cloud-4285F4.svg)](https://cloud.google.com/)
[![PowerShell](https://img.shields.io/badge/Language-PowerShell-5391FE.svg)](https://learn.microsoft.com/en-us/powershell/)
[![Bash](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![Python](https://img.shields.io/badge/Language-Python-3776AB.svg)](https://www.python.org/)
[![KQL](https://img.shields.io/badge/Language-KQL-0078D4.svg)](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/)
[![Sponsor](https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-ea4aaa.svg)](https://github.com/sponsors/git-ranjan)

A collection of operational and security automation scripts for **Microsoft Azure**,
**Amazon Web Services**, and **Google Cloud**. Mostly read-only audit utilities:
they discover storage and networking exposure, flag misconfiguration, and export
findings to CSV/JSON so teams can act on them. Geared toward Cloud Engineers,
DevOps teams, and Security Auditors who want a second pair of eyes on storage
configurations without writing bespoke tooling.

---

## Repository Architecture

```text
multi-cloud-automation-scripts/
├── .github/
│   ├── ISSUE_TEMPLATE/               # Bug & feature templates
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── CODEOWNERS
│   ├── dependabot.yml                # Automated dependency updates
│   └── workflows/
│       └── ci.yml                    # Lint + test pipeline
├── aws/
│   └── s3/
│       ├── audit-public-buckets/         # S3 public exposure detection
│       └── audit-security-config/        # S3 hardening compliance matrix
├── azure/
│   └── storage/
│       ├── audit-private-endpoints/      # Storage accounts WITH Private Endpoints
│       └── audit-missing-private-endpoints/  # Storage accounts WITHOUT Private Endpoints
├── gcp/
│   └── storage/
│       ├── audit-public-buckets/         # GCS public IAM exposure detection
│       └── audit-security-config/        # GCS hardening compliance matrix
├── tests/                            # Pester (PowerShell) + pytest (Python)
├── CONTRIBUTING.md
├── SECURITY.md
├── CHANGELOG.md
├── LICENSE
├── Makefile                          # make lint / test / validate
└── README.md
```

---

## Available Modules

### Microsoft Azure

| Module | Description | Formats |
| :--- | :--- | :--- |
| **[Audit Private Endpoints](azure/storage/audit-private-endpoints/)** | Discover and report storage accounts secured with Private Endpoints across subscriptions. | PowerShell, Bash, KQL |
| **[Audit Missing Private Endpoints](azure/storage/audit-missing-private-endpoints/)** | Identify publicly exposed or unlinked storage accounts to mitigate security risk. | PowerShell, Bash, KQL |

### Amazon Web Services

| Module | Description | Formats |
| :--- | :--- | :--- |
| **[Audit Public Buckets](aws/s3/audit-public-buckets/)** | Detect S3 buckets reachable via Public Access Block, bucket policy, or ACL exposure. | Python, Bash |
| **[Audit Security Config](aws/s3/audit-security-config/)** | Compliance matrix for Public Access Block, default encryption, and versioning. | Python, Bash |

### Google Cloud

| Module | Description | Formats |
| :--- | :--- | :--- |
| **[Audit Public Buckets](gcp/storage/audit-public-buckets/)** | Detect GCS buckets with public IAM bindings (`allUsers` / `allAuthenticatedUsers`). | Python, Bash |
| **[Audit Security Config](gcp/storage/audit-security-config/)** | Compliance matrix for uniform bucket-level access, public access prevention, and public bindings. | Python, Bash |

---

## Quick Start

### Azure

```powershell
# PowerShell (Az module)
.\azure\storage\audit-private-endpoints\audit-storage-with-pe.ps1 -OutputPath "PE_Report.csv"
.\azure\storage\audit-missing-private-endpoints\audit-storage-without-pe.ps1 -ExportFormat JSON -OutputPath "Exposed_Storage.json"
```

```bash
# Bash / Azure CLI (requires resource-graph extension)
./azure/storage/audit-missing-private-endpoints/audit-storage-without-pe.sh json report.json
```

```kql
// Azure Resource Graph Explorer
resources
| where type =~ 'microsoft.storage/storageaccounts'
| extend peCount = array_length(properties.privateEndpointConnections)
| where peCount == 0 or isnull(peCount)
| project subscriptionId, resourceGroup, name, publicNetworkAccess = tostring(properties.publicNetworkAccess)
```

### AWS

```bash
pip install -r aws/requirements.txt

# Python (boto3)
python aws/s3/audit-public-buckets/audit_public_buckets.py --only-public --format json --output-file public.json
python aws/s3/audit-security-config/audit_bucket_security.py --output-file compliance.csv

# Bash / AWS CLI
./aws/s3/audit-public-buckets/audit-public-buckets.sh json public.json
```

### GCP

```bash
pip install -r gcp/requirements.txt

# Python (google-cloud-storage)
python gcp/storage/audit-public-buckets/audit_public_buckets.py --project my-project --only-public --output-file public.csv
python gcp/storage/audit-security-config/audit_bucket_security.py --output-file compliance.csv

# Bash / gcloud + gsutil
GCP_PROJECT=my-project ./gcp/storage/audit-security-config/audit-security-config.sh json compliance.json
```

---

## Security & Best Practices

All scripts follow the cloud provider security benchmarks and the Well-Architected
frameworks (Azure Security Benchmark, AWS Well-Architected, Google Cloud
security best practices):

- **Least Privilege Access**: each module documents the minimum granular read
  permissions required.
- **Cross-Subscription / Cross-Account Support**: handles multi-subscription and
  multi-account enterprise environments.
- **Non-Destructive Operations**: all audit scripts operate strictly in
  read-only mode.
- **Automation Ready**: every module supports non-interactive execution
  (service principal / workload identity / application default credentials).

---

## Automated CI/CD

Every commit and pull request is validated against:

- **PSScriptAnalyzer** — PowerShell code quality and security standards
- **Pester 5** — PowerShell test execution
- **ShellCheck + `bash -n`** — Bash reliability and POSIX compliance
- **ruff** — Python linting and import sorting
- **pytest** — Python unit tests (mocked cloud clients)
- **markdownlint-cli2** — documentation formatting
- **yamllint** — workflow/configuration validation
- **Structure checks** — repository layout invariants

## Local Development

```bash
make lint       # run all linters
make test       # run all test suites
make validate   # lint + test + structure (mirrors CI)
```

Optionally install [pre-commit](https://pre-commit.com/) for local hook-based
checks. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for contribution guidelines.

---

## Support & Sponsorship

If you find these multi-cloud automation scripts helpful, consider supporting
the project:

[![Sponsor git-ranjan](https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-ea4aaa.svg?style=for-the-badge&logo=github)](https://github.com/sponsors/git-ranjan)

---

## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.
