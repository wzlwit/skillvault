function Test-HarnessMonitorNumber {
    param($Value)
    ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) -and
        -not [double]::IsNaN([double]$Value) -and -not [double]::IsInfinity([double]$Value)
}

function Get-HarnessMonitorSettings {
    param($Config)
    if ($null -ne $Config.monitoring) { return $Config.monitoring }
    [pscustomobject]@{ monitors = @() }
}

function Assert-HarnessMonitorSettings {
    param($Settings)
    if ($Settings -is [array] -or $Settings -isnot [pscustomobject] -or $Settings.monitors -isnot [array] -or
        @($Settings.PSObject.Properties.Name | Where-Object { $_ -cne 'monitors' }).Count -gt 0) { throw 'Monitor declarations contain only a monitors array.' }
    $names = @{}
    foreach ($definition in $Settings.monitors) {
        if ($definition -isnot [pscustomobject]) { throw 'Each monitor must be a JSON object.' }
        $fields = @('name', 'source', 'resource', 'environment', 'metric', 'windowMinutes', 'maxAgeMinutes', 'maxMinutes', 'condition', 'response', 'allowScheduled', 'referenceId')
        if (@($definition.PSObject.Properties.Name | Where-Object { $_ -cnotin $fields }).Count -gt 0) { throw 'Unsupported monitor field; automatic intake and provider connectors are not configured by this schema.' }
        Assert-HarnessTestName $definition.name
        Assert-HarnessTestName $definition.environment
        if ($names.ContainsKey($definition.name)) { throw "Duplicate monitor: $($definition.name)" }
        $names[$definition.name] = $true
        foreach ($field in @('resource', 'metric')) {
            if ($definition.$field -isnot [string] -or [string]::IsNullOrWhiteSpace($definition.$field)) { throw "Monitor $field must be a non-empty string." }
        }
        if ($definition.source -isnot [pscustomobject] -or $definition.source.type -cne 'json-file' -or
            $definition.source.path -isnot [string] -or [string]::IsNullOrWhiteSpace($definition.source.path) -or
            @($definition.source.PSObject.Properties.Name | Where-Object { $_ -cnotin @('type', 'path') }).Count -gt 0) { throw 'Monitor source requires only type json-file and a non-empty path.' }
        foreach ($field in @('windowMinutes', 'maxAgeMinutes', 'maxMinutes')) {
            if (-not (Test-HarnessMonitorNumber $definition.$field) -or $definition.$field -le 0) { throw "Monitor $field must be a positive finite number." }
            $null = [timespan]::FromMinutes([double]$definition.$field)
        }
        if ($definition.condition -isnot [pscustomobject] -or $definition.condition.operator -cnotin @('gt', 'ge', 'lt', 'le', 'eq', 'ne') -or
            -not (Test-HarnessMonitorNumber $definition.condition.threshold) -or
            @($definition.condition.PSObject.Properties.Name | Where-Object { $_ -cnotin @('operator', 'threshold') }).Count -gt 0) { throw 'Monitor condition requires a supported operator and a finite numeric threshold.' }
        if ('response' -cin $definition.PSObject.Properties.Name -and $definition.response -cnotin @('report-only', 'propose-task')) { throw 'Monitor response must be report-only or propose-task; checks never create tasks automatically.' }
        if ('allowScheduled' -cin $definition.PSObject.Properties.Name -and $definition.allowScheduled -isnot [bool]) { throw 'Monitor allowScheduled must be boolean.' }
        if ('referenceId' -cin $definition.PSObject.Properties.Name -and ($definition.referenceId -isnot [string] -or [string]::IsNullOrWhiteSpace($definition.referenceId))) { throw 'Monitor referenceId must identify an existing harness reference.' }
    }
}

