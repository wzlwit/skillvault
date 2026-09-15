[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$GlobalSkillsPath = (Join-Path $HOME '.copilot/skills'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\skills\public\core\skillvault-install\scripts\skill-files.ps1')

$canonicalSourceRepo = 'https://github.com/wzlwit/skillvault'
$sourceRepo = 'https://github.com/wzlwit/skillvault.git'
$installedBy = 'skillvault-bootstrap'
$requestedVersion = 'latest'

# Keep this list identical to bootstrap_skill_names in install-global.sh.
$bootstrapSkillNames = @(
    'skillvault-install',
    'skillvault-evaluate',
    'skillvault-fresh',
    'skillvault-list',
    'skillvault-remove',
    'skillvault-search',
    'skillvault-uninstall',
    'skillvault-upsert',
    'rules',
    'rules-core',
    'schedule-manager'
)

# name:source-path of installs earlier bootstrap runs created; keep identical to legacy_skill_entries in install-global.sh.
$legacySkillEntries = @(
    'skillvault:skills/public/core/skillvault',
    'sv-sync:skills/public/sv-sync',
    'skillvault-sync:skills/public/skillvault-sync',
    'ai-principles:skills/public/core/ai-principles',
    'rule-update:skills/public/core/rule-update'
)

function Get-SkillInstallMetadata {
    param([Parameter(Mandatory = $true)][string]$SkillPath)

    $metadataPath = Join-Path $SkillPath '.skillvault-install.json'
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) { return $null }

    try {
        $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }

    if ($metadata -isnot [System.Management.Automation.PSCustomObject]) { return $null }
    return $metadata
}

function Test-SkillVaultSourceRepo {
    param($Value)

    if ($null -eq $Value) { return $false }

    $repoUrl = ([string]$Value).Trim().TrimEnd('/')
    if ($repoUrl.EndsWith('.git', [System.StringComparison]::OrdinalIgnoreCase)) {
        $repoUrl = $repoUrl.Substring(0, $repoUrl.Length - 4)
    }

    return $repoUrl -eq $canonicalSourceRepo
}

function Test-SkillVaultManagedInstall {
    param($Metadata, [Parameter(Mandatory = $true)][string]$SourcePath)

    if ($null -eq $Metadata) { return $false }
    if (([string]$Metadata.installedBy) -cnotin @('skillvault', 'skillvault-bootstrap')) { return $false }
    if (([string]$Metadata.sourcePath) -cne $SourcePath) { return $false }

    return (Test-SkillVaultSourceRepo -Value $Metadata.sourceRepo)
}

function Test-CurrentBootstrapInstall {
    param($Metadata, [Parameter(Mandatory = $true)][string]$SourcePath, $Version)

    if (-not (Test-SkillVaultManagedInstall -Metadata $Metadata -SourcePath $SourcePath)) { return $false }
    if (([string]$Metadata.installedBy) -cne $installedBy) { return $false }
    if (([string]$Metadata.sourceRepo) -cne $sourceRepo) { return $false }
    if (([string]$Metadata.scope) -cne 'global') { return $false }
    if (([string]$Metadata.requestedVersion) -cne $requestedVersion) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$Metadata.installedAt)) { return $false }
    if ('installedVersion' -notin $Metadata.PSObject.Properties.Name) { return $false }

    return ($Metadata.installedVersion -ceq $Version)
}

$repositoryRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RepoRoot)
$catalogPath = Join-Path $repositoryRoot 'catalog.json'
if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
    throw "Missing catalog: $catalogPath"
}

$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$globalSkillsRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($GlobalSkillsPath)

$plannedInstalls = New-Object System.Collections.ArrayList
$preflightErrors = New-Object System.Collections.ArrayList

