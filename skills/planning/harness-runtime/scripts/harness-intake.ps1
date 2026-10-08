# Standing intake and flow workers for discovery monitors. A monitor whose declaration has `intake`
# accepts its new proposals into tasks at the end of a named check, then runs the declared local-only
# worker flow for up to `maxPerCheck` of its queued tasks. Callers hold the controller run lock.

function Get-HarnessIntakeLimit {
    param($Definition)
    if ($null -ne $Definition.intake.maxAttempts) { return [int]$Definition.intake.maxAttempts }
    2
}

function Set-HarnessTaskWorker {
    param($State, [string]$TaskId, $Definition)
    $task = Get-HarnessTask $State $TaskId
    if ($task.worker) { return }
    $task | Add-Member -NotePropertyName worker -NotePropertyValue ([pscustomobject]@{
        monitor = $Definition.name; attempts = 0; maxAttempts = Get-HarnessIntakeLimit $Definition
        lastExitCode = $null; lastRunAt = ''; lastReport = ''
    }) -Force
}

function Invoke-HarnessMonitorFlowRun {
    param($Paths, $Config, $Reference, [string]$Role, [string]$TaskId, [string]$ParentTarget, [hashtable]$Variables, [switch]$Scheduled)
    $workspace = Get-HarnessExecutionRoot $Config
    $plan = Resolve-HarnessTestPlan -Config $Config -Flow $Reference.flow -Environment ([string]$Reference.environment) -Workspace $workspace -Scheduled:$Scheduled
    $lease = Enter-HarnessOwnership -Paths $Paths -Role $Role -TaskId $TaskId -Workspace $plan.directory
    $result = $null
    try {
        $result = Invoke-HarnessTestFlow -Config $Config -Flow $plan.flow -Environment $plan.environment -Workspace $workspace -Scheduled:$Scheduled -Paths $Paths -ParentTarget $ParentTarget -ExtraVariables $Variables
        $result
    }
    # A process that could not be confirmed stopped keeps its checkout claim until explicit recovery.
    finally { Exit-SkillOwnership $lease -Uncertain:($null -eq $result -or $result.failureKind -ceq 'Interrupted') }
}

function Invoke-HarnessMonitorIntake {
    param($Paths, $Config, $Definition, $Result)
    $accepted = [Collections.Generic.List[string]]::new()
    $skipped = [Collections.Generic.List[object]]::new()
    $reason = "Standing intake for monitor $($Definition.name), approved by $($Definition.intake.approvedBy): $($Definition.intake.reason)"
    foreach ($proposal in @($Result.proposal | Where-Object { $_ } | Sort-Object priority, candidateId, incidentId)) {
        # Discovery proposals name a candidate; health proposals name an incident.
        $itemId = if ($proposal.candidateId) { [string]$proposal.candidateId } else { [string]$proposal.incidentId }
        # Follow-ups and blocked work stay for a human, exactly as they would without intake.
        if ($proposal.followUpOf) { $skipped.Add([pscustomobject]@{ item = $itemId; reason = 'A follow-up of completed work needs explicit acceptance.' }); continue }
        if ($proposal.blocked) { $skipped.Add([pscustomobject]@{ item = $itemId; reason = 'Blocked work needs a human to unblock it first.' }); continue }
        try {
            $recorded = Add-HarnessMonitorTaskRecord -Paths $Paths -IncidentId $itemId -Apply -Actor 'harness' -Reason $reason
            if ($recorded.status -ceq 'Recorded') { $accepted.Add([string]$recorded.task.id) }
        }
        catch { $skipped.Add([pscustomobject]@{ item = $itemId; reason = $_.Exception.Message }) }
    }
    [pscustomobject]@{ accepted = @($accepted); skipped = @($skipped) }
}

