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

function Sync-Repo {
    param([Parameter(Mandatory = $true)][string]$RepoUrl)

    if ($repoCache.ContainsKey($RepoUrl)) {
        $cached = $repoCache[$RepoUrl]
        if ($cached.Error) { throw $cached.Error }
        return $cached.Path
    }

    try {
        $repoPath = Sync-SkillSourceRepository -RepoUrl $RepoUrl -CacheRoot $cacheRoot
        $repoCache[$RepoUrl] = [pscustomobject]@{ Path = $repoPath; Error = $null }
        return $repoPath
    }
    catch {
        $repoCache[$RepoUrl] = [pscustomobject]@{ Path = $null; Error = $_.Exception.Message }
        throw
    }
}

function Invoke-RefreshGit {
    param([Parameter(Mandatory = $true)][string]$RepoPath, [Parameter(Mandatory = $true)][string[]]$Arguments)

    $ErrorActionPreference = 'Continue'
    $output = @(git -C $RepoPath @Arguments 2>&1 | ForEach-Object { [string]$_ })
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output; Text = ($output -join ' ').Trim() }
}

function Get-SkillCheckoutRoot {
    param([string]$Path, [string]$RepoUrl)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Container)) { return $null }
    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd([char[]]'\/')
    if (-not (Test-SkillGitTopLevel -Path $fullPath)) { return $null }
    $origin = Invoke-RefreshGit $fullPath @('config', '--get', 'remote.origin.url')
    if ($origin.ExitCode -ne 0 -or (ConvertTo-SkillRepoIdentity $origin.Text) -cne (ConvertTo-SkillRepoIdentity $RepoUrl)) { return $null }
    return $fullPath
}

function Update-SkillLocalCheckout {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$RepoUrl, [switch]$NoUpdate)

    $result = [pscustomobject]@{ Root = $null; Usable = $false; Reason = 'CheckoutUnavailable'; Message = "Checkout is missing or does not track ${RepoUrl}: $Path" }
    $root = Get-SkillCheckoutRoot -Path $Path -RepoUrl $RepoUrl
    if (-not $root) { return $result }
    $result.Root = $root
    $previousGitPrompt = $env:GIT_TERMINAL_PROMPT
    $previousGcmInteractive = $env:GCM_INTERACTIVE
    try {
        $env:GIT_TERMINAL_PROMPT = '0'
        $env:GCM_INTERACTIVE = 'Never'
        $fetch = $null
        if (-not $NoUpdate) { $fetch = Invoke-RefreshGit $root @('fetch', '--quiet', 'origin') }
        $remoteHead = Invoke-RefreshGit $root @('symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD')
        if ($remoteHead.ExitCode -ne 0 -and -not $NoUpdate) {
            $null = Invoke-RefreshGit $root @('remote', 'set-head', 'origin', '--auto')
            $remoteHead = Invoke-RefreshGit $root @('symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD')
        }
        if ($remoteHead.ExitCode -ne 0 -or $remoteHead.Text -cnotmatch '^origin/(\S+)$') { $result.Message = "Cannot determine the default branch of $root."; return $result }
        $branch = $Matches[1]
        $current = Invoke-RefreshGit $root @('symbolic-ref', '--quiet', '--short', 'HEAD')
        if ($current.Text -cne $branch) {
            $result.Reason = 'CheckoutOnOtherBranch'
            $result.Message = "Checkout $root is on '$($current.Text)', not '$branch'; it was not updated and its installed copies wait."
            return $result
        }
        $result.Usable = $true
        $result.Reason = $null
        $result.Message = $null
        if ($NoUpdate) { return $result }
        if ($fetch.ExitCode -ne 0) {
            $result.Reason = 'CheckoutFetchFailed'
            $result.Message = "Could not fetch into ${root}; installed copies follow its local commits. $($fetch.Text)"
            return $result
        }
        $counts = (Invoke-RefreshGit $root @('rev-list', '--left-right', '--count', "HEAD...origin/$branch")).Text -split '\s+'
        if ($counts.Count -ne 2 -or [int]$counts[1] -eq 0) { return $result }
        if ([int]$counts[0] -eq 0) {
            $merge = Invoke-RefreshGit $root @('merge', '--ff-only', '--quiet', "origin/$branch")
            if ($merge.ExitCode -eq 0) { $result.Message = "Updated checkout $root from origin/$branch."; return $result }
            $result.Reason = 'CheckoutBlocked'
            $result.Message = "Checkout $root was not updated: uncommitted changes touch files that changed on GitHub. Commit or stash them, then rerun. $($merge.Text)"
            return $result
        }
        if ((Invoke-RefreshGit $root @('status', '--porcelain', '--untracked-files=no')).Output.Count) {
            $result.Reason = 'CheckoutBlocked'
            $result.Message = "Checkout $root and GitHub both have new commits, and the checkout has uncommitted changes; the merge waits for your decision."
            return $result
        }
        $merge = Invoke-RefreshGit $root @('merge', '--no-edit', '--quiet', "origin/$branch")
        if ($merge.ExitCode -eq 0) { $result.Message = "Merged origin/$branch into checkout $root."; return $result }
        if ((Invoke-RefreshGit $root @('rev-parse', '-q', '--verify', 'MERGE_HEAD')).ExitCode -eq 0) { $null = Invoke-RefreshGit $root @('merge', '--abort') }
        $result.Reason = 'CheckoutConflict'
        $result.Message = "Merging origin/$branch into $root conflicts; the checkout was left as it was and waits for your decision. $($merge.Text)"
        return $result
    }
    finally {
        $env:GIT_TERMINAL_PROMPT = $previousGitPrompt
        $env:GCM_INTERACTIVE = $previousGcmInteractive
    }
}

