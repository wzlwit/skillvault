param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [ValidateSet('Status', 'Set', 'Disable', 'Resume')][string]$Action = 'Set',
    [double]$IntervalDay,
    [string]$Topic = 'e2e',
    [Alias('Flow')][string]$TestFlow,
    [Alias('Environment')][string]$TestEnvironment,
    [string]$MonitorName,
    [ValidateSet('Reuse', 'New')][string]$InstanceMode,
    [string]$InstanceName,
    [string]$RunnerContextPath,
    [switch]$Apply,
    [switch]$Prepare,
    [string]$RunnerPath = (Join-Path $PSScriptRoot '..\..\harness\scripts\harness.ps1')
)

. (Join-Path $PSScriptRoot '..\..\harness\scripts\harness-store.ps1')
. (Join-Path $PSScriptRoot '..\..\harness\scripts\harness-runner.ps1')
$paths = Get-HarnessPaths $ProjectPath
if ($Prepare -and ($Apply -or $Action -ne 'Set')) { throw 'Prepare only validates a Set definition without applying it.' }
if ($InstanceMode -and $Action -ne 'Set') { throw 'InstanceMode applies only to Set; select an existing instance by InstanceName for Status, Disable, or Resume.' }
if ($PSBoundParameters.ContainsKey('InstanceName')) { Assert-HarnessTestName $InstanceName }
if ($InstanceMode -eq 'New' -and -not $InstanceName) { throw 'New requires a distinct -InstanceName; use Reuse for the singleton schedule.' }
Assert-HarnessTestName $Topic
$Topic = $Topic.ToLowerInvariant()
if (-not $PSBoundParameters.ContainsKey('Topic') -and $TestFlow) { $Topic = 'test' }
if ($MonitorName) {
    Assert-HarnessTestName $MonitorName
    if ($TestFlow -or $TestEnvironment -or ($PSBoundParameters.ContainsKey('Topic') -and $Topic -ne 'monitor')) { throw 'MonitorName selects one declared monitor; do not combine it with another topic, flow, or environment override.' }
    $Topic = 'monitor'
}
if ($Topic -eq 'dev') { $Topic = 'e2e' }
if ($TestEnvironment -and -not $TestFlow) { throw 'TestEnvironment requires an explicit TestFlow.' }
if ($Topic -in @('e2e', 'review') -and $TestFlow) { throw "Topic $Topic does not accept a test flow. Select test, monitor, or a named command-flow topic." }
if ($Topic -notin @('e2e', 'review') -and -not $TestFlow -and -not $MonitorName) { throw "Topic $Topic requires an explicitly declared flow or -MonitorName. Do not substitute development." }
if (-not (Test-Path -LiteralPath $paths.Config) -and $Action -eq 'Status') {
    [ordered]@{ exists = $false; initialized = $false; project = $paths.Project } | ConvertTo-Json
    return
}
$config = Read-HarnessConfig $paths
if ($MonitorName) {
    $declaredMonitor = @((Get-HarnessMonitorSettings $config).monitors | Where-Object { $_.name -eq $MonitorName }) | Select-Object -First 1
    if ($declaredMonitor) { $MonitorName = [string]$declaredMonitor.name }
}
$policyTarget = if ($MonitorName) { 'monitor:' + $MonitorName } elseif ($TestFlow) { Get-HarnessTestTarget $config $TestFlow $TestEnvironment } elseif ($Topic -eq 'review') { 'review' } else { 'development' }
$taskName = 'SkillVault Harness ' + $config.projectId
$description = 'SkillVault harness project ' + $config.projectId
if ($MonitorName) {
    $taskName += " Monitor $MonitorName"
    $description += " monitor $MonitorName"
}
if ($Topic -eq 'review') {
    $taskName += ' Review'
    $description += ' review'
}
if ($TestFlow) {
    Assert-HarnessTestName $TestFlow
    $flow = @((Get-HarnessTestSettings $config).flows | Where-Object { $_.name -eq $TestFlow })
    if ($flow.Count -eq 1) { $TestFlow = [string]$flow[0].name }
    if (-not $TestEnvironment) {
        if ($flow.Count -ne 1) { throw 'Supply the test environment explicitly when the saved flow definition is unavailable.' }
        $TestEnvironment = [string]$flow[0].defaultEnvironment
    }
    Assert-HarnessTestName $TestEnvironment
    $environment = @((Get-HarnessTestSettings $config).environments | Where-Object { $_.name -eq $TestEnvironment })
    if ($environment.Count -eq 1) { $TestEnvironment = [string]$environment[0].name }
    if ($Topic -eq 'test') {
        $taskName += " Test $TestFlow $TestEnvironment"
        $description += " test $TestFlow $TestEnvironment"
    }
    else {
        $taskName += " Topic $Topic $TestFlow $TestEnvironment"
        $description += " topic $Topic $TestFlow $TestEnvironment"
    }
}
$baseTaskName = $taskName
$baseDescription = $description
$instancePattern = '^' + [regex]::Escape($baseTaskName) + ' Instance ([A-Za-z0-9][A-Za-z0-9_.-]*)$'
$tasks = if ($Prepare) { @() } else { @(Get-ScheduledTask -TaskPath '\' -ErrorAction Stop) }
$instances = @(foreach ($candidate in $tasks) {
    $candidateName = ''
    $candidateDescription = $baseDescription
    if ($candidate.TaskName -ine $baseTaskName) {
        if ($candidate.TaskName -notmatch $instancePattern) { continue }
        $candidateName = $Matches[1]
        $candidateDescription += " instance $candidateName"
    }
    [pscustomobject]@{ instanceName = $candidateName; taskName = $candidate.TaskName; taskPath = '\'; state = [string]$candidate.State; owned = ($candidate.Description -ieq $candidateDescription) }
})
if ($InstanceName) {
    $taskName += " Instance $InstanceName"
    $description += " instance $InstanceName"
}
$task = @($tasks | Where-Object { $_.TaskName -ieq $taskName })
if ($task.Count -gt 1 -or ($task.Count -eq 1 -and $task[0].Description -ine $description)) { throw 'The exact timer name is owned by a different task. Do not overwrite it.' }
if ($task.Count -eq 1) {
    $taskName = [string]$task[0].TaskName
    if ($taskName -match $instancePattern) { $InstanceName = $Matches[1] }
}
$runnerAction = if ($MonitorName) { 'Monitor' } elseif ($TestFlow) { 'Test' } elseif ($Topic -eq 'review') { 'Review' } else { 'Cycle' }
if ($Action -eq 'Status') {
    [ordered]@{ exists = ($task.Count -eq 1); taskName = $taskName; taskPath = '\'; state = $(if ($task.Count) { [string]$task[0].State } else { 'NotConfigured' }); project = $paths.Project; topic = $Topic; testFlow = $TestFlow; testEnvironment = $TestEnvironment; monitorName = $MonitorName; instanceName = $InstanceName; instances = $instances; safetyPause = Get-HarnessPause $paths $policyTarget } | ConvertTo-Json -Depth 5
    return
}
if (-not $Prepare -and $Action -eq 'Set' -and -not $InstanceMode -and ($instances.Count -gt 0 -or $InstanceName)) {
    if ($Apply) { throw 'Confirm Reuse (singleton) or New before changing matching schedules; supply -InstanceMode and the selected InstanceName when named.' }
    [ordered]@{ preview = $true; status = 'NeedsInstanceChoice'; requiresInstanceChoice = $true; choices = @('Reuse', 'New'); taskName = $taskName; taskPath = '\'; project = $paths.Project; topic = $Topic; runnerAction = $runnerAction; instanceName = $InstanceName; instances = $instances } | ConvertTo-Json -Depth 5
    return
}
if ($InstanceMode -eq 'New' -and $task.Count -gt 0) { throw 'The named schedule already exists. Choose Reuse for that exact instance or New with a different name.' }
if (-not $Prepare -and $InstanceMode -eq 'Reuse' -and $task.Count -eq 0 -and ($InstanceName -or $instances.Count -gt 0)) { throw 'The selected schedule does not exist to reuse. Select an existing InstanceName or choose New with a distinct name.' }
if ($Action -eq 'Set') {
    if (-not $PSBoundParameters.ContainsKey('IntervalDay')) {
        if ($task.Count -ne 1 -or @($task[0].Triggers).Count -ne 1 -or -not $task[0].Triggers[0].Repetition.Interval) { throw 'No single saved cadence is available for this target. Ask the user for a positive interval in days and supply -IntervalDay.' }
        $IntervalDay = [System.Xml.XmlConvert]::ToTimeSpan([string]$task[0].Triggers[0].Repetition.Interval).TotalDays
    }
    if ($IntervalDay -le 0 -or [double]::IsNaN($IntervalDay) -or [double]::IsInfinity($IntervalDay)) {
        throw 'Set requires a positive interval in days. Use /harness-dev or /harness-test run for immediate work; zero does not create a timer.'
    }
}
if ($Action -eq 'Set' -or $Action -eq 'Resume') {
    $savedContextPath = ''
    if ($task.Count -eq 1 -and @($task[0].Actions).Count -eq 1 -and $task[0].Actions[0].Arguments) {
        $tokens = $null
        $parseErrors = $null
        $syntax = [System.Management.Automation.Language.Parser]::ParseInput(('pwsh ' + $task[0].Actions[0].Arguments), [ref]$tokens, [ref]$parseErrors)
        $command = $syntax.Find({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $false)
        $elements = @($command.CommandElements)
        for ($index = 0; $index -lt $elements.Count - 1; $index++) {
            if ($elements[$index] -is [System.Management.Automation.Language.CommandParameterAst] -and $elements[$index].ParameterName -eq 'RunnerContextPath') {
                $savedContextPath = [string]$elements[$index + 1].Value
                break
            }
        }
    }
    if (-not $PSBoundParameters.ContainsKey('RunnerContextPath')) { $RunnerContextPath = $savedContextPath }
    if ($RunnerContextPath) {
        if (-not [IO.Path]::IsPathRooted($RunnerContextPath)) { $RunnerContextPath = Join-Path $paths.Project $RunnerContextPath }
        $RunnerContextPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RunnerContextPath)
    }
    if ($Action -eq 'Resume' -and $PSBoundParameters.ContainsKey('RunnerContextPath') -and $RunnerContextPath -ine $savedContextPath) { throw 'Use Set to change a timer context file; Resume retains its saved invocation.' }
    $runnerContext = Read-HarnessRunnerContext -ContextPath $RunnerContextPath -ProjectRoot $paths.Project
    $config = Resolve-HarnessRunnerConfig $config $runnerContext
    $executionRoot = Get-HarnessExecutionRoot $config
    Assert-HarnessTargetRunning $paths @($policyTarget)
    $null = Get-HarnessRuleContext $paths $config
    if ($MonitorName) {
        $monitorDefinition = Get-HarnessMonitorDefinition $config $MonitorName
        $null = Resolve-HarnessMonitorSource $paths $config $monitorDefinition -Scheduled
    }
    elseif ($TestFlow) {
        $testPlan = Resolve-HarnessTestPlan -Config $config -Flow $TestFlow -Environment $TestEnvironment -Workspace $executionRoot -Scheduled
    }
    elseif ($Topic -eq 'review') {
        Assert-HarnessRunnerConfig $config -ReviewOnly
        Assert-HarnessRestrictions -Config $config -ProjectRoot $paths.Project -Workspace $executionRoot -Model $config.runner.model -Tools @('view', 'glob', 'grep') -Executable $config.runner.command
    }
    else {
        Assert-HarnessRunnerConfig $config
        Assert-HarnessRestrictions -Config $config -Model $config.runner.model -WorkspaceMode $config.runner.workspaceMode -Tools @($config.runner.availableTools | Where-Object { $_ }) -PermissionRules @($config.runner.allowedTools | Where-Object { $_ }) -Executable $config.runner.command
        foreach ($hook in @((Get-HarnessTestSettings $config).afterDev)) {
            Assert-HarnessTargetRunning $paths @((Get-HarnessTestTarget $config $hook.flow $hook.environment))
            $null = Resolve-HarnessTestPlan -Config $config -Flow $hook.flow -Environment $hook.environment -Workspace $executionRoot -Scheduled
        }
    }
    if (-not (Test-Path -LiteralPath $RunnerPath -PathType Leaf)) { throw 'Installed harness runner is missing.' }
}
if ($Prepare) {
    $arguments = @('-NoProfile', '-NonInteractive', '-File', [IO.Path]::GetFullPath($RunnerPath), '-ProjectPath', $paths.Project, '-Action', $runnerAction, '-Scheduled')
    if ($MonitorName) { $arguments += @('-MonitorName', $MonitorName) }
    elseif ($TestFlow) { $arguments += @('-Flow', $TestFlow, '-TestEnvironment', $TestEnvironment) }
    if ($RunnerContextPath) { $arguments += @('-RunnerContextPath', $RunnerContextPath) }
    [pscustomobject]@{
        key = $taskName.ToLowerInvariant(); kind = 'project'; projectRoot = $paths.Project; projectId = $config.projectId
        directory = $paths.Project; executable = (Get-Command pwsh -ErrorAction Stop).Source; arguments = $arguments
        topic = $Topic; testFlow = $TestFlow; testEnvironment = $TestEnvironment; monitorName = $MonitorName
        instanceName = $InstanceName; runnerContextPath = $RunnerContextPath; runnerPath = [IO.Path]::GetFullPath($RunnerPath); legacyTaskName = $taskName; legacyDescription = $description
    } | ConvertTo-Json -Depth 10
    return
}
if ($Action -ne 'Set' -and $task.Count -eq 0) { throw 'No saved timer exists for this project.' }
$operation = if ($Action -eq 'Set') { if ($task.Count -eq 1) { 'Update' } else { 'Create' } } else { $Action }
if (-not $Apply) {
    [ordered]@{ preview = $true; action = $Action; operation = $operation; taskName = $taskName; taskPath = '\'; intervalDay = $IntervalDay; project = $paths.Project; topic = $Topic; runnerAction = $runnerAction; testFlow = $TestFlow; testEnvironment = $TestEnvironment; monitorName = $MonitorName; runnerContextPath = $RunnerContextPath; instanceMode = $InstanceMode; instanceName = $InstanceName; instances = $instances } | ConvertTo-Json -Depth 5
    return
}
switch ($Action) {
    'Set' {
        $powerShell = (Get-Command pwsh -ErrorAction Stop).Source
        $runnerFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RunnerPath)
        $arguments = "-NoProfile -NonInteractive -File `"$runnerFile`" -ProjectPath `"$($paths.Project)`""
        if ($MonitorName) { $arguments += " -Action Monitor -MonitorName `"$MonitorName`" -Scheduled" }
        elseif ($TestFlow) { $arguments += " -Action Test -Flow `"$TestFlow`" -TestEnvironment `"$TestEnvironment`" -Scheduled" }
        else { $arguments += " -Action $runnerAction -Scheduled" }
        if ($RunnerContextPath) { $arguments += " -RunnerContextPath `"$RunnerContextPath`"" }
        $scheduledAction = New-ScheduledTaskAction -Execute $powerShell -Argument $arguments
        $interval = [timespan]::FromDays($IntervalDay)
        $trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).Add($interval)) -RepetitionInterval $interval
        $minutes = if ($MonitorName) { Get-HarnessExecutionLimit $config maxProcessMinutes $monitorDefinition.maxMinutes } elseif ($TestFlow) { Get-HarnessExecutionLimit $config maxProcessMinutes $testPlan.maxMinutes } elseif ($null -eq $config.runner.maxMinutes) { $null } elseif ($Topic -eq 'review') { $config.runner.maxMinutes * 2 } elseif ($null -ne $config.runner.maxTasksPerCycle) { $config.runner.maxMinutes * 4 * $config.runner.maxTasksPerCycle } else { $null }
        $timeLimit = if ($null -eq $minutes) { [timespan]::Zero } else { [timespan]::FromMinutes($minutes + 2) }
        $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit $timeLimit
        Register-ScheduledTask -TaskName $taskName -TaskPath '\' -Action $scheduledAction -Trigger $trigger -Settings $settings -Description $description -Force | Out-Null
    }
    'Disable' { Disable-ScheduledTask -TaskName $taskName -TaskPath '\' | Out-Null }
    'Resume' { Enable-ScheduledTask -TaskName $taskName -TaskPath '\' | Out-Null }
}
[ordered]@{ action = $Action; operation = $operation; taskName = $taskName; taskPath = '\'; project = $paths.Project; intervalDay = $IntervalDay; topic = $Topic; runnerAction = $runnerAction; testFlow = $TestFlow; testEnvironment = $TestEnvironment; monitorName = $MonitorName; runnerContextPath = $RunnerContextPath; instanceMode = $InstanceMode; instanceName = $InstanceName } | ConvertTo-Json