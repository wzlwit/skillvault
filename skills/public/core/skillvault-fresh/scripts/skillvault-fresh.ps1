param(
    [ValidateRange(0, 365)]
    [double]$IntervalDay = 1,

    [switch]$RunOnce,

    [string]$GlobalSkillsPath = (Join-Path $HOME '.copilot/skills'),

    [string]$CachePath = (Join-Path $HOME '.copilot/skillvault-fresh-src')
)

$ErrorActionPreference = 'Stop'

$sharedHelperPath = Join-Path $PSScriptRoot '..\..\skillvault-install\scripts\skill-files.ps1'
if (-not (Test-Path -LiteralPath $sharedHelperPath -PathType Leaf)) {
    throw "Missing shared helper '$sharedHelperPath'. Install the bundled 'skillvault-install' skill next to 'skillvault-fresh', then re-run."
}
. $sharedHelperPath

$taskName = 'SkillVault Source Refresh'
$defaultRepo = 'https://github.com/wzlwit/skillvault.git'
$globalSkillsRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($GlobalSkillsPath)
$cacheRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CachePath)
$repoCache = @{}

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

    if (-not (Test-Path -LiteralPath $globalSkillsRoot -PathType Container)) {
        Write-Output "Global skills directory not found: $globalSkillsRoot"
        return
    }

    $failures = New-Object System.Collections.ArrayList

    foreach ($skillDirectory in @(Get-ChildItem -LiteralPath $globalSkillsRoot -Directory -Force | Sort-Object -Property Name)) {
        $name = $skillDirectory.Name
        if ($name -like '.skillvault-stage-*' -or $name -like '.skillvault-backup-*') { continue }

        $metadataPath = Join-Path $skillDirectory.FullName '.skillvault-install.json'
        if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
            Write-Output "Skipped install without SkillVault metadata: $name"
            continue
        }

        try {
            $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
            if ($null -eq $metadata -or $metadata -isnot [System.Management.Automation.PSCustomObject]) {
                throw "Install metadata must be a JSON object: $metadataPath"
            }

            if ($metadata.installedBy -cnotin @('skillvault', 'skillvault-bootstrap')) {
                Write-Output "Skipped install managed elsewhere: $name ($($metadata.installedBy))"
                continue
            }

            if ($metadata.requestedVersion -cne 'latest') {
                Write-Output "Skipped pinned install: $name ($($metadata.requestedVersion))"
                continue
            }

            if ($metadata.scope -cne 'global') {
                Write-Output "Skipped non-global install: $name ($($metadata.scope))"
                continue
            }

            $sourcePath = [string]$metadata.sourcePath
            if ([string]::IsNullOrWhiteSpace($sourcePath)) {
                Write-Output "Skipped install without sourcePath: $name"
                continue
            }

            $repoUrl = if ([string]::IsNullOrWhiteSpace([string]$metadata.sourceRepo)) { $defaultRepo } else { [string]$metadata.sourceRepo }
            $repoPath = Sync-Repo -RepoUrl $repoUrl
            $source = if ($sourcePath -ceq '.') { $repoPath } else { Resolve-SkillSourcePath -RepositoryRoot $repoPath -SourcePath $sourcePath }
            $manifest = Read-SkillManifest -SkillPath $source -ExpectedName $name

            if ($metadata.installedVersion -ceq $manifest.version -and
                (Test-SkillContentEqual -Source $source -Target $skillDirectory.FullName)) {
                Write-Output "Unchanged: $name ($($manifest.version))"
                continue
            }

            $updatedMetadata = [ordered]@{}
            foreach ($property in $metadata.PSObject.Properties) { $updatedMetadata[$property.Name] = $property.Value }
            $updatedMetadata['scope'] = 'global'
            $updatedMetadata['sourceRepo'] = $repoUrl
            $updatedMetadata['sourcePath'] = $sourcePath
            $updatedMetadata['installedVersion'] = $manifest.version
            $updatedMetadata['installedAt'] = (Get-Date).ToUniversalTime().ToString('o')

            $revision = Get-SourceRevision -RepoPath $repoPath -SourcePath $sourcePath
            if ($revision) { $updatedMetadata['sourceRevision'] = $revision }

            $installResult = Copy-SkillInstallation -Source $source -TargetRoot $globalSkillsRoot -Name $name -Metadata $updatedMetadata -Force
            Write-Output "Updated: $name $($installResult.Version) -> $($installResult.Path)"
        }
        catch {
            [void]$failures.Add("${name}: $($_.Exception.Message)")
            Write-Output "Failed: ${name}: $($_.Exception.Message)"
        }
    }

    if ($failures.Count -gt 0) {
        throw ("SkillVault refresh failed for $($failures.Count) skill(s):" + [Environment]::NewLine + ($failures -join [Environment]::NewLine))
    }
}

if ($RunOnce -or $IntervalDay -eq 0) {
    Invoke-SkillVaultSync
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