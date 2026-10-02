param([switch]$OwnershipOnly, [switch]$CompatibilityOnly, [Alias('RecoveryOnly')][switch]$TransactionOnly, [switch]$SelectionOnly)

$ErrorActionPreference = 'Stop'

$installScript = Join-Path $PSScriptRoot 'install-skills.ps1'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'skills\core\skillvault-installation\scripts\skill-files.ps1')
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'skills/core/skillvault-installation/scripts/skill-ownership.ps1')

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Test-Throws {
    param([scriptblock]$Action)
    try { & $Action | Out-Null; return $false }
    catch { return $true }
}

function New-FixtureSkill {
    param([string]$RepositoryRoot, [string]$RelativePath, [string]$SkillName, $Version, [string]$DefaultScope)
    $skillPath = Join-Path $RepositoryRoot $RelativePath.Replace('/', '\')
    New-Item -ItemType Directory -Path $skillPath -Force | Out-Null
    [ordered]@{
        name = $SkillName
        description = "Fixture skill $SkillName"
        version = $Version
        install = @{ defaultScope = $DefaultScope }
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $skillPath 'skill.json') -Encoding utf8
    "# $SkillName" | Set-Content -LiteralPath (Join-Path $skillPath 'SKILL.md') -Encoding utf8
    return $skillPath
}

function New-FixtureMetadata {
    param([string]$SourcePath, [string]$Scope, $Version)
    return [ordered]@{
        installedBy = 'skillvault'
        sourceRepo = 'https://github.com/wzlwit/skillvault.git'
        sourcePath = $SourcePath
        scope = $Scope
        requestedVersion = 'latest'
        installedVersion = $Version
        installedAt = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Get-InstallResidue {
    param([string]$Root)
    return @(Get-ChildItem -LiteralPath $Root -Force | Where-Object { $_.Name -like '.skillvault-stage-*' -or $_.Name -like '.skillvault-backup-*' })
}

$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-install-test-' + [guid]::NewGuid().ToString('N'))
$savedFixtureOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
$env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixtureRoot 'runtime-ownership'
$savedFixtureRecoveryRoot = $env:SKILLVAULT_RECOVERY_ROOT
$env:SKILLVAULT_RECOVERY_ROOT = Join-Path $fixtureRoot 'recovery'
$savedFixtureTransactionRoot = $env:SKILLVAULT_TRANSACTION_ROOT
$env:SKILLVAULT_TRANSACTION_ROOT = Join-Path $fixtureRoot 'updates'
$savedGitConfigGlobal = $env:GIT_CONFIG_GLOBAL
$savedGitConfigNoSystem = $env:GIT_CONFIG_NOSYSTEM
$repositoryRoot = Join-Path $fixtureRoot 'repo'
$projectRoot = Join-Path $fixtureRoot 'project'
$globalRoot = Join-Path $fixtureRoot 'global'

try {
    New-Item -ItemType Directory -Path $repositoryRoot, $projectRoot, $globalRoot -Force | Out-Null

    if ($SelectionOnly) {
        $selectionCatalog = @(
            @{ name = 'harness'; description = 'Project controller'; path = 'skills/planning/harness'; version = '1.0.0' },
            @{ name = 'harness-dev'; description = 'Development workflow'; path = 'skills/planning/harness-dev'; version = '1.0.0' },
            @{ name = 'harness-timer'; description = 'Scheduled work'; path = 'skills/planning/harness-timer'; version = '1.0.0' },
            @{ name = 'utility'; description = 'Observability companion mentioning harness'; path = 'skills/system/utility'; version = '1.0.0' },
            @{ name = 'report-builder'; description = 'Business KPI dashboards'; path = 'skills/data/report-builder'; version = '1.0.0' },
            @{ name = 'diagram-guide'; description = 'Architecture views'; path = 'skills/codeview/diagram-guide'; version = '1.0.0' }
        )
        foreach ($entry in $selectionCatalog) { $null = New-FixtureSkill $repositoryRoot $entry.path $entry.name $entry.version global }
        ConvertTo-Json -Depth 5 -InputObject $selectionCatalog | Set-Content (Join-Path $repositoryRoot 'catalog.json')
        foreach ($query in @('harness', 'arnes', 'HARNESS', 'harness*')) {
            $matched = @(Find-SkillCatalogEntry $selectionCatalog $query)
            Assert-True (($matched.name -join ',') -ceq 'harness,harness-dev,harness-timer') 'name matching includes all family members even when one name matches exactly'
        }
        Assert-True (@(Find-SkillCatalogEntry $selectionCatalog 'harness-*').Count -eq 2) 'name patterns can select only suffixed members'
        Assert-True ((@(Find-SkillCatalogEntry $selectionCatalog harness -Exact).name -join ',') -ceq 'harness') 'explicit exact selection keeps a single skill'
        Assert-True ((@(Find-SkillCatalogEntry $selectionCatalog observability).name -join ',') -ceq 'utility') 'description keywords work when no names match'
        Assert-True ((@(Find-SkillCatalogEntry $selectionCatalog 'KPI dashboards').name -join ',') -ceq 'report-builder') 'literal keyword phrases are supported'
        Assert-True ((@(Find-SkillCatalogEntry $selectionCatalog codeview).name -join ',') -ceq 'diagram-guide') 'catalog folder keywords are supported'
        Assert-True (@(Find-SkillCatalogEntry $selectionCatalog public).Count -eq $selectionCatalog.Count) 'the existing public selector still selects the full catalog'
        Assert-True (Test-Throws { Find-SkillCatalogEntry $selectionCatalog 'absent*' }) 'unmatched patterns do not select unrelated skills'
        Assert-True (Test-Throws { Find-SkillCatalogEntry $selectionCatalog ' ' }) 'blank selection does not install everything'
        $preview = & $installScript -Select harness,arnes -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot -Preview | ConvertFrom-Json
        Assert-True ($preview.Count -eq 3 -and @(Get-ChildItem $globalRoot -Force).Count -eq 0) 'selection preview is deduplicated and copies nothing'
        Assert-True (-not (Test-Path $env:SKILLVAULT_OWNERSHIP_ROOT)) 'preview acquires no ownership or runtime state'
        Assert-True (Test-Throws { & $installScript -Select harness,absent -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot }) 'one unmatched selector blocks the entire batch'
        Assert-True (@(Get-ChildItem $globalRoot -Force).Count -eq 0) 'a failed selection batch leaves all targets untouched'
        & $installScript -Select harness -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot | Out-Null
        Assert-True ((@(Get-ChildItem $globalRoot -Directory | Sort-Object Name).Name -join ',') -ceq 'harness,harness-dev,harness-timer') 'partial selection installs the complete name match set, not description-only neighbors'
        $repeatPreview = & $installScript -Select harness -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot -Preview | ConvertFrom-Json
        Assert-True ($repeatPreview.Count -eq 3) 'existing installations can be previewed without force approval'
        Assert-True (Test-Throws { & $installScript -Select harness -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot }) 'selection does not bypass forced-replacement approval'
        $exactPreview = & $installScript -Name harness -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot -Preview | ConvertFrom-Json
        Assert-True (@($exactPreview).Count -eq 1) 'the existing script Name API remains exact'
        Write-Output 'Selection checks passed: partial names, keywords, patterns, explicit exact names, read-only preview, batching, and replacement approval.'
        return
    }

    if ($TransactionOnly) {
        $source = New-FixtureSkill $repositoryRoot 'skills/core/alpha' alpha '1.0.0' global
        $target = New-FixtureSkill $globalRoot alpha alpha '1.0.0' global
        $metadata = New-FixtureMetadata skills/core/alpha global '1.0.0'
        'obsolete content' | Set-Content (Join-Path $target 'obsolete.txt')
        $installed = Copy-SkillInstallation -Source $source -TargetRoot $globalRoot -Name alpha -Metadata $metadata -Force
        Assert-True ((Test-SkillContentEqual $source $target) -and -not $installed.RecoveryBackup) 'successful replacement retains only the current installation'
        Assert-True (-not (Test-Path $env:SKILLVAULT_TRANSACTION_ROOT) -and -not (Test-Path $env:SKILLVAULT_RECOVERY_ROOT)) 'successful replacement leaves no temporary transaction or persistent recovery archive'
        'original customization' | Set-Content (Join-Path $target 'original.txt')
        $global:fixturePartialSwapReached = $false
        function global:Move-Item {
            param([string]$LiteralPath, [string]$Destination, [switch]$Force)
            if ($LiteralPath -like '*.skillvault-stage-*') {
                $global:fixturePartialSwapReached = $true
                New-Item -ItemType Directory -Path $Destination -Force | Out-Null
                throw 'Injected partial swap failure'
            }
            Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force
        }
        try { Assert-True (Test-Throws { Copy-SkillInstallation -Source $source -TargetRoot $globalRoot -Name alpha -Metadata $metadata -Force }) 'a failed replacement remains an error' }
        finally { Remove-Item Function:\Move-Item }
        Assert-True ($global:fixturePartialSwapReached -and (Get-Content (Join-Path $target 'original.txt')) -ceq 'original customization') 'partial swap rollback restores the original files'
        Assert-True (-not (Test-Path $env:SKILLVAULT_TRANSACTION_ROOT) -and -not (Test-Path $env:SKILLVAULT_RECOVERY_ROOT)) 'verified rollback also discards its temporary copy'
        $newTarget = Join-Path $globalRoot beta
        $newSource = New-FixtureSkill $repositoryRoot 'skills/core/beta' beta '1.0.0' global
        function global:Move-Item {
            param([string]$LiteralPath, [string]$Destination, [switch]$Force)
            if ($LiteralPath -like '*.skillvault-stage-*') {
                New-Item -ItemType Directory -Path $Destination -Force | Out-Null
                throw 'Injected new-install failure'
            }
            Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force
        }
        try { Assert-True (Test-Throws { Copy-SkillInstallation -Source $newSource -TargetRoot $globalRoot -Name beta -Metadata (New-FixtureMetadata skills/core/beta global '1.0.0') }) 'failed new installations remain errors' }
        finally { Remove-Item Function:\Move-Item }
        Assert-True (-not (Test-Path $newTarget)) 'a failed new installation leaves no partial registered copy'
        New-Item -ItemType Directory -Path (Join-Path $target '.git') | Out-Null
        'original git metadata' | Set-Content (Join-Path $target '.git/config')
        $transaction = New-SkillUpdateTransaction -Targets @(@{ path = $target; target = $target; name = 'alpha' })
        Assert-True (Test-SkillContentEqual $target (Join-Path $transaction.path alpha) -Complete) 'temporary rollback preserves complete original contents'
        Remove-Item -LiteralPath $target -Recurse -Force
        function global:Copy-Item { throw 'Injected rollback copy failure' }
        try { Assert-True (Test-Throws { Restore-SkillUpdateTransaction $transaction }) 'a rollback failure remains visible' }
        finally { Remove-Item Function:\Copy-Item }
        Assert-True ((Test-Path (Join-Path $transaction.path 'alpha/original.txt')) -and $transaction.record.status -ceq 'RollbackFailed') 'unrestored originals are not deleted as stale archives'
        Restore-SkillUpdateTransaction $transaction
        Assert-True ((Test-Path (Join-Path $target 'original.txt')) -and -not (Test-Path $transaction.path)) 'a verified recovery discards the temporary failed transaction'
        $safeRoot = $env:SKILLVAULT_TRANSACTION_ROOT
        try {
            $env:SKILLVAULT_TRANSACTION_ROOT = Join-Path $projectRoot '.github/skills/updates'
            Assert-True (Test-Throws { Get-SkillTransactionRoot }) 'temporary originals cannot enter skill discovery'
        }
        finally { $env:SKILLVAULT_TRANSACTION_ROOT = $safeRoot }
        Write-Output 'Transaction checks passed: current-copy-only success, verified rollback, no retained recovery directory.'
        return
    }

    if ($CompatibilityOnly) {
        $consumer = New-FixtureSkill -RepositoryRoot $globalRoot -RelativePath consumer -SkillName consumer -Version '1.0.0' -DefaultScope global
        $provider = New-FixtureSkill -RepositoryRoot $globalRoot -RelativePath provider -SkillName provider -Version '1.0.0' -DefaultScope global
        $consumerManifest = Get-Content (Join-Path $consumer 'skill.json') -Raw | ConvertFrom-Json
        $consumerManifest | Add-Member -NotePropertyMembers @{ dependencies = @('provider'); requiredInterfaces = [pscustomobject]@{ provider = [pscustomobject]@{ receipt = 1 } } }
        Write-SkillTransactionJson (Join-Path $consumer 'skill.json') $consumerManifest
        try { $unexpected = Enter-SkillRuntimeOwnership -SkillPath $consumer -Owner @{ role = 'fixture' }; Exit-SkillOwnership $unexpected; throw 'Missing interface was accepted.' }
        catch {
            Assert-True ($_.Exception.Data['SkillRuntimeStatus'] -ceq 'Incompatible') 'equal package versions do not imply interface compatibility'
            Assert-True (($_.Exception.Data['SkillRuntimeRequiredUpdates'] -join ',') -ceq 'consumer,provider') 'compatibility failure names the companion update set'
        }
        Assert-True (@(Read-SkillOwnershipClaims (Get-SkillOwnershipRoot)).Count -eq 0) 'a failed preflight releases its ownership claim'
        $providerManifest = Get-Content (Join-Path $provider 'skill.json') -Raw | ConvertFrom-Json
        $providerManifest.version = '9.0.0'
        $providerManifest | Add-Member -NotePropertyName runtimeInterfaces -NotePropertyValue ([pscustomobject]@{ receipt = 1 })
        Write-SkillTransactionJson (Join-Path $provider 'skill.json') $providerManifest
        $lease = Enter-SkillRuntimeOwnership -SkillPath $consumer -Owner @{ role = 'fixture' }
        Exit-SkillOwnership $lease
        $providerManifest.runtimeInterfaces.receipt = 2
        Write-SkillTransactionJson (Join-Path $provider 'skill.json') $providerManifest
        Assert-True (Test-Throws { Enter-SkillRuntimeOwnership -SkillPath $consumer -Owner @{ role = 'fixture' } }) 'a different interface version is not silently assumed compatible'
        $providerManifest.runtimeInterfaces.receipt = '1'
        Write-SkillTransactionJson (Join-Path $provider 'skill.json') $providerManifest
        Assert-True (Test-Throws { Get-SkillRuntimeCompatibility -SkillPath $consumer }) 'malformed interface declarations are rejected'
        $installed = Join-Path $repositoryRoot '.github/skills/consumer'
        New-Item -ItemType Directory -Path (Split-Path -Parent $installed) -Force | Out-Null
        Copy-Item $consumer $installed -Recurse
        $null = New-FixtureSkill -RepositoryRoot $repositoryRoot -RelativePath skills/core/provider -SkillName provider -Version '1.0.0' -DefaultScope global
        @(@{ name = 'consumer'; path = 'skills/core/consumer' }, @{ name = 'provider'; path = 'skills/core/provider' }) | ConvertTo-Json | Set-Content (Join-Path $repositoryRoot 'catalog.json')
        $missing = Get-SkillRuntimeCompatibility -SkillPath $installed
        Assert-True (-not $missing.compatible -and $missing.requiredUpdates -contains 'provider') 'an installed bundle cannot satisfy a missing sibling from the source catalog'
        $source = Join-Path (Split-Path -Parent $PSScriptRoot) 'skills/planning/harness-timer'
        Assert-SkillRuntimeCompatibility -SkillPath $source
        Write-Output 'Compatibility checks passed: same-version rejection, explicit companion updates, released claims, independent package versions, exact interfaces, and installation isolation.'
        return
    }

    $ownershipRoot = Join-Path $fixtureRoot 'ownership'
    $checkout = [pscustomobject]@{ kind = 'checkout'; path = $repositoryRoot; mode = 'Write'; snapshot = '' }
    $firstOwner = [pscustomobject]@{ controller = 'first'; task = 'T-001' }
    $secondOwner = [pscustomobject]@{ controller = 'second'; task = 'T-001' }
    $lease = Enter-SkillOwnership -Resources @($checkout) -Owner $firstOwner -Root $ownershipRoot
    try {
        try { $null = Enter-SkillOwnership -Resources @($checkout) -Owner $secondOwner -Root $ownershipRoot; throw 'A second writer acquired the checkout.' }
        catch {
            Assert-True ($_.Exception.Data['SkillOwnershipStatus'] -ceq 'Busy') 'cross-controller contention returns Busy'
            Assert-True ($_.Exception.Data['SkillOwnershipOwner'].controller -ceq 'first') 'contention identifies the original owner'
        }
        $helper = Join-Path (Split-Path -Parent $PSScriptRoot) 'skills/core/skillvault-installation/scripts/skill-ownership.ps1'
        $childCode = '. $args[0]; try { $lease = Enter-SkillOwnership -Resources @([pscustomobject]@{ kind = "checkout"; path = $args[1]; mode = "Write" }) -Owner @{ controller = "child" } -Root $args[2]; Exit-SkillOwnership $lease; exit 9 } catch { [Console]::Write($_.Exception.Data["SkillOwnershipStatus"]); exit 0 }'
        $childResult = & pwsh -NoProfile -NonInteractive -CommandWithArgs $childCode $helper $repositoryRoot $ownershipRoot
        Assert-True ($LASTEXITCODE -eq 0 -and $childResult -ceq 'Busy') 'the ownership gate excludes writers in another process'
        $independent = Enter-SkillOwnership -Resources @([pscustomobject]@{ kind = 'checkout'; path = $projectRoot; mode = 'Write' }) -Owner $secondOwner -Root $ownershipRoot
        Exit-SkillOwnership $independent
        Assert-True (Test-Throws { Clear-SkillOwnership -Id $lease.id -ConfirmStopped -Root $ownershipRoot }) 'even explicit recovery cannot steal an active claim'
    }
    finally { Exit-SkillOwnership $lease }
    $checkout.mode = 'Read'
    $checkout.snapshot = 'snapshot-one'
    $reader = Enter-SkillOwnership -Resources @($checkout) -Owner $firstOwner -Root $ownershipRoot
    try {
        $secondReader = Enter-SkillOwnership -Resources @($checkout) -Owner $secondOwner -Root $ownershipRoot
        Exit-SkillOwnership $secondReader
        $checkout.snapshot = 'snapshot-two'
        Assert-True (Test-Throws { Enter-SkillOwnership -Resources @($checkout) -Owner $secondOwner -Root $ownershipRoot }) 'different snapshots cannot share a checkout'
        $checkout.mode = 'Write'
        Assert-True (Test-Throws { Enter-SkillOwnership -Resources @($checkout) -Owner $secondOwner -Root $ownershipRoot }) 'readers exclude writers'
    }
    finally { Exit-SkillOwnership $reader }
    $lease = Enter-SkillOwnership -Resources @($checkout) -Owner $firstOwner -Root $ownershipRoot
    Exit-SkillOwnership $lease -Uncertain
    try { $null = Enter-SkillOwnership -Resources @($checkout) -Owner $secondOwner -Root $ownershipRoot; throw 'An uncertain claim was ignored.' }
    catch { Assert-True ($_.Exception.Data['SkillOwnershipStatus'] -ceq 'NeedsRecovery') 'uncertain ownership is not automatically reclaimed' }
    Assert-True (Test-Throws { Clear-SkillOwnership -Id $lease.id -Root $ownershipRoot }) 'uncertain claims need explicit stopped-worker confirmation'
    Clear-SkillOwnership -Id $lease.id -ConfirmStopped -Root $ownershipRoot
    $lease = Enter-SkillOwnership -Resources @($checkout) -Owner $secondOwner -Root $ownershipRoot
    Exit-SkillOwnership $lease
    $lease = Enter-SkillOwnership -Resources @($checkout) -Owner $firstOwner -Root $ownershipRoot
    $registryFunction = (Get-Command Enter-SkillOwnershipRegistry).ScriptBlock
    function Enter-SkillOwnershipRegistry { throw 'Injected registry release failure' }
    try { Assert-True (Test-Throws { Exit-SkillOwnership $lease }) 'a registry cleanup failure remains visible' }
    finally { Set-Item -LiteralPath Function:Enter-SkillOwnershipRegistry -Value $registryFunction }
    Assert-True (-not $lease.stream.CanRead) 'registry cleanup failure still closes the process-held claim handle'
    Assert-True (Test-Path -LiteralPath (Join-Path $ownershipRoot ($lease.id + '.json'))) 'failed cleanup retains recoverable claim evidence'
    Clear-SkillOwnership -Id $lease.id -ConfirmStopped -Root $ownershipRoot
    Assert-True (@(Get-ChildItem -LiteralPath $ownershipRoot -File).Count -eq 0) 'released claims leave no stale ownership evidence'
    $runtimeResources = @(Get-SkillRuntimeResources (Join-Path (Split-Path -Parent $PSScriptRoot) 'skills/planning/harness'))
    Assert-True (@($runtimeResources | Where-Object { $_.path -like '*SKILLVAULT-INSTALLATION' }).Count -eq 1) 'source runtime ownership includes its installer dependency exactly once'
    $legacyRoot = Join-Path $fixtureRoot 'legacy-runtime'
    $legacyRuntime = New-FixtureSkill -RepositoryRoot $legacyRoot -RelativePath harness -SkillName harness -Version '1.0.0' -DefaultScope global
    $legacyManifest = Get-Content -LiteralPath (Join-Path $legacyRuntime 'skill.json') -Raw | ConvertFrom-Json
    $legacyManifest | Add-Member -NotePropertyName dependencies -NotePropertyValue @('beta')
    $legacyManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $legacyRuntime 'skill.json')
    $legacyDependency = New-FixtureSkill -RepositoryRoot $legacyRoot -RelativePath beta -SkillName beta -Version '1.0.0' -DefaultScope global
    'old dependency content' | Set-Content -LiteralPath (Join-Path $legacyDependency 'original.txt')
    $replacement = New-FixtureSkill -RepositoryRoot $fixtureRoot -RelativePath replacement -SkillName beta -Version '1.0.0' -DefaultScope global
    $replacementMetadata = New-FixtureMetadata -SourcePath skills/core/beta -Scope global -Version '1.0.0'
    Assert-True (Test-Throws { Copy-SkillInstallation -Source $replacement -TargetRoot $legacyRoot -Name beta -Metadata $replacementMetadata -Force }) 'unknown older runtime ownership is not treated as idle'
    $activeLegacy = Enter-SkillOwnership -Resources @([pscustomobject]@{ kind = 'runtime'; path = $legacyDependency; mode = 'Read' }) -Owner @{ controller = 'active legacy fixture' }
    try { Assert-True (Test-Throws { Copy-SkillInstallation -Source $replacement -TargetRoot $legacyRoot -Name beta -Metadata $replacementMetadata -Force -ConfirmStopped }) 'ConfirmStopped cannot bypass active ownership' }
    finally { Exit-SkillOwnership $activeLegacy }
    $transition = Copy-SkillInstallation -Source $replacement -TargetRoot $legacyRoot -Name beta -Metadata $replacementMetadata -Force -ConfirmStopped
    Assert-True ((Test-SkillContentEqual $replacement $legacyDependency) -and -not $transition.RecoveryBackup) 'a confirmed legacy transition leaves the current dependency only'
    Assert-True (-not (Test-Path $env:SKILLVAULT_TRANSACTION_ROOT) -and -not (Test-Path $env:SKILLVAULT_RECOVERY_ROOT)) 'a completed transition retains no obsolete copies'
    Assert-True ((Get-InstallResidue -Root $legacyRoot).Count -eq 0) 'a completed update leaves no discovered temporary bundle'
    $updateLease = Enter-SkillUpdateOwnership -Paths @($legacyDependency) -ConfirmStopped
    $duringUpdate = $legacyDependency + '-during-update'
    try {
        Move-Item -LiteralPath $legacyDependency -Destination $duringUpdate
        $blocked = $false
        try { $unexpected = Enter-SkillRuntimeOwnership -SkillPath $legacyRuntime -Owner @{ controller = 'starting during update' }; Exit-SkillOwnership $unexpected }
        catch { $blocked = $_.Exception.Data['SkillOwnershipStatus'] -ceq 'Busy' }
        Assert-True $blocked 'a temporarily absent dependency cannot hide its active update reservation'
    }
    finally {
        Move-Item -LiteralPath $duringUpdate -Destination $legacyDependency
        Exit-SkillOwnership $updateLease
    }
    Write-Output 'Ownership checks passed: cross-controller exclusion, shared snapshots, independent checkouts, owner reporting, and explicit recovery.'
    if ($OwnershipOnly) { return }

    $alphaSource = New-FixtureSkill -RepositoryRoot $repositoryRoot -RelativePath 'skills/core/alpha' -SkillName 'alpha' -Version $null -DefaultScope 'project'
    $betaSource = New-FixtureSkill -RepositoryRoot $repositoryRoot -RelativePath 'skills/core/beta' -SkillName 'beta' -Version '1.0.0' -DefaultScope 'global'
    New-FixtureSkill -RepositoryRoot $repositoryRoot -RelativePath 'skills/core/gamma' -SkillName 'gamma' -Version '1.0.0' -DefaultScope 'session' | Out-Null

    New-Item -ItemType Directory -Path (Join-Path $alphaSource 'nested\deep'), (Join-Path $alphaSource '.git') -Force | Out-Null
    [System.IO.File]::WriteAllBytes((Join-Path $alphaSource 'nested\deep\payload.bin'), [byte[]](0, 1, 2, 250, 255))
    'gitdir metadata' | Set-Content -LiteralPath (Join-Path $alphaSource '.git\config') -Encoding utf8

    ConvertTo-Json -Depth 5 -InputObject @(
        [ordered]@{ name = 'alpha'; description = 'Fixture alpha'; path = 'skills/core/alpha'; version = $null },
        [ordered]@{ name = 'beta'; description = 'Fixture beta'; path = 'skills/core/beta'; version = '1.0.0' },
        [ordered]@{ name = 'gamma'; description = 'Fixture gamma'; path = 'skills/core/gamma'; version = '1.0.0' }
    ) | Set-Content -LiteralPath (Join-Path $repositoryRoot 'catalog.json') -Encoding utf8

    & $installScript -Name 'alpha', 'beta' -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot | Out-Null

    $alphaTarget = Join-Path $projectRoot '.github\skills\alpha'
    $betaTarget = Join-Path $globalRoot 'beta'
    Assert-True (Test-Path -LiteralPath $alphaTarget) 'project default scope installs under .github/skills'
    Assert-True (Test-Path -LiteralPath $betaTarget) 'global default scope installs under the global skills root'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $alphaTarget '.git'))) 'source .git directory is excluded'
    Assert-True (Test-SkillContentEqual -Source $alphaSource -Target $alphaTarget) 'nested and binary content is copied byte for byte'

    $alphaMetadata = Get-Content -LiteralPath (Join-Path $alphaTarget '.skillvault-install.json') -Raw | ConvertFrom-Json
    Assert-True ('installedVersion' -in $alphaMetadata.PSObject.Properties.Name) 'install metadata keeps installedVersion'
    Assert-True ($null -eq $alphaMetadata.installedVersion) 'an unversioned manifest records installedVersion as null'
    Assert-True ($alphaMetadata.installedBy -eq 'skillvault') 'install metadata records installedBy'
    Assert-True ($alphaMetadata.scope -eq 'project' -and $alphaMetadata.requestedVersion -eq 'latest') 'install metadata records scope and requested version'
    Assert-True ($alphaMetadata.sourcePath -eq 'skills/core/alpha') 'install metadata records the catalog source path'
    Assert-True ((Get-Content -LiteralPath (Join-Path $betaTarget '.skillvault-install.json') -Raw | ConvertFrom-Json).installedVersion -eq '1.0.0') 'a versioned manifest records its version'

    $betaGlobalMetadata = [System.IO.File]::ReadAllText((Join-Path $betaTarget '.skillvault-install.json'))
    & $installScript -Name 'beta' -Scope project -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot | Out-Null
    $betaProjectTarget = Join-Path $projectRoot '.github\skills\beta'
    Assert-True (Test-SkillContentEqual -Source $betaSource -Target $betaProjectTarget) 'an explicit project scope overrides a global default'
    Assert-True ((Get-Content -LiteralPath (Join-Path $betaProjectTarget '.skillvault-install.json') -Raw | ConvertFrom-Json).scope -ceq 'project') 'the explicit scope is recorded in the project copy'
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $betaTarget '.skillvault-install.json')) -ceq $betaGlobalMetadata) 'a project override leaves the existing global installation untouched'

    Assert-True (Test-Throws { & $installScript -Name 'alpha' -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot }) 'reinstalling without -Force fails'
    & $installScript -Name 'alpha' -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot -Force | Out-Null
    Assert-True (Test-SkillContentEqual -Source $alphaSource -Target $alphaTarget) 'forced reinstall keeps content identical'

    Assert-True (Test-Throws { & $installScript -Name 'gamma' -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot }) 'session default scope is rejected'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.github\skills\gamma'))) 'session default scope copies nothing'

    'marker' | Set-Content -LiteralPath (Join-Path $alphaTarget 'marker.txt') -Encoding utf8
    'marker' | Set-Content -LiteralPath (Join-Path $betaTarget 'marker.txt') -Encoding utf8
    Assert-True (Test-Throws { & $installScript -Name 'alpha', 'absent-skill' -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot -Force }) 'an unknown name fails preflight'
    Assert-True (Test-Path -LiteralPath (Join-Path $alphaTarget 'marker.txt')) 'a failed preflight writes nothing'

    $brokenSource = Join-Path $fixtureRoot 'broken'
    New-Item -ItemType Directory -Path $brokenSource -Force | Out-Null
    '{"name":"alpha","version":"1.0.0"}' | Set-Content -LiteralPath (Join-Path $brokenSource 'skill.json') -Encoding utf8
    $projectSkillsRoot = Join-Path $projectRoot '.github\skills'
    Assert-True (Test-Throws { Copy-SkillInstallation -Source $brokenSource -TargetRoot $projectSkillsRoot -Name 'alpha' -Metadata (New-FixtureMetadata -SourcePath 'skills/core/alpha' -Scope 'project' -Version '1.0.0') -Force }) 'a source without SKILL.md is rejected'
    Assert-True (Test-Path -LiteralPath (Join-Path $alphaTarget 'marker.txt')) 'a rejected source leaves the existing install intact'
    Assert-True (Test-Throws { Copy-SkillInstallation -Source $betaSource -TargetRoot $globalRoot -Name 'beta' -Metadata (New-FixtureMetadata -SourcePath 'skills/core/beta' -Scope 'global' -Version '9.9.9') -Force }) 'metadata that disagrees with the manifest version is rejected'

    $betaMetadata = New-FixtureMetadata -SourcePath 'skills/core/beta' -Scope 'global' -Version '1.0.0'

    $runtimeLease = Enter-SkillOwnership -Resources @([pscustomobject]@{ kind = 'runtime'; path = $betaTarget; mode = 'Read' }) -Owner ([pscustomobject]@{ controller = 'active runtime fixture' })
    try {
        Assert-True (Test-Throws { & $installScript -Name alpha,beta -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot -Force }) 'an active runtime blocks the complete selected replacement set'
        Assert-True (Test-Path -LiteralPath (Join-Path $alphaTarget 'marker.txt')) 'a later busy dependency cannot leave an earlier replacement applied'
    }
    finally { Exit-SkillOwnership $runtimeLease }

    function global:Copy-Item {
        param([string]$LiteralPath, [string]$Destination)
        throw 'injected copy failure'
    }
    $copyFailed = Test-Throws { Copy-SkillInstallation -Source $betaSource -TargetRoot $globalRoot -Name 'beta' -Metadata $betaMetadata -Force }
    Remove-Item -LiteralPath 'Function:\Copy-Item' -Force
    Assert-True $copyFailed 'a staging copy failure surfaces as an error'
    Assert-True (Test-Path -LiteralPath (Join-Path $betaTarget 'marker.txt')) 'a staging copy failure keeps the original install'
    Assert-True ((Get-InstallResidue -Root $globalRoot).Count -eq 0) 'a staging copy failure leaves no residue'

    function global:Move-Item {
        param([string]$LiteralPath, [string]$Destination, [switch]$Force)
        if ($LiteralPath -like '*.skillvault-stage-*') { throw 'injected move failure' }
        Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force
    }
    $swapFailed = Test-Throws { Copy-SkillInstallation -Source $betaSource -TargetRoot $globalRoot -Name 'beta' -Metadata $betaMetadata -Force }
    Remove-Item -LiteralPath 'Function:\Move-Item' -Force
    Assert-True $swapFailed 'a failed final swap surfaces as an error'
    Assert-True (Test-Path -LiteralPath (Join-Path $betaTarget 'marker.txt')) 'a failed final swap restores the original install'
    Assert-True ((Get-InstallResidue -Root $globalRoot).Count -eq 0) 'a restored swap leaves no residue'

    $global:fixturePartialSwapReached = $false
    function global:Move-Item {
        param([string]$LiteralPath, [string]$Destination, [switch]$Force)
        if ($LiteralPath -like '*.skillvault-stage-*') {
            $global:fixturePartialSwapReached = $true
            New-Item -ItemType Directory -Path $Destination -Force | Out-Null
            throw 'injected partial move failure'
        }
        Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force
    }
    $partialSwapFailed = Test-Throws { Copy-SkillInstallation -Source $betaSource -TargetRoot $globalRoot -Name 'beta' -Metadata $betaMetadata -Force }
    Remove-Item -LiteralPath 'Function:\Move-Item' -Force
    Assert-True ($partialSwapFailed -and $global:fixturePartialSwapReached) 'the partial swap failure is exercised'
    Assert-True (Test-Path -LiteralPath (Join-Path $betaTarget 'marker.txt')) 'partial swap rollback restores the original files'
    Assert-True (-not (Test-Path $env:SKILLVAULT_TRANSACTION_ROOT) -and -not (Test-Path $env:SKILLVAULT_RECOVERY_ROOT)) 'completed rollback leaves no retained copies'

    foreach ($rejectedPath in @('../outside', 'skills/../../outside', 'skills/./core', 'skills//core', '/etc/passwd', 'C:\Windows', 'skills/core/missing')) {
        Assert-True (Test-Throws { Resolve-SkillSourcePath -RepositoryRoot $repositoryRoot -SourcePath $rejectedPath }) "source path is rejected: $rejectedPath"
    }
    Assert-True ((Resolve-SkillSourcePath -RepositoryRoot $repositoryRoot -SourcePath 'skills/core/alpha') -eq (Get-Item -LiteralPath $alphaSource).FullName) 'a canonical relative source path resolves inside the repository'

    Assert-True (Test-Throws { Copy-SkillInstallation -Source $alphaSource -TargetRoot (Split-Path -Parent $alphaSource) -Name 'alpha' -Metadata (New-FixtureMetadata -SourcePath 'skills/core/alpha' -Scope 'project' -Version $null) -Force }) 'an overlapping source and target is rejected'

    $catalogRepository = Split-Path -Parent $PSScriptRoot
    # A reference installs by fetching its original from the network; the sync test covers that with local repositories.
    $catalogEntries = @(Get-Content -LiteralPath (Join-Path $catalogRepository 'catalog.json') -Raw | ConvertFrom-Json | Where-Object {
        [string](Get-Content -LiteralPath (Join-Path $catalogRepository "$($_.path)/skill.json") -Raw | ConvertFrom-Json).install.strategy -cne 'upstream'
    })
    $catalogGlobalRoot = Join-Path $fixtureRoot 'catalog-global'
    $catalogProjectRoot = Join-Path $fixtureRoot 'catalog-project'
    New-Item -ItemType Directory -Path $catalogGlobalRoot, $catalogProjectRoot -Force | Out-Null
    & $installScript -Name @($catalogEntries.name) -RepoRoot $catalogRepository -ProjectPath $catalogProjectRoot -GlobalSkillsPath $catalogGlobalRoot | Out-Null
    foreach ($entry in $catalogEntries) {
        $source = Join-Path $catalogRepository $entry.path
        $manifest = Get-Content -LiteralPath (Join-Path $source 'skill.json') -Raw | ConvertFrom-Json
        $defaultScope = [string]$manifest.install.defaultScope
        Assert-True ($defaultScope -in @('global', 'project') -and $manifest.install.$defaultScope -eq $true) "catalog default selects a supported installation scope for '$($entry.name)'"
        $targetRoot = if ($defaultScope -eq 'global') { $catalogGlobalRoot } else { Join-Path $catalogProjectRoot '.github/skills' }
        $target = Join-Path $targetRoot $entry.name
        Assert-True (Test-SkillContentEqual -Source $source -Target $target) "default install copies every '$($entry.name)' file"
        $metadata = Get-Content -LiteralPath (Join-Path $target '.skillvault-install.json') -Raw | ConvertFrom-Json
        Assert-True ($metadata.scope -ceq $defaultScope -and $metadata.sourcePath -ceq $entry.path -and $metadata.installedVersion -ceq $entry.version) "default installation metadata matches '$($entry.name)'"
    }
    $sharedDispatcher = Join-Path $catalogGlobalRoot 'harness/scripts/harness.ps1'
    $secondProject = Join-Path $fixtureRoot 'second-catalog-project'
    New-Item -ItemType Directory -Path $secondProject | Out-Null
    $projectIds = @()
    foreach ($project in @($catalogProjectRoot, $secondProject)) {
        $statusJson = & pwsh -NoProfile -NonInteractive -File $sharedDispatcher -ProjectPath $project -Action Status
        Assert-True ($LASTEXITCODE -eq 0) 'the globally installed dispatcher reads project status'
        $status = $statusJson | ConvertFrom-Json
        Assert-True (-not $status.initialized -and $status.project -eq $project -and -not (Test-Path -LiteralPath (Join-Path $project '.harness_sv'))) 'global skill availability does not initialize a project'
        $configJson = & pwsh -NoProfile -NonInteractive -File $sharedDispatcher -ProjectPath $project -Action Init -ConfirmLocation
        Assert-True ($LASTEXITCODE -eq 0) 'the global dispatcher initializes only an explicitly selected fixture project'
        $projectConfig = $configJson | ConvertFrom-Json
        Assert-True ($projectConfig.projectRoot -eq $project -and (Test-Path -LiteralPath (Join-Path $project '.harness_sv/runtime/state.json')) -and
            (Test-Path -LiteralPath (Join-Path $project '.harness_sv/config/project.json')) -and -not (Test-Path -LiteralPath (Join-Path $project '.harness_sv/config.json'))) 'runtime records stay in the selected fixture project'
        $projectIds += $projectConfig.projectId
    }
    Assert-True ($projectIds[0] -cne $projectIds[1] -and -not (Test-Path -LiteralPath (Join-Path $catalogGlobalRoot '.harness_sv')) -and -not (Test-Path -LiteralPath (Join-Path $catalogGlobalRoot 'harness/.harness_sv'))) 'one global runtime preserves separate project identities and stores no runtime state in its installation'
    Write-Output "Catalog default installation checks passed for $($catalogEntries.Count) skills; shared global runtime preserves two isolated fixture projects."

    $migrationGlobal = Join-Path $fixtureRoot 'migration-global'
    $migrationProject = Join-Path $fixtureRoot 'migration-project'
    $legacyFolder = Join-Path $migrationGlobal 'harness-root'
    New-Item -ItemType Directory -Path $legacyFolder, $migrationProject -Force | Out-Null
    '{"name":"harness-root","version":"1.0.0"}' | Set-Content -LiteralPath (Join-Path $legacyFolder 'skill.json')
    '# Legacy fixture with preserved custom guidance' | Set-Content -LiteralPath (Join-Path $legacyFolder 'SKILL.md')
    (New-FixtureMetadata -SourcePath 'skills/public/planning/harness-root' -Scope global -Version '1.0.0') | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $legacyFolder '.skillvault-install.json')
    $migrationScript = Join-Path $catalogRepository 'skills/core/skillvault-installation/scripts/migrate-topics.ps1'
    $fullNames = @('skillvault-authoring', 'skillvault-discovery', 'skillvault-installation', 'skillvault-refresh')
    foreach ($fullName in $fullNames) {
        $shortName = if ($fullName -eq 'skillvault-authoring') { 'sv-source' } else { $fullName -replace '^skillvault-', 'sv-' }
        $catalogEntry = $catalogEntries | Where-Object name -CEQ $fullName
        $shortPath = New-FixtureSkill -RepositoryRoot $migrationGlobal -RelativePath $shortName -SkillName $shortName -Version $catalogEntry.version -DefaultScope global
        (New-FixtureMetadata -SourcePath "skills/public/core/$shortName" -Scope global -Version $catalogEntry.version) | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $shortPath '.skillvault-install.json')
    }
    $formerSourcePath = New-FixtureSkill -RepositoryRoot $migrationGlobal -RelativePath 'skillvault-source' -SkillName 'skillvault-source' -Version '1.0.0' -DefaultScope global
    (New-FixtureMetadata -SourcePath 'skills/public/core/skillvault-source' -Scope global -Version '1.0.0') | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $formerSourcePath '.skillvault-install.json')
    $legacyBefore = [IO.File]::ReadAllText((Join-Path $legacyFolder 'SKILL.md'))
    $namingPreview = & $migrationScript -ProjectPath $migrationProject -RepoPath $catalogRepository -Scope global -GlobalSkillsPath $migrationGlobal -Name $fullNames | ConvertFrom-Json
    Assert-True ($namingPreview.preview -and $namingPreview.install.Count -eq 4 -and $namingPreview.retire.Count -eq 5 -and -not (Test-Path (Join-Path $migrationGlobal 'skillvault-installation'))) 'selected naming migration previews the four management topics and retires both former authoring names'
    Assert-True (Test-Throws { & $migrationScript -ProjectPath $migrationProject -RepoPath $catalogRepository -Scope global -GlobalSkillsPath $migrationGlobal -Name 'absent-skill' -Apply -Force }) 'unknown canonical migration names are rejected before writes'
    Assert-True (Test-Throws { & $migrationScript -ProjectPath $migrationProject -RepoPath $catalogRepository -Scope global -GlobalSkillsPath $migrationGlobal -Name $fullNames -Apply -Force }) 'legacy runtime migration requires explicit stopped-worker confirmation'
    Assert-True (-not (Test-Path (Join-Path $migrationGlobal 'skillvault-authoring'))) 'an unconfirmed transition writes no replacement'
    $namingResult = & $migrationScript -ProjectPath $migrationProject -RepoPath $catalogRepository -Scope global -GlobalSkillsPath $migrationGlobal -Name $fullNames -Apply -Force -ConfirmStopped | ConvertFrom-Json
    Assert-True ($namingResult.backups.Count -eq 0 -and -not (Test-Path $env:SKILLVAULT_TRANSACTION_ROOT) -and (Get-InstallResidue $migrationGlobal).Count -eq 0) 'completed topic migration retains no archives'
    foreach ($fullName in $fullNames) {
        $shortName = if ($fullName -eq 'skillvault-authoring') { 'sv-source' } else { $fullName -replace '^skillvault-', 'sv-' }
        Assert-True (-not (Test-Path (Join-Path $migrationGlobal $shortName)) -and (Test-Path (Join-Path $migrationGlobal "$fullName/SKILL.md"))) 'full names replace short registered folders'
    }
    Assert-True (-not (Test-Path -LiteralPath $formerSourcePath)) 'the former full authoring name is retired after replacements verify'
    Assert-True ([IO.File]::ReadAllText((Join-Path $legacyFolder 'SKILL.md')) -ceq $legacyBefore) 'a selected naming migration leaves unselected topics untouched'
    & (Join-Path $PSScriptRoot 'verify-installed-skills.ps1') -RepoRoot $catalogRepository -SkillsPath $migrationGlobal -Name $fullNames | Out-Null
    $repeatNaming = & $migrationScript -ProjectPath $migrationProject -RepoPath $catalogRepository -Scope global -GlobalSkillsPath $migrationGlobal -Name $fullNames | ConvertFrom-Json
    Assert-True ($repeatNaming.install.Count -eq 0 -and $repeatNaming.retire.Count -eq 0) 'selected migration does not refresh already identical copies'
    $shortPath = New-FixtureSkill -RepositoryRoot $migrationGlobal -RelativePath 'sv-installation' -SkillName 'sv-installation' -Version '1.1.0' -DefaultScope global
    (New-FixtureMetadata -SourcePath 'skills/public/core/sv-installation' -Scope global -Version '1.1.0') | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $shortPath '.skillvault-install.json')
    $fullMetadata = [IO.File]::ReadAllText((Join-Path $migrationGlobal 'skillvault-installation/.skillvault-install.json'))
    $retireOnly = & $migrationScript -ProjectPath $migrationProject -RepoPath $catalogRepository -Scope global -GlobalSkillsPath $migrationGlobal -Name 'skillvault-installation' -Apply -Force | ConvertFrom-Json
    Assert-True ($retireOnly.install.Count -eq 0 -and $retireOnly.retire.Count -eq 1 -and $retireOnly.backups.Count -eq 0 -and -not (Test-Path $shortPath)) 'a short-name duplicate is retired when the full-name copy is already current'
    Assert-True ([IO.File]::ReadAllText((Join-Path $migrationGlobal 'skillvault-installation/.skillvault-install.json')) -ceq $fullMetadata) 'retiring a duplicate does not rewrite the current full-name metadata'
    $migrationPreview = & $migrationScript -ProjectPath $migrationProject -RepoPath $catalogRepository -Scope global -GlobalSkillsPath $migrationGlobal | ConvertFrom-Json
    Assert-True ($migrationPreview.preview -and $migrationPreview.retire[0].oldName -eq 'harness-root' -and -not (Test-Path (Join-Path $migrationGlobal 'harness'))) 'topic migration preview writes nothing and maps exact legacy names'
    $migrationResult = & $migrationScript -ProjectPath $migrationProject -RepoPath $catalogRepository -Scope global -GlobalSkillsPath $migrationGlobal -Apply -Force -ConfirmStopped | ConvertFrom-Json
    Assert-True (-not (Test-Path -LiteralPath $legacyFolder) -and (Test-Path (Join-Path $migrationGlobal 'harness/SKILL.md'))) 'approved migration replaces the legacy registration with the canonical topic'
    Assert-True ($migrationResult.backups.Count -eq 0 -and -not (Test-Path $env:SKILLVAULT_TRANSACTION_ROOT)) 'migration leaves only the approved canonical copies'

    $scopedNames = @('skillvault-authoring', 'skillvault-installation')
    & $installScript -Name $scopedNames -RepoRoot $catalogRepository -ProjectPath $migrationProject -Scope project | Out-Null
    $global:fixtureUnchangedTarget = Join-Path $migrationGlobal 'skillvault-installation'
    'stale' | Set-Content (Join-Path $migrationGlobal 'skillvault-authoring/stale.txt')
    foreach ($name in $scopedNames) { 'stale' | Set-Content (Join-Path $migrationProject ".github/skills/$name/stale.txt") }
    function global:Copy-Item {
        param([string]$LiteralPath, [string]$Destination, [switch]$Recurse, [switch]$Force)
        if ($LiteralPath -ieq $global:fixtureUnchangedTarget) { throw 'An unchanged, unreserved copy must not enter the rollback transaction.' }
        Microsoft.PowerShell.Management\Copy-Item @PSBoundParameters
    }
    try {
        $scopedResult = & $migrationScript -ProjectPath $migrationProject -RepoPath $catalogRepository -Scope all -GlobalSkillsPath $migrationGlobal -Name $scopedNames -Apply -Force | ConvertFrom-Json
        Assert-True ($scopedResult.install.Count -eq 3 -and -not (Test-Path $env:SKILLVAULT_TRANSACTION_ROOT)) 'cross-scope migration protects only the three exact replacement targets'
    }
    finally {
        Remove-Item Function:\Copy-Item
        Remove-Variable fixtureUnchangedTarget -Scope Global
    }
    & (Join-Path $PSScriptRoot 'verify-installed-skills.ps1') -RepoRoot $catalogRepository -SkillsPath $migrationGlobal -Name $scopedNames | Out-Null
    & (Join-Path $PSScriptRoot 'verify-installed-skills.ps1') -RepoRoot $catalogRepository -SkillsPath (Join-Path $migrationProject '.github/skills') -Name $scopedNames | Out-Null

    # Real Git with isolated settings: a pin reads the skill's own tag and leaves the checkout as it was.
    $env:GIT_CONFIG_GLOBAL = Join-Path $fixtureRoot 'gitconfig'
    $env:GIT_CONFIG_NOSYSTEM = '1'
    New-Item -ItemType File -Path $env:GIT_CONFIG_GLOBAL -Force | Out-Null
    foreach ($setting in @(@('user.name', 'SkillVault Fixture'), @('user.email', 'fixture@example.invalid'), @('core.autocrlf', 'false'), @('init.defaultBranch', 'main'))) {
        git config --global $setting[0] $setting[1]
    }
    $tagRepository = Join-Path $fixtureRoot 'tag-repo'
    $tagGlobal = Join-Path $fixtureRoot 'tag-global'
    $tagSkill = Join-Path $tagRepository 'skills\core\alpha'
    $tagCatalog = Join-Path $tagRepository 'catalog.json'
    function Invoke-TagGit {
        $ErrorActionPreference = 'Continue'
        $output = @(git -C $tagRepository @args 2>&1 | ForEach-Object { [string]$_ })
        if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed: $($output -join ' ')" }
        return $output
    }
    $null = New-FixtureSkill -RepositoryRoot $tagRepository -RelativePath 'skills/core/alpha' -SkillName 'alpha' -Version '1.0.0' -DefaultScope 'global'
    'released notes' | Set-Content -LiteralPath (Join-Path $tagSkill 'notes.md') -Encoding utf8
    ConvertTo-Json -Depth 5 -InputObject @([ordered]@{ name = 'alpha'; description = 'Fixture alpha'; path = 'skills/core/alpha'; version = '1.0.0' }) | Set-Content -LiteralPath $tagCatalog -Encoding utf8
    Invoke-TagGit init -q | Out-Null
    Invoke-TagGit add --all | Out-Null
    Invoke-TagGit commit -q -m 'alpha 1.0.0' | Out-Null
    Invoke-TagGit tag -a alpha/v1.0.0 -m 'alpha 1.0.0' | Out-Null
    $releasedCopy = Join-Path $fixtureRoot 'alpha-1.0.0'
    Copy-Item -LiteralPath $tagSkill -Destination $releasedCopy -Recurse
    $null = New-FixtureSkill -RepositoryRoot $tagRepository -RelativePath 'skills/core/alpha' -SkillName 'alpha' -Version '1.1.0' -DefaultScope 'global'
    Remove-Item -LiteralPath (Join-Path $tagSkill 'notes.md')
    ConvertTo-Json -Depth 5 -InputObject @([ordered]@{ name = 'alpha'; description = 'Fixture alpha'; path = 'skills/core/alpha'; version = '1.1.0' }) | Set-Content -LiteralPath $tagCatalog -Encoding utf8
    Invoke-TagGit add --all | Out-Null
    Invoke-TagGit commit -q -m 'alpha 1.1.0' | Out-Null
    Invoke-TagGit tag -a alpha/v2.0.0 -m 'mislabeled' | Out-Null
    'staged' | Set-Content -LiteralPath (Join-Path $tagRepository 'staged.md')
    Invoke-TagGit add staged.md | Out-Null
    'uncommitted' | Set-Content -LiteralPath (Join-Path $tagSkill 'SKILL.md')
    $checkoutState = { (@(Invoke-TagGit symbolic-ref HEAD) + @(Invoke-TagGit rev-parse HEAD) + @(Invoke-TagGit status --porcelain)) -join '|' }
    $stateBefore = & $checkoutState

    $pinPreview = @(& $installScript -Name alpha -Scope global -RepoRoot $tagRepository -ProjectPath $projectRoot -GlobalSkillsPath $tagGlobal -RequestedVersion v1.0.0 -Preview | ConvertFrom-Json)
    Assert-True ($pinPreview[0].Tag -ceq 'alpha/v1.0.0' -and $pinPreview[0].PathAtTag -ceq 'skills/core/alpha' -and -not (Test-Path -LiteralPath $tagGlobal)) 'a pin preview names the skill tag and copies nothing'
    & $installScript -Name alpha -Scope global -RepoRoot $tagRepository -ProjectPath $projectRoot -GlobalSkillsPath $tagGlobal -RequestedVersion v1.0.0 | Out-Null
    $pinnedTarget = Join-Path $tagGlobal 'alpha'
    $pinnedMetadata = Get-Content -LiteralPath (Join-Path $pinnedTarget '.skillvault-install.json') -Raw | ConvertFrom-Json
    Assert-True (Test-SkillContentEqual -Source $releasedCopy -Target $pinnedTarget) 'a pin installs the files at its skill tag, not the current checkout'
    Assert-True ($pinnedMetadata.requestedVersion -ceq 'v1.0.0' -and $pinnedMetadata.installedVersion -ceq '1.0.0' -and $pinnedMetadata.sourcePath -ceq 'skills/core/alpha') 'pin metadata records the requested and installed versions'
    Assert-True ($pinnedMetadata.sourceRevision -ceq [string](Invoke-TagGit rev-parse 'alpha/v1.0.0:skills/core/alpha')) 'a pin records the tagged skill folder as its source revision'
    Assert-True ((& $checkoutState) -ceq $stateBefore) 'a pin leaves the branch, staged change, and uncommitted edit as they were'
    Assert-True (Test-Throws { & $installScript -Name alpha -Scope global -RepoRoot $tagRepository -ProjectPath $projectRoot -GlobalSkillsPath $tagGlobal -RequestedVersion v9.9.9 -Force }) 'a missing skill tag blocks installation'
    Assert-True (Test-Throws { & $installScript -Name alpha -Scope global -RepoRoot $tagRepository -ProjectPath $projectRoot -GlobalSkillsPath $tagGlobal -RequestedVersion v2.0.0 -Force }) 'a tag whose skill holds another version is rejected'
    Assert-True (Test-SkillContentEqual -Source $releasedCopy -Target $pinnedTarget) 'rejected pins leave the installed copy unchanged'
    $verifyScript = Join-Path $PSScriptRoot 'verify-installed-skills.ps1'
    Assert-True ((@(& $verifyScript -RepoRoot $tagRepository -SkillsPath $tagGlobal -Name alpha) -join ' ') -match '1 of them are pinned') 'verification compares a pinned copy with its own tag'
    'local edit' | Set-Content -LiteralPath (Join-Path $pinnedTarget 'notes.md')
    Assert-True (Test-Throws { & $verifyScript -RepoRoot $tagRepository -SkillsPath $tagGlobal -Name alpha }) 'verification reports a pinned copy that differs from its tag'

    Write-Output 'Install helper checks passed: scope routing, metadata, exclusions, preflight batching, staged rollback, and per-skill tag pins.'
}
finally {
    $env:SKILLVAULT_OWNERSHIP_ROOT = $savedFixtureOwnershipRoot
    $env:SKILLVAULT_RECOVERY_ROOT = $savedFixtureRecoveryRoot
    $env:SKILLVAULT_TRANSACTION_ROOT = $savedFixtureTransactionRoot
    $env:GIT_CONFIG_GLOBAL = $savedGitConfigGlobal
    $env:GIT_CONFIG_NOSYSTEM = $savedGitConfigNoSystem
    Remove-Variable -Name fixturePartialSwapReached -Scope Global -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath 'Function:\Copy-Item') { Remove-Item -LiteralPath 'Function:\Copy-Item' -Force }
    if (Test-Path -LiteralPath 'Function:\Move-Item') { Remove-Item -LiteralPath 'Function:\Move-Item' -Force }
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
