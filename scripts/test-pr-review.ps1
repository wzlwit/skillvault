$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../skills/github/pr-review/scripts/pr-review-core.ps1')
. (Join-Path $PSScriptRoot '../skills/github/pr-review/scripts/pr-review-runner.ps1')
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('pr-review-' + [guid]::NewGuid().ToString('N'))
$savedFixtureOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
$env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixtureRoot 'runtime-ownership'
$savedGitConfigGlobal = $env:GIT_CONFIG_GLOBAL

function Assert-PrFailure {
    param([scriptblock]$Operation, [string]$Expected)
    try { & $Operation | Out-Null }
    catch { if ($_.Exception.Message -notlike "*$Expected*") { throw }; return }
    throw "Expected failure: $Expected"
}

try {
    $paths = Get-PrReviewPaths $fixtureRoot
    $empty = Get-PrReviewList $paths
    if ($empty.entries.Count -ne 0 -or $empty.configured -or (Test-Path -LiteralPath $fixtureRoot)) { throw 'Read-only listing created user-wide state.' }
    $canonical = ConvertTo-PrReviewTarget 'https://GitHub.com/Owner/Repo/pull/12#discussion'
    if ($canonical.key -cne 'https://github.com/owner/repo/pull/12' -or $canonical.kind -cne 'pr') { throw 'PR identity was not normalized.' }
    foreach ($bad in @('https://user:secret@github.com/owner/repo', 'https://github.com/owner/repo?token=x', 'http://github.com/owner/repo', 'https://example.invalid/owner/repo', 'https://github.com/owner/repo/pull/0', 'https://github.com/owner/repo/issues/1', 'https://github.com/owner/a%2fb')) {
        Assert-PrFailure { ConvertTo-PrReviewTarget $bad } ''
    }
    $entry = Add-PrReviewWatch $paths 'https://github.com/owner/repo.git' -Limit 7 -IncludeDrafts
    $original = [System.IO.File]::ReadAllText($paths.Watchlist)
    $duplicate = Add-PrReviewWatch $paths 'https://GITHUB.com/OWNER/REPO/'
    if ($entry.id -cne $duplicate.id -or $duplicate.limit -ne 7 -or -not $duplicate.includeDrafts -or [System.IO.File]::ReadAllText($paths.Watchlist) -cne $original) { throw 'Idempotent add changed existing filters or duplicated a target.' }
    if (Test-Path -LiteralPath $paths.Config) { throw 'Adding a watch initialized runner settings.' }
    $preview = Remove-PrReviewWatch $paths $entry.id
    if (-not $preview.preview -or [System.IO.File]::ReadAllText($paths.Watchlist) -cne $original) { throw 'Removal preview changed the list.' }
    $null = Remove-PrReviewWatch $paths $entry.url -Apply
    $readded = Add-PrReviewWatch $paths $entry.url
    if ($entry.id -ceq $readded.id) { throw 'A removed entry ID was reused.' }
    $watchLock = Enter-HarnessLock $paths.WatchLock
    try { Assert-PrFailure { Add-PrReviewWatch $paths 'https://github.com/owner/other' } 'busy' }
    finally { $watchLock.Dispose() }
    $rulePath = Join-Path $fixtureRoot 'fixture-rules.md'
    [System.IO.File]::WriteAllText($rulePath, 'Fixture rules: review only approved sources.')
    $definition = [pscustomobject]@{
        runner = [pscustomobject]@{ command = 'pwsh'; maxMinutes = 1; maxCredits = 2; rulesPath = $rulePath }
        prReview = [pscustomobject]@{
            profiles = @(
                [pscustomobject]@{ model = 'fixture-best'; efforts = @('high', 'max'); contexts = @('default', 'long_context') },
                [pscustomobject]@{ model = 'fixture-other'; efforts = @('high'); contexts = @('default') }
            )
            githubHosts = @('github.com'); maxPullRequests = 2; maxCycleMinutes = 5; maxCycleCredits = 8; allowScheduled = $false; securityReview = $false
        }
    }
    $configPreview = Set-PrReviewConfiguration $paths $definition
    if (-not $configPreview.preview -or (Test-Path -LiteralPath $paths.Config)) { throw 'Configuration preview initialized state.' }
    $inheritedDefinition = $definition | ConvertTo-Json -Depth 15 | ConvertFrom-Json
    $inheritedDefinition.runner.maxMinutes = 'None'
    $inheritedDefinition.runner.maxCredits = 'Max'
    $cycleDefaults = Set-PrReviewConfiguration $paths $inheritedDefinition
    if ($cycleDefaults.effectiveRunner.maxMinutes -ne 5 -or $cycleDefaults.effectiveRunner.maxCredits -ne 8 -or (Test-Path -LiteralPath $paths.Config)) { throw 'Missing PR agent limits did not inherit the declared cycle budget without writes.' }
    $null = Set-PrReviewConfiguration $paths $definition -Apply
    $runtime = Get-HarnessPaths $paths.Root
    $config = Read-HarnessConfig $runtime
    $currentDefaults = Set-PrReviewConfiguration $paths $inheritedDefinition
    if ($currentDefaults.effectiveRunner.maxMinutes -ne 1 -or $currentDefaults.effectiveRunner.maxCredits -ne 2) { throw 'Missing PR agent limits did not preserve the current controller allowance.' }
    $profile = Select-PrReviewProfile $config ([pscustomobject]@{ efforts = @('high', 'max'); contexts = @('default', 'long_context') })
    if ($profile.model -cne 'fixture-best' -or $profile.effort -cne 'max' -or $profile.context -cne 'long_context') { throw 'Highest approved model, effort, and context were not selected.' }
    $config | Add-Member -NotePropertyName restrictions -NotePropertyValue ([pscustomobject]@{ allowedModels = @('fixture-other') })
    $restricted = Select-PrReviewProfile $config
    if ($restricted.model -cne 'fixture-other') { throw 'Model selection ignored restrictions.' }
    Write-HarnessJson $runtime.Config $config
    $restrictedPreview = Set-PrReviewConfiguration $paths $definition
    if ($restrictedPreview.selection.model -cne 'fixture-other') { throw 'Configuration preview ignored the existing model restriction.' }
    $null = Set-PrReviewConfiguration $paths $definition -Apply
    if ((Read-HarnessConfig $runtime).runner.model -cne 'fixture-other') { throw 'Applied runner selection differed from the restricted preview.' }
    $config.restrictions.allowedModels = @('unapproved-fixture')
    Assert-PrFailure { Select-PrReviewProfile $config } 'No approved ranked model'
    foreach ($placeholder in @($null, '', ' ', @(), 'None', 'Max')) {
        $config.restrictions.allowedModels = $placeholder
        if ((Select-PrReviewProfile $config).model -cne 'fixture-best') { throw 'An unspecified model allowance blocked the approved ranked PR profiles.' }
    }
    $config.PSObject.Properties.Remove('restrictions')
    Write-HarnessJson $runtime.Config $config
    Assert-PrFailure { Select-PrReviewProfile $config ([pscustomobject]@{ efforts = @('low'); contexts = @('default') }) } 'do not silently choose another model'
    $definition.prReview.profiles[0].model = 'auto'
    Assert-PrFailure { Set-PrReviewConfiguration $paths $definition } 'unique explicit model'
    $definition.prReview.profiles[0].model = 'fixture-best'
    $realProcess = ${function:Invoke-HarnessProcess}
    $script:capabilityFailure = $null
    function Invoke-HarnessProcess {
        param($Executable, $Arguments, $Directory, $MaxMinutes)
        if ($script:capabilityFailure) { return $script:capabilityFailure }
        $help = @('model', 'no-custom-instructions', 'silent', 'max-ai-credits', 'available-tools', 'deny-tool', 'no-ask-user', 'no-remote', 'no-remote-export', 'disable-builtin-mcps', 'disallow-temp-dir') | ForEach-Object { "  --$_ <value>" }
        $help += '  --reasoning-effort <level> Set effort [possible values: none, high, max]'
        $help += '  --context <tier> Set context [possible values: default, long_context]'
        [pscustomobject]@{ ExitCode = 0; Output = ($help -join "`n") }
    }
    $capabilities = Get-PrReviewCapabilities $runtime $config 1
    if ($capabilities.efforts -cnotcontains 'max' -or $capabilities.contexts -cnotcontains 'long_context') { throw 'CLI capability parsing lost supported settings.' }
    foreach ($failure in @(
        [pscustomobject]@{ ExitCode = 124; TimedOut = $true; Stopped = $false; Kind = 'Budget' },
        [pscustomobject]@{ ExitCode = 125; TimedOut = $false; Stopped = $true; Kind = 'Stopped' }
    )) {
        $script:capabilityFailure = $failure
        $caught = $null
        try { $null = Invoke-PrReviewRun $paths }
        catch { $caught = $_ }
        if (-not $caught -or (Get-HarnessFailureKind $caught) -cne $failure.Kind -or -not (Get-HarnessPause $runtime review)) { throw "Capability probe lost its $($failure.Kind) classification or durable review pause." }
        $null = Resume-HarnessTarget $runtime review 'fixture-owner' 'Fixture process is stopped' -ConfirmStopped
    }
    $script:capabilityFailure = $null
    Set-Item Function:Invoke-HarnessProcess $realProcess
    $sourceRepo = Join-Path $fixtureRoot 'fixture-origin'
    New-Item -ItemType Directory -Path $sourceRepo | Out-Null
    $null = Invoke-HarnessGit $sourceRepo @('init', '--quiet')
    [System.IO.File]::WriteAllText((Join-Path $sourceRepo 'source.txt'), 'base fixture')
    $null = Invoke-HarnessGit $sourceRepo @('add', '--', 'source.txt')
    $commitOptions = @('-c', 'user.name=PR Fixture', '-c', 'user.email=pr@example.invalid', '-c', 'commit.gpgSign=false', '-c', "core.hooksPath=$sourceRepo/no-hooks", 'commit', '--quiet', '-m')
    $null = Invoke-HarnessGit $sourceRepo ($commitOptions + @('base fixture'))
    $baseCommit = [string](Invoke-HarnessGit $sourceRepo @('rev-parse', 'HEAD'))
    $null = Invoke-HarnessGit $sourceRepo @('update-ref', 'refs/heads/main', $baseCommit)
    [System.IO.File]::WriteAllText((Join-Path $sourceRepo 'source.txt'), 'changed PR fixture')
    $prHookDirectory = Join-Path $sourceRepo '.git-empty-template'
    New-Item -ItemType Directory -Path $prHookDirectory | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $prHookDirectory 'post-checkout'), "#!/bin/sh`nprintf 'unexpected fixture hook' > ../hook-executed.txt`n")
    [System.IO.File]::WriteAllText((Join-Path $sourceRepo '.gitattributes'), "source.txt filter=pr-fixture`n")
    $null = Invoke-HarnessGit $sourceRepo @('add', '--', 'source.txt', '.git-empty-template/post-checkout', '.gitattributes')
    $null = Invoke-HarnessGit $sourceRepo @('update-index', '--chmod=+x', '--', '.git-empty-template/post-checkout')
    $null = Invoke-HarnessGit $sourceRepo ($commitOptions + @('head fixture'))
    $headCommit = [string](Invoke-HarnessGit $sourceRepo @('rev-parse', 'HEAD'))
    foreach ($number in @(1, 2)) { $null = Invoke-HarnessGit $sourceRepo @('update-ref', "refs/pull/$number/head", $headCommit) }
    $script:providerFixture = [pscustomobject]@{ Commands = [Collections.Generic.List[object]]::new(); PullReads = 0; ChangeAfterReview = $false; FailEvidence = $false; Numbers = @(1); Workers = 0; Guidance = ''; LastWorkspace = '' }
    $realCommand = ${function:Invoke-PrReviewCommand}
    function Invoke-PrReviewCommand {
        param($Runtime, $Config, $Clock, $Executable, $Arguments, $Directory, $EnvironmentVariables)
        $script:providerFixture.Commands.Add([pscustomobject]@{ executable = $Executable; arguments = @($Arguments); directory = $Directory })
        if ($Executable -ceq 'git') {
            $argumentsCopy = @($Arguments | ForEach-Object { if ($_ -ceq 'https://github.com/owner/repo.git') { $sourceRepo } elseif ($_ -ceq 'protocol.file.allow=never') { 'protocol.file.allow=always' } else { $_ } })
            return & $realCommand -Runtime $Runtime -Config $Config -Clock $Clock -Executable git -Arguments $argumentsCopy -Directory $Directory -EnvironmentVariables $EnvironmentVariables
        }
        if ($Executable -cne 'gh') { throw 'Unexpected fixture launcher.' }
        if ($Arguments[0] -ceq 'auth') { return '' }
        if ($Arguments[0] -ceq 'pr') {
            if ($Arguments -cnotcontains 'sort:updated-desc draft:false') { throw 'Repository discovery lost latest open/non-draft filters.' }
            return ConvertTo-Json -InputObject @($script:providerFixture.Numbers | ForEach-Object { [pscustomobject]@{ url = "https://github.com/owner/repo/pull/$_"; isDraft = $false; updatedAt = '2026-09-15T00:00:00Z' } })
        }
        if ($Arguments -ccontains 'graphql') {
            $second = $Arguments -ccontains 'endCursor=fixture-cursor'
            return @{ data = @{ repository = @{ pullRequest = @{ reviewThreads = @{ nodes = @(@{ id = $(if ($second) { 'thread-2' } else { 'thread-1' }); isResolved = $second; isOutdated = $false; comments = @{ nodes = @(@{ databaseId = $(if ($second) { 101 } else { 1 }) }) } }); pageInfo = @{ hasNextPage = (-not $second); endCursor = $(if ($second) { $null } else { 'fixture-cursor' }) } } } } } } | ConvertTo-Json -Depth 15
        }
        $endpoint = @($Arguments | Where-Object { $_ -like 'repos/*' })[0]
        if ($endpoint -match '/pulls/([12])$') {
            $number = [int]$Matches[1]
            $script:providerFixture.PullReads++
            $head = if ($script:providerFixture.ChangeAfterReview -and $script:providerFixture.PullReads -eq 3) { 'c' * 40 } else { $headCommit }
            return @{ number = $number; state = 'open'; draft = $false; html_url = "https://github.com/owner/repo/pull/$number"; title = 'Fixture PR'; body = 'Untrusted fixture body'; base = @{ sha = $baseCommit; ref = 'main'; repo = @{ full_name = 'owner/repo' } }; head = @{ sha = $head } } | ConvertTo-Json -Depth 8
        }
        if ($script:providerFixture.FailEvidence) { throw 'Fixture evidence unavailable' }
        if ($endpoint -match '/pulls/[12]/comments\?') {
            $comments = if ($endpoint -like '*page=1') { @(1..100 | ForEach-Object { @{ id = $_; body = "Comment $_" } }) } else { @(@{ id = 101; body = 'Last comment' }) }
            return ConvertTo-Json -InputObject @($comments)
        }
        if ($endpoint -match '/(reviews|comments)\?') { return '[]' }
        throw "Unexpected fixture request: $endpoint"
    }
    function Get-PrReviewCapabilities { param($Runtime, $Config, $MaxMinutes); $capabilities }
    function Invoke-HarnessAgent {
        param($Paths, $Config, $Task, $Workspace, $Phase, $Snapshot, $ReviewGuidance)
        $script:providerFixture.Workers++
        $script:providerFixture.Guidance = $ReviewGuidance
        $script:providerFixture.LastWorkspace = $Workspace
        if (-not $Task.untrustedInput -or $Workspace -ceq $sourceRepo -or ($Snapshot | ConvertFrom-Json).head -cne $headCommit) { throw 'Review lost snapshot isolation or exact head.' }
        [System.IO.File]::SetLastWriteTimeUtc((Join-Path $Workspace 'source.txt'), [datetime]::UtcNow.AddSeconds(2))
        [pscustomobject]@{ verdict = 'clean'; summary = 'Fixture review'; findings = @() }
    }
    $null = Add-PrReviewWatch $paths 'https://github.com/owner/repo/pull/1'
    $filterMarker = Join-Path $fixtureRoot 'snapshot-filter-executed.txt'
    $filterConfig = Join-Path $fixtureRoot 'fixture-global.gitconfig'
    $filterCommand = "printf 'unexpected fixture filter' > '$($filterMarker.Replace('\', '/'))'; cat"
    $null = Invoke-HarnessGit $sourceRepo @('config', '--file', $filterConfig, 'filter.pr-fixture.clean', $filterCommand)
    $env:GIT_CONFIG_GLOBAL = $filterConfig
    $run = Invoke-PrReviewRun $paths
    if (Test-Path -LiteralPath $filterMarker) { throw 'PR snapshot reads loaded a user Git clean filter.' }
    $env:GIT_CONFIG_GLOBAL = $savedGitConfigGlobal
    if (Test-Path -LiteralPath (Join-Path $paths.Workspaces 'hook-executed.txt')) { throw 'PR-supplied content executed as a checkout hook.' }
    if ($run.status -cne 'Completed' -or $run.discovered -ne 1 -or $run.attempted -ne 1 -or $run.results[0].status -cne 'clean' -or $script:providerFixture.Workers -ne 2) { throw ('PR cycle did not deduplicate and run one bounded review: ' + ($run | ConvertTo-Json -Depth 10)) }
    if (-not (Test-Path -LiteralPath (Join-Path $script:providerFixture.LastWorkspace '.git-empty-template/post-checkout') -PathType Leaf)) { throw 'Checkout preparation removed a PR source file that collided with a controller path.' }
    if ($script:providerFixture.Guidance -notmatch 'Last comment' -or $script:providerFixture.Guidance -notmatch 'thread-2' -or (Invoke-HarnessGit $sourceRepo @('rev-parse', 'HEAD')) -cne $headCommit) { throw 'Evidence pagination or original-checkout preservation failed.' }
    if (@(Invoke-HarnessGit $script:providerFixture.LastWorkspace @('status', '--porcelain')).Count) { throw 'Prepared PR checkout contained untracked controller input.' }
    $again = Invoke-PrReviewRun $paths
    if ($again.results[0].status -cne 'Unchanged' -or $script:providerFixture.Workers -ne 2) { throw 'An unchanged completed snapshot was reviewed again.' }
    $script:providerFixture.PullReads = 0
    $script:providerFixture.ChangeAfterReview = $true
    $stale = Invoke-PrReviewRun $paths -Again
    if ($stale.results[0].status -cne 'Stale' -or $stale.status -cne 'Partial') { throw 'A remotely changed PR was accepted as current.' }
    $script:providerFixture.ChangeAfterReview = $false
    $script:providerFixture.FailEvidence = $true
    $beforeFailure = $script:providerFixture.Workers
    $failed = Invoke-PrReviewRun $paths
    if ($failed.results[0].status -cne 'blocked' -or $script:providerFixture.Workers -ne $beforeFailure) { throw 'Missing evidence started an agent or was marked clean.' }
    $script:providerFixture.FailEvidence = $false
    $retry = Invoke-PrReviewRun $paths
    if ($retry.results[0].status -cne 'clean' -or $script:providerFixture.Workers -ne $beforeFailure + 2) { throw 'A failed snapshot did not remain pending for a later explicit run.' }
    $securityPath = Join-Path $fixtureRoot '.github/skills/differential-review'
    New-Item -ItemType Directory -Path $securityPath -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $securityPath 'SKILL.md'), 'Fixture security methodology only.')
    $securityRun = Invoke-PrReviewRun $paths -SecurityReview
    if (-not $securityRun.results[0].securityReview -or $script:providerFixture.Guidance -notmatch 'Fixture security methodology' -or (Read-HarnessConfig $runtime).prReview.securityReview) { throw 'Ad-hoc security review did not load guidance or changed the saved timer mode.' }
    $cycleLock = Enter-HarnessLock $paths.CycleLock
    try { if ((Invoke-PrReviewRun $paths).status -cne 'Busy') { throw 'Concurrent review bypassed the one-list cycle lock.' } }
    finally { $cycleLock.Dispose() }
    Assert-PrFailure { Invoke-PrReviewRun $paths -Scheduled } 'not approved'
    $definition.prReview.maxPullRequests = 1
    $null = Set-PrReviewConfiguration $paths $definition -Apply
    $script:providerFixture.Numbers = @(2, 1)
    $bounded = Invoke-PrReviewRun $paths -Again
    if ($bounded.status -cne 'Bounded' -or $bounded.attempted -ne 1 -or $bounded.deferred -ne 1 -or $bounded.results[0].key -cne 'https://github.com/owner/repo/pull/2') { throw 'Per-cycle bound or latest-PR ordering was lost.' }
    $definition.prReview.maxPullRequests = 2
    $definition.prReview.maxCycleCredits = 1
    $null = Set-PrReviewConfiguration $paths $definition -Apply
    $workersBeforeBudget = $script:providerFixture.Workers
    $creditBounded = Invoke-PrReviewRun $paths -Again
    if ($creditBounded.status -cne 'Bounded' -or $creditBounded.attempted -ne 1 -or $creditBounded.deferred -ne 1 -or $creditBounded.reservedCreditCeiling -ne 1 -or $script:providerFixture.Workers -ne $workersBeforeBudget + 2) { throw 'The exhausted reserved-credit ceiling launched another PR review.' }
    $definition.prReview.maxCycleCredits = 8
    $null = Set-PrReviewConfiguration $paths $definition -Apply
    $reportsBeforeRemove = @((Read-HarnessState $runtime).prReviews).Count
    $null = Remove-PrReviewWatch $paths $readded.id -Apply
    if (@((Read-HarnessState $runtime).prReviews).Count -ne $reportsBeforeRemove -or -not (Test-Path -LiteralPath $run.results[0].report)) { throw 'Removing a watch deleted review evidence.' }
    if ((Read-HarnessState $runtime).prReviews -isnot [array]) { throw 'PR history lost its array schema.' }
    $script:timerFixture = [pscustomobject]@{ Tasks = @([pscustomobject]@{ TaskName = 'Unrelated fixture task'; TaskPath = '\'; Description = 'Preserve'; State = 'Ready' }); Writes = 0 }
    function Get-ScheduledTask { param($TaskPath); $script:timerFixture.Tasks }
    function New-ScheduledTaskAction { param($Execute, $Argument); [pscustomobject]@{ Execute = $Execute; Arguments = $Argument } }
    function New-ScheduledTaskTrigger { param([switch]$Once, $At, $RepetitionInterval); [pscustomobject]@{ At = $At; Repetition = [pscustomobject]@{ Interval = [System.Xml.XmlConvert]::ToString([timespan]$RepetitionInterval) } } }
    function New-ScheduledTaskSettingsSet { param($MultipleInstances, [switch]$StartWhenAvailable, [switch]$AllowStartIfOnBatteries, [switch]$DontStopIfGoingOnBatteries, $ExecutionTimeLimit); [pscustomobject]@{ Instances = $MultipleInstances; Limit = $ExecutionTimeLimit } }
    function New-ScheduledTaskPrincipal { param($UserId, $LogonType, $RunLevel); [pscustomobject]@{ UserId = $UserId; LogonType = $LogonType; RunLevel = $RunLevel } }
    function Register-ScheduledTask {
        param($TaskName, $TaskPath, $Action, $Trigger, $Settings, $Principal, $Description, [switch]$Force)
        $script:timerFixture.Writes++
        $script:timerFixture.Tasks = @($script:timerFixture.Tasks | Where-Object TaskName -INE $TaskName) + @([pscustomobject]@{ TaskName = $TaskName; TaskPath = $TaskPath; Description = $Description; State = 'Ready'; Actions = @($Action); Triggers = @($Trigger); Settings = $Settings; Principal = $Principal })
    }
    function Disable-ScheduledTask { param($TaskName, $TaskPath); $script:timerFixture.Writes++; ($script:timerFixture.Tasks | Where-Object TaskName -IEQ $TaskName).State = 'Disabled' }
    function Enable-ScheduledTask { param($TaskName, $TaskPath); $script:timerFixture.Writes++; ($script:timerFixture.Tasks | Where-Object TaskName -IEQ $TaskName).State = 'Ready' }
    $runnerPath = Join-Path $PSScriptRoot '../skills/github/pr-review/scripts/pr-review.ps1'
    $timerStatus = Invoke-PrReviewTimer $paths -Action Status -RunnerPath $runnerPath
    if ($timerStatus.exists -or $script:timerFixture.Writes) { throw 'Timer inspection created a schedule.' }
    Assert-PrFailure { Invoke-PrReviewTimer $paths -RunnerPath $runnerPath } 'No single saved cadence'
    Assert-PrFailure { Invoke-PrReviewTimer $paths -IntervalDays 0.5 -RunnerPath $runnerPath -Apply } 'not approved'
    $definition.prReview.allowScheduled = $true
    $null = Set-PrReviewConfiguration $paths $definition -Apply
    $previewTimer = Invoke-PrReviewTimer $paths -IntervalDays 0.5 -RunnerPath $runnerPath
    if (-not $previewTimer.preview -or $script:timerFixture.Writes) { throw 'Timer preview performed a scheduler write.' }
    $created = Invoke-PrReviewTimer $paths -IntervalDays 0.5 -RunnerPath $runnerPath -Apply
    $null = Add-PrReviewWatch $paths 'https://github.com/owner/another-repository'
    $updated = Invoke-PrReviewTimer $paths -IntervalDays 0.25 -RunnerPath $runnerPath -Apply
    $savedTimer = $script:timerFixture.Tasks | Where-Object TaskName -CEQ $created.taskName
    if ($created.taskName -cne $updated.taskName -or $script:timerFixture.Tasks.Count -ne 2 -or $savedTimer.Actions[0].Arguments -notmatch '-Action Review.*-Scheduled' -or $savedTimer.Actions[0].Arguments -match '-Url|-Selector' -or $savedTimer.Settings.Instances -cne 'IgnoreNew' -or $savedTimer.Principal.RunLevel -cne 'Limited') { throw 'Timer setup created per-target tasks or lost the whole-list non-elevated worker.' }
    $reused = Invoke-PrReviewTimer $paths -RunnerPath $runnerPath
    if ($reused.intervalDays -ne 0.25) { throw 'Bare timer setup did not reuse its one saved cadence.' }
    $triggerBefore = $savedTimer.Triggers[0].Repetition.Interval
    $null = Invoke-PrReviewTimer $paths -Action Disable -RunnerPath $runnerPath -Apply
    $null = Invoke-PrReviewTimer $paths -Action Resume -RunnerPath $runnerPath -Apply
    if ($savedTimer.Triggers[0].Repetition.Interval -cne $triggerBefore -or $script:timerFixture.Tasks[0].State -cne 'Ready') { throw 'Resume changed the cadence or touched an unrelated task.' }
    $savedTimer.Description = 'Foreign ownership'
    Assert-PrFailure { Invoke-PrReviewTimer $paths -IntervalDays 1 -RunnerPath $runnerPath -Apply } 'different ownership'
    Write-Output 'One-timer checks passed: whole-list worker, stable current-user identity, preview, fractional cadence/reuse, upsert, disable/resume, ownership verification, and unrelated-task preservation. All schedules were fake.'
    Write-Output 'PR review checks passed: user-wide list, approved maximum profiles, complete pagination, deduplication, isolated Git snapshots, unchanged skipping, pending failures/stale heads, cycle bounds, and locks. All GitHub and AI calls were fake.'
}
finally {
    $env:SKILLVAULT_OWNERSHIP_ROOT = $savedFixtureOwnershipRoot
    $env:GIT_CONFIG_GLOBAL = $savedGitConfigGlobal
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}