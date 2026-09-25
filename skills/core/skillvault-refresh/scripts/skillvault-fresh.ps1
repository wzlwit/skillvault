param(
    [ValidateRange(0, 365)]
    [double]$IntervalDay = 1,

    [switch]$RunOnce,

    [string]$GlobalSkillsPath = (Join-Path $HOME '.copilot/skills'),

    [string]$CachePath = (Join-Path $HOME '.copilot/skillvault-fresh-src'),

    [switch]$ResultJson,

    [string]$RetryPlanPath,

    [int]$OwnerProcessId
)

$ErrorActionPreference = 'Stop'

$sharedHelperPath = Join-Path $PSScriptRoot '..\..\skillvault-installation\scripts\skill-files.ps1'
if (-not (Test-Path -LiteralPath $sharedHelperPath -PathType Leaf)) {
    throw "Missing shared helper '$sharedHelperPath'. Install the bundled 'skillvault-installation' skill next to 'skillvault-refresh', then re-run."
}
. $sharedHelperPath

$taskName = 'SkillVault Source Refresh'
$defaultRepo = 'https://github.com/wzlwit/skillvault.git'
$globalSkillsRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($GlobalSkillsPath)
$cacheRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CachePath)
$repoCache = @{}
if (($ResultJson -or $RetryPlanPath -or $OwnerProcessId) -and -not ($RunOnce -or $IntervalDay -eq 0)) { throw 'Structured results and retry plans apply only to one refresh run.' }
if ($RetryPlanPath -and -not $ResultJson) { throw 'Retry plans require structured results.' }

function Write-SkillRefreshMessage {
    param([string]$Message)
    if ($ResultJson) { $script:refreshMessages.Add($Message) }
    else { Write-Output $Message }
}

function Get-PowerShellExecutable {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) { return $pwsh.Source }

    $powershell = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($powershell) { return $powershell.Source }

    throw 'No PowerShell executable found for scheduled refresh.'
}

function ConvertTo-CacheName {
    param([Parameter(Mandatory = $true)][string]$RepoUrl)

    return ($RepoUrl -replace '[^A-Za-z0-9._-]', '_').Trim('_')
}

function Sync-Repo {
    param([Parameter(Mandatory = $true)][string]$RepoUrl)

    if ($repoCache.ContainsKey($RepoUrl)) {
        $cached = $repoCache[$RepoUrl]
        if ($cached.Error) { throw $cached.Error }
        return $cached.Path
    }

    try {
        if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
            throw 'Source repository is empty.'
        }
        if ($RepoUrl.StartsWith('-')) {
            throw "Source repository must not start with '-': $RepoUrl"
        }

        $repoPath = Join-Path $cacheRoot (ConvertTo-CacheName $RepoUrl)
        if (Test-Path -LiteralPath $repoPath) {
            if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) {
                throw "Source cache is not a Git repository; inspect and remove it manually: $repoPath"
            }

            $remoteUrl = [string](git -C $repoPath remote get-url origin | Select-Object -First 1)
            if ($LASTEXITCODE -ne 0) { throw "Git remote get-url failed for $repoPath" }
            if ($remoteUrl.Trim() -cne $RepoUrl) {
                throw "Source cache $repoPath tracks '$($remoteUrl.Trim())', not '$RepoUrl'."
            }

            $status = git -C $repoPath status --porcelain
            if ($LASTEXITCODE -ne 0) { throw "Git status failed for $repoPath" }
            if ($status) { throw "Refusing to refresh from a modified source cache: $repoPath" }

            git -C $repoPath fetch --prune origin | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Git fetch failed for $RepoUrl" }

            git -C $repoPath remote set-head origin --auto | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Git remote set-head failed for $RepoUrl" }

            $defaultRef = [string](git -C $repoPath symbolic-ref --quiet --short refs/remotes/origin/HEAD | Select-Object -First 1)
            if ($LASTEXITCODE -ne 0) { throw "Git symbolic-ref failed for $RepoUrl" }
            $defaultRef = $defaultRef.Trim()
            if ($defaultRef -cnotmatch '^origin/\S+$') {
                throw "Unexpected default branch ref for ${RepoUrl}: '$defaultRef'"
            }

            git -C $repoPath checkout --detach $defaultRef | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Git checkout failed for $RepoUrl" }
        }
        else {
            New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
            git clone -- $RepoUrl $repoPath | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Git clone failed for $RepoUrl" }
        }

        $repoCache[$RepoUrl] = [pscustomobject]@{ Path = $repoPath; Error = $null }
        return $repoPath
    }
    catch {
        $repoCache[$RepoUrl] = [pscustomobject]@{ Path = $null; Error = $_.Exception.Message }
        throw
    }
}

