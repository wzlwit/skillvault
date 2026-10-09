$ErrorActionPreference = 'Stop'
$harnessCandidates = @(
    (Join-Path $PSScriptRoot '../../harness-runtime/scripts'),
    (Join-Path $PSScriptRoot '../../../planning/harness-runtime/scripts')
)
$harnessScripts = $harnessCandidates | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'harness-runner.ps1') -PathType Leaf } | Select-Object -First 1
if (-not $harnessScripts) { throw 'Install the sibling harness dependency before using PR review.' }
. (Join-Path $harnessScripts 'harness-store.ps1')
. (Join-Path $harnessScripts 'harness-runner.ps1')

function Get-PrReviewPaths {
    param([string]$DataRoot = (Join-Path $HOME '.copilot/pr-review'))
    $root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DataRoot)
    $configPath = if (Test-Path -LiteralPath $root -PathType Container) { (Get-HarnessPaths $root).Config } else { Join-Path $root '.harness_sv/config/project.json' }
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
    if (Test-Path -LiteralPath $Paths.Config -PathType Leaf) { return @((Get-PrReviewSettings (Read-HarnessConfig (Get-HarnessPaths $Paths.Root)).prReview).githubHosts) }
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
    [pscustomobject]@{
        dataRoot = $Paths.Root
        entries = @(foreach ($entry in (Read-PrReviewWatchlist $Paths).entries) {
            [pscustomobject]@{ id = $entry.id; url = $entry.url; kind = $entry.kind; limit = $entry.limit; includeDrafts = $entry.includeDrafts; addedAt = $entry.addedAt }
        })
    }
}

function ConvertTo-PrReviewTime {
    param($Value)
    # ConvertFrom-Json can already have turned saved ISO strings into DateTime values.
    if ($Value -is [datetime]) { return [datetimeoffset]$Value }
    $time = [datetimeoffset]::MinValue
    if ([datetimeoffset]::TryParse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$time)) { $time } else { [datetimeoffset]::MinValue }
}

function Test-PrReviewOwnerRunning {
    param($Current)
    try {
        $process = Get-Process -Id ([int]$Current.ownerProcessId) -ErrorAction Stop
        # A process that started after the marker reused the PID of an ended review.
        ([datetimeoffset]$process.StartTime) -le (ConvertTo-PrReviewTime $Current.startedAt)
    }
    catch { $false }
}

function Get-PrReviewResults {
    param($Paths)
    $entries = @((Read-PrReviewWatchlist $Paths).entries)
    $configured = Test-Path -LiteralPath $Paths.Config -PathType Leaf
    $state = if ($configured) { Read-HarnessState (Get-HarnessPaths $Paths.Root) } else { $null }
    $latest = [ordered]@{}
    foreach ($record in @($state.prReviews | Where-Object { $null -ne $_ })) { $latest[$record.key] = $record }
    $current = $state.prReviewCurrent
    if ($current -and -not $latest.Contains($current.key)) { $latest[$current.key] = $null }
    $reviews = foreach ($key in @($latest.Keys)) {
        $record = $latest[$key]
        $repositoryUrl = if ($record) { $record.repositoryUrl } else { $current.repositoryUrl }
        $watchedBy = @($entries | Where-Object { $_.key -ceq $key -or ($_.kind -ceq 'repository' -and $_.repositoryUrl -ceq $repositoryUrl) } | ForEach-Object id)
        if ($current -and $current.key -ceq $key) {
            [pscustomobject]@{ key = $key; repositoryUrl = $repositoryUrl; status = $(if (Test-PrReviewOwnerRunning $current) { 'Running' } else { 'Interrupted' })
                at = $current.startedAt; base = $current.base; head = $current.head; ownerProcessId = $current.ownerProcessId; watchedBy = $watchedBy; lastCompleted = $record }
        }
        else {
            $item = $record | Select-Object *
            $item | Add-Member -NotePropertyName watchedBy -NotePropertyValue $watchedBy -Force
            $item
        }
    }
    [pscustomobject]@{ dataRoot = $Paths.Root; configured = $configured; reviews = @($reviews | Sort-Object { ConvertTo-PrReviewTime $_.at } -Descending) }
}

