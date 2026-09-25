param(
    [ValidateNotNullOrEmpty()][string]$ProjectPath,
    [ValidateSet('Init', 'Status', 'Context', 'Root', 'Clean', 'Board', 'Task', 'UpdateTask', 'Ref', 'Dev', 'Review', 'Cycle', 'Recover', 'Test', 'TestConfig', 'Restrict', 'Fallback', 'Monitor', 'MonitorConfig', 'MonitorTask')][string]$Action = 'Status',
    [string]$Id,
    [string]$Title,
    [string]$Text,
    [string]$Scope,
    [string]$Acceptance,
    [string]$Source,
    [string]$SourceRevision,
    [Alias('RepoRef')][string]$RepositoryRef,
    [string]$FollowUpOf,
    [ValidateSet('feature', 'fix', 'verify')][string]$Kind = 'feature',
    [ValidateRange(1, 5)][int]$Priority = 3,
    [ValidateSet('Low', 'High', 'Unknown')][string]$Risk = 'Unknown',
    [switch]$AutoEligible,
    [string]$BoardPath,
    [switch]$Move,
    [string]$DestinationPath,
    [string]$Note,
    [string]$RemoveId,
    [ValidateSet('now', 'next')][string]$Mode,
    [switch]$UseWorkingChanges,
    [string]$BaseRef,
    [switch]$SecurityReview,
    [switch]$ConfirmStopped,
    [switch]$ConfirmLocation,
    [string]$Flow,
    [string]$MonitorName,
    [string]$TestEnvironment,
    [string]$DefinitionPath,
    [object]$RunnerContext,
    [string]$RunnerContextPath,
    [switch]$Scheduled,
    [ValidateSet('Show', 'Declare', 'Pause', 'Stop', 'Resume')][string]$PolicyAction = 'Show',
    [string]$Target,
    [string]$Actor,
    [string]$Reason,
    [switch]$Apply
)