function Get-SourceRevision {
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][string]$SourcePath
    )

    $revisionSpec = if ($SourcePath -ceq '.') { 'HEAD^{tree}' } else { "HEAD:$SourcePath" }
    try {
        $revision = [string](git -C $RepoPath rev-parse $revisionSpec | Select-Object -First 1)
    }
    catch {
        return $null
    }

    if ($LASTEXITCODE -ne 0) { return $null }
    if ([string]::IsNullOrWhiteSpace($revision)) { return $null }
    return $revision.Trim()
}

function Invoke-SkillVaultSync {
    $script:repoCache = @{}
    $script:refreshMessages = [Collections.Generic.List[string]]::new()
    $retryTargets = [Collections.Generic.List[object]]::new()
    $unresolved = [Collections.Generic.List[object]]::new()
    $retrySelection = @{}
    if ($RetryPlanPath) {
        $plan = Get-Content -LiteralPath $RetryPlanPath -Raw | ConvertFrom-Json
        if ($plan.schemaVersion -ne 1 -or $plan.targets -isnot [array] -or $plan.targets.Count -eq 0 -or $plan.globalSkillsRoot -cne $globalSkillsRoot) { throw 'Invalid refresh retry plan or target root.' }
        foreach ($target in $plan.targets) {
            if ($target.name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -or $retrySelection.ContainsKey($target.name)) { throw 'Retry targets require unique canonical skill names.' }
            foreach ($field in @('sourceRepo', 'sourcePath', 'sourceRevision', 'metadataHash')) {
                if ([string]::IsNullOrWhiteSpace([string]$target.$field)) { throw "Retry target lacks $field." }
            }
            $retrySelection[$target.name] = $target
        }
        foreach ($item in @($plan.unresolved | Where-Object { $null -ne $_ -and -not $retrySelection.ContainsKey([string]$_.name) })) { $unresolved.Add($item) }
    }

    if (-not (Test-Path -LiteralPath $globalSkillsRoot -PathType Container)) {
        if ($ResultJson) { [pscustomobject]@{ schemaVersion = 1; kind = 'SkillVaultRefresh'; status = 'Blocked'; retryTargets = @(); unresolved = @(); messages = @("Global skills directory not found: $globalSkillsRoot") } }
        else { Write-Output "Global skills directory not found: $globalSkillsRoot" }
        return
    }

    $failures = New-Object System.Collections.ArrayList

    foreach ($skillDirectory in @(Get-ChildItem -LiteralPath $globalSkillsRoot -Directory -Force | Sort-Object -Property Name)) {
        $name = $skillDirectory.Name
        if ($name -like '.skillvault-stage-*' -or $name -like '.skillvault-backup-*') { continue }
        if ($RetryPlanPath -and -not $retrySelection.ContainsKey($name)) { continue }
        $requested = $retrySelection[$name]
        $revision = $null

        $metadataPath = Join-Path $skillDirectory.FullName '.skillvault-install.json'
        if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
            Write-SkillRefreshMessage "Skipped install without SkillVault metadata: $name"
            if ($requested) { $unresolved.Add([pscustomobject]@{ name = $name; status = 'Deferred'; reason = 'InstalledMetadataMissing' }) }
            continue
        }

        try {
            $metadataHash = (Get-FileHash -LiteralPath $metadataPath -Algorithm SHA256).Hash
            if ($requested -and $requested.metadataHash -cne $metadataHash) {
                $unresolved.Add([pscustomobject]@{ name = $name; status = 'Deferred'; reason = 'InstalledMetadataChanged' })
                Write-SkillRefreshMessage "Deferred: ${name}: installed metadata changed since the approved retry."
                continue
            }
            $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
            if ($null -eq $metadata -or $metadata -isnot [System.Management.Automation.PSCustomObject]) {
                throw "Install metadata must be a JSON object: $metadataPath"
            }

            if ($metadata.installedBy -cnotin @('skillvault', 'skillvault-bootstrap')) {
                Write-SkillRefreshMessage "Skipped install managed elsewhere: $name ($($metadata.installedBy))"
                continue
            }

            if ($metadata.requestedVersion -cne 'latest') {
                Write-SkillRefreshMessage "Skipped pinned install: $name ($($metadata.requestedVersion))"
                continue
            }

            if ($metadata.scope -cne 'global') {
                Write-SkillRefreshMessage "Skipped non-global install: $name ($($metadata.scope))"
                continue
            }

            $sourcePath = [string]$metadata.sourcePath
            if ([string]::IsNullOrWhiteSpace($sourcePath)) {
                Write-SkillRefreshMessage "Skipped install without sourcePath: $name"
                continue
            }

            $repoUrl = if ([string]::IsNullOrWhiteSpace([string]$metadata.sourceRepo)) { $defaultRepo } else { [string]$metadata.sourceRepo }
            $repoPath = Sync-Repo -RepoUrl $repoUrl
            if ($sourcePath -cmatch ('^skills/public/([a-z0-9]+(?:-[a-z0-9]+)*)/' + [regex]::Escape($name) + '$') -and
                -not (Test-Path -LiteralPath (Join-Path $repoPath $sourcePath))) {
                $relocatedPath = 'skills/' + $Matches[1] + '/' + $name
                $catalogPath = Join-Path $repoPath 'catalog.json'
                if (Test-Path -LiteralPath $catalogPath -PathType Leaf) {
                    $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
                    $entries = @($catalog | Where-Object { $_.name -ceq $name })
                    if ($entries.Count -eq 1 -and $entries[0].path -ceq $relocatedPath) {
                        $sourcePath = $relocatedPath
                    }
                }
            }
            $source = if ($sourcePath -ceq '.') { $repoPath } else { Resolve-SkillSourcePath -RepositoryRoot $repoPath -SourcePath $sourcePath }
            $manifest = Read-SkillManifest -SkillPath $source -ExpectedName $name
            if ($requested) {
                $revision = Get-SourceRevision -RepoPath $repoPath -SourcePath $sourcePath
                if ($requested.sourceRepo -cne $repoUrl -or $requested.sourcePath -cne $sourcePath -or $requested.sourceRevision -cne $revision) {
                    $unresolved.Add([pscustomobject]@{ name = $name; status = 'Deferred'; reason = 'SourceChanged' })
                    Write-SkillRefreshMessage "Deferred: ${name}: source identity or revision changed since the approved retry."
                    continue
                }
            }

            if ($manifest.kind -ceq 'compatibility') {
                Write-SkillRefreshMessage "Skipped compatibility migration: $name. Install the canonical topic and review the old copy explicitly."
                continue
            }

            if ($metadata.sourcePath -ceq $sourcePath -and $metadata.installedVersion -ceq $manifest.version -and
                (Test-SkillContentEqual -Source $source -Target $skillDirectory.FullName)) {
                Write-SkillRefreshMessage "Unchanged: $name ($($manifest.version))"
                continue
            }

            $updatedMetadata = [ordered]@{}
            foreach ($property in $metadata.PSObject.Properties) { $updatedMetadata[$property.Name] = $property.Value }
            $updatedMetadata['scope'] = 'global'
            $updatedMetadata['sourceRepo'] = $repoUrl
            $updatedMetadata['sourcePath'] = $sourcePath
            $updatedMetadata['installedVersion'] = $manifest.version
            $updatedMetadata['installedAt'] = (Get-Date).ToUniversalTime().ToString('o')

            if (-not $revision) { $revision = Get-SourceRevision -RepoPath $repoPath -SourcePath $sourcePath }
            if ($revision) { $updatedMetadata['sourceRevision'] = $revision }

            $installResult = Copy-SkillInstallation -Source $source -TargetRoot $globalSkillsRoot -Name $name -Metadata $updatedMetadata -Force
            Write-SkillRefreshMessage "Updated: $name $($installResult.Version) -> $($installResult.Path)"
        }
        catch {
            if ($_.Exception.Data['SkillOwnershipStatus']) {
                [void]$failures.Add("${name}: Deferred - $($_.Exception.Message)")
                $ownershipStatus = [string]$_.Exception.Data['SkillOwnershipStatus']
                $ownerPid = $_.Exception.Data['SkillOwnershipProcessId']
                $retryable = $ownershipStatus -ceq 'Busy' -and $revision -and $ownerPid -notin @($PID, $OwnerProcessId)
                $unresolved.Add([pscustomobject]@{ name = $name; status = 'Deferred'; reason = $ownershipStatus; retryable = [bool]$retryable })
                if ($retryable) {
                    $retryTargets.Add([pscustomobject]@{ name = $name; sourceRepo = $repoUrl; sourcePath = $sourcePath; sourceRevision = $revision; metadataHash = $metadataHash })
                }
                Write-SkillRefreshMessage "Deferred: ${name}: $($_.Exception.Message)"
                continue
            }
            [void]$failures.Add("${name}: $($_.Exception.Message)")
            $unresolved.Add([pscustomobject]@{ name = $name; status = 'Failed'; reason = $_.Exception.Message })
            Write-SkillRefreshMessage "Failed: ${name}: $($_.Exception.Message)"
        }
    }

    foreach ($name in @($retrySelection.Keys)) {
        if (-not (Test-Path -LiteralPath (Join-Path $globalSkillsRoot $name) -PathType Container)) { $unresolved.Add([pscustomobject]@{ name = $name; status = 'Deferred'; reason = 'InstalledTargetMissing' }) }
    }
    if ($ResultJson) {
        return [pscustomobject]@{ schemaVersion = 1; kind = 'SkillVaultRefresh'; status = $(if (-not $unresolved.Count) { 'Succeeded' } elseif ($retryTargets.Count -or @($unresolved | Where-Object status -EQ Deferred).Count) { 'Deferred' } else { 'Failed' }); globalSkillsRoot = $globalSkillsRoot; retryTargets = @($retryTargets); unresolved = @($unresolved); messages = @($script:refreshMessages) }
    }
    if ($failures.Count -gt 0) {
        throw ("SkillVault refresh failed for $($failures.Count) skill(s):" + [Environment]::NewLine + ($failures -join [Environment]::NewLine))
    }
}

