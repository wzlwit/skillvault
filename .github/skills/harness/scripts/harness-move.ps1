. (Join-Path $PSScriptRoot 'harness-store.ps1')
. (Join-Path $PSScriptRoot 'harness-runner.ps1')

function ConvertTo-HarnessMovedPath {
    param([string]$Value, $Paths, $Destination, [switch]$ResolveRelative, [switch]$ExistingRelative)
    if (-not $Value -or $Value -match '^[a-z][a-z0-9+.-]*://') { return $Value }
    $parts = $Value.Split('#', 2)
    if ($ExistingRelative -and -not [IO.Path]::IsPathFullyQualified($parts[0])) {
        if (-not (Test-Path -LiteralPath (Join-Path $Paths.Project $parts[0]))) { return $Value }
        $ResolveRelative = $true
    }
    if (-not [IO.Path]::IsPathFullyQualified($parts[0]) -and -not $ResolveRelative) { return $Value }
    $absolute = [IO.Path]::GetFullPath($parts[0], $Paths.Project)
    $relative = [IO.Path]::GetRelativePath($Paths.Control, $absolute)
    if ($relative -ne '..' -and -not $relative.StartsWith('..' + [IO.Path]::DirectorySeparatorChar) -and -not [IO.Path]::IsPathRooted($relative)) {
        $absolute = [IO.Path]::GetFullPath((Join-Path $Destination.Control $relative))
    }
    if ($parts.Count -eq 2) { $absolute += '#' + $parts[1] }
    $absolute
}

function ConvertTo-HarnessMovedData {
    param($Paths, $Destination, $Config, $State, $Schedules)
    $configCopy = $Config | ConvertTo-Json -Depth 40 | ConvertFrom-Json
    $stateCopy = $State | ConvertTo-Json -Depth 40 | ConvertFrom-Json
    $executionRoot = if ($Config.executionRoot) { $Config.executionRoot } else { $Paths.Project }
    $configCopy | Add-Member -NotePropertyName executionRoot -NotePropertyValue $executionRoot -Force
    $configCopy.projectRoot = $Destination.Project
    $configCopy.boardPath = ConvertTo-HarnessMovedPath (Get-HarnessBoard $Paths $Config) $Paths $Destination
    if ($configCopy.boardPath -ieq $Destination.Control) { $configCopy.boardPath = '.harness_sv' }
    if ($configCopy.runner.rulesPath) { $configCopy.runner.rulesPath = ConvertTo-HarnessMovedPath $configCopy.runner.rulesPath $Paths $Destination -ResolveRelative }
    if ($configCopy.runner.command -match '[\\/]') { $configCopy.runner.command = ConvertTo-HarnessMovedPath $configCopy.runner.command $Paths $Destination -ResolveRelative }
    if ($configCopy.restrictions.workingRoots) {
        $configCopy.restrictions.workingRoots = @($configCopy.restrictions.workingRoots | ForEach-Object { ConvertTo-HarnessMovedPath $_ $Paths $Destination -ResolveRelative })
    }
    foreach ($environment in @($configCopy.testing.environments)) {
        if ($environment.workingDirectory) { $environment.workingDirectory = ConvertTo-HarnessMovedPath $environment.workingDirectory $Paths $Destination }
    }
    foreach ($step in @($configCopy.runner.validationCommands) + @($configCopy.testing.flows.steps)) {
        if (-not $step) { continue }
        $step.executable = ConvertTo-HarnessMovedPath $step.executable $Paths $Destination
        $step.arguments = @($step.arguments | ForEach-Object { ConvertTo-HarnessMovedPath $_ $Paths $Destination })
    }
    foreach ($monitor in @($configCopy.monitoring.monitors)) {
        if ($monitor.source.path) { $monitor.source.path = ConvertTo-HarnessMovedPath $monitor.source.path $Paths $Destination -ResolveRelative }
    }
    foreach ($task in @($stateCopy.tasks)) {
        foreach ($field in @('workspace', 'lastReport', 'repositoryRoot')) {
            if ($task.$field) { $task.$field = ConvertTo-HarnessMovedPath $task.$field $Paths $Destination }
        }
        if ($task.source) { $task.source = ConvertTo-HarnessMovedPath $task.source $Paths $Destination -ExistingRelative }
    }
    foreach ($reference in @($stateCopy.references)) {
        if ($reference.source) { $reference.source = ConvertTo-HarnessMovedPath $reference.source $Paths $Destination -ExistingRelative }
    }
    foreach ($run in @($stateCopy.runs)) {
        foreach ($field in @('workspace', 'report', 'repositoryRoot')) {
            if ($run.$field) { $run.$field = ConvertTo-HarnessMovedPath $run.$field $Paths $Destination }
        }
        if ($run.review.repositoryRoot) { $run.review.repositoryRoot = ConvertTo-HarnessMovedPath $run.review.repositoryRoot $Paths $Destination }
    }
    foreach ($entry in @($stateCopy.monitoring.latest) + @($stateCopy.maintenance.pendingDeletes) + @($stateCopy.prReviews)) {
        if (-not $entry) { continue }
        foreach ($field in @('report', 'engineReport')) {
            if ($entry.$field) { $entry.$field = ConvertTo-HarnessMovedPath $entry.$field $Paths $Destination }
        }
    }
    foreach ($incident in @($stateCopy.monitoring.incidents)) {
        foreach ($field in @('firstReport', 'latestReport')) {
            if ($incident.$field) { $incident.$field = ConvertTo-HarnessMovedPath $incident.$field $Paths $Destination }
        }
    }
    $scheduleCopy = $null
    if ($Schedules) {
        $scheduleCopy = $Schedules | ConvertTo-Json -Depth 40 | ConvertFrom-Json
        foreach ($job in $scheduleCopy.jobs) {
            if ($job.projectRoot -ine $Paths.Project -or $job.projectId -cne $Config.projectId) { throw 'A local schedule belongs to another controller.' }
            $job.projectRoot = $Destination.Project
            $job.directory = $Destination.Project
            foreach ($field in @('runnerPath', 'runnerContextPath', 'executable')) {
                if ($job.$field) { $job.$field = ConvertTo-HarnessMovedPath $job.$field $Paths $Destination }
            }
            for ($index = 0; $index -lt $job.arguments.Count; $index++) {
                if ($index -gt 0 -and $job.arguments[$index - 1] -ieq '-ProjectPath') { $job.arguments[$index] = $Destination.Project }
                else { $job.arguments[$index] = ConvertTo-HarnessMovedPath $job.arguments[$index] $Paths $Destination }
            }
            $job | Add-Member -NotePropertyName lockRoots -NotePropertyValue @(@($job.lockRoots | ForEach-Object { ConvertTo-HarnessMovedPath $_ $Paths $Destination }) + @($Destination.Project, $executionRoot) | Where-Object { $_ } | Sort-Object -Unique) -Force
        }
    }
    [pscustomobject]@{ config = $configCopy; state = $stateCopy; schedules = $scheduleCopy }
}

