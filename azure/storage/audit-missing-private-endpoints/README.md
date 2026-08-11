# Audit Azure Storage Accounts Without Private Endpoints

Identify, audit, and report on Azure Storage Accounts that **DO NOT** have Private Endpoints configured, helping you audit public exposure and enforce networking compliance.

---

## Files in this Module

| File Name | Language / Type | Description |
| :--- | :--- | :--- |
| [`audit-storage-without-pe.ps1`](audit-storage-without-pe.ps1) | PowerShell (`Az` module) | Multi-subscription PowerShell script exporting CSV/JSON reports. |
| [`audit-storage-without-pe.sh`](audit-storage-without-pe.sh) | Bash / Azure CLI | Shell script utilizing `az graph query` for fast cross-subscription reporting. |
| [`audit-storage-without-pe.kql`](audit-storage-without-pe.kql) | Kusto Query Language | KQL query for Azure Resource Graph Explorer. |

---

## Quick Start

### 1. Azure PowerShell (`.ps1`)
```powershell
# Audit all subscriptions for exposed storage accounts and export to CSV
.\audit-storage-without-pe.ps1 -OutputPath "ExposedStorageAccounts.csv"

# Audit a specific subscription and export to JSON
.\audit-storage-without-pe.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000" -ExportFormat JSON -OutputPath "ExposedStorage.json"
```

### 2. Azure CLI / Bash (`.sh`)
```bash
# Output results directly as a table
./audit-storage-without-pe.sh table

# Output results as JSON and save to file
./audit-storage-without-pe.sh json exposed_report.json
```

### 3. Azure Resource Graph Explorer (`.kql`)
Paste the contents of [`audit-storage-without-pe.kql`](audit-storage-without-pe.kql) into [Azure Resource Graph Explorer](https://portal.azure.com/#blade/HubsExtension/BrowseResourceBlade/resourceType/Microsoft.ResourceGraph%2Fqueries).