# Every setting is optional; omitted ones fall back to the defaults in Get-PrReviewSettings.
function Assert-PrReviewSettings {
    param($Settings)
    if ($null -eq $Settings) { return }
    if ($Settings -is [array] -or $Settings -isnot [pscustomobject]) { throw 'PR review settings must be a JSON object.' }
    $allowedFields = @('profiles', 'githubHosts', 'maxPullRequests', 'maxCycleMinutes', 'maxCycleCredits', 'allowScheduled', 'securityReview', 'reviewLevel')
    foreach ($field in $Settings.PSObject.Properties.Name) { if ($field -cnotin $allowedFields) { throw "Unknown PR review setting: $field" } }
    foreach ($field in @('maxPullRequests', 'maxCycleMinutes', 'maxCycleCredits')) {
        $value = $Settings.$field
        if (Test-HarnessUnspecifiedAllowance $value) { continue }
        if ($value -is [string] -or $value -is [bool] -or [double]$value -le 0 -or -not [double]::IsFinite([double]$value)) { throw "$field must be a positive finite number when supplied." }
    }
    if (-not (Test-HarnessUnspecifiedAllowance $Settings.maxPullRequests) -and ($Settings.maxPullRequests -ne [Math]::Floor($Settings.maxPullRequests) -or $Settings.maxPullRequests -gt 100)) { throw 'maxPullRequests must be an integer from 1 through 100.' }
    foreach ($field in @('allowScheduled', 'securityReview')) { if ($null -ne $Settings.$field -and $Settings.$field -isnot [bool]) { throw "$field must be true or false when supplied." } }
    if (-not (Test-HarnessUnspecifiedAllowance $Settings.reviewLevel) -and ($Settings.reviewLevel -isnot [string] -or $Settings.reviewLevel -cnotin @('critical', 'broad'))) { throw 'reviewLevel must be critical or broad when supplied.' }
    if (-not (Test-HarnessUnspecifiedAllowance $Settings.githubHosts)) {
        if ($Settings.githubHosts -isnot [array]) { throw 'githubHosts must be a list of DNS names.' }
        foreach ($hostName in $Settings.githubHosts) {
            if ($hostName -isnot [string] -or [uri]::CheckHostName($hostName) -ne [UriHostNameType]::Dns -or $hostName -notmatch '\.' -or $hostName -match '[/\\:]') { throw 'GitHub hosts must be DNS names without paths or ports.' }
        }
    }
    if (Test-HarnessUnspecifiedAllowance $Settings.profiles) { return }
    if ($Settings.profiles -isnot [array]) { throw 'profiles must be a strongest-first array when supplied.' }
    $models = @()
    foreach ($profile in $Settings.profiles) {
        if ($profile -is [array] -or (@($profile.PSObject.Properties.Name | Sort-Object) -join ',') -cne 'contexts,efforts,model' -or
            $profile.model -isnot [string] -or $profile.model -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]*$' -or $profile.model -ieq 'auto' -or $profile.model -cin $models) { throw 'Each ranked profile needs one unique explicit model, efforts, and contexts.' }
        if ($profile.efforts -isnot [array] -or $profile.efforts.Count -eq 0 -or @($profile.efforts | Where-Object { $_ -cnotin @('none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max') }).Count) { throw 'Declare verified supported and approved effort levels for each model.' }
        if ($profile.contexts -isnot [array] -or $profile.contexts.Count -eq 0 -or @($profile.contexts | Where-Object { $_ -cnotin @('default', 'long_context') }).Count) { throw 'Declare verified supported and approved context tiers for each model.' }
        $models += $profile.model
    }
}

