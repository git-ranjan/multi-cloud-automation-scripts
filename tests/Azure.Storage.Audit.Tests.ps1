#requires -Version 5.1
# Pester 5.x tests validating the Azure Storage audit modules without
# requiring an Azure subscription (parse/structure-level coverage).

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$modules = @(
    @{
        Name     = 'audit-private-endpoints'
        PsScript = 'audit-storage-with-pe.ps1'
        Kql      = 'audit-storage-with-pe.kql'
        Sh       = 'audit-storage-with-pe.sh'
    },
    @{
        Name     = 'audit-missing-private-endpoints'
        PsScript = 'audit-storage-without-pe.ps1'
        Kql      = 'audit-storage-without-pe.kql'
        Sh       = 'audit-storage-without-pe.sh'
    }
)

Describe 'Azure Storage audit module layout' {
    It 'exposes a README, PowerShell, Bash and KQL implementation for each module' {
        foreach ($module in $modules) {
            $dir = Join-Path $repoRoot "azure\storage\$($module.Name)"
            foreach ($file in @('README.md', $module.PsScript, $module.Kql, $module.Sh)) {
                Test-Path -LiteralPath (Join-Path $dir $file) | Should -BeTrue
            }
        }
    }
}

foreach ($module in $modules) {
    $psPath = Join-Path $repoRoot "azure\storage\$($module.Name)\$($module.PsScript)"

    Describe "$($module.PsScript) - static validation" {
        It 'parses without syntax errors' {
            $tokens = $null
            $parseErrors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $psPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
            $parseErrors | Should -BeNullOrEmpty
        }

        It 'exposes the documented parameters' {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $psPath, [ref]$null, [ref]$null)
            $paramBlocks = $ast.ParamBlock.Parent
            $paramNames = $paramBlocks.Parameters.Name.Value
            $paramNames | Should -Contain 'SubscriptionId'
            $paramNames | Should -Contain 'OutputPath'
            $paramNames | Should -Contain 'ExportFormat'
            $paramNames | Should -Contain 'Environment'
            $paramNames | Should -Contain 'NoAuthPrompt'
        }

        It 'is strictly read-only (no mutating cmdlets)' {
            $content = Get-Content -Raw -LiteralPath $psPath
            $content | Should -Not -Match 'Remove-|New-Az|Set-Az(?!Context)|Update-Az|Add-Az'
        }

        It 'contains comment-based help' {
            $content = Get-Content -Raw -LiteralPath $psPath
            $content | Should -Match '\.SYNOPSIS'
            $content | Should -Match '\.DESCRIPTION'
            $content | Should -Match '\.EXAMPLE'
        }
    }

    $kqlPath = Join-Path $repoRoot "azure\storage\$($module.Name)\$($module.Kql)"
    Describe "$($module.Kql) - static validation" {
        It 'targets storage accounts through Azure Resource Graph' {
            Get-Content -Raw -LiteralPath $kqlPath |
                Should -Match "type =~ 'microsoft.storage/storageaccounts'"
        }

        It 'projects subscriptionId and resourceGroup columns' {
            $content = Get-Content -Raw -LiteralPath $kqlPath
            $content | Should -Match 'subscriptionId'
            $content | Should -Match 'resourceGroup'
        }
    }

    $shPath = Join-Path $repoRoot "azure\storage\$($module.Name)\$($module.Sh)"
    Describe "$($module.Sh) - static validation" {
        It 'is a POSIX bash script' {
            Get-Content -TotalCount 1 -LiteralPath $shPath |
                Should -Match '^#!/usr/bin/env bash'
        }

        It 'aborts on error and pipelines (set -euo pipefail)' {
            Get-Content -Raw -LiteralPath $shPath | Should -Match 'set -euo pipefail'
        }

        It 'verifies az CLI availability and login state' {
            $content = Get-Content -Raw -LiteralPath $shPath
            $content | Should -Match 'command -v az'
            $content | Should -Match 'az account show'
        }
    }
}