param([switch]$RefreshRetryOnly)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../skills/planning/harness/scripts/harness-duration.ps1')

function Assert-SchedulerFailure {
    param([scriptblock]$Operation)
    $failed = $false
    try { & $Operation | Out-Null } catch { $failed = $true }
    if (-not $failed) { throw 'Expected a rejected scheduler operation.' }
}

foreach ($value in @('0d', '-1h', '30', '1.5n', '0.5y', 'NaNd', '1M')) { Assert-SchedulerFailure { ConvertTo-HarnessDuration $value } }
if ((ConvertTo-HarnessDuration '0.5h').seconds -ne 1800) { throw 'Fractional fixed duration changed.' }
$anchor = [datetimeoffset]'2026-01-31T08:30:00Z'
if ((Get-HarnessNextDue '1n' $anchor ([datetimeoffset]'2026-02-28T08:30:00Z') UTC) -ne [datetimeoffset]'2026-03-31T08:30:00Z') { throw 'Calendar cadence drifted from its original anchor.' }
if ((Get-HarnessNextDue '1y' ([datetimeoffset]'2024-02-29T08:30:00Z') ([datetimeoffset]'2024-03-01T00:00:00Z') UTC) -ne [datetimeoffset]'2025-02-28T08:30:00Z') { throw 'Leap-day clamping failed.' }
if ((Get-HarnessNextDue '30m' $anchor $anchor.AddHours(3).AddMinutes(5) UTC) -ne $anchor.AddHours(3.5)) { throw 'Missed fixed ticks did not coalesce.' }
if (-not (Test-HarnessMaintenanceWindow ([datetimeoffset]'2026-09-19T08:30:00Z') UTC)) { throw 'Saturday maintenance window was not selected.' }
foreach ($time in @('2026-09-19T08:29:00Z', '2026-09-19T09:00:00Z', '2026-09-20T08:30:00Z')) {
    if (Test-HarnessMaintenanceWindow ([datetimeoffset]$time) UTC) { throw 'Maintenance ran outside Saturday 08:30-09:00.' }
}
if (Test-HarnessMaintenanceWindow ([datetimeoffset]'2026-09-19T08:45:00Z') UTC '2026-09-19') { throw 'Maintenance repeated in the same window.' }
Write-Output 'Scheduler duration checks passed: fixed/calendar cadence, coalescing, and Saturday maintenance window.'

