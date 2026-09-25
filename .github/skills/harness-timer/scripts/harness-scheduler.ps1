. (Join-Path $PSScriptRoot '../../harness/scripts/harness-store.ps1')
. (Join-Path $PSScriptRoot '../../harness/scripts/harness-ownership.ps1')
. (Join-Path $PSScriptRoot '../../harness/scripts/harness-duration.ps1')
. (Join-Path $PSScriptRoot '../../harness/scripts/harness-maintenance.ps1')

function Get-HarnessSchedulerPaths {
    param([string]$Root = (Join-Path $HOME '.copilot/skillvault/scheduler'))
    $directory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
    [pscustomobject]@{ Root = $directory; State = Join-Path $directory 'schedules.json'; Lock = Join-Path $directory 'scheduler.lock'; Receipts = Join-Path $directory 'receipts' }
}

function ConvertTo-HarnessHeartbeatInterval {
    param([string]$Value)
    $duration = ConvertTo-HarnessDuration $Value
    if ($null -eq $duration.seconds -or $duration.seconds -lt 60) { throw 'HeartbeatInterval requires a fixed duration of at least one minute.' }
    [timespan]::FromSeconds($duration.seconds)
}

function Read-HarnessSchedules {
    param($Paths)
    if (-not (Test-Path -LiteralPath $Paths.State)) {
        return [pscustomobject]@{ schemaVersion = 1; heartbeatInterval = '1d'; jobs = @(); projects = @(); unavailableProjects = @(); maintenance = [pscustomobject]@{ enabled = $false; timeZoneId = [TimeZoneInfo]::Local.Id; lastCompletedDate = '' }; lastTick = '' }
    }
    $state = Get-Content -LiteralPath $Paths.State -Raw | ConvertFrom-Json -NoEnumerate
    if ($state.schemaVersion -ne 1 -or $state.jobs -isnot [array] -or $state.maintenance.enabled -isnot [bool]) { throw 'Invalid scheduler state; restore it rather than replacing it.' }
    if (-not $state.PSObject.Properties['heartbeatInterval']) { $state | Add-Member -NotePropertyName heartbeatInterval -NotePropertyValue '1d' }
    $null = ConvertTo-HarnessHeartbeatInterval $state.heartbeatInterval
    $unavailable = @()
    if (-not $state.PSObject.Properties['projects']) { $state | Add-Member -NotePropertyName projects -NotePropertyValue @() }
    foreach ($project in @($state.projects)) {
        try {
            $projectPaths = Get-HarnessPaths $project.projectRoot
            $config = Read-HarnessConfig $projectPaths
            if ($config.projectId -cne $project.projectId) { throw 'Controller identity changed.' }
            $file = Join-Path $projectPaths.Control 'schedules.json'
            $local = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -NoEnumerate
            if ($local.schemaVersion -ne 1 -or $local.schedulerRoot -ine $Paths.Root -or $local.projectId -cne $project.projectId -or $local.jobs -isnot [array]) { throw 'Invalid project schedule ownership.' }
            foreach ($job in $local.jobs) {
                if ($job.kind -ne 'project' -or $job.projectId -cne $project.projectId -or $job.projectRoot -ine $project.projectRoot) { throw 'Project schedule points at a different controller.' }
            }
            $state.jobs = @($state.jobs) + @($local.jobs)
        }
        catch { $unavailable += $project }
    }
    $state | Add-Member -NotePropertyName unavailableProjects -NotePropertyValue $unavailable -Force
    $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($job in $state.jobs) {
        if ($job.id -cnotmatch '^[a-f0-9]{32}$' -or -not $ids.Add($job.id) -or $job.enabled -isnot [bool] -or $job.kind -notin @('project', 'pr', 'refresh')) { throw 'Invalid or duplicate logical schedule.' }
        $null = ConvertTo-HarnessDuration $job.interval
        $null = [TimeZoneInfo]::FindSystemTimeZoneById($job.timeZoneId)
        $null = [datetimeoffset]::Parse($job.nextDue)
        if ($job.refreshRetry) {
            if ($job.kind -cne 'refresh' -or $job.refreshRetry.attempt -notin @(1, 2, 3) -or $job.refreshRetry.targets -isnot [array] -or $job.refreshRetry.targets.Count -eq 0) { throw 'Invalid refresh retry state.' }
            $null = [datetimeoffset]::Parse($job.refreshRetry.nextDue)
        }
    }
    $state
}

