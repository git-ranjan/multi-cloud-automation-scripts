# Audit Azure Storage Accounts With Private Endpoints

Identify, audit, and report on Azure Storage Accounts configured with **Private Endpoints** across your Azure tenant.

---

## Files in this Module

| File Name | Language / Type | Description |
| :--- | :--- | :--- |
| [`audit-storage-with-pe.ps1`](audit-storage-with-pe.ps1) | PowerShell (`Az` module) | Multi-subscription PowerShell script exporting CSV/JSON reports. |
| [`audit-storage-with-pe.sh`](audit-storage-with-pe.sh) | Bash / Azure CLI | Shell script utilizing `az graph query` for fast cross-subscription reporting. |
| [`audit-storage-with-pe.kql`](audit-storage-with-pe.kql) | Kusto Query Language | KQL query for Azure Resource Graph Explorer. |

---

## Quick Start

### 1. Azure PowerShell (`.ps1`)
```powershell
# Audit all subscriptions and export to CSV
.\audit-storage-with-pe.ps1 -OutputPath "PrivateEndpointStorageReport.csv"

# Audit a specific subscription and export to JSON
.\audit-storage-with-pe.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000" -ExportFormat JSON -OutputPath "Report.json"
```

### 2. Azure CLI / Bash (`.sh`)
```bash
# Output results directly as a table
./audit-storage-with-pe.sh table

# Output results as JSON and save to file
./audit-storage-with-pe.sh json pe_report.json
```

### 3. Azure Resource Graph Explorer (`.kql`)
Paste the contents of [`audit-storage-with-pe.kql`](audit-storage-with-pe.kql) into [Azure Resource Graph Explorer](https://portal.azure.com/#blade/HubsExtension/BrowseResourceBlade/resourceType/Microsoft.ResourceGraph%2Fqueries).
