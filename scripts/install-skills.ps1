[CmdletBinding(DefaultParameterSetName = 'Names')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Names')][string[]]$Name,
    [Parameter(Mandatory = $true, ParameterSetName = 'Selection')][string[]]$Select,
    [Parameter(ParameterSetName = 'Selection')][switch]$Exact,
    [switch]$Preview,
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [ValidateSet('default', 'global', 'project')][string]$Scope = 'default',
    [string]$ProjectPath = (Get-Location).ProviderPath,
    [string]$GlobalSkillsPath = (Join-Path $HOME '.copilot/skills'),
    [string]$RequestedVersion = 'latest',
    [string]$SourceRepo = 'https://github.com/wzlwit/skillvault.git',
    [ValidateSet('default', 'adapt', 'origin')][string]$Variant = 'default',
    [string]$UpstreamCachePath = (Join-Path $HOME '.copilot/skillvault-install-src'),
    [switch]$Force,
    [switch]$ConfirmStopped
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\skills\core\skillvault-installation\scripts\skill-files.ps1')

if ($RequestedVersion -cnotmatch '^(latest|v\d+\.\d+\.\d+)$') {
    throw "Invalid -RequestedVersion '$RequestedVersion'. Use 'latest' or a v#.#.# version."
}

$repositoryRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RepoRoot)
$catalogPath = Join-Path $repositoryRoot 'catalog.json'
if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
    throw "Missing catalog: $catalogPath"
}

$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
if ($PSCmdlet.ParameterSetName -eq 'Selection') {
    $selectedEntries = @(foreach ($query in $Select) { Find-SkillCatalogEntry -Catalog $catalog -Query $query -Exact:$Exact })
    $Name = @($selectedEntries | Select-Object -ExpandProperty name -Unique)
}
$projectSkillsRoot = Join-Path $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectPath) '.github\skills'
$globalSkillsRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($GlobalSkillsPath)
$checkoutRoot = if (Test-SkillGitTopLevel -Path $repositoryRoot) { [System.IO.Path]::GetFullPath($repositoryRoot).TrimEnd([char[]]'\/') }
$upstreamCacheRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($UpstreamCachePath)
$snapshotRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-origin-' + [guid]::NewGuid().ToString('N'))

$plannedInstalls = New-Object System.Collections.ArrayList
$preflightErrors = New-Object System.Collections.ArrayList

