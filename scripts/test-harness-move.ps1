param([switch]$LayoutOnly)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../skills/planning/harness/scripts/harness-move.ps1')
. (Join-Path $PSScriptRoot '../skills/planning/harness/scripts/harness-runner.ps1')
function Get-ScheduledTask { param($TaskPath); @() }
function Assert-MoveFailure {
    param([scriptblock]$Operation, [string]$Message)
    $failed = $false
    try { & $Operation | Out-Null }
    catch { if ($_.Exception.Message -notmatch $Message) { throw }; $failed = $true }
    if (-not $failed) { throw 'Expected relocation to be rejected.' }
}
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('harness-move-' + [guid]::NewGuid().ToString('N'))
$savedFixtureOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
$env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixture 'runtime-ownership'
try {
    if ($LayoutOnly) {
        . (Join-Path $PSScriptRoot '../skills/planning/harness/scripts/harness-migration.ps1')
        New-Item -ItemType Directory -Path $fixture -Force | Out-Null
        $paths = Get-HarnessPaths $fixture -LayoutVersion 1
        $config = Initialize-Harness $paths
        $task = Add-HarnessTask $paths -Title 'Preserved task' -Description 'Keep local records' -Scope 'fixture' -Acceptance 'Evidence intact'
        $state = Read-HarnessState $paths
        $report = Join-Path $paths.Control 'history/run-fixture.md'
        New-Item -ItemType Directory -Path (Split-Path -Parent $report) | Out-Null
        [IO.File]::WriteAllText($report, 'Immutable original run evidence')
        $state.runs = @([pscustomobject]@{ id = 'run-fixture'; phase = 'Monitor'; report = $report; startedAt = '2026-09-25T10:00:00Z'; status = 'Succeeded' })
        $state.tasks[0].lastReport = $report
        $state.nextQueue = @($task.id)
        Write-HarnessJson $paths.State $state
        [IO.File]::WriteAllText((Join-Path $paths.Control 'state.before-custom.json'), 'Preserve this unrelated snapshot')
        $before = [IO.File]::ReadAllText($paths.State)
        $preview = Invoke-HarnessMigration $paths
        if (-not $preview.preview -or (Test-Path (Join-Path $paths.Control 'config')) -or [IO.File]::ReadAllText($paths.State) -cne $before) { throw 'Migration preview changed storage.' }
        $state.active = [pscustomobject]@{ runId = 'busy' }
        Write-HarnessJson $paths.State $state
        Assert-MoveFailure { Invoke-HarnessMigration $paths -Apply } 'active work'
        $state.active = $null
        Write-HarnessJson $paths.State $state
        $writer = ${function:Write-HarnessViews}
        try {
            function Write-HarnessViews { throw 'Injected migration failure' }
            Assert-MoveFailure { Invoke-HarnessMigration $paths -Apply } 'Injected migration failure'
        }
        finally { Set-Item Function:Write-HarnessViews -Value $writer }
        if ((Read-HarnessConfig $paths).projectId -cne $config.projectId -or -not (Test-Path $report) -or (Test-Path (Join-Path $paths.Control 'migrate.pending.json'))) { throw 'Migration rollback did not restore the original controller.' }
        $result = Invoke-HarnessMigration $paths -Apply
        $currentPaths = Get-HarnessPaths $fixture
        $current = Read-HarnessState $currentPaths
        if ($result.status -cne 'Migrated' -or $currentPaths.LayoutVersion -ne 2 -or (Read-HarnessConfig $currentPaths).projectId -cne $config.projectId -or
            $current.tasks[0].id -cne $task.id -or $current.tasks[0].status -cne $task.status -or $current.nextQueue[0] -cne $task.id) { throw 'Migration changed task identity, status, or queue order.' }
        if ([IO.File]::ReadAllText($current.runs[0].report) -cne 'Immutable original run evidence' -or $current.tasks[0].lastReport -cne $current.runs[0].report -or
            (Test-Path $paths.State) -or (Test-Path $paths.Config) -or (Test-Path $report) -or -not (Test-Path (Join-Path $paths.Control 'state.before-custom.json'))) { throw 'Migration lost evidence, kept duplicate state, or deleted an unrelated snapshot.' }
        if ((Invoke-HarnessMigration $currentPaths -Apply).status -cne 'Current') { throw 'Repeated migration was not idempotent.' }
        $public = & (Join-Path $PSScriptRoot '../skills/planning/harness/scripts/harness.ps1') -ProjectPath $fixture -Action Migrate | ConvertFrom-Json
        if ($public.status -cne 'Current') { throw 'Public migration dispatch did not inspect the selected controller.' }
        $movedRoot = Join-Path $fixture 'moved-layout'
        New-Item -ItemType Directory -Path $movedRoot | Out-Null
        $relocated = Move-HarnessRoot $currentPaths $movedRoot -SchedulerRoot (Join-Path $fixture 'isolated-scheduler') -Apply
        $movedPaths = Get-HarnessPaths $movedRoot
        if ($relocated.status -cne 'Moved' -or $movedPaths.LayoutVersion -ne 2 -or (Read-HarnessState $movedPaths).tasks[0].id -cne $task.id -or
            (Read-HarnessConfig $movedPaths).projectId -cne $config.projectId) { throw 'Root relocation did not preserve the declarative layout.' }
        $externalRoot = Join-Path $fixture 'external-board-controller'
        $externalBoard = Join-Path $fixture 'explicit-board'
        $schedulerRoot = Join-Path $fixture 'declared-scheduler'
        New-Item -ItemType Directory -Path $externalRoot, $externalBoard, $schedulerRoot | Out-Null
        $legacyPaths = Get-HarnessPaths $externalRoot -LayoutVersion 1
        $legacyConfig = Initialize-Harness $legacyPaths
        $legacyConfig.boardPath = $externalBoard
        Write-HarnessConfig $legacyPaths $legacyConfig
        Write-HarnessViews $legacyPaths $legacyConfig (Read-HarnessState $legacyPaths)
        $job = [pscustomobject]@{ id = [guid]::NewGuid().ToString('N'); kind = 'project'; projectId = $legacyConfig.projectId; projectRoot = $externalRoot; directory = $externalRoot; enabled = $false; interval = '45m'; anchor = '2026-09-25T10:00:00Z'; nextDue = '2026-09-25T10:45:00Z'; timeZoneId = 'UTC'; active = $null; recoveryRequired = $false }
        Write-HarnessProjectSchedules $legacyPaths ([pscustomobject]@{ schemaVersion = 1; projectId = $legacyConfig.projectId; schedulerRoot = $schedulerRoot; jobs = @($job) })
        Write-HarnessJson (Join-Path $schedulerRoot 'schedules.json') ([pscustomobject]@{ schemaVersion = 1; projects = @([pscustomobject]@{ projectId = $legacyConfig.projectId; projectRoot = $externalRoot }) })
        $registryBefore = [IO.File]::ReadAllText((Join-Path $schedulerRoot 'schedules.json'))
        $null = Invoke-HarnessMigration $legacyPaths -Apply
        $migratedPaths = Get-HarnessPaths $externalRoot
        $migratedJob = (Read-HarnessProjectSchedules $migratedPaths).jobs[0]
        if ((Get-HarnessBoard $migratedPaths (Read-HarnessConfig $migratedPaths)) -ine $externalBoard -or $migratedJob.id -cne $job.id -or $migratedJob.enabled -or
            $migratedJob.interval -cne '45m' -or [datetimeoffset]$migratedJob.nextDue -ne [datetimeoffset]$job.nextDue -or
            [IO.File]::ReadAllText((Join-Path $schedulerRoot 'schedules.json')) -cne $registryBefore) { throw 'Migration changed external board placement, schedule cadence, or the heartbeat registration.' }
        Write-Output 'Layout migration checks passed: no-write preview, active-work refusal, rollback, preserved identities/queues/evidence, readable report links, and idempotent dispatch.'
        return
    }
    $oldRoot = Join-Path $fixture 'old project'
    $newRoot = Join-Path $fixture 'new controller'
    New-Item -ItemType Directory -Path $oldRoot, $newRoot -Force | Out-Null
    $paths = Get-HarnessPaths $oldRoot -LayoutVersion 1
    $destination = Get-HarnessPaths $newRoot -LayoutVersion 1
    $config = Initialize-Harness $paths
    $planFile = Join-Path $paths.Control 'docs/plan.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $planFile) -Force | Out-Null
    [IO.File]::WriteAllText($planFile, 'Original decision evidence')
    $config | Add-Member -NotePropertyName restrictions -NotePropertyValue ([pscustomobject]@{ workingRoots = @('.', '.harness_sv/worktrees') })
    $config.runner.rulesPath = '.harness_sv/definitions/rules.md'
    $config.testing.environments = @([pscustomobject]@{ workingDirectory = 'tests' })
    $task = Add-HarnessTask $paths -Title 'Move fixture' -Description 'Preserve records' -Scope 'source.txt' -Acceptance 'No retargeting'
    $state = Read-HarnessState $paths
    $state.tasks[0].workspace = Join-Path $paths.Control 'worktrees/T-001'
    $state.tasks[0].repositoryRoot = $oldRoot
    $state.tasks[0].lastReport = Join-Path $paths.Control 'history/run.md'
    $state.tasks[0].snapshot = 'Original snapshot evidence'
    $state.tasks[0].source = 'requirement-42'
    $state.references = @(
        [pscustomobject]@{ id = 'R-001'; source = $oldRoot; active = $true }
        [pscustomobject]@{ id = 'R-002'; source = '.harness_sv/docs/plan.md#choice'; active = $true }
    )
    $discoveryTask = $task | Select-Object *
    $discoveryTask.id = 'T-050'
    $discoveryTask.source = ([uri]$planFile).AbsoluteUri
    $discoveryTask.scope = "Source discovery: $($discoveryTask.source)"
    $discoveryTask.status = 'Blocked'
    $state.tasks += $discoveryTask
    $state | Add-Member -NotePropertyName monitoring -NotePropertyValue ([pscustomobject]@{
        latest = @(); incidents = @(); candidates = @([pscustomobject]@{
            id = 'C-001'; sourceId = 'plan.md'; source = $discoveryTask.source; taskId = $discoveryTask.id; disposition = 'Deferred'
            firstReport = Join-Path $paths.Control 'history/discovery-first.md'; latestReport = Join-Path $paths.Control 'history/discovery-last.md'
            sameRequirementAs = @($discoveryTask.source + '#related')
            verificationCheckpoint = [pscustomobject]@{ report = Join-Path $paths.Control 'history/checkpoint.md'; evidence = @([pscustomobject]@{ path = $planFile; hash = 'unchanged'; quote = 'Original decision evidence' }) }
        })
    })
    $config | Add-Member -NotePropertyName monitoring -NotePropertyValue ([pscustomobject]@{ monitors = @(); correlations = @([pscustomobject]@{ name = 'related'; sources = @($discoveryTask.source, $discoveryTask.source + '#related'); authorities = [pscustomobject]@{ 'acceptance.value' = $discoveryTask.source } }) }) -Force
    $moved = ConvertTo-HarnessMovedData $paths $destination $config $state
    if ($moved.config.projectId -cne $config.projectId -or $moved.config.projectRoot -ine $newRoot -or $moved.config.executionRoot -ine $oldRoot) { throw 'Relocation changed identity or failed to preserve the execution root.' }
    if ($moved.config.restrictions.workingRoots[0] -ine $oldRoot -or $moved.config.restrictions.workingRoots[1] -ine (Join-Path $destination.Control 'worktrees')) { throw 'Relative permissions were retargeted or lost.' }
    if ($moved.config.testing.environments[0].workingDirectory -cne 'tests') { throw 'Workspace-relative tests were made controller-relative.' }
    if ($moved.state.tasks[0].workspace -ine (Join-Path $destination.Control 'worktrees/T-001') -or $moved.state.tasks[0].snapshot -cne $state.tasks[0].snapshot -or $moved.state.references[0].source -ine $oldRoot) { throw 'Worktree location, historical evidence, or external repository identity was not preserved.' }
    if ($moved.state.references[1].source -ine ((Join-Path $destination.Control 'docs/plan.md') + '#choice')) { throw 'A relocated internal reference lost its destination or fragment.' }
    if ($moved.state.tasks[0].source -cne 'requirement-42') { throw 'An opaque requirement identifier became a file path.' }
    $movedCandidate = $moved.state.monitoring.candidates[0]
    $expectedSource = ([uri](Join-Path $destination.Control 'docs/plan.md')).AbsoluteUri
    if ($movedCandidate.source -cne $expectedSource -or $movedCandidate.firstReport -cne (Join-Path $destination.Control 'history/discovery-first.md') -or
        $moved.state.tasks[1].source -cne $expectedSource -or $moved.state.tasks[1].scope -cne "Source discovery: $expectedSource" -or $moved.state.tasks[1].status -cne 'Blocked') { throw 'Relocation lost discovery evidence, task identity, or deferral.' }
    if ($movedCandidate.sameRequirementAs[0] -cne ($expectedSource + '#related') -or $moved.config.monitoring.correlations[0].sources[0] -cne $expectedSource -or
        $moved.config.monitoring.correlations[0].authorities.'acceptance.value' -cne $expectedSource -or
        $movedCandidate.verificationCheckpoint.report -cne (Join-Path $destination.Control 'history/checkpoint.md') -or
        $movedCandidate.verificationCheckpoint.evidence[0].path -cne (Join-Path $destination.Control 'docs/plan.md') -or
        $movedCandidate.verificationCheckpoint.evidence[0].quote -cne 'Original decision evidence') { throw 'Relocation stranded correlation/checkpoint paths or rewrote evidence content.' }
    if ($config.projectRoot -ine $oldRoot -or (Test-Path -LiteralPath $destination.Control)) { throw 'Relocation planning changed source objects or created a destination.' }
    $file = Join-Path $paths.Control 'artifacts/payload.bin'
    New-Item -ItemType Directory -Path (Split-Path -Parent $file) -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $paths.Control 'artifacts/empty') | Out-Null
    [IO.File]::WriteAllBytes($file, [byte[]](0, 1, 2, 250, 255))
    $null = Invoke-HarnessGit $oldRoot @('init', '--quiet')
    $null = Invoke-HarnessGit $oldRoot @('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--allow-empty', '-m', 'fixture', '--quiet')
    [IO.File]::WriteAllText((Join-Path $oldRoot 'AGENTS.md'), 'Retain the original project instructions.')
    $null = Invoke-HarnessGit $oldRoot @('worktree', 'add', '--detach', $state.tasks[0].workspace, 'HEAD')
    [IO.File]::WriteAllText((Join-Path $state.tasks[0].workspace 'uncommitted.txt'), 'Preserve this work')
    $state.tasks[0].status = 'Completed'
    Write-HarnessJson $paths.State $state
    $followUp = Add-HarnessTask -Paths $paths -FollowUpOf $task.id -Description 'Continue the completed workspace'
    $state = Read-HarnessState $paths
    if ($followUp.workspace -cne $state.tasks[0].workspace) { throw 'The relocation fixture did not retain a shared follow-up workspace.' }
    $before = [IO.File]::ReadAllText($paths.State)
    $preview = Move-HarnessRoot $paths $newRoot -SchedulerRoot (Join-Path $fixture 'scheduler')
    if (-not $preview.preview -or (Test-Path $destination.Control) -or [IO.File]::ReadAllText($paths.State) -cne $before) { throw 'Move preview wrote or retargeted records.' }
    Assert-MoveFailure { Move-HarnessRoot $paths $newRoot -RunnerContext ([pscustomobject]@{ restrictions = [pscustomobject]@{ workingRoots = @($oldRoot) } }) } 'outside the approved workingRoots'
    $state.active = [pscustomobject]@{ taskId = $task.id; runId = 'active' }
    Write-HarnessJson $paths.State $state
    Assert-MoveFailure { Move-HarnessRoot $paths $newRoot } 'active work'
    $state.active = $null
    Write-HarnessJson $paths.State $state
    New-Item -ItemType Directory -Path $destination.Control | Out-Null
    [IO.File]::WriteAllText((Join-Path $destination.Control 'keep.txt'), 'Keep the destination')
    Assert-MoveFailure { Move-HarnessRoot $paths $newRoot } 'never merges or overwrites'
    if ([IO.File]::ReadAllText((Join-Path $destination.Control 'keep.txt')) -cne 'Keep the destination') { throw 'A conflicting destination was changed.' }
    Remove-Item -LiteralPath $destination.Control -Recurse -Force
    $held = Enter-HarnessLock $paths.RunLock
    try { Assert-MoveFailure { Move-HarnessRoot $paths $newRoot -SchedulerRoot (Join-Path $fixture 'scheduler') -Apply } 'Harness is busy' }
    finally { $held.Dispose() }
    $viewWriter = (Get-Item Function:Write-HarnessViews).ScriptBlock
    try {
        function Write-HarnessViews { throw 'Injected view publication failure.' }
        $caught = $false
        try { Move-HarnessRoot $paths $newRoot -SchedulerRoot (Join-Path $fixture 'scheduler') -Apply | Out-Null }
        catch { if ($_.Exception.Message -notmatch 'Injected view publication') { throw }; $caught = $true }
        if (-not $caught -or (Test-Path $destination.Control) -or (Read-HarnessConfig $paths).projectRoot -ine $oldRoot) { throw 'A failed move left an authoritative duplicate or blocked the original.' }
        Assert-HarnessRepositoryWorkspace $oldRoot $state.tasks[0].workspace
    }
    finally { Set-Item Function:Write-HarnessViews -Value $viewWriter }
    $result = Move-HarnessRoot $paths $newRoot -SchedulerRoot (Join-Path $fixture 'scheduler') -Apply
    if ($result.status -cne 'Moved' -or (Test-Path $paths.Control) -or (Read-HarnessConfig $destination).projectId -cne $config.projectId) { throw 'The controller was not moved with its identity intact.' }
    if (@([IO.File]::ReadAllBytes((Join-Path $destination.Control 'artifacts/payload.bin'))) -join ',' -cne '0,1,2,250,255') { throw 'Relocation did not preserve binary artifacts.' }
    if (-not (Test-Path -LiteralPath (Join-Path $destination.Control 'artifacts/empty') -PathType Container)) { throw 'Relocation dropped an empty authored directory.' }
    if ((Read-HarnessState $destination).tasks[0].id -cne $task.id) { throw 'Relocation lost the task register.' }
    $savedConfig = Read-HarnessConfig $destination
    $savedConfig.runner.workspaceMode = 'worktree'
    $savedTask = (Read-HarnessState $destination).tasks[0]
    if ((Resolve-HarnessRepository $destination $savedConfig $savedTask) -ine $oldRoot) { throw 'The moved controller changed its implicit coding repository.' }
    $workspace = Get-HarnessWorkspace $destination $savedConfig $savedTask
    Assert-HarnessRepositoryWorkspace $oldRoot $workspace
    if ([IO.File]::ReadAllText((Join-Path $workspace 'uncommitted.txt')) -cne 'Preserve this work') { throw 'Uncommitted work was not preserved.' }
    $movedFollowUp = Get-HarnessTask (Read-HarnessState $destination) $followUp.id
    if ($movedFollowUp.followUpOf -cne $task.id -or $movedFollowUp.workspace -cne $workspace -or $savedTask.snapshot -cne 'Original snapshot evidence') { throw 'Relocation broke a follow-up link, shared workspace, or original completion evidence.' }
    $rootView = & (Join-Path $PSScriptRoot '../skills/planning/harness/scripts/harness.ps1') -Action Root -ProjectPath $newRoot | ConvertFrom-Json
    if ($rootView.executionRoot -ine $oldRoot -or $rootView.project -ine $newRoot) { throw 'Root inspection hid the retained coding target.' }
    $contextView = & (Join-Path $PSScriptRoot '../skills/planning/harness/scripts/harness.ps1') -Action Context -ProjectPath $newRoot | ConvertFrom-Json
    if ($contextView.executionRoot -ine $oldRoot -or (Join-Path $oldRoot 'AGENTS.md') -inotIn $contextView.instructionCandidates) { throw 'Untargeted context inspection lost the original project instructions.' }
    $null = Invoke-HarnessGit $oldRoot @('worktree', 'remove', '--force', $workspace)
    $scheduledRoot = Join-Path $fixture 'scheduled'
    $scheduledDestination = Join-Path $fixture 'scheduled moved'
    New-Item -ItemType Directory -Path $scheduledRoot, $scheduledDestination | Out-Null
    $scheduledPaths = Get-HarnessPaths $scheduledRoot -LayoutVersion 1
    $scheduledConfig = Initialize-Harness $scheduledPaths
    $scheduledConfig.boardPath = 'board'
    $scheduledConfig.runner.rulesPath = '.harness_sv/rules.md'
    [IO.File]::WriteAllText((Join-Path $scheduledPaths.Control 'rules.md'), 'Run only the temporary test fixture.')
    $scheduledConfig.testing = [pscustomobject]@{
        environments = @([pscustomobject]@{ name = 'local'; workingDirectory = 'tests'; variables = @{}; requiredVariables = @(); allowScheduled = $true })
        flows = @([pscustomobject]@{ name = 'location'; method = 'Verify execution directory'; defaultEnvironment = 'local'; maxMinutes = 1; steps = @([pscustomobject]@{ name = 'directory'; executable = 'pwsh'; arguments = @('-NoProfile', '-NonInteractive', '-Command', '[Console]::Write((Get-Location).ProviderPath)') }) })
        afterDev = @()
    }
    New-Item -ItemType Directory -Path (Join-Path $scheduledRoot 'tests') | Out-Null
    Write-HarnessJson $scheduledPaths.Config $scheduledConfig
    Write-HarnessViews $scheduledPaths $scheduledConfig (Read-HarnessState $scheduledPaths)
    $decisionHelper = Join-Path $PSScriptRoot '../skills/planning/harness-decision/scripts/harness-decide.ps1'
    $null = & $decisionHelper -ProjectPath $scheduledRoot -Action Record -Question 'Keep the rule file?' -Choice 'Keep' -Owner Fixture -Reference (Join-Path $scheduledPaths.Control 'rules.md')
    $schedulerRoot = Join-Path $fixture 'scheduled registry'
    New-Item -ItemType Directory -Path $schedulerRoot | Out-Null
    $jobs = @(foreach ($enabled in @($true, $false)) {
        [pscustomobject]@{
            id = [guid]::NewGuid().ToString('N'); key = "fixture-$enabled"; kind = 'project'; projectRoot = $scheduledRoot; projectId = $scheduledConfig.projectId
            directory = $scheduledRoot; executable = 'pwsh'; arguments = @('-File', 'fixture.ps1', '-ProjectPath', $scheduledRoot, '-Action', 'Test', '-Scheduled')
            enabled = $enabled; interval = '45m'; anchor = '2026-09-19T08:30:00Z'; nextDue = '2026-09-19T09:15:00Z'; timeZoneId = 'UTC'; active = $null; recoveryRequired = $false; lockRoots = @($scheduledRoot)
        }
    })
    $local = [pscustomobject]@{ schemaVersion = 1; projectId = $scheduledConfig.projectId; schedulerRoot = $schedulerRoot; jobs = $jobs }
    Write-HarnessJson (Join-Path $scheduledPaths.Control 'schedules.json') $local
    $registry = [pscustomobject]@{ schemaVersion = 1; projects = @([pscustomobject]@{ projectRoot = $scheduledRoot; projectId = $scheduledConfig.projectId; lockRoots = @($scheduledRoot) }); jobs = @(); maintenance = [pscustomobject]@{ enabled = $false; timeZoneId = 'UTC'; lastCompletedDate = '' }; lastTick = '' }
    Write-HarnessJson (Join-Path $schedulerRoot 'schedules.json') $registry
    $jobs[0].active = [pscustomobject]@{ runId = 'active' }
    Write-HarnessJson (Join-Path $scheduledPaths.Control 'schedules.json') $local
    Assert-MoveFailure { Move-HarnessRoot $scheduledPaths $scheduledDestination } 'scheduled workers'
    $jobs[0].active = $null
    Write-HarnessJson (Join-Path $scheduledPaths.Control 'schedules.json') $local
    $board = Join-Path $scheduledRoot 'board'
    $boardBefore = [IO.File]::ReadAllText((Join-Path $board 'decisions.csv'))
    $null = Move-HarnessRoot $scheduledPaths $scheduledDestination -Apply
    $newScheduledPaths = Get-HarnessPaths $scheduledDestination
    $newSchedules = Get-Content -LiteralPath (Join-Path $newScheduledPaths.Control 'schedules.json') -Raw | ConvertFrom-Json
    for ($index = 0; $index -lt $jobs.Count; $index++) {
        foreach ($field in @('id', 'key', 'enabled', 'interval', 'timeZoneId')) {
            if ($newSchedules.jobs[$index].$field -cne $jobs[$index].$field) { throw "Relocation changed saved schedule $field." }
        }
        foreach ($field in @('anchor', 'nextDue')) {
            if ([datetimeoffset]$newSchedules.jobs[$index].$field -ne [datetimeoffset]$jobs[$index].$field) { throw "Relocation changed the scheduled $field instant." }
        }
        if ($newSchedules.jobs[$index].projectRoot -ine $scheduledDestination -or $newSchedules.jobs[$index].arguments[3] -ine $scheduledDestination) { throw 'Scheduled invocation was not retargeted to the moved controller.' }
    }
    $registryAfter = Get-Content -LiteralPath (Join-Path $schedulerRoot 'schedules.json') -Raw | ConvertFrom-Json
    if ($registryAfter.projects[0].projectRoot -ine $scheduledDestination -or (Get-HarnessBoard $newScheduledPaths (Read-HarnessConfig $newScheduledPaths)) -ine $board) { throw 'Scheduler registration or explicit external board was lost.' }
    $decisionAfter = Import-Csv -LiteralPath (Join-Path $board 'decisions.csv')
    $decisionBefore = $boardBefore | ConvertFrom-Csv
    if ($decisionAfter.reference -ine (Join-Path $newScheduledPaths.Control 'rules.md') -or $decisionAfter.recordedAt -cne $decisionBefore.recordedAt -or $decisionAfter.choice -cne 'Keep') { throw 'External decision evidence was broken or its history changed.' }
    $testResult = Invoke-HarnessTests $newScheduledPaths -Flow location -Scheduled
    if ($testResult.status -cne 'Passed' -or $testResult.workspace -ine $scheduledRoot -or $testResult.result.checks[0].output -ine (Join-Path $scheduledRoot 'tests')) { throw 'A moved test controller changed its execution directory.' }
    Write-Output 'Relocation mapping checks passed: identity, execution root, owned paths, external references, permissions, and historical evidence.'
}
finally {
    $env:SKILLVAULT_OWNERSHIP_ROOT = $savedFixtureOwnershipRoot
    Remove-Item -LiteralPath $fixture -Recurse -Force
}