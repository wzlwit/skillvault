function Get-HarnessSafetyState {
    param($State)
    if ($null -ne $State.safety) { return $State.safety }
    [pscustomobject]@{ targets = @(); pauses = @(); events = @() }
}

function Get-HarnessFallbackPolicy {
    param($Config)
    $policy = [pscustomobject]@{
        failureThreshold = $null
        transientRetry = [pscustomobject]@{ maxRetries = 1; delaySeconds = 5; exitCodes = @() }
    }
    if ($null -ne $Config.fallback) {
        if ($null -ne $Config.fallback.failureThreshold) { $policy.failureThreshold = $Config.fallback.failureThreshold }
        foreach ($field in @('maxRetries', 'delaySeconds', 'exitCodes')) {
            if ($field -cin $Config.fallback.transientRetry.PSObject.Properties.Name) {
                $policy.transientRetry.$field = $Config.fallback.transientRetry.$field
            }
        }
    }
    $policy
}

function Assert-HarnessPolicyTarget {
    param([string]$Target)
    if ($Target -notmatch '^(project|development|review|monitor:[A-Za-z0-9][A-Za-z0-9_.-]*|test:[A-Za-z0-9][A-Za-z0-9_.-]*:[A-Za-z0-9][A-Za-z0-9_.-]*)$') {
        throw 'Target must be project, development, review, monitor:<name>, or test:<flow>:<environment>.'
    }
}

function Stop-HarnessPolicyViolation {
    param([string]$Message)
    $exception = [System.InvalidOperationException]::new($Message)
    $exception.Data['HarnessFailureKind'] = 'Restriction'
    throw $exception
}

function Get-HarnessFailureKind {
    param($Failure)
    $exception = if ($Failure -is [System.Management.Automation.ErrorRecord]) { $Failure.Exception } else { $Failure }
    while ($null -ne $exception) {
        if ($exception.Data.Contains('HarnessFailureKind')) { return [string]$exception.Data['HarnessFailureKind'] }
        $exception = $exception.InnerException
    }
    'Failure'
}

function Stop-HarnessBudget {
    param([string]$Message)
    $exception = [System.InvalidOperationException]::new($Message)
    $exception.Data['HarnessFailureKind'] = 'Budget'
    throw $exception
}

function Get-HarnessActiveTarget {
    param($State)
    if ($State.active.target) { return [string]$State.active.target }
    if ($State.active.phase -eq 'Test') {
        $run = @($State.runs | Where-Object { $_.id -eq $State.active.runId }) | Select-Object -First 1
        if ($run.flow -and $run.environment) { return 'test:{0}:{1}' -f $run.flow, $run.environment }
        return 'project'
    }
    if ($State.active.taskId) { return 'development' }
    if ($State.active.phase -in @('Review', 'Critical')) { return 'review' }
    'project'
}

function Test-HarnessUnspecifiedAllowance {
    param($Value)
    if ($Value -is [array]) {
        foreach ($item in $Value) { if (-not (Test-HarnessUnspecifiedAllowance $item)) { return $false } }
        return $true
    }
    $null -eq $Value -or
        ($Value -is [string] -and ([string]::IsNullOrWhiteSpace($Value) -or $Value.Trim() -in @('None', 'Max')))
}

function ConvertTo-HarnessRestrictions {
    param($Policy)
    if (Test-HarnessUnspecifiedAllowance $Policy) { return }
    $normalized = $Policy | ConvertTo-Json -Depth 30 | ConvertFrom-Json -NoEnumerate
    if ($null -eq $normalized -or $normalized.GetType() -ne [System.Management.Automation.PSCustomObject]) { throw 'A restriction declaration must be a JSON object or None.' }
    foreach ($field in @('allowedModels', 'allowedTools', 'availableTools', 'deniedTools', 'workspaceModes', 'workingRoots', 'testEnvironments', 'allowedExecutables', 'maxProcessMinutes', 'maxAgentCredits', 'maxTasksPerCycle')) {
        if ($field -cin $normalized.PSObject.Properties.Name -and (Test-HarnessUnspecifiedAllowance $normalized.$field)) { $normalized.$field = $null }
    }
    $normalized
}