try {
foreach ($skillName in @($Name | Select-Object -Unique)) {
    try {
        $catalogMatches = @($catalog | Where-Object { $_.name -ceq $skillName })
        if ($catalogMatches.Count -ne 1) {
            throw "Skill '$skillName' was not found exactly once in $catalogPath."
        }

        $catalogEntry = $catalogMatches[0]
        $pin = if ($RequestedVersion -cne 'latest') { Get-SkillTagSnapshot -RepoPath $repositoryRoot -Name $skillName -Version $RequestedVersion -Destination (Join-Path $snapshotRoot $skillName) }
        if ($pin) { $sourcePath = $pin.Folder; $manifest = $pin.Manifest }
        else {
            $sourcePath = Resolve-SkillSourcePath -RepositoryRoot $repositoryRoot -SourcePath ([string]$catalogEntry.path)
            $manifest = Read-SkillManifest -SkillPath $sourcePath -ExpectedName $skillName -AllowReference
            if ($manifest.version -cne $catalogEntry.version) { throw "Catalog and manifest versions differ for $skillName" }
        }
        $strategy = if ($manifest.install) { [string]$manifest.install.strategy } else { '' }
        if ($Variant -ceq 'origin' -and $strategy -cnotin @('upstream', 'adapted')) { throw "Skill '$skillName' has no upstream original; install it without 'origin'." }
        if ($Variant -ceq 'adapt' -and $strategy -ceq 'upstream') { throw "Skill '$skillName' has no adaptation; install it without 'adapt' to get the original." }
        $fromOrigin = $Variant -ceq 'origin' -or $strategy -ceq 'upstream'

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
        if ((Test-Path -LiteralPath $targetPath) -and -not $Force -and -not $Preview) {
            throw "Skill '$skillName' is already installed at $targetPath. Review the pending changes, then re-run with -Force to overwrite."
        }
        $snapshot = if ($fromOrigin) { Get-SkillUpstreamSnapshot -Manifest $manifest -CacheRoot $upstreamCacheRoot -Destination (Join-Path $snapshotRoot $skillName) }

        [void]$plannedInstalls.Add([pscustomobject]@{
            Name = $skillName
            SourcePath = $sourcePath
            CatalogPath = $(if ($pin) { $pin.Path } else { [string]$catalogEntry.path })
            Manifest = $manifest
            Scope = $resolvedScope
            TargetRoot = $targetRoot
            Variant = $(if ($fromOrigin) { 'origin' } elseif ($strategy -ceq 'adapted') { 'adapt' })
            Snapshot = $snapshot
            Pin = $pin
        })
    }
    catch {
        [void]$preflightErrors.Add($_.Exception.Message)
    }
}

if ($preflightErrors.Count -gt 0) {
    throw ('Install preflight failed; no skills were installed:' + [Environment]::NewLine + ($preflightErrors -join [Environment]::NewLine))
}

if ($Preview) {
    ConvertTo-Json -Depth 5 -InputObject @($plannedInstalls | ForEach-Object {
        $item = [ordered]@{ Name = $_.Name; Scope = $_.Scope }
        if ($_.Variant) { $item.Variant = $_.Variant }
        if ($_.Snapshot) {
            $item.SourceRepo = $_.Snapshot.Repo; $item.UpstreamPath = $_.Snapshot.Path; $item.RequestedVersion = $_.Snapshot.Version
            $item.Commit = $_.Snapshot.Commit; $item.Files = $_.Snapshot.Files
        }
        elseif ($_.Pin) { $item.Tag = $_.Pin.Tag; $item.Commit = $_.Pin.Commit; $item.PathAtTag = $_.Pin.Path }
        else { $item.SourcePath = $_.SourcePath }
        $item.TargetPath = Join-Path $_.TargetRoot $_.Name
        [pscustomobject]$item
    })
    return
}

$updateLease = Enter-SkillUpdateOwnership -Paths @($plannedInstalls | ForEach-Object { Join-Path $_.TargetRoot $_.Name }) -ConfirmStopped:$ConfirmStopped
try {
foreach ($plannedInstall in $plannedInstalls) {
    if ($plannedInstall.Snapshot) {
        $snapshot = $plannedInstall.Snapshot
        $metadata = [ordered]@{
            installedBy = 'skillvault'
            sourceRepo = $snapshot.Repo
            sourcePath = $snapshot.Path
            scope = $plannedInstall.Scope
            requestedVersion = $snapshot.Version
            installedVersion = $plannedInstall.Manifest.version
            installedAt = (Get-Date).ToUniversalTime().ToString('o')
            sourceType = 'upstream'
            sourceRevision = $snapshot.Revision
        }
        $installResult = Copy-SkillInstallation -Source $snapshot.Folder -TargetRoot $plannedInstall.TargetRoot -Name $plannedInstall.Name -Metadata $metadata -Force:$Force -OwnershipLease $updateLease -OriginManifest $plannedInstall.Manifest
        Write-Output "Installed skill: $($installResult.Name) [$($plannedInstall.Scope)] -> $($installResult.Path) from $($snapshot.Repo) $($snapshot.Path) at $($snapshot.Commit)"
        continue
    }
    $metadata = [ordered]@{
        installedBy = 'skillvault'
        sourceRepo = $SourceRepo
        sourcePath = $plannedInstall.CatalogPath
        scope = $plannedInstall.Scope
        requestedVersion = $RequestedVersion
        installedVersion = $plannedInstall.Manifest.version
        installedAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    if ($checkoutRoot) {
        # Refresh merges committed updates into this copy; the recorded base marks what was committed at install.
        $metadata['sourceCheckout'] = $checkoutRoot
        $baseRevision = if ($plannedInstall.Pin) { $plannedInstall.Pin.Revision } else { Get-SkillSourceRevision -RepoPath $checkoutRoot -SourcePath $plannedInstall.CatalogPath }
        if ($baseRevision) { $metadata['sourceRevision'] = $baseRevision }
    }

    $installResult = Copy-SkillInstallation -Source $plannedInstall.SourcePath -TargetRoot $plannedInstall.TargetRoot -Name $plannedInstall.Name -Metadata $metadata -Force:$Force -OwnershipLease $updateLease
    Write-Output "Installed skill: $($installResult.Name) [$($plannedInstall.Scope)] -> $($installResult.Path)$(if ($plannedInstall.Pin) { " from tag $($plannedInstall.Pin.Tag)" })"
    if ($installResult.RecoveryBackup) { Write-Output "Recovery backup: $($installResult.RecoveryBackup)" }
}
}
finally { Exit-SkillOwnership $updateLease }
}
finally { Remove-Item -LiteralPath $snapshotRoot -Recurse -Force -ErrorAction SilentlyContinue }