function Write-HarnessSchedules {
    param($Paths, $State)
    $registered = @($State.projects)
    foreach ($group in @($State.jobs | Where-Object kind -EQ project | Group-Object projectId)) {
        if ($group.Name -cnotin @($registered.projectId)) {
            $registered += [pscustomobject]@{ projectId = $group.Name; projectRoot = $group.Group[0].projectRoot; lockRoots = @() }
        }
    }
    foreach ($project in $registered) {
        if ($project.projectId -cin @($State.unavailableProjects.projectId)) { continue }
        $projectPaths = Get-HarnessPaths $project.projectRoot
        if ((Read-HarnessConfig $projectPaths).projectId -cne $project.projectId) { throw 'Controller identity changed before saving schedules.' }
        $file = Join-Path $projectPaths.Control 'schedules.json'
        $projectLock = Enter-HarnessLock (Join-Path $projectPaths.Control 'schedules.lock')
        try {
            if (Test-Path -LiteralPath $file) {
                $saved = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
                if ($saved.schedulerRoot -ine $Paths.Root -or $saved.projectId -cne $project.projectId) { throw 'Project schedules belong to another scheduler; do not replace them.' }
            }
            $jobs = @($State.jobs | Where-Object { $_.kind -eq 'project' -and $_.projectId -ceq $project.projectId })
            $project.lockRoots = @(@($project.projectRoot) + @($jobs.lockRoots | Where-Object { $_ }) | Sort-Object -Unique)
            Write-HarnessJson $file ([pscustomobject]@{ schemaVersion = 1; projectId = $project.projectId; schedulerRoot = $Paths.Root; jobs = $jobs })
        }
        finally { $projectLock.Dispose() }
    }
    $State.projects = $registered
    $stored = $State | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $stored.jobs = @($State.jobs | Where-Object kind -NE project)
    $stored.PSObject.Properties.Remove('unavailableProjects')
    Write-HarnessJson $Paths.State $stored
}

