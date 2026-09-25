$ErrorActionPreference = 'Stop'
$harnessCandidates = @(
    (Join-Path $PSScriptRoot '../../harness/scripts'),
    (Join-Path $PSScriptRoot '../../../planning/harness/scripts')
)
$harnessScripts = $harnessCandidates | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'harness-runner.ps1') -PathType Leaf } | Select-Object -First 1
if (-not $harnessScripts) { throw 'Install the sibling harness-init dependency before using PR review.' }
. (Join-Path $harnessScripts 'harness-store.ps1')
. (Join-Path $harnessScripts 'harness-runner.ps1')

function Get-PrReviewPaths {
    param([string]$DataRoot = (Join-Path $HOME '.copilot/pr-review'))
    $root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DataRoot)
    $configPath = if (Test-Path -LiteralPath $root -PathType Container) { (Get-HarnessPaths $root).Config } else { Join-Path $root '.harness_sv/config.json' }
    [pscustomobject]@{
        Root = $root
        Watchlist = Join-Path $root 'watchlist.json'
        WatchLock = Join-Path $root 'watchlist.lock'
        CycleLock = Join-Path $root 'cycle.lock'
        Config = $configPath
        Workspaces = Join-Path $root 'workspaces'
    }
}

function ConvertTo-PrReviewTarget {
    param([string]$Url, [string[]]$GitHubHosts = @('github.com'))
    $address = $null
    if (-not [uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$address) -or $address.Scheme -cne 'https' -or
        -not $address.IsDefaultPort -or $address.UserInfo -or $address.Query -or $address.DnsSafeHost -notin $GitHubHosts) {
        throw 'Use an HTTPS PR or repository URL on an explicitly configured GitHub host, without credentials or a query.'
    }
    $segments = @($address.AbsolutePath.Trim('/').Split('/') | ForEach-Object { [uri]::UnescapeDataString($_) })
    if ($segments.Count -notin @(2, 4) -or $segments[0] -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*$' -or
        $segments[1] -notmatch '^[A-Za-z0-9_.-]+$' -or $segments[1] -in @('.', '..')) { throw 'Expected a repository URL or /owner/repository/pull/number.' }
    $number = 0L
    if ($segments.Count -eq 4 -and ($segments[2] -cne 'pull' -or -not [long]::TryParse($segments[3], [ref]$number) -or $number -le 0)) { throw 'A PR URL requires a positive pull request number.' }
    $hostName = $address.DnsSafeHost.ToLowerInvariant()
    $owner = $segments[0].ToLowerInvariant()
    $repository = ($segments[1] -replace '\.git$', '').ToLowerInvariant()
    if (-not $repository -or $repository -in @('.', '..')) { throw 'A repository name is required.' }
    $repoUrl = "https://$hostName/$owner/$repository"
    $canonical = if ($number) { "$repoUrl/pull/$number" } else { $repoUrl }
    [pscustomobject]@{ key = $canonical; url = $canonical; repositoryUrl = $repoUrl; host = $hostName; owner = $owner; repository = $repository; number = $number; kind = $(if ($number) { 'pr' } else { 'repository' }) }
}

function Get-PrReviewHosts {
    param($Paths)
    if (Test-Path -LiteralPath $Paths.Config -PathType Leaf) { return @((Read-HarnessConfig (Get-HarnessPaths $Paths.Root)).prReview.githubHosts) }
    @('github.com')
}

function Read-PrReviewWatchlist {
    param($Paths)
    if (-not (Test-Path -LiteralPath $Paths.Watchlist)) { return [pscustomobject]@{ schemaVersion = 1; nextId = 1; entries = @() } }
    $list = Get-Content -LiteralPath $Paths.Watchlist -Raw | ConvertFrom-Json -NoEnumerate
    if ($list -is [array] -or $list.schemaVersion -ne 1 -or $list.entries -isnot [array] -or $list.nextId -isnot [long] -and $list.nextId -isnot [int] -or $list.nextId -lt 1) { throw 'Invalid PR watchlist; restore it instead of replacing its state.' }
    $keys = @()
    $ids = @()
    foreach ($entry in $list.entries) {
        $target = ConvertTo-PrReviewTarget $entry.url @($entry.host)
        if ($entry.key -cne $target.key -or $entry.kind -cne $target.kind -or $entry.id -cnotmatch '^W-[0-9]+$' -or $entry.id -cin $ids -or $entry.key -cin $keys -or
            $entry.limit -isnot [long] -and $entry.limit -isnot [int] -or $entry.limit -lt 1 -or $entry.limit -gt 100 -or $entry.includeDrafts -isnot [bool]) { throw 'Invalid or duplicate PR watchlist entry.' }
        if ([long]$entry.id.Substring(2) -ge $list.nextId) { throw 'Watchlist nextId would reuse an existing entry ID.' }
        $keys += $entry.key
        $ids += $entry.id
    }
    $list
}

