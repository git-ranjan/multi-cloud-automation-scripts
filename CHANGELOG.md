# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **AWS** modules under `aws/s3/`:
  - `audit-public-buckets` — detect S3 buckets exposed via Public Access Block,
    bucket policy, or ACL grants (Python + Bash).
  - `audit-security-config` — compliance matrix for Public Access Block, default
    encryption, and versioning (Python + Bash).
- **GCP** modules under `gcp/storage/`:
  - `audit-public-buckets` — detect buckets with public IAM bindings
    (`allUsers` / `allAuthenticatedUsers`) (Python + Bash).
  - `audit-security-config` — compliance matrix for uniform bucket-level access,
    public access prevention, and public bindings (Python + Bash).
- **Azure** hardening:
  - PowerShell: multi-subscription targeting, cloud environment selection,
    `-NoAuthPrompt` CI mode, timestamped report output, and expanded compliance
    fields (TLS version, secure transfer, public network access).
  - Bash: paginated Azure Resource Graph export and single-subscription scoping.
  - KQL: null-safe fields and expanded security posture columns.
- **Testing**: Pester 5 suite for Azure modules; mocked pytest suites for the
  AWS and GCP modules.
- **CI**: full pipeline with PSScriptAnalyzer, ShellCheck + `bash -n`, ruff,
  Pester, pytest, markdownlint-cli2, yamllint, and repository structure checks.
- **Governance**: `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  issue and PR templates, `CODEOWNERS`, Dependabot, EditorConfig, pre-commit
  hooks, Makefile, and `.gitattributes`.

### Changed

- README restructured for multi-cloud coverage and usage examples.

## [0.1.0] - Initial Release

### Added

- Azure storage auditing modules:
  - `azure/storage/audit-private-endpoints` (PowerShell, Bash, KQL).
  - `azure/storage/audit-missing-private-endpoints` (PowerShell, Bash, KQL).
- CI linting workflow for PowerShell, Bash, and Markdown.
- MIT license, README, and GitHub Sponsors configuration.