function Get-HarnessSchedulerIdentity {
    param($Paths)
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    [pscustomobject]@{ name = 'SkillVault Harness Heartbeat ' + $identity.User.Value; path = '\'; user = $identity.Name; description = 'SkillVault scheduler ' + $identity.User.Value + ' ' + $Paths.Root }
}

function Sync-HarnessHeartbeat {
    param($Paths, $State, [datetimeoffset]$Now = [datetimeoffset]::UtcNow, [string[]]$DeferredJobIds = @())
    $identity = Get-HarnessSchedulerIdentity $Paths
    $existing = @(Get-ScheduledTask -TaskPath $identity.path -ErrorAction Stop | Where-Object { $_.TaskName -ieq $identity.name })
    if ($existing.Count -gt 1 -or ($existing.Count -eq 1 -and $existing[0].Description -cne $identity.description)) { throw 'The heartbeat task is not owned by this scheduler.' }
    $workScheduled = @($State.jobs | Where-Object { $_.enabled -or $_.active }).Count -gt 0
    if (-not $workScheduled -and -not $State.maintenance.enabled) {
        if ($existing.Count -eq 1) { Disable-ScheduledTask -TaskName $identity.name -TaskPath $identity.path -ErrorAction Stop | Out-Null }
        return [pscustomobject]@{ taskName = $identity.name; state = 'Inactive'; wakeMachine = $false; signedInOnly = $true }
    }
    $fallback = [timespan]::FromDays(7)
    if ($workScheduled) {
        $baseline = if ($State.PSObject.Properties['heartbeatInterval']) { [string]$State.heartbeatInterval } else { '1d' }
        $seconds = (ConvertTo-HarnessHeartbeatInterval $baseline).TotalSeconds
        foreach ($job in @($State.jobs | Where-Object { $_.enabled -and -not $_.recoveryRequired })) {
            $jobDuration = ConvertTo-HarnessDuration $job.interval
            if ($null -ne $jobDuration.seconds) { $seconds = [math]::Min($seconds, $jobDuration.seconds) }
        }
        if (@($State.jobs | Where-Object active).Count) { $seconds = [math]::Min($seconds, 1800) }
        if (@($State.jobs | Where-Object { $_.active -and $_.kind -ceq 'refresh' }).Count) { $seconds = [math]::Min($seconds, 60) }
        $fallback = [timespan]::FromSeconds([math]::Max(60, $seconds))
    }
    $next = if ($workScheduled) { $Now.Add($fallback) } else { [datetimeoffset]::MaxValue }
    foreach ($job in @($State.jobs | Where-Object { $_.enabled -and -not $_.active -and -not $_.recoveryRequired })) {
        $due = Get-HarnessScheduleDue $job
        if ($due -le $Now -and $job.id -cin $DeferredJobIds) { continue }
        if ($due -lt $next) { $next = $due }
    }
    if ($State.maintenance.enabled) {
        $zone = [TimeZoneInfo]::FindSystemTimeZoneById($State.maintenance.timeZoneId)
        $local = [TimeZoneInfo]::ConvertTime($Now, $zone).DateTime
        $days = (([int][DayOfWeek]::Saturday - [int]$local.DayOfWeek) + 7) % 7
        $saturday = $local.Date.AddDays($days).AddHours(8.5)
        if ($saturday -le $local) { $saturday = $saturday.AddDays(7) }
        $maintenanceDue = ConvertFrom-HarnessLocalTime $saturday $zone
        if ($maintenanceDue -lt $next) { $next = $maintenanceDue }
    }
    if ($next -le $Now) { $next = $Now.AddMinutes(1) }
    $runner = Join-Path $PSScriptRoot 'harness-heartbeat.ps1'
    foreach ($path in @($runner, $Paths.Root)) { if ($path -match '["\r\n]') { throw 'Scheduler paths cannot contain quotes or newlines.' } }
    $arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -File "' + $runner + '" -SchedulerRoot "' + $Paths.Root + '" -Action Tick'
    $action = New-ScheduledTaskAction -Execute (Get-Command pwsh -ErrorAction Stop).Source -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -Once -At $next.LocalDateTime -RepetitionInterval $fallback
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([timespan]::FromMinutes(5)) -Priority 7
    $principal = New-ScheduledTaskPrincipal -UserId $identity.user -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $identity.name -TaskPath $identity.path -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description $identity.description -Force | Out-Null
    [pscustomobject]@{ taskName = $identity.name; nextWake = $next.ToString('o'); fallbackSeconds = $fallback.TotalSeconds; wakeMachine = $false; signedInOnly = $true }
}

function Set-HarnessHeartbeatInterval {
    param($Paths, [string]$Interval, [switch]$Apply, [datetimeoffset]$Now = [datetimeoffset]::UtcNow)
    $state = Read-HarnessSchedules $Paths
    if (-not $Interval) { $Interval = $state.heartbeatInterval }
    $null = ConvertTo-HarnessHeartbeatInterval $Interval
    if (-not $Apply) { return [pscustomobject]@{ preview = $true; operation = 'HeartbeatInterval'; heartbeatInterval = $Interval; previousInterval = $state.heartbeatInterval } }
    $expectedState = $state | ConvertTo-Json -Depth 25 -Compress
    New-Item -ItemType Directory -Path $Paths.Root -Force | Out-Null
    $lock = Enter-HarnessLock $Paths.Lock
    try {
        $current = Read-HarnessSchedules $Paths
        if (($current | ConvertTo-Json -Depth 25 -Compress) -cne $expectedState) { throw 'Scheduler changed; refresh the preview.' }
        $current.heartbeatInterval = $Interval
        Write-HarnessSchedules $Paths $current
        $heartbeat = Sync-HarnessHeartbeat $Paths $current $Now
        [pscustomobject]@{ preview = $false; operation = 'HeartbeatInterval'; heartbeatInterval = $Interval; heartbeat = $heartbeat }
    }
    finally { $lock.Dispose() }
}

function Set-HarnessSchedule {
    param($Paths, $Definition, [string]$Interval, [ValidateSet('Reuse', 'New')][string]$InstanceMode, [switch]$Apply, [datetimeoffset]$Now = [datetimeoffset]::UtcNow, [Nullable[datetimeoffset]]$FirstDue, [bool]$Enabled = $true)
    $state = Read-HarnessSchedules $Paths
    $expectedState = $state | ConvertTo-Json -Depth 25 -Compress
    $existing = @($state.jobs | Where-Object { $_.key -ieq $Definition.key })
    if ($existing.Count -gt 1) { throw 'Duplicate schedule keys require recovery.' }
    if ($existing.Count -and -not $InstanceMode) {
        if ($Apply) { throw 'Choose Reuse or New before changing a matching logical schedule.' }
        return [pscustomobject]@{ preview = $true; status = 'NeedsInstanceChoice'; jobs = $existing }
    }
    if ($existing.Count -and $InstanceMode -eq 'New') { throw 'New cannot replace an existing schedule identity.' }
    if (-not $existing.Count -and $InstanceMode -eq 'Reuse') { throw 'There is no matching schedule to reuse.' }
    if (-not $Interval -and $existing.Count) { $Interval = $existing[0].interval }
    if (-not $Interval) { throw 'Choose an explicit schedule duration; no cadence is invented.' }
    $null = ConvertTo-HarnessDuration $Interval
    if ($Definition.kind -notin @('project', 'pr', 'refresh') -or -not $Definition.key -or -not $Definition.executable -or $Definition.arguments -isnot [array]) { throw 'A verified runner definition is required.' }
    if (-not [IO.Path]::IsPathRooted($Definition.directory) -or -not (Test-Path -LiteralPath $Definition.directory -PathType Container)) { throw 'The approved working directory must exist.' }
    $job = if ($existing.Count) { $existing[0] } else { [pscustomobject]@{ id = [guid]::NewGuid().ToString('N'); active = $null; lastResult = $null; recoveryRequired = $false; retiredAt = ''; staleSince = '' } }
    if ($job.active -or $job.recoveryRequired) { throw 'Finish or recover the existing worker before changing its schedule.' }
    foreach ($property in $Definition.PSObject.Properties) { $job | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value -Force }
    $zone = if ($job.timeZoneId) { $job.timeZoneId } else { [TimeZoneInfo]::Local.Id }
    $job | Add-Member -NotePropertyMembers @{ interval = $Interval; anchor = $Now.ToString('o'); nextDue = (Get-HarnessNextDue $Interval $Now $Now $zone).ToString('o'); timeZoneId = $zone; enabled = $Enabled } -Force
    $job.PSObject.Properties.Remove('refreshRetry')
    if ($null -ne $FirstDue) { $job.anchor = $FirstDue.ToString('o'); $job.nextDue = $FirstDue.ToString('o') }
    if (-not $Apply) { return [pscustomobject]@{ preview = $true; operation = $(if ($existing.Count) { 'Update' } else { 'Create' }); job = $job } }
    New-Item -ItemType Directory -Path $Paths.Root -Force | Out-Null
    $lock = Enter-HarnessLock $Paths.Lock
    try {
        $current = Read-HarnessSchedules $Paths
        if (($current | ConvertTo-Json -Depth 25 -Compress) -cne $expectedState) { throw 'Scheduler changed; refresh the preview.' }
        $saved = @($current.jobs | Where-Object { $_.key -ieq $job.key })
        if ($saved.Count -and ($saved[0].active -or $saved[0].recoveryRequired)) { throw 'The schedule became active; retry after it finishes.' }
        $current.jobs = @($current.jobs | Where-Object { $_.key -ine $job.key }) + @($job)
        Write-HarnessSchedules $Paths $current
        try { $heartbeat = Sync-HarnessHeartbeat $Paths $current $Now }
        catch { $job.enabled = $false; Write-HarnessSchedules $Paths $current; throw }
        [pscustomobject]@{ preview = $false; job = $job; heartbeat = $heartbeat }
    }
    finally { $lock.Dispose() }
}

function Set-HarnessScheduleEnabled {
    param($Paths, [string]$Id, [bool]$Enabled, [switch]$Apply, [switch]$ConfirmStopped)
    $state = Read-HarnessSchedules $Paths
    $job = @($state.jobs | Where-Object { $_.id -ceq $Id })
    if ($job.Count -ne 1) { throw 'Select one exact logical schedule ID.' }
    if (-not $Apply) { return [pscustomobject]@{ preview = $true; job = $job[0]; enabled = $Enabled } }
    $lock = Enter-HarnessLock $Paths.Lock
    try {
        $state = Read-HarnessSchedules $Paths
        $selected = @($state.jobs | Where-Object { $_.id -ceq $Id }) | Select-Object -First 1
        if (-not $selected) { throw 'The selected schedule no longer exists.' }
        if ($Enabled -and $selected.active -and -not $ConfirmStopped) { throw 'ConfirmStopped is required to recover an uncertain worker.' }
        if ($Enabled -and $ConfirmStopped) {
            if ($selected.active -and (Test-HarnessScheduledProcess $selected.active)) { throw 'The original worker is still running.' }
            $ownershipRoot = Get-SkillOwnershipRoot
            foreach ($claim in @(Read-SkillOwnershipClaims $ownershipRoot | Where-Object { $_.owner.scheduler -ieq $Paths.Root -and $_.owner.job -ceq $selected.id })) {
                Clear-SkillOwnership -Id $claim.id -Root $ownershipRoot -ConfirmStopped
            }
            $selected.active = $null; $selected.recoveryRequired = $false
        }
        if ($Enabled -and $selected.recoveryRequired) { throw 'Recover the uncertain worker before resuming.' }
        $selected.enabled = $Enabled
        if (-not $Enabled -and -not $selected.active) { $selected.PSObject.Properties.Remove('refreshRetry') }
        Write-HarnessSchedules $Paths $state
        $heartbeat = Sync-HarnessHeartbeat $Paths $state
        [pscustomobject]@{ preview = $false; job = $selected; heartbeat = $heartbeat }
    }
    finally { $lock.Dispose() }
}

function Test-HarnessScheduledProcess {
    param($Active)
    if (-not $Active.processId -or -not $Active.processStartedAt) { return $false }
    $process = Get-Process -Id $Active.processId -ErrorAction SilentlyContinue
    if (-not $process) { return $false }
    try { $process.StartTime.ToUniversalTime().Ticks -eq ([datetimeoffset]::Parse($Active.processStartedAt)).UtcTicks }
    catch { $true }
}

function Get-HarnessScheduleHealth {
    param($Job)
    if ($Job.retiredAt) { return [pscustomobject]@{ status = 'Stale'; reason = 'ExplicitlyRetired' } }
    if (-not (Test-Path -LiteralPath $Job.directory -PathType Container)) { return [pscustomobject]@{ status = 'Unknown'; reason = 'WorkingDirectoryUnavailable' } }
    if ($Job.kind -eq 'project') {
        try {
            $paths = Get-HarnessPaths $Job.projectRoot
            $config = Read-HarnessConfig $paths
            if ($config.projectId -cne $Job.projectId) { return [pscustomobject]@{ status = 'Unknown'; reason = 'ControllerIdentityChanged' } }
            if ($Job.monitorName -and $Job.monitorName -notin @($config.monitoring.monitors.name)) { return [pscustomobject]@{ status = 'Stale'; reason = 'MonitorDeclarationRemoved' } }
            if ($Job.testFlow -and $Job.testFlow -notin @($config.testing.flows.name)) { return [pscustomobject]@{ status = 'Stale'; reason = 'TestDeclarationRemoved' } }
        }
        catch { return [pscustomobject]@{ status = 'Unknown'; reason = 'ControllerUnavailable' } }
    }
    [pscustomobject]@{ status = 'Valid'; reason = '' }
}

function Get-HarnessScheduleRoots {
    param($Job)
    $roots = @($Job.directory)
    if ($Job.kind -eq 'project') {
        $roots += @($Job.lockRoots | Where-Object { $_ })
        try {
            $projectPaths = Get-HarnessPaths $Job.projectRoot
            $roots += Get-HarnessExecutionRoot (Read-HarnessConfig $projectPaths)
            $state = Read-HarnessState $projectPaths
            $roots += @($state.references | Where-Object { $_.active -and [IO.Path]::IsPathRooted([string]$_.source) } | ForEach-Object { $_.source })
            $roots += @($state.tasks | ForEach-Object { $_.workspace } | Where-Object { $_ })
        }
        catch { if (-not $Job.lockRoots) { throw 'Cannot verify the working roots of an active schedule.' } }
    }
    @($roots | Sort-Object -Unique)
}

function Test-HarnessScheduleConflict {
    param($Left, $Right)
    if ($Left.kind -eq 'refresh' -or $Right.kind -eq 'refresh') { return $true }
    foreach ($leftRoot in @(Get-HarnessScheduleRoots $Left)) {
        foreach ($rightRoot in @(Get-HarnessScheduleRoots $Right)) {
            $leftPath = [IO.Path]::GetFullPath($leftRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
            $rightPath = [IO.Path]::GetFullPath($rightRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
            if ($leftPath.StartsWith($rightPath, [StringComparison]::OrdinalIgnoreCase) -or $rightPath.StartsWith($leftPath, [StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
    }
    $false
}

function Start-HarnessScheduledWorker {
    param($Paths, $Job, [string]$RunId)
    $start = [Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -ErrorAction Stop).Source)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    foreach ($argument in @('-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-File', (Join-Path $PSScriptRoot 'harness-heartbeat.ps1'), '-SchedulerRoot', $Paths.Root, '-Action', 'Execute', '-JobId', $Job.id, '-RunId', $RunId)) { $start.ArgumentList.Add($argument) }
    foreach ($name in @('NODE_OPTIONS', 'VSCODE_INSPECTOR_OPTIONS')) { $null = $start.Environment.Remove($name) }
    $process = [Diagnostics.Process]::Start($start)
    try {
        $process.PriorityClass = [Diagnostics.ProcessPriorityClass]::BelowNormal
        [pscustomobject]@{ processId = $process.Id; processStartedAt = $process.StartTime.ToUniversalTime().ToString('o') }
    }
    finally { $process.Dispose() }
}

function Receive-HarnessScheduleResult {
    param($Job, $Receipt, [datetimeoffset]$Now)
    if (-not $Job.active -or $Receipt.runId -cne $Job.active.runId) { return $false }
    $Job.lastResult = $Receipt | Select-Object runId, startedAt, finishedAt, status, runnerStatus, exitCode
    if ($Receipt.requiresRecovery -eq $true) {
        $Job.enabled = $false
        $Job.recoveryRequired = $true
        $Job.lastResult.status = 'NeedsRecovery'
        $Job.PSObject.Properties.Remove('refreshRetry')
        return $true
    }
    if ($Job.kind -ceq 'refresh') {
        $attempt = if ($Job.refreshRetry) { [int]$Job.refreshRetry.attempt } else { 0 }
        $targets = @($Receipt.retryTargets | Where-Object { $null -ne $_ })
        $retryable = $Receipt.status -ceq 'Deferred' -and $targets.Count -gt 0
        $Job.lastResult | Add-Member -NotePropertyMembers @{ retryAttempt = $attempt; retryExhausted = ($retryable -and $attempt -ge 3) }
        $Job.lastResult | Add-Member -NotePropertyName unresolved -NotePropertyValue @($Receipt.unresolved | Where-Object { $null -ne $_ })
        $Job.PSObject.Properties.Remove('refreshRetry')
        if ($retryable -and $attempt -lt 3 -and $Job.enabled -and -not $Job.retiredAt -and -not $Job.recoveryRequired) {
            $delays = @(1, 10, 30)
            $finished = [datetimeoffset]::Parse($Receipt.finishedAt)
            $Job | Add-Member -NotePropertyName refreshRetry -NotePropertyValue ([pscustomobject]@{
                attempt = $attempt + 1
                nextDue = $finished.AddMinutes($delays[$attempt]).ToString('o')
                targets = $targets
                globalSkillsRoot = $Receipt.globalSkillsRoot
                unresolved = @($Receipt.unresolved | Where-Object { $null -ne $_ })
            })
        }
        elseif ($attempt -gt 0 -and [datetimeoffset]::Parse($Job.nextDue) -le $Now) {
            $Job.nextDue = (Get-HarnessNextDue $Job.interval ([datetimeoffset]::Parse($Job.anchor)) $Now $Job.timeZoneId).ToString('o')
        }
    }
    $Job.active = $null
    $Job.recoveryRequired = $false
    $true
}

function Get-HarnessScheduleDue {
    param($Job)
    if ($Job.kind -ceq 'refresh' -and $Job.refreshRetry) { return [datetimeoffset]::Parse($Job.refreshRetry.nextDue) }
    [datetimeoffset]::Parse($Job.nextDue)
}

function Complete-HarnessRefreshSchedule {
    param($Paths, [string]$JobId, $Receipt, [datetimeoffset]$Now = [datetimeoffset]::UtcNow)
    try { $lock = Enter-HarnessLock $Paths.Lock }
    catch { if ($_.Exception.Message -like '*Harness is busy*') { return }; throw }
    try {
        $state = Read-HarnessSchedules $Paths
        $jobs = @($state.jobs | Where-Object { $_.id -ceq $JobId -and $_.kind -ceq 'refresh' })
        if ($jobs.Count -ne 1 -or -not (Receive-HarnessScheduleResult $jobs[0] $Receipt $Now)) { return }
        $jobs[0].lastResult | Add-Member -NotePropertyName receipt -NotePropertyValue (Join-Path $Paths.Receipts ($JobId + '.json'))
        Write-HarnessSchedules $Paths $state
        $null = Sync-HarnessHeartbeat $Paths $state $Now
    }
    finally { $lock.Dispose() }
}

function Invoke-HarnessSchedulerTick {
    param($Paths, [datetimeoffset]$Now = [datetimeoffset]::UtcNow)
    if (-not (Test-Path -LiteralPath $Paths.State)) { return [pscustomobject]@{ status = 'NotConfigured'; started = @() } }
    $lock = Enter-HarnessLock $Paths.Lock
    try {
        $state = Read-HarnessSchedules $Paths
        foreach ($job in @($state.jobs | Where-Object active)) {
            $receiptPath = Join-Path $Paths.Receipts ($job.id + '.json')
            $receipt = $null
            try { if (Test-Path -LiteralPath $receiptPath) { $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json } }
            catch { $job.recoveryRequired = $true; $job.enabled = $false; continue }
            if ($receipt -and $receipt.runId -ceq $job.active.runId) {
                $null = Receive-HarnessScheduleResult $job $receipt $Now
                $job.lastResult | Add-Member -NotePropertyName receipt -NotePropertyValue $receiptPath
            }
            elseif (-not (Test-HarnessScheduledProcess $job.active)) {
                $job.recoveryRequired = $true; $job.enabled = $false
            }
        }
        if ($state.maintenance.enabled -and -not @($state.jobs | Where-Object active).Count -and
            (Test-HarnessMaintenanceWindow $Now $state.maintenance.timeZoneId $state.maintenance.lastCompletedDate)) {
            $maintenance = Invoke-HarnessSchedulerCleanup -Paths $Paths -State $state -Now $Now -Apply -Automatic
            $state.maintenance | Add-Member -NotePropertyName lastResult -NotePropertyValue $maintenance -Force
            $state.maintenance.lastCompletedDate = [TimeZoneInfo]::ConvertTime($Now, [TimeZoneInfo]::FindSystemTimeZoneById($state.maintenance.timeZoneId)).ToString('yyyy-MM-dd')
        }
        $started = [Collections.Generic.List[string]]::new()
        $deferred = [Collections.Generic.List[string]]::new()
        foreach ($job in @($state.jobs | Where-Object { $_.enabled -and -not $_.active -and -not $_.recoveryRequired } | Sort-Object @{ Expression = { Get-HarnessScheduleDue $_ } }, id)) {
            if ((Get-HarnessScheduleDue $job) -gt $Now) { continue }
            $health = Get-HarnessScheduleHealth $job
            if ($health.status -ne 'Valid') { $job.lastResult = $health; $deferred.Add($job.id); continue }
            $conflict = $false
            foreach ($active in @($state.jobs | Where-Object active)) { if (Test-HarnessScheduleConflict $job $active) { $conflict = $true; break } }
            foreach ($unavailable in @($state.unavailableProjects)) {
                $unknown = [pscustomobject]@{ kind = 'project'; directory = $unavailable.projectRoot; projectRoot = $unavailable.projectRoot; lockRoots = $unavailable.lockRoots }
                if (Test-HarnessScheduleConflict $job $unknown) { $conflict = $true; break }
            }
            if ($conflict) { $deferred.Add($job.id); continue }
            $runId = [guid]::NewGuid().ToString('N')
            $job | Add-Member -NotePropertyName lockRoots -NotePropertyValue @(Get-HarnessScheduleRoots $job) -Force
            $job.active = [pscustomobject]@{ runId = $runId; processId = $null; processStartedAt = ''; claimedAt = $Now.ToString('o') }
            if (-not $job.refreshRetry) { $job.nextDue = (Get-HarnessNextDue $job.interval ([datetimeoffset]::Parse($job.anchor)) $Now $job.timeZoneId).ToString('o') }
            Write-HarnessSchedules $Paths $state
            try {
                $worker = Start-HarnessScheduledWorker $Paths $job $runId
                $job.active.processId = $worker.processId; $job.active.processStartedAt = $worker.processStartedAt
                $started.Add($job.id)
            }
            catch { $job.recoveryRequired = $true; $job.enabled = $false; $job.lastResult = [pscustomobject]@{ status = 'LaunchUncertain'; reason = $_.Exception.Message } }
            Write-HarnessSchedules $Paths $state
        }
        $state.lastTick = $Now.ToString('o')
        Write-HarnessSchedules $Paths $state
        $heartbeat = Sync-HarnessHeartbeat $Paths $state $Now -DeferredJobIds @($deferred)
        [pscustomobject]@{ status = 'Ticked'; started = @($started); deferred = @($deferred); heartbeat = $heartbeat }
    }
    finally { $lock.Dispose() }
}

function Invoke-HarnessSchedulerCleanup {
    param($Paths, $State, [datetimeoffset]$Now = [datetimeoffset]::UtcNow, [switch]$Apply, [switch]$DeleteStale, [switch]$Automatic)
    $results = [Collections.Generic.List[object]]::new()
    $removedIds = [Collections.Generic.List[string]]::new()
    foreach ($job in @($State.jobs | Where-Object { $_.legacy -and -not $_.legacy.removedAt -and -not $_.active })) {
        if (-not $DeleteStale -or ([datetimeoffset]::Parse($job.legacy.disabledAt)).AddDays(30) -gt $Now) { continue }
        $task = @(Get-ScheduledTask -TaskPath $job.legacy.taskPath -ErrorAction Stop | Where-Object { $_.TaskName -ieq $job.legacy.taskName })
        if ($task.Count -eq 0) { continue }
        if ($task.Count -ne 1 -or [string]$task[0].State -ne 'Disabled' -or $task[0].Description -cne $job.legacy.description -or
            @($task[0].Actions).Count -ne 1 -or $task[0].Actions[0].Execute -ine $job.legacy.execute -or $task[0].Actions[0].Arguments -cne $job.legacy.arguments) { continue }
        $results.Add([pscustomobject]@{ id = $job.id; action = 'DeleteLegacyTask'; taskName = $job.legacy.taskName; reason = 'MigratedAndDisabledFor30Days' })
        if ($Apply) {
            Unregister-ScheduledTask -TaskName $job.legacy.taskName -TaskPath $job.legacy.taskPath -Confirm:$false -ErrorAction Stop
            $job.legacy | Add-Member -NotePropertyName removedAt -NotePropertyValue $Now.ToString('o') -Force
        }
    }
    foreach ($job in @($State.jobs)) {
        $health = Get-HarnessScheduleHealth $job
        if ($Apply -and $health.status -eq 'Valid') { $job.staleSince = '' }
        if ($health.status -ne 'Stale' -or $job.active) { continue }
        $delete = $DeleteStale -and $job.staleSince -and ([datetimeoffset]::Parse($job.staleSince)).AddDays(30) -le $Now
        $results.Add([pscustomobject]@{ id = $job.id; action = $(if ($delete) { 'Delete' } else { 'Disable' }); reason = $health.reason })
        if ($Apply) {
            $job.enabled = $false
            if (-not $job.staleSince) { $job.staleSince = $Now.ToString('o') }
            if ($delete) { $removedIds.Add($job.id) }
        }
    }
    if ($Apply -and $removedIds.Count) {
        foreach ($id in $removedIds) {
            $receipt = Join-Path $Paths.Receipts ($id + '.json')
            if (Test-Path -LiteralPath $receipt -PathType Leaf) { Remove-Item -LiteralPath $receipt -Force -ErrorAction Stop }
        }
        $State.jobs = @($State.jobs | Where-Object { $_.id -cnotin $removedIds })
    }
    $history = [Collections.Generic.List[object]]::new()
    $roots = if ($Automatic) { @(@($State.projects.projectRoot) + @($State.jobs | Where-Object { $_.kind -in @('project', 'pr') } | ForEach-Object projectRoot) | Where-Object { $_ } | Sort-Object -Unique) } else { @() }
    foreach ($project in $roots) {
        try {
            $projectPaths = Get-HarnessPaths $project
            $config = Read-HarnessConfig $projectPaths
            if ($Automatic -and $config.maintenance.enabled -eq $false) { continue }
            $history.Add((Invoke-HarnessHistoryCleanup $projectPaths -Apply:$Apply -Now $Now))
        }
        catch { $history.Add([pscustomobject]@{ project = $project; status = 'Skipped'; reason = $_.Exception.Message }) }
    }
    [pscustomobject]@{ preview = -not $Apply; schedules = @($results); history = @($history); status = $(if (@($history | Where-Object { $_.status -in @('Skipped', 'Partial') }).Count) { 'Partial' } else { 'Cleaned' }) }
}

function ConvertFrom-HarnessTaskArguments {
    param([string]$Arguments)
    $tokens = $null
    $errors = $null
    $syntax = [Management.Automation.Language.Parser]::ParseInput(('pwsh ' + $Arguments), [ref]$tokens, [ref]$errors)
    $statements = @($syntax.EndBlock.Statements)
    if ($errors.Count -or $statements.Count -ne 1 -or $statements[0] -isnot [Management.Automation.Language.PipelineAst] -or $statements[0].PipelineElements.Count -ne 1) { throw 'Legacy scheduler arguments are not a single literal command.' }
    $command = $statements[0].PipelineElements[0]
    if ($command -isnot [Management.Automation.Language.CommandAst] -or $command.Redirections.Count) { throw 'Legacy scheduler command contains unsupported expressions.' }
    $elements = @($command.CommandElements)
    $parameters = @{}
    for ($index = 1; $index -lt $elements.Count; $index++) {
        $element = $elements[$index]
        if ($element -isnot [Management.Automation.Language.CommandParameterAst] -or $element.Argument -or $parameters.ContainsKey($element.ParameterName)) { throw 'Legacy command contains positional, duplicate, or nonliteral arguments.' }
        $name = $element.ParameterName
        $value = $true
        if ($index + 1 -lt $elements.Count -and $elements[$index + 1] -isnot [Management.Automation.Language.CommandParameterAst]) {
            $index++
            if ($elements[$index] -isnot [Management.Automation.Language.StringConstantExpressionAst] -and $elements[$index] -isnot [Management.Automation.Language.ConstantExpressionAst]) { throw 'Legacy command contains an expandable argument.' }
            $value = $elements[$index].Value
        }
        $parameters[$name] = $value
    }
    $parameters
}

function Convert-HarnessLegacySchedule {
    param($Paths, $Definition, [switch]$Apply, [datetimeoffset]$Now = [datetimeoffset]::UtcNow)
    if (@((Read-HarnessSchedules $Paths).jobs | Where-Object { $_.key -ieq $Definition.key }).Count) { throw 'A logical replacement already exists; inspect it instead of migrating twice.' }
    $tasks = @(Get-ScheduledTask -TaskPath '\' -ErrorAction Stop | Where-Object { $_.TaskName -ieq $Definition.legacyTaskName })
    if ($tasks.Count -ne 1 -or @($tasks[0].Actions).Count -ne 1 -or @($tasks[0].Triggers).Count -ne 1) { throw 'Migration requires one exact legacy task with one action and one repetition trigger.' }
    $task = $tasks[0]
    if ([string]$task.State -eq 'Running') { throw 'The legacy task is running; migrate only after it finishes.' }
    if ($task.Triggers[0].EndBoundary -or $task.Triggers[0].Repetition.Duration -or $task.Triggers[0].RandomDelay -or $task.Triggers[0].Enabled -eq $false) { throw 'Expiring, delayed, or disabled triggers require explicit manual review before migration.' }
    if ($Definition.legacyDescription -and $task.Description -cne $Definition.legacyDescription) { throw 'Legacy task ownership does not match.' }
    if ($Definition.kind -eq 'refresh' -and $task.Description -notlike 'Refresh latest source-backed SkillVault installs every *') { throw 'The refresh task ownership is not recognized.' }
    $parameters = ConvertFrom-HarnessTaskArguments $task.Actions[0].Arguments
    if ($task.Actions[0].Execute -notmatch '(?i)(?:^|[\\/])(?:pwsh|powershell)(?:\.exe)?$' -or -not $parameters.File) { throw 'Legacy task is not a supported PowerShell file invocation.' }
    $expected = @{}
    for ($index = 0; $index -lt $Definition.arguments.Count; $index++) {
        $name = ([string]$Definition.arguments[$index]).TrimStart('-')
        $value = $true
        if ($index + 1 -lt $Definition.arguments.Count -and -not ([string]$Definition.arguments[$index + 1]).StartsWith('-')) { $index++; $value = $Definition.arguments[$index] }
        $expected[$name] = $value
    }
    foreach ($name in $parameters.Keys) {
        if ($name -eq 'ExecutionPolicy' -and $parameters[$name] -eq 'Bypass') { continue }
        if (-not $expected.ContainsKey($name)) { throw "Legacy argument $name has no approved replacement." }
        if ($name -eq 'File') {
            if ((Split-Path -Leaf $parameters[$name]) -ine (Split-Path -Leaf $expected[$name])) { throw 'Legacy runner is not the expected adapter.' }
        }
        elseif ([string]$parameters[$name] -ine [string]$expected[$name]) { throw "Legacy $name differs from the approved target." }
    }
    foreach ($name in @('ProjectPath', 'DataRoot', 'GlobalSkillsPath', 'CachePath', 'Scheduled', 'RunOnce', 'Action', 'Flow', 'TestEnvironment', 'MonitorName')) {
        if ($expected.ContainsKey($name) -and -not $parameters.ContainsKey($name)) { throw "Legacy command is missing $name." }
    }
    if (-not $task.Triggers[0].Repetition.Interval) { throw 'A saved positive repetition interval is required; custom triggers need manual review.' }
    $duration = [Xml.XmlConvert]::ToTimeSpan([string]$task.Triggers[0].Repetition.Interval)
    $interval = $duration.TotalDays.ToString('R', [Globalization.CultureInfo]::InvariantCulture) + 'd'
    $null = ConvertTo-HarnessDuration $interval
    $info = Get-ScheduledTaskInfo -TaskName $task.TaskName -TaskPath '\' -ErrorAction Stop
    $firstDue = if ($info.NextRunTime -and $info.NextRunTime.Year -gt 2000) { [datetimeoffset]$info.NextRunTime } else { $Now.Add($duration) }
    $enabled = [string]$task.State -ne 'Disabled'
    $legacy = [pscustomobject]@{ taskName = $task.TaskName; taskPath = '\'; description = $task.Description; execute = $task.Actions[0].Execute; arguments = $task.Actions[0].Arguments; disabledAt = $Now.ToString('o'); wasEnabled = $enabled }
    $Definition | Add-Member -NotePropertyName legacy -NotePropertyValue $legacy -Force
    if (-not $Apply) { return [pscustomobject]@{ preview = $true; operation = 'Migrate'; legacy = $legacy; definition = $Definition; interval = $interval; firstDue = $firstDue; enabled = $enabled } }
    Disable-ScheduledTask -TaskName $task.TaskName -TaskPath '\' -ErrorAction Stop | Out-Null
    $disabled = @(Get-ScheduledTask -TaskPath '\' -ErrorAction Stop | Where-Object { $_.TaskName -ieq $task.TaskName })
    if ($disabled.Count -ne 1 -or [string]$disabled[0].State -ne 'Disabled' -or $disabled[0].Description -cne $legacy.description -or @($disabled[0].Actions).Count -ne 1 -or $disabled[0].Actions[0].Execute -ine $legacy.execute -or $disabled[0].Actions[0].Arguments -cne $legacy.arguments) { throw 'Legacy disable could not be verified; no logical schedule was created.' }
    try { Set-HarnessSchedule $Paths $Definition $interval -Apply -Now $Now -FirstDue $firstDue -Enabled:$enabled }
    catch {
        $replacement = @((Read-HarnessSchedules $Paths).jobs | Where-Object { $_.key -ieq $Definition.key })
        if ($enabled -and -not @($replacement | Where-Object { $_.enabled -or $_.active }).Count) { Enable-ScheduledTask -TaskName $task.TaskName -TaskPath '\' -ErrorAction Stop | Out-Null }
        throw
    }
}