function Get-HarnessExecutionLimit {
    param($Config, [string]$Name, $Requested)
    $effective = if (Test-HarnessUnspecifiedAllowance $Requested) { $null } else { [double]$Requested }
    foreach ($source in @($Config.restrictions) + @($Config.inheritedRestrictions.policy)) {
        $policy = ConvertTo-HarnessRestrictions $source
        if ($null -ne $policy -and $Name -cin $policy.PSObject.Properties.Name -and $null -ne $policy.$Name) {
            $effective = if ($null -eq $effective) { [double]$policy.$Name } else { [Math]::Min($effective, [double]$policy.$Name) }
        }
    }
    $effective
}

function Assert-HarnessRestrictions {
    param($Config, [string]$ProjectRoot, [string]$Workspace, [string]$Model,
        [string[]]$Tools, [string[]]$PermissionRules, [string]$WorkspaceMode,
        [string]$TestEnvironment, [string]$Executable)
    foreach ($inherited in $Config.inheritedRestrictions) {
        $parameters = @{} + $PSBoundParameters
        $parameters.Config = [pscustomobject]@{ restrictions = $inherited.policy }
        $parameters.ProjectRoot = $inherited.projectRoot
        Assert-HarnessRestrictions @parameters
    }
    try {
        $policy = ConvertTo-HarnessRestrictions $Config.restrictions
        if ($null -eq $policy) { return }
        Assert-HarnessPolicyDefinition restrictions $policy
    }
    catch { Stop-HarnessPolicyViolation "Invalid restriction policy: $($_.Exception.Message)" }
    $checks = @(
        @{ field = 'allowedModels'; values = @($Model); supplied = $PSBoundParameters.ContainsKey('Model') }
        @{ field = 'availableTools'; values = @($Tools); supplied = $PSBoundParameters.ContainsKey('Tools') }
        @{ field = 'allowedTools'; values = @($PermissionRules); supplied = $PSBoundParameters.ContainsKey('PermissionRules') }
        @{ field = 'workspaceModes'; values = @($WorkspaceMode); supplied = $PSBoundParameters.ContainsKey('WorkspaceMode') }
        @{ field = 'testEnvironments'; values = @($TestEnvironment); supplied = $PSBoundParameters.ContainsKey('TestEnvironment') }
    )
    foreach ($check in $checks) {
        if (-not $check.supplied -or $check.field -cnotin $policy.PSObject.Properties.Name -or $null -eq $policy.($check.field)) { continue }
        foreach ($value in $check.values) {
            if ($value -cnotin $policy.($check.field)) { Stop-HarnessPolicyViolation "$($check.field) does not permit '$value'." }
        }
    }
    if ($Workspace -and 'workingRoots' -cin $policy.PSObject.Properties.Name -and $null -ne $policy.workingRoots) {
        $directory = [System.IO.Path]::GetFullPath($Workspace)
        $permitted = $false
        foreach ($root in $policy.workingRoots) {
            $candidate = $root
            if (-not [System.IO.Path]::IsPathRooted($candidate)) {
                if (-not $ProjectRoot) { Stop-HarnessPolicyViolation 'Project root is required to resolve workingRoots.' }
                $candidate = Join-Path $ProjectRoot $candidate
            }
            $candidate = [System.IO.Path]::GetFullPath($candidate)
            $prefix = $candidate.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
            $comparison = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
            if ($directory.Equals($candidate, $comparison) -or $directory.StartsWith($prefix, $comparison)) { $permitted = $true; break }
        }
        if (-not $permitted) { Stop-HarnessPolicyViolation "Working directory is outside the approved workingRoots: $Workspace" }
    }
    if ($Executable -and 'allowedExecutables' -cin $policy.PSObject.Properties.Name -and $null -ne $policy.allowedExecutables) {
        $resolved = Get-Command $Executable -ErrorAction Stop
        $permitted = $false
        foreach ($allowed in $policy.allowedExecutables) {
            $candidate = Get-Command $allowed -ErrorAction SilentlyContinue
            if ($candidate -and $candidate.Source -and $candidate.Source -eq $resolved.Source) { $permitted = $true; break }
        }
        if (-not $permitted) { Stop-HarnessPolicyViolation "Executable is not approved: $Executable" }
    }
}