function Add-PrReviewWatch {
    param($Paths, [string]$Url, [ValidateRange(1, 100)][int]$Limit = 5, [switch]$IncludeDrafts)
    $target = ConvertTo-PrReviewTarget $Url (Get-PrReviewHosts $Paths)
    New-Item -ItemType Directory -Path $Paths.Root -Force | Out-Null
    $lock = Enter-HarnessLock $Paths.WatchLock
    try {
        $list = Read-PrReviewWatchlist $Paths
        $existing = @($list.entries | Where-Object key -CEQ $target.key) | Select-Object -First 1
        if ($existing) {
            $changed = $false
            if ($PSBoundParameters.ContainsKey('Limit') -and $existing.limit -ne $Limit) { $existing.limit = $Limit; $changed = $true }
            if ($PSBoundParameters.ContainsKey('IncludeDrafts') -and $existing.includeDrafts -ne [bool]$IncludeDrafts) { $existing.includeDrafts = [bool]$IncludeDrafts; $changed = $true }
            if ($changed) { Write-HarnessJson $Paths.Watchlist $list }
            return $existing
        }
        $target | Add-Member -NotePropertyMembers @{ id = ('W-{0:D3}' -f [long]$list.nextId); limit = $Limit; includeDrafts = [bool]$IncludeDrafts; addedAt = [datetimeoffset]::UtcNow.ToString('o') }
        $list.nextId++
        $list.entries = @($list.entries) + @($target)
        Write-HarnessJson $Paths.Watchlist $list
        $target
    }
    finally { $lock.Dispose() }
}

function Remove-PrReviewWatch {
    param($Paths, [string]$Selector, [switch]$Apply)
    $list = Read-PrReviewWatchlist $Paths
    $knownHosts = @((Get-PrReviewHosts $Paths)) + @($list.entries.host)
    $key = if ($Selector -cmatch '^W-[0-9]+$') { $Selector } else { (ConvertTo-PrReviewTarget $Selector $knownHosts).key }
    $selected = @($list.entries | Where-Object { $_.id -ceq $key -or $_.key -ceq $key })
    if ($selected.Count -ne 1) { throw 'Select one exact watched URL or W- entry ID.' }
    if (-not $Apply) { return [pscustomobject]@{ preview = $true; entry = $selected[0]; reportsPreserved = $true } }
    $lock = Enter-HarnessLock $Paths.WatchLock
    try {
        $list = Read-PrReviewWatchlist $Paths
        $list.entries = @($list.entries | Where-Object id -CNE $selected[0].id)
        Write-HarnessJson $Paths.Watchlist $list
        [pscustomobject]@{ removed = $selected[0]; reportsPreserved = $true }
    }
    finally { $lock.Dispose() }
}

function Get-PrReviewList {
    param($Paths)
    $list = Read-PrReviewWatchlist $Paths
    $state = if (Test-Path -LiteralPath $Paths.Config) { Read-HarnessState (Get-HarnessPaths $Paths.Root) } else { $null }
    $latest = @($state.prReviews | Group-Object key | ForEach-Object { $_.Group | Select-Object -Last 1 })
    [pscustomobject]@{
        dataRoot = $Paths.Root
        configured = (Test-Path -LiteralPath $Paths.Config -PathType Leaf)
        entries = @(foreach ($entry in $list.entries) {
            [pscustomobject]@{ id = $entry.id; url = $entry.url; kind = $entry.kind; limit = $entry.limit; includeDrafts = $entry.includeDrafts
                reviews = @($latest | Where-Object { $_.key -ceq $entry.key -or $entry.kind -ceq 'repository' -and $_.repositoryUrl -ceq $entry.repositoryUrl }) }
        })
    }
}

