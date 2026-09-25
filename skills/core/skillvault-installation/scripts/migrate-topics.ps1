[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).ProviderPath,
    [string]$RepoPath,
    [ValidateSet('all', 'global', 'project')][string]$Scope = 'all',
    [Alias('Name')][string[]]$SelectedNames,
    [string]$GlobalSkillsPath = (Join-Path $HOME '.copilot/skills'),
    [switch]$Apply,
    [switch]$Force,
    [switch]$ConfirmStopped
)

$ErrorActionPreference = 'Stop'
$applyMigration = [bool]$Apply
$forceReplacement = [bool]$Force
$confirmTransition = [bool]$ConfirmStopped
$selectedScope = $Scope
$projectRoot = (Get-Item -LiteralPath $ProjectPath).FullName
$globalRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($GlobalSkillsPath)
$sourceOptions = @{ ProjectPath = $projectRoot; Mode = 'Install' }
if ($RepoPath) { $sourceOptions.RepoPath = $RepoPath }
$source = & (Join-Path $PSScriptRoot 'resolve-source-repo.ps1') @sourceOptions
if ($source.Status -ne 'Resolved') { throw 'A verified SkillVault source is required.' }
$repositoryRoot = $source.RepoRoot
$catalog = @(Get-Content -LiteralPath $source.CatalogPath -Raw | ConvertFrom-Json)
foreach ($selectedName in $SelectedNames) {
    if ($selectedName -cnotin $catalog.name) { throw "Select an exact canonical catalog name: $selectedName" }
}
. (Join-Path $PSScriptRoot 'skill-files.ps1')
. (Join-Path $PSScriptRoot 'skillvault-list.ps1') -ProjectPath $projectRoot -Scope $selectedScope -GlobalSkillsPath $globalRoot | Out-Null
$projectSkills = Join-Path $projectRoot '.github/skills'
$installed = @($entries | Where-Object {
    $_.Managed -eq 'yes' -and ((Split-Path -Parent $_.Path) -ieq $globalRoot -or (Split-Path -Parent $_.Path) -ieq $projectSkills)
})
$mapping = @{
    'harness-init' = 'harness'; 'harness-root' = 'harness'; 'harness-loc' = 'harness'; 'harness-context' = 'harness'; 'harness-management' = 'harness'
    'harness-decide' = 'harness-decision'; 'harness-ref' = 'harness-link'; 'harness-report-create' = 'harness-report'
    'harness-fallback' = 'harness-policy'; 'harness-restrict' = 'harness-policy'
    'sv-installation' = 'skillvault-installation'; 'sv-discovery' = 'skillvault-discovery'
    'sv-refresh' = 'skillvault-refresh'; 'sv-source' = 'skillvault-authoring'; 'skillvault-source' = 'skillvault-authoring'
    'skillvault-install' = 'skillvault-installation'; 'skillvault-list' = 'skillvault-installation'; 'skillvault-uninstall' = 'skillvault-installation'
    'skillvault-upsert' = 'skillvault-authoring'; 'skillvault-remove' = 'skillvault-authoring'; 'skillvault-fresh' = 'skillvault-refresh'
    'skillvault-evaluate' = 'skillvault-discovery'; 'skillvault-search' = 'skillvault-discovery'; 'skillvault-key-points' = 'skillvault-discovery'
    'pr-review-add' = 'pr-watch'; 'pr-review-list' = 'pr-watch'; 'pr-review-remove' = 'pr-watch'; 'pr-review-timer' = 'harness-timer'
    'rules-core' = 'rules'; 'jarvis-metrics-create' = 'jarvis-metrics'; 'kpi-dashboard-design' = 'kpi-dashboard'; 'openapi-spec-generation' = 'openapi-spec'
}
$installs = [Collections.Generic.List[object]]::new()
$retire = [Collections.Generic.List[object]]::new()
$skipped = [Collections.Generic.List[object]]::new()
foreach ($group in @($installed | Group-Object ScopeType)) {
    $targetRoot = if ($group.Name -eq 'global') { $globalRoot } else { $projectSkills }
    $wanted = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in $group.Group) {
        $name = if ($mapping.ContainsKey($entry.Name)) { $mapping[$entry.Name] } else { $entry.Name }
        if ($SelectedNames -and $name -cnotin $SelectedNames) { continue }
        if ($entry.RequestedVersion -ne 'latest') { $skipped.Add($entry); continue }
        if ($name -cnotin $catalog.name) { $skipped.Add($entry); continue }
        $null = $wanted.Add($name)
        if ($name -cne $entry.Name) { $retire.Add([pscustomobject]@{ oldName = $entry.Name; name = $name; path = $entry.Path; scope = $group.Name }) }
    }
    do {
        $added = $false
        foreach ($name in @($wanted)) {
            $item = $catalog | Where-Object name -CEQ $name
            $bundle = Resolve-SkillSourcePath -RepositoryRoot $repositoryRoot -SourcePath $item.path
            $manifest = Read-SkillManifest $bundle $name
            foreach ($dependency in @($manifest.dependencies | Where-Object { $_ -cin $catalog.name })) { if ($wanted.Add($dependency)) { $added = $true } }
        }
    } while ($added)
    foreach ($name in @($wanted | Sort-Object)) {
        $item = $catalog | Where-Object name -CEQ $name
        $bundle = Resolve-SkillSourcePath -RepositoryRoot $repositoryRoot -SourcePath $item.path
        $manifest = Read-SkillManifest $bundle $name
        $target = Join-Path $targetRoot $name
        if (Test-Path -LiteralPath $target) {
            $known = @($installed | Where-Object { $_.Path -ieq $target })
            if ($known.Count -ne 1 -or $known[0].RequestedVersion -ne 'latest') { throw "Preserve the unmanaged or pinned target: $target" }
            if ($SelectedNames -and (Test-SkillContentEqual -Source $bundle -Target $target)) { continue }
        }
        $installs.Add([pscustomobject]@{ name = $name; source = $bundle; sourcePath = $item.path; target = $target; root = $targetRoot; scope = $group.Name; version = $manifest.version; operation = $(if (Test-Path -LiteralPath $target) { 'Replace' } else { 'Install' }) })
    }
}
$plan = [pscustomobject]@{ preview = -not $applyMigration; repository = $repositoryRoot; install = @($installs); retire = @($retire); skipped = @($skipped); backups = @() }
if (-not $applyMigration) { $plan | ConvertTo-Json -Depth 12; return }
if (-not $forceReplacement) { throw 'Review the exact migration preview and supply Apply and Force after approval.' }
$updatePaths = @(@($installs.target) + @($retire.path) | Where-Object { $_ } | Sort-Object -Unique)
if (-not $updatePaths.Count) { $plan | ConvertTo-Json -Depth 12; return }
$updateLease = Enter-SkillUpdateOwnership -Paths $updatePaths -ConfirmStopped:$confirmTransition
$backups = @{}
$originals = @{}
$written = [Collections.Generic.List[object]]::new()
$succeeded = $false
try {
    $backupRoots = @(@($installs.root) + @($retire | ForEach-Object { Split-Path -Parent $_.path }) | Sort-Object -Unique)
    foreach ($root in $backupRoots) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $targets = @(foreach ($entry in @($installed | Where-Object { (Split-Path -Parent $_.Path) -ieq $root -and $_.Path -iin $updatePaths })) {
            @{ path = $entry.Path; target = $entry.Path; name = $(if ($mapping.ContainsKey($entry.Name)) { $mapping[$entry.Name] } else { $entry.Name }); payload = $entry.Name; scope = $entry.ScopeType }
        })
        if ($targets.Count) {
            $backup = New-SkillUpdateTransaction -Targets $targets
            $backups[$root] = $backup
            foreach ($entry in $backup.record.entries) { $originals[$entry.target] = Join-Path $backup.path $entry.payload }
        }
    }
    foreach ($item in $installs) {
        $metadata = [ordered]@{ installedBy = 'skillvault'; sourceRepo = 'https://github.com/wzlwit/skillvault.git'; sourcePath = $item.sourcePath; scope = $item.scope; requestedVersion = 'latest'; installedVersion = $item.version; installedAt = [datetimeoffset]::UtcNow.ToString('o') }
        $written.Add($item)
        $null = Copy-SkillInstallation -Source $item.source -TargetRoot $item.root -Name $item.name -Metadata $metadata -Force -OwnershipLease $updateLease -RecoveryBackup $backups[$item.root]
        if (-not (Test-SkillContentEqual -Source $item.source -Target $item.target)) { throw "Installed copy did not match its source: $($item.name)" }
    }
    foreach ($item in $retire) {
        if (-not $originals.ContainsKey($item.path)) { throw 'The original bundle was not backed up; do not retire it.' }
        Remove-Item -LiteralPath $item.path -Recurse -Force
    }
    $succeeded = $true
    $plan | ConvertTo-Json -Depth 12
}
catch {
    foreach ($item in @($written | Where-Object { -not $originals.ContainsKey($_.target) })) {
        if (Test-Path -LiteralPath $item.target) { Remove-Item -LiteralPath $item.target -Recurse -Force }
    }
    foreach ($backup in $backups.Values) { Restore-SkillUpdateTransaction $backup }
    throw
}
finally {
    try { if ($succeeded) { foreach ($backup in $backups.Values) { Complete-SkillUpdateTransaction $backup } } }
    finally { Exit-SkillOwnership $updateLease }
}