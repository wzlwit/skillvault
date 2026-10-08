. (Join-Path $PSScriptRoot 'harness-store.ps1')
. (Join-Path $PSScriptRoot 'harness-runner.ps1')
. (Join-Path $PSScriptRoot 'harness-maintenance.ps1')

function Get-HarnessMigrationPlan {
    param($Paths, $RunnerContext)
    $config = Read-HarnessConfig $Paths
    $state = Read-HarnessState $Paths
    if ($Paths.LayoutVersion -eq 2) { return [pscustomobject]@{ status = 'Current'; projectId = $config.projectId; source = $Paths; destination = $Paths } }
    if ($state.active -or @($state.tasks | Where-Object status -EQ Running).Count) { throw 'Finish or recover active work before layout migration.' }
    $destination = Get-HarnessPaths $Paths.Project -LayoutVersion 2
    $board = Get-HarnessBoard $Paths $config
    $nextConfig = $config | ConvertTo-Json -Depth 30 | ConvertFrom-Json -NoEnumerate
    if ($board -ieq $Paths.Control) { $nextConfig.boardPath = [IO.Path]::GetRelativePath($Paths.Project, (Join-Path $Paths.Control 'board')) }
    $nextBoard = Get-HarnessBoard $destination $nextConfig
    $effective = Resolve-HarnessRunnerConfig $config $RunnerContext
    foreach ($root in @($Paths.Control, $board, $nextBoard)) {
        Assert-HarnessMigrationPath $root
        Assert-HarnessRestrictions -Config $effective -ProjectRoot $Paths.Project -Workspace $root
    }
    Assert-HarnessBoard $Paths $config
    $schedules = Read-HarnessProjectSchedules $Paths
    if ($schedules) {
        if ($schedules.schemaVersion -ne 1 -or $schedules.projectId -cne $config.projectId -or $schedules.jobs -isnot [array]) { throw 'Invalid project schedule ownership.' }
        if (@($schedules.jobs | Where-Object { $_.active -or $_.recoveryRequired }).Count) { throw 'Finish or recover scheduled workers before layout migration.' }
        foreach ($job in $schedules.jobs) {
            if ($job.kind -cne 'project' -or $job.projectId -cne $config.projectId -or $job.projectRoot -ine $Paths.Project) { throw 'A local schedule points at another controller.' }
        }
        if (-not [IO.Path]::IsPathFullyQualified([string]$schedules.schedulerRoot)) { throw 'The project scheduler registration must be unambiguous.' }
        $registry = Read-HarnessConfigObject (Join-Path $schedules.schedulerRoot 'schedules.json')
        $registration = @($registry.projects | Where-Object { $_.projectId -ceq $config.projectId -or $_.projectRoot -ieq $Paths.Project })
        if ($registry.schemaVersion -ne 1 -or $registration.Count -ne 1 -or $registration[0].projectId -cne $config.projectId -or $registration[0].projectRoot -ine $Paths.Project) { throw 'Local schedules and their scheduler registration disagree.' }
    }
    $mappings = @(
        [pscustomobject]@{ source = $Paths.Config; destination = $destination.Config; kind = 'Configuration' }
        [pscustomobject]@{ source = $Paths.State; destination = $destination.State; kind = 'State' }
    )
    if ($schedules) { $mappings += [pscustomobject]@{ source = $Paths.ScheduleConfig; destination = $destination.ScheduleConfig; kind = 'Schedules' } }
    if ($board -ine $nextBoard) {
        foreach ($name in @('.harness-board.json', (Get-HarnessCurrentFileName $config), 'history.csv', 'references.csv', 'decisions.csv')) {
            $source = Join-Path $board $name
            if (Test-Path -LiteralPath $source) { $mappings += [pscustomobject]@{ source = $source; destination = Join-Path $nextBoard $name; kind = 'Board' } }
        }
    }
    foreach ($run in @($state.runs | Where-Object report)) {
        if (-not (Test-Path -LiteralPath $run.report -PathType Leaf)) { continue }
        if (-not (Test-HarnessOwnedHistoryPath $board $run.report $run.id)) { continue }
        $target = Get-HarnessReportPath $destination $nextConfig $run.id $run.phase ([datetimeoffset]$run.startedAt)
        $mappings += [pscustomobject]@{ source = $run.report; destination = $target; kind = 'Report' }
    }
    $duplicates = @()
    foreach ($legacy in @(
        [pscustomobject]@{ name = 'monitors.json'; value = $config.monitoring; target = 'monitors.json' }
        [pscustomobject]@{ name = 'automation-policy.json'; value = $config.restrictions; target = 'policy.json' }
    )) {
        $source = Join-Path $Paths.Control $legacy.name
        if (-not (Test-Path -LiteralPath $source)) { continue }
        $declared = Read-HarnessConfigObject $source
        if (($declared | ConvertTo-Json -Depth 30 -Compress) -cne ($legacy.value | ConvertTo-Json -Depth 30 -Compress)) { throw "Legacy declaration differs from effective configuration: $source. Reconcile it before migration." }
        $duplicates += $source
        $mappings += [pscustomobject]@{ source = $source; destination = Join-Path (Split-Path -Parent $destination.Config) $legacy.target; kind = 'Declaration' }
    }
    $destinations = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($mapping in $mappings) {
        Assert-HarnessMigrationPath $mapping.source
        Assert-HarnessMigrationPath $mapping.destination
        if ((Test-Path -LiteralPath $mapping.destination) -or -not $destinations.Add($mapping.destination)) { throw "Migration destination already exists or is duplicated: $($mapping.destination)" }
    }
    foreach ($name in @('project.json', 'monitors.json', 'tests.json', 'policy.json', 'schedules.json')) {
        if (Test-Path -LiteralPath (Join-Path $Paths.Control "config/$name")) { throw 'The new configuration directory already contains a declaration; migration does not merge controllers.' }
    }
    if (Test-Path -LiteralPath $destination.ScheduleState) { throw 'The new runtime directory already contains schedule state.' }
    $nextState = $state | ConvertTo-Json -Depth 30 | ConvertFrom-Json -NoEnumerate
    Update-HarnessLayoutReferences $nextState $Paths $mappings
    Update-HarnessLayoutReferences $nextConfig $Paths $mappings
    foreach ($candidate in @($nextState.monitoring.candidates | Where-Object { $_ })) {
        $original = $state.monitoring.candidates | Where-Object id -CEQ $candidate.id | Select-Object -First 1
        foreach ($task in @($nextState.tasks | Where-Object { $_.id -ceq $candidate.taskId -and $_.scope -ceq "Source discovery: $($original.source)" })) { $task.scope = "Source discovery: $($candidate.source)" }
    }
    [pscustomobject]@{ status = 'Planned'; source = $Paths; destination = $destination; projectId = $config.projectId; config = $nextConfig; state = $nextState; schedules = $schedules; mappings = $mappings; board = $nextBoard; previousBoard = $board; duplicates = $duplicates }
}