function Get-HarnessMonitorDefinition {
    param($Config, [string]$Name)
    $settings = Get-HarnessMonitorSettings $Config
    Assert-HarnessMonitorSettings $settings
    $definitions = @($settings.monitors | Where-Object { $_.name -eq $Name })
    if ($definitions.Count -ne 1) { throw "Monitor not found exactly once: $Name" }
    $definitions[0]
}

function Get-HarnessMonitorContract {
    param($Definition)
    [ordered]@{
        resource = $Definition.resource; environment = $Definition.environment; metric = $Definition.metric
        windowMinutes = $Definition.windowMinutes; operator = $Definition.condition.operator; threshold = $Definition.condition.threshold
    } | ConvertTo-Json -Compress
}

function Set-HarnessMonitorSettings {
    param($Paths, [string]$DefinitionPath, [switch]$Apply, [string]$Actor, [string]$Reason)
    if (-not [System.IO.Path]::IsPathRooted($DefinitionPath)) { $DefinitionPath = Join-Path $Paths.Project $DefinitionPath }
    $incoming = [System.IO.File]::ReadAllText($DefinitionPath) | ConvertFrom-Json -NoEnumerate
    Assert-HarnessMonitorSettings $incoming
    $runLock = Enter-HarnessLock $Paths.RunLock
    try {
        $lock = Enter-HarnessLock $Paths.Lock
        try {
            $config = Read-HarnessConfig $Paths
            $state = Read-HarnessState $Paths
            if ($state.active) { throw 'Recover interrupted work before changing monitor declarations.' }
            $settings = Get-HarnessMonitorSettings $config
            foreach ($definition in $incoming.monitors) {
                $existing = @($settings.monitors | Where-Object { $_.name -eq $definition.name }) | Select-Object -First 1
                $observed = @((Get-HarnessMonitoringState $state).latest | Where-Object { $_.monitor -eq $definition.name }).Count -gt 0
                if ($existing -and ($existing.name -cne $definition.name -or ($observed -and (Get-HarnessMonitorContract $existing) -cne (Get-HarnessMonitorContract $definition)))) {
                    throw 'Use a new monitor name to change an observed resource, environment, metric, window, or condition; prior incidents must retain their meaning.'
                }
                if ($definition.referenceId -and @($state.references | Where-Object { $_.id -ceq $definition.referenceId -and $_.active }).Count -ne 1) { throw 'Monitor referenceId must select an active existing harness reference.' }
            }
            $replaced = @($incoming.monitors | ForEach-Object { $_.name })
            $proposed = [pscustomobject]@{ monitors = @($settings.monitors | Where-Object { $_.name -notin $replaced }) + @($incoming.monitors) }
            Assert-HarnessMonitorSettings $proposed
            if (-not $Apply) { return [pscustomobject]@{ preview = $true; current = $settings; proposed = $proposed } }
            if ([string]::IsNullOrWhiteSpace($Actor) -or [string]::IsNullOrWhiteSpace($Reason)) { throw 'Applying monitor declarations requires a human Actor and Reason.' }
            $config | Add-Member -NotePropertyName monitoring -NotePropertyValue $proposed -Force
            $safety = Get-HarnessSafetyState $state
            Add-HarnessPolicyEvent $safety 'Declare' 'monitoring' $Reason $Actor
            $state | Add-Member -NotePropertyName safety -NotePropertyValue $safety -Force
            Write-HarnessJson $Paths.Config $config
            Write-HarnessJson $Paths.State $state
            $proposed
        }
        finally { $lock.Dispose() }
    }
    finally { $runLock.Dispose() }
}

function ConvertTo-HarnessMonitorTime {
    param($Value)
    if ($Value -is [datetimeoffset]) { return $Value }
    if ($Value -is [datetime] -and $Value.Kind -ne [DateTimeKind]::Unspecified) { return [datetimeoffset]$Value }
    $timestamp = [datetimeoffset]::MinValue
    if ($Value -isnot [string] -or $Value -notmatch '^\d{4}-\d{2}-\d{2}T.+(Z|[+-]\d{2}:\d{2})$' -or
        -not [datetimeoffset]::TryParse($Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$timestamp)) {
        throw 'Observation timestamps require ISO 8601 dates with an explicit timezone.'
    }
    $timestamp
}

