# Finding Azure Storage Accounts with Private Endpoints

To generate a report of Azure Storage Accounts that have private endpoints configured, you have several options:

---

## Option 1: Using Azure Portal
- Navigate to the [Azure Portal](https://portal.azure.com)
- Go to **All resources**
- Filter by **Storage accounts**
- You can add a column for **Private endpoint connections** or look for the lock icon indicating private access

---

## Option 2: Using Azure PowerShell
- Use Azure PowerShell cmdlets to query storage accounts and their private endpoints 

---

## Option 3: Using Azure PowerShell in Cloud Shell
- Open Azure Cloud Shell (https://shell.azure.com)
- Choose PowerShell as the environment.
- Run the scripts with .ps1 extensions to list storage accounts with private endpoints and export to CSV.
   ## How to Access the Report in Cloud Shell
    - The report is saved in your Cloud Shell's attached storage (clouddrive).
    - To download it:
        - Click the "Upload/Download" button in Cloud Shell.
        - Select Download and choose the generated file (PrivateEndpointStorageReport.csv or storage_private_endpoints.json).

---

## Option 4: Using Azure CLI
- Use Azure CLI commands to list storage accounts with private endpoint connections. You can use the commands listed in the .cmd files.

---

## Option 5: Using Azure Resource Graph Explorer
- Use Kusto Query Language (KQL) queries in Azure Resource Graph Explorer to find storage accounts with private endpoints. Those are listed in .kql files. Also, you can use KQL queries with Azure CLI, this is listed in one of the .cmd file.

---

## Option 6: Azure Storage REST API
- You can also use the Azure Storage REST API to programmatically get private endpoint connections information

---

## Report Customization

For more detailed reports, consider including:

- Subscription name  
- Private endpoint names and IDs  
- Private endpoint connection status  
- Virtual Network (VNET) information for each private endpoint  
- Creation dates  

---