function Invoke-HarnessMonitorWork {
    param($Paths, $Config, $Definition, [string]$CollectionRunId, [switch]$Scheduled)
    $intake = $Definition.intake
    $setupCodes = @($intake.setupExitCodes | ForEach-Object { [int]$_ })
    $maxAttempts = Get-HarnessIntakeLimit $Definition
    $state = Read-HarnessState $Paths
    $monitoring = Get-HarnessMonitoringState $state
    # Work only items present in this check: current discovery candidates, or incidents still open in it.
    $current = if ($Definition.kind -ceq 'discovery') {
        @($monitoring.candidates | Where-Object {
            $_.monitor -ceq $Definition.name -and $_.taskId -and $_.lastRunId -ceq $CollectionRunId -and $_.evidenceStatus -ceq 'Current' -and
            $_.disposition -cnotin @('Missing', 'Resolved', 'Superseded')
        } | ForEach-Object { [pscustomobject]@{ id = $_.id; taskId = $_.taskId; itemId = [string]$_.sourceId; source = [string]$_.source; revision = [string]$_.revision } })
    }
    else {
        @($monitoring.incidents | Where-Object { $_.monitor -ceq $Definition.name -and $_.taskId -and $_.status -ceq 'Open' -and $_.lastRunId -ceq $CollectionRunId } |
            ForEach-Object { [pscustomobject]@{ id = $_.id; taskId = $_.taskId; itemId = [string]$_.id; source = "harness-monitor://$($Config.projectId)/$($_.id)"; revision = [string]$_.lastRunId } })
    }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $queue = @(foreach ($item in $current) {
        $task = @($state.tasks | Where-Object id -CEQ $item.taskId) | Select-Object -First 1
        if ($task -and $task.worker.monitor -ceq $Definition.name -and $task.status -ceq 'Queued' -and $seen.Add([string]$task.id)) { [pscustomobject]@{ task = $task; item = $item } }
    }) | Sort-Object { [int]$_.task.priority }, { [string]$_.task.createdAt }, { [string]$_.task.id }
    $work = [pscustomobject]@{ status = 'Idle'; ran = @(); pending = @($queue).Count; reason = '' }
    if (-not @($queue).Count) { return $work }
    $targetName = Get-HarnessTestTarget $Config $intake.worker.flow ([string]$intake.worker.environment)
    $pause = Get-HarnessPause $Paths $targetName
    if ($pause) { $work.status = 'Paused'; $work.reason = "The worker target $($pause.target) is paused: $($pause.reason)"; return $work }
    $work.status = 'Completed'
    $workspace = Get-HarnessExecutionRoot $Config
    foreach ($entry in @($queue | Select-Object -First ([int]$intake.maxPerCheck))) {
        $taskId = [string]$entry.task.id
        $runId = [guid]::NewGuid().ToString('N')
        $reportPath = Get-HarnessReportPath $Paths $Config $runId Work
        $run = [pscustomobject][ordered]@{
            id = $runId; taskId = $taskId; phase = 'Work'; status = 'Running'; startedAt = [datetimeoffset]::UtcNow.ToString('o'); finishedAt = ''
            model = ''; effort = ''; workspace = $workspace; report = $reportPath; exitCode = ''
            flow = [string]$intake.worker.flow; environment = [string]$intake.worker.environment; monitor = $Definition.name
        }
        $variables = @{
            HARNESS_TASK_ID = $taskId; HARNESS_ITEM_ID = [string]$entry.item.itemId; HARNESS_SOURCE = [string]$entry.item.source
            HARNESS_SOURCE_REVISION = [string]$entry.item.revision; HARNESS_MONITOR = $Definition.name
        }
        $lease = $null; $result = $null; $started = $false
        try {
            $plan = Resolve-HarnessTestPlan -Config $Config -Flow $intake.worker.flow -Environment ([string]$intake.worker.environment) -Workspace $workspace -Scheduled:$Scheduled
            $run.flow = $plan.flow; $run.environment = $plan.environment; $run.workspace = $plan.directory
            $lease = Enter-HarnessOwnership -Paths $Paths -Role work -TaskId $taskId -Workspace $plan.directory
        }
        catch {
            $kind = if ($_.Exception.Data['SkillOwnershipStatus']) { 'Blocked' } else { Get-HarnessFailureKind $_ }
            $result = [pscustomobject]@{ status = 'Blocked'; passed = $false; exitCode = $null; failureKind = $(if ($kind -eq 'Failure') { 'Blocked' } else { $kind }); error = $_.Exception.Message; flow = $run.flow; environment = $run.environment }
        }
        try {
            if (-not $result) {
                $null = Update-HarnessState $Paths -Config $Config -Operation {
                    param($saved)
                    $saved.runs = @($saved.runs) + @($run)
                    (Get-HarnessTask $saved $taskId).status = 'Running'
                    $saved.active = [pscustomobject]@{ taskId = $taskId; runId = $runId; phase = 'Work'; ownerProcessId = $PID; target = $targetName; ownershipClaim = $lease.id }
                }
                $started = $true
                try { $result = Invoke-HarnessTestFlow -Config $Config -Flow $run.flow -Environment $run.environment -Workspace $workspace -Scheduled:$Scheduled -Paths $Paths -ParentTarget "monitor:$($Definition.name)" -ExtraVariables $variables }
                catch { $result = [pscustomobject]@{ status = 'Failed'; passed = $false; exitCode = $null; failureKind = (Get-HarnessFailureKind $_); error = $_.Exception.Message; flow = $run.flow; environment = $run.environment } }
            }
            $kind = if ($result.passed) { 'Success' } else { [string]$result.failureKind }
            $setup = $kind -ceq 'Failure' -and $null -ne $result.exitCode -and [int]$result.exitCode -in $setupCodes
            # Only a real attempt counts: a nonzero exit or a timeout. Explicit recovery counts an interruption.
            $counts = $started -and -not $setup -and $kind -in @('Failure', 'Budget')
            $outcome = if ($result.passed) { 'Completed' } elseif ($setup) { 'SetupProblem' } elseif ($kind -ceq 'Interrupted') { 'Interrupted' } elseif ($counts) { 'Failed' } else { 'NotRun' }
            New-Item -ItemType Directory -Path (Split-Path -Parent $reportPath) -Force | Out-Null
            $report = "# Harness work report`n`nTask: $taskId`nMonitor: $($Definition.name)`nItem: $($entry.item.itemId)`nSource: $($entry.item.source)`nOutcome: $outcome`nScheduled: $([bool]$Scheduled)`n`n## Result`n`n" + ($result | ConvertTo-Json -Depth 15) + "`n"
            [IO.File]::WriteAllText($reportPath, $report, [Text.UTF8Encoding]::new($false))
            $saved = Update-HarnessState $Paths -Config $Config -Operation {
                param($saved)
                $task = Get-HarnessTask $saved $taskId
                if ($counts) { $task.worker.attempts = [int]$task.worker.attempts + 1 }
                $task.worker.maxAttempts = $maxAttempts
                $task.worker.lastExitCode = $result.exitCode; $task.worker.lastRunAt = [datetimeoffset]::UtcNow.ToString('o'); $task.worker.lastReport = $reportPath
                $task.lastReport = $reportPath
                # An interrupted run stays Running with its recovery marker until explicit recovery.
                if ($outcome -cne 'Interrupted') { $task.status = if ($result.passed) { 'Completed' } elseif ($counts -and [int]$task.worker.attempts -ge $maxAttempts) { 'Failed' } else { 'Queued' } }
                $savedRun = if ($started) { $saved.runs | Where-Object id -CEQ $runId } else { $run }
                $savedRun.status = $outcome; $savedRun.finishedAt = [datetimeoffset]::UtcNow.ToString('o')
                $savedRun.exitCode = if ($null -ne $result.exitCode) { [string]$result.exitCode } else { '' }
                if (-not $started) { $saved.runs = @($saved.runs) + @($run) }
                if ($started -and $outcome -cne 'Interrupted') { $saved.active = $null }
                $policyKind = if ($result.passed) { 'Success' } elseif ($setup) { 'Blocked' } else { $kind }
                if ($policyKind -notin @('PolicyPaused', '')) { Register-HarnessPolicyOutcome $saved $Config $targetName $runId $policyKind "Work on $taskId for monitor $($Definition.name): $outcome. Report: $reportPath" }
                [pscustomobject]@{ taskStatus = $task.status; attempts = [int]$task.worker.attempts }
            }
        }
        finally { if ($lease) { Exit-HarnessOwnership $lease $Paths } }
        $work.ran = @($work.ran) + @([pscustomobject]@{ taskId = $taskId; itemRef = $entry.item.id; item = $entry.item.itemId; outcome = $outcome; exitCode = $result.exitCode; taskStatus = $saved.taskStatus; attempts = $saved.attempts; report = $reportPath })
        if ($outcome -ceq 'Completed') { continue }
        if ($outcome -ceq 'Failed' -and $kind -ceq 'Failure') { $work.status = 'Failed'; continue }
        # Everything else stops this check: setup problems, and timeouts, interruptions, stops, pauses,
        # restrictions, or blocked starts, which leave the worker target or project paused or unusable.
        $work.status = if ($outcome -ceq 'Failed') { 'Failed' } else { 'Blocked' }
        $work.reason = switch ($outcome) {
            'SetupProblem' { "The worker reported a setup problem (exit $($result.exitCode)); remaining items wait for the next check." }
            'Interrupted' { 'The worker process could not be confirmed stopped; recover it explicitly before the next check.' }
            'Failed' { "The worker ran out of time; $targetName stays paused until it is resumed." }
            default { "The worker could not run ($($result.failureKind)): $($result.error)" }
        }
        break
    }
    $work.pending = @($queue).Count - @($work.ran | Where-Object outcome -CEQ 'Completed').Count
    $work
}

