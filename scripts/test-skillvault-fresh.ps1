$ErrorActionPreference = 'Stop'

$refreshScript = Join-Path $PSScriptRoot '..\skills\core\skillvault-refresh\scripts\skillvault-fresh.ps1'
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-fresh-test-' + [guid]::NewGuid().ToString('N'))
$savedFixtureOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
$env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixtureRoot 'runtime-ownership'
$savedFixtureTransactionRoot = $env:SKILLVAULT_TRANSACTION_ROOT
$env:SKILLVAULT_TRANSACTION_ROOT = Join-Path $fixtureRoot 'updates'
. (Join-Path $PSScriptRoot '../skills/core/skillvault-installation/scripts/skill-ownership.ps1')
$sourceRepoRoot = Join-Path $fixtureRoot 'source'
$globalRoot = Join-Path $fixtureRoot 'global'
$cacheRoot = Join-Path $fixtureRoot 'cache'
$repoUrl = 'https://example.invalid/fixture.git'
$stamp = '2000-01-01T00:00:00.0000000Z'

$global:fakeGitSource = $sourceRepoRoot
$global:fakeGitCalls = New-Object 'System.Collections.Generic.List[string]'
$global:fakeGitFail = ''
$global:fakeGitStatus = @()
$global:fakeGitHead = 'origin/master'
$global:fakeGitRemote = $repoUrl
$global:fakeGitRevision = 'deadbeef'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function global:git {
    $arguments = @($args | ForEach-Object { [string]$_ })
    $offset = if ($arguments[0] -eq '-C') { 2 } else { 0 }
    $operation = $arguments[$offset]
    $global:fakeGitCalls.Add($operation)
    if ($operation -eq $global:fakeGitFail) { $global:LASTEXITCODE = 1; return }
    $global:LASTEXITCODE = 0

    switch ($operation) {
        'clone' {
            Copy-Item -LiteralPath $global:fakeGitSource -Destination $arguments[-1] -Recurse -Force
            New-Item -ItemType Directory -Path (Join-Path $arguments[-1] '.git') -Force | Out-Null
        }
        'status' { return $global:fakeGitStatus }
        'symbolic-ref' { return $global:fakeGitHead }
        'rev-parse' { return $global:fakeGitRevision }
        'remote' { if ($arguments[$offset + 1] -eq 'get-url') { return $global:fakeGitRemote } }
        'checkout' {
            $repoPath = $arguments[1]
            Get-ChildItem -LiteralPath $repoPath -Force | Where-Object { $_.Name -cne '.git' } | Remove-Item -Recurse -Force
            Get-ChildItem -LiteralPath $global:fakeGitSource -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $repoPath -Recurse -Force }
        }
    }
}

function New-FixtureSkill {
    param([string]$Name, $Version, [string]$Body = 'original')
    $path = Join-Path $sourceRepoRoot "skills\core\$Name"
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    [ordered]@{ name = $Name; description = "Fixture $Name"; version = $Version } |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $path 'skill.json') -Encoding utf8
    "# $Name $Body" | Set-Content -LiteralPath (Join-Path $path 'SKILL.md') -Encoding utf8
    return $path
}

function Install-FixtureSkill {
    param([string]$Name, $Version, [string]$RequestedVersion = 'latest', [string]$Scope = 'global',
        [string]$InstalledBy = 'skillvault', [string]$SourcePath)
    $target = Join-Path $globalRoot $Name
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    $source = Join-Path $sourceRepoRoot "skills\core\$Name"
    if (Test-Path -LiteralPath $source) {
        Get-ChildItem -LiteralPath $source -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force }
    }
    if (-not $SourcePath) { $SourcePath = "skills/core/$Name" }
    [ordered]@{ installedBy = $InstalledBy; sourceRepo = $repoUrl; sourcePath = $SourcePath; scope = $Scope;
        requestedVersion = $RequestedVersion; installedVersion = $Version; installedAt = $stamp } |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $target '.skillvault-install.json') -Encoding utf8
    return $target
}

