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
    $oldRoot = Join-Path $fixture 'old project'
    $newRoot = Join-Path $fixture 'new controller'
    New-Item -ItemType Directory -Path $oldRoot, $newRoot -Force | Out-Null
    $paths = Get-HarnessPaths $oldRoot
    $destination = Get-HarnessPaths $newRoot
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
    $moved = ConvertTo-HarnessMovedData $paths $destination $config $state
    if ($moved.config.projectId -cne $config.projectId -or $moved.config.projectRoot -ine $newRoot -or $moved.config.executionRoot -ine $oldRoot) { throw 'Relocation changed identity or failed to preserve the execution root.' }
    if ($moved.config.restrictions.workingRoots[0] -ine $oldRoot -or $moved.config.restrictions.workingRoots[1] -ine (Join-Path $destination.Control 'worktrees')) { throw 'Relative permissions were retargeted or lost.' }
    if ($moved.config.testing.environments[0].workingDirectory -cne 'tests') { throw 'Workspace-relative tests were made controller-relative.' }
    if ($moved.state.tasks[0].workspace -ine (Join-Path $destination.Control 'worktrees/T-001') -or $moved.state.tasks[0].snapshot -cne $state.tasks[0].snapshot -or $moved.state.references[0].source -ine $oldRoot) { throw 'Worktree location, historical evidence, or external repository identity was not preserved.' }
    if ($moved.state.references[1].source -ine ((Join-Path $destination.Control 'docs/plan.md') + '#choice')) { throw 'A relocated internal reference lost its destination or fragment.' }
    if ($moved.state.tasks[0].source -cne 'requirement-42') { throw 'An opaque requirement identifier became a file path.' }
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
    $scheduledPaths = Get-HarnessPaths $scheduledRoot
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