function Get-HarnessMonitorHealth {
    param($Definition, $Observation, [datetimeoffset]$Now = [datetimeoffset]::UtcNow)
    $result = [pscustomobject]@{
        status = 'Blocked'; health = 'Unknown'; value = $null; reason = ''
        observedAt = ''; windowStart = ''; windowEnd = ''; checkedAt = $Now.ToString('o')
    }
    try {
        if ($Observation -is [array] -or $Observation -isnot [pscustomobject]) { throw 'An observation must be one JSON object, not an array or scalar.' }
        foreach ($field in @('resource', 'environment', 'metric')) {
            if ($Observation.$field -isnot [string] -or $Observation.$field -cne $Definition.$field) { throw "Observation $field does not match the monitor definition." }
        }
        if (-not (Test-HarnessMonitorNumber $Observation.value)) { throw 'Observation value must be a finite JSON number, not missing, null, or a numeric string.' }
        $observedAt = ConvertTo-HarnessMonitorTime $Observation.observedAt
        $windowStart = ConvertTo-HarnessMonitorTime $Observation.windowStart
        $windowEnd = ConvertTo-HarnessMonitorTime $Observation.windowEnd
        if ($windowStart -ge $windowEnd -or $windowEnd -gt $observedAt -or $observedAt -gt $Now) { throw 'Observation timestamps are unordered or in the future.' }
        if (($windowEnd - $windowStart).Ticks -ne [timespan]::FromMinutes([double]$Definition.windowMinutes).Ticks) { throw 'Observation window length does not match windowMinutes.' }
        if (($Now - $windowEnd).TotalMinutes -gt $Definition.maxAgeMinutes) { throw 'Observation window is stale; health cannot be determined.' }
        $value = [double]$Observation.value
        $threshold = [double]$Definition.condition.threshold
        $breached = switch ($Definition.condition.operator) {
            'gt' { $value -gt $threshold }
            'ge' { $value -ge $threshold }
            'lt' { $value -lt $threshold }
            'le' { $value -le $threshold }
            'eq' { $value -eq $threshold }
            'ne' { $value -ne $threshold }
            default { throw 'Unsupported monitor comparison operator.' }
        }
        $result.status = 'Succeeded'
        $result.health = if ($breached) { 'Unhealthy' } else { 'Healthy' }
        $result.value = $Observation.value
        $result.observedAt = $observedAt.ToString('o')
        $result.windowStart = $windowStart.ToString('o')
        $result.windowEnd = $windowEnd.ToString('o')
        $result.reason = if ($breached) { 'The declared breach condition is true.' } else { 'The declared breach condition is false.' }
    }
    catch { $result.reason = $_.Exception.Message }
    $result
}

function Get-HarnessMonitoringState {
    param($State)
    if ($null -ne $State.monitoring) { return $State.monitoring }
    [pscustomobject]@{ latest = @(); incidents = @() }
}