function Invoke-HarnessMigration {
    param($Paths, [switch]$Apply, $RunnerContext)
    $plan = Get-HarnessMigrationPlan $Paths $RunnerContext
    if ($plan.status -eq 'Current') { return [pscustomobject]@{ preview = -not $Apply; status = 'Current'; projectId = $plan.projectId; layoutVersion = 2 } }
    $summary = [pscustomobject]@{ preview = -not $Apply; status = 'Planned'; projectId = $plan.projectId; layoutVersion = 2; control = $Paths.Control; board = $plan.board; moves = $plan.mappings; schedules = @($plan.schedules.jobs.id); note = 'Custom adapters, snapshots, and unrelated files are preserved. Review adapter path assumptions before applying.' }
    if (-not $Apply) { return $summary }
    $locks = [Collections.Generic.List[object]]::new()
    $ownership = $null
    $marker = Join-Path $Paths.Control 'migrate.pending.json'
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('harness-layout-' + [guid]::NewGuid().ToString('N'))
    $originals = @()
    $committed = $false
    try {
        if ($plan.schedules) { $locks.Add((Enter-HarnessLock (Join-Path $plan.schedules.schedulerRoot 'scheduler.lock'))) }
        $locks.Add((Enter-HarnessLock $Paths.RunLock))
        $locks.Add((Enter-HarnessLock $Paths.Lock))
        $locks.Add((Enter-HarnessLock $Paths.ScheduleLock))
        if (Test-Path -LiteralPath $plan.previousBoard) { $locks.Add((Enter-HarnessLock (Join-Path $plan.previousBoard 'decisions.lock'))) }
        $ownership = Enter-HarnessOwnership $Paths -Role migration -Workspace $Paths.Control -AdditionalWorkspaces @($plan.previousBoard, $plan.board)
        $plan = Get-HarnessMigrationPlan $Paths $RunnerContext
        $writes = @($plan.mappings.source) + @($plan.mappings.destination) + @(
            $plan.destination.State, $plan.destination.ScheduleState, (Join-Path $Paths.Control 'README.md')
            foreach ($name in @('project.json', 'tests.json', 'monitors.json', 'policy.json')) { Join-Path $Paths.Control "config/$name" }
            foreach ($name in @('.harness-board.json', (Get-HarnessCurrentFileName $plan.config), 'history.csv', 'references.csv', 'decisions.csv')) { Join-Path $plan.board $name }
        ) | Sort-Object -Unique
        New-Item -ItemType Directory -Path $temporary | Out-Null
        foreach ($path in $writes) {
            Assert-HarnessMigrationPath $path
            $backup = Join-Path $temporary ([string]$originals.Count)
            $exists = Test-Path -LiteralPath $path
            if ($exists) { Copy-Item -LiteralPath $path -Destination $backup }
            $originals += [pscustomobject]@{ path = $path; original = $backup; existed = $exists }
        }
        Write-HarnessJson $marker ([pscustomobject]@{ operation = 'layout'; projectId = $plan.projectId; originals = $originals; temporary = $temporary })
        foreach ($mapping in @($plan.mappings | Where-Object kind -In @('Board', 'Report'))) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $mapping.destination) -Force | Out-Null
            Copy-Item -LiteralPath $mapping.source -Destination $mapping.destination
            if ((Get-FileHash -LiteralPath $mapping.source).Hash -cne (Get-FileHash -LiteralPath $mapping.destination).Hash) { throw 'Evidence changed during layout migration.' }
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $plan.destination.Lock) -Force | Out-Null
        Write-HarnessConfig $plan.destination $plan.config
        Write-HarnessJson $plan.destination.State $plan.state
        if ($plan.schedules) { Write-HarnessProjectSchedules $plan.destination $plan.schedules }
        $decisionPath = Join-Path $plan.board 'decisions.csv'
        if (Test-Path -LiteralPath $decisionPath) {
            $decisions = @(Import-Csv -LiteralPath $decisionPath)
            foreach ($decision in $decisions) { if ($decision.reference) { $decision.reference = ConvertTo-HarnessLayoutReference $decision.reference $Paths $plan.mappings } }
            if ($decisions.Count) { Write-HarnessCsv $decisionPath $decisions @($decisions[0].PSObject.Properties.Name) }
        }
        Write-HarnessViews $plan.destination $plan.config $plan.state
        foreach ($mapping in $plan.mappings) { Remove-Item -LiteralPath $mapping.source -Force }
        Remove-Item -LiteralPath $marker -Force
        $committed = $true
        $summary.status = 'Migrated'
    }
    catch {
        $failure = $_
        if (Test-Path -LiteralPath $marker) {
            try {
                foreach ($original in $originals) {
                    if ($original.existed) { Copy-Item -LiteralPath $original.original -Destination $original.path -Force }
                    elseif (Test-Path -LiteralPath $original.path) { Remove-Item -LiteralPath $original.path -Force }
                }
                Remove-Item -LiteralPath $marker -Force
            }
            catch { throw "Layout recovery is incomplete. Preserve $marker and $temporary. $($_.Exception.Message) Original error: $($failure.Exception.Message)" }
        }
        throw $failure
    }
    finally {
        if ($ownership) { Exit-HarnessOwnership $ownership $(if ($committed) { $plan.destination } else { $Paths }) }
        for ($index = $locks.Count - 1; $index -ge 0; $index--) { $locks[$index].Dispose() }
        if (-not (Test-Path -LiteralPath $marker) -and (Test-Path -LiteralPath $temporary)) { Remove-Item -LiteralPath $temporary -Recurse -Force }
    }
    foreach ($lockPath in @($Paths.Lock, $Paths.RunLock, $Paths.ScheduleLock)) { if (Test-Path -LiteralPath $lockPath) { Remove-Item -LiteralPath $lockPath -Force } }
    if ($plan.previousBoard -ine $plan.board) {
        $oldDecisionLock = Join-Path $plan.previousBoard 'decisions.lock'
        if (Test-Path -LiteralPath $oldDecisionLock) { Remove-Item -LiteralPath $oldDecisionLock -Force }
    }
    $summary
}