. (Join-Path $PSScriptRoot '../skills/planning/harness-timer/scripts/harness-scheduler.ps1')
$syncHeartbeat = ${function:Sync-HarnessHeartbeat}
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('sv-scheduler-' + [guid]::NewGuid().ToString('N'))
$savedFixtureOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
$env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixture 'runtime-ownership'
try {
    $retryStart = [datetimeoffset]'2026-09-24T08:00:00Z'
    $retryJob = [pscustomobject]@{
        kind = 'refresh'; enabled = $true; retiredAt = ''; recoveryRequired = $false
        active = [pscustomobject]@{ runId = 'initial' }; lastResult = $null
        interval = '1d'; anchor = $retryStart.ToString('o'); nextDue = $retryStart.AddDays(1).ToString('o'); timeZoneId = 'UTC'
    }
    $regularDue = $retryJob.nextDue
    $retryTarget = [pscustomobject]@{ name = 'fixture'; sourceRepo = 'fixture-source'; sourcePath = 'skills/testing/fixture'; sourceRevision = 'revision-one'; metadataHash = 'metadata-one' }
    $expectedTimes = @(1, 11, 41)
    $finished = $retryStart
    for ($attempt = 0; $attempt -lt 4; $attempt++) {
        $receipt = [pscustomobject]@{ runId = $retryJob.active.runId; finishedAt = $finished.ToString('o'); status = 'Deferred'; exitCode = 0; retryTargets = @($retryTarget) }
        if (-not (Receive-HarnessScheduleResult $retryJob $receipt $finished)) { throw 'Refresh completion was not accepted.' }
        if ($retryJob.active -or $retryJob.nextDue -cne $regularDue) { throw 'Refresh retry retained a worker slot or changed the regular cadence.' }
        if ($attempt -lt 3) {
            $expected = $retryStart.AddMinutes($expectedTimes[$attempt])
            if ($retryJob.refreshRetry.attempt -ne $attempt + 1 -or (Get-HarnessScheduleDue $retryJob) -ne $expected -or $retryJob.refreshRetry.targets[0].name -cne 'fixture') { throw 'Refresh retries did not use 1, 10, and 30 minute intervals with the original targets.' }
            if (Receive-HarnessScheduleResult $retryJob $receipt $finished) { throw 'The same receipt was consumed twice.' }
            $retryJob.active = [pscustomobject]@{ runId = "retry-$($attempt + 1)" }
            $finished = $expected
        }
    }
    if ($retryJob.refreshRetry -or -not $retryJob.lastResult.retryExhausted -or (Get-HarnessScheduleDue $retryJob) -ne [datetimeoffset]$regularDue) { throw 'The third busy retry did not stop and return to normal scheduling.' }
    foreach ($status in @('Succeeded', 'NeedsRecovery', 'NeedsTransition', 'Failed')) {
        $retryJob.active = [pscustomobject]@{ runId = $status }
        $null = Receive-HarnessScheduleResult $retryJob ([pscustomobject]@{ runId = $status; finishedAt = $finished.ToString('o'); status = $status; retryTargets = @() }) $finished
        if ($retryJob.refreshRetry) { throw "Non-contention status scheduled a retry: $status" }
    }
    $retryJob.enabled = $false
    $retryJob.active = [pscustomobject]@{ runId = 'disabled' }
    $null = Receive-HarnessScheduleResult $retryJob ([pscustomobject]@{ runId = 'disabled'; finishedAt = $finished.ToString('o'); status = 'Deferred'; retryTargets = @($retryTarget) }) $finished
    if ($retryJob.refreshRetry) { throw 'A disabled refresh scheduled a retry.' }
    $retryJob.enabled = $true
    $retryJob.active = [pscustomobject]@{ runId = 'uncertain' }
    $null = Receive-HarnessScheduleResult $retryJob ([pscustomobject]@{ runId = 'uncertain'; finishedAt = $finished.ToString('o'); status = 'Failed'; requiresRecovery = $true; retryTargets = @($retryTarget) }) $finished
    if ($retryJob.enabled -or -not $retryJob.recoveryRequired -or -not $retryJob.active -or $retryJob.refreshRetry -or $retryJob.lastResult.status -cne 'NeedsRecovery') { throw 'Uncertain worker termination released ownership or scheduled an automatic retry.' }
    $otherJob = [pscustomobject]@{ kind = 'project'; active = [pscustomobject]@{ runId = 'not-refresh' }; lastResult = $null; recoveryRequired = $false }
    $null = Receive-HarnessScheduleResult $otherJob ([pscustomobject]@{ runId = 'not-refresh'; status = 'Deferred'; retryTargets = @($retryTarget) }) $finished
    if ($otherJob.refreshRetry) { throw 'Refresh retries leaked into another job kind.' }
    Write-Output 'Refresh retry state checks passed: 1/10/30-minute deadlines, released worker slot, preserved cadence, exact targets, terminal exclusions, and exhaustion.'
    if ($RefreshRetryOnly) { return }

    $paths = Get-HarnessSchedulerPaths (Join-Path $fixture 'scheduler')
    if ((Read-HarnessSchedules $paths).jobs.Count -ne 0 -or (Test-Path $paths.Root)) { throw 'Scheduler inspection created state.' }
    $publicTimer = Join-Path $PSScriptRoot '../skills/planning/harness-timer/scripts/harness-timer.ps1'
    $emptyListing = & $publicTimer -SchedulerRoot $paths.Root | ConvertFrom-Json
    if ($emptyListing.jobs.Count -or $emptyListing.heartbeatInterval -ne '1d' -or (Test-Path $paths.Root)) { throw 'The bare timer command lost the default baseline or wrote state.' }
    $baselinePreview = & $publicTimer -SchedulerRoot $paths.Root -Action Set -Target heartbeat -Interval 12h | ConvertFrom-Json
    if (-not $baselinePreview.preview -or $baselinePreview.heartbeatInterval -ne '12h' -or (Test-Path $paths.Root)) { throw 'Baseline preview wrote state or used the wrong interval.' }
    foreach ($invalid in @('1n', '1y', '0d', '0.5m', '12')) {
        Assert-SchedulerFailure { & $publicTimer -SchedulerRoot $paths.Root -Action Set -Target heartbeat -Interval $invalid -Apply }
    }
    if (Test-Path $paths.Root) { throw 'Rejected heartbeat settings created scheduler state.' }
    $project = Join-Path $fixture 'project'
    New-Item -ItemType Directory -Path $project -Force | Out-Null
    $projectPaths = Get-HarnessPaths $project
    $config = Initialize-Harness $projectPaths
    $script:heartbeatCalls = 0
    function Sync-HarnessHeartbeat { param($Paths, $State, $Now); $script:heartbeatCalls++; [pscustomobject]@{ taskName = 'fixture-heartbeat' } }
    $script:workerCalls = 0
    function Start-HarnessScheduledWorker { param($Paths, $Job, $RunId); $script:workerCalls++; [pscustomobject]@{ processId = 4321; processStartedAt = '2026-09-19T08:30:00Z' } }
    function Test-HarnessScheduledProcess { param($Active); $true }
    $retryPaths = Get-HarnessSchedulerPaths (Join-Path $fixture 'refresh-retries')
    $refreshDefinition = [pscustomobject]@{ key = 'fixture-refresh'; kind = 'refresh'; directory = $project; executable = 'pwsh'; arguments = @('-NoProfile', '-Command', 'exit 0') }
    $retryCreated = Set-HarnessSchedule $retryPaths $refreshDefinition '1d' -Now $retryStart.AddDays(-1) -Apply
    $retryId = $retryCreated.job.id
    $null = Invoke-HarnessSchedulerTick $retryPaths -Now $retryStart
    $retryState = Read-HarnessSchedules $retryPaths
    $retryReceipt = [pscustomobject]@{ runId = $retryState.jobs[0].active.runId; finishedAt = $retryStart.ToString('o'); status = 'Deferred'; retryTargets = @($retryTarget) }
    Complete-HarnessRefreshSchedule $retryPaths $retryId $retryReceipt -Now $retryStart
    $retryState = Read-HarnessSchedules $retryPaths
    if ($retryState.jobs[0].active -or $retryState.jobs[0].refreshRetry.attempt -ne 1 -or (Get-HarnessScheduleDue $retryState.jobs[0]) -ne $retryStart.AddMinutes(1)) { throw 'Worker completion did not release refresh and persist its first retry deadline.' }
    $independentDefinition = [pscustomobject]@{ key = 'fixture-independent'; kind = 'pr'; directory = $project; executable = 'pwsh'; arguments = @('-NoProfile', '-Command', 'exit 0') }
    $independent = Set-HarnessSchedule $retryPaths $independentDefinition '1d' -Now $retryStart -FirstDue $retryStart.AddSeconds(30) -Apply
    $betweenAttempts = Invoke-HarnessSchedulerTick $retryPaths -Now $retryStart.AddSeconds(30)
    if ($betweenAttempts.started.Count -ne 1 -or $betweenAttempts.started[0] -cne $independent.job.id) { throw 'An idle refresh retry prevented another job from starting.' }
    $null = Set-HarnessScheduleEnabled $retryPaths $retryId $false -Apply
    if ((Read-HarnessSchedules $retryPaths).jobs[0].refreshRetry) { throw 'Disabling an idle refresh retained its retry request.' }
    $script:heartbeatCalls = 0
    $script:workerCalls = 0
    $definition = [pscustomobject]@{ key = 'fixture-project'; kind = 'project'; projectRoot = $project; projectId = $config.projectId; directory = $project; executable = 'pwsh'; arguments = @('-NoProfile', '-Command', 'exit 0'); topic = 'e2e'; monitorName = ''; testFlow = '' }
    $now = [datetimeoffset]'2026-09-19T08:00:00Z'
    $preview = Set-HarnessSchedule $paths $definition '30m' -Now $now
    if (-not $preview.preview -or (Test-Path $paths.Root) -or $script:heartbeatCalls) { throw 'Preview registered a heartbeat or wrote state.' }
    $created = Set-HarnessSchedule $paths $definition '30m' -Now $now -Apply
    $id = $created.job.id
    if ($script:heartbeatCalls -ne 1 -or $created.job.nextDue -ne $now.AddMinutes(30).ToString('o')) { throw 'Logical schedule did not use a stable heartbeat and cadence.' }
    $legacySchedulerState = Get-Content -LiteralPath $paths.State -Raw | ConvertFrom-Json -NoEnumerate
    $legacySchedulerState.PSObject.Properties.Remove('heartbeatInterval')
    Write-HarnessJson $paths.State $legacySchedulerState
    $legacySchedulerText = [IO.File]::ReadAllText($paths.State)
    if ((Read-HarnessSchedules $paths).heartbeatInterval -ne '1d' -or [IO.File]::ReadAllText($paths.State) -cne $legacySchedulerText) { throw 'Reading an older scheduler did not use the daily baseline without rewriting state.' }
    $localSchedules = Join-Path $projectPaths.Control 'schedules.json'
    if ((Get-Content $localSchedules -Raw | ConvertFrom-Json).jobs[0].id -ne $id -or @((Get-Content $paths.State -Raw | ConvertFrom-Json).jobs).Count) { throw 'Project schedules were not stored in their own harness directory.' }
    if ((Set-HarnessSchedule $paths $definition '1h').status -ne 'NeedsInstanceChoice') { throw 'Matching schedule did not ask for reuse or new.' }
    Assert-SchedulerFailure { Set-HarnessSchedule $paths $definition '1h' -InstanceMode New -Apply }
    $tick = Invoke-HarnessSchedulerTick $paths -Now $now.AddHours(2)
    if ($tick.started.Count -ne 1 -or $script:workerCalls -ne 1) { throw 'Overdue ticks did not coalesce into one worker.' }
    $null = Invoke-HarnessSchedulerTick $paths -Now $now.AddHours(3)
    if ($script:workerCalls -ne 1) { throw 'An active worker was overlapped.' }
    New-Item -ItemType Directory -Path $paths.Receipts -Force | Out-Null
    $state = Read-HarnessSchedules $paths
    Write-HarnessJson (Join-Path $paths.Receipts ($id + '.json')) ([pscustomobject]@{ runId = $state.jobs[0].active.runId; status = 'Succeeded'; exitCode = 0 })
    $null = Set-HarnessScheduleEnabled $paths $id $false -Apply
    $null = Invoke-HarnessSchedulerTick $paths -Now $now.AddHours(4)
    if ((Read-HarnessSchedules $paths).jobs[0].active -or $script:workerCalls -ne 1) { throw 'Disabled schedule started work or failed to collect its completed result.' }
    $state = Read-HarnessSchedules $paths
    $state.jobs[0].retiredAt = $now.ToString('o')
    $cleanup = Invoke-HarnessSchedulerCleanup $paths $state -Now $now -Apply
    if ($cleanup.schedules[0].action -ne 'Disable' -or -not $state.jobs[0].staleSince) { throw 'Stale schedule was not disabled before deletion.' }
    $null = Invoke-HarnessSchedulerCleanup $paths $state -Now $now.AddDays(29) -Apply -DeleteStale
    if ($state.jobs.Count -ne 1) { throw 'Stale grace period was bypassed.' }
    $null = Invoke-HarnessSchedulerCleanup $paths $state -Now $now.AddDays(31) -Apply -DeleteStale
    if ($state.jobs.Count) { throw 'Approved stale deletion did not remove the retired schedule.' }
    foreach ($arguments in @('-File "runner.ps1"; Write-Output unsafe', '-File $env:UNTRUSTED', '-File one.ps1 -File two.ps1')) { Assert-SchedulerFailure { ConvertFrom-HarnessTaskArguments $arguments } }
    if ((ConvertFrom-HarnessTaskArguments '-NoProfile -File "C:\path with spaces\runner.ps1" -Action Cycle -Scheduled').Action -ne 'Cycle') { throw 'Literal task arguments did not parse.' }
    $script:legacyTask = [pscustomobject]@{ TaskName = 'SkillVault Harness fixture'; TaskPath = '\'; State = 'Ready'; Description = 'Fixture owner'; Actions = @([pscustomobject]@{ Execute = 'pwsh.exe'; Arguments = '-NoProfile -NonInteractive -File "C:\old\harness.ps1" -ProjectPath "' + $project + '" -Action Cycle -Scheduled' }); Triggers = @([pscustomobject]@{ Repetition = [pscustomobject]@{ Interval = 'PT45M' } }) }
    function Get-ScheduledTask { param($TaskPath); @($script:legacyTask) }
    function Get-ScheduledTaskInfo { param($TaskName, $TaskPath); [pscustomobject]@{ NextRunTime = [datetime]'2026-09-19T08:45:00' } }
    function Disable-ScheduledTask { param($TaskName, $TaskPath); $script:legacyTask.State = 'Disabled' }
    function Enable-ScheduledTask { param($TaskName, $TaskPath); $script:legacyTask.State = 'Ready' }
    $migrateDefinition = [pscustomobject]@{ key = 'migration'; kind = 'project'; projectRoot = $project; projectId = $config.projectId; directory = $project; executable = 'pwsh.exe'; arguments = @('-NoProfile', '-NonInteractive', '-File', 'C:\new\harness.ps1', '-ProjectPath', $project, '-Action', 'Cycle', '-Scheduled'); legacyTaskName = 'SkillVault Harness fixture'; legacyDescription = 'Fixture owner' }
    $migration = Convert-HarnessLegacySchedule $paths $migrateDefinition -Now $now
    if (-not $migration.preview -or $script:legacyTask.State -ne 'Ready') { throw 'Migration preview changed the old task.' }
    $migrated = Convert-HarnessLegacySchedule $paths $migrateDefinition -Now $now -Apply
    if ($script:legacyTask.State -ne 'Disabled' -or (ConvertTo-HarnessDuration $migrated.job.interval).seconds -ne 2700 -or -not $migrated.job.enabled) { throw 'Migration lost cadence or enabled two schedulers.' }
    Assert-SchedulerFailure { Convert-HarnessLegacySchedule $paths $migrateDefinition -Apply }
    $config.runner.rulesPath = Join-Path $projectPaths.Control 'rules.md'
    [IO.File]::WriteAllText($config.runner.rulesPath, 'Only run the declared temporary fixture.')
    $config.testing = [pscustomobject]@{
        environments = @([pscustomobject]@{ name = 'local'; workingDirectory = '.'; variables = @{}; requiredVariables = @(); allowScheduled = $true })
        flows = @([pscustomobject]@{ name = 'smoke'; method = 'Verify fixture output'; defaultEnvironment = 'local'; maxMinutes = 1; steps = @([pscustomobject]@{ name = 'one'; executable = 'pwsh'; arguments = @('-NoProfile', '-NonInteractive', '-Command', '[Console]::Write("fixture check")') }) })
        afterDev = @()
    }
    Write-HarnessJson $projectPaths.Config $config
    $registeredTasks = [Collections.Generic.List[object]]::new()
    function New-ScheduledTaskAction { param($Execute, $Argument); [pscustomobject]@{ Execute = $Execute; Arguments = $Argument } }
    function New-ScheduledTaskTrigger { param([switch]$Once, $At, $RepetitionInterval); [pscustomobject]@{ StartBoundary = $At; Interval = $RepetitionInterval } }
    function New-ScheduledTaskSettingsSet { param([switch]$StartWhenAvailable, [switch]$AllowStartIfOnBatteries, [switch]$DontStopIfGoingOnBatteries, $MultipleInstances, $ExecutionTimeLimit, $Priority); [pscustomobject]@{ Priority = $Priority } }
    function New-ScheduledTaskPrincipal { param($UserId, $LogonType, $RunLevel); [pscustomobject]@{ UserId = $UserId; LogonType = $LogonType; RunLevel = $RunLevel } }
    function Register-ScheduledTask { param($TaskName, $TaskPath, $Action, $Trigger, $Settings, $Principal, $Description, [switch]$Force); $registeredTasks.Add([pscustomobject]@{ TaskName = $TaskName; Description = $Description; Actions = @($Action); Triggers = @($Trigger) }) }
    $heartbeatState = Read-HarnessSchedules (Get-HarnessSchedulerPaths (Join-Path $fixture 'adaptive-heartbeat'))
    $heartbeatJob = [pscustomobject]@{ interval = '2d'; enabled = $true; active = $null; recoveryRequired = $false; nextDue = $now.AddDays(2).ToString('o') }
    $heartbeatState.jobs = @($heartbeatJob)
    $pendingRefresh = [pscustomobject]@{ kind = 'refresh'; interval = '1d'; enabled = $true; active = $null; recoveryRequired = $false; nextDue = $now.AddDays(1).ToString('o'); refreshRetry = [pscustomobject]@{ attempt = 1; nextDue = $now.AddMinutes(1).ToString('o'); targets = @($retryTarget) } }
    $heartbeatState.jobs = @($pendingRefresh)
    if ([datetimeoffset](& $syncHeartbeat $paths $heartbeatState $now).nextWake -ne $now.AddMinutes(1)) { throw 'The heartbeat ignored an earlier refresh retry deadline.' }
    $pendingRefresh.active = [pscustomobject]@{ runId = 'refresh-result-pending' }
    if ((& $syncHeartbeat $paths $heartbeatState $now).fallbackSeconds -ne 60) { throw 'An uncollected refresh result could miss its one-minute retry window.' }
    $heartbeatState.jobs = @($heartbeatJob)
    $snapshot = $heartbeatState | ConvertTo-Json -Depth 10
    $result = & $syncHeartbeat $paths $heartbeatState $now
    if ([datetimeoffset]$result.nextWake -ne $now.AddDays(1) -or $registeredTasks[-1].Triggers[0].Interval -ne [timespan]::FromDays(1)) { throw 'Routine heartbeat did not default to one day.' }
    if (($heartbeatState | ConvertTo-Json -Depth 10) -cne $snapshot) { throw 'Heartbeat synchronization changed job timing or state.' }
    $heartbeatState.heartbeatInterval = '12h'
    $result = & $syncHeartbeat $paths $heartbeatState $now
    if ([datetimeoffset]$result.nextWake -ne $now.AddHours(12) -or $registeredTasks[-1].Triggers[0].Interval -ne [timespan]::FromHours(12)) { throw 'Configured heartbeat baseline was ignored.' }
    $heartbeatState.heartbeatInterval = '1d'
    $heartbeatJob.interval = '30m'
    $heartbeatJob.nextDue = $now.AddMinutes(10).ToString('o')
    $result = & $syncHeartbeat $paths $heartbeatState $now
    if ([datetimeoffset]$result.nextWake -ne $now.AddMinutes(10) -or $registeredTasks[-1].Triggers[0].Interval -ne [timespan]::FromMinutes(30)) { throw 'Fast job cadence or exact due time was lost.' }
    $dailyJob = [pscustomobject]@{ interval = '1d'; enabled = $true; active = $null; recoveryRequired = $false; nextDue = $now.AddMinutes(5).ToString('o') }
    $heartbeatState.jobs += $dailyJob
    $result = & $syncHeartbeat $paths $heartbeatState $now
    if ([datetimeoffset]$result.nextWake -ne $now.AddMinutes(5)) { throw 'The shortest interval overrode an earlier daily-job deadline.' }
    $heartbeatJob.enabled = $false
    $dailyJob.nextDue = $now.AddDays(1).ToString('o')
    $result = & $syncHeartbeat $paths $heartbeatState $now
    if ([datetimeoffset]$result.nextWake -ne $now.AddDays(1) -or $registeredTasks[-1].Triggers[0].Interval -ne [timespan]::FromDays(1)) { throw 'Disabled fast job kept the heartbeat frequent.' }
    $heartbeatJob.active = [pscustomobject]@{ runId = 'pending-receipt' }
    $result = & $syncHeartbeat $paths $heartbeatState $now
    if ([datetimeoffset]$result.nextWake -ne $now.AddMinutes(30) -or $registeredTasks[-1].Triggers[0].Interval -ne [timespan]::FromMinutes(30)) { throw 'Outstanding worker result was delayed by the routine baseline.' }
    $heartbeatJob.active = $null
    $dailyJob.interval = '1n'
    $dailyJob.nextDue = $now.AddMonths(1).ToString('o')
    $result = & $syncHeartbeat $paths $heartbeatState $now
    if ([datetimeoffset]$result.nextWake -ne $now.AddDays(1)) { throw 'Calendar job changed the fixed heartbeat baseline.' }
    $dailyJob.interval = '0.5m'
    $result = & $syncHeartbeat $paths $heartbeatState $now
    if ($registeredTasks[-1].Triggers[0].Interval -ne [timespan]::FromMinutes(1)) { throw 'Heartbeat repetition fell below Windows minute precision.' }
    $heartbeatState.heartbeatInterval = '1n'
    Assert-SchedulerFailure { & $syncHeartbeat $paths $heartbeatState $now }
    $heartbeatState.heartbeatInterval = '1d'
    $heartbeatState.jobs = @()
    $registrationsBefore = $registeredTasks.Count
    if ((& $syncHeartbeat $paths $heartbeatState $now).state -ne 'Inactive' -or $registeredTasks.Count -ne $registrationsBefore) { throw 'An empty scheduler registered routine wakeups.' }
    function Sync-HarnessHeartbeat {
        param($Paths, $State, $Now, [string[]]$DeferredJobIds = @())
        & $syncHeartbeat $Paths $State $Now -DeferredJobIds $DeferredJobIds
    }
    $blockedPaths = Get-HarnessSchedulerPaths (Join-Path $fixture 'blocked-heartbeat')
    New-Item -ItemType Directory -Path $blockedPaths.Root | Out-Null
    $blockedState = Read-HarnessSchedules $blockedPaths
    $overdue = $now.AddMinutes(-10)
    $blockedJob = [pscustomobject]@{
        id = [guid]::NewGuid().ToString('N'); key = 'blocked'; kind = 'pr'; interval = '1d'
        directory = (Join-Path $fixture 'unavailable'); enabled = $true; active = $null
        recoveryRequired = $false; retiredAt = ''; nextDue = $overdue.ToString('o')
        anchor = $now.AddDays(-1).ToString('o'); timeZoneId = 'UTC'; lastResult = $null
    }
    $blockedState.jobs = @($blockedJob)
    Write-HarnessSchedules $blockedPaths $blockedState
    $workersBefore = $script:workerCalls
    $blockedTick = Invoke-HarnessSchedulerTick $blockedPaths -Now $now
    if ($blockedTick.started.Count -or $blockedTick.deferred -notcontains $blockedJob.id -or [datetimeoffset]$blockedTick.heartbeat.nextWake -ne $now.AddDays(1) -or $script:workerCalls -ne $workersBefore) { throw 'An unavailable daily job caused rapid heartbeat retries or launched work.' }
    $blockedState = Read-HarnessSchedules $blockedPaths
    if ([datetimeoffset]$blockedState.jobs[0].nextDue -ne $overdue) { throw 'Deferred work advanced its due time without running.' }
    $futureJob = $blockedJob | ConvertTo-Json | ConvertFrom-Json -NoEnumerate
    $futureJob.id = [guid]::NewGuid().ToString('N')
    $futureJob.key = 'future'
    $futureJob.directory = $project
    $futureJob.nextDue = $now.AddMinutes(10).ToString('o')
    $blockedState.jobs += $futureJob
    Write-HarnessSchedules $blockedPaths $blockedState
    $blockedTick = Invoke-HarnessSchedulerTick $blockedPaths -Now $now
    if ([datetimeoffset]$blockedTick.heartbeat.nextWake -ne $now.AddMinutes(10)) { throw 'Deferred work hid an earlier runnable deadline.' }
    $activeJob = $futureJob | ConvertTo-Json | ConvertFrom-Json -NoEnumerate
    $activeJob.enabled = $false
    $activeJob.active = [pscustomobject]@{ runId = [guid]::NewGuid().ToString('N'); processId = 4321; processStartedAt = $now.ToString('o') }
    $blockedJob.directory = $project
    $blockedState.jobs = @($blockedJob, $activeJob)
    Write-HarnessSchedules $blockedPaths $blockedState
    $blockedTick = Invoke-HarnessSchedulerTick $blockedPaths -Now $now
    if ($blockedTick.started.Count -or $blockedTick.deferred -notcontains $blockedJob.id -or [datetimeoffset]$blockedTick.heartbeat.nextWake -ne $now.AddMinutes(30)) { throw 'Conflicting overdue work did not use the active-worker recheck cap.' }
    New-Item -ItemType Directory -Path $blockedPaths.Receipts | Out-Null
    Write-HarnessJson (Join-Path $blockedPaths.Receipts ($activeJob.id + '.json')) ([pscustomobject]@{ runId = $activeJob.active.runId; status = 'Succeeded'; exitCode = 0 })
    $unblockedTick = Invoke-HarnessSchedulerTick $blockedPaths -Now $now.AddMinutes(30)
    if ($unblockedTick.started.Count -ne 1 -or $unblockedTick.started[0] -cne $blockedJob.id -or $script:workerCalls -ne $workersBefore + 1) { throw 'Completed-worker reconciliation failed to release deferred work.' }
    $registeredTasks.Clear()
    Write-Output 'Adaptive heartbeat checks passed: daily baseline, override, exact deadlines, fast jobs, active results, calendar jobs, disabled jobs, and bounded blocked-job rechecks.'
    $publicResult = & $publicTimer -SchedulerRoot $paths.Root -ProjectPath $project -Action Set -Topic test -TestFlow smoke -Interval 1h -Apply | ConvertFrom-Json
    if ($publicResult.job.topic -ne 'test' -or $registeredTasks.Count -ne 1) { throw "Public timer registration mismatch: topic=$($publicResult.job.topic), registrations=$($registeredTasks.Count)." }
    $beforeBaseline = Read-HarnessSchedules $paths
    $jobSnapshot = $beforeBaseline.jobs | ConvertTo-Json -Depth 25
    $maintenanceSnapshot = $beforeBaseline.maintenance | ConvertTo-Json -Depth 10
    $baselineResult = & $publicTimer -SchedulerRoot $paths.Root -Action Set -Target heartbeat -Interval 12h -Apply | ConvertFrom-Json
    $afterBaseline = Read-HarnessSchedules $paths
    if ($baselineResult.preview -or $afterBaseline.heartbeatInterval -ne '12h' -or ($afterBaseline.jobs | ConvertTo-Json -Depth 25) -cne $jobSnapshot -or ($afterBaseline.maintenance | ConvertTo-Json -Depth 10) -cne $maintenanceSnapshot) { throw 'Heartbeat configuration altered saved jobs, anchors, or maintenance.' }
    $baselineListing = & $publicTimer -SchedulerRoot $paths.Root -Target heartbeat | ConvertFrom-Json
    if ($baselineListing.heartbeatInterval -ne '12h' -or $baselineListing.jobs.Count) { throw 'Heartbeat settings were not exposed through read-only listing.' }
    $reusedBaseline = & $publicTimer -SchedulerRoot $paths.Root -Action Set -Target heartbeat -Apply | ConvertFrom-Json
    if ($reusedBaseline.heartbeatInterval -ne '12h') { throw 'Omitted heartbeat interval did not retain the saved baseline.' }
    $null = & $publicTimer -SchedulerRoot $paths.Root -ProjectPath $project -Action Clean -RetireId $migrated.job.id -Apply
    if ($registeredTasks[-1].Triggers[0].Interval -ne [timespan]::FromHours(1)) { throw 'Retiring a fast schedule did not resynchronize the heartbeat to the remaining jobs.' }
    $null = & $publicTimer -SchedulerRoot $paths.Root -ProjectPath $project -Action Disable -Id $publicResult.job.id -Apply
    $listing = & $publicTimer -SchedulerRoot $paths.Root -ProjectPath $project | ConvertFrom-Json
    if (($listing.jobs | Where-Object id -EQ $publicResult.job.id).enabled) { throw 'Public disable did not retain the logical job while disabling it.' }
    $state = Read-HarnessSchedules $paths
    $job = $state.jobs | Where-Object id -EQ $publicResult.job.id
    $executionId = [guid]::NewGuid().ToString('N')
    $job.active = [pscustomobject]@{ runId = $executionId; processId = $PID; processStartedAt = (Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o') }
    Write-HarnessSchedules $paths $state
    $heartbeatScript = Join-Path $PSScriptRoot '../skills/planning/harness-timer/scripts/harness-heartbeat.ps1'
    & $heartbeatScript -SchedulerRoot $paths.Root -Action Execute -JobId $job.id -RunId $executionId
    $receipt = Get-Content (Join-Path $paths.Receipts ($job.id + '.json')) -Raw | ConvertFrom-Json
    $execution = $receipt.output | ConvertFrom-Json
    if ($receipt.status -ne 'Succeeded' -or $receipt.runnerStatus -ne 'Passed' -or -not (Test-Path -LiteralPath $execution.report) -or $execution.result.checks[0].output -ne 'fixture check') { throw 'The scheduled test adapter lost its real output, outcome, or contained evidence.' }
    $refreshBundle = Join-Path $fixture 'refresh-adapter'
    $refreshFixture = Join-Path $refreshBundle 'scripts/refresh-runner.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $refreshFixture) -Force | Out-Null
    $refreshManifest = [pscustomobject]@{ name = 'skillvault-refresh'; version = '1.0.0'; runtimeInterfaces = [pscustomobject]@{ 'structured-refresh' = 1 } }
    Write-HarnessJson (Join-Path $refreshBundle 'skill.json') $refreshManifest
    [IO.File]::WriteAllText($refreshFixture, @'
param([switch]$RunOnce, [switch]$ResultJson, [string]$RetryPlanPath, [int]$OwnerProcessId)
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'invoked.txt'), 'invoked')
if (-not $ResultJson -or -not $OwnerProcessId) { throw 'Missing refresh transport controls.' }
$targets = @([pscustomobject]@{ name = 'fixture'; sourceRepo = 'fixture-source'; sourcePath = 'skills/testing/fixture'; sourceRevision = 'revision-one'; metadataHash = 'metadata-one' })
$status = 'Deferred'
if ($RetryPlanPath) {
    $plan = Get-Content -LiteralPath $RetryPlanPath -Raw | ConvertFrom-Json
    if ($plan.targets.Count -ne 1 -or $plan.targets[0].name -cne 'fixture') { throw 'The retry scope changed.' }
    $status = 'Succeeded'
    $targets = @()
}
[pscustomobject]@{ schemaVersion = 1; kind = 'SkillVaultRefresh'; status = $status; globalSkillsRoot = $PSScriptRoot; retryTargets = $targets; unresolved = @(); messages = @() } | ConvertTo-Json -Depth 6
'@)
    $transportPaths = Get-HarnessSchedulerPaths (Join-Path $fixture 'refresh-transport')
    $transportDefinition = [pscustomobject]@{ key = 'transport'; kind = 'refresh'; directory = $fixture; executable = 'pwsh'; arguments = @('-NoProfile', '-NonInteractive', '-File', $refreshFixture, '-RunOnce') }
    $transportJob = (Set-HarnessSchedule $transportPaths $transportDefinition '1d' -Now ([datetimeoffset]::UtcNow) -Apply).job
    foreach ($attempt in @(0, 1)) {
        $transportState = Read-HarnessSchedules $transportPaths
        $transportJob = $transportState.jobs[0]
        $transportRunId = [guid]::NewGuid().ToString('N')
        $transportJob.active = [pscustomobject]@{ runId = $transportRunId; processId = $PID; processStartedAt = (Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o') }
        Write-HarnessSchedules $transportPaths $transportState
        & $heartbeatScript -SchedulerRoot $transportPaths.Root -Action Execute -JobId $transportJob.id -RunId $transportRunId
        $completedJob = (Read-HarnessSchedules $transportPaths).jobs[0]
        if ($completedJob.active -or ($attempt -eq 0 -and $completedJob.refreshRetry.attempt -ne 1) -or ($attempt -eq 1 -and ($completedJob.refreshRetry -or $completedJob.lastResult.status -cne 'Succeeded'))) { throw 'Refresh receipt transport did not persist, apply, and clear the bounded retry.' }
        if (@(Get-ChildItem -LiteralPath $transportPaths.Receipts -Filter 'refresh-retry-*').Count) { throw 'Refresh retry input was not cleaned up.' }
    }
    Remove-Item (Join-Path (Split-Path -Parent $refreshFixture) 'invoked.txt')
    $refreshManifest.runtimeInterfaces.'structured-refresh' = 2
    Write-HarnessJson (Join-Path $refreshBundle 'skill.json') $refreshManifest
    $transportState = Read-HarnessSchedules $transportPaths
    $blockedRun = [guid]::NewGuid().ToString('N')
    $transportState.jobs[0].active = [pscustomobject]@{ runId = $blockedRun; processId = $PID; processStartedAt = (Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o') }
    Write-HarnessSchedules $transportPaths $transportState
    Assert-SchedulerFailure { & $heartbeatScript -SchedulerRoot $transportPaths.Root -Action Execute -JobId $transportJob.id -RunId $blockedRun }
    $blockedReceipt = Get-Content (Join-Path $transportPaths.Receipts ($transportJob.id + '.json')) -Raw | ConvertFrom-Json
    if ($blockedReceipt.status -cne 'Blocked' -or $blockedReceipt.requiredUpdates -notcontains 'skillvault-refresh' -or (Test-Path (Join-Path (Split-Path -Parent $refreshFixture) 'invoked.txt'))) { throw 'An incompatible saved refresh adapter launched or failed to report its required update set.' }
    $maintenanceRoot = Join-Path $fixture 'maintenance-only'
    $null = & $publicTimer -SchedulerRoot $maintenanceRoot -Action Set -Target maintenance -Apply
    $maintenanceTrigger = $registeredTasks[$registeredTasks.Count - 1].Triggers[0]
    if ($maintenanceTrigger.StartBoundary.DayOfWeek -ne [DayOfWeek]::Saturday -or $maintenanceTrigger.StartBoundary.TimeOfDay -ne [timespan]::FromHours(8.5) -or $maintenanceTrigger.Interval -ne [timespan]::FromDays(7)) { throw 'Maintenance-only setup did not wait quietly for Saturday 08:30.' }
    $historyProject = Join-Path $fixture 'history-boundary'
    New-Item -ItemType Directory -Path $historyProject | Out-Null
    $historyPaths = Get-HarnessPaths $historyProject
    $historyConfig = Initialize-Harness $historyPaths
    $report = Join-Path $historyPaths.Control 'history/old.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $report) | Out-Null
    [IO.File]::WriteAllText($report, 'Retain until harness cleanup or scheduled maintenance.')
    $historyState = Read-HarnessState $historyPaths
    $historyState.runs = @([pscustomobject]@{ id = 'old'; taskId = ''; phase = 'Test'; status = 'Passed'; finishedAt = $now.AddDays(-100).ToString('o'); report = $report })
    Write-HarnessJson $historyPaths.State $historyState
    Write-HarnessViews $historyPaths $historyConfig $historyState
    $historyBefore = [IO.File]::ReadAllText($historyPaths.State)
    $schedulePaths = Get-HarnessSchedulerPaths (Join-Path $fixture 'history-scheduler')
    $scheduleOnly = & $publicTimer -SchedulerRoot $schedulePaths.Root -ProjectPath $historyProject -Action Clean -Apply | ConvertFrom-Json
    if ($scheduleOnly.history.Count -or -not (Test-Path -LiteralPath $report) -or [IO.File]::ReadAllText($historyPaths.State) -cne $historyBefore) { throw 'Timer clean crossed its schedule boundary and pruned project history.' }
    $legacyPolicy = Join-Path $historyProject 'retention.json'
    Write-HarnessJson $legacyPolicy ([pscustomobject]@{ maxAge = '90d'; maxEntries = 5000 })
    $null = & $publicTimer -SchedulerRoot $schedulePaths.Root -ProjectPath $historyProject -Action Clean -DefinitionPath $legacyPolicy -Apply
    if ((Read-HarnessConfig $historyPaths).maintenance.maxAge -ne '90d' -or -not (Test-Path -LiteralPath $report)) { throw 'Legacy retention declaration did not delegate without running cleanup.' }
    $weeklyState = Read-HarnessSchedules $schedulePaths
    $weeklyState.maintenance.enabled = $true
    $weeklyState.maintenance.timeZoneId = 'UTC'
    $weeklyState.projects = @([pscustomobject]@{ projectId = $historyConfig.projectId; projectRoot = $historyProject; lockRoots = @($historyProject) })
    New-Item -ItemType Directory -Path $schedulePaths.Root -Force | Out-Null
    Write-HarnessSchedules $schedulePaths $weeklyState
    $null = Invoke-HarnessSchedulerTick $schedulePaths -Now $now.AddMinutes(30)
    $weeklyResult = (Read-HarnessSchedules $schedulePaths).maintenance.lastResult
    if ((Read-HarnessState $historyPaths).runs.Count -or (Test-Path -LiteralPath $report) -or $weeklyResult.history[0].pruned -notcontains 'old') { throw 'Weekly maintenance stopped invoking the shared harness history cleanup.' }
    if ($weeklyResult.PSObject.Properties['backups']) { throw 'Weekly maintenance must not manage retired installation archives.' }
    Write-Output 'Heartbeat fixtures passed: preview, identity, reuse approval, coalescing, no overlap, disable, receipts, stale grace, and a real local test adapter. AI workers and OS timer registration were fake.'
}
finally {
    $env:SKILLVAULT_OWNERSHIP_ROOT = $savedFixtureOwnershipRoot
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}