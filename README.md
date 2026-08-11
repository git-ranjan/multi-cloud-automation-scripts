# Multi-Cloud Automation Scripts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Azure](https://img.shields.io/badge/Provider-Microsoft%20Azure-blue.svg)](https://azure.microsoft.com/)
[![PowerShell](https://img.shields.io/badge/Language-PowerShell-5391FE.svg)](https://learn.microsoft.com/en-us/powershell/)
[![Bash](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![KQL](https://img.shields.io/badge/Language-KQL-0078D4.svg)](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/)
[![Sponsor](https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-ea4aaa.svg)](https://github.com/sponsors/git-ranjan)
[![CI/CD](https://github.com/git-ranjan/multi-cloud-automation-scripts/actions/workflows/lint-and-validate.yml/badge.svg)](.github/workflows/lint-and-validate.yml)

An enterprise-grade collection of multi-cloud operational, security governance, and compliance automation scripts. Designed for Cloud Engineers, DevOps Teams, and Security Auditors to maintain robust security posture, automate infrastructure discovery, and enforce enterprise governance.

---

## 🏛️ Repository Architecture

```
multi-cloud-automation-scripts/
├── .github/
│   ├── FUNDING.yml                      # GitHub Sponsors Configuration
│   └── workflows/
│       └── lint-and-validate.yml        # CI/CD Script & Markdown Linting Workflow
├── azure/
│   └── storage/
│       ├── audit-private-endpoints/         # Audit Storage Accounts WITH Private Endpoints
│       │   ├── README.md
│       │   ├── audit-storage-with-pe.ps1    # PowerShell (Az Module) implementation
│       │   ├── audit-storage-with-pe.sh     # Bash / Azure CLI implementation
│       │   └── audit-storage-with-pe.kql    # Azure Resource Graph KQL query
│       └── audit-missing-private-endpoints/ # Audit Storage Accounts WITHOUT Private Endpoints
│           ├── README.md
│           ├── audit-storage-without-pe.ps1 # PowerShell (Az Module) implementation
│           ├── audit-storage-without-pe.sh  # Bash / Azure CLI implementation
│           └── audit-storage-without-pe.kql # Azure Resource Graph KQL query
├── .gitignore
├── LICENSE
└── README.md
```

---

## 🚀 Available Modules

### 🔍 Azure Storage Security & Governance

| Module | Description | Supported Formats |
| :--- | :--- | :--- |
| **[Audit Private Endpoints](azure/storage/audit-private-endpoints/)** | Discover and report on storage accounts secured with Private Endpoints across subscriptions. | PowerShell, Bash, KQL |
| **[Audit Missing Private Endpoints](azure/storage/audit-missing-private-endpoints/)** | Identify publicly exposed or unlinked storage accounts to mitigate security risk. | PowerShell, Bash, KQL |

---

## 💻 Quick Start & Usage Examples

### 1. Azure PowerShell (`.ps1`)
Ensure the Azure PowerShell module (`Az`) is installed:
```powershell
# Install Az module if not present
Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force

# Audit all accessible subscriptions and export to CSV
.\azure\storage\audit-private-endpoints\audit-storage-with-pe.ps1 -OutputPath "Storage_PE_Report.csv"

# Identify exposed storage accounts and export to JSON
.\azure\storage\audit-missing-private-endpoints\audit-storage-without-pe.ps1 -ExportFormat JSON -OutputPath "Exposed_Storage.json"
```

### 2. Azure CLI & Bash (`.sh`)
Ensure Azure CLI (`az`) and the `resource-graph` extension are installed:
```bash
# Add Azure Resource Graph extension
az extension add --name resource-graph

# Run audit for missing private endpoints (output as table)
./azure/storage/audit-missing-private-endpoints/audit-storage-without-pe.sh table

# Output as JSON and save report to disk
./azure/storage/audit-missing-private-endpoints/audit-storage-without-pe.sh json report.json
```

### 3. Azure Resource Graph Explorer (`.kql`)
Open **Azure Resource Graph Explorer** in the Azure Portal and run queries directly:
```kql
// Identify Storage Accounts lacking Private Endpoints
resources
| where type =~ 'microsoft.storage/storageaccounts'
| extend peConnections = properties.privateEndpointConnections
| extend peCount = array_length(peConnections)
| where peCount == 0 or isnull(peCount)
| project subscriptionId, resourceGroup, name, location, sku=sku.name, publicNetworkAccess=properties.publicNetworkAccess
```

---

## 🔒 Security & Best Practices

All scripts in this repository follow Microsoft Azure Security Benchmarks and Cloud Adoption Framework (CAF) guidelines:
- **Least Privilege Access**: Requires minimum `Reader` permission across targeted Azure subscriptions.
- **Cross-Subscription Support**: Handles multi-tenant and multi-subscription enterprise environments seamlessly.
- **Non-Destructive Operations**: All audit scripts operate strictly in read-only mode.

---

## 🛠️ Automated CI/CD Linting

Every commit and pull request is automatically validated against:
- **PSScriptAnalyzer** for PowerShell code quality and security standards.
- **ShellCheck** for Bash script reliability and POSIX compliance.
- **MarkdownLint** for documentation formatting.

---

## 💖 Support & Sponsorship

If you find these multi-cloud automation scripts helpful, consider supporting the project:

[![Sponsor git-ranjan](https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-ea4aaa.svg?style=for-the-badge&logo=github)](https://github.com/sponsors/git-ranjan)

---

## 📄 License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.