if ($RunOnce -or $IntervalDay -eq 0) {
    if (-not (Get-Command Enter-SkillRuntimeOwnership).Parameters.ContainsKey('InterfaceVersion')) { throw 'Incompatible runtime helper. Update skillvault-installation and skillvault-refresh together before execution; compatibility interface v1 is required.' }
    $runtimeOwnership = Enter-SkillRuntimeOwnership -SkillPath (Split-Path -Parent $PSScriptRoot) -Owner ([pscustomobject]@{ role = 'skill refresh'; root = $globalSkillsRoot }) -InterfaceVersion 1
    try {
        if ($ResultJson) { Invoke-SkillVaultSync | ConvertTo-Json -Depth 12 }
        else { Invoke-SkillVaultSync }
    }
    finally { Exit-SkillOwnership $runtimeOwnership }
    return
}

$scriptPath = $PSCommandPath
if (-not $scriptPath) { throw 'Cannot determine current script path for scheduled task.' }

$powerShellPath = Get-PowerShellExecutable
$scheduledArgument = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -RunOnce -GlobalSkillsPath `"$globalSkillsRoot`" -CachePath `"$cacheRoot`""
$action = New-ScheduledTaskAction -Execute $powerShellPath -Argument $scheduledArgument
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Days $IntervalDay)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Refresh latest source-backed SkillVault installs every $IntervalDay day(s)." -Force | Out-Null
Write-Output "Scheduled '$taskName' every $IntervalDay day(s)."