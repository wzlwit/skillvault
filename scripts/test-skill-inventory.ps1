$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '..\skills\core\skillvault-installation\scripts\skillvault-list.ps1'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-inventory-' + [guid]::NewGuid().ToString('N'))
$savedFixtureOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
$fixtureOwnership = $root + '-ownership'
$env:SKILLVAULT_OWNERSHIP_ROOT = $fixtureOwnership
$savedFixtureTransactionRoot = $env:SKILLVAULT_TRANSACTION_ROOT
$fixtureRecovery = $root + '-recovery'
$env:SKILLVAULT_TRANSACTION_ROOT = $fixtureRecovery
. (Join-Path $PSScriptRoot '../skills/core/skillvault-installation/scripts/skill-ownership.ps1')

try {
    foreach ($name in @('alpha', 'beta', 'gamma', 'session', '.skillvault-backup-fixture')) {
        New-Item -ItemType Directory -Path (Join-Path $root $name) -Force | Out-Null
    }
    $metadata = @{ installedBy = 'skillvault'; requestedVersion = 'latest'; sourcePath = 'skills/test/alpha' }
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
    $activeRuntime = Enter-SkillOwnership -Resources @([pscustomobject]@{ kind = 'runtime'; path = (Join-Path $root 'alpha'); mode = 'Read' }) -Owner @{ controller = 'uninstall fixture' }
    try {
        $blocked = $false
        try { & $scriptPath -Scope global -GlobalSkillsPath $root -Uninstall -Selector 'alpha' -Force | Out-Null }
        catch { $blocked = $_.Exception.Data['SkillOwnershipStatus'] -ceq 'Busy' }
        if (-not $blocked -or -not (Test-Path -LiteralPath (Join-Path $root 'alpha'))) { throw 'Uninstall bypassed active runtime ownership.' }
    }
    finally { Exit-SkillOwnership $activeRuntime }
    & $scriptPath -Scope global -GlobalSkillsPath $root -Uninstall -Selector 'alpha' -Force | Out-Null
    if ((Test-Path -LiteralPath (Join-Path $root 'alpha')) -or -not (Test-Path -LiteralPath (Join-Path $root 'beta'))) { throw 'Uninstall changed the wrong skill.' }
    . (Join-Path $PSScriptRoot '../skills/core/skillvault-installation/scripts/skill-files.ps1')
    if (Test-Path -LiteralPath $fixtureRecovery) { throw 'A successful uninstall retained an obsolete copy.' }
    & $scriptPath -Scope global -GlobalSkillsPath $root -Uninstall -Selector 'session' -Force | Out-Null
    if (-not (Test-Path -LiteralPath (Join-Path $root 'session'))) { throw 'Global uninstall removed session-only storage.' }
    Write-Output 'Inventory checks passed: selectors, null versions, reserved folders, preview, and targeted uninstall.'

    $cleanRoot = Join-Path $root 'clean'
    $globalSkills = Join-Path $cleanRoot 'global'
    $agentSkills = Join-Path $cleanRoot 'agents'
    $projectA = Join-Path $cleanRoot 'repo-a/.github/skills'
    $projectB = Join-Path $cleanRoot 'repo-b/.github/skills'
    $fromVault = @{ installedBy = 'skillvault'; requestedVersion = 'latest'; sourceRepo = 'https://github.com/wzlwit/skillvault.git' }
    $pinned = @{ installedBy = 'skillvault'; requestedVersion = 'v1.0.0'; sourceRepo = 'https://github.com/wzlwit/skillvault.git' }
    $original = @{ installedBy = 'skillvault'; requestedVersion = 'latest'; sourceType = 'upstream' }
    $script:nextIndex = 0
    function Add-CleanCopy {
        param([string]$Root, [string]$Name, [string]$Group, [hashtable]$Metadata, [switch]$NoHeader, [switch]$Other)
        $path = Join-Path $Root $Name
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        $text = if ($NoHeader) { "# $Name" } else { "---`nname: $Name`ndescription: Fixture.`n---`n# $Name" }
        Set-Content -LiteralPath (Join-Path $path 'SKILL.md') -Value $text -Encoding utf8
        if ($Metadata) { $Metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $path '.skillvault-install.json') -Encoding utf8 }
        $index = if ($Other) { $null } else { $script:nextIndex += 1; $script:nextIndex }
        New-SkillCleanCopy -Path $path -Place ($Root.Substring($cleanRoot.Length + 1) -split '[\\/]')[0] -Group $Group -Index $index
    }
    $copies = @(
        Add-CleanCopy $globalSkills 'dup' 'global' $fromVault
        Add-CleanCopy $projectA 'dup' $projectA $fromVault
        Add-CleanCopy $projectA 'shared' $projectA $fromVault
        Add-CleanCopy $projectB 'shared' $projectB $fromVault
        Add-CleanCopy $globalSkills 'adapted' 'global' $fromVault
        Add-CleanCopy $projectA 'adapted' $projectA $original
        Add-CleanCopy $globalSkills 'pinned' 'global' $fromVault
        Add-CleanCopy $projectA 'pinned' $projectA $pinned
        Add-CleanCopy $globalSkills 'renamed' 'global' $fromVault
        Add-CleanCopy $agentSkills 'renamed-original' 'global' $null -Other
        Add-CleanCopy $globalSkills 'old-name' 'global' $fromVault
        Add-CleanCopy $globalSkills 'gone' 'global' $fromVault
        Add-CleanCopy $globalSkills 'broken' 'global' $null -NoHeader
        Add-CleanCopy $projectA 'only-a' $projectA $fromVault
        Add-CleanCopy $projectB 'only-b' $projectB $fromVault
    )
    $descriptions = @{
        'dup' = 'Fixture. Overlaps with adapted on testing; mentions gone outside the clause.'
        'shared' = 'Overlaps with gone on cleanup.'; 'adapted' = 'Fixture.'; 'pinned' = 'Fixture.'; 'renamed' = 'Fixture.'
        'only-a' = 'Overlaps with only-b on project work.'; 'only-b' = 'Fixture.'
    }
    $report = Get-SkillCleanFindings -Copies $copies -Descriptions $descriptions -RenamedOriginals @{ 'renamed-original' = 'renamed' } -FormerNames @{ 'old-name' = 'dup' }
    $byName = @{}
    foreach ($finding in $report.findings) { $byName["$($finding.kind):$($finding.name)"] = @($finding.copies | ForEach-Object { "$($_.place)=$($_.action)" } | Sort-Object) -join ',' }
    $expected = [ordered]@{
        'Duplicate:dup' = 'global=keep,repo-a=uninstall'
        'AdaptationAndOriginal:adapted' = 'global=keep,repo-a=uninstall'
        'Duplicate:pinned' = 'global=keep,repo-a=decide'
        'AdaptationAndOriginal:renamed + renamed-original' = 'agents=report,global=keep'
        'FormerName:old-name' = 'global=update-topics'
        'NotInCatalog:gone' = 'global=uninstall'
        'CannotLoad:broken' = 'global=report'
    }
    foreach ($key in $expected.Keys) {
        if ($byName[$key] -cne $expected[$key]) { throw "Clean finding $key was '$($byName[$key])', expected '$($expected[$key])'." }
    }
    if ($report.findings.Count -ne $expected.Count) { throw "Clean reported unexpected findings: $(@($byName.Keys) -join ', ')" }
    $pairs = @($report.catalogOverlaps | ForEach-Object { $_.skills -join '~' } | Sort-Object)
    if (($pairs -join ',') -cne 'adapted~dup,gone~shared') { throw "Clean catalog overlaps were '$($pairs -join ',')'." }

    $checkGlobal = Join-Path $cleanRoot 'check-global'
    $checkOther = Join-Path $cleanRoot 'check-other'
    $null = Add-CleanCopy $checkGlobal 'twin' 'global' $fromVault
    $null = Add-CleanCopy $checkOther 'twin' 'global' $null -Other
    $snapshot = { @(Get-ChildItem -LiteralPath $cleanRoot -Recurse -Force | ForEach-Object { if ($_.PSIsContainer) { $_.FullName } else { "$($_.FullName)|$((Get-FileHash -LiteralPath $_.FullName).Hash)" } }) }
    $before = & $snapshot
    $scan = & $scriptPath -Check -Scope global -GlobalSkillsPath $checkGlobal -OtherSkillRoots @($checkOther) -RepoPath (Split-Path -Parent $PSScriptRoot) | ConvertFrom-Json
    $after = & $snapshot
    if (Compare-Object $before $after) { throw 'Clean scan changed files.' }
    $twin = @($scan.findings | Where-Object { $_.kind -eq 'Duplicate' -and $_.name -eq 'twin' })
    if ($twin.Count -ne 1 -or (@($twin[0].copies.action) -join ',') -cne 'keep,report' -or @($scan.places).Count -ne 2) { throw 'Clean scan did not report the global and other-folder copies of one skill.' }
    Write-Output 'Clean checks passed: load sets, adaptation and original pairs, pinned copies, former names, catalog gaps, unloadable skills, catalog overlaps, and read-only scan.'
}
finally {
    $env:SKILLVAULT_OWNERSHIP_ROOT = $savedFixtureOwnershipRoot
    $env:SKILLVAULT_TRANSACTION_ROOT = $savedFixtureTransactionRoot
    if (Test-Path -LiteralPath $fixtureRecovery) { Remove-Item -LiteralPath $fixtureRecovery -Recurse -Force }
    if (Test-Path -LiteralPath $fixtureOwnership) { Remove-Item -LiteralPath $fixtureOwnership -Recurse -Force }
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}