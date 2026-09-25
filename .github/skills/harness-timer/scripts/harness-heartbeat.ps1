param(
    [string]$SchedulerRoot = (Join-Path $HOME '.copilot/skillvault/scheduler'),
    [ValidateSet('List', 'Tick', 'Execute', 'Clean', 'Maintenance')][string]$Action = 'List',
    [string]$JobId,
    [string]$RunId,
    [switch]$Apply,
    [switch]$DeleteStale,
    [bool]$Enabled = $true
)

. (Join-Path $PSScriptRoot '../../harness/scripts/harness-ownership.ps1')
$runtimeOwnership = $null
$runtimeUncertain = $false
try {
if ($Action -ne 'List') {
    if (-not (Get-Command Enter-SkillRuntimeOwnership).Parameters.ContainsKey('InterfaceVersion')) { throw 'Incompatible runtime helper. Update skillvault-installation, harness, and harness-timer together before execution; compatibility interface v1 is required.' }
    $runtimeOwnership = Enter-SkillRuntimeOwnership -SkillPath (Split-Path -Parent $PSScriptRoot) -Owner ([pscustomobject]@{ scheduler = $SchedulerRoot; role = 'heartbeat'; job = $JobId; run = $RunId }) -InterfaceVersion 1
}
. (Join-Path $PSScriptRoot 'harness-scheduler.ps1')
$paths = Get-HarnessSchedulerPaths $SchedulerRoot
if ($Action -eq 'List') { Read-HarnessSchedules $paths | ConvertTo-Json -Depth 25; return }
if ($Action -eq 'Tick') { Invoke-HarnessSchedulerTick $paths | ConvertTo-Json -Depth 15; return }
if ($Action -eq 'Execute') {
    $state = Read-HarnessSchedules $paths
    $job = @($state.jobs | Where-Object { $_.id -ceq $JobId -and $_.active.runId -ceq $RunId })
    if ($job.Count -ne 1 -or -not $RunId) { throw 'No matching scheduler claim exists.' }
    $job = $job[0]
    $result = [pscustomobject]@{ runId = $RunId; startedAt = [datetimeoffset]::UtcNow.ToString('o'); finishedAt = ''; status = 'Failed'; runnerStatus = ''; exitCode = 1; output = ''; error = '' }
    $retryInput = $null
    $runnerOwnership = $null
    try {
        if ((Get-HarnessScheduleHealth $job).status -ne 'Valid') { throw 'Scheduled target is unavailable or retired.' }
        . (Join-Path $PSScriptRoot '../../harness/scripts/harness-runner.ps1')
        $arguments = @($job.arguments)
        if ($job.kind -ceq 'refresh') {
            $runnerIndex = [array]::IndexOf([string[]]$arguments, '-File')
            if ($runnerIndex -lt 0 -or $runnerIndex + 1 -ge $arguments.Count) { throw 'Refresh requires an exact script adapter.' }
            $runnerBundle = Split-Path -Parent (Split-Path -Parent $arguments[$runnerIndex + 1])
            $runnerOwnership = Enter-SkillRuntimeOwnership -SkillPath $runnerBundle -Owner @{ scheduler = $SchedulerRoot; role = 'refresh adapter'; run = $RunId } -InterfaceVersion 1 -RequiredInterface structured-refresh -RequiredVersion 1 -Consumer harness-timer
            $arguments += @('-ResultJson', '-OwnerProcessId', [string]$PID)
            if ($job.refreshRetry) {
                New-Item -ItemType Directory -Path $paths.Receipts -Force | Out-Null
                $retryInput = Join-Path $paths.Receipts ('refresh-retry-' + $RunId + '.json')
                Write-HarnessJson $retryInput ([pscustomobject]@{ schemaVersion = 1; globalSkillsRoot = $job.refreshRetry.globalSkillsRoot; targets = @($job.refreshRetry.targets); unresolved = @($job.refreshRetry.unresolved) })
                $arguments += @('-RetryPlanPath', $retryInput)
            }
        }
        $process = Invoke-HarnessProcess -Executable $job.executable -Arguments $arguments -Directory $job.directory -InheritPermissions
        $result.exitCode = $process.ExitCode
        $result.status = if ($process.ExitCode -eq 0) { 'Succeeded' } else { 'Failed' }
        $result.output = $process.Output; $result.error = $process.Error
        try {
            $payload = $process.Output | ConvertFrom-Json -NoEnumerate -ErrorAction Stop
            $result.runnerStatus = [string]$payload.status
            if ($process.ExitCode -eq 0 -and $payload.status -in @('Partial', 'Bounded', 'Busy', 'Idle', 'PolicyPaused', 'NeedsRecovery', 'Blocked')) { $result.status = $payload.status }
            if ($job.kind -ceq 'refresh' -and $process.ExitCode -eq 0) {
                if ($payload.schemaVersion -ne 1 -or $payload.kind -cne 'SkillVaultRefresh' -or $payload.status -cnotin @('Succeeded', 'Deferred', 'Failed', 'Blocked') -or $payload.retryTargets -isnot [array] -or $payload.unresolved -isnot [array]) { throw 'Invalid structured refresh result.' }
                $result.status = $payload.status
                $result | Add-Member -NotePropertyMembers @{ retryTargets = @($payload.retryTargets); globalSkillsRoot = $payload.globalSkillsRoot; unresolved = @($payload.unresolved) }
            }
        }
        catch {
            $result.runnerStatus = ''
            if ($job.kind -ceq 'refresh') { $result.status = 'Failed'; $result.exitCode = 1; $result.error = $_.Exception.Message }
        }
    }
    catch {
        $result.error = $_.Exception.Message
        if ($_.Exception.Data['SkillRuntimeStatus']) {
            $result.status = 'Blocked'
            $result | Add-Member -NotePropertyName requiredUpdates -NotePropertyValue $_.Exception.Data['SkillRuntimeRequiredUpdates']
        }
        $runtimeUncertain = (Get-HarnessFailureKind $_) -eq 'Interrupted'
    }
    finally {
        $result.finishedAt = [datetimeoffset]::UtcNow.ToString('o')
        $result | Add-Member -NotePropertyName requiresRecovery -NotePropertyValue $runtimeUncertain
        New-Item -ItemType Directory -Path $paths.Receipts -Force | Out-Null
        Write-HarnessJson (Join-Path $paths.Receipts ($JobId + '.json')) $result
        if ($retryInput -and (Test-Path -LiteralPath $retryInput)) { Remove-Item -LiteralPath $retryInput }
        Exit-SkillOwnership $runnerOwnership -Uncertain:$runtimeUncertain
        if ($job.kind -ceq 'refresh') { Complete-HarnessRefreshSchedule $paths $JobId $result }
    }
    if ($result.exitCode -ne 0) { throw 'Scheduled runner failed; inspect its recorded result.' }
    return
}
$state = Read-HarnessSchedules $paths
if (-not $Apply) {
    if ($Action -eq 'Clean') { Invoke-HarnessSchedulerCleanup $paths $state -DeleteStale:$DeleteStale | ConvertTo-Json -Depth 25 }
    else { [pscustomobject]@{ preview = $true; enabled = $Enabled; day = 'Saturday'; start = '08:30'; end = '09:00'; timeZoneId = $state.maintenance.timeZoneId; skipActive = $true; wakeMachine = $false } | ConvertTo-Json }
    return
}
New-Item -ItemType Directory -Path $paths.Root -Force | Out-Null
$lock = Enter-HarnessLock $paths.Lock
try {
    $state = Read-HarnessSchedules $paths
    if ($Action -eq 'Clean') { $result = Invoke-HarnessSchedulerCleanup $paths $state -Apply -DeleteStale:$DeleteStale }
    else { $state.maintenance.enabled = $Enabled; $result = $state.maintenance }
    Write-HarnessSchedules $paths $state
    $null = Sync-HarnessHeartbeat $paths $state
    $result | ConvertTo-Json -Depth 25
}
finally { $lock.Dispose() }
}
finally { Exit-SkillOwnership $runtimeOwnership -Uncertain:$runtimeUncertain }