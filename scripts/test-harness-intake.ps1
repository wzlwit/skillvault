$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\skills\planning\harness-runtime\scripts\harness-store.ps1')
. (Join-Path $PSScriptRoot '..\skills\planning\harness-runtime\scripts\harness-runner.ps1')
. (Join-Path $PSScriptRoot '..\skills\planning\harness-runtime\scripts\harness-monitor.ps1')

function Assert-IntakeFailure {
    param([scriptblock]$Operation, [string]$Expected)
    $failed = $false
    try { & $Operation | Out-Null }
    catch { $failed = $true; if ($_.Exception.Message -notlike "*$Expected*") { throw } }
    if (-not $failed) { throw "Expected failure: $Expected" }
}

$fixture = Join-Path ([IO.Path]::GetTempPath()) ('harness-intake-' + [guid]::NewGuid().ToString('N'))
$priorOwnership = $env:SKILLVAULT_OWNERSHIP_ROOT
$env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixture 'ownership'
try {
    New-Item -ItemType Directory -Path $fixture | Out-Null
    $paths = Get-HarnessPaths $fixture
    $config = Initialize-Harness $paths
    $config.runner.rulesPath = Join-Path $fixture 'rules.md'
    [IO.File]::WriteAllText($config.runner.rulesPath, 'Fixture only.')
    Write-HarnessConfig $paths $config
    $control = Join-Path $fixture 'control.json'
    $workLog = Join-Path $fixture 'work.log'
    # Fake producer and worker: the control file decides the feed items and each item's worker exit code.
    [IO.File]::WriteAllText((Join-Path $fixture 'produce.ps1'), @'
$control = Get-Content -Raw (Join-Path $PSScriptRoot 'control.json') | ConvertFrom-Json
$items = @(foreach ($item in $control.items) { [pscustomobject]@{ id = $item.id; source = "https://example.invalid/$($item.id)"; revision = 'one'; title = "Item $($item.id)"; text = 'Fixture item.'; disposition = 'Open'; priority = $item.priority } })
$feed = [pscustomobject]@{ schemaVersion = 1; complete = $true; observedAt = [datetimeoffset]::UtcNow.ToString('o'); items = $items }
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'feed.json'), ($feed | ConvertTo-Json -Depth 5))
exit [int]$control.producerExit
'@)
    [IO.File]::WriteAllText((Join-Path $fixture 'work.ps1'), @'
$control = Get-Content -Raw (Join-Path $PSScriptRoot 'control.json') | ConvertFrom-Json
Add-Content -Path (Join-Path $PSScriptRoot 'work.log') -Value "$env:HARNESS_ITEM_ID|$env:HARNESS_TASK_ID|$env:HARNESS_MONITOR|$env:HARNESS_SOURCE|$env:HARNESS_SOURCE_REVISION"
$code = @($control.items | Where-Object id -CEQ $env:HARNESS_ITEM_ID | ForEach-Object { $_.exit }) | Select-Object -First 1
exit [int]$code
'@)
    function Set-Control { param([object[]]$Items, [int]$ProducerExit = 0) Write-HarnessJson $control ([pscustomobject]@{ producerExit = $ProducerExit; items = @($Items) }) }
    function New-Item-Spec { param([string]$Id, [int]$Priority, [int]$Exit) [pscustomobject]@{ id = $Id; priority = $Priority; exit = $Exit } }
    function Get-Flow { param([string]$Name, [string]$Script, [string]$Effects)
        $flow = [ordered]@{ name = $Name; method = "Fixture $Name"; defaultEnvironment = 'local'; maxMinutes = 2; steps = @([pscustomobject]@{ name = $Name; executable = 'pwsh'; arguments = @('-NoProfile', '-NonInteractive', '-File', (Join-Path $fixture $Script)) }) }
        if ($Effects) { $flow.effects = $Effects }
        [pscustomobject]$flow
    }

    $testsFile = Join-Path $fixture 'tests.json'
    Write-HarnessJson $testsFile ([pscustomobject]@{ flows = @((Get-Flow bogus work.ps1 'remote')) ; environments = @([pscustomobject]@{ name = 'local'; workingDirectory = '.'; variables = [pscustomobject]@{}; requiredVariables = @(); allowScheduled = $true }) })
    Assert-IntakeFailure { Set-HarnessTestSettings $paths $testsFile } 'effects must be local'
    Write-HarnessJson $testsFile ([pscustomobject]@{
        environments = @([pscustomobject]@{ name = 'local'; workingDirectory = '.'; variables = [pscustomobject]@{}; requiredVariables = @(); allowScheduled = $true })
        flows = @((Get-Flow feed produce.ps1 'local'), (Get-Flow work work.ps1 'local'), (Get-Flow unsafe work.ps1 ''))
    })
    $null = Set-HarnessTestSettings $paths $testsFile

    function Get-Monitor { param([hashtable]$Intake, [hashtable]$Extra = @{})
        $intakeValue = [ordered]@{ mode = 'auto'; worker = [pscustomobject]@{ flow = 'work' }; maxPerCheck = 2; maxAttempts = 2; setupExitCodes = @(2); approvedBy = 'fixture-owner'; reason = 'Work every open fixture item.' }
        foreach ($key in $Intake.Keys) { if ($null -eq $Intake[$key]) { $intakeValue.Remove($key) } else { $intakeValue[$key] = $Intake[$key] } }
        $definition = [ordered]@{
            name = 'queue'; kind = 'discovery'; source = [pscustomobject]@{ type = 'json-feed'; path = 'feed.json'; producer = [pscustomobject]@{ flow = 'feed' } }
            environment = 'local'; maxMinutes = 2; maxAgeMinutes = 60; response = 'propose-task'; allowScheduled = $true
            verification = [pscustomobject]@{ enabled = $false }; intake = [pscustomobject]$intakeValue
        }
        foreach ($key in $Extra.Keys) { $definition[$key] = $Extra[$key] }
        [pscustomobject]@{ monitors = @([pscustomobject]$definition) }
    }
    $monitorFile = Join-Path $fixture 'monitors.json'
    foreach ($case in @(
        @{ intake = @{ approvedBy = $null }; expected = 'approvedBy' }
        @{ intake = @{ maxPerCheck = 0 }; expected = 'maxPerCheck' }
        @{ intake = @{ mode = 'manual' }; expected = 'mode must be auto' }
        @{ intake = @{ setupExitCodes = @(0) }; expected = 'setupExitCodes' }
        @{ intake = @{}; extra = @{ response = 'report-only' }; expected = 'report-only' }
    )) {
        $extra = if ($case.extra) { $case.extra } else { @{} }
        Assert-IntakeFailure { Assert-HarnessMonitorSettings (Get-Monitor $case.intake $extra) } $case.expected
    }
    Write-HarnessJson $monitorFile (Get-Monitor @{ worker = [pscustomobject]@{ flow = 'unsafe' } })
    Assert-IntakeFailure { Set-HarnessMonitorSettings -Paths $paths -DefinitionPath $monitorFile } 'must declare effects local'
    Write-HarnessJson $monitorFile (Get-Monitor @{})
    $null = Set-HarnessMonitorSettings -Paths $paths -DefinitionPath $monitorFile -Apply -Actor 'fixture-owner' -Reason 'Fixture standing intake'
    if (-not @((Read-HarnessState $paths).safety.events | Where-Object { $_.action -ceq 'StandingIntake' -and $_.target -ceq 'monitor:queue' }).Count) { throw 'Applying a standing intake did not record its approval.' }

    # First check: the producer refreshes the feed; all open items become worker tasks; two run in priority order.
    Set-Control @((New-Item-Spec A 1 0), (New-Item-Spec B 2 1), (New-Item-Spec C 3 0))
    $first = Invoke-HarnessMonitor $paths queue -Scheduled
    $state = Read-HarnessState $paths
    $tasks = @($state.tasks)
    if ($first.status -cne 'Succeeded' -or -not $first.complete -or @($first.intake.accepted).Count -ne 3 -or $tasks.Count -ne 3 -or
        @($tasks | Where-Object { $_.worker.monitor -cne 'queue' -or $_.risk -cne 'Unknown' -or $_.autoEligible }).Count) { throw 'Standing intake did not accept every open item as a worker task outside the development loop.' }
    if (@($first.work.ran).Count -ne 2 -or $first.work.ran[0].item -cne 'A' -or $first.work.ran[0].outcome -cne 'Completed' -or
        $first.work.ran[1].item -cne 'B' -or $first.work.ran[1].outcome -cne 'Failed' -or $first.work.ran[1].taskStatus -cne 'Queued' -or $first.work.status -cne 'Failed') { throw 'Work did not run the two highest-priority items with exit-code outcomes.' }
    $log = @(Get-Content $workLog)
    if ($log.Count -ne 2 -or $log[0] -cne 'A|T-001|queue|https://example.invalid/A|one') { throw 'The worker did not receive its item through HARNESS_* variables.' }
    if (@($state.runs | Where-Object phase -CEQ 'Work').Count -ne 2 -or $null -ne $state.active -or
        -not @($state.safety.events | Where-Object { $_.action -ceq 'MonitorTask' -and $_.actor -ceq 'harness' -and $_.reason -like '*fixture-owner*' }).Count) { throw 'Worker runs or standing acceptances were not recorded.' }
    if ((Get-HarnessTask $state T-001).status -cne 'Completed' -or -not (Test-Path (Get-HarnessTask $state T-001).lastReport)) { throw 'A successful worker run did not complete its task with a report.' }

    # Development never selects a worker task, whatever its risk.
    $copy = $state | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $copyTask = $copy.tasks | Where-Object id -CEQ T-003
    $copyTask.risk = 'Low'; $copyTask.autoEligible = $true
    if ($null -ne (Select-HarnessTask $copy)) { throw 'The development loop selected a monitor worker task.' }

    # Second check: the failing item reaches its attempt cap; the next item completes.
    $second = Invoke-HarnessMonitor $paths queue
    $state = Read-HarnessState $paths
    if (@($second.intake.accepted).Count -ne 0 -or (Get-HarnessTask $state T-002).status -cne 'Failed' -or (Get-HarnessTask $state T-002).worker.attempts -ne 2 -or
        (Get-HarnessTask $state T-003).status -cne 'Completed' -or $second.work.status -cne 'Failed') { throw 'Attempt limits or later items did not follow the declared intake.' }

    # An explicit run or queue request retries a failed worker task through its monitor, never development.
    $requeued = Queue-HarnessTask $paths T-002
    $state = Read-HarnessState $paths
    if ($requeued.status -cne 'QueuedForWorker' -or (Get-HarnessTask $state T-002).status -cne 'Queued' -or (Get-HarnessTask $state T-002).worker.attempts -ne 0 -or
        @($state.nowQueue) -contains 'T-002' -or @($state.nextQueue) -contains 'T-002') { throw 'A worker task retry entered the development queue or kept its spent attempts.' }
    Assert-IntakeFailure { Queue-HarnessTask $paths T-001 } 'only retries queued or failed'

    # A setup exit stops the check without spending an attempt; a Missing item waits.
    Set-Control @((New-Item-Spec D 1 2), (New-Item-Spec E 2 0))
    $third = Invoke-HarnessMonitor $paths queue
    $state = Read-HarnessState $paths
    $setupTask = Get-HarnessTask $state T-004
    if ($third.work.status -cne 'Blocked' -or @($third.work.ran).Count -ne 1 -or $third.work.ran[0].outcome -cne 'SetupProblem' -or
        $setupTask.status -cne 'Queued' -or $setupTask.worker.attempts -ne 0 -or (Get-HarnessTask $state T-005).status -cne 'Queued') { throw 'A setup problem counted an attempt or let later items run.' }
    Set-Control @((New-Item-Spec E 2 0))
    $fourth = Invoke-HarnessMonitor $paths queue
    $state = Read-HarnessState $paths
    if (@($fourth.work.ran).Count -ne 1 -or $fourth.work.ran[0].item -cne 'E' -or (Get-HarnessTask $state T-004).status -cne 'Queued') { throw 'A Missing item was worked, or its task changed.' }

    # A failed producer fails the check before anything is taken in.
    Set-Control @((New-Item-Spec F 1 0)) -ProducerExit 1
    $failed = Invoke-HarnessMonitor $paths queue
    if ($failed.status -cne 'Failed' -or $failed.result.reason -notlike '*Feed producer feed*' -or $failed.work.status -cne 'Skipped' -or @((Read-HarnessState $paths).tasks).Count -ne 5) { throw 'A failed feed producer still allowed intake or work.' }
    # A producer exit listed in setupExitCodes (such as a busy shared resource) blocks without counting a failure.
    $failuresBefore = [int](@((Read-HarnessState $paths).safety.targets | Where-Object target -CEQ 'monitor:queue') | Select-Object -First 1).consecutiveFailures
    Set-Control @((New-Item-Spec F 1 0)) -ProducerExit 2
    $busy = Invoke-HarnessMonitor $paths queue
    $failuresAfter = [int](@((Read-HarnessState $paths).safety.targets | Where-Object target -CEQ 'monitor:queue') | Select-Object -First 1).consecutiveFailures
    if ($busy.status -cne 'Blocked' -or $busy.result.reason -notlike '*next check retries*' -or $failuresAfter -ne $failuresBefore -or @((Read-HarnessState $paths).tasks).Count -ne 5) { throw "A busy feed producer counted as a collection failure or allowed intake: status=$($busy.status) failures=$failuresBefore->$failuresAfter" }

    # A paused worker target leaves accepted items queued.
    Set-Control @((New-Item-Spec F 1 0))
    $null = Set-HarnessPause -Paths $paths -Target 'test:work:local' -Actor 'fixture-owner' -Reason 'Fixture pause'
    $paused = Invoke-HarnessMonitor $paths queue
    if ($paused.work.status -cne 'Paused' -or @($paused.work.ran).Count -or (Get-HarnessTask (Read-HarnessState $paths) T-006).status -cne 'Queued') { throw 'Work ran while its worker target was paused.' }
    $null = Resume-HarnessTarget -Paths $paths -Target 'test:work:local' -Actor 'fixture-owner' -Reason 'Fixture resume' -ConfirmStopped

    # `check all` batches collect and propose only.
    $logCount = @(Get-Content $workLog).Count
    $batch = Invoke-HarnessMonitorBatch $paths
    if (@(Get-Content $workLog).Count -ne $logCount -or $batch.work) { throw 'A batch check ran standing work.' }

    # Explicit recovery of an interrupted worker counts the attempt and requeues until the cap.
    $interrupted = [pscustomobject]@{ status = 'Running'; worker = [pscustomobject]@{ attempts = 0; maxAttempts = 2 } }
    Set-HarnessInterruptedWorker $interrupted
    if ($interrupted.status -cne 'Queued' -or $interrupted.worker.attempts -ne 1) { throw 'An interrupted worker was not requeued.' }
    $interrupted.status = 'Running'
    Set-HarnessInterruptedWorker $interrupted
    if ($interrupted.status -cne 'Failed') { throw 'An interrupted worker passed its attempt cap.' }

    # The dispatcher reports failed work with a nonzero exit, so scheduled receipts show it.
    Set-Control @((New-Item-Spec F 1 1))
    $dispatcher = Join-Path $PSScriptRoot '..\skills\planning\harness-runtime\scripts\harness.ps1'
    $output = & pwsh -NoProfile -NonInteractive -File $dispatcher -ProjectPath $fixture -Action Monitor -MonitorName queue 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -or $output -notlike '*Monitor work did not finish*') { throw "Failed work did not fail the monitor command: $output" }

    # An interrupted worker keeps its task Running with the recovery marker; explicit recovery counts it once.
    Set-Control @((New-Item-Spec G 1 0), (New-Item-Spec H 2 0))
    $realFlow = ${function:Invoke-HarnessTestFlow}
    $interruptedCheck = & {
        function Invoke-HarnessTestFlow {
            param($Config, [string]$Flow, [string]$Environment, [string]$Workspace, [switch]$Scheduled, [double]$MaxMinutes = 0, $Paths, [string]$ParentTarget, [hashtable]$ExtraVariables)
            if ($Flow -ceq 'work') { return [pscustomobject]@{ status = 'Failed'; passed = $false; exitCode = 1; failureKind = 'Interrupted'; error = 'Fixture: process not confirmed stopped.'; flow = 'work'; environment = 'local' } }
            & $realFlow @PSBoundParameters
        }
        Invoke-HarnessMonitor $paths queue
    }
    $state = Read-HarnessState $paths
    $interruptedTask = @($state.tasks | Where-Object { $_.status -ceq 'Running' })
    if ($interruptedCheck.work.status -cne 'Blocked' -or @($interruptedCheck.work.ran).Count -ne 1 -or $interruptedCheck.work.ran[0].outcome -cne 'Interrupted' -or
        $interruptedTask.Count -ne 1 -or $interruptedTask[0].worker.attempts -ne 0 -or $state.active.phase -cne 'Work' -or -not $state.active.ownershipClaim) { throw "An interrupted worker lost its recovery marker, counted early, or let the next item run: status=$($interruptedCheck.status) reason=$($interruptedCheck.result.reason) work=$($interruptedCheck.work | ConvertTo-Json -Depth 4 -Compress) running=$($interruptedTask.Count) active=$($state.active | ConvertTo-Json -Compress)" }
    $null = & pwsh -NoProfile -NonInteractive -File $dispatcher -ProjectPath $fixture -Action Recover -ConfirmStopped 2>&1
    $state = Read-HarnessState $paths
    $recovered = Get-HarnessTask $state $interruptedTask[0].id
    if ($null -ne $state.active -or $recovered.status -cne 'Queued' -or $recovered.worker.attempts -ne 1) { throw 'Recovery did not requeue the interrupted worker with exactly one attempt.' }
    Set-HarnessInterruptedWorker $recovered
    if ($recovered.worker.attempts -ne 1) { throw 'A second recovery path counted the same interruption again.' }
    $null = Resume-HarnessTarget -Paths $paths -Target 'test:work:local' -Actor 'fixture-owner' -Reason 'Fixture resume after recovery' -ConfirmStopped

    # A restricted worker spends no attempts, stops the check, and leaves the remaining items queued.
    Write-HarnessJson $testsFile ([pscustomobject]@{ flows = @([pscustomobject]@{ name = 'work-node'; method = 'Fixture node worker'; defaultEnvironment = 'local'; maxMinutes = 1; effects = 'local'; steps = @([pscustomobject]@{ name = 'node'; executable = 'node'; arguments = @('-e', 'process.exit(0)') }) }) })
    $null = Set-HarnessTestSettings $paths $testsFile
    Write-HarnessJson $monitorFile (Get-Monitor @{ worker = [pscustomobject]@{ flow = 'work-node' } })
    $null = Set-HarnessMonitorSettings -Paths $paths -DefinitionPath $monitorFile -Apply -Actor 'fixture-owner' -Reason 'Fixture restricted worker'
    $restricted = Read-HarnessConfig $paths
    $restricted | Add-Member -NotePropertyName restrictions -NotePropertyValue ([pscustomobject]@{ allowedExecutables = @('pwsh') }) -Force
    Write-HarnessConfig $paths $restricted
    $queuedBefore = @((Read-HarnessState $paths).tasks | Where-Object { $_.status -ceq 'Queued' -and $_.worker }).Count
    $restrictedCheck = Invoke-HarnessMonitor $paths queue
    $state = Read-HarnessState $paths
    if ($restrictedCheck.work.status -cne 'Blocked' -or @($restrictedCheck.work.ran).Count -ne 1 -or $restrictedCheck.work.ran[0].outcome -cne 'NotRun' -or
        @($state.tasks | Where-Object { $_.worker -and $_.worker.attempts -gt 1 }).Count -or @($state.tasks | Where-Object { $_.status -ceq 'Queued' -and $_.worker }).Count -ne $queuedBefore -or
        -not @($state.safety.pauses | Where-Object { $_.target -ceq 'project' -and $_.active }).Count) { throw 'A restricted worker spent attempts, kept running items, or did not stop the project.' }
    $restricted.PSObject.Properties.Remove('restrictions')
    Write-HarnessConfig $paths $restricted
    $null = Resume-HarnessTarget -Paths $paths -Target 'project' -Actor 'fixture-owner' -Reason 'Fixture restriction removed' -ConfirmStopped

    # Removing the standing intake releases a queued worker task back to normal review instead of stranding it.
    $monitorWithout = Get-Monitor @{}
    $monitorWithout.monitors[0].PSObject.Properties.Remove('intake')
    Write-HarnessJson $monitorFile $monitorWithout
    $null = Set-HarnessMonitorSettings -Paths $paths -DefinitionPath $monitorFile -Apply -Actor 'fixture-owner' -Reason 'Fixture intake removed'
    $stranded = @((Read-HarnessState $paths).tasks | Where-Object { $_.status -ceq 'Queued' -and $_.worker }) | Select-Object -First 1
    $released = Queue-HarnessTask $paths $stranded.id
    if ($released.status -cne 'ReleasedFromWorker' -or (Get-HarnessTask (Read-HarnessState $paths) $stranded.id).worker) { throw 'A worker task stayed bound to a monitor without intake.' }
    Assert-IntakeFailure { Queue-HarnessTask $paths $stranded.id } 'low-risk scope'

    # `auto` previews, turns on, lists, and turns off a standing intake in one action.
    $autoPreview = Set-HarnessMonitorAuto -Paths $paths -Name queue -Flow work -MaxPerCheck 3
    if (-not $autoPreview.preview -or -not $autoPreview.auto -or $autoPreview.intake.maxPerCheck -ne 3 -or -not $autoPreview.allowScheduled -or
        (Get-HarnessMonitorDefinition (Read-HarnessConfig $paths) queue).intake) { throw 'An auto preview changed the declaration or misreported it.' }
    Assert-IntakeFailure { Set-HarnessMonitorAuto -Paths $paths -Name queue -Flow work -Apply } 'Actor and Reason'
    Assert-IntakeFailure { Set-HarnessMonitorAuto -Paths $paths -Name queue -Flow unsafe } 'must declare effects local'
    $removalsBefore = @((Read-HarnessState $paths).safety.events | Where-Object { $_.action -ceq 'StandingIntakeRemoved' }).Count
    $on = Set-HarnessMonitorAuto -Paths $paths -Name queue -Flow work -MaxPerCheck 3 -SetupExitCode 2 -Apply -Actor 'fixture-owner' -Reason 'Fixture auto on'
    $autoDefinition = Get-HarnessMonitorDefinition (Read-HarnessConfig $paths) queue
    if ($on.status -cne 'On' -or $autoDefinition.intake.approvedBy -cne 'fixture-owner' -or $autoDefinition.intake.maxPerCheck -ne 3 -or (@($autoDefinition.intake.setupExitCodes) -join ',') -cne '2' -or
        -not $autoDefinition.allowScheduled -or $autoDefinition.source.producer.flow -cne 'feed') { throw 'Turning auto on lost the approval, limits, schedule permission, or producer.' }
    $autoView = (Get-HarnessMonitorAutoView $paths).monitors | Where-Object name -CEQ queue
    if (-not $autoView.auto -or $autoView.worker.flow -cne 'work' -or $autoView.tasks.total -lt 1) { throw 'The auto list did not show the standing intake and its tasks.' }
    $off = Set-HarnessMonitorAuto -Paths $paths -Name queue -Off -Apply -Actor 'fixture-owner' -Reason 'Fixture auto off'
    if ($off.status -cne 'Off' -or (Get-HarnessMonitorDefinition (Read-HarnessConfig $paths) queue).intake -or
        @((Read-HarnessState $paths).safety.events | Where-Object { $_.action -ceq 'StandingIntakeRemoved' }).Count -ne $removalsBefore + 1) { throw 'Turning auto off left the intake or recorded no removal.' }
    if ((Set-HarnessMonitorAuto -Paths $paths -Name queue -Off).status -cne 'AlreadyOff') { throw 'A repeated auto off was not idempotent.' }

    # Health monitors: an Unhealthy incident becomes a task that the worker follows up; a healthy check takes nothing in.
    $health = [pscustomobject]@{ name = 'cpu'; resource = 'fixture-api'; environment = 'local'; metric = 'cpu-percent'; windowMinutes = 5; maxAgeMinutes = 60; maxMinutes = 1; response = 'propose-task'; condition = [pscustomobject]@{ operator = 'gt'; threshold = 90 }; source = [pscustomobject]@{ type = 'json-file'; path = 'cpu.json' } }
    Write-HarnessJson $monitorFile ([pscustomobject]@{ monitors = @($health) })
    $null = Set-HarnessMonitorSettings -Paths $paths -DefinitionPath $monitorFile -Apply -Actor 'fixture-owner' -Reason 'Fixture health monitor'
    $null = Set-HarnessMonitorAuto -Paths $paths -Name cpu -Flow work -Apply -Actor 'fixture-owner' -Reason 'Follow up every CPU breach'
    function Write-Cpu { param([double]$Value) $end = [datetimeoffset]::UtcNow; Write-HarnessJson (Join-Path $fixture 'cpu.json') ([pscustomobject]@{ resource = 'fixture-api'; environment = 'local'; metric = 'cpu-percent'; value = $Value; windowStart = $end.AddMinutes(-5).ToString('o'); windowEnd = $end.ToString('o'); observedAt = $end.ToString('o') }) }
    Set-Control @((New-Item-Spec 'I-001' 1 0))
    Write-Cpu 95
    $breach = Invoke-HarnessMonitor $paths cpu
    $incidentTasks = @((Read-HarnessState $paths).tasks | Where-Object { $_.worker.monitor -ceq 'cpu' })
    if ($breach.health -cne 'Unhealthy' -or @($breach.intake.accepted).Count -ne 1 -or $incidentTasks.Count -ne 1 -or $incidentTasks[0].status -cne 'Completed' -or
        $breach.work.ran[0].item -cne 'I-001' -or (Get-Content $workLog | Select-Object -Last 1) -notlike 'I-001|*|cpu|harness-monitor://*') { throw "A health breach was not followed up by its worker: $($breach | ConvertTo-Json -Depth 4 -Compress)" }
    Start-Sleep -Milliseconds 50
    Write-Cpu 10
    $recovered = Invoke-HarnessMonitor $paths cpu
    if ($recovered.health -cne 'Healthy' -or @($recovered.intake.accepted).Count -or @($recovered.work.ran).Count) { throw 'A healthy check took in or worked something.' }
    $listOutput = & pwsh -NoProfile -NonInteractive -File $dispatcher -ProjectPath $fixture -Action MonitorAuto 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or (($listOutput | ConvertFrom-Json).monitors | Where-Object name -CEQ cpu).auto -ne $true) { throw "The auto list command failed: $listOutput" }

    Write-Output 'Standing intake checks passed: declaration guards, local-only flows, feed producer, automatic acceptance, item variables, priority order, attempt limits, setup exits, Missing items, pauses, batch isolation, single-count recovery, interrupted runs, restrictions, intake removal, the auto action, health incidents, and development isolation.'
}
finally {
    $env:SKILLVAULT_OWNERSHIP_ROOT = $priorOwnership
    if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force }
}
