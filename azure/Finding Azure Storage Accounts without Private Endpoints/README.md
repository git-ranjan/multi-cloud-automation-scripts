# Azure Storage Accounts Without Private Endpoints

This repository contains scripts to identify Azure Storage Accounts that don't have Private Endpoints configured, helping you audit your security posture.

## Features

- Lists all storage accounts without private endpoints
- Supports multiple subscriptions
- Output formats: Table, JSON, CSV
- Azure CLI and PowerShell implementations

## Prerequisites

- Azure CLI (`az`) or Azure PowerShell (`Az` module)
- Azure account with at least **Reader** permissions
- [Resource Graph](https://docs.microsoft.com/en-us/azure/governance/resource-graph/) extension for cross-subscription queries (optional)

## Installation

```bash
# For Azure CLI users
az extension add --name resource-graph

# For PowerShell users
Install-Module -Name Az -Scope CurrentUser -Force
Import-Module Az