# Returns saved settings with defaults filled in; null limits mean no limit.
function Get-PrReviewSettings {
    param($Settings)
    if ($null -ne $Settings -and $Settings.PSObject.Properties['defaultProfiles']) { return $Settings }
    Assert-PrReviewSettings $Settings
    $effective = [ordered]@{ profiles = @(); githubHosts = @('github.com'); maxPullRequests = $null; maxCycleMinutes = $null; maxCycleCredits = $null; allowScheduled = $false; securityReview = $false; reviewLevel = 'critical' }
    if ($null -ne $Settings) {
        foreach ($field in @($effective.Keys)) { if (-not (Test-HarnessUnspecifiedAllowance $Settings.$field)) { $effective[$field] = $Settings.$field } }
    }
    $effective.defaultProfiles = @($effective.profiles).Count -eq 0
    [pscustomobject]$effective
}

function Get-PrReviewDefaultProfiles {
    if (-not (Get-Command Get-HarnessReviewModelList -ErrorAction SilentlyContinue)) { throw 'The installed harness has no review model list. Update harness and pr-review together, or save explicit profiles with /pr-review configure.' }
    @(foreach ($family in (Get-HarnessReviewModelList).families) {
        foreach ($model in @($family.models)) { [pscustomobject]@{ model = [string]$model; efforts = @('max', 'xhigh', 'high', 'medium', 'low', 'minimal', 'none'); contexts = @('long_context', 'default') } }
    })
}

function Read-PrReviewConfig {
    param($Runtime)
    $config = Read-HarnessConfig $Runtime
    $config | Add-Member -NotePropertyName prReview -NotePropertyValue (Get-PrReviewSettings $config.prReview) -Force
    $config
}

# Creates the user-wide controller on first use; reports live under its reports folder.
function Initialize-PrReviewController {
    param($Paths)
    New-Item -ItemType Directory -Path $Paths.Root -Force | Out-Null
    $runtime = Get-HarnessPaths $Paths.Root
    if (-not (Test-Path -LiteralPath $runtime.Config -PathType Leaf)) {
        $config = Initialize-Harness $runtime
        $config.boardPath = 'reports'
        Write-HarnessConfig $runtime $config
    }
    $runtime
}

function Select-PrReviewProfile {
    param($Config, $Capabilities)
    $settings = Get-PrReviewSettings $Config.prReview
    $restrictions = ConvertTo-HarnessRestrictions $Config.restrictions
    $profiles = if ($settings.defaultProfiles) { @(Get-PrReviewDefaultProfiles) } else { @($settings.profiles) }
    $allowed = @($profiles | Where-Object { $null -eq $restrictions.allowedModels -or $_.model -cin $restrictions.allowedModels })
    if ($allowed.Count -eq 0) { throw 'No approved ranked model is allowed by the current restrictions.' }
    $choices = @(foreach ($profile in $allowed) {
        $efforts = @(@('max', 'xhigh', 'high', 'medium', 'low', 'minimal', 'none') | Where-Object { $_ -cin $profile.efforts -and ($null -eq $Capabilities -or $_ -cin $Capabilities.efforts) })
        $context = @('long_context', 'default') | Where-Object { $_ -cin $profile.contexts -and ($null -eq $Capabilities -or $_ -cin $Capabilities.contexts) } | Select-Object -First 1
        [pscustomobject]@{ model = [string]$profile.model; efforts = $efforts; context = $context }
    })
    if ($choices[0].efforts.Count -eq 0 -or -not $choices[0].context) { throw 'The highest-ranked allowed model has no supported approved effort/context combination; do not silently choose another model.' }
    $selection = [pscustomobject]@{ model = $choices[0].model; effort = [string]$choices[0].efforts[0]; context = $choices[0].context }
    # Default models may be skipped when the CLI rejects them; saved profiles are never replaced.
    if ($settings.defaultProfiles) { $selection | Add-Member -NotePropertyName options -NotePropertyValue @($choices | Where-Object { $_.efforts.Count -and $_.context }) }
    $selection
}

