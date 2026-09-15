$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '..\skills\public\core\skillvault-list\scripts\skillvault-list.ps1'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-inventory-' + [guid]::NewGuid().ToString('N'))

try {
    foreach ($name in @('alpha', 'beta', 'gamma', 'session', '.skillvault-backup-fixture')) {
        New-Item -ItemType Directory -Path (Join-Path $root $name) -Force | Out-Null
    }
    $metadata = @{ installedBy = 'skillvault'; requestedVersion = 'latest'; sourcePath = 'skills/public/test/alpha' }
    $metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'alpha/.skillvault-install.json') -Encoding utf8
    '{"name":"alpha","version":null}' | Set-Content -LiteralPath (Join-Path $root 'alpha/skill.json') -Encoding utf8
    . $scriptPath -Scope global -GlobalSkillsPath $root | Out-Null
    $inventory = @(Get-InstalledSkills)
    if ($inventory.Count -ne 3 -or $inventory[0].Name -ne 'alpha' -or $null -ne $inventory[0].Version) { throw 'Inventory failed to include unversioned skills or exclude reserved folders.' }
    foreach ($case in @(
        @{ Selector = '1'; Count = 1 },
        @{ Selector = '1,2-3'; Count = 3 },
        @{ Selector = '1,alpha'; Count = 1 },
        @{ Selector = 'BETA'; Count = 1 },
        @{ Selector = 'no-match'; Count = 0 }
    )) {
        if (@(Resolve-Selector -Entries $inventory -SelectorText $case.Selector).Count -ne $case.Count) { throw "Incorrect selector result: $($case.Selector)" }
    }
    & $scriptPath -Scope global -GlobalSkillsPath $root -Uninstall -Selector 'alpha' | Out-Null
    if (-not (Test-Path -LiteralPath (Join-Path $root 'alpha'))) { throw 'Preview removed a skill.' }
    & $scriptPath -Scope global -GlobalSkillsPath $root -Uninstall -Selector 'alpha' -Force | Out-Null
    if ((Test-Path -LiteralPath (Join-Path $root 'alpha')) -or -not (Test-Path -LiteralPath (Join-Path $root 'beta'))) { throw 'Uninstall changed the wrong skill.' }
    & $scriptPath -Scope global -GlobalSkillsPath $root -Uninstall -Selector 'session' -Force | Out-Null
    if (-not (Test-Path -LiteralPath (Join-Path $root 'session'))) { throw 'Global uninstall removed session-only storage.' }
    Write-Output 'Inventory checks passed: selectors, null versions, reserved folders, preview, and targeted uninstall.'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}