function Assert-PrReviewSettings {
    param($Settings)
    if ($Settings -is [array] -or $Settings -isnot [pscustomobject] -or $Settings.profiles -isnot [array] -or $Settings.profiles.Count -eq 0) { throw 'Declare a nonempty, strongest-first profiles array.' }
    $allowedFields = @('profiles', 'githubHosts', 'maxPullRequests', 'maxCycleMinutes', 'maxCycleCredits', 'allowScheduled', 'securityReview')
    foreach ($field in $Settings.PSObject.Properties.Name) { if ($field -cnotin $allowedFields) { throw "Unknown PR review setting: $field" } }
    foreach ($field in @('maxPullRequests', 'maxCycleMinutes', 'maxCycleCredits')) {
        $value = $Settings.$field
        if ($null -eq $value -or $value -is [string] -or $value -is [bool] -or [double]$value -le 0 -or -not [double]::IsFinite([double]$value)) { throw "Declare a positive finite $field." }
    }
    if ($Settings.maxPullRequests -ne [Math]::Floor($Settings.maxPullRequests) -or $Settings.maxPullRequests -gt 100) { throw 'maxPullRequests must be an integer from 1 through 100.' }
    foreach ($field in @('allowScheduled', 'securityReview')) { if ($Settings.$field -isnot [bool]) { throw "Choose $field explicitly." } }
    if ($Settings.githubHosts -isnot [array] -or $Settings.githubHosts.Count -eq 0) { throw 'Declare the GitHub host allowlist.' }
    foreach ($hostName in $Settings.githubHosts) {
        if ($hostName -isnot [string] -or [uri]::CheckHostName($hostName) -ne [UriHostNameType]::Dns -or $hostName -notmatch '\.' -or $hostName -match '[/\\:]') { throw 'GitHub hosts must be DNS names without paths or ports.' }
    }
    $models = @()
    foreach ($profile in $Settings.profiles) {
        if ($profile -is [array] -or (@($profile.PSObject.Properties.Name | Sort-Object) -join ',') -cne 'contexts,efforts,model' -or
            $profile.model -isnot [string] -or $profile.model -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]*$' -or $profile.model -ieq 'auto' -or $profile.model -cin $models) { throw 'Each ranked profile needs one unique explicit model, efforts, and contexts.' }
        if ($profile.efforts -isnot [array] -or $profile.efforts.Count -eq 0 -or @($profile.efforts | Where-Object { $_ -cnotin @('none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max') }).Count) { throw 'Declare verified supported and approved effort levels for each model.' }
        if ($profile.contexts -isnot [array] -or $profile.contexts.Count -eq 0 -or @($profile.contexts | Where-Object { $_ -cnotin @('default', 'long_context') }).Count) { throw 'Declare verified supported and approved context tiers for each model.' }
        $models += $profile.model
    }
}

function Select-PrReviewProfile {
    param($Config, $Capabilities)
    Assert-PrReviewSettings $Config.prReview
    $restrictions = ConvertTo-HarnessRestrictions $Config.restrictions
    $profile = @($Config.prReview.profiles | Where-Object { $null -eq $restrictions.allowedModels -or $_.model -cin $restrictions.allowedModels }) | Select-Object -First 1
    if (-not $profile) { throw 'No approved ranked model is allowed by the current restrictions.' }
    $effort = @('max', 'xhigh', 'high', 'medium', 'low', 'minimal', 'none') | Where-Object { $_ -cin $profile.efforts -and ($null -eq $Capabilities -or $_ -cin $Capabilities.efforts) } | Select-Object -First 1
    $context = @('long_context', 'default') | Where-Object { $_ -cin $profile.contexts -and ($null -eq $Capabilities -or $_ -cin $Capabilities.contexts) } | Select-Object -First 1
    if (-not $effort -or -not $context) { throw 'The highest-ranked allowed model has no supported approved effort/context combination; do not silently choose another model.' }
    [pscustomobject]@{ model = $profile.model; effort = $effort; context = $context }
}