# `/harness-monitor auto`: every monitor's standing intake, worker, limits, last check, and its worker tasks.
function Get-HarnessMonitorAutoView {
    param($Paths)
    $config = Read-HarnessConfig $Paths
    $state = Read-HarnessState $Paths
    $monitoring = Get-HarnessMonitoringState $state
    [pscustomobject]@{ monitors = @(foreach ($definition in @((Get-HarnessMonitorSettings $config).monitors)) {
        $latest = @($monitoring.latest | Where-Object monitor -CEQ $definition.name) | Select-Object -First 1
        $tasks = @($state.tasks | Where-Object { $_.worker.monitor -ceq $definition.name })
        [pscustomobject][ordered]@{
            name = $definition.name; kind = $(if ($definition.kind) { $definition.kind } else { 'health' }); auto = [bool]$definition.intake
            worker = $definition.intake.worker; producer = $definition.source.producer
            maxPerCheck = $definition.intake.maxPerCheck; maxAttempts = $(if ($definition.intake) { Get-HarnessIntakeLimit $definition } else { $null })
            approvedBy = $definition.intake.approvedBy; reason = $definition.intake.reason; allowScheduled = [bool]$definition.allowScheduled
            lastCheck = $latest.result.status; lastCheckedAt = $latest.result.checkedAt
            tasks = [ordered]@{ total = $tasks.Count; queued = @($tasks | Where-Object status -CEQ 'Queued').Count; completed = @($tasks | Where-Object status -CEQ 'Completed').Count; failed = @($tasks | Where-Object status -CEQ 'Failed').Count; running = @($tasks | Where-Object status -CEQ 'Running').Count }
        }
    }) }
}

