$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness-store.ps1')
. (Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness-runner.ps1')
. (Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness-monitor.ps1')

function Assert-MonitorFailure {
    param([scriptblock]$Operation, [string]$Expected)
    $failed = $false
    try { & $Operation | Out-Null }
    catch { $failed = $true; if ($_.Exception.Message -notlike "*$Expected*") { throw } }
    if (-not $failed) { throw "Expected monitor failure: $Expected" }
}

$now = [datetimeoffset]'2026-09-15T12:00:00Z'
$definition = [pscustomobject]@{
    name = 'service-health'; resource = 'fixture-api'; environment = 'local'; metric = 'error-percent'
    windowMinutes = 5; maxAgeMinutes = 10; response = 'propose-task'
    condition = [pscustomobject]@{ operator = 'gt'; threshold = 2 }
}
$observation = [pscustomobject]@{
    resource = 'fixture-api'; environment = 'local'; metric = 'error-percent'; value = 5
    windowStart = '2026-09-15T11:55:00Z'; windowEnd = '2026-09-15T12:00:00Z'; observedAt = '2026-09-15T12:00:00Z'
}
$state = [pscustomobject]@{ tasks = @() }
$unhealthy = Get-HarnessMonitorHealth $definition $observation $now
if ($unhealthy.status -cne 'Succeeded' -or $unhealthy.health -cne 'Unhealthy') { throw 'An unhealthy observation was treated as failed monitoring.' }
$incident = Register-HarnessMonitorObservation $state $definition $unhealthy 'run-1' 'report-1.md'
$repeated = Register-HarnessMonitorObservation $state $definition $unhealthy 'run-2' 'report-2.md'
if ($incident.id -cne $repeated.id -or $state.monitoring.incidents.Count -ne 1 -or $state.tasks.Count -ne 0) { throw 'Repeated observations duplicated an incident or implicitly created tasks.' }
$observation.value = 0
$stale = Get-HarnessMonitorHealth $definition $observation $now.AddMinutes(11)
$null = Register-HarnessMonitorObservation $state $definition $stale 'run-3' 'report-3.md'
if ($stale.health -cne 'Unknown' -or $state.monitoring.incidents[0].status -cne 'Open') { throw 'Stale healthy data incorrectly recovered an incident.' }
$healthy = Get-HarnessMonitorHealth $definition $observation $now.AddMinutes(1)
$null = Register-HarnessMonitorObservation $state $definition $healthy 'run-4' 'report-4.md'
if ($healthy.health -cne 'Healthy' -or $state.monitoring.incidents[0].status -cne 'Recovered') { throw 'Fresh recovery was not recorded.' }
$observation.value = 5
$observation.windowStart = '2026-09-15T12:00:00Z'; $observation.windowEnd = '2026-09-15T12:05:00Z'; $observation.observedAt = '2026-09-15T12:05:00Z'
$recurrence = Get-HarnessMonitorHealth $definition $observation $now.AddMinutes(5)
$nextIncident = Register-HarnessMonitorObservation $state $definition $recurrence 'run-5' 'report-5.md'
if ($nextIncident.id -ceq $incident.id -or $state.monitoring.incidents.Count -ne 2) { throw 'A later breach reused an earlier recovered episode.' }
$observation.value = 0
$observation.windowStart = '2026-09-15T11:59:00Z'; $observation.windowEnd = '2026-09-15T12:04:00Z'; $observation.observedAt = '2026-09-15T12:04:00Z'
$older = Get-HarnessMonitorHealth $definition $observation $now.AddMinutes(5)
$null = Register-HarnessMonitorObservation $state $definition $older 'run-6' 'report-6.md'
if ($older.health -cne 'Unknown' -or $nextIncident.status -cne 'Open') { throw 'An older window falsely recovered a newer incident.' }
foreach ($invalid in @($null, '0', $true, [double]::NaN)) {
    $observation.value = $invalid
    if ((Get-HarnessMonitorHealth $definition $observation $now.AddMinutes(5)).health -cne 'Unknown') { throw 'Invalid observation value became a healthy reading.' }
}
$observation.value = 0; $observation.environment = 'other'
if ((Get-HarnessMonitorHealth $definition $observation $now.AddMinutes(5)).health -cne 'Unknown') { throw 'Data from a different environment was accepted.' }
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('harness-monitor-' + [guid]::NewGuid().ToString('N'))
$savedFixtureOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
$env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixtureRoot 'runtime-ownership'
try {
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    $paths = Get-HarnessPaths $fixtureRoot
    $view = Get-HarnessMonitorView $paths
    if ($view.initialized -or (Test-Path -LiteralPath $paths.Control)) { throw 'Monitor inspection initialized a project.' }
    $config = Initialize-Harness $paths
    $definition | Add-Member -NotePropertyName source -NotePropertyValue ([pscustomobject]@{ type = 'json-file'; path = 'observation.json' })
    $definition | Add-Member -NotePropertyName maxMinutes -NotePropertyValue 1
    $definitionFile = Join-Path $fixtureRoot 'monitors.json'
    Write-HarnessJson $definitionFile ([pscustomobject]@{ monitors = @($definition) })
    $beforeState = [IO.File]::ReadAllText($paths.State)
    $beforeConfig = [IO.File]::ReadAllText($paths.Config)
    $preview = Set-HarnessMonitorSettings $paths $definitionFile
    if (-not $preview.preview -or [IO.File]::ReadAllText($paths.State) -cne $beforeState -or [IO.File]::ReadAllText($paths.Config) -cne $beforeConfig) { throw 'Monitor declaration preview changed config or state.' }
    Assert-MonitorFailure { Set-HarnessMonitorSettings $paths $definitionFile -Apply } 'Actor and Reason'
    $null = Set-HarnessMonitorSettings $paths $definitionFile -Apply -Actor 'Fixture owner' -Reason 'Approve fixture only'
    $config = Read-HarnessConfig $paths
    if ((Get-HarnessMonitorDefinition $config SERVICE-HEALTH).name -cne 'service-health' -or (Read-HarnessState $paths).runs.Count -ne 0) { throw 'Declaring monitoring ran work or lost the selected definition.' }
    $null = Update-HarnessState -Paths $paths -SkipViews -Operation {
        param($saved)
        Register-HarnessMonitorObservation $saved $definition $unhealthy 'run-1' 'fixture-report.md'
    }
    $view = Get-HarnessMonitorView $paths
    if ($view.proposals.Count -ne 1 -or $view.proposals[0].autoEligible -or $view.proposals[0].kind -cne 'verify' -or (Read-HarnessState $paths).tasks.Count -ne 0) { throw 'A monitor proposal granted task execution or changed the task board.' }
    $beforeConfig = [IO.File]::ReadAllText($paths.Config)
    $definition.condition.threshold = 10
    Write-HarnessJson $definitionFile ([pscustomobject]@{ monitors = @($definition) })
    Assert-MonitorFailure { Set-HarnessMonitorSettings $paths $definitionFile -Apply -Actor Owner -Reason Change } 'new monitor name'
    if ([IO.File]::ReadAllText($paths.Config) -cne $beforeConfig) { throw 'A monitor update silently reinterpreted existing incident evidence.' }
    $definition.condition.threshold = 2
    $definition.response = 'create-task'
    Write-HarnessJson $definitionFile ([pscustomobject]@{ monitors = @($definition) })
    Assert-MonitorFailure { Set-HarnessMonitorSettings $paths $definitionFile -Apply -Actor Owner -Reason Change } 'never create tasks automatically'
    $null = Update-HarnessState -Paths $paths -SkipViews -Operation {
        param($saved)
        $saved.monitoring = [pscustomobject]@{ latest = @(); incidents = @() }
    }
    $config = Read-HarnessConfig $paths
    $config.runner.rulesPath = Join-Path $fixtureRoot 'rules.md'
    'Fixture rules: never access live systems.' | Set-Content -LiteralPath $config.runner.rulesPath
    $config | Add-Member -NotePropertyName fallback -NotePropertyValue ([pscustomobject]@{ failureThreshold = 1 })
    Write-HarnessJson $paths.Config $config
    $sampleTime = [datetimeoffset]::UtcNow.AddMinutes(-1)
    $observation.environment = 'local'; $observation.value = 5
    $observation.windowEnd = $sampleTime.ToString('o'); $observation.windowStart = $sampleTime.AddMinutes(-5).ToString('o'); $observation.observedAt = $sampleTime.ToString('o')
    Write-HarnessJson (Join-Path $fixtureRoot 'observation.json') $observation
    $dispatcher = Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness.ps1'
    $run = & $dispatcher -ProjectPath $fixtureRoot -Action Monitor -MonitorName service-health | ConvertFrom-Json
    if ($run.status -cne 'Succeeded' -or $run.health -cne 'Unhealthy' -or -not $run.proposal -or -not (Test-Path -LiteralPath $run.report)) { throw 'Public monitoring did not collect a real local JSON snapshot and propose an investigation.' }
    if ([IO.Path]::GetRelativePath($paths.Control, $run.report).StartsWith('..')) { throw 'Default monitor evidence was written outside .harness_sv.' }
    if (Get-HarnessPause $paths 'monitor:service-health') { throw 'An unhealthy service incorrectly paused its successful monitor.' }
    $beforeState = [IO.File]::ReadAllText($paths.State)
    $listing = & $dispatcher -ProjectPath $fixtureRoot -Action Monitor | ConvertFrom-Json
    $previewTask = & $dispatcher -ProjectPath $fixtureRoot -Action MonitorTask -Id $run.incident.id | ConvertFrom-Json
    if ($listing.proposals.Count -ne 1 -or -not $previewTask.preview -or [IO.File]::ReadAllText($paths.State) -cne $beforeState) { throw 'Monitor listing or task preview wrote state.' }
    $accepted = & $dispatcher -ProjectPath $fixtureRoot -Action MonitorTask -Id $run.incident.id -Apply -Actor Owner -Reason 'Investigate fixture only' | ConvertFrom-Json
    $again = & $dispatcher -ProjectPath $fixtureRoot -Action MonitorTask -Id $run.incident.id -Apply -Actor Owner -Reason 'Repeat acceptance' | ConvertFrom-Json
    if ($accepted.task.id -cne $again.task.id -or $accepted.task.autoEligible -or $accepted.task.risk -cne 'Unknown' -or $accepted.task.kind -cne 'verify' -or (Read-HarnessState $paths).tasks.Count -ne 1) { throw 'Accepting a proposal duplicated a task or granted execution.' }
    $sampleTime = [datetimeoffset]::UtcNow
    $observation.value = 0; $observation.windowEnd = $sampleTime.ToString('o'); $observation.windowStart = $sampleTime.AddMinutes(-5).ToString('o'); $observation.observedAt = $sampleTime.ToString('o')
    Write-HarnessJson (Join-Path $fixtureRoot 'observation.json') $observation
    $recovered = Invoke-HarnessMonitor $paths service-health
    if ($recovered.health -cne 'Healthy' -or $recovered.incident.status -cne 'Recovered' -or (Get-HarnessTask (Read-HarnessState $paths) $accepted.task.id).status -cne $accepted.task.status) { throw 'Monitor recovery failed or implicitly completed its linked task.' }
    $history = @(Import-Csv -LiteralPath (Join-Path $paths.Control 'history.csv'))
    if ($history[-1].phase -cne 'Monitor' -or $history[-1].health -cne 'Healthy' -or $history[-1].model) { throw 'Monitor history lost the health/collection distinction or claimed an AI model.' }
    ConvertTo-Json -InputObject @($observation) -Depth 10 | Set-Content -LiteralPath (Join-Path $fixtureRoot 'observation.json') -Encoding UTF8
    $tableReading = Invoke-HarnessMonitor $paths service-health
    if ($tableReading.status -cne 'Blocked' -or $tableReading.health -cne 'Unknown' -or $tableReading.result.reason -notlike '*one JSON object*') { throw 'A one-row JSON array was silently accepted as a metric object.' }
    Write-HarnessJson (Join-Path $fixtureRoot 'observation.json') $observation
    $configBeforeCheck = [IO.File]::ReadAllText($paths.Config)
    $deniedSchedule = Invoke-HarnessMonitor $paths service-health -Scheduled
    if ($deniedSchedule.status -cne 'Blocked' -or $deniedSchedule.health -cne 'Unknown' -or [IO.File]::ReadAllText($paths.Config) -cne $configBeforeCheck -or (Read-HarnessState $paths).active) { throw 'Unapproved scheduled monitoring ran or left active state.' }
    $config = Read-HarnessConfig $paths
    $config.monitoring.monitors[0] | Add-Member -NotePropertyName allowScheduled -NotePropertyValue $true
    Write-HarnessJson $paths.Config $config
    $observation.value = 5
    Write-HarnessJson (Join-Path $fixtureRoot 'observation.json') $observation
    $breachAgain = Invoke-HarnessMonitor $paths service-health -Scheduled
    if ($breachAgain.status -cne 'Succeeded' -or $breachAgain.health -cne 'Unhealthy' -or $breachAgain.incident.id -ceq $run.incident.id -or (Read-HarnessState $paths).tasks.Count -ne 1) { throw 'A new scheduled breach reused a recovered incident or created a task automatically.' }
    $readLock = Enter-HarnessLock $paths.RunLock
    try {
        $beforeState = [IO.File]::ReadAllText($paths.State)
        if ((Invoke-HarnessMonitor $paths service-health).status -cne 'Busy' -or [IO.File]::ReadAllText($paths.State) -cne $beforeState) { throw 'Monitor bypassed the shared runner lock or wrote state while busy.' }
    }
    finally { $readLock.Dispose() }
    $null = Set-HarnessPause $paths 'monitor:service-health' 'Fixture paused' Owner
    $beforeState = [IO.File]::ReadAllText($paths.State)
    if ((Invoke-HarnessMonitor $paths service-health -Scheduled).status -cne 'PolicyPaused' -or [IO.File]::ReadAllText($paths.State) -cne $beforeState) { throw 'A paused scheduled monitor executed or changed incident state.' }
    $null = Resume-HarnessTarget $paths 'monitor:service-health' -Actor Owner -Reason Checked -ConfirmStopped
    $observation.value = 0
    $observation.windowEnd = $sampleTime.AddMinutes(-20).ToString('o'); $observation.windowStart = $sampleTime.AddMinutes(-25).ToString('o'); $observation.observedAt = $sampleTime.ToString('o')
    Write-HarnessJson (Join-Path $fixtureRoot 'observation.json') $observation
    $staleReading = Invoke-HarnessMonitor $paths service-health
    if ($staleReading.health -cne 'Unknown' -or $staleReading.incident.status -cne 'Open') { throw 'Fresh export time hid stale data or recovered a breach.' }
    Assert-MonitorFailure { Add-HarnessMonitorTask -Paths $paths -IncidentId $breachAgain.incident.id -Apply -Actor Owner -Reason Investigate } 'fresh unhealthy evidence'
    'private fixture content that is not JSON' | Set-Content -LiteralPath (Join-Path $fixtureRoot 'observation.json')
    $invalidReading = Invoke-HarnessMonitor $paths service-health
    if ($invalidReading.status -cne 'Failed' -or $invalidReading.health -cne 'Unknown' -or $invalidReading.incident.status -cne 'Open' -or [IO.File]::ReadAllText($invalidReading.report) -match 'private fixture content' -or -not (Get-HarnessPause $paths 'monitor:service-health')) { throw 'A collection failure lost evidence state, leaked unparsed input, or failed to honor the failure threshold.' }
    $null = & $dispatcher -ProjectPath $fixtureRoot -Action Recover -ConfirmStopped
    if (-not (Get-HarnessPause $paths 'monitor:service-health')) { throw 'Recovery silently cleared a monitor safety pause.' }
    $null = Resume-HarnessTarget $paths 'monitor:service-health' -Actor Owner -Reason Checked -ConfirmStopped
    $observation.windowEnd = $sampleTime.ToString('o'); $observation.windowStart = $sampleTime.AddMinutes(-5).ToString('o'); $observation.observedAt = $sampleTime.ToString('o')
    Write-HarnessJson (Join-Path $fixtureRoot 'observation.json') $observation
    $config = Read-HarnessConfig $paths
    $config | Add-Member -NotePropertyName restrictions -NotePropertyValue ([pscustomobject]@{ testEnvironments = @('other') })
    Write-HarnessJson $paths.Config $config
    $restricted = Invoke-HarnessMonitor $paths service-health
    if ($restricted.status -cne 'Blocked' -or $restricted.health -cne 'Unknown' -or -not (Get-HarnessPause $paths project)) { throw 'Monitor collection bypassed the declared environment restriction.' }
    $null = Resume-HarnessTarget $paths project -Actor Owner -Reason Checked -ConfirmStopped
    $config.PSObject.Properties.Remove('restrictions')
    Write-HarnessJson $paths.Config $config
    function Invoke-HarnessProcess {
        param($Executable, $Arguments, $Directory, $MaxMinutes, $EnvironmentVariables, $Paths, $Config, $Targets)
        [pscustomobject]@{ ExitCode = 124; Output = ''; Error = 'Fixture timeout'; TimedOut = $true; Stopped = $false }
    }
    $timedOut = Invoke-HarnessMonitor $paths service-health
    if ($timedOut.status -cne 'Failed' -or $timedOut.health -cne 'Unknown' -or -not (Get-HarnessPause $paths 'monitor:service-health') -or $timedOut.incident.status -cne 'Open') { throw 'A monitor timeout lost its durable pause or recovered an open incident.' }
    $null = Resume-HarnessTarget $paths 'monitor:service-health' -Actor Owner -Reason Checked -ConfirmStopped
    $taskBeforeRecovery = Get-HarnessTask (Read-HarnessState $paths) $accepted.task.id | ConvertTo-Json -Depth 10
    $null = Update-HarnessState -Paths $paths -SkipViews -Operation {
        param($saved)
        $saved.active = [pscustomobject]@{ runId = 'interrupted-monitor'; taskId = ''; phase = 'Monitor'; ownerProcessId = 0; target = 'monitor:service-health' }
    }
    if ((Invoke-HarnessMonitor $paths service-health).status -cne 'NeedsRecovery') { throw 'Monitor bypassed an interrupted run.' }
    $null = & $dispatcher -ProjectPath $fixtureRoot -Action Recover -ConfirmStopped
    $saved = Read-HarnessState $paths
    if ($saved.active -or -not (Get-HarnessPause $paths 'monitor:service-health') -or (Get-HarnessTask $saved $accepted.task.id | ConvertTo-Json -Depth 10) -cne $taskBeforeRecovery) { throw 'Monitor recovery altered a task, failed to clear its marker, or cleared the safety pause.' }
}
finally {
    $env:SKILLVAULT_OWNERSHIP_ROOT = $savedFixtureOwnershipRoot
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Output 'Monitor checks passed: declarations, JSON collection, health/collection separation, freshness, episodes, explicit task intake, read-only views, scheduling approval, locks, pauses, and recovery. No live sources or schedules were used.'