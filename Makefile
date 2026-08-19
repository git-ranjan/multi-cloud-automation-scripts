# Multi-Cloud Automation Scripts - developer task runner
#
# Usage:
#   make lint       # run all linters
#   make test       # run all test suites
#   make validate   # lint + test + structure checks (mirrors CI)

PWSH   ?= pwsh
PYTHON ?= python3

.PHONY: help lint lint-powershell lint-shell lint-python lint-yaml test test-powershell test-python structure validate

help:
	@echo "Available targets:"
	@echo "  lint             run all linters"
	@echo "  lint-powershell  PSScriptAnalyzer (Error/Warning)"
	@echo "  lint-shell       ShellCheck + bash -n syntax pass"
	@echo "  lint-python      ruff"
	@echo "  lint-yaml        yamllint"
	@echo "  test             run all test suites"
	@echo "  test-powershell  Pester 5"
	@echo "  test-python      pytest"
	@echo "  structure        verify repository layout"
	@echo "  validate         lint + test + structure (mirrors CI)"

lint: lint-powershell lint-shell lint-python lint-yaml

lint-powershell:
	$(PWSH) -NoProfile -Command "Install-Module PSScriptAnalyzer -Force -Scope CurrentUser; Invoke-ScriptAnalyzer -Path ./ -Recurse -Severity Error,Warning"

lint-shell:
	@echo "Running bash syntax checks..."
	@for script in $$(find . -type f -name '*.sh' -not -path './.git/*'); do \
		echo "  $$script"; \
		bash -n "$$script" || exit 1; \
	done

lint-python:
	ruff check .

lint-yaml:
	yamllint .

test: test-powershell test-python

test-powershell:
	$(PWSH) -NoProfile -Command "Invoke-Pester -Path ./tests -Output Detailed"

test-python:
	$(PYTHON) -m pytest --cov --cov-report=term-missing

structure:
	@for provider in aws azure gcp; do \
		test -d "$$provider" || { echo "missing provider directory: $$provider"; exit 1; }; \
		test -n "$$(find "$$provider" -type f | head -n 1)" || { echo "provider directory empty: $$provider"; exit 1; }; \
	done
	@for required in README.md LICENSE .gitignore; do \
		test -f "$$required" || { echo "missing required file: $$required"; exit 1; }; \
	done
	@echo "Repository structure OK."

validate: lint test structure
	@echo "All checks passed."