foreach ($skillName in $bootstrapSkillNames) {
    try {
        $catalogMatches = @($catalog | Where-Object { $_.name -ceq $skillName })
        if ($catalogMatches.Count -ne 1) {
            throw "Bootstrap skill '$skillName' was not found exactly once in $catalogPath."
        }

        $catalogEntry = $catalogMatches[0]
        $catalogSourcePath = [string]$catalogEntry.path
        $sourcePath = Resolve-SkillSourcePath -RepositoryRoot $repositoryRoot -SourcePath $catalogSourcePath
        $manifest = Read-SkillManifest -SkillPath $sourcePath -ExpectedName $skillName

        $defaultScope = ''
        if ($manifest.install) { $defaultScope = [string]$manifest.install.defaultScope }
        if ($defaultScope -cne 'global') {
            throw "Bootstrap skill '$skillName' must declare install.defaultScope 'global' but declares '$defaultScope'."
        }

        if ($manifest.version -cne $catalogEntry.version) {
            throw "Bootstrap skill '$skillName' manifest version '$($manifest.version)' does not match catalog version '$($catalogEntry.version)'."
        }

        $targetPath = Join-Path $globalSkillsRoot $skillName
        $action = 'install'

        if (Test-Path -LiteralPath $targetPath) {
            $targetItem = Get-Item -LiteralPath $targetPath -Force
            if ($targetItem -isnot [System.IO.DirectoryInfo]) {
                throw "Bootstrap target is not a directory: $targetPath"
            }
            if (Test-SkillReparsePoint -Item $targetItem) {
                throw "Bootstrap target is a reparse point and will not be replaced: $targetPath"
            }

            $metadata = Get-SkillInstallMetadata -SkillPath $targetPath
            if ((Test-CurrentBootstrapInstall -Metadata $metadata -SourcePath $catalogSourcePath -Version $manifest.version) -and
                (Test-SkillContentEqual -Source $sourcePath -Target $targetPath)) {
                $action = 'skip'
            }
            elseif (-not $Force) {
                $reason = 'Its installed content differs from the repository source.'
                if ($null -eq $metadata) {
                    $reason = 'It has no SkillVault install metadata, so this bootstrap does not manage it.'
                }
                elseif ((-not [string]::IsNullOrWhiteSpace([string]$metadata.requestedVersion)) -and
                    ([string]$metadata.requestedVersion) -cne $requestedVersion) {
                    $reason = "It is pinned to '$($metadata.requestedVersion)'."
                }
                elseif (-not (Test-SkillVaultManagedInstall -Metadata $metadata -SourcePath $catalogSourcePath)) {
                    $reason = 'It records a different source, so this bootstrap does not manage it.'
                }

                throw "Bootstrap skill '$skillName' is already installed at ${targetPath}. $reason Review it, then re-run with -Force to overwrite."
            }
        }

        [void]$plannedInstalls.Add([pscustomobject]@{
            Name = $skillName
            SourcePath = $sourcePath
            CatalogPath = $catalogSourcePath
            Version = $manifest.version
            TargetPath = $targetPath
            Action = $action
        })
    }
    catch {
        [void]$preflightErrors.Add($_.Exception.Message)
    }
}

if ($preflightErrors.Count -gt 0) {
    throw ('SkillVault bootstrap preflight failed; nothing was installed or removed:' + [Environment]::NewLine + ($preflightErrors -join [Environment]::NewLine))
}

foreach ($plannedInstall in $plannedInstalls) {
    if ($plannedInstall.Action -eq 'skip') {
        Write-Output "Already current: $($plannedInstall.TargetPath)"
        continue
    }

    $metadata = [ordered]@{
        installedBy = $installedBy
        sourceRepo = $sourceRepo
        sourcePath = $plannedInstall.CatalogPath
        scope = 'global'
        requestedVersion = $requestedVersion
        installedVersion = $plannedInstall.Version
        installedAt = (Get-Date).ToUniversalTime().ToString('o')
    }

    $installResult = Copy-SkillInstallation -Source $plannedInstall.SourcePath -TargetRoot $globalSkillsRoot -Name $plannedInstall.Name -Metadata $metadata -Force:$Force
    Write-Output "Installed SkillVault bootstrap skill: $($installResult.Path)"
}

foreach ($legacySkillEntry in $legacySkillEntries) {
    $separatorIndex = $legacySkillEntry.IndexOf(':')
    $legacyName = $legacySkillEntry.Substring(0, $separatorIndex)
    $legacySourcePath = $legacySkillEntry.Substring($separatorIndex + 1)
    $legacyPath = Join-Path $globalSkillsRoot $legacyName

    if (-not (Test-Path -LiteralPath $legacyPath)) { continue }

    $legacyItem = Get-Item -LiteralPath $legacyPath -Force
    if ($legacyItem -isnot [System.IO.DirectoryInfo] -or (Test-SkillReparsePoint -Item $legacyItem)) {
        Write-Output "Preserved unmanaged legacy skill: $legacyPath"
        continue
    }

    if (-not (Test-SkillVaultManagedInstall -Metadata (Get-SkillInstallMetadata -SkillPath $legacyPath) -SourcePath $legacySourcePath)) {
        Write-Output "Preserved unmanaged legacy skill: $legacyPath"
        continue
    }

    if ($legacyName -eq 'skillvault' -and -not $Force) {
        Write-Output "Preserved renamed installer: $legacyPath. Review it, then re-run with -Force to finish migration to skillvault-install."
        continue
    }

    Remove-Item -LiteralPath $legacyPath -Recurse -Force
    Write-Output "Removed superseded SkillVault skill: $legacyPath"
}
