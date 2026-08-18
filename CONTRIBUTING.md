# Contributing to Multi-Cloud Automation Scripts

Thank you for your interest in contributing. This project is a skills-focused
showcase of multi-cloud operational, security governance, and compliance
automation — contributions that improve quality, coverage, and documentation
are welcome.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [How Can I Contribute?](#how-can-i-contribute)
3. [Development Workflow](#development-workflow)
4. [Coding Standards](#coding-standards)
5. [Testing](#testing)
6. [Documentation](#documentation)
7. [Commit Message Guidelines](#commit-message-guidelines)
8. [Pull Request Process](#pull-request-process)

## Code of Conduct

This project and everyone participating in it is governed by the
[Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to
uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report, search the existing issues to avoid duplicates.
When you do create one, include:

- The script/language and the exact command run
- Expected vs. actual behavior
- Full error output and any sanitized report excerpts
- Environment details (OS, module/tool versions)

### Suggesting Features

Feature requests are welcome. Please explain the problem you are trying to
solve, not just the feature you want. New modules should follow the existing
module structure (see [Repository Architecture](#repository-architecture)).

### Adding a New Module

Each module lives under a cloud provider directory and ships the same shape:

```
<provider>/<service>/<module-name>/
├── README.md                 # usage, permissions, and detection logic
├── <script>.py or .ps1       # primary implementation
├── <script>.sh               # CLI implementation
└── <query>.kql (Azure only)  # Resource Graph query
```

Mirror an existing module (for example `aws/s3/audit-public-buckets/`) rather
than inventing a new structure.

## Development Workflow

1. Branch off `develop` (never work directly on `main`).
2. Use a descriptive branch name: `feat/<provider>-<description>` or
   `fix/<provider>-<description>`.
3. Open a Pull Request against `develop`.
4. All checks in the CI pipeline must pass before merging.

## Coding Standards

### All Languages

- Scripts must be **strictly read-only** (no mutation of cloud resources).
- Fail fast with actionable error messages; never swallow failures silently.
- Support non-interactive execution (service principal / workload identity) for
  CI automation.
- No secrets, keys, or account identifiers in code or committed reports.

### PowerShell

- Include comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`,
  `.EXAMPLE`).
- Use `Set-StrictMode -Version Latest` at the top of the script.
- Pass `Invoke-ScriptAnalyzer` with `-Severity Error,Warning`.

### Bash

- Start with `#!/usr/bin/env bash` and use `set -euo pipefail`.
- Quote all variable expansions; pass ShellCheck.
- Read-only cloud commands only.

### Python

- Python 3.9+; pass `ruff check .` with the repo configuration.
- Use `if __name__ == "__main__":` guards and return exit codes from `main()`.
- Keep decision logic in small, testable functions.

### KQL (Azure Resource Graph)

- Target the `resources` table and project consistent column names.
- Guard against null fields with `isnull`/`tostring`.

## Testing

- PowerShell logic: Pester 5 tests under `tests/` (parse/structure-level where
  live credentials are unavailable).
- Python logic: pytest under `tests/` with mocked cloud clients.
- Every new module must ship tests; the CI pipeline runs them.

## Documentation

- Every module needs a `README.md` covering usage, permissions, and detection
  logic.
- Keep the root `README.md` architecture diagram in sync when adding modules.
- Update `CHANGELOG.md` under "Unreleased" for user-visible changes.

## Commit Message Guidelines

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>

<body (optional)>
```

Types: `feat`, `fix`, `docs`, `test`, `chore`, `ci`, `refactor`, `perf`.
Scope examples: `azure`, `aws`, `gcp`, `ci`, `docs`.

## Pull Request Process

1. Keep PRs focused on a single change.
2. Update the relevant documentation and tests in the same PR.
3. Reference any related issue in the PR description.
4. Ensure CI is green; maintainers may request changes for code quality.