function Set-PrReviewConfiguration {
    param($Paths, $Definition, [switch]$Apply)
    if ($Definition -is [array] -or $Definition -isnot [pscustomobject] -or @($Definition.PSObject.Properties.Name).Count -eq 0 -or @($Definition.PSObject.Properties.Name | Where-Object { $_ -cnotin @('runner', 'prReview') }).Count) { throw 'Configuration accepts only runner and prReview objects; use harness policy commands for restrictions and fallback.' }
    Assert-PrReviewSettings $Definition.prReview
    if ($null -ne $Definition.runner) { foreach ($field in $Definition.runner.PSObject.Properties.Name) { if ($field -cnotin @('command', 'maxMinutes', 'maxCredits', 'rulesPath')) { throw "Unsupported PR runner setting: $field" } } }
    $current = if (Test-Path -LiteralPath $Paths.Config) { Read-HarnessConfig (Get-HarnessPaths $Paths.Root) } else { $null }
    $saved = if ($null -ne $Definition.prReview) { $Definition.prReview } else { $current.prReview }
    $settings = Get-PrReviewSettings $saved
    $profile = Select-PrReviewProfile ([pscustomobject]@{ prReview = $settings; restrictions = $current.restrictions })
    $runner = [pscustomobject]@{ command = $Definition.runner.command; maxMinutes = $Definition.runner.maxMinutes; maxCredits = $Definition.runner.maxCredits; rulesPath = $Definition.runner.rulesPath; model = $profile.model; reasoningEffort = $profile.effort; contextTier = $profile.context; validationCommands = @() }
    foreach ($field in @('command', 'maxMinutes', 'maxCredits', 'rulesPath')) {
        if (Test-HarnessUnspecifiedAllowance $runner.$field) { $runner.$field = if (Test-HarnessUnspecifiedAllowance $current.runner.$field) { $null } else { $current.runner.$field } }
    }
    if (-not $runner.command) { $runner.command = 'copilot' }
    if ($null -eq $runner.maxMinutes) { $runner.maxMinutes = $settings.maxCycleMinutes }
    if ($null -eq $runner.maxCredits) { $runner.maxCredits = $settings.maxCycleCredits }
    Assert-HarnessRunnerConfig ([pscustomobject]@{ runner = $runner }) -ReviewOnly
    if (-not $Apply) { return [pscustomobject]@{ preview = $true; dataRoot = $Paths.Root; current = $current; proposed = $Definition; selection = $profile; effectiveRunner = $runner } }
    New-Item -ItemType Directory -Path $Paths.Root -Force | Out-Null
    $cycleLock = Enter-HarnessLock $Paths.CycleLock
    try {
        $runtime = Initialize-PrReviewController $Paths
        $runLock = Enter-HarnessLock $runtime.RunLock
        try {
            if ((Read-HarnessState $runtime).active) { throw 'Recover the prior active run before changing PR settings.' }
            $config = Read-HarnessConfig $runtime
            if (-not $config.prReview) { $config.boardPath = 'reports' }
            if ($null -ne $Definition.prReview) {
                $stored = [ordered]@{}
                foreach ($property in $Definition.prReview.PSObject.Properties) { if (-not (Test-HarnessUnspecifiedAllowance $property.Value)) { $stored[$property.Name] = $property.Value } }
                $config | Add-Member -NotePropertyName prReview -NotePropertyValue ([pscustomobject]$stored) -Force
            }
            foreach ($field in @('command', 'maxMinutes', 'maxCredits', 'rulesPath', 'model', 'reasoningEffort', 'contextTier')) { $config.runner | Add-Member -NotePropertyName $field -NotePropertyValue $runner.$field -Force }
            $profile = Select-PrReviewProfile $config
            Assert-HarnessRestrictions -Config $config -ProjectRoot $runtime.Project -Workspace $runtime.Project -Model $profile.model -Tools @('view', 'glob', 'grep') -Executable $runner.command
            Write-HarnessConfig $runtime $config
            [pscustomobject]@{ configured = $true; dataRoot = $Paths.Root; selection = $profile; scheduleChanged = $false }
        }
        finally { $runLock.Dispose() }
    }
    finally { $cycleLock.Dispose() }
}

function Get-PrReviewCapabilities {
    param($Runtime, $Config, [Nullable[double]]$MaxMinutes)
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