function Set-PrReviewConfiguration {
    param($Paths, $Definition, [switch]$Apply)
    if ($Definition -is [array] -or (@($Definition.PSObject.Properties.Name | Sort-Object) -join ',') -cne 'prReview,runner') { throw 'Configuration requires only runner and prReview objects; use harness policy commands for restrictions and fallback.' }
    Assert-PrReviewSettings $Definition.prReview
    foreach ($field in $Definition.runner.PSObject.Properties.Name) { if ($field -cnotin @('command', 'maxMinutes', 'maxCredits', 'rulesPath')) { throw "Unsupported PR runner setting: $field" } }
    $current = if (Test-Path -LiteralPath $Paths.Config) { Read-HarnessConfig (Get-HarnessPaths $Paths.Root) } else { $null }
    $profile = Select-PrReviewProfile ([pscustomobject]@{ prReview = $Definition.prReview; restrictions = $current.restrictions })
    $runner = [pscustomobject]@{ command = $Definition.runner.command; maxMinutes = $Definition.runner.maxMinutes; maxCredits = $Definition.runner.maxCredits; rulesPath = $Definition.runner.rulesPath; model = $profile.model; reasoningEffort = $profile.effort; contextTier = $profile.context; validationCommands = @() }
    foreach ($field in @('command', 'maxMinutes', 'maxCredits', 'rulesPath')) {
        if (Test-HarnessUnspecifiedAllowance $runner.$field) { $runner.$field = if (Test-HarnessUnspecifiedAllowance $current.runner.$field) { $null } else { $current.runner.$field } }
    }
    if (-not $runner.command) { $runner.command = 'copilot' }
    if ($null -eq $runner.maxMinutes) { $runner.maxMinutes = $Definition.prReview.maxCycleMinutes }
    if ($null -eq $runner.maxCredits) { $runner.maxCredits = $Definition.prReview.maxCycleCredits }
    Assert-HarnessRunnerConfig ([pscustomobject]@{ runner = $runner }) -ReviewOnly
    if (-not $Apply) { return [pscustomobject]@{ preview = $true; dataRoot = $Paths.Root; current = $current; proposed = $Definition; selection = $profile; effectiveRunner = $runner } }
    New-Item -ItemType Directory -Path $Paths.Root -Force | Out-Null
    $cycleLock = Enter-HarnessLock $Paths.CycleLock
    try {
        $runtime = Get-HarnessPaths $Paths.Root
        $config = Initialize-Harness $runtime
        $runLock = Enter-HarnessLock $runtime.RunLock
        try {
            if ((Read-HarnessState $runtime).active) { throw 'Recover the prior active run before changing PR settings.' }
            $config = Read-HarnessConfig $runtime
            if (-not $config.prReview) { $config.boardPath = 'reports' }
            $config | Add-Member -NotePropertyName prReview -NotePropertyValue $Definition.prReview -Force
            foreach ($field in @('command', 'maxMinutes', 'maxCredits', 'rulesPath', 'model', 'reasoningEffort', 'contextTier')) { $config.runner | Add-Member -NotePropertyName $field -NotePropertyValue $runner.$field -Force }
            $profile = Select-PrReviewProfile $config
            Assert-HarnessRestrictions -Config $config -ProjectRoot $runtime.Project -Workspace $runtime.Project -Model $profile.model -Tools @('view', 'glob', 'grep') -Executable $runner.command
            Write-HarnessJson $runtime.Config $config
            [pscustomobject]@{ configured = $true; dataRoot = $Paths.Root; selection = $profile; scheduleChanged = $false }
        }
        finally { $runLock.Dispose() }
    }
    finally { $cycleLock.Dispose() }
}

function Get-PrReviewCapabilities {
    param($Runtime, $Config, [double]$MaxMinutes)
    $result = Invoke-HarnessProcess -Executable $Config.runner.command -Arguments @('--no-auto-update', '--help') -Directory $Runtime.Project -MaxMinutes $MaxMinutes -Paths $Runtime -Config $Config -Targets @('review')
    Assert-HarnessProcessSuccess $result 'Unable to inspect the configured Copilot CLI; no review started.' -FailureKind Blocked
    foreach ($flag in @('model', 'reasoning-effort', 'context', 'no-custom-instructions', 'silent', 'max-ai-credits', 'available-tools', 'deny-tool', 'no-ask-user', 'no-remote', 'no-remote-export', 'disable-builtin-mcps', 'disallow-temp-dir')) {
        if ($result.Output -notmatch ('(?m)^\s*--' + [regex]::Escape($flag) + '(?:[\s,]|$)') -and $result.Output -notmatch ('(?m)^\s*-[a-z],\s*--' + [regex]::Escape($flag) + '(?:[\s,]|$)')) { throw "Configured CLI does not advertise --$flag; update or explicitly revise the approved profile." }
    }
    $efforts = [regex]::Match($result.Output, '(?s)--reasoning-effort\s+<[^>]+>.*?\[possible values:\s*([^\]]+)\]')
    $contexts = [regex]::Match($result.Output, '(?s)--context\s+<[^>]+>.*?\[possible values:\s*([^\]]+)\]')
    if (-not $efforts.Success -or -not $contexts.Success) { throw 'CLI effort/context capabilities are unverified; do not invent settings.' }
    [pscustomobject]@{ efforts = @($efforts.Groups[1].Value.Split(',').Trim()); contexts = @($contexts.Groups[1].Value.Split(',').Trim()) }
}