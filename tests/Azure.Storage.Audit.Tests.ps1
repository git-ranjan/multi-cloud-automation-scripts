#requires -Version 5.1
# Pester 5.x tests validating the Azure Storage audit modules without
# requiring an Azure subscription (parse/structure-level coverage).

Describe 'Azure Storage audit module layout' {
    It 'exposes a README, PowerShell, Bash and KQL implementation for each module' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        foreach ($moduleName in @('audit-private-endpoints', 'audit-missing-private-endpoints')) {
            $dir = Join-Path $repoRoot "azure\storage\$moduleName"
            foreach ($file in @('README.md', '*.ps1', '*.kql', '*.sh')) {
                (Get-ChildItem -LiteralPath $dir -Filter $file -ErrorAction Stop).Count |
                    Should -BeGreaterThan 0
            }
        }
    }
}

Describe '<ModuleName> - static validation' -ForEach @(
    @{ ModuleName = 'audit-private-endpoints' },
    @{ ModuleName = 'audit-missing-private-endpoints' }
) {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $base = Join-Path $repoRoot "azure\storage\$ModuleName"
        $script:module = @{
            Directory = $base
            PsScript  = Join-Path $base (Get-ChildItem -LiteralPath $base -Filter *.ps1 |
                Select-Object -ExpandProperty Name -First 1)
            Kql       = Join-Path $base (Get-ChildItem -LiteralPath $base -Filter *.kql |
                Select-Object -ExpandProperty Name -First 1)
            Sh        = Join-Path $base (Get-ChildItem -LiteralPath $base -Filter *.sh |
                Select-Object -ExpandProperty Name -First 1)
        }
    }

    It 'parses the PowerShell script without syntax errors' {
        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $script:module.PsScript, [ref]$tokens, [ref]$parseErrors) | Out-Null
        $parseErrors | Should -BeNullOrEmpty
    }

    It 'exposes the documented parameters on the PowerShell script' {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:module.PsScript, [ref]$null, [ref]$null)
        $paramNames = @($ast.ParamBlock.Parameters | ForEach-Object {
            $_.Name.VariablePath.UserPath
        })
        foreach ($expected in @('SubscriptionId', 'OutputPath', 'ExportFormat', 'Environment', 'NoAuthPrompt')) {
            $paramNames | Should -Contain $expected
        }
    }

    It 'is strictly read-only (no mutating cmdlets)' {
        $content = Get-Content -Raw -LiteralPath $script:module.PsScript
        $content | Should -Not -Match 'Remove-|New-Az|Set-Az(?!Context)|Update-Az|Add-Az'
    }

    It 'contains comment-based help' {
        $content = Get-Content -Raw -LiteralPath $script:module.PsScript
        $content | Should -Match '\.SYNOPSIS'
        $content | Should -Match '\.DESCRIPTION'
        $content | Should -Match '\.EXAMPLE'
    }

    It 'targets storage accounts through Azure Resource Graph' {
        Get-Content -Raw -LiteralPath $script:module.Kql |
            Should -Match "type =~ 'microsoft.storage/storageaccounts'"
    }

    It 'projects subscriptionId and resourceGroup columns' {
        $content = Get-Content -Raw -LiteralPath $script:module.Kql
        $content | Should -Match 'subscriptionId'
        $content | Should -Match 'resourceGroup'
    }

    It 'is a POSIX bash script' {
        Get-Content -TotalCount 1 -LiteralPath $script:module.Sh |
            Should -Match '^#!/usr/bin/env bash'
    }

    It 'aborts on error and pipelines (set -euo pipefail)' {
        Get-Content -Raw -LiteralPath $script:module.Sh | Should -Match 'set -euo pipefail'
    }

    It 'verifies az CLI availability and login state' {
        $content = Get-Content -Raw -LiteralPath $script:module.Sh
        $content | Should -Match 'command -v az'
        $content | Should -Match 'az account show'
    }
}