function Register-HarnessMonitorObservation {
    param($State, $Definition, $Result, [string]$RunId, [string]$ReportPath)
    $monitoring = Get-HarnessMonitoringState $State
    $previous = @($monitoring.latest | Where-Object { $_.monitor -ceq $Definition.name }) | Select-Object -First 1
    $lastWindowEnd = if ($previous.lastWindowEnd) { (ConvertTo-HarnessMonitorTime $previous.lastWindowEnd).ToString('o') } else { '' }
    if ($Result.health -ne 'Unknown' -and $lastWindowEnd -and (ConvertTo-HarnessMonitorTime $Result.windowEnd) -lt (ConvertTo-HarnessMonitorTime $lastWindowEnd)) {
        $Result.status = 'Blocked'; $Result.health = 'Unknown'; $Result.reason = 'Observation window predates the latest accepted window.'
    }
    if ($Result.health -ne 'Unknown') { $lastWindowEnd = $Result.windowEnd }
    $incident = @($monitoring.incidents | Where-Object { $_.monitor -ceq $Definition.name -and $_.status -eq 'Open' }) | Select-Object -First 1
    if ($Result.health -eq 'Unhealthy') {
        if (-not $incident) {
            $incident = [pscustomobject]@{
                id = Get-HarnessNextId @($monitoring.incidents) 'I'; monitor = $Definition.name
                resource = $Definition.resource; environment = $Definition.environment; metric = $Definition.metric
                condition = $Definition.condition; windowMinutes = $Definition.windowMinutes
                status = 'Open'; openedAt = $Result.observedAt; recoveredAt = ''; lastObservedAt = ''
                firstReport = $ReportPath; latestReport = ''; lastRunId = ''; taskId = ''; referenceId = ''
                response = $(if ($Definition.response) { $Definition.response } else { 'propose-task' })
            }
            $monitoring.incidents = @($monitoring.incidents) + @($incident)
        }
        $incident.lastObservedAt = $Result.observedAt
        $incident.latestReport = $ReportPath
        $incident.lastRunId = $RunId
        $incident.response = if ($Definition.response) { $Definition.response } else { 'propose-task' }
    }
    elseif ($Result.health -eq 'Healthy' -and $incident) {
        $incident.status = 'Recovered'; $incident.recoveredAt = $Result.observedAt
        $incident.lastObservedAt = $Result.observedAt; $incident.latestReport = $ReportPath; $incident.lastRunId = $RunId
    }
    $monitoring.latest = @($monitoring.latest | Where-Object { $_.monitor -cne $Definition.name }) + @([pscustomobject]@{
        monitor = $Definition.name; runId = $RunId; report = $ReportPath; result = $Result; lastWindowEnd = $lastWindowEnd
    })
    $State | Add-Member -NotePropertyName monitoring -NotePropertyValue $monitoring -Force
    $incident
}

function Get-HarnessMonitorProposal {
    param($Config, $Incident)
    if ($Incident.status -ne 'Open' -or $Incident.response -ne 'propose-task' -or $Incident.taskId) { return }
    $definition = @((Get-HarnessMonitorSettings $Config).monitors | Where-Object { $_.name -ceq $Incident.monitor }) | Select-Object -First 1
    if (-not $definition -or $definition.response -eq 'report-only') { return }
    [pscustomobject]@{
        incidentId = $Incident.id
        title = "Investigate $($Incident.monitor) for $($Incident.resource)"
        description = "Monitor $($Incident.monitor) detected $($Incident.metric) $($Incident.condition.operator) $($Incident.condition.threshold) in $($Incident.environment). Verify the evidence before deciding a cause or fix. Latest evidence: $($Incident.latestReport)"
        scope = "Monitor $($Incident.monitor): $($Incident.environment)/$($Incident.resource), $($Incident.metric)"
        acceptance = 'Establish the cause or explain the expected breach; record fresh observations and any required follow-up. Signal recovery alone is not proof of a fix.'
        source = "harness-monitor://$($Config.projectId)/$($Incident.id)"
        sourceRevision = $Incident.lastRunId
        kind = 'verify'; risk = 'Unknown'; autoEligible = $false
    }
}

function Get-HarnessMonitorView {
    param($Paths)
    if (-not (Test-Path -LiteralPath $Paths.Config -PathType Leaf)) {
        return [pscustomobject]@{ initialized = $false; monitors = @(); latest = @(); incidents = @(); proposals = @() }
    }
    $config = Read-HarnessConfig $Paths
    $state = Read-HarnessState $Paths
    $monitoring = Get-HarnessMonitoringState $state
    [pscustomobject]@{
        initialized = $true; monitors = @((Get-HarnessMonitorSettings $config).monitors)
        latest = @($monitoring.latest); incidents = @($monitoring.incidents)
        proposals = @(foreach ($incident in $monitoring.incidents) { Get-HarnessMonitorProposal $config $incident })
    }
}

