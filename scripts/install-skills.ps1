param(
    [Parameter(Mandatory = $true)][string[]]$Name,
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [ValidateSet('default', 'global', 'project')][string]$Scope = 'default',
    [string]$ProjectPath = (Get-Location).ProviderPath,
    [string]$GlobalSkillsPath = (Join-Path $HOME '.copilot/skills'),
    [string]$RequestedVersion = 'latest',
    [string]$SourceRepo = 'https://github.com/wzlwit/skillvault.git',
    [switch]$Force,
    [switch]$ConfirmStopped
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\skills\core\skillvault-installation\scripts\skill-files.ps1')

if ($RequestedVersion -cnotmatch '^(latest|v\d+\.\d+\.\d+)$') {
    throw "Invalid -RequestedVersion '$RequestedVersion'. Use 'latest' or a v#.#.# tag."
}

$repositoryRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RepoRoot)
if ($RequestedVersion -cne 'latest') {
    $tagCommit = git -C $repositoryRoot rev-parse --verify "refs/tags/${RequestedVersion}^{commit}"
    if ($LASTEXITCODE -ne 0) { throw "Cannot resolve requested tag: $RequestedVersion" }
    $headCommit = git -C $repositoryRoot rev-parse --verify HEAD
    if ($LASTEXITCODE -ne 0 -or [string]$headCommit -cne [string]$tagCommit) {
        throw "The local checkout is not at tag $RequestedVersion. Select the tag before installing a pinned version."
    }
    $worktreeChanges = git -C $repositoryRoot status --porcelain
    if ($LASTEXITCODE -ne 0 -or $worktreeChanges) { throw 'A pinned installation requires a clean tagged checkout.' }
}
$catalogPath = Join-Path $repositoryRoot 'catalog.json'
if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
    throw "Missing catalog: $catalogPath"
}

$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$projectSkillsRoot = Join-Path $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectPath) '.github\skills'
$globalSkillsRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($GlobalSkillsPath)

$plannedInstalls = New-Object System.Collections.ArrayList
$preflightErrors = New-Object System.Collections.ArrayList

foreach ($skillName in @($Name | Select-Object -Unique)) {
    try {
        $catalogMatches = @($catalog | Where-Object { $_.name -ceq $skillName })
        if ($catalogMatches.Count -ne 1) {
            throw "Skill '$skillName' was not found exactly once in $catalogPath."
        }

        $catalogEntry = $catalogMatches[0]
        $sourcePath = Resolve-SkillSourcePath -RepositoryRoot $repositoryRoot -SourcePath ([string]$catalogEntry.path)
        $manifest = Read-SkillManifest -SkillPath $sourcePath -ExpectedName $skillName
        if ($manifest.version -cne $catalogEntry.version) { throw "Catalog and manifest versions differ for $skillName" }

        $resolvedScope = $Scope
        if ($resolvedScope -eq 'default') {
            $resolvedScope = 'project'
            if ($manifest.install -and -not [string]::IsNullOrWhiteSpace([string]$manifest.install.defaultScope)) {
                $resolvedScope = [string]$manifest.install.defaultScope
            }
        }

        if ($resolvedScope -eq 'session') {
            throw "Skill '$skillName' defaults to session scope, which copies no files. Use /sv-install with session scope, or pass -Scope project or -Scope global."
        }

        if ($resolvedScope -cnotin @('global', 'project')) {
            throw "Unsupported scope '$resolvedScope' for skill '$skillName'."
        }

        $targetRoot = $projectSkillsRoot
        if ($resolvedScope -eq 'global') { $targetRoot = $globalSkillsRoot }

        $targetPath = Join-Path $targetRoot $skillName
        if ((Test-Path -LiteralPath $targetPath) -and -not $Force) {
            throw "Skill '$skillName' is already installed at $targetPath. Review the pending changes, then re-run with -Force to overwrite."
        }

        [void]$plannedInstalls.Add([pscustomobject]@{
            Name = $skillName
            SourcePath = $sourcePath
            CatalogPath = [string]$catalogEntry.path
            Manifest = $manifest
            Scope = $resolvedScope
            TargetRoot = $targetRoot
        })
    }
    catch {
        [void]$preflightErrors.Add($_.Exception.Message)
    }
}

if ($preflightErrors.Count -gt 0) {
    throw ('Install preflight failed; no skills were installed:' + [Environment]::NewLine + ($preflightErrors -join [Environment]::NewLine))
}

$updateLease = Enter-SkillUpdateOwnership -Paths @($plannedInstalls | ForEach-Object { Join-Path $_.TargetRoot $_.Name }) -ConfirmStopped:$ConfirmStopped
try {
foreach ($plannedInstall in $plannedInstalls) {
    $metadata = [ordered]@{
        installedBy = 'skillvault'
        sourceRepo = $SourceRepo
        sourcePath = $plannedInstall.CatalogPath
        scope = $plannedInstall.Scope
        requestedVersion = $RequestedVersion
        installedVersion = $plannedInstall.Manifest.version
        installedAt = (Get-Date).ToUniversalTime().ToString('o')
    }

    $installResult = Copy-SkillInstallation -Source $plannedInstall.SourcePath -TargetRoot $plannedInstall.TargetRoot -Name $plannedInstall.Name -Metadata $metadata -Force:$Force -OwnershipLease $updateLease
    Write-Output "Installed skill: $($installResult.Name) [$($plannedInstall.Scope)] -> $($installResult.Path)"
    if ($installResult.RecoveryBackup) { Write-Output "Recovery backup: $($installResult.RecoveryBackup)" }
}
}
finally { Exit-SkillOwnership $updateLease }