function Assert-HarnessPolicyDefinition {
    param([ValidateSet('restrictions', 'fallback')][string]$Section, $Policy)
    if ($Section -eq 'restrictions') {
        $Policy = ConvertTo-HarnessRestrictions $Policy
        if ($null -eq $Policy) { return }
    }
    if ($Policy -isnot [pscustomobject]) { throw 'A policy declaration must be a JSON object.' }
    $arrays = @('allowedModels', 'allowedTools', 'availableTools', 'deniedTools', 'workspaceModes', 'workingRoots', 'testEnvironments', 'allowedExecutables')
    $limits = @('maxProcessMinutes', 'maxAgentCredits', 'maxTasksPerCycle')
    $allowed = if ($Section -eq 'restrictions') { $arrays + $limits } else { @('failureThreshold', 'transientRetry') }
    foreach ($property in $Policy.PSObject.Properties) {
        if ($property.Name -cnotin $allowed) { throw "Unsupported $Section field: $($property.Name)" }
        if ($Section -eq 'restrictions' -and $null -eq $property.Value) { continue }
        if ($Section -eq 'restrictions' -and $property.Name -cin $arrays) {
            if ($property.Value -isnot [array] -or @($property.Value | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { throw "$($property.Name) must be an array of non-empty strings." }
            if ($property.Name -eq 'workspaceModes' -and @($property.Value | Where-Object { $_ -cnotin @('current', 'worktree') }).Count -gt 0) { throw 'workspaceModes permits current and worktree only.' }
        }
        elseif ($property.Name -cin ($limits + @('failureThreshold'))) {
            $value = $property.Value
            if ($property.Name -eq 'failureThreshold' -and $null -eq $value) { continue }
            if ($value -is [string] -or $value -is [bool] -or $null -eq $value -or [double]$value -le 0 -or [double]::IsNaN([double]$value) -or [double]::IsInfinity([double]$value)) { throw "$($property.Name) must be a positive finite number." }
            if ($property.Name -in @('maxTasksPerCycle', 'failureThreshold') -and [double]$value -ne [Math]::Floor([double]$value)) { throw "$($property.Name) must be a positive integer." }
        }
    }
    if ($Section -eq 'fallback' -and 'transientRetry' -cin $Policy.PSObject.Properties.Name) {
        $retry = $Policy.transientRetry
        if ($retry -isnot [pscustomobject] -or @($retry.PSObject.Properties.Name | Where-Object { $_ -cnotin @('maxRetries', 'delaySeconds', 'exitCodes') }).Count) { throw 'transientRetry permits only maxRetries, delaySeconds, and exitCodes.' }
        $retry = (Get-HarnessFallbackPolicy ([pscustomobject]@{ fallback = $Policy })).transientRetry
        if ($retry.maxRetries -is [string] -or $retry.maxRetries -is [bool] -or $null -eq $retry.maxRetries -or [double]$retry.maxRetries -lt 0 -or [double]$retry.maxRetries -gt 5 -or [double]$retry.maxRetries -ne [Math]::Floor([double]$retry.maxRetries)) { throw 'maxRetries must be an integer from 0 through 5.' }
        if ($retry.delaySeconds -is [string] -or $retry.delaySeconds -is [bool] -or $null -eq $retry.delaySeconds -or [double]$retry.delaySeconds -lt 0 -or [double]$retry.delaySeconds -gt 300 -or [double]::IsNaN([double]$retry.delaySeconds)) { throw 'delaySeconds must be a finite number from 0 through 300.' }
        if ($retry.exitCodes -isnot [array] -or @($retry.exitCodes | Where-Object { $_ -isnot [int] -and $_ -isnot [long] -or $_ -eq 0 -or $_ -eq 124 }).Count -gt 0) { throw 'Retry exitCodes must be integers excluding success and timeout (0 and 124).' }
        if ($retry.maxRetries -gt 0 -and $retry.exitCodes.Count -eq 0) { throw 'Retries require explicitly classified transient exit codes.' }
    }
}

function Add-HarnessPolicyEvent {
    param($Safety, [string]$Action, [string]$Target, [string]$Reason, [string]$Actor)
    $Safety.events = @($Safety.events) + @([pscustomobject]@{
        id = [guid]::NewGuid().ToString('N'); at = [datetimeoffset]::UtcNow.ToString('o')
        action = $Action; target = $Target; reason = $Reason; actor = $Actor
    })
}

function Get-HarnessPolicyView {
    param($Paths, [ValidateSet('restrictions', 'fallback')][string]$Section, $RunnerContext)
    if (-not (Test-Path -LiteralPath $Paths.Config -PathType Leaf)) {
        return [pscustomobject]@{ initialized = $false; section = $Section; declared = $false; policy = $null; pauses = @(); targets = @() }
    }
    $config = Read-HarnessConfig $Paths
    $executionConfig = if (Get-Command Resolve-HarnessRunnerConfig -ErrorAction SilentlyContinue) { Resolve-HarnessRunnerConfig $config $RunnerContext } else { $config }
    $safety = Get-HarnessSafetyState (Read-HarnessState $Paths)
    [pscustomobject]@{
        initialized = $true; section = $Section; declared = ($null -ne $config.$Section)
        policy = $(if ($Section -eq 'fallback') { Get-HarnessFallbackPolicy $config } else { $config.restrictions })
        pauses = @($safety.pauses | Where-Object { $_.active }); targets = @($safety.targets)
        recentEvents = @($safety.events | Select-Object -Last 10)
        maxConcurrentRuns = 1
        effectiveRunner = [pscustomobject]@{
            model = $executionConfig.runner.model; reasoningEffort = $executionConfig.runner.reasoningEffort; workspaceMode = $executionConfig.runner.workspaceMode
            contextTier = $executionConfig.runner.contextTier
            allowedTools = $executionConfig.runner.allowedTools; availableTools = $executionConfig.runner.availableTools
            deniedTools = @(@($executionConfig.restrictions.deniedTools) + @($executionConfig.inheritedRestrictions.policy.deniedTools) | Where-Object { $_ } | Select-Object -Unique)
            maxMinutes = Get-HarnessExecutionLimit $executionConfig maxProcessMinutes $executionConfig.runner.maxMinutes
            maxCredits = Get-HarnessExecutionLimit $executionConfig maxAgentCredits $executionConfig.runner.maxCredits
            maxTasksPerCycle = Get-HarnessExecutionLimit $executionConfig maxTasksPerCycle $executionConfig.runner.maxTasksPerCycle
        }
        testBudgets = @(foreach ($flow in $config.testing.flows) { [pscustomobject]@{ flow = $flow.name; maxMinutes = Get-HarnessExecutionLimit $config maxProcessMinutes $flow.maxMinutes } })
    }
}

function Set-HarnessPolicy {
    param($Paths, [ValidateSet('restrictions', 'fallback')][string]$Section, [string]$DefinitionPath, [switch]$Apply, [string]$Actor, [string]$Reason)
    if (-not [System.IO.Path]::IsPathRooted($DefinitionPath)) { $DefinitionPath = Join-Path $Paths.Project $DefinitionPath }
    $policy = [System.IO.File]::ReadAllText($DefinitionPath) | ConvertFrom-Json -NoEnumerate
    if ($Section -eq 'restrictions') { $policy = ConvertTo-HarnessRestrictions $policy }
    Assert-HarnessPolicyDefinition $Section $policy
    $config = Read-HarnessConfig $Paths
    if (-not $Apply) { return [pscustomobject]@{ preview = $true; section = $Section; current = $config.$Section; proposed = $policy } }
    if ([string]::IsNullOrWhiteSpace($Actor) -or [string]::IsNullOrWhiteSpace($Reason)) { throw 'Applying a policy requires a human Actor and Reason.' }
    $runLock = Enter-HarnessLock $Paths.RunLock
    try {
        $lock = Enter-HarnessLock $Paths.Lock
        try {
            $state = Read-HarnessState $Paths
            if ($state.active) { throw 'Recover interrupted work before changing policy.' }
            $config = Read-HarnessConfig $Paths
            $config | Add-Member -NotePropertyName $Section -NotePropertyValue $policy -Force
            $safety = Get-HarnessSafetyState $state
            Add-HarnessPolicyEvent $safety 'Declare' $Section $Reason $Actor
            $state | Add-Member -NotePropertyName safety -NotePropertyValue $safety -Force
            Write-HarnessJson $Paths.Config $config
            Write-HarnessJson $Paths.State $state
        }
        finally { $lock.Dispose() }
    }
    finally { $runLock.Dispose() }
    Get-HarnessPolicyView $Paths $Section
}

function Set-HarnessPauseState {
    param($Safety, [string]$Target, [string]$Reason, [string]$Actor, [bool]$StopRequested)
    $pause = @($Safety.pauses | Where-Object { $_.target -eq $Target })
    if ($pause.Count -eq 0) {
        $entry = [pscustomobject]@{ target = $Target; active = $true; stopRequested = $StopRequested; reason = $Reason; at = [datetimeoffset]::UtcNow.ToString('o'); actor = $Actor }
        $Safety.pauses = @($Safety.pauses) + @($entry)
    }
    else {
        $entry = $pause[0]
        if ($entry.active -and ($entry.stopRequested -or -not $StopRequested) -and $entry.reason -ceq $Reason) { return }
        $entry.stopRequested = $StopRequested -or ($entry.active -and $entry.stopRequested)
        $entry.active = $true; $entry.reason = $Reason; $entry.actor = $Actor; $entry.at = [datetimeoffset]::UtcNow.ToString('o')
    }
    Add-HarnessPolicyEvent $Safety $(if ($StopRequested) { 'Stop' } else { 'Pause' }) $Target $Reason $Actor
}

function Set-HarnessPause {
    param($Paths, [string]$Target, [string]$Reason, [string]$Actor, [switch]$Stop)
    Assert-HarnessPolicyTarget $Target
    if ([string]::IsNullOrWhiteSpace($Reason) -or [string]::IsNullOrWhiteSpace($Actor)) { throw 'Pausing requires Actor and Reason.' }
    Update-HarnessState -Paths $Paths -SkipViews -Operation {
        param($state)
        $safety = Get-HarnessSafetyState $state
        Set-HarnessPauseState $safety $Target $Reason $Actor ([bool]$Stop)
        $state | Add-Member -NotePropertyName safety -NotePropertyValue $safety -Force
        $safety.pauses | Where-Object { $_.target -eq $Target }
    }
}

function Get-HarnessPause {
    param($Paths, [string]$Target)
    $safety = Get-HarnessSafetyState (Read-HarnessState $Paths)
    $safety.pauses | Where-Object { $_.active -and $_.target -in @('project', $Target) } | Sort-Object @{ Expression = { $_.stopRequested }; Descending = $true } | Select-Object -First 1
}

function Assert-HarnessTargetRunning {
    param($Paths, [string[]]$Targets)
    if ($null -eq $Paths) { return }
    foreach ($target in $Targets) {
        $pause = Get-HarnessPause $Paths $target
        if ($null -ne $pause) {
            $exception = [System.InvalidOperationException]::new("Execution is paused for $($pause.target): $($pause.reason)")
            $exception.Data['HarnessFailureKind'] = if ($pause.stopRequested) { 'Stopped' } else { 'PolicyPaused' }
            throw $exception
        }
    }
}

function Save-HarnessPolicyOutcome {
    param($Paths, $Config, [string]$Target, [string]$RunId, [string]$Kind, [string]$Reason)
    if ($Kind -eq 'PolicyPaused') { return }
    $null = Update-HarnessState -Paths $Paths -SkipViews -Operation {
        param($state)
        Register-HarnessPolicyOutcome $state $Config $Target $RunId $Kind $Reason
    }
}

function Resume-HarnessTarget {
    param($Paths, [string]$Target, [string]$Actor, [string]$Reason, [switch]$ConfirmStopped)
    Assert-HarnessPolicyTarget $Target
    if (-not $ConfirmStopped -or [string]::IsNullOrWhiteSpace($Actor) -or [string]::IsNullOrWhiteSpace($Reason)) { throw 'Resume requires Actor, Reason, and confirmation that prior workers stopped.' }
    $runLock = Enter-HarnessLock $Paths.RunLock
    try {
        Update-HarnessState -Paths $Paths -SkipViews -Operation {
            param($state)
            if ($state.active) { throw 'Recover interrupted work before resuming a paused target.' }
            $safety = Get-HarnessSafetyState $state
            $pause = @($safety.pauses | Where-Object { $_.target -eq $Target -and $_.active })
            if ($pause.Count -ne 1) { throw "No active pause exists for $Target." }
            $pause[0].active = $false; $pause[0].stopRequested = $false
            foreach ($counter in @($safety.targets | Where-Object { $_.target -eq $Target })) { $counter.consecutiveFailures = 0 }
            Add-HarnessPolicyEvent $safety 'Resume' $Target $Reason $Actor
            $state | Add-Member -NotePropertyName safety -NotePropertyValue $safety -Force
            [pscustomobject]@{ status = 'Resumed'; target = $Target; message = 'No work started, no task requeued, and no schedule enabled.' }
        }
    }
    finally { $runLock.Dispose() }
}

function Register-HarnessPolicyOutcome {
    param($State, $Config, [string]$Target, [string]$RunId, [ValidateSet('Success', 'Failure', 'Blocked', 'Budget', 'Restriction', 'Interrupted', 'Stopped')][string]$Kind, [string]$Reason)
    $safety = Get-HarnessSafetyState $State
    $counter = @($safety.targets | Where-Object { $_.target -eq $Target }) | Select-Object -First 1
    if ($null -eq $counter) {
        $counter = [pscustomobject]@{ target = $Target; consecutiveFailures = 0; lastRunId = ''; lastOutcome = '' }
        $safety.targets = @($safety.targets) + @($counter)
    }
    if ($counter.lastRunId -ceq $RunId -and $counter.lastOutcome -ceq $Kind) { return }
    $counter.lastRunId = $RunId; $counter.lastOutcome = $Kind
    if ($Kind -eq 'Success') { $counter.consecutiveFailures = 0 }
    if ($Kind -eq 'Failure' -and $counter.lastFailureRunId -cne $RunId) {
        $counter.consecutiveFailures++
        $counter | Add-Member -NotePropertyName lastFailureRunId -NotePropertyValue $RunId -Force
    }
    $policy = Get-HarnessFallbackPolicy $Config
    if ($Kind -eq 'Restriction') { Set-HarnessPauseState $safety 'project' $Reason 'harness' $true }
    elseif ($Kind -in @('Budget', 'Interrupted', 'Stopped')) { Set-HarnessPauseState $safety $Target $Reason 'harness' $false }
    elseif ($Kind -eq 'Failure' -and $null -ne $policy.failureThreshold -and $counter.consecutiveFailures -ge $policy.failureThreshold) {
        Set-HarnessPauseState $safety $Target "Failure threshold reached ($($counter.consecutiveFailures)): $Reason" 'harness' $false
    }
    $State | Add-Member -NotePropertyName safety -NotePropertyValue $safety -Force
}