# Turn a monitor's standing intake on or update it (`-Flow`), or off (`-Off`). Previews unless -Apply;
# applying records the human approval through the normal declaration path. Scheduling stays with
# /harness-timer (`set project <duration>` for `monitor <name>`).
function Set-HarnessMonitorAuto {
    param($Paths, [string]$Name, [string]$Flow, [string]$Environment, [int]$MaxPerCheck, [int]$MaxAttempts, [int[]]$SetupExitCode, [switch]$Off, [switch]$Apply, [string]$Actor, [string]$Reason)
    $config = Read-HarnessConfig $Paths
    $definition = Get-HarnessMonitorDefinition $config $Name
    $updated = $definition | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    if ($Off) {
        if (-not $updated.intake) { return [pscustomobject]@{ status = 'AlreadyOff'; monitor = $Name; next = 'No standing intake to remove. Disable any monitor timer with /harness-timer disable <id>.' } }
        $updated.PSObject.Properties.Remove('intake')
    }
    else {
        $existing = $definition.intake
        $worker = if ($Flow) { [pscustomobject]@{ flow = $Flow } } elseif ($existing) { $existing.worker } else { throw 'Name the worker with -Flow: a declared /harness-work test flow with effects local.' }
        if ($Flow -and $Environment) { $worker | Add-Member -NotePropertyName environment -NotePropertyValue $Environment }
        $intake = [ordered]@{
            mode = 'auto'; worker = $worker
            maxPerCheck = $(if ($MaxPerCheck) { $MaxPerCheck } elseif ($existing) { [int]$existing.maxPerCheck } else { 2 })
            maxAttempts = $(if ($MaxAttempts) { $MaxAttempts } elseif ($existing.maxAttempts) { [int]$existing.maxAttempts } else { 2 })
            setupExitCodes = @($(if ($PSBoundParameters.ContainsKey('SetupExitCode')) { $SetupExitCode } elseif ($existing) { $existing.setupExitCodes } else { @() }) | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
            approvedBy = $(if ($Actor) { $Actor } else { '(the approving owner)' })
            reason = $(if ($Reason) { $Reason } else { '(the approval reason)' })
        }
        $updated | Add-Member -NotePropertyName intake -NotePropertyValue ([pscustomobject]$intake) -Force
        $updated | Add-Member -NotePropertyName allowScheduled -NotePropertyValue $true -Force
    }
    $incoming = [pscustomobject]@{ monitors = @($updated) }
    Assert-HarnessMonitorSettings $incoming -AllowUnscopedDiscovery
    if (-not $Off) { Assert-HarnessMonitorFlows $config $updated }
    if (-not $Apply) {
        $state = Read-HarnessState $Paths
        $monitoring = Get-HarnessMonitoringState $state
        $pending = if ($updated.kind -ceq 'discovery') { @($monitoring.candidates | Where-Object monitor -CEQ $Name | ForEach-Object { Get-HarnessDiscoveryProposal $config $_ $state } | Where-Object { $_ }) }
            else { @($monitoring.incidents | Where-Object monitor -CEQ $Name | ForEach-Object { Get-HarnessMonitorProposal $config $_ } | Where-Object { $_ }) }
        return [pscustomobject]@{
            preview = $true; monitor = $Name; auto = -not $Off; intake = $updated.intake; allowScheduled = $updated.allowScheduled
            proposalsNow = @($pending).Count
            next = $(if ($Off) { 'Apply with -Apply -Actor <owner> -Reason <why>, then disable the monitor timer with /harness-timer disable <id>.' } else { "Apply with -Apply -Actor <owner> -Reason <why>; the next complete check accepts what manual acceptance would and runs the worker. Then schedule it: /harness-timer set project <duration> for monitor $Name." })
        }
    }
    if ([string]::IsNullOrWhiteSpace($Actor) -or [string]::IsNullOrWhiteSpace($Reason)) { throw 'Turning a standing intake on or off requires a human Actor and Reason.' }
    $null = Set-HarnessMonitorSettings -Paths $Paths -Settings $incoming -Apply -Actor $Actor -Reason $Reason
    [pscustomobject]@{ status = $(if ($Off) { 'Off' } else { 'On' }); monitor = $Name; intake = $updated.intake; allowScheduled = $updated.allowScheduled }
}