function Get-HarnessMoveFiles {
    param([string]$Root, [string[]]$Exclude = @())
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($Root)
    while ($pending.Count) {
        $directory = $pending.Pop()
        foreach ($item in Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Relocation does not follow linked files or directories. Resolve those paths explicitly before moving.' }
            if ($item.PSIsContainer) {
                if ($item.Name -eq '.git') { throw 'An embedded Git repository is application source, not movable harness state.' }
                $pending.Push($item.FullName)
                [pscustomobject]@{ relative = [IO.Path]::GetRelativePath($Root, $item.FullName); source = $item.FullName; hash = 'Directory'; directory = $true }
            }
            else {
                $relative = [IO.Path]::GetRelativePath($Root, $item.FullName)
                if ($relative -in @('store.lock', 'runner.lock', 'schedules.lock', 'move.pending.json') -or $item.FullName -in $Exclude) { continue }
                [pscustomobject]@{ relative = $relative; source = $item.FullName; hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash; directory = $false }
            }
        }
    }
}

function Get-HarnessMovePlan {
    param($Paths, [string]$DestinationPath, [string]$SchedulerRoot, $RunnerContext)
    if (-not [IO.Path]::IsPathRooted($DestinationPath)) { $DestinationPath = Join-Path $Paths.Project $DestinationPath }
    $destination = Get-HarnessPaths $DestinationPath
    if ($destination.Project -ieq $Paths.Project) { throw 'Choose a different existing parent directory for relocation.' }
    if (Test-Path -LiteralPath $destination.Control) { throw 'The destination already contains harness data; relocation never merges or overwrites it.' }
    foreach ($pair in @(@($Paths.Control, $destination.Control), @($destination.Control, $Paths.Control))) {
        $relative = [IO.Path]::GetRelativePath($pair[0], $pair[1])
        if ($relative -ne '..' -and -not $relative.StartsWith('..' + [IO.Path]::DirectorySeparatorChar) -and -not [IO.Path]::IsPathRooted($relative)) { throw 'Relocation source and destination cannot contain each other.' }
    }
    foreach ($root in @($Paths.Control, $destination.Project)) {
        $current = $root
        while ($current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Relocation requires non-linked parent directories.' }
            $current = Split-Path -Parent $current
        }
    }
    $config = Read-HarnessConfig $Paths
    $effectiveConfig = Resolve-HarnessRunnerConfig $config $RunnerContext
    foreach ($directory in @($Paths.Control, $destination.Control, (Get-HarnessBoard $Paths $config))) {
        Assert-HarnessRestrictions -Config $effectiveConfig -ProjectRoot $Paths.Project -Workspace $directory
    }
    if ($config.prReview) { throw 'The user-wide PR controller has separate storage; this operation moves project harnesses only.' }
    $state = Read-HarnessState $Paths
    if ($state.active -or @($state.tasks | Where-Object status -EQ Running).Count) { throw 'Finish or recover active work before moving a harness.' }
    Assert-HarnessBoard $Paths $config
    $localPath = Join-Path $Paths.Control 'schedules.json'
    $local = if (Test-Path -LiteralPath $localPath) { Get-Content -LiteralPath $localPath -Raw | ConvertFrom-Json -NoEnumerate } else { $null }
    if ($local) {
        if ($local.schemaVersion -ne 1 -or $local.projectId -cne $config.projectId -or $local.jobs -isnot [array]) { throw 'Invalid project schedule ownership.' }
        if (@($local.jobs | Where-Object { $_.active -or $_.recoveryRequired }).Count) { throw 'Finish or recover scheduled workers before relocation.' }
        if ($SchedulerRoot -and [IO.Path]::GetFullPath($SchedulerRoot) -ine $local.schedulerRoot) { throw 'Use the scheduler recorded by this controller.' }
        $SchedulerRoot = $local.schedulerRoot
    }
    if (-not $SchedulerRoot) { $SchedulerRoot = Join-Path $HOME '.copilot/skillvault/scheduler' }
    $SchedulerRoot = [IO.Path]::GetFullPath($SchedulerRoot)
    if ((ConvertTo-HarnessMovedPath $SchedulerRoot $Paths $destination) -ine $SchedulerRoot) { throw 'The user-wide scheduler cannot be moved inside this controller.' }
    $registryPath = Join-Path $SchedulerRoot 'schedules.json'
    $registry = if (Test-Path -LiteralPath $registryPath) { Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json -NoEnumerate } else { $null }
    if ($registry -and ($registry.schemaVersion -ne 1 -or $registry.projects -isnot [array])) { throw 'Invalid scheduler registry; do not retarget it.' }
    $registered = @($registry.projects | Where-Object { $_.projectId -ceq $config.projectId -or $_.projectRoot -ieq $Paths.Project })
    if (($local -and $registered.Count -ne 1) -or ($registered.Count -and (-not $local -or $registered[0].projectId -cne $config.projectId -or $registered[0].projectRoot -ine $Paths.Project))) { throw 'Local schedules and the central registration do not agree.' }
    if (@($registry.projects | Where-Object { $_.projectRoot -ieq $destination.Project }).Count) { throw 'The destination is already registered with the scheduler.' }
    if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
        $pattern = '^SkillVault Harness ' + [regex]::Escape($config.projectId) + '(?: |$)'
        $legacy = @(Get-ScheduledTask -TaskPath '\' -ErrorAction Stop | Where-Object { $_.TaskName -match $pattern -and [string]$_.State -ne 'Disabled' })
        if ($legacy.Count) { throw 'Disable or migrate the exact legacy OS timers before relocating their controller.' }
    }
    $worktrees = @(foreach ($task in @($state.tasks | Where-Object workspace)) {
        $target = ConvertTo-HarnessMovedPath $task.workspace $Paths $destination
        if ($target -ieq $task.workspace) { continue }
        if (-not $task.repositoryRoot -or -not (Test-Path -LiteralPath (Join-Path $task.workspace '.git') -PathType Leaf)) { throw 'A moved workspace must be a registered Git worktree with its repository root recorded.' }
        Assert-HarnessRestrictions -Config $effectiveConfig -ProjectRoot $Paths.Project -Workspace $task.repositoryRoot -Executable git
        Assert-HarnessRepositoryWorkspace $task.repositoryRoot $task.workspace
        [pscustomobject]@{ source = $task.workspace; destination = $target; repository = $task.repositoryRoot }
    })
    foreach ($job in @($local.jobs | Where-Object runnerContextPath)) {
        if ((ConvertTo-HarnessMovedPath $job.runnerContextPath $Paths $destination) -ine $job.runnerContextPath) { throw 'Move the runner context to an explicitly selected external file before relocating this scheduled controller.' }
        $context = Get-Content -LiteralPath $job.runnerContextPath -Raw | ConvertFrom-Json
        foreach ($layer in @($context, $context.parent | Where-Object { $_ })) {
            if ((-not $layer.projectRoot -and @($layer.restrictions.workingRoots | Where-Object { $_ -and -not [IO.Path]::IsPathFullyQualified($_) }).Count) -or ($layer.runner.rulesPath -and -not [IO.Path]::IsPathFullyQualified($layer.runner.rulesPath)) -or ($layer.runner.command -match '[\\/]' -and -not [IO.Path]::IsPathFullyQualified($layer.runner.command))) { throw 'Runner context paths must keep an explicit original root before relocation; its file is preserved.' }
        }
    }
    $data = ConvertTo-HarnessMovedData $Paths $destination $config $state $local
    $decisionLockPath = Join-Path (Get-HarnessBoard $Paths $config) 'decisions.lock'
    $files = @(Get-HarnessMoveFiles $Paths.Control -Exclude $decisionLockPath)
    foreach ($file in @($files | Where-Object { [IO.Path]::GetFileName($_.source) -eq '.git' })) {
        if ((Split-Path -Parent $file.source) -inotIn @($worktrees.source)) { throw 'An unregistered worktree must be reconciled before relocation.' }
    }
    if ($registry) {
        $schedulerHelper = Join-Path $PSScriptRoot '../../harness-timer/scripts/harness-scheduler.ps1'
        if (-not (Test-Path -LiteralPath $schedulerHelper)) { throw 'Install the sibling harness-timer helper before relocating a registered controller.' }
        . $schedulerHelper
        $scheduledState = Read-HarnessSchedules (Get-HarnessSchedulerPaths $SchedulerRoot)
        $moving = [pscustomobject]@{ kind = 'move'; directory = $Paths.Control }
        foreach ($job in @($scheduledState.jobs | Where-Object { $_.active -or $_.recoveryRequired })) {
            if ((Test-HarnessScheduleConflict $moving $job) -or @($worktrees | Where-Object { Test-HarnessScheduleConflict ([pscustomobject]@{ kind = 'move'; directory = $_.repository }) $job }).Count) { throw 'A conflicting scheduled worker is active or requires recovery.' }
        }
        foreach ($unknown in $scheduledState.unavailableProjects) {
            $job = [pscustomobject]@{ kind = 'project'; projectRoot = $unknown.projectRoot; directory = $unknown.projectRoot; lockRoots = $unknown.lockRoots }
            if (Test-HarnessScheduleConflict $moving $job) { throw 'A conflicting scheduler registration is unavailable; reconcile it before moving.' }
        }
    }
    [pscustomobject]@{ preview = $true; source = $Paths; destination = $destination; projectId = $config.projectId; board = Get-HarnessBoard $destination $data.config; executionRoot = $data.config.executionRoot; data = $data; files = $files; worktrees = $worktrees; registry = $registry; registryPath = $registryPath; schedulerRoot = $SchedulerRoot; scheduled = [bool]$local; decisionLockPath = $decisionLockPath }
}

