. (Join-Path $PSScriptRoot 'harness-discovery.ps1')
. (Join-Path $PSScriptRoot 'harness-verification.ps1')

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

function Assert-HarnessDiscoveryMonitor {
    param($Definition, [switch]$AllowUnscoped)
    $fields = @('name', 'kind', 'source', 'topics', 'scope', 'environment', 'maxAgeMinutes', 'maxMinutes', 'response', 'allowScheduled', 'referenceId', 'verification')
    if (@($Definition.PSObject.Properties.Name | Where-Object { $_ -cnotin $fields }).Count) { throw 'Unsupported discovery monitor field.' }
    if ($Definition.source -isnot [pscustomobject]) { throw 'Discovery source must be an object.' }
    $sourceFields = switch ($Definition.source.type) {
        'folder' { @('type', 'path', 'include', 'exclude', 'granularity') }
        'ado' { @('type', 'url', 'tokenEnvironment') }
        'json-feed' { @('type', 'path') }
        default { throw 'Discovery source must be folder, ado, or json-feed for another approved adapter.' }
    }
    if (@($Definition.source.PSObject.Properties.Name | Where-Object { $_ -cnotin $sourceFields }).Count) { throw 'Unsupported discovery source field; never store credentials in monitor definitions.' }
    if ($Definition.source.granularity -and $Definition.source.granularity -cnotin @('document', 'section')) { throw 'Folder granularity must be document or section.' }
    if ($Definition.source.type -ceq 'ado') {
        if (-not $Definition.scope -and -not $AllowUnscoped) { throw 'ADO discovery requires an explicit service scope; broad topic labels alone are insufficient.' }
        $uri = $null
        if (-not [uri]::TryCreate([string]$Definition.source.url, [UriKind]::Absolute, [ref]$uri) -or
            $uri.Scheme -cne 'https' -or $uri.Host -ine 'dev.azure.com' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or -not $uri.IsDefaultPort) {
            throw 'ADO discovery requires a dev.azure.com HTTPS backlog or saved-query URL without credentials or query parameters.'
        }
        if ($Definition.source.tokenEnvironment -and $Definition.source.tokenEnvironment -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*$') { throw 'tokenEnvironment must be an environment variable name, never a token.' }
    }
    elseif ($Definition.source.path -isnot [string] -or [string]::IsNullOrWhiteSpace($Definition.source.path)) { throw 'Discovery file and folder sources require a path.' }
    foreach ($property in @('include', 'exclude')) {
        if ($null -ne $Definition.source.$property -and ($Definition.source.$property -isnot [array] -or
            @($Definition.source.$property | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count)) { throw "Discovery $property must be an array of non-empty patterns." }
    }
    if ($null -ne $Definition.topics -and ($Definition.topics -isnot [array] -or
        @($Definition.topics | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count)) { throw 'Discovery topics must be an array of non-empty literal terms.' }
    if ($null -ne $Definition.scope) {
        if ($Definition.scope -isnot [pscustomobject] -or $Definition.scope.description -isnot [string] -or
            [string]::IsNullOrWhiteSpace($Definition.scope.description) -or
            @($Definition.scope.PSObject.Properties.Name | Where-Object { $_ -cnotin @('description', 'terms', 'areaPaths', 'excludedCategories', 'priorityFloors') }).Count) { throw 'Discovery scope requires a service description and supported evidence filters.' }
        foreach ($field in @('terms', 'areaPaths', 'excludedCategories')) {
            if ($null -ne $Definition.scope.$field -and ($Definition.scope.$field -isnot [array] -or
                @($Definition.scope.$field | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count)) { throw "Scope $field must be an array of non-empty strings." }
        }
        if (-not $Definition.scope.terms.Count -and -not $Definition.scope.areaPaths.Count) { throw 'Discovery scope requires service-specific terms or verified area paths.' }
        if ($Definition.scope.priorityFloors) {
            if ($Definition.scope.priorityFloors -isnot [pscustomobject]) { throw 'Priority floors must map assessed category names to priorities.' }
            foreach ($rule in $Definition.scope.priorityFloors.PSObject.Properties) {
                if (($rule.Value -isnot [int] -and $rule.Value -isnot [long]) -or $rule.Value -lt 1 -or $rule.Value -gt 5) { throw 'Priority floors must be integers from 1 through 5.' }
            }
        }
    }
    foreach ($field in @('maxAgeMinutes', 'maxMinutes')) {
        if (-not (Test-HarnessMonitorNumber $Definition.$field) -or $Definition.$field -le 0) { throw "Discovery $field must be a positive finite number." }
        $null = [timespan]::FromMinutes([double]$Definition.$field)
    }
    if ('response' -cin $Definition.PSObject.Properties.Name -and $Definition.response -cnotin @('report-only', 'propose-task')) { throw 'Discovery checks propose work; they never create tasks automatically.' }
    if ('allowScheduled' -cin $Definition.PSObject.Properties.Name -and $Definition.allowScheduled -isnot [bool]) { throw 'Monitor allowScheduled must be boolean.' }
    if ('referenceId' -cin $Definition.PSObject.Properties.Name -and [string]::IsNullOrWhiteSpace([string]$Definition.referenceId)) { throw 'Monitor referenceId must identify an existing harness reference.' }
    if ($null -ne $Definition.verification) {
        if ($Definition.verification -isnot [pscustomobject] -or @($Definition.verification.PSObject.Properties.Name | Where-Object { $_ -cnotin @('enabled', 'repositoryRef', 'authority') }).Count) { throw 'Verification accepts enabled, an optional existing repositoryRef, and explicit repository authority; its AI model mode is auto.' }
        if ($Definition.verification.PSObject.Properties['enabled'] -and $Definition.verification.enabled -isnot [bool]) { throw 'Verification enabled must be boolean.' }
        if ($Definition.verification.PSObject.Properties['repositoryRef'] -and [string]::IsNullOrWhiteSpace([string]$Definition.verification.repositoryRef)) { throw 'Verification repositoryRef must identify a registered coding repository.' }
        if ($Definition.verification.authority) {
            $authority = $Definition.verification.authority
            if ($authority -isnot [pscustomobject] -or @($authority.PSObject.Properties.Name | Where-Object { $_ -cnotin @('remote', 'branch', 'credentialHelper') }).Count -or
                $authority.remote -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$' -or [string]::IsNullOrWhiteSpace([string]$authority.branch) -or
                ($authority.credentialHelper -and $authority.credentialHelper -cnotin @('none', 'manager', 'gh'))) { throw 'Repository authority requires an explicit remote and branch, with optional existing none/manager/gh credential helper.' }
        }
    }
}

function Assert-HarnessMonitorSettings {
    param($Settings, [switch]$AllowUnscopedDiscovery)
    if ($Settings -is [array] -or $Settings -isnot [pscustomobject] -or $Settings.monitors -isnot [array] -or
        @($Settings.PSObject.Properties.Name | Where-Object { $_ -cnotin @('monitors', 'correlations') }).Count -gt 0) { throw 'Monitor declarations contain monitors and optional explicit correlations.' }
    if ($null -ne $Settings.correlations -and $Settings.correlations -isnot [array]) { throw 'Correlations must be an array of named source relationships.' }
    $correlationNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($correlation in $Settings.correlations) {
        if ($correlation -isnot [pscustomobject] -or @($correlation.PSObject.Properties.Name | Where-Object { $_ -cnotin @('name', 'sources', 'authorities') }).Count) { throw 'A correlation accepts name, sources, and optional fact authorities.' }
        Assert-HarnessTestName $correlation.name
        if (-not $correlationNames.Add($correlation.name)) { throw 'Correlation names must be unique.' }
        $sources = @(ConvertTo-HarnessRelatedSources $correlation.sources)
        if ($sources.Count -lt 2 -or ($sources -join "`n") -cne ($correlation.sources -join "`n")) { throw 'A correlation requires at least two distinct canonical source URIs.' }
        if ($null -ne $correlation.authorities -and $correlation.authorities -isnot [pscustomobject]) { throw 'Fact authorities must map exact fact names to related source URIs.' }
        foreach ($authority in $correlation.authorities.PSObject.Properties) {
            if ($authority.Name -cnotmatch '^(acceptance|requirements|completion)(\.[a-z0-9-]+)*$' -or $authority.Value -isnot [string] -or $authority.Value -cnotin $sources) { throw 'Declare authority only for a substantive fact and a source in the relationship.' }
        }
    }
    $names = @{}
    foreach ($definition in $Settings.monitors) {
        if ($definition -isnot [pscustomobject]) { throw 'Each monitor must be a JSON object.' }
        if ($definition.kind -ceq 'discovery') {
            Assert-HarnessTestName $definition.name
            Assert-HarnessTestName $definition.environment
            if ($names.ContainsKey($definition.name)) { throw "Duplicate monitor: $($definition.name)" }
            $names[$definition.name] = $true
            Assert-HarnessDiscoveryMonitor $definition -AllowUnscoped:$AllowUnscopedDiscovery
            continue
        }
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
    Assert-HarnessMonitorSettings $settings -AllowUnscopedDiscovery
    $definitions = @($settings.monitors | Where-Object { $_.name -eq $Name })
    if ($definitions.Count -ne 1) { throw "Monitor not found exactly once: $Name" }
    $definitions[0]
}

function Get-HarnessMonitorContract {
    param($Definition)
    if ($Definition.kind -ceq 'discovery') {
        return ([ordered]@{ kind = 'discovery'; source = $Definition.source; topics = @($Definition.topics); scope = $Definition.scope; environment = $Definition.environment } | ConvertTo-Json -Depth 6 -Compress)
    }
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
            if ($null -ne $settings.correlations -or $null -ne $incoming.correlations) {
                $proposed | Add-Member -NotePropertyName correlations -NotePropertyValue (@($settings.correlations | Where-Object { $_.name -cnotin $incoming.correlations.name }) + @($incoming.correlations | Where-Object { $_ }))
            }
            Assert-HarnessMonitorSettings $proposed -AllowUnscopedDiscovery
            if (-not $Apply) { return [pscustomobject]@{ preview = $true; current = $settings; proposed = $proposed } }
            if ([string]::IsNullOrWhiteSpace($Actor) -or [string]::IsNullOrWhiteSpace($Reason)) { throw 'Applying monitor declarations requires a human Actor and Reason.' }
            $config | Add-Member -NotePropertyName monitoring -NotePropertyValue $proposed -Force
            $safety = Get-HarnessSafetyState $state
            Add-HarnessPolicyEvent $safety 'Declare' 'monitoring' $Reason $Actor
            $state | Add-Member -NotePropertyName safety -NotePropertyValue $safety -Force
            Write-HarnessConfig $Paths $config
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
    [pscustomobject]@{ latest = @(); incidents = @(); candidates = @() }
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

function Get-HarnessVerifiedMonitorSubset {
    param($Config, $MonitorState)
    $proposals = @(
        foreach ($candidate in $MonitorState.monitoring.candidates) {
            $correlation = Get-HarnessDiscoveryCorrelation $Config $MonitorState $candidate
            if (($correlation.correlated -and $correlation.ready -and $correlation.outcome -ceq 'open') -or
                (-not $correlation.correlated -and $candidate.verification.outcome -ceq 'open')) { Get-HarnessDiscoveryProposal $Config $candidate $MonitorState }
        }
        foreach ($incident in $MonitorState.monitoring.incidents) {
            $definition = $Config.monitoring.monitors | Where-Object name -CEQ $incident.monitor | Select-Object -First 1
            $latest = $MonitorState.monitoring.latest | Where-Object monitor -CEQ $incident.monitor | Select-Object -First 1
            if ($definition -and $latest.result.status -ceq 'Succeeded' -and $latest.result.health -ceq 'Unhealthy' -and $latest.result.windowEnd -and
                ([datetimeoffset]::UtcNow - [datetimeoffset]$latest.result.windowEnd).TotalMinutes -le $definition.maxAgeMinutes) { Get-HarnessMonitorProposal $Config $incident }
        }
    )
    $proposals | Sort-Object priority, candidateId, incidentId
}

function Get-HarnessMonitorView {
    param($Paths)
    if (-not (Test-Path -LiteralPath $Paths.Config -PathType Leaf)) {
        return [pscustomobject]@{ initialized = $false; monitors = @(); latest = @(); incidents = @(); candidates = @(); proposals = @(); verifiedSubset = @() }
    }
    $config = Read-HarnessConfig $Paths
    $state = Read-HarnessState $Paths
    $monitoring = Get-HarnessMonitoringState $state
    $discoveryProposals = @(foreach ($candidate in $monitoring.candidates) { Get-HarnessDiscoveryProposal $config $candidate $state })
    [pscustomobject]@{
        initialized = $true; monitors = @((Get-HarnessMonitorSettings $config).monitors)
        current = Get-HarnessCurrentPath $Paths $config
        latest = @($monitoring.latest); incidents = @($monitoring.incidents)
        candidates = @($monitoring.candidates | Where-Object { $_ })
        batch = $monitoring.batch
        verifiedSubset = @(Get-HarnessVerifiedMonitorSubset $config $state)
        assessments = @(foreach ($definition in (Get-HarnessMonitorSettings $config).monitors | Where-Object { $_.kind -ceq 'discovery' -and $_.scope }) {
            $latest = @($monitoring.latest | Where-Object monitor -CEQ $definition.name) | Select-Object -First 1
            [pscustomobject]@{ monitor = $definition.name; assessment = Get-HarnessDiscoveryAssessmentSummary $definition @($monitoring.candidates | Where-Object monitor -CEQ $definition.name) ([string]$latest.result.status) }
        })
        proposals = $(if ($monitoring.batch -and -not $monitoring.batch.complete) { @() } else { @(
            foreach ($incident in $monitoring.incidents) { Get-HarnessMonitorProposal $config $incident }
            $discoveryProposals | Sort-Object priority, candidateId
        ) })
    }
}

function Resolve-HarnessMonitorSource {
    param($Paths, $Config, $Definition, [switch]$Scheduled)
    if ($Scheduled -and $Definition.allowScheduled -ne $true) { throw 'Scheduled checks are not approved for this monitor.' }
    if ($Definition.kind -ceq 'discovery') {
        Assert-HarnessDiscoveryMonitor $Definition
        Assert-HarnessRestrictions -Config $Config -ProjectRoot $Paths.Project -Workspace $Paths.Project -Executable pwsh -TestEnvironment $Definition.environment
        if ($Definition.source.type -ceq 'ado') { $null = Get-HarnessAdoSource $Definition.source.url }
        else {
            $path = [string]$Definition.source.path
            if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $Paths.Project $path }
            $null = Assert-HarnessDiscoveryPath $path $Config $Paths.Project
            if (-not (Test-Path -LiteralPath $path)) { throw 'The declared discovery source is unavailable.' }
        }
        return $Definition.source
    }
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
    param($Paths, [string]$Name, [switch]$Scheduled, $RunnerContext, [IO.FileStream]$HeldRunLock, $Configuration, [switch]$CollectOnly)
    $config = if ($Configuration) { $Configuration } else { Read-HarnessConfig $Paths }
    $definition = Get-HarnessMonitorDefinition $config $Name
    $target = 'monitor:' + $definition.name
    $pause = Get-HarnessPause $Paths $target
    if ($pause) { return [pscustomobject]@{ status = 'PolicyPaused'; health = 'Unknown'; target = $pause.target; reason = $pause.reason } }
    try {
        if ($HeldRunLock) {
            if (-not $HeldRunLock.CanWrite -or $HeldRunLock.Name -ine $Paths.RunLock) { throw 'The supplied monitor lock is not the selected controller run lock.' }
            $runLock = $HeldRunLock
        }
        else { $runLock = Enter-HarnessLock $Paths.RunLock }
    }
    catch { if ($_.Exception.Message -like '*Harness is busy*') { return [pscustomobject]@{ status = 'Busy'; health = 'Unknown'; reason = 'Another harness run owns the project; no observation collected.' } }; throw }
    $ownership = $null
    try {
        $config = Resolve-HarnessRunnerConfig $(if ($Configuration) { $Configuration } else { Read-HarnessConfig $Paths }) $RunnerContext
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
        $reportPath = Get-HarnessReportPath $Paths $config $runId Monitor
        $result = [pscustomobject]@{
            status = 'Blocked'; health = 'Unknown'; value = $null; reason = ''
            observedAt = ''; windowStart = ''; windowEnd = ''; checkedAt = [datetimeoffset]::UtcNow.ToString('o')
        }
        $run = [pscustomobject]@{
            id = $runId; taskId = ''; phase = 'Monitor'; status = 'Running'; startedAt = $result.checkedAt; finishedAt = ''
            model = ''; effort = ''; workspace = $Paths.Project; report = $reportPath; exitCode = ''
            monitor = $definition.name; environment = $definition.environment; health = 'Unknown'
        }
        $null = Update-HarnessState $Paths -Config $config -Operation {
            param($saved)
            $saved.runs = @($saved.runs) + @($run)
            $saved.active = [pscustomobject]@{ taskId = ''; runId = $runId; phase = 'Monitor'; ownerProcessId = $PID; target = $target; ownershipClaim = $ownership.id }
        }
        $failureKind = 'Blocked'
        $source = $null
        $collectorExit = $null
        $monitorClock = [Diagnostics.Stopwatch]::StartNew()
        try {
            $source = Resolve-HarnessMonitorSource $Paths $config $definition -Scheduled:$Scheduled
            Assert-HarnessTargetRunning $Paths @($target)
            $failureKind = 'Failure'
            $arguments = @('-NoProfile', '-NonInteractive', '-CommandWithArgs', '[Console]::Out.Write([System.IO.File]::ReadAllText($args[0]))', $source.path)
            if ($definition.kind -ceq 'discovery') {
                $limits = [pscustomobject]@{ restrictions = $config.restrictions; inheritedRestrictions = $config.inheritedRestrictions }
                $arguments = @('-NoProfile', '-NonInteractive', '-File', (Join-Path $PSScriptRoot 'harness-source-reader.ps1'), '-DefinitionJson', ($definition | ConvertTo-Json -Depth 10 -Compress), '-ProjectPath', $Paths.Project, '-RestrictionsJson', ($limits | ConvertTo-Json -Depth 15 -Compress))
            }
            $collector = Invoke-HarnessProcess -Executable pwsh -Arguments $arguments -Directory $Paths.Project -MaxMinutes $definition.maxMinutes -Paths $Paths -Config $config -Targets @($target)
            $collectorExit = $collector.ExitCode
            if ($collector.ExitCode -ne 0) {
                $result.status = 'Failed'
                $failureKind = if ($collector.Stopped) { 'Stopped' } elseif ($collector.TimedOut) { 'Budget' } else { 'Failure' }
                $result.reason = "Observation collection did not finish successfully (exit $collectorExit)."
            }
            else {
                $observation = $collector.Output | ConvertFrom-Json -NoEnumerate -ErrorAction Stop
                if ($definition.kind -ceq 'discovery') {
                    if ($observation.succeeded -eq $true) {
                        $result = Get-HarnessDiscoveryResult $definition $observation.observation
                        $failureKind = if ($result.status -eq 'Succeeded') { 'Success' } else { 'Blocked' }
                    }
                    else {
                        $result.reason = $observation.reason; $result.health = 'NotApplicable'
                        $failureKind = if ($observation.failureKind -in @('Restriction', 'Blocked')) { $observation.failureKind } else { 'Failure' }
                        $result.status = if ($failureKind -eq 'Failure') { 'Failed' } else { 'Blocked' }
                    }
                }
                else {
                    $result = Get-HarnessMonitorHealth $definition $observation
                    $failureKind = if ($result.status -eq 'Succeeded') { 'Success' } else { 'Blocked' }
                }
            }
        }
        catch {
            $kind = Get-HarnessFailureKind $_
            if ($kind -ne 'Failure') { $failureKind = $kind }
            $result.reason = if ($failureKind -eq 'Failure') { 'The observation could not be collected or parsed as JSON. Check the declared file and producer.' } else { $_.Exception.Message }
            $result.status = if ($failureKind -eq 'PolicyPaused') { 'PolicyPaused' } elseif ($failureKind -in @('Failure', 'Budget', 'Stopped', 'Interrupted')) { 'Failed' } else { 'Blocked' }
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $reportPath) -Force | Out-Null
        $savedResult = Update-HarnessState $Paths -Config $config -Operation {
            param($saved)
            $incident = $null; $candidates = @(); $proposal = $null; $assessment = $null
            if ($definition.kind -ceq 'discovery') {
                $candidates = @(Register-HarnessDiscoveryObservation $saved $definition $result $runId $reportPath)
                $proposal = @(@(foreach ($candidate in $candidates) { Get-HarnessDiscoveryProposal $config $candidate $saved }) | Sort-Object priority, candidateId)
                $assessment = Get-HarnessDiscoveryAssessmentSummary $definition $candidates $result.status
            }
            else {
                $incident = Register-HarnessMonitorObservation $saved $definition $result $runId $reportPath
                $proposal = if ($incident) { Get-HarnessMonitorProposal $config $incident } else { $null }
            }
            $reportData = [ordered]@{ monitor = $definition; source = $source; scheduled = [bool]$Scheduled; collectorExitCode = $collectorExit; observation = $result; incidentId = $incident.id; taskId = $incident.taskId; candidates = $candidates; assessment = $assessment; proposal = $proposal }
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
            [pscustomobject]@{ status = $result.status; health = $result.health; monitor = $definition.name; report = $reportPath; incident = $incident; candidates = $candidates; assessment = $assessment; proposal = $proposal; result = $result }
        }
        if ($definition.kind -ceq 'discovery' -and $result.status -ceq 'Succeeded') {
            $operationBudget = Get-HarnessExecutionLimit $config maxProcessMinutes $definition.maxMinutes
            if ($config.runner.maxMinutes) { $operationBudget = [Math]::Min($operationBudget, $config.runner.maxMinutes) }
            $remainingMinutes = [Math]::Max(0, $operationBudget - $monitorClock.Elapsed.TotalMinutes)
            if ($CollectOnly) { $savedResult | Add-Member -NotePropertyName verificationInput -NotePropertyValue ([pscustomobject]@{ remainingMinutes = $remainingMinutes; items = @($observation.observation.items); runId = $runId }) }
            else {
                $verification = Invoke-HarnessDiscoveryVerification $Paths $config $definition $runId $remainingMinutes -SourceItems @($observation.observation.items)
                $savedResult = Set-HarnessMonitorVerificationResult $Paths $config $definition $savedResult $verification
            }
        }
        $assessmentComplete = -not $savedResult.assessment -or $savedResult.assessment.status -in @('Assessed', 'NotRequired')
        $savedResult | Add-Member -NotePropertyName complete -NotePropertyValue ($savedResult.status -ceq 'Succeeded' -and $assessmentComplete -and (-not $savedResult.verification -or $savedResult.verification.status -in @('Verified', 'NoCandidates', 'Disabled'))) -Force
        $savedResult
    }
    catch {
        if ($_.Exception.Data['SkillOwnershipStatus']) { return [pscustomobject]@{ status = $_.Exception.Data['SkillOwnershipStatus']; health = 'Unknown'; owner = $_.Exception.Data['SkillOwnershipOwner']; reason = $_.Exception.Message } }
        throw
    }
    finally {
        try { Exit-HarnessOwnership $ownership $Paths }
        finally { if (-not $HeldRunLock) { $runLock.Dispose() } }
    }
}

function Set-HarnessMonitorVerificationResult {
    param($Paths, $Config, $Definition, $Result, $Verification)
    $Result | Add-Member -NotePropertyName verification -NotePropertyValue $Verification -Force
    $verifiedState = Read-HarnessState $Paths
    $Result.candidates = @($verifiedState.monitoring.candidates | Where-Object monitor -CEQ $Definition.name)
    $Result.assessment = Get-HarnessDiscoveryAssessmentSummary $Definition $Result.candidates
    $Result.proposal = @(@(foreach ($candidate in $Result.candidates) { Get-HarnessDiscoveryProposal $Config $candidate $verifiedState }) | Sort-Object priority, candidateId)
    $Result.status = if ($Verification.status -ceq 'NeedsRecovery') { 'NeedsRecovery' } elseif ($Verification.status -in @('Partial', 'Unverified')) { 'Partial' } else { $Result.result.status }
    $assessmentComplete = -not $Result.assessment -or $Result.assessment.status -in @('Assessed', 'NotRequired')
    $Result | Add-Member -NotePropertyName complete -NotePropertyValue ($Result.status -ceq 'Succeeded' -and $assessmentComplete -and $Verification.status -in @('Verified', 'NoCandidates', 'Disabled')) -Force
    $Result
}

function Invoke-HarnessMonitorBatch {
    param($Paths, [switch]$Scheduled, $RunnerContext)
    $config = Resolve-HarnessRunnerConfig (Read-HarnessConfig $Paths) $RunnerContext
    $definitions = @((Get-HarnessMonitorSettings $config).monitors)
    if (-not $definitions.Count) { return [pscustomobject]@{ status = 'NotConfigured'; complete = $false; sources = @(); proposals = @() } }
    try { $batchLock = Enter-HarnessLock $Paths.RunLock }
    catch { if ($_.Exception.Message -like '*Harness is busy*') { return [pscustomobject]@{ status = 'Busy'; complete = $false; sources = @(); proposals = @() } }; throw }
    $batchVerification = [pscustomobject]@{ runs = [Collections.Generic.List[object]]::new(); appliedTasks = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal) }
    try {
        if ((Read-HarnessState $Paths).active) { return [pscustomobject]@{ status = 'NeedsRecovery'; complete = $false; sources = @(); proposals = @() } }
        $batchId = [guid]::NewGuid().ToString('N')
        $startedAt = [datetimeoffset]::UtcNow
        $before = Read-HarnessState $Paths
        $batch = [pscustomobject]@{ id = $batchId; status = 'Running'; complete = $false; startedAt = $startedAt.ToString('o'); finishedAt = ''; selected = @($definitions.name); sources = @(); report = Get-HarnessReportPath $Paths $config $batchId MonitorBatch $startedAt }
        $null = Update-HarnessState $Paths -Config $config -Operation {
            param($saved)
            $monitoring = Get-HarnessMonitoringState $saved
            $monitoring | Add-Member -NotePropertyName batch -NotePropertyValue $batch -Force
            $saved | Add-Member -NotePropertyName monitoring -NotePropertyValue $monitoring -Force
        }
        $results = @(
            foreach ($definition in $definitions) {
                try {
                    $sourceResult = Invoke-HarnessMonitor $Paths $definition.name -Scheduled:$Scheduled -RunnerContext $RunnerContext -HeldRunLock $batchLock -Configuration $config -CollectOnly
                    $sourceResult | Add-Member -NotePropertyName monitor -NotePropertyValue $definition.name -Force
                    $sourceResult
                }
                catch { [pscustomobject]@{ monitor = $definition.name; status = 'Failed'; complete = $false; reason = $_.Exception.Message; proposal = @() } }
            }
        )
        $collectedSources = @($results | Where-Object verificationInput | ForEach-Object { [pscustomobject]@{ monitor = $_.monitor; items = $_.verificationInput.items } })
        foreach ($sourceResult in $results | Where-Object verificationInput) {
            $definition = $definitions | Where-Object name -CEQ $sourceResult.monitor | Select-Object -First 1
            try {
                $inputData = $sourceResult.verificationInput
                $verification = Invoke-HarnessDiscoveryVerification $Paths $config $definition $inputData.runId $inputData.remainingMinutes -SourceItems $inputData.items -CollectedSources $collectedSources -BatchVerification $batchVerification
                $null = Set-HarnessMonitorVerificationResult $Paths $config $definition $sourceResult $verification
            }
            catch { $sourceResult.status = 'Failed'; $sourceResult.complete = $false; $sourceResult | Add-Member -NotePropertyName reason -NotePropertyValue $_.Exception.Message -Force }
            finally { $sourceResult.PSObject.Properties.Remove('verificationInput') }
        }
        foreach ($verificationRun in $batchVerification.runs) {
            $sourceResult = $results | Where-Object monitor -CEQ $verificationRun.Definition.name | Select-Object -First 1
            $verification = Save-HarnessDiscoveryVerification $verificationRun
            $null = Set-HarnessMonitorVerificationResult $Paths $config $verificationRun.Definition $sourceResult $verification
        }
        $after = Read-HarnessState $Paths
        $sources = @(foreach ($definition in $definitions) {
            $result = $results | Where-Object monitor -CEQ $definition.name | Select-Object -First 1
            $candidates = @($after.monitoring.candidates | Where-Object monitor -CEQ $definition.name)
            $oldCandidates = @($before.monitoring.candidates | Where-Object monitor -CEQ $definition.name)
            $terminalTransitions = @(foreach ($outcome in @($result.verification.outcomes | Where-Object { $_.outcome -in @('already-fixed', 'stale') })) {
                $previousCandidate = $oldCandidates | Where-Object id -CEQ $outcome.candidateId | Select-Object -First 1
                $currentCandidate = $candidates | Where-Object id -CEQ $outcome.candidateId | Select-Object -First 1
                if ($outcome.reconciledTask -or $previousCandidate.completion.outcome -cne $outcome.outcome -or
                    $previousCandidate.completion.requirementFingerprint -cne $currentCandidate.completion.requirementFingerprint) { $outcome }
            })
            [pscustomobject]@{
                monitor = $definition.name; sourceType = Get-HarnessSourceType $definition; complete = [bool]$result.complete; status = [string]$result.status
                reason = $(if ($result.reason) { $result.reason } else { $result.result.reason }); report = $result.report; verification = $result.verification
                diagnostics = $result.result.diagnostics; candidates = $candidates.Count; added = @($candidates | Where-Object { $_.id -cnotin @($oldCandidates.id) }).Count
                updated = @($candidates | Where-Object { $_.id -cin @($oldCandidates.id) -and $_.lastRunId -cnotin @($oldCandidates.lastRunId) }).Count
                completed = @($terminalTransitions | Where-Object outcome -CEQ 'already-fixed').Count
                stale = @($terminalTransitions | Where-Object outcome -CEQ 'stale').Count
                retainedTerminal = @($result.verification.outcomes | Where-Object { $_.outcome -in @('already-fixed', 'stale') }).Count - $terminalTransitions.Count
                uncertain = @($candidates | Where-Object { $_.evidenceStatus -ceq 'Uncertain' -or $_.disposition -ceq 'Missing' -or $_.verification.outcome -ceq 'unverified' -or $_.assessment.relevance -ceq 'Uncertain' }).Count
                rejected = @($candidates | Where-Object { $_.assessment.relevance -ceq 'NotRelevant' -or $_.assessment.classification -in @('Informational', 'OutOfScope') -or ($_.isContainer -and -not $_.assessment.independentConcern) } | ForEach-Object { [pscustomobject]@{ id = $_.id; reason = $(if ($_.isContainer -and -not $_.assessment.independentConcern) { 'Container context; no separate actionable requirement.' } else { $_.assessment.reason }) } })
            }
        })
        $batch.sources = $sources
        $batch.complete = @($sources | Where-Object { -not $_.complete }).Count -eq 0
        $batch.status = if ($batch.complete) { 'Succeeded' } else { 'Partial' }
        $batch.finishedAt = [datetimeoffset]::UtcNow.ToString('o')
        $boardRows = @(Get-HarnessCurrentRows $config $after)
        $batch | Add-Member -NotePropertyName board -NotePropertyValue ([pscustomobject]@{ total = $boardRows.Count; bySource = @($boardRows | Group-Object sourceType | Select-Object Name, Count); byPriority = @($boardRows | Group-Object priority | Sort-Object Name | Select-Object Name, Count) })
        $null = Update-HarnessState $Paths -Config $config -Operation {
            param($saved)
            $saved.monitoring.batch = $batch
            New-Item -ItemType Directory -Path (Split-Path -Parent $batch.report) -Force | Out-Null
            [IO.File]::WriteAllText($batch.report, ("# Harness multi-source check`n`n" + ($batch | ConvertTo-Json -Depth 25) + "`n"), [Text.UTF8Encoding]::new($false))
            $saved.runs += [pscustomobject]@{ id = $batchId; phase = 'MonitorBatch'; status = $batch.status; startedAt = $batch.startedAt; finishedAt = $batch.finishedAt; report = $batch.report; taskId = ''; model = ''; effort = ''; exitCode = $(if ($batch.complete) { '0' } else { '1' }) }
        }
        [pscustomobject]@{
            status = $batch.status; complete = $batch.complete; sources = $sources; board = $batch.board; report = $batch.report
            proposals = $(if ($batch.complete) { @($results.proposal | Where-Object { $_ } | Sort-Object priority, candidateId) } else { @() })
            verifiedSubset = @(Get-HarnessVerifiedMonitorSubset $config $after)
        }
    }
    finally {
        foreach ($verificationRun in $batchVerification.runs) {
            foreach ($lease in $verificationRun.readLeases) { Exit-HarnessOwnership $lease $Paths }
            Exit-HarnessOwnership $verificationRun.ownership $Paths
            if (-not $verificationRun.interrupted) { foreach ($snapshot in $verificationRun.repositorySnapshots.Values) { if (Test-Path -LiteralPath $snapshot.root) { Remove-Item -LiteralPath $snapshot.root -Recurse -Force } } }
        }
        $batchLock.Dispose()
    }
}

function Add-HarnessMonitorTask {
    param($Paths, [string]$IncidentId, [switch]$Apply, [string]$Actor, [string]$Reason)
    $runLock = Enter-HarnessLock $Paths.RunLock
    try {
        $config = Read-HarnessConfig $Paths
        $state = Read-HarnessState $Paths
        if ($state.active) { throw 'Recover interrupted work before accepting a monitor task proposal.' }
        $candidate = @((Get-HarnessMonitoringState $state).candidates | Where-Object id -CEQ $IncidentId) | Select-Object -First 1
        if ($candidate) {
            $definition = Get-HarnessMonitorDefinition $config $candidate.monitor
            $latest = @((Get-HarnessMonitoringState $state).latest | Where-Object monitor -CEQ $candidate.monitor) | Select-Object -First 1
            if ($candidate.evidenceStatus -ceq 'Uncertain' -or $latest.result.status -cne 'Succeeded' -or
                ([datetimeoffset]::UtcNow - (ConvertTo-HarnessMonitorTime $latest.result.observedAt)).TotalMinutes -gt $definition.maxAgeMinutes) { throw 'Collect fresh complete discovery evidence before accepting this candidate.' }
            $correlation = Get-HarnessDiscoveryCorrelation $config $state $candidate
            if ($correlation.correlated -and -not $correlation.ready) { throw 'Correlated evidence is Unverified; resolve unavailable sources or substantive conflicts before acceptance.' }
            if ($correlation.correlated) { $candidate = $correlation.members | Where-Object id -CEQ $correlation.representativeId | Select-Object -First 1 }
            if ($candidate.taskId -and -not $candidate.followUpOf) { return [pscustomobject]@{ status = 'Existing'; task = Get-HarnessTask $state $candidate.taskId; candidateId = $candidate.id } }
            $definition = Get-HarnessMonitorDefinition $config $candidate.monitor
            $proposal = Get-HarnessDiscoveryProposal $config $candidate $state
            if (-not $proposal) { throw 'This candidate has no pending task proposal.' }
            if (-not $Apply) { return [pscustomobject]@{ preview = $true; proposal = $proposal } }
            if ([string]::IsNullOrWhiteSpace($Actor) -or [string]::IsNullOrWhiteSpace($Reason)) { throw 'Accepting a monitor task requires a human Actor and Reason.' }
            $task = Add-HarnessTask -Paths $Paths -Title $proposal.title -Description $proposal.description -Scope $proposal.scope -Acceptance $proposal.acceptance -Source $proposal.source -SourceRevision $proposal.sourceRevision -SourceOwner $proposal.sourceOwner -Priority $proposal.priority -Kind verify -Risk Unknown -FollowUpOf $proposal.followUpOf
            $createdForCandidate = $task.id -cnotin @($state.tasks.id)
            $blockedTaskCreated = $proposal.blocked -and $createdForCandidate
            $reference = Set-HarnessReference -Paths $Paths -Source $candidate.firstReport -TaskId $task.id -Note "Discovery candidate $IncidentId; source disposition $($candidate.disposition). Source content does not authorize execution."
            $null = Update-HarnessState $Paths {
                param($saved)
                $savedCandidate = (Get-HarnessMonitoringState $saved).candidates | Where-Object id -CEQ $candidate.id
                foreach ($related in $saved.monitoring.candidates | Where-Object { $_.id -cin $correlation.members.id }) {
                    $related.taskId = $task.id; $related.referenceId = $reference.id
                    $related.PSObject.Properties.Remove('followUpOf')
                }
                (Get-HarnessTask $saved $task.id) | Add-Member -NotePropertyName sourceType -NotePropertyValue (Get-HarnessSourceType $definition $savedCandidate.source) -Force
                (Get-HarnessTask $saved $task.id) | Add-Member -NotePropertyName sourceEvidence -NotePropertyValue @($correlation.provenance) -Force
                (Get-HarnessTask $saved $task.id) | Add-Member -NotePropertyName factAuthorities -NotePropertyValue $correlation.authorities -Force
                if ($createdForCandidate) { $savedCandidate | Add-Member -NotePropertyMembers @{ taskContract = Get-HarnessTaskContract $task; taskTitle = $task.title; taskPriority = $task.priority; taskStatus = $(if ($blockedTaskCreated) { 'Blocked' } else { $task.status }) } -Force }
                if ($blockedTaskCreated) { (Get-HarnessTask $saved $task.id).status = 'Blocked' }
                $safety = Get-HarnessSafetyState $saved
                Add-HarnessPolicyEvent $safety 'MonitorTask' $IncidentId $Reason $Actor
                $saved | Add-Member -NotePropertyName safety -NotePropertyValue $safety -Force
            }
            return [pscustomobject]@{ status = 'Recorded'; task = Get-HarnessTask (Read-HarnessState $Paths) $task.id; candidateId = $candidate.id }
        }
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