. (Join-Path $PSScriptRoot 'harness-ownership.ps1')
$entryOwnership = $null
$guardsExecution = $Action -in @('Dev', 'Cycle', 'Review') -or ($Action -eq 'Test' -and $Flow) -or ($Action -eq 'Monitor' -and $MonitorName)
try {
if ($guardsExecution) {
    try { $entryOwnership = Enter-HarnessOwnership -Paths ([pscustomobject]@{ Project = $ProjectPath }) -Role dispatcher }
    catch {
        if ($_.Exception.Data['SkillOwnershipStatus']) { [pscustomobject]@{ status = $_.Exception.Data['SkillOwnershipStatus']; owner = $_.Exception.Data['SkillOwnershipOwner']; message = $_.Exception.Message } | ConvertTo-Json -Depth 8; return }
        throw
    }
}
. (Join-Path $PSScriptRoot 'harness-store.ps1')
. (Join-Path $PSScriptRoot 'harness-runner.ps1')
if (($Move -or $PSBoundParameters.ContainsKey('DestinationPath')) -and $Action -ne 'Root') { throw 'Move and DestinationPath apply only to Root.' }
if ($SecurityReview -and $Action -ne 'Review') { throw 'SecurityReview applies only to the independent Review action.' }
if ($ConfirmLocation -and $Action -ne 'Init') { throw 'ConfirmLocation applies only to Init.' }
if ($PSBoundParameters.ContainsKey('FollowUpOf') -and ($Action -notin @('Task', 'Dev') -or $Id)) { throw 'FollowUpOf creates a task through Task or Dev without Id; use UpdateTask -Id to revise a completed task.' }
if ($PSBoundParameters.ContainsKey('RepositoryRef') -and $Action -notin @('Task', 'UpdateTask', 'Dev', 'Review')) { throw 'RepositoryRef selects a coding target; use it with Task, UpdateTask, Dev, or Review.' }
if ($PSBoundParameters.ContainsKey('RepositoryRef') -and (($Action -eq 'Task' -and -not $Title -and -not $FollowUpOf) -or ($Action -eq 'Dev' -and -not $Id -and -not $Title -and -not $FollowUpOf))) { throw 'RepositoryRef requires a new task title or Dev -Id; use UpdateTask -Id to change a queued task.' }
$defaultRoot = -not $PSBoundParameters.ContainsKey('ProjectPath')
if ($defaultRoot) {
    if ($Action -ne 'Root') { throw 'Supply an explicit -ProjectPath from the selected session Root for this action without asking for location again. Only Root can select the current folder.' }
    $ProjectPath = (Get-Location).ProviderPath
}
$paths = Get-HarnessPaths $ProjectPath
if ($Action -eq 'Root') {
    if ($Scheduled -or $PSBoundParameters.ContainsKey('BoardPath')) { throw 'Root cannot run unattended or change board placement.' }
    if ($Move) {
        if ($defaultRoot -or [string]::IsNullOrWhiteSpace($DestinationPath)) { throw 'Root -Move requires the selected -ProjectPath and an existing -DestinationPath.' }
        . (Join-Path $PSScriptRoot 'harness-move.ps1')
        $RunnerContext = Read-HarnessRunnerContext -RunnerContext $RunnerContext -ContextPath $RunnerContextPath -ProjectRoot $paths.Project
        Move-HarnessRoot -Paths $paths -DestinationPath $DestinationPath -Apply:$Apply -RunnerContext $RunnerContext | ConvertTo-Json -Depth 10
        return
    }
    if ($Apply -or $PSBoundParameters.ContainsKey('DestinationPath')) { throw 'Ordinary Root is read-only. Use explicit -Move with -DestinationPath for relocation.' }
    $initialized = Test-Path -LiteralPath $paths.Config -PathType Leaf
    $config = if ($initialized) { Read-HarnessConfig $paths } else { $null }
    $board = if ($initialized) { Get-HarnessBoard $paths $config } else { $paths.Control }
    [ordered]@{ project = $paths.Project; control = $paths.Control; config = $paths.Config; state = $paths.State; board = $board; executionRoot = $(if ($initialized) { Get-HarnessExecutionRoot $config }); initialized = $initialized; selection = $(if ($defaultRoot) { 'CurrentDirectory' } else { 'Explicit' }) } | ConvertTo-Json
    return
}
$RunnerContext = Read-HarnessRunnerContext -RunnerContext $RunnerContext -ContextPath $RunnerContextPath -ProjectRoot $paths.Project
if ($Action -eq 'Monitor' -and -not $MonitorName) {
    if ($Scheduled -or $Id -or $Apply) { throw 'Choose a monitor name before supplying run options.' }
    Get-HarnessMonitorView $paths | ConvertTo-Json -Depth 15
    return
}
if ($Action -in @('Restrict', 'Fallback')) {
    $section = if ($Action -eq 'Restrict') { 'restrictions' } else { 'fallback' }
    if ($PolicyAction -eq 'Show') {
        if ($DefinitionPath -or $Target -or $Actor -or $Reason -or $Apply -or $ConfirmStopped) { throw 'Policy Show does not accept mutation options. Choose an explicit policy action.' }
            Get-HarnessPolicyView $paths $section -RunnerContext $RunnerContext | ConvertTo-Json -Depth 15
    }
    elseif ($PolicyAction -eq 'Declare') {
        if (-not $DefinitionPath -or $Target -or $ConfirmStopped) { throw 'Declare requires a definition file, not target or recovery options.' }
        Set-HarnessPolicy -Paths $paths -Section $section -DefinitionPath $DefinitionPath -Apply:$Apply -Actor $Actor -Reason $Reason | ConvertTo-Json -Depth 15
    }
    else {
        if ($Action -ne 'Fallback' -or $DefinitionPath) { throw 'Only Fallback supports target Pause, Stop, and Resume actions.' }
        $null = Read-HarnessConfig $paths
        Assert-HarnessPolicyTarget $Target
        if (-not $Apply) {
            [ordered]@{ preview = $true; action = $PolicyAction; target = $Target; actor = $Actor; reason = $Reason; currentPause = Get-HarnessPause $paths $Target; confirmStopped = [bool]$ConfirmStopped } | ConvertTo-Json -Depth 10
        }
        elseif ($PolicyAction -eq 'Resume') {
            Resume-HarnessTarget -Paths $paths -Target $Target -Actor $Actor -Reason $Reason -ConfirmStopped:$ConfirmStopped | ConvertTo-Json -Depth 10
        }
        else {
            Set-HarnessPause -Paths $paths -Target $Target -Actor $Actor -Reason $Reason -Stop:($PolicyAction -eq 'Stop') | ConvertTo-Json -Depth 10
        }
    }
    return
}
if ($Action -eq 'Init') {
    if ($Scheduled) { throw 'Init requires a session initialization request; scheduled initialization is not allowed.' }
    if (-not $ConfirmLocation) { throw "Supply -ConfirmLocation to acknowledge the resolved Root '$($paths.Project)'. Reuse the selected location without another user confirmation." }
    Initialize-Harness $paths | ConvertTo-Json -Depth 8
    return
}
if (-not (Test-Path -LiteralPath $paths.Config)) {
    if ($Action -in @('Status', 'Context', 'Board') -or ($Action -eq 'Test' -and -not $Flow)) {
        [ordered]@{ initialized = $false; project = $paths.Project; board = $paths.Control; next = '/harness init' } | ConvertTo-Json
        return
    }
}
$config = Read-HarnessConfig $paths
$state = Read-HarnessState $paths
$taskFields = @{}
foreach ($field in @('Title', 'Scope', 'Acceptance', 'Source', 'SourceRevision', 'Kind', 'Priority', 'Risk', 'AutoEligible', 'RepositoryRef')) {
    if ($PSBoundParameters.ContainsKey($field)) { $taskFields[$field] = $PSBoundParameters[$field] }
}
if ($PSBoundParameters.ContainsKey('Text')) { $taskFields.Description = $Text }

switch ($Action) {
    'Clean' {
        . (Join-Path $PSScriptRoot 'harness-maintenance.ps1')
        if ($DefinitionPath) {
            if ($Scheduled) { throw 'Scheduled cleanup cannot change its retention policy.' }
            Set-HarnessMaintenancePolicy -Paths $paths -DefinitionPath $DefinitionPath -Apply:$Apply | ConvertTo-Json -Depth 10
        }
        else { Invoke-HarnessHistoryCleanup -Paths $paths -Apply:$Apply | ConvertTo-Json -Depth 25 }
    }
    'MonitorConfig' {
        if (-not $DefinitionPath) { throw 'MonitorConfig requires an explicit declaration file.' }
        Set-HarnessMonitorSettings -Paths $paths -DefinitionPath $DefinitionPath -Apply:$Apply -Actor $Actor -Reason $Reason | ConvertTo-Json -Depth 15
    }
    'MonitorTask' {
        if (-not $Id -or $Scheduled -or $AutoEligible) { throw 'MonitorTask requires an exact incident Id and never permits scheduled or automatic task execution.' }
        Add-HarnessMonitorTask -Paths $paths -IncidentId $Id -Apply:$Apply -Actor $Actor -Reason $Reason | ConvertTo-Json -Depth 15
    }
    'Monitor' {
        $result = Invoke-HarnessMonitor -Paths $paths -Name $MonitorName -Scheduled:$Scheduled -RunnerContext $RunnerContext
        $result | ConvertTo-Json -Depth 15
        if ($result.status -in @('Failed', 'Blocked', 'NeedsRecovery')) { throw "Monitoring did not establish current health: $($result.status). Report: $($result.report)" }
    }
    'TestConfig' {
        if (-not $DefinitionPath) { throw 'TestConfig requires an explicit declaration file.' }
        Set-HarnessTestSettings -Paths $paths -DefinitionPath $DefinitionPath | ConvertTo-Json -Depth 15
    }
    'Test' {
        if (-not $Flow) {
            if ($TestEnvironment -or $Id -or $Scheduled) { throw 'Select a test flow before supplying run options.' }
            Get-HarnessTestSettings $config | ConvertTo-Json -Depth 15
            return
        }
        $result = Invoke-HarnessTests -Paths $paths -Flow $Flow -Environment $TestEnvironment -TaskId $Id -Scheduled:$Scheduled -RunnerContext $RunnerContext
        $result | ConvertTo-Json -Depth 15
        if ($result.status -in @('Failed', 'Blocked')) { throw "Test flow $Flow $($result.status). See the saved report: $($result.report)" }
    }
    'Status' {
        [ordered]@{ project = $paths.Project; board = Get-HarnessBoard $paths $config; active = $state.active; tasks = $state.tasks; nextQueue = $state.nextQueue; nowQueue = $state.nowQueue; resumeQueue = $state.resumeQueue; safety = Get-HarnessSafetyState $state } | ConvertTo-Json -Depth 10
    }
    'Context' {
        $task = $null
        if ($Id) { $task = Get-HarnessTask $state $Id }
        $repository = $null
        $executionRoot = Get-HarnessExecutionRoot $config
        $instructionRoots = @($paths.Project, $executionRoot, $task.repositoryRoot, $task.workspace | Where-Object { $_ })
        if ($task.repositoryRef) {
            $repository = $state.references | Where-Object { $_.id -ceq $task.repositoryRef } | Select-Object -First 1
            if (-not $task.repositoryRoot -and $repository.active -and [IO.Path]::IsPathFullyQualified([string]$repository.source) -and (Test-Path -LiteralPath $repository.source -PathType Container)) { $instructionRoots += [string]$repository.source }
        }
        [ordered]@{
            project = $paths.Project
            executionRoot = $executionRoot
            board = Get-HarnessBoard $paths $config
            task = $task
            repository = $repository
            effectiveRunner = (Resolve-HarnessRunnerConfig $config $RunnerContext).runner | Select-Object command, model, reasoningEffort, contextTier, workspaceMode, maxMinutes, maxCredits, maxTasksPerCycle, criticalReview, availableTools
            references = @($state.references | Where-Object { $_.active -and (-not $_.taskId -or ($Id -and $_.taskId -eq $Id)) })
            instructionCandidates = @(foreach ($root in @($instructionRoots | Select-Object -Unique)) { 'AGENTS.md', '.github/copilot-instructions.md' | ForEach-Object { Join-Path $root $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } })
            decisions = Join-Path (Get-HarnessBoard $paths $config) 'decisions.csv'
        } | ConvertTo-Json -Depth 10
    }
    'Board' {
        if ($PSBoundParameters.ContainsKey('BoardPath')) { $config = Set-HarnessBoard $paths $BoardPath }
        [ordered]@{ project = $paths.Project; board = Get-HarnessBoard $paths $config } | ConvertTo-Json
    }
    'Task' {
        if ($Title -or $FollowUpOf) {
            Add-HarnessTask -Paths $paths @taskFields -FollowUpOf $FollowUpOf | ConvertTo-Json -Depth 8
        }
        else { @($state.tasks) | ConvertTo-Json -Depth 8 }
    }
    'UpdateTask' {
        if (-not $Id) { throw 'UpdateTask requires an exact task ID.' }
        Update-HarnessTask -Paths $paths -Id $Id -Fields $taskFields | ConvertTo-Json -Depth 8
    }
    'Ref' {
        if ($Source -or $RemoveId) { Set-HarnessReference -Paths $paths -Source $Source -Note $Note -TaskId $Id -RemoveId $RemoveId | ConvertTo-Json -Depth 8 }
        else { @($state.references | Where-Object { $_.active }) | ConvertTo-Json -Depth 8 }
    }
    'Recover' {
        if (-not $ConfirmStopped) { throw 'Review interrupted work and confirm all prior workers are stopped before recovery.' }
        $runLock = Enter-HarnessLock $paths.RunLock
        try {
            Clear-HarnessOwnership -Paths $paths -ConfirmStopped
            Update-HarnessState $paths {
                param($saved)
                if ($saved.active) {
                    if ($saved.active.taskId -and $saved.active.phase -ne 'Test') {
                        $task = Get-HarnessTask $saved $saved.active.taskId
                        $task.status = 'Blocked'
                        $task.phase = 'Develop'
                    }
                    foreach ($run in @($saved.runs | Where-Object { $_.id -eq $saved.active.runId })) { $run.status = 'Interrupted'; $run.finishedAt = [datetimeoffset]::UtcNow.ToString('o') }
                    Register-HarnessPolicyOutcome $saved $config (Get-HarnessActiveTarget $saved) $saved.active.runId Interrupted 'Interrupted work inspected during explicit recovery.'
                    $saved.active = $null
                }
                [ordered]@{ status = 'Recovered'; next = 'Safety pauses remain. Inspect the cause, explicitly resume the affected target, and separately requeue any failed task when ready.' }
            } | ConvertTo-Json
        }
        finally { $runLock.Dispose() }
    }
    'Review' {
        $result = Invoke-HarnessReview -Paths $paths -Scope $(if ($Scope) { $Scope } else { 'Current changes' }) -BaseRef $BaseRef -SecurityReview:$SecurityReview -RepositoryRef $RepositoryRef -RunnerContext $RunnerContext
        $result | ConvertTo-Json -Depth 10
        if ($result.status -in @('Failed', 'NeedsRecovery', 'blocked')) { throw "Independent review $($result.status). Inspect its recorded outcome and report." }
    }
    { $_ -in @('Dev', 'Cycle') } {
        if ($Action -eq 'Dev') {
            [void]$taskFields.Remove('AutoEligible')
            if ($Id -and $taskFields.Count -and (Get-HarnessTask $state $Id).status -eq 'Completed') {
                $task = Update-HarnessTask -Paths $paths -Id $Id -Fields $taskFields
                $Id = $task.id
            }
            elseif ($Title -or $FollowUpOf) {
                $task = Add-HarnessTask -Paths $paths @taskFields -FollowUpOf $FollowUpOf
                $Id = $task.id
            }
        }
        if ($Id) {
            $queueMode = $(if ($Mode) { $Mode } elseif ($state.active) { 'next' } else { 'now' })
            $repositoryOptions = @{}
            if ($PSBoundParameters.ContainsKey('RepositoryRef')) { $repositoryOptions.RepositoryRef = $RepositoryRef }
            $queued = Queue-HarnessTask -Paths $paths -Id $Id -Mode $queueMode -UseWorkingChanges:$UseWorkingChanges @repositoryOptions
            if ($Mode -eq 'next' -or $queued.status -eq 'AlreadyRunning') { $queued | ConvertTo-Json; return }
        }
        $outcomes = @()
        $config = Resolve-HarnessRunnerConfig $config $RunnerContext
        $taskLimit = if ($null -ne $config.runner.maxTasksPerCycle) { $config.runner.maxTasksPerCycle } else { [Math]::Max(1, @((Read-HarnessState $paths).tasks).Count) }
        for ($taskNumber = 0; $taskNumber -lt $taskLimit; $taskNumber++) {
            $currentConfig = Resolve-HarnessRunnerConfig (Read-HarnessConfig $paths) $RunnerContext
            $currentLimit = if ($null -ne $currentConfig.runner.maxTasksPerCycle) { $currentConfig.runner.maxTasksPerCycle } else { $taskLimit }
            if ($taskNumber -ge $currentLimit) { break }
            $result = Invoke-HarnessCycle $paths -Scheduled:$Scheduled -RunnerContext $RunnerContext
            $outcomes += $result
            if ($result.status -notin @('Completed', 'Paused', 'Unsupported', 'Stale', 'AlreadyFixed')) { break }
            $saved = Read-HarnessState $paths
            if (@($saved.nowQueue).Count + @($saved.resumeQueue).Count + @($saved.nextQueue).Count -eq 0) { break }
        }
        $outcomes | ConvertTo-Json -Depth 10
        if (@($outcomes | Where-Object { $_.status -in @('Failed', 'NeedsRecovery') }).Count -gt 0) { throw 'Harness did not complete successfully; inspect the recorded outcome and report.' }
    }
}
}
finally {
    Exit-SkillOwnership $entryOwnership
}