function Resolve-HarnessMonitorSource {
    param($Paths, $Config, $Definition, [switch]$Scheduled)
    if ($Scheduled -and $Definition.allowScheduled -ne $true) { throw 'Scheduled checks are not approved for this monitor.' }
    $sourcePath = [string]$Definition.source.path
    if (-not [System.IO.Path]::IsPathRooted($sourcePath)) { $sourcePath = Join-Path $Paths.Project $sourcePath }
    $sourcePath = [System.IO.Path]::GetFullPath($sourcePath)
    Assert-HarnessRestrictions -Config $Config -ProjectRoot $Paths.Project -Workspace $Paths.Project -Executable pwsh -TestEnvironment $Definition.environment
    Assert-HarnessRestrictions -Config $Config -ProjectRoot $Paths.Project -Workspace (Split-Path -Parent $sourcePath)
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Monitor observation file is unavailable: $sourcePath" }
    $reference = $null
    if ($Definition.referenceId) {
        $reference = @((Read-HarnessState $Paths).references | Where-Object { $_.id -ceq $Definition.referenceId -and $_.active }) | Select-Object -First 1
        if (-not $reference) { throw 'The monitor supporting reference is no longer available.' }
    }
    [pscustomobject]@{ path = $sourcePath; reference = $reference }
}