function Get-FixtureMetadata {
    param([string]$Path)
    $metadata = Get-Content -LiteralPath (Join-Path $Path '.skillvault-install.json') -Raw | ConvertFrom-Json
    if ($metadata.installedAt -is [datetime]) {
        $metadata.installedAt = $metadata.installedAt.ToUniversalTime().ToString('o')
    }
    return $metadata
}

function Get-FixtureBody {
    param([string]$Path)
    return Get-Content -LiteralPath (Join-Path $Path 'SKILL.md') -Raw
}

function Invoke-Refresh {
    $global:fakeGitCalls.Clear()
    try { & $refreshScript -RunOnce -GlobalSkillsPath $globalRoot -CachePath $cacheRoot | Out-Null; return $false }
    catch { return $true }
}

function Get-GitCallCount {
    param([string]$Operation)
    return @($global:fakeGitCalls | Where-Object { $_ -eq $Operation }).Count
}

try {
    New-Item -ItemType Directory -Path $sourceRepoRoot, $globalRoot -Force | Out-Null
    foreach ($fixtureName in @('alpha', 'pinned', 'foreign', 'scoped', 'ac-mismatch')) {
        New-FixtureSkill -Name $fixtureName -Version '1.0.0' | Out-Null
    }
    New-FixtureSkill -Name 'beta' -Version $null | Out-Null

    $alphaTarget = Install-FixtureSkill -Name 'alpha' -Version '1.0.0'
    $betaTarget = Install-FixtureSkill -Name 'beta' -Version $null
    $skippedTargets = @(
        (Install-FixtureSkill -Name 'pinned' -Version '1.0.0' -RequestedVersion 'v1.0.0'),
        (Install-FixtureSkill -Name 'foreign' -Version '1.0.0' -InstalledBy 'other'),
        (Install-FixtureSkill -Name 'scoped' -Version '1.0.0' -Scope 'project')
    )
    New-Item -ItemType Directory -Path (Join-Path $globalRoot 'manual') -Force | Out-Null
    'manual' | Set-Content -LiteralPath (Join-Path $globalRoot 'manual\notes.md') -Encoding utf8

    Assert-True (-not (Invoke-Refresh)) 'an unchanged run succeeds'
    Assert-True ((Get-GitCallCount 'clone') -eq 1) 'skills sharing one source repository clone it once per run'
    Assert-True ((Get-FixtureMetadata $alphaTarget).installedAt -eq $stamp) 'an unchanged skill keeps installedAt'
    Assert-True ((Get-FixtureMetadata $betaTarget).installedAt -eq $stamp) 'an unchanged unversioned skill keeps installedAt'
    foreach ($skippedTarget in $skippedTargets) {
        Assert-True ((Get-FixtureMetadata $skippedTarget).installedAt -eq $stamp) "pinned, unmanaged and project installs are untouched: $skippedTarget"
    }

    $compatibilitySource = New-FixtureSkill -Name 'legacy-runtime' -Version '1.0.0'
    $compatibilityTarget = Install-FixtureSkill -Name 'legacy-runtime' -Version '1.0.0'
    '{"name":"legacy-runtime","version":"1.0.0","kind":"compatibility","dependencies":["new-topic"]}' |
        Set-Content -LiteralPath (Join-Path $compatibilitySource 'skill.json') -Encoding utf8
    '# compatibility forwarder' | Set-Content -LiteralPath (Join-Path $compatibilitySource 'SKILL.md') -Encoding utf8
    Assert-True (-not (Invoke-Refresh)) 'compatibility-only sources are skipped without failing a refresh'
    Assert-True ((Get-FixtureBody $compatibilityTarget) -like '*original*') 'refresh preserves the full old installed runtime instead of replacing it with a forwarder'
    Assert-True ((Get-FixtureMetadata $compatibilityTarget).installedAt -eq $stamp) 'skipped migration preserves install metadata'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $globalRoot 'new-topic'))) 'refresh never installs migration dependencies implicitly'

    New-FixtureSkill -Name 'relocated' -Version '1.0.0' | Out-Null
    $relocatedTarget = Install-FixtureSkill -Name 'relocated' -Version '1.0.0' -SourcePath 'skills/public/core/relocated'
    $relocationCatalog = Join-Path $sourceRepoRoot 'catalog.json'
    '[{"name":"other","path":"skills/core/relocated"}]' | Set-Content -LiteralPath $relocationCatalog -Encoding utf8
    Assert-True (Invoke-Refresh) 'a moved path without a matching catalog identity fails without guessing'
    Assert-True ((Get-FixtureMetadata $relocatedTarget).installedAt -eq $stamp) 'an unverified relocation leaves the install untouched'
    '[{"name":"relocated","path":"skills/core/relocated"},{"name":"relocated","path":"skills/core/relocated"}]' |
        Set-Content -LiteralPath $relocationCatalog -Encoding utf8
    Assert-True (Invoke-Refresh) 'ambiguous catalog entries do not authorize a relocation'
    '[{"name":"relocated","path":"skills/core/relocated"}]' | Set-Content -LiteralPath $relocationCatalog -Encoding utf8
    Assert-True (-not (Invoke-Refresh)) 'a catalog-confirmed layout relocation succeeds'
    $relocatedMetadata = Get-FixtureMetadata $relocatedTarget
    Assert-True ($relocatedMetadata.sourcePath -ceq 'skills/core/relocated') 'a same-content relocation updates the recorded source path'
    Assert-True ($relocatedMetadata.sourceRevision -eq 'deadbeef') 'relocation records the new source revision'
    Assert-True ((Get-FixtureBody $relocatedTarget) -like '*original*') 'relocation preserves the complete skill content'
    Assert-True (-not (Invoke-Refresh)) 'a subsequent refresh uses the relocated path normally'
    Assert-True ((Get-FixtureMetadata $relocatedTarget).installedAt -eq $relocatedMetadata.installedAt) 'an unchanged relocated install is not restamped again'
    foreach ($skippedTarget in $skippedTargets) {
        Assert-True ((Get-FixtureMetadata $skippedTarget).installedAt -eq $stamp) 'relocation does not change pinned, unmanaged, or project installs'
    }

    New-FixtureSkill -Name 'alpha' -Version '1.0.0' -Body 'updated' | Out-Null
    New-FixtureSkill -Name 'beta' -Version $null -Body 'updated' | Out-Null
    $activeRuntime = Enter-SkillOwnership -Resources @([pscustomobject]@{ kind = 'runtime'; path = $alphaTarget; mode = 'Read' }) -Owner @{ controller = 'active refresh fixture' }
    try {
        Assert-True (Invoke-Refresh) 'refresh defers a changed bundle that an active worker owns'
        Assert-True ((Get-FixtureBody $alphaTarget) -like '*original*') 'deferred refresh preserves active runtime content'
    }
    finally { Exit-SkillOwnership $activeRuntime }
    Assert-True (-not (Invoke-Refresh)) 'a same-version content change succeeds'
    Assert-True ((Get-GitCallCount 'clone') -eq 0 -and (Get-GitCallCount 'checkout') -eq 1) 'an existing cache is refreshed without cloning'
    Assert-True ((Get-FixtureBody $alphaTarget) -like '*updated*') 'a same-version content change is copied'
    $alphaMetadata = Get-FixtureMetadata $alphaTarget
    Assert-True ($alphaMetadata.installedVersion -eq '1.0.0') 'a same-version update keeps the manifest version'
    Assert-True ($alphaMetadata.installedAt -ne $stamp) 'an updated skill is restamped'
    Assert-True ($alphaMetadata.installedBy -eq 'skillvault' -and $alphaMetadata.requestedVersion -eq 'latest') 'an update preserves local metadata fields'
    Assert-True ($alphaMetadata.sourceRevision -eq 'deadbeef') 'an update records the source revision'
    Assert-True ($null -eq (Get-FixtureMetadata $betaTarget).installedVersion) 'an unversioned manifest updates with a null version'
    Assert-True ((Get-FixtureBody $betaTarget) -like '*updated*') 'an unversioned skill updates its content'

    New-FixtureSkill -Name 'retryable' -Version '1.0.0' | Out-Null
    $retryTarget = Install-FixtureSkill -Name 'retryable' -Version '1.0.0'
    New-FixtureSkill -Name 'retryable' -Version '1.0.0' -Body 'retry update' | Out-Null
    $retryLease = Enter-SkillOwnership -Resources @([pscustomobject]@{ kind = 'runtime'; path = $retryTarget; mode = 'Read' }) -Owner @{ controller = 'retry worker fixture' }
    $claimPath = Join-Path $retryLease.root ($retryLease.id + '.json')
    try {
        $selfResult = & $refreshScript -RunOnce -ResultJson -GlobalSkillsPath $globalRoot -CachePath $cacheRoot | ConvertFrom-Json
        Assert-True ($selfResult.status -ceq 'Deferred' -and $selfResult.retryTargets.Count -eq 0) 'self-owned contention is not retryable'
        $claim = Get-Content -LiteralPath $claimPath -Raw | ConvertFrom-Json
        $claim.processId = 987654
        $claim | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $claimPath
        $busyResult = & $refreshScript -RunOnce -ResultJson -GlobalSkillsPath $globalRoot -CachePath $cacheRoot | ConvertFrom-Json
        Assert-True ($busyResult.status -ceq 'Deferred' -and $busyResult.retryTargets.Count -eq 1 -and $busyResult.retryTargets[0].name -ceq 'retryable') 'another active owner produces exactly one scoped retry target'
        $parentResult = & $refreshScript -RunOnce -ResultJson -OwnerProcessId 987654 -GlobalSkillsPath $globalRoot -CachePath $cacheRoot | ConvertFrom-Json
        Assert-True ($parentResult.retryTargets.Count -eq 0) 'the heartbeat parent cannot retry updates to its own protected dependency'
        $retryPlanPath = Join-Path $fixtureRoot 'retry-plan.json'
        [pscustomobject]@{ schemaVersion = 1; globalSkillsRoot = $globalRoot; targets = @($busyResult.retryTargets); unresolved = @($busyResult.unresolved) } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $retryPlanPath
        $metadataPath = Join-Path $retryTarget '.skillvault-install.json'
        $originalMetadata = [IO.File]::ReadAllText($metadataPath)
        [IO.File]::WriteAllText($metadataPath, $originalMetadata + "`n")
        $changedMetadata = & $refreshScript -RunOnce -ResultJson -RetryPlanPath $retryPlanPath -GlobalSkillsPath $globalRoot -CachePath $cacheRoot | ConvertFrom-Json
        Assert-True ($changedMetadata.retryTargets.Count -eq 0 -and $changedMetadata.unresolved[0].reason -ceq 'InstalledMetadataChanged') 'retry does not adopt changed installed metadata'
        [IO.File]::WriteAllText($metadataPath, $originalMetadata)
        $global:fakeGitRevision = 'different-revision'
        $changedSource = & $refreshScript -RunOnce -ResultJson -RetryPlanPath $retryPlanPath -GlobalSkillsPath $globalRoot -CachePath $cacheRoot | ConvertFrom-Json
        Assert-True ($changedSource.retryTargets.Count -eq 0 -and $changedSource.unresolved[0].reason -ceq 'SourceChanged') 'retry does not substitute a newer source revision'
        $global:fakeGitRevision = 'deadbeef'
    }
    finally { Exit-SkillOwnership $retryLease -Uncertain }
    $recoveryResult = & $refreshScript -RunOnce -ResultJson -RetryPlanPath $retryPlanPath -GlobalSkillsPath $globalRoot -CachePath $cacheRoot | ConvertFrom-Json
    Assert-True ($recoveryResult.retryTargets.Count -eq 0 -and $recoveryResult.unresolved[0].reason -ceq 'NeedsRecovery') 'uncertain claims are not eligible for automatic retries'
    Clear-SkillOwnership -Id $retryLease.id -Root $retryLease.root -ConfirmStopped
    $alphaBeforeScopedRetry = Get-FixtureBody $alphaTarget
    New-FixtureSkill -Name 'alpha' -Version '1.0.0' -Body 'outside retry scope' | Out-Null
    $scopedRetry = & $refreshScript -RunOnce -ResultJson -RetryPlanPath $retryPlanPath -GlobalSkillsPath $globalRoot -CachePath $cacheRoot | ConvertFrom-Json
    Assert-True ($scopedRetry.status -ceq 'Succeeded' -and $scopedRetry.retryTargets.Count -eq 0 -and (Get-FixtureBody $retryTarget) -like '*retry update*') 'released ownership permits the originally approved target update'
    Assert-True ((Get-FixtureBody $alphaTarget) -ceq $alphaBeforeScopedRetry) 'a scoped retry does not refresh unrelated or previously completed targets'
    New-FixtureSkill -Name 'alpha' -Version '1.0.0' -Body 'updated' | Out-Null
    $mixedPlan = Get-Content -LiteralPath $retryPlanPath -Raw | ConvertFrom-Json
    $mixedPlan.unresolved += [pscustomobject]@{ name = 'other-target'; status = 'Deferred'; reason = 'NeedsTransition'; retryable = $false }
    $mixedPlan | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $retryPlanPath
    $mixedResult = & $refreshScript -RunOnce -ResultJson -RetryPlanPath $retryPlanPath -GlobalSkillsPath $globalRoot -CachePath $cacheRoot | ConvertFrom-Json
    Assert-True ($mixedResult.status -ceq 'Deferred' -and @($mixedResult.unresolved | Where-Object { $_.name -ceq 'other-target' -and $_.reason -ceq 'NeedsTransition' }).Count -eq 1) 'a later retry preserves unrelated terminal deferrals instead of reporting overall success'
    $legacySource = New-FixtureSkill -Name 'harness' -Version '1.0.0'
    $legacyTarget = Install-FixtureSkill -Name 'harness' -Version '1.0.0'
    New-FixtureSkill -Name 'harness' -Version '1.0.0' -Body 'legacy update' | Out-Null
    $legacyResult = & $refreshScript -RunOnce -ResultJson -GlobalSkillsPath $globalRoot -CachePath $cacheRoot | ConvertFrom-Json
    Assert-True ($legacyResult.retryTargets.Count -eq 0 -and @($legacyResult.unresolved | Where-Object { $_.name -ceq 'harness' -and $_.reason -ceq 'NeedsTransition' }).Count -eq 1) 'older runtime transitions are terminal deferrals, not automatic retries'
    Assert-True ((Get-FixtureBody $legacyTarget) -like '*original*') 'retry reporting does not replace an unconfirmed older runtime'
    Remove-Item -LiteralPath $legacySource, $legacyTarget -Recurse -Force

    New-FixtureSkill -Name 'alpha' -Version '1.0.0' -Body 'pending' | Out-Null
    $alphaBody = Get-FixtureBody $alphaTarget
    $alphaStamp = $alphaMetadata.installedAt
    $cachedRepo = @(Get-ChildItem -LiteralPath $cacheRoot -Directory)[0].FullName

    foreach ($operation in @('fetch', 'symbolic-ref', 'checkout')) {
        $global:fakeGitFail = $operation
        Assert-True (Invoke-Refresh) "a failed git $operation fails the run"
        Assert-True ((Get-FixtureBody $alphaTarget) -eq $alphaBody) "a failed git $operation leaves the install untouched"
        Assert-True ((Get-FixtureMetadata $alphaTarget).installedAt -eq $alphaStamp) "a failed git $operation does not restamp the install"
    }
    $global:fakeGitFail = ''

    $global:fakeGitHead = 'refs/heads/main'
    Assert-True (Invoke-Refresh) 'a default branch ref outside origin/ fails the run'
    Assert-True ((Get-FixtureBody $alphaTarget) -eq $alphaBody) 'a rejected default branch ref leaves the install untouched'
    $global:fakeGitHead = 'origin/master'

    $global:fakeGitStatus = @(' M SKILL.md')
    Assert-True (Invoke-Refresh) 'a modified source cache fails the run'
    $global:fakeGitStatus = @()

    $global:fakeGitRemote = 'https://example.invalid/other.git'
    Assert-True (Invoke-Refresh) 'a cache tracking another repository fails the run'
    $global:fakeGitRemote = $repoUrl

    Remove-Item -LiteralPath (Join-Path $cachedRepo '.git') -Recurse -Force
    Assert-True (Invoke-Refresh) 'a cache directory without .git fails the run'
    Assert-True (Test-Path -LiteralPath $cachedRepo) 'a cache directory without .git is not deleted'
    Remove-Item -LiteralPath $cacheRoot -Recurse -Force

    $global:fakeGitFail = 'clone'
    Assert-True (Invoke-Refresh) 'a failed git clone fails the run'
    Assert-True ((Get-FixtureBody $alphaTarget) -eq $alphaBody) 'a failed git clone leaves the install untouched'
    $global:fakeGitFail = ''

    $badJsonTarget = Install-FixtureSkill -Name 'aa-badjson' -Version '1.0.0'
    '{ not json' | Set-Content -LiteralPath (Join-Path $badJsonTarget '.skillvault-install.json') -Encoding utf8
    $noManifestSource = Join-Path $sourceRepoRoot 'skills\core\ab-nomanifest'
    New-Item -ItemType Directory -Path $noManifestSource -Force | Out-Null
    '# ab-nomanifest' | Set-Content -LiteralPath (Join-Path $noManifestSource 'SKILL.md') -Encoding utf8
    $noManifestTarget = Install-FixtureSkill -Name 'ab-nomanifest' -Version '1.0.0'
    $mismatchTarget = Install-FixtureSkill -Name 'ac-mismatch' -Version '1.0.0'
    '{"name":"other","version":"1.0.0"}' | Set-Content -LiteralPath (Join-Path $sourceRepoRoot 'skills\core\ac-mismatch\skill.json') -Encoding utf8
    $traversalTarget = Install-FixtureSkill -Name 'ad-traversal' -Version '1.0.0' -SourcePath '../outside'

    Assert-True (Invoke-Refresh) 'per-skill failures fail the run'
    Assert-True ((Get-FixtureBody $alphaTarget) -like '*pending*') 'a later valid skill still updates after earlier failures'
    Assert-True ((Get-Content -LiteralPath (Join-Path $badJsonTarget '.skillvault-install.json') -Raw) -like '*not json*') 'malformed metadata is left alone'
    Assert-True ((Get-FixtureMetadata $noManifestTarget).installedAt -eq $stamp) 'a source without a manifest leaves the install untouched'
    Assert-True ((Get-FixtureMetadata $mismatchTarget).installedAt -eq $stamp) 'a manifest name mismatch leaves the install untouched'
    Assert-True (@(Get-ChildItem -LiteralPath $traversalTarget -Force).Count -eq 1) 'a traversal source path copies nothing'
    Assert-True (@(Get-ChildItem -LiteralPath $globalRoot -Force | Where-Object { $_.Name -like '.skillvault-stage-*' -or $_.Name -like '.skillvault-backup-*' }).Count -eq 0) 'a run leaves no staging residue'

    Write-Output 'Refresh checks passed using fake Git and temporary fixtures only.'
}
finally {
    $env:SKILLVAULT_OWNERSHIP_ROOT = $savedFixtureOwnershipRoot
    $env:SKILLVAULT_TRANSACTION_ROOT = $savedFixtureTransactionRoot
    Remove-Item -LiteralPath 'Function:\git' -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name fakeGitSource, fakeGitCalls, fakeGitFail, fakeGitStatus, fakeGitHead, fakeGitRemote, fakeGitRevision -Scope Global -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    $global:LASTEXITCODE = 0
}