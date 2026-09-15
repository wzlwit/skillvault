$ErrorActionPreference = 'Stop'
$savedNodeOptions = $env:NODE_OPTIONS
$savedInspectorOptions = $env:VSCODE_INSPECTOR_OPTIONS

try {
    Remove-Item Env:NODE_OPTIONS, Env:VSCODE_INSPECTOR_OPTIONS -ErrorAction SilentlyContinue
    node --test (Join-Path $PSScriptRoot 'test-skill-files.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Node skill validation tests failed.' }
    foreach ($test in @('test-catalog-versions.ps1', 'test-install-skills.ps1', 'test-skillvault-remove.ps1', 'test-skillvault-fresh.ps1', 'test-skill-inventory.ps1', 'test-schedule-manager.ps1', 'test-bootstrap.ps1')) {
        & (Join-Path $PSScriptRoot $test)
    }
    & (Join-Path $PSScriptRoot 'validate-catalog.ps1')
    git -C (Split-Path -Parent $PSScriptRoot) diff --check
    if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed.' }
    Write-Output 'All SkillVault checks passed. Tests used temporary files and fake task/Git commands.'
}
finally {
    $env:NODE_OPTIONS = $savedNodeOptions
    $env:VSCODE_INSPECTOR_OPTIONS = $savedInspectorOptions
}