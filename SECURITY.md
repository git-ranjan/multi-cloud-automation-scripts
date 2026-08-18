# Security Policy

## Supported Versions

This repository is maintained as a rolling showcase. The `main` branch and the
latest release are actively supported. Older release tags receive security
fixes on a best-effort basis.

| Version | Supported |
| :--- | :--- |
| main / latest release | Supported |
| previous releases | Best effort |

## Reporting a Vulnerability

Security issues should be reported privately, not through public issues.

- Use GitHub's **private vulnerability reporting** on this repository
  (Security tab → Report a vulnerability).
- Alternatively, email the maintainer at the address listed on the GitHub
  profile for this repository.

Please include:

- The affected script(s) and cloud provider
- A description of the issue and its potential impact
- Steps to reproduce, sanitized of any real account identifiers or secrets

You should receive an acknowledgment within 5 business days. We ask that you
do not disclose the issue publicly until a fix has been released.

## Security Model

All scripts in this repository are designed to be:

- **Read-only** — they never create, modify, or delete cloud resources.
- **Least privilege** — they document the minimum granular permissions needed.
- **Credential safe** — they rely on standard authenticated SDK/CLI sessions and
  never accept, store, or log credentials or secrets.

If you believe a script violates any of these principles, report it as a
security vulnerability.