function Publish-SkillAdaptations {
    param(
        [Parameter(Mandatory = $true)][string]$RepoUrl,
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [string[]]$FallbackPushUrls,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$Failures,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Unresolved
    )

    $catalogPath = Join-Path $RepoPath 'catalog.json'
    if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) { return }
    $adaptations = @(foreach ($entry in @(Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json)) {
        if ([string]::IsNullOrWhiteSpace([string]$entry.path)) { continue }
        $manifestPath = Join-Path (Join-Path $RepoPath ([string]$entry.path)) 'skill.json'
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { continue }
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.install -and [string]$manifest.install.strategy -ceq 'adapted') { $entry }
    })
    if (-not $adaptations.Count) { return }

    $previousGitPrompt = $env:GIT_TERMINAL_PROMPT
    $previousGcmInteractive = $env:GCM_INTERACTIVE
    try {
        $env:GIT_TERMINAL_PROMPT = '0'
        $env:GCM_INTERACTIVE = 'Never'
        $remoteHead = Invoke-RefreshGit $RepoPath @('symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD')
        if ($remoteHead.Text -cnotmatch '^origin/(\S+)$') { Write-SkillRefreshMessage "Skipped adaptation updates for ${RepoUrl}: unknown default branch."; return }
        $branch = $Matches[1]
        $pushTarget = $null
        foreach ($candidate in @('origin') + @($FallbackPushUrls | Where-Object { $_ })) {
            if ((Invoke-RefreshGit $RepoPath @('push', '--dry-run', '--quiet', $candidate, "HEAD:refs/heads/$branch")).ExitCode -eq 0) { $pushTarget = $candidate; break }
        }
        if (-not $pushTarget) { Write-SkillRefreshMessage "Skipped adaptation updates for ${RepoUrl}: no permission to publish there."; return }

        $committed = [Collections.Generic.List[string]]::new()
        foreach ($entry in $adaptations) {
            $name = [string]$entry.name
            $relativePath = [string]$entry.path
            try {
                $skillPath = Resolve-SkillSourcePath -RepositoryRoot $RepoPath -SourcePath $relativePath
                $manifest = Read-SkillManifest -SkillPath $skillPath -ExpectedName $name
                $upstreamRoot = Sync-SkillSourceRepository -RepoUrl ([string]$manifest.upstream.repo) -CacheRoot (Join-Path $cacheRoot 'upstream') -Version ([string]$manifest.upstream.version)
                $commit = (Invoke-RefreshGit $upstreamRoot @('rev-parse', 'HEAD')).Text
                $source = "$(ConvertTo-SkillRepoIdentity ([string]$manifest.upstream.repo))@$($commit.Substring(0, [Math]::Min(7, $commit.Length)))"
                $merge = Merge-SkillAdaptation -SkillPath $skillPath -Manifest $manifest -UpstreamRoot $upstreamRoot -Commit $commit
                if ($merge.Conflicts.Count) {
                    $files = $merge.Conflicts -join ', '
                    [void]$Failures.Add("${name}: Deferred - upstream changes from $source conflict with the adaptation in $files")
                    $Unresolved.Add([pscustomobject]@{ name = $name; status = 'Deferred'; reason = "AdaptationConflict: $files" })
                    Write-SkillRefreshMessage "Deferred: ${name}: upstream changes from $source conflict with SkillVault changes to $files; undo those changes, moving what is needed to the wrapper side, and the next refresh merges."
                    continue
                }
                if (-not $merge.Changed) { continue }
                if ((Invoke-RefreshGit $RepoPath @('add', '--all', '--', $relativePath)).ExitCode -ne 0) { throw "Cannot stage $relativePath." }
                if ((Invoke-RefreshGit $RepoPath @('diff', '--cached', '--quiet')).ExitCode -eq 0) { continue }
                $commitResult = Invoke-RefreshGit $RepoPath @('commit', '--quiet', '-m', "refresh: merge $source into $name")
                if ($commitResult.ExitCode -ne 0) { throw "Commit failed: $($commitResult.Text)" }
                $committed.Add($name)
            }
            catch {
                $null = Invoke-RefreshGit $RepoPath @('reset', '--quiet', '--', $relativePath)
                $null = Invoke-RefreshGit $RepoPath @('checkout', '--quiet', '--', $relativePath)
                $null = Invoke-RefreshGit $RepoPath @('clean', '-fdq', '--', $relativePath)
                [void]$Failures.Add("${name}: adaptation update failed - $($_.Exception.Message)")
                $Unresolved.Add([pscustomobject]@{ name = $name; status = 'Failed'; reason = "AdaptationUpdateFailed: $($_.Exception.Message)" })
                Write-SkillRefreshMessage "Failed adaptation update: ${name}: $($_.Exception.Message)"
            }
        }
        if (-not $committed.Count) { return }

        $push = Invoke-RefreshGit $RepoPath @('push', '--quiet', $pushTarget, "HEAD:refs/heads/$branch")
        if ($push.ExitCode -ne 0 -and (Invoke-RefreshGit $RepoPath @('fetch', '--quiet', 'origin')).ExitCode -eq 0) {
            if ((Invoke-RefreshGit $RepoPath @('rebase', '--quiet', "origin/$branch")).ExitCode -eq 0) {
                $push = Invoke-RefreshGit $RepoPath @('push', '--quiet', $pushTarget, "HEAD:refs/heads/$branch")
            }
            else { $null = Invoke-RefreshGit $RepoPath @('rebase', '--abort') }
        }
        if ($push.ExitCode -eq 0) {
            Write-SkillRefreshMessage "Published adaptation updates to ${RepoUrl}: $($committed -join ', ')"
            return
        }
        # Installed copies must not get content that GitHub does not have.
        $null = Invoke-RefreshGit $RepoPath @('checkout', '--quiet', '--detach', "origin/$branch")
        foreach ($name in $committed) {
            [void]$Failures.Add("${name}: adaptation update not published - $($push.Text)")
            $Unresolved.Add([pscustomobject]@{ name = $name; status = 'Deferred'; reason = 'PublishFailed' })
        }
        Write-SkillRefreshMessage "Deferred adaptation updates for ${RepoUrl}: push failed. $($push.Text)"
    }
    finally {
        $env:GIT_TERMINAL_PROMPT = $previousGitPrompt
        $env:GCM_INTERACTIVE = $previousGcmInteractive
    }
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
    $workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-refresh-' + [guid]::NewGuid().ToString('N'))
    $checkouts = @{}

    try {
    if (-not $RetryPlanPath) {
        $installs = @(foreach ($directory in @(Get-ChildItem -LiteralPath $globalSkillsRoot -Directory -Force)) {
            $installMetadataPath = Join-Path $directory.FullName '.skillvault-install.json'
            if (-not (Test-Path -LiteralPath $installMetadataPath -PathType Leaf)) { continue }
            try { $installMetadata = Get-Content -LiteralPath $installMetadataPath -Raw | ConvertFrom-Json } catch { continue }
            if ($installMetadata -isnot [System.Management.Automation.PSCustomObject] -or $installMetadata.installedBy -cnotin @('skillvault', 'skillvault-bootstrap') -or
                $installMetadata.requestedVersion -cne 'latest' -or $installMetadata.scope -cne 'global') { continue }
            $installMetadata
        })
        $vaultInstalls = @($installs | Where-Object { [string]$_.sourceType -cne 'upstream' })
        foreach ($url in @($vaultInstalls | ForEach-Object { if ([string]::IsNullOrWhiteSpace([string]$_.sourceRepo)) { $defaultRepo } else { [string]$_.sourceRepo } } | Sort-Object -Unique)) {
            try { $clone = Sync-Repo -RepoUrl $url }
            catch { continue }
            $fallbackUrls = @(foreach ($install in @($vaultInstalls | Where-Object { $_.sourceCheckout })) {
                $root = Get-SkillCheckoutRoot -Path ([string]$install.sourceCheckout) -RepoUrl $url
                if ($root) { (Invoke-RefreshGit $root @('remote', 'get-url', '--push', 'origin')).Text }
            }) | Where-Object { $_ } | Sort-Object -Unique
            Publish-SkillAdaptations -RepoUrl $url -RepoPath $clone -FallbackPushUrls $fallbackUrls -Failures $failures -Unresolved $unresolved
        }
        foreach ($install in @($vaultInstalls | Where-Object { $_.sourceCheckout })) {
            $checkoutKey = [string]$install.sourceCheckout
            if ($checkouts.ContainsKey($checkoutKey)) { continue }
            $repoForCheckout = if ([string]::IsNullOrWhiteSpace([string]$install.sourceRepo)) { $defaultRepo } else { [string]$install.sourceRepo }
            $state = Update-SkillLocalCheckout -Path $checkoutKey -RepoUrl $repoForCheckout
            $checkouts[$checkoutKey] = $state
            if ($state.Message) { Write-SkillRefreshMessage $state.Message }
            if ($state.Usable -and $state.Reason) {
                [void]$failures.Add("checkout ${checkoutKey}: Deferred - $($state.Message)")
                $unresolved.Add([pscustomobject]@{ name = "checkout:$checkoutKey"; status = 'Deferred'; reason = $state.Reason })
            }
        }
    }

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
            $workingSource = $null
            $origin = [string]$metadata.sourceType -ceq 'upstream'
            if ($origin) {
                $repoPath = Sync-Repo -RepoUrl $repoUrl
                $source = Join-Path $workRoot "$name-origin"
                $originRevision = Get-SkillSourceRevision -RepoPath $repoPath -SourcePath $sourcePath
                if (-not $originRevision -or -not (Export-SkillGitTree -RepoPath $repoPath -TreeIsh $originRevision -Destination $source)) {
                    throw "Path '$sourcePath' was not found in $repoUrl."
                }
                Assert-SkillUpstreamFolder -SkillPath $source -ExpectedName $name
            }
            elseif (-not [string]::IsNullOrWhiteSpace([string]$metadata.sourceCheckout)) {
                $checkoutKey = [string]$metadata.sourceCheckout
                if (-not $checkouts.ContainsKey($checkoutKey)) { $checkouts[$checkoutKey] = Update-SkillLocalCheckout -Path $checkoutKey -RepoUrl $repoUrl -NoUpdate }
                $checkout = $checkouts[$checkoutKey]
                if (-not $checkout.Usable) {
                    [void]$failures.Add("${name}: Deferred - $($checkout.Message)")
                    $unresolved.Add([pscustomobject]@{ name = $name; status = 'Deferred'; reason = $checkout.Reason })
                    Write-SkillRefreshMessage "Deferred: ${name}: $($checkout.Message)"
                    continue
                }
                $repoPath = $checkout.Root
                $source = Join-Path $workRoot "$name-committed"
                if (-not (Export-SkillGitTree -RepoPath $repoPath -TreeIsh "HEAD:$sourcePath" -Destination $source)) {
                    Write-SkillRefreshMessage "Skipped: $name has no committed version in $repoPath yet."
                    continue
                }
                $workingSource = Join-Path $repoPath $sourcePath
            }
            else {
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
            }
            # An original from upstream has no skill.json; its recorded version stays.
            $manifest = if ($origin) { [pscustomobject]@{ name = $name; version = $metadata.installedVersion } }
                else { Read-SkillManifest -SkillPath $source -ExpectedName $name -AllowReference }
            if (-not $origin -and $manifest.install -and [string]$manifest.install.strategy -ceq 'upstream') {
                Write-SkillRefreshMessage "Skipped: $name is now a reference; reinstall it to get the original from $($manifest.upstream.repo)."
                continue
            }
            if ($requested) {
                $revision = Get-SkillSourceRevision -RepoPath $repoPath -SourcePath $sourcePath
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

            $mergedLocalWork = $false
            if ($workingSource -or $origin) {
                if ($workingSource -and (Test-Path -LiteralPath $workingSource -PathType Container) -and (Test-SkillContentEqual -Source $workingSource -Target $skillDirectory.FullName)) {
                    Write-SkillRefreshMessage "Unchanged: $name matches your working copy, which already includes the committed changes."
                    continue
                }
                if (-not $revision) { $revision = Get-SkillSourceRevision -RepoPath $repoPath -SourcePath $sourcePath }
                if ($metadata.sourceRevision -and $metadata.sourceRevision -ceq $revision) {
                    Write-SkillRefreshMessage "Unchanged: $name keeps its installed changes; nothing new was committed for it."
                    continue
                }
                $base = Join-Path $workRoot "$name-base"
                $hasBase = $metadata.sourceRevision -and (Export-SkillGitTree -RepoPath $repoPath -TreeIsh ([string]$metadata.sourceRevision) -Destination $base) -and
                    @(Get-SkillFiles -SkillPath $base).Count -gt 0
                if (-not $hasBase) {
                    [void]$failures.Add("${name}: Deferred - the installed copy has changes and no recorded base to merge them with.")
                    $unresolved.Add([pscustomobject]@{ name = $name; status = 'Deferred'; reason = 'NoMergeBase' })
                    Write-SkillRefreshMessage "Deferred: ${name}: the installed copy has changes and no recorded base; reinstall it or decide which version to keep."
                    continue
                }
                if (-not (Test-SkillContentEqual -Source $base -Target $skillDirectory.FullName)) {
                    $merged = Join-Path $workRoot "$name-merged"
                    $conflicts = Merge-SkillFolder -Base $base -Ours $skillDirectory.FullName -Theirs $source -Destination $merged
                    if ($conflicts.Count) {
                        [void]$failures.Add("${name}: Deferred - merge conflict in $($conflicts -join ', ')")
                        $unresolved.Add([pscustomobject]@{ name = $name; status = 'Deferred'; reason = "MergeConflict: $($conflicts -join ', ')" })
                        Write-SkillRefreshMessage "Deferred: ${name}: your installed changes conflict with committed changes in $($conflicts -join ', '); it waits for your decision."
                        continue
                    }
                    $mergedLocalWork = -not (Test-SkillContentEqual -Source $merged -Target $source)
                    $source = $merged
                    if (-not $origin) { $manifest = Read-SkillManifest -SkillPath $source -ExpectedName $name }
                }
            }

            $updatedMetadata = [ordered]@{}
            foreach ($property in $metadata.PSObject.Properties) { $updatedMetadata[$property.Name] = $property.Value }
            $updatedMetadata['scope'] = 'global'
            $updatedMetadata['sourceRepo'] = $repoUrl
            $updatedMetadata['sourcePath'] = $sourcePath
            $updatedMetadata['installedVersion'] = $manifest.version
            $updatedMetadata['installedAt'] = (Get-Date).ToUniversalTime().ToString('o')

            if (-not $revision) { $revision = Get-SkillSourceRevision -RepoPath $repoPath -SourcePath $sourcePath }
            if ($revision) { $updatedMetadata['sourceRevision'] = $revision }

            $installResult = Copy-SkillInstallation -Source $source -TargetRoot $globalSkillsRoot -Name $name -Metadata $updatedMetadata -Force -OriginManifest $(if ($origin) { $manifest })
            $mergeNote = if ($mergedLocalWork) { ' (merged with your local changes)' } else { '' }
            Write-SkillRefreshMessage "Updated: $name $($installResult.Version) -> $($installResult.Path)$mergeNote"
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
    }
    finally { Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue }

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
$scheduledArgument = "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`" -RunOnce -GlobalSkillsPath `"$globalSkillsRoot`" -CachePath `"$cacheRoot`""
$action = New-ScheduledTaskAction -Execute $powerShellPath -Argument $scheduledArgument
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Days $IntervalDay)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Refresh latest source-backed SkillVault installs every $IntervalDay day(s)." -Force | Out-Null
Write-Output "Scheduled '$taskName' every $IntervalDay day(s)."