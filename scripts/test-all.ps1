$ErrorActionPreference = 'Stop'
$savedNodeOptions = $env:NODE_OPTIONS
$savedInspectorOptions = $env:VSCODE_INSPECTOR_OPTIONS
$savedOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
$savedTransactionRoot = $env:SKILLVAULT_TRANSACTION_ROOT
$fixtureOwnershipRoot = Join-Path ([IO.Path]::GetTempPath()) ('skillvault-suite-ownership-' + [guid]::NewGuid().ToString('N'))

try {
    $env:SKILLVAULT_OWNERSHIP_ROOT = $fixtureOwnershipRoot
    $env:SKILLVAULT_TRANSACTION_ROOT = Join-Path $fixtureOwnershipRoot 'updates'
    Remove-Item Env:NODE_OPTIONS, Env:VSCODE_INSPECTOR_OPTIONS -ErrorAction SilentlyContinue
    node --test (Join-Path $PSScriptRoot 'test-skill-files.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Node skill validation tests failed.' }
    foreach ($test in @('test-catalog-versions.ps1', 'test-install-skills.ps1', 'test-skillvault-upsert.ps1', 'test-skillvault-remove.ps1', 'test-skillvault-fresh.ps1', 'test-skill-inventory.ps1', 'test-harness-decide.ps1', 'test-schedule-manager.ps1', 'test-bootstrap.ps1')) {
        & (Join-Path $PSScriptRoot $test)
    }
    & (Join-Path $PSScriptRoot 'test-install-skills.ps1') -TransactionOnly
    & (Join-Path $PSScriptRoot 'test-install-skills.ps1') -CompatibilityOnly
    foreach ($test in @('test-harness.ps1', 'test-harness-tests.ps1', 'test-harness-policy.ps1', 'test-harness-monitor.ps1', 'test-harness-retention.ps1', 'test-harness-scheduler.ps1', 'test-harness-move.ps1', 'test-pr-review.ps1')) {
        if ($PSVersionTable.PSVersion.Major -ge 7) { & (Join-Path $PSScriptRoot $test) }
        else {
            & pwsh -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot $test)
            if ($LASTEXITCODE -ne 0) { throw "PowerShell 7 $test failed." }
        }
    }
    & (Join-Path $PSScriptRoot 'validate-catalog.ps1')
    git -C (Split-Path -Parent $PSScriptRoot) diff --check
    if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed.' }
    Write-Output 'All SkillVault checks passed. Tests used temporary files and fake task/Git commands.'
}
finally {
    $env:NODE_OPTIONS = $savedNodeOptions
    $env:VSCODE_INSPECTOR_OPTIONS = $savedInspectorOptions
    $env:SKILLVAULT_OWNERSHIP_ROOT = $savedOwnershipRoot
    $env:SKILLVAULT_TRANSACTION_ROOT = $savedTransactionRoot
    if (Test-Path -LiteralPath $fixtureOwnershipRoot) { Remove-Item -LiteralPath $fixtureOwnershipRoot -Recurse -Force }
}