function Invoke-HarnessMonitor {
    param($Paths, [string]$Name, [switch]$Scheduled, $RunnerContext)
    $config = Read-HarnessConfig $Paths
    $definition = Get-HarnessMonitorDefinition $config $Name
    $target = 'monitor:' + $definition.name
    $pause = Get-HarnessPause $Paths $target
    if ($pause) { return [pscustomobject]@{ status = 'PolicyPaused'; health = 'Unknown'; target = $pause.target; reason = $pause.reason } }
    try { $runLock = Enter-HarnessLock $Paths.RunLock }
    catch { if ($_.Exception.Message -like '*Harness is busy*') { return [pscustomobject]@{ status = 'Busy'; health = 'Unknown'; reason = 'Another harness run owns the project; no observation collected.' } }; throw }
    $ownership = $null
    try {
        $config = Resolve-HarnessRunnerConfig (Read-HarnessConfig $Paths) $RunnerContext
        $definition = Get-HarnessMonitorDefinition $config $Name
        Assert-HarnessTargetRunning $Paths @($target)
        $state = Read-HarnessState $Paths
        if ($state.active) {
            Save-HarnessPolicyOutcome $Paths $config (Get-HarnessActiveTarget $state) $state.active.runId Interrupted 'Previous runner ended without a confirmed outcome.'
            return [pscustomobject]@{ status = 'NeedsRecovery'; health = 'Unknown'; reason = 'Recover interrupted work before collecting monitor observations.' }
        }
        $ownership = Enter-HarnessOwnership -Paths $Paths -Role monitor
        $null = Get-HarnessRuleContext $Paths $config
        Assert-HarnessBoard $Paths $config
        $runId = [guid]::NewGuid().ToString('N')
        $reportPath = Join-Path (Get-HarnessBoard $Paths $config) "history/$runId.md"
        $result = [pscustomobject]@{
            status = 'Blocked'; health = 'Unknown'; value = $null; reason = ''
            observedAt = ''; windowStart = ''; windowEnd = ''; checkedAt = [datetimeoffset]::UtcNow.ToString('o')
        }
        $run = [pscustomobject]@{
            id = $runId; taskId = ''; phase = 'Monitor'; status = 'Running'; startedAt = $result.checkedAt; finishedAt = ''
            model = ''; effort = ''; workspace = $Paths.Project; report = $reportPath; exitCode = ''
            monitor = $definition.name; environment = $definition.environment; health = 'Unknown'
        }
        $null = Update-HarnessState $Paths {
            param($saved)
            $saved.runs = @($saved.runs) + @($run)
            $saved.active = [pscustomobject]@{ taskId = ''; runId = $runId; phase = 'Monitor'; ownerProcessId = $PID; target = $target; ownershipClaim = $ownership.id }
        }
        $failureKind = 'Blocked'
        $source = $null
        $collectorExit = $null
        try {
            $source = Resolve-HarnessMonitorSource $Paths $config $definition -Scheduled:$Scheduled
            Assert-HarnessTargetRunning $Paths @($target)
            $failureKind = 'Failure'
            $collector = Invoke-HarnessProcess -Executable pwsh -Arguments @('-NoProfile', '-NonInteractive', '-CommandWithArgs', '[Console]::Out.Write([System.IO.File]::ReadAllText($args[0]))', $source.path) -Directory $Paths.Project -MaxMinutes $definition.maxMinutes -Paths $Paths -Config $config -Targets @($target)
            $collectorExit = $collector.ExitCode
            if ($collector.ExitCode -ne 0) {
                $result.status = 'Failed'
                $failureKind = if ($collector.Stopped) { 'Stopped' } elseif ($collector.TimedOut) { 'Budget' } else { 'Failure' }
                $result.reason = "Observation collection did not finish successfully (exit $collectorExit)."
            }
            else {
                $observation = $collector.Output | ConvertFrom-Json -NoEnumerate -ErrorAction Stop
                $result = Get-HarnessMonitorHealth $definition $observation
                $failureKind = if ($result.status -eq 'Succeeded') { 'Success' } else { 'Blocked' }
            }
        }
        catch {
            $kind = Get-HarnessFailureKind $_
            if ($kind -ne 'Failure') { $failureKind = $kind }
            $result.reason = if ($failureKind -eq 'Failure') { 'The observation could not be collected or parsed as JSON. Check the declared file and producer.' } else { $_.Exception.Message }
            $result.status = if ($failureKind -eq 'PolicyPaused') { 'PolicyPaused' } elseif ($failureKind -in @('Failure', 'Budget', 'Stopped', 'Interrupted')) { 'Failed' } else { 'Blocked' }
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $reportPath) -Force | Out-Null
        $savedResult = Update-HarnessState $Paths {
            param($saved)
            $incident = Register-HarnessMonitorObservation $saved $definition $result $runId $reportPath
            $proposal = if ($incident) { Get-HarnessMonitorProposal $config $incident } else { $null }
            $reportData = [ordered]@{ monitor = $definition; source = $source; scheduled = [bool]$Scheduled; collectorExitCode = $collectorExit; observation = $result; incidentId = $incident.id; taskId = $incident.taskId; proposal = $proposal }
            $report = "# Harness monitor report`n`nHealth: $($result.health)`nExecution: $($result.status)`n`n" + ($reportData | ConvertTo-Json -Depth 15) + "`n"
            [System.IO.File]::WriteAllText($reportPath, $report, [System.Text.UTF8Encoding]::new($false))
            $savedRun = $saved.runs | Where-Object { $_.id -ceq $runId }
            $savedRun.status = $result.status; $savedRun.health = $result.health
            $savedRun.finishedAt = [datetimeoffset]::UtcNow.ToString('o')
            $savedRun.exitCode = if ($result.status -eq 'Succeeded') { '0' } else { '1' }
            if ($failureKind -ne 'Interrupted') { $saved.active = $null }
            if ($result.status -eq 'Blocked' -and $failureKind -eq 'Success') { $failureKind = 'Blocked' }
            if ($failureKind -ne 'PolicyPaused') { Register-HarnessPolicyOutcome $saved $config $target $runId $failureKind "Monitor $($definition.name): $($result.status). Report: $reportPath" }
            if ($incident.referenceId) {
                $reference = @($saved.references | Where-Object { $_.id -ceq $incident.referenceId -and $_.active }) | Select-Object -First 1
                if ($reference) {
                    $reference.note = "Incident $($incident.id); latest check $($result.health): $reportPath. Recovery does not complete the linked task."
                    $reference.updatedAt = [datetimeoffset]::UtcNow.ToString('o')
                }
            }
            [pscustomobject]@{ status = $result.status; health = $result.health; monitor = $definition.name; report = $reportPath; incident = $incident; proposal = $proposal; result = $result }
        }
        $savedResult
    }
    catch {
        if ($_.Exception.Data['SkillOwnershipStatus']) { return [pscustomobject]@{ status = $_.Exception.Data['SkillOwnershipStatus']; health = 'Unknown'; owner = $_.Exception.Data['SkillOwnershipOwner']; reason = $_.Exception.Message } }
        throw
    }
    finally {
        try { Exit-HarnessOwnership $ownership $Paths }
        finally { $runLock.Dispose() }
    }
}

