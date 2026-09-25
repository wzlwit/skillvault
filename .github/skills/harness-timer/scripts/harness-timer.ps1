param(
    [string]$ProjectPath,
    [ValidateSet('List', 'Status', 'Set', 'Disable', 'Resume', 'Clean', 'Migrate')][string]$Action = 'List',
    [ValidateSet('project', 'pr', 'refresh', 'maintenance', 'heartbeat')][string]$Target = 'project',
    [string]$Interval,
    [Nullable[double]]$IntervalDay,
    [string]$Topic = 'e2e',
    [Alias('Flow')][string]$TestFlow,
    [Alias('Environment')][string]$TestEnvironment,
    [string]$MonitorName,
    [ValidateSet('Reuse', 'New')][string]$InstanceMode,
    [string]$InstanceName,
    [string]$RunnerContextPath,
    [string]$Id,
    [string]$DefinitionPath,
    [string]$SchedulerRoot = (Join-Path $HOME '.copilot/skillvault/scheduler'),
    [string]$DataRoot = (Join-Path $HOME '.copilot/pr-review'),
    [string]$GlobalSkillsPath = (Join-Path $HOME '.copilot/skills'),
    [string]$CachePath = (Join-Path $HOME '.copilot/skillvault-fresh-src'),
    [switch]$All,
    [switch]$Apply,
    [switch]$DeleteStale,
    [switch]$ConfirmStopped,
    [string]$RetireId,
    [string]$RunnerPath = (Join-Path $PSScriptRoot '../../harness/scripts/harness.ps1')
)