function Move-HarnessRoot {
    param($Paths, [string]$DestinationPath, [string]$SchedulerRoot, [switch]$Apply, $RunnerContext)
    $plan = Get-HarnessMovePlan $Paths $DestinationPath $SchedulerRoot $RunnerContext
    $summary = [pscustomobject]@{ preview = -not $Apply; status = 'Planned'; projectId = $plan.projectId; source = $Paths.Control; destination = $plan.destination.Control; root = $plan.destination.Project; executionRoot = $plan.executionRoot; board = $plan.board; files = @($plan.files | Where-Object { -not $_.directory }).Count; worktrees = $plan.worktrees; scheduledJobs = @($plan.data.schedules.jobs | ForEach-Object { $_.id }); schedulerUpdated = [bool]($Apply -and $plan.scheduled) }
    if (-not $Apply) { return $summary }
    $schedulerLock = $null
    $runLock = $null
    $storeLock = $null
    $decisionLock = $null
    $externalViews = @()
    $stage = ''
    $newPublished = $false
    $registryWritten = $false
    $sourceConfig = [IO.File]::ReadAllText($Paths.Config)
    $sourceMarker = Join-Path $Paths.Control 'move.pending.json'
    $repaired = @()
    try {
        New-Item -ItemType Directory -Path $plan.schedulerRoot -Force | Out-Null
        $schedulerLock = Enter-HarnessLock (Join-Path $plan.schedulerRoot 'scheduler.lock')
        $runLock = Enter-HarnessLock $Paths.RunLock
        $storeLock = Enter-HarnessLock $Paths.Lock
        $plan = Get-HarnessMovePlan $Paths $DestinationPath $SchedulerRoot $RunnerContext
        $sourceConfig = [IO.File]::ReadAllText($Paths.Config)
        $sourceBoard = Get-HarnessBoard $Paths ($sourceConfig | ConvertFrom-Json)
        $sourceDecisions = Join-Path $sourceBoard 'decisions.csv'
        if (Test-Path -LiteralPath $sourceBoard) { $decisionLock = Enter-HarnessLock $plan.decisionLockPath }
        if ($plan.board -ieq $sourceBoard) {
            $externalViews = @(foreach ($name in @('.harness-board.json', 'current.csv', 'history.csv', 'references.csv', 'decisions.csv')) {
                $file = Join-Path $sourceBoard $name
                [pscustomobject]@{ path = $file; content = $(if (Test-Path -LiteralPath $file) { [IO.File]::ReadAllBytes($file) }) }
            })
        }
        $stage = Join-Path $plan.destination.Project ('.harness_sv.move-' + [guid]::NewGuid().ToString('N'))
        $marker = [pscustomobject]@{ projectId = $plan.projectId; sourceRoot = $Paths.Project; destinationRoot = $plan.destination.Project; staging = $stage; phase = 'Preparing' }
        Write-HarnessJson $sourceMarker $marker
        New-Item -ItemType Directory -Path $stage | Out-Null
        foreach ($file in $plan.files) {
            $target = Join-Path $stage $file.relative
            if ($file.directory) { New-Item -ItemType Directory -Path $target -Force | Out-Null; continue }
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $file.source -Destination $target -Force
            if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -cne $file.hash -or (Get-FileHash -LiteralPath $file.source -Algorithm SHA256).Hash -cne $file.hash) { throw 'Harness files changed while being copied; relocation was not committed.' }
        }
        Write-HarnessJson (Join-Path $stage 'config.json') $plan.data.config
        Write-HarnessJson (Join-Path $stage 'state.json') $plan.data.state
        Write-HarnessJson (Join-Path $stage 'move.pending.json') $marker
        if ($plan.data.schedules) { Write-HarnessJson (Join-Path $stage 'schedules.json') $plan.data.schedules }
        $decisions = @()
        if (Test-Path -LiteralPath $sourceDecisions) {
            $decisions = @(Import-Csv -LiteralPath $sourceDecisions)
            foreach ($decision in $decisions) {
                if ($decision.PSObject.Properties['reference'] -and $decision.reference) { $decision.reference = ConvertTo-HarnessMovedPath $decision.reference $Paths $plan.destination -ExistingRelative }
            }
            if ($decisions.Count -and $plan.board -ine $sourceBoard) {
                $decisionRegister = Join-Path (ConvertTo-HarnessMovedPath $sourceBoard $Paths ([pscustomobject]@{ Control = $stage })) 'decisions.csv'
                Write-HarnessCsv $decisionRegister $decisions @($decisions[0].PSObject.Properties.Name)
            }
        }
        if (Test-Path -LiteralPath $plan.destination.Control) { throw 'The destination changed after preview; no overwrite is permitted.' }
        [IO.Directory]::Move($stage, $plan.destination.Control)
        $newPublished = $true
        foreach ($worktree in $plan.worktrees) {
            $repaired += $worktree
            $null = Invoke-HarnessGit $worktree.repository @('worktree', 'repair', $worktree.destination)
            Assert-HarnessRepositoryWorkspace $worktree.repository $worktree.destination
        }
        $currentFiles = @(Get-HarnessMoveFiles $Paths.Control -Exclude $plan.decisionLockPath)
        if ($currentFiles.Count -ne $plan.files.Count -or @(Compare-Object $plan.files $currentFiles -Property relative, hash).Count) { throw 'Source files changed during relocation; the original controller is retained.' }
        if ($decisions.Count -and $plan.board -ieq $sourceBoard) { Write-HarnessCsv $sourceDecisions $decisions @($decisions[0].PSObject.Properties.Name) }
        Write-HarnessViews $plan.destination $plan.data.config $plan.data.state
        if ($plan.scheduled) {
            $updatedRegistry = $plan.registry | ConvertTo-Json -Depth 40 | ConvertFrom-Json
            $entry = $updatedRegistry.projects | Where-Object { $_.projectId -ceq $plan.projectId }
            $entry.projectRoot = $plan.destination.Project
            $entry.lockRoots = @(@($plan.data.schedules.jobs.lockRoots) + @($plan.destination.Project, $plan.executionRoot) | Where-Object { $_ } | Sort-Object -Unique)
            Write-HarnessJson $plan.registryPath $updatedRegistry
            $registryWritten = $true
        }
        $oldConfig = $sourceConfig | ConvertFrom-Json
        $oldConfig.projectRoot = $plan.destination.Project
        Write-HarnessJson $Paths.Config $oldConfig
        Remove-Item -LiteralPath (Join-Path $plan.destination.Control 'move.pending.json') -Force
        $summary.status = 'Moved'
    }
    catch {
        $failure = $_
        try {
            foreach ($worktree in $repaired) { $null = Invoke-HarnessGit $worktree.repository @('worktree', 'repair', $worktree.source) }
            if ($registryWritten) { Write-HarnessJson $plan.registryPath $plan.registry }
            foreach ($view in $externalViews) {
                if ($null -ne $view.content) { [IO.File]::WriteAllBytes($view.path, [byte[]]$view.content) }
                elseif (Test-Path -LiteralPath $view.path) { Remove-Item -LiteralPath $view.path -Force }
            }
            if ($newPublished) { Remove-Item -LiteralPath $plan.destination.Control -Recurse -Force }
            elseif ($stage -and (Test-Path -LiteralPath $stage)) { Remove-Item -LiteralPath $stage -Recurse -Force }
            if (Test-Path -LiteralPath $sourceMarker) {
                [IO.File]::WriteAllText($Paths.Config, $sourceConfig, [Text.UTF8Encoding]::new($false))
                Remove-Item -LiteralPath $sourceMarker -Force
            }
        }
        catch { throw "Relocation recovery is incomplete. Preserve both locations. $($_.Exception.Message) Original error: $($failure.Exception.Message)" }
        throw $failure
    }
    finally {
        if ($decisionLock) { $decisionLock.Dispose() }
        if ($storeLock) { $storeLock.Dispose() }
        if ($runLock) { $runLock.Dispose() }
        if ($schedulerLock) { $schedulerLock.Dispose() }
    }
    $retiredSource = $Paths.Control
    try {
        $retiredSource = Join-Path (Split-Path -Parent $Paths.Control) ('.harness_sv.moved-' + [guid]::NewGuid().ToString('N'))
        [IO.Directory]::Move($Paths.Control, $retiredSource)
        $retiredDecisionLock = ConvertTo-HarnessMovedPath $plan.decisionLockPath $Paths ([pscustomobject]@{ Control = $retiredSource })
        $retainedFiles = @(Get-HarnessMoveFiles $retiredSource -Exclude $retiredDecisionLock | Where-Object { $_.relative -ne 'config.json' })
        $expectedFiles = @($plan.files | Where-Object { $_.relative -ne 'config.json' })
        if ($retainedFiles.Count -ne $expectedFiles.Count -or @(Compare-Object $expectedFiles $retainedFiles -Property relative, hash).Count) { throw 'Source files changed after publication; retain the blocked original for reconciliation.' }
        Remove-Item -LiteralPath $retiredSource -Recurse -Force -ErrorAction Stop
    }
    catch {
        $summary.status = 'MovedCleanupPending'
        $summary | Add-Member -NotePropertyName retainedPath -NotePropertyValue $(if (Test-Path -LiteralPath $retiredSource) { $retiredSource } else { $Paths.Control })
        $summary | Add-Member -NotePropertyName warning -NotePropertyValue 'The new controller is authoritative; inspect the retained blocked copy before removing it.'
    }
    $summary
}