function Add-HarnessMonitorTask {
    param($Paths, [string]$IncidentId, [switch]$Apply, [string]$Actor, [string]$Reason)
    $runLock = Enter-HarnessLock $Paths.RunLock
    try {
        $config = Read-HarnessConfig $Paths
        $state = Read-HarnessState $Paths
        if ($state.active) { throw 'Recover interrupted work before accepting a monitor task proposal.' }
        $incident = @((Get-HarnessMonitoringState $state).incidents | Where-Object { $_.id -ceq $IncidentId }) | Select-Object -First 1
        if (-not $incident) { throw 'Select an existing exact monitor incident ID.' }
        if ($incident.taskId) { return [pscustomobject]@{ status = 'Existing'; task = Get-HarnessTask $state $incident.taskId; incidentId = $IncidentId } }
        $proposal = Get-HarnessMonitorProposal $config $incident
        if (-not $proposal) { throw 'This incident has no pending task proposal.' }
        if (-not $Apply) { return [pscustomobject]@{ preview = $true; proposal = $proposal } }
        if ([string]::IsNullOrWhiteSpace($Actor) -or [string]::IsNullOrWhiteSpace($Reason)) { throw 'Accepting a monitor task requires a human Actor and Reason.' }
        $definition = Get-HarnessMonitorDefinition $config $incident.monitor
        $latest = @((Get-HarnessMonitoringState $state).latest | Where-Object { $_.monitor -ceq $incident.monitor }) | Select-Object -First 1
        if ($latest.result.health -ne 'Unhealthy' -or ([datetimeoffset]::UtcNow - (ConvertTo-HarnessMonitorTime $latest.result.windowEnd)).TotalMinutes -gt $definition.maxAgeMinutes) { throw 'Collect fresh unhealthy evidence before accepting this proposal.' }
        $task = Add-HarnessTask -Paths $Paths -Title $proposal.title -Description $proposal.description -Scope $proposal.scope -Acceptance $proposal.acceptance -Source $proposal.source -SourceRevision $proposal.sourceRevision -Kind verify -Risk Unknown
        $reference = Set-HarnessReference -Paths $Paths -Source $incident.firstReport -TaskId $task.id -Note "Monitor incident $IncidentId; latest evidence: $($incident.latestReport)."
        $null = Update-HarnessState $Paths {
            param($saved)
            $savedIncident = (Get-HarnessMonitoringState $saved).incidents | Where-Object { $_.id -ceq $IncidentId }
            $savedIncident.taskId = $task.id; $savedIncident.referenceId = $reference.id
            $safety = Get-HarnessSafetyState $saved
            Add-HarnessPolicyEvent $safety 'MonitorTask' $IncidentId $Reason $Actor
            $saved | Add-Member -NotePropertyName safety -NotePropertyValue $safety -Force
        }
        [pscustomobject]@{ status = 'Recorded'; task = $task; incidentId = $IncidentId }
    }
    finally { $runLock.Dispose() }
}