. (Join-Path $PSScriptRoot 'harness-scheduler.ps1')
$scheduler = Get-HarnessSchedulerPaths $SchedulerRoot
$state = Read-HarnessSchedules $scheduler
if ($Action -eq 'Status') { $Action = 'List' }
if ($Action -eq 'List') {
    $jobs = @($state.jobs | Where-Object { $All -or ($Target -eq 'project' -and $ProjectPath -and $_.projectRoot -ieq [IO.Path]::GetFullPath($ProjectPath)) -or ($Target -ne 'project' -and $_.kind -eq $Target) })
    [pscustomobject]@{ jobs = $jobs; heartbeatInterval = $state.heartbeatInterval; maintenance = $state.maintenance; actions = @('list', 'set', 'disable', 'resume', 'clean', 'migrate'); schedulerRoot = $scheduler.Root } | ConvertTo-Json -Depth 25
    return
}
if ($Target -eq 'heartbeat') {
    if ($Action -ne 'Set' -or $null -ne $IntervalDay) { throw 'Use Set with a unit-bearing Interval for the heartbeat baseline, or List to inspect it.' }
    Set-HarnessHeartbeatInterval $scheduler $Interval -Apply:$Apply | ConvertTo-Json -Depth 25
    return
}
if ($Target -eq 'maintenance') {
    if ($Action -notin @('Set', 'Disable', 'Resume')) { throw 'Use Set, Disable, or Resume for weekly maintenance.' }
    & (Join-Path $PSScriptRoot 'harness-heartbeat.ps1') -SchedulerRoot $SchedulerRoot -Action Maintenance -Enabled:($Action -ne 'Disable') -Apply:$Apply
    return
}
if ($Action -eq 'Clean') {
    if ($DefinitionPath) {
        if ($All -or -not $ProjectPath) { throw 'A retention policy requires one explicit project root.' }
        & (Join-Path $PSScriptRoot '../../harness/scripts/harness.ps1') -ProjectPath $ProjectPath -Action Clean -DefinitionPath $DefinitionPath -Apply:$Apply
        return
    }
    if (-not $All -and $Target -eq 'project' -and -not $ProjectPath) { throw 'Select a project or explicitly use All for cleanup.' }
    $selectJobs = { $All -or ($Target -ne 'project' -and $_.kind -eq $Target) -or ($Target -eq 'project' -and $_.kind -eq 'project' -and $_.projectRoot -ieq [IO.Path]::GetFullPath($ProjectPath)) }
    $selectedJobs = @($state.jobs | Where-Object $selectJobs)
    if ($RetireId) {
        $retired = @($selectedJobs | Where-Object id -CEQ $RetireId)
        if ($retired.Count -ne 1) { throw 'RetireId must identify one schedule in the selected scope.' }
        if (-not $Apply) { [pscustomobject]@{ preview = $true; retire = $retired[0]; operation = 'DisableAndRetire' } | ConvertTo-Json -Depth 20; return }
    }
    $lock = $null
    if ($Apply -and (Test-Path $scheduler.State)) { $lock = Enter-HarnessLock $scheduler.Lock }
    try {
        if ($lock) {
            $state = Read-HarnessSchedules $scheduler
            $selectedJobs = @($state.jobs | Where-Object $selectJobs)
        }
        if ($RetireId -and $Apply) { ($selectedJobs | Where-Object id -CEQ $RetireId).retiredAt = [datetimeoffset]::UtcNow.ToString('o') }
        $subset = [pscustomobject]@{ jobs = $selectedJobs }
        $result = Invoke-HarnessSchedulerCleanup $scheduler $subset -Apply:$Apply -DeleteStale:$DeleteStale
        if ($Apply -and (Test-Path $scheduler.State)) {
            $selectedIds = @($selectedJobs | ForEach-Object id)
            $state.jobs = @($state.jobs | Where-Object { $_.id -cnotin $selectedIds }) + @($subset.jobs)
            Write-HarnessSchedules $scheduler $state
            $null = Sync-HarnessHeartbeat $scheduler $state
        }
        $result | ConvertTo-Json -Depth 25
    }
    finally { if ($lock) { $lock.Dispose() } }
    return
}
if ($Id -and $Action -in @('Disable', 'Resume')) {
    $job = @($state.jobs | Where-Object id -CEQ $Id) | Select-Object -First 1
    if (-not $job -or (-not $All -and ($job.kind -ne $Target -or ($Target -eq 'project' -and (-not $ProjectPath -or $job.projectRoot -ine [IO.Path]::GetFullPath($ProjectPath)))))) { throw 'Select a schedule in the requested scope or explicitly use All.' }
    if ($Action -eq 'Resume' -and $job.kind -eq 'project') {
        $options = @{ ProjectPath = $job.projectRoot; Action = 'Set'; Prepare = $true; IntervalDay = 1; Topic = $job.topic }
        foreach ($name in @('testFlow', 'testEnvironment', 'monitorName', 'instanceName', 'runnerContextPath', 'runnerPath')) { if ($job.$name) { $options[$name] = $job.$name } }
        & (Join-Path $PSScriptRoot 'harness-project-timer.ps1') @options | Out-Null
    }
    elseif ($Action -eq 'Resume' -and $job.kind -eq 'pr') {
        $runnerIndex = [array]::IndexOf([string[]]$job.arguments, '-File')
        if ($runnerIndex -lt 0) { throw 'The saved PR adapter path is missing.' }
        $prRunner = $job.arguments[$runnerIndex + 1]
        $prScripts = Split-Path -Parent $prRunner
        . (Join-Path $prScripts 'pr-review-core.ps1')
        . (Join-Path $prScripts 'pr-review-runner.ps1')
        $null = Invoke-PrReviewTimer (Get-PrReviewPaths $job.directory) -Prepare -IntervalDays 1 -RunnerPath $prRunner
    }
    elseif ($Action -eq 'Resume') {
        $runnerIndex = [array]::IndexOf([string[]]$job.arguments, '-File')
        if ($runnerIndex -lt 0 -or -not (Test-Path -LiteralPath $job.arguments[$runnerIndex + 1] -PathType Leaf) -or (Get-HarnessScheduleHealth $job).status -ne 'Valid') { throw 'The saved refresh adapter or target is unavailable.' }
        if (-not (Get-Command Assert-SkillRuntimeCompatibility -ErrorAction SilentlyContinue)) { throw 'Update skillvault-installation and harness-timer before scheduling; compatibility interface v1 is required.' }
        Assert-SkillRuntimeCompatibility -SkillPath (Split-Path -Parent (Split-Path -Parent $job.arguments[$runnerIndex + 1])) -Interface structured-refresh -Version 1 -Consumer harness-timer
    }
    Set-HarnessScheduleEnabled $scheduler $Id ($Action -eq 'Resume') -Apply:$Apply -ConfirmStopped:$ConfirmStopped | ConvertTo-Json -Depth 25
    return
}
if ($Action -notin @('Set', 'Migrate')) { throw 'Select an exact logical schedule Id for Disable or Resume.' }
if ($Interval -and $null -ne $IntervalDay) { throw 'Choose Interval or the legacy IntervalDay, not both.' }
if ($null -ne $IntervalDay) { $Interval = $IntervalDay.ToString('R', [Globalization.CultureInfo]::InvariantCulture) + 'd' }
if ($Interval) { $null = ConvertTo-HarnessDuration $Interval }
if ($Target -eq 'project') {
    if (-not $ProjectPath) { throw 'Select the harness root before configuring a project schedule.' }
    $options = @{ ProjectPath = $ProjectPath; Action = 'Set'; Prepare = $true; IntervalDay = 1; RunnerPath = $RunnerPath }
    foreach ($name in @('Topic', 'TestFlow', 'TestEnvironment', 'MonitorName', 'InstanceMode', 'InstanceName', 'RunnerContextPath')) {
        if ($PSBoundParameters.ContainsKey($name)) { $options[$name] = $PSBoundParameters[$name] }
    }
    $definition = & (Join-Path $PSScriptRoot 'harness-project-timer.ps1') @options | ConvertFrom-Json
    $existing = @($state.jobs | Where-Object { $_.key -ieq $definition.key }) | Select-Object -First 1
    $reuseInputs = $false
    foreach ($name in @('RunnerContextPath', 'RunnerPath')) {
        if ($existing.$name -and -not $PSBoundParameters.ContainsKey($name)) { $options[$name] = $existing.$name; $reuseInputs = $true }
    }
    if ($reuseInputs) {
        $definition = & (Join-Path $PSScriptRoot 'harness-project-timer.ps1') @options | ConvertFrom-Json
    }
    $definition | Add-Member -NotePropertyName lockRoots -NotePropertyValue @(Get-HarnessScheduleRoots $definition)
}
elseif ($Target -eq 'pr') {
    $candidates = @((Join-Path $PSScriptRoot '../../pr-review/scripts'), (Join-Path $PSScriptRoot '../../../github/pr-review/scripts'))
    $scripts = $candidates | Where-Object { Test-Path (Join-Path $_ 'pr-review-core.ps1') } | Select-Object -First 1
    if (-not $scripts) { throw 'Install the pr-review companion before scheduling its watchlist.' }
    . (Join-Path $scripts 'pr-review-core.ps1')
    . (Join-Path $scripts 'pr-review-runner.ps1')
    $definition = Invoke-PrReviewTimer (Get-PrReviewPaths $DataRoot) -Prepare -IntervalDays 1 -RunnerPath (Join-Path $scripts 'pr-review.ps1')
}
else {
    $candidates = @((Join-Path $PSScriptRoot '../../skillvault-refresh/scripts/skillvault-fresh.ps1'), (Join-Path $PSScriptRoot '../../../core/skillvault-refresh/scripts/skillvault-fresh.ps1'))
    $runner = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $runner -or -not (Test-Path -LiteralPath $GlobalSkillsPath -PathType Container)) { throw 'The global refresh installation and target must exist.' }
    if (-not (Get-Command Assert-SkillRuntimeCompatibility -ErrorAction SilentlyContinue)) { throw 'Update skillvault-installation and harness-timer before scheduling; compatibility interface v1 is required.' }
    Assert-SkillRuntimeCompatibility -SkillPath (Split-Path -Parent (Split-Path -Parent $runner)) -Interface structured-refresh -Version 1 -Consumer harness-timer
    $definition = [pscustomobject]@{ key = 'refresh'; kind = 'refresh'; directory = [IO.Path]::GetFullPath($GlobalSkillsPath); executable = (Get-Command pwsh).Source; arguments = @('-NoProfile', '-NonInteractive', '-File', [IO.Path]::GetFullPath($runner), '-RunOnce', '-GlobalSkillsPath', [IO.Path]::GetFullPath($GlobalSkillsPath), '-CachePath', [IO.Path]::GetFullPath($CachePath)); legacyTaskName = 'SkillVault Source Refresh'; legacyDescription = '' }
}
$legacy = @(Get-ScheduledTask -TaskPath '\' -ErrorAction Stop | Where-Object { $_.TaskName -ieq $definition.legacyTaskName })
if ($legacy.Count -and $Action -eq 'Set') {
    $replacement = @($state.jobs | Where-Object { $_.key -ieq $definition.key }) | Select-Object -First 1
    if (-not $replacement.legacy -or $legacy.Count -ne 1 -or [string]$legacy[0].State -ne 'Disabled' -or $legacy[0].Description -cne $replacement.legacy.description -or $legacy[0].Actions[0].Arguments -cne $replacement.legacy.arguments) { throw 'A legacy OS schedule exists. Preview Migrate before creating its logical replacement.' }
}
if ($Action -eq 'Migrate') {
    Convert-HarnessLegacySchedule $scheduler $definition -Apply:$Apply | ConvertTo-Json -Depth 25
    return
}
$parameters = @{}
if ($InstanceMode) { $parameters.InstanceMode = $InstanceMode }
Set-HarnessSchedule $scheduler $definition $Interval @parameters -Apply:$Apply | ConvertTo-Json -Depth 25
