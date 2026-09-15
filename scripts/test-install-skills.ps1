$ErrorActionPreference = 'Stop'

$installScript = Join-Path $PSScriptRoot 'install-skills.ps1'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'skills\public\core\skillvault-install\scripts\skill-files.ps1')

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
$repositoryRoot = Join-Path $fixtureRoot 'repo'
$projectRoot = Join-Path $fixtureRoot 'project'
$globalRoot = Join-Path $fixtureRoot 'global'

try {
    New-Item -ItemType Directory -Path $repositoryRoot, $projectRoot, $globalRoot -Force | Out-Null

    $alphaSource = New-FixtureSkill -RepositoryRoot $repositoryRoot -RelativePath 'skills/public/core/alpha' -SkillName 'alpha' -Version $null -DefaultScope 'project'
    $betaSource = New-FixtureSkill -RepositoryRoot $repositoryRoot -RelativePath 'skills/public/core/beta' -SkillName 'beta' -Version '1.0.0' -DefaultScope 'global'
    New-FixtureSkill -RepositoryRoot $repositoryRoot -RelativePath 'skills/public/core/gamma' -SkillName 'gamma' -Version '1.0.0' -DefaultScope 'session' | Out-Null

    New-Item -ItemType Directory -Path (Join-Path $alphaSource 'nested\deep'), (Join-Path $alphaSource '.git') -Force | Out-Null
    [System.IO.File]::WriteAllBytes((Join-Path $alphaSource 'nested\deep\payload.bin'), [byte[]](0, 1, 2, 250, 255))
    'gitdir metadata' | Set-Content -LiteralPath (Join-Path $alphaSource '.git\config') -Encoding utf8

    ConvertTo-Json -Depth 5 -InputObject @(
        [ordered]@{ name = 'alpha'; description = 'Fixture alpha'; path = 'skills/public/core/alpha'; version = $null },
        [ordered]@{ name = 'beta'; description = 'Fixture beta'; path = 'skills/public/core/beta'; version = '1.0.0' },
        [ordered]@{ name = 'gamma'; description = 'Fixture gamma'; path = 'skills/public/core/gamma'; version = '1.0.0' }
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
    Assert-True ($alphaMetadata.sourcePath -eq 'skills/public/core/alpha') 'install metadata records the catalog source path'
    Assert-True ((Get-Content -LiteralPath (Join-Path $betaTarget '.skillvault-install.json') -Raw | ConvertFrom-Json).installedVersion -eq '1.0.0') 'a versioned manifest records its version'

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
    Assert-True (Test-Throws { Copy-SkillInstallation -Source $brokenSource -TargetRoot $projectSkillsRoot -Name 'alpha' -Metadata (New-FixtureMetadata -SourcePath 'skills/public/core/alpha' -Scope 'project' -Version '1.0.0') -Force }) 'a source without SKILL.md is rejected'
    Assert-True (Test-Path -LiteralPath (Join-Path $alphaTarget 'marker.txt')) 'a rejected source leaves the existing install intact'
    Assert-True (Test-Throws { Copy-SkillInstallation -Source $betaSource -TargetRoot $globalRoot -Name 'beta' -Metadata (New-FixtureMetadata -SourcePath 'skills/public/core/beta' -Scope 'global' -Version '9.9.9') -Force }) 'metadata that disagrees with the manifest version is rejected'

    $betaMetadata = New-FixtureMetadata -SourcePath 'skills/public/core/beta' -Scope 'global' -Version '1.0.0'

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
        param([string]$LiteralPath, [string]$Destination)
        if ($LiteralPath -like '*.skillvault-stage-*') { throw 'injected move failure' }
        Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination
    }
    $swapFailed = Test-Throws { Copy-SkillInstallation -Source $betaSource -TargetRoot $globalRoot -Name 'beta' -Metadata $betaMetadata -Force }
    Remove-Item -LiteralPath 'Function:\Move-Item' -Force
    Assert-True $swapFailed 'a failed final swap surfaces as an error'
    Assert-True (Test-Path -LiteralPath (Join-Path $betaTarget 'marker.txt')) 'a failed final swap restores the original install'
    Assert-True ((Get-InstallResidue -Root $globalRoot).Count -eq 0) 'a restored swap leaves no residue'

    function global:Move-Item {
        param([string]$LiteralPath, [string]$Destination)
        if ($LiteralPath -like '*.skillvault-stage-*') {
            New-Item -ItemType Directory -Path $Destination -Force | Out-Null
            throw 'injected partial move failure'
        }
        Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination
    }
    $partialSwapFailed = Test-Throws { Copy-SkillInstallation -Source $betaSource -TargetRoot $globalRoot -Name 'beta' -Metadata $betaMetadata -Force }
    Remove-Item -LiteralPath 'Function:\Move-Item' -Force
    $backups = @(Get-ChildItem -LiteralPath $globalRoot -Directory -Force | Where-Object { $_.Name -like '.skillvault-backup-*' })
    Assert-True ($partialSwapFailed -and $backups.Count -eq 1) 'a partial swap preserves the original backup'
    Assert-True (Test-Path -LiteralPath (Join-Path $backups[0].FullName 'marker.txt')) 'a preserved backup contains the original files'
    & (Join-Path $PSScriptRoot 'verify-installed-skills.ps1') -RepoRoot $repositoryRoot -SkillsPath $globalRoot | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $backups[0].FullName 'marker.txt')) 'parity checking leaves recovery backups untouched'

    foreach ($rejectedPath in @('../outside', 'skills/../../outside', 'skills/public/./core', 'skills/public//core', '/etc/passwd', 'C:\Windows', 'skills/public/core/missing')) {
        Assert-True (Test-Throws { Resolve-SkillSourcePath -RepositoryRoot $repositoryRoot -SourcePath $rejectedPath }) "source path is rejected: $rejectedPath"
    }
    Assert-True ((Resolve-SkillSourcePath -RepositoryRoot $repositoryRoot -SourcePath 'skills/public/core/alpha') -eq (Get-Item -LiteralPath $alphaSource).FullName) 'a canonical relative source path resolves inside the repository'

    Assert-True (Test-Throws { Copy-SkillInstallation -Source $alphaSource -TargetRoot (Split-Path -Parent $alphaSource) -Name 'alpha' -Metadata (New-FixtureMetadata -SourcePath 'skills/public/core/alpha' -Scope 'project' -Version $null) -Force }) 'an overlapping source and target is rejected'
    $global:fixtureTagHead = 'head'
    function global:git {
        $global:LASTEXITCODE = 0
        if ($args[2] -eq 'status') { return }
        if ($args[-1] -eq 'HEAD') { return $global:fixtureTagHead }
        return 'tag'
    }
    Assert-True (Test-Throws { & $installScript -Name 'alpha' -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot -RequestedVersion 'v1.2.0' -Force }) 'a tag not matching HEAD is rejected'
    $global:fixtureTagHead = 'tag'
    & $installScript -Name 'alpha' -RepoRoot $repositoryRoot -ProjectPath $projectRoot -GlobalSkillsPath $globalRoot -RequestedVersion 'v1.2.0' -Force | Out-Null
    Assert-True ((Get-Content -LiteralPath (Join-Path $alphaTarget '.skillvault-install.json') -Raw | ConvertFrom-Json).requestedVersion -eq 'v1.2.0') 'a verified tag remains pinned in metadata'

    Write-Output 'Install helper checks passed: scope routing, metadata, exclusions, preflight batching, and staged rollback.'
}
finally {
    if (Test-Path -LiteralPath 'Function:\git') { Remove-Item -LiteralPath 'Function:\git' -Force }
    Remove-Variable -Name fixtureTagHead -Scope Global -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath 'Function:\Copy-Item') { Remove-Item -LiteralPath 'Function:\Copy-Item' -Force }
    if (Test-Path -LiteralPath 'Function:\Move-Item') { Remove-Item -LiteralPath 'Function:\Move-Item' -Force }
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
