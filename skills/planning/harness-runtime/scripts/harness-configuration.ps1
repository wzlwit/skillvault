function Get-HarnessConfigDomains {
    [ordered]@{ monitoring = 'monitors.json'; testing = 'tests.json'; policy = 'policy.json' }
}

function Read-HarnessConfigObject {
    param([string]$Path)
    $value = [IO.File]::ReadAllText($Path) | ConvertFrom-Json -NoEnumerate -ErrorAction Stop
    if ($value -isnot [pscustomobject]) { throw "Configuration must be a JSON object: $Path" }
    $value
}

function Get-HarnessConfigurationRevision {
    param($Paths)
    $directory = Split-Path -Parent $Paths.Config
    $values = @(foreach ($name in @('project.json', 'monitors.json', 'tests.json', 'policy.json')) {
        $path = Join-Path $directory $name
        if (Test-Path -LiteralPath $path) { $name + "`0" + [IO.File]::ReadAllText($path) } else { $name + "`0" }
    })
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes(($values -join "`0"))))).Replace('-', '') }
    finally { $hasher.Dispose() }
}

function Read-HarnessDeclarativeConfig {
    param($Paths)
    $pending = Join-Path $Paths.Control 'runtime/config.pending.json'
    if (Test-Path -LiteralPath $pending) { throw 'Configuration update is incomplete; inspect runtime/config.pending.json before continuing.' }
    $revision = Get-HarnessConfigurationRevision $Paths
    $config = Read-HarnessConfigObject $Paths.Config
    if ($config.layoutVersion -ne 2) { throw 'Unsupported declarative configuration layout.' }
    foreach ($field in @('monitoring', 'testing', 'restrictions', 'fallback', 'maintenance', '_configurationRevision')) {
        if ($config.PSObject.Properties[$field]) { throw "Configuration field $field belongs in its domain file, not project.json." }
    }
    $directory = Split-Path -Parent $Paths.Config
    foreach ($domain in @('monitoring', 'testing')) {
        $path = Join-Path $directory (Get-HarnessConfigDomains)[$domain]
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required configuration declaration is missing: $path" }
        $value = Read-HarnessConfigObject $path
        $config | Add-Member -NotePropertyName $domain -NotePropertyValue $value
    }
    $policyPath = Join-Path $directory 'policy.json'
    if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) { throw "Required configuration declaration is missing: $policyPath" }
    if (Test-Path -LiteralPath $policyPath) {
        $policy = Read-HarnessConfigObject $policyPath
        foreach ($property in $policy.PSObject.Properties) {
            if ($property.Name -cnotin @('restrictions', 'fallback', 'maintenance')) { throw "Unknown policy section: $($property.Name)" }
            $config | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
        }
    }
    if ($config.monitoring.monitors -isnot [array] -or $config.testing.environments -isnot [array] -or
        $config.testing.flows -isnot [array] -or $config.testing.afterDev -isnot [array]) { throw 'Monitor and test declarations require their documented arrays.' }
    foreach ($validator in @(
        @{ command = 'Assert-HarnessTestSettings'; file = 'harness-tests.ps1' }
        @{ command = 'Assert-HarnessMonitorSettings'; file = 'harness-monitor.ps1' }
        @{ command = 'Get-HarnessMaintenancePolicy'; file = 'harness-maintenance.ps1' }
    )) {
        if (-not (Get-Command $validator.command -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot $validator.file) }
    }
    Assert-HarnessMonitorSettings $config.monitoring -AllowUnscopedDiscovery
    Assert-HarnessTestSettings $config.testing
    foreach ($section in @('restrictions', 'fallback')) {
        if ($null -ne $config.$section) { Assert-HarnessPolicyDefinition $section $config.$section }
    }
    $null = Get-HarnessMaintenancePolicy $config
    if ((Test-Path -LiteralPath $pending) -or (Get-HarnessConfigurationRevision $Paths) -cne $revision) { throw 'Configuration changed during the read; retry against one stable declaration set.' }
    $config | Add-Member -NotePropertyName _configurationRevision -NotePropertyValue $revision
    $config
}

function Write-HarnessConfig {
    param($Paths, $Config)
    if ($Paths.LayoutVersion -ne 2) { Write-HarnessJson $Paths.Config $Config; return }
    $directory = Split-Path -Parent $Paths.Config
    if ($Config._configurationRevision -and $Config._configurationRevision -cne (Get-HarnessConfigurationRevision $Paths)) { throw 'Configuration declarations changed; reload before applying the command.' }
    $project = $Config | ConvertTo-Json -Depth 30 | ConvertFrom-Json -NoEnumerate
    $project.PSObject.Properties.Remove('_configurationRevision')
    $project | Add-Member -NotePropertyName layoutVersion -NotePropertyValue 2 -Force
    $writes = [ordered]@{}
    foreach ($domain in @('monitoring', 'testing')) {
        if ($project.PSObject.Properties[$domain]) {
            $writes[(Get-HarnessConfigDomains)[$domain]] = $project.$domain
            $project.PSObject.Properties.Remove($domain)
        }
        else { $writes[(Get-HarnessConfigDomains)[$domain]] = $(if ($domain -eq 'monitoring') { [ordered]@{ monitors = @() } } else { [ordered]@{ environments = @(); flows = @(); afterDev = @() } }) }
    }
    $policy = [ordered]@{}
    foreach ($field in @('restrictions', 'fallback', 'maintenance')) {
        if ($project.PSObject.Properties[$field]) { $policy[$field] = $project.$field; $project.PSObject.Properties.Remove($field) }
    }
    $writes['policy.json'] = $policy
    $writes['project.json'] = $project
    $changed = @(foreach ($name in $writes.Keys) {
        $path = Join-Path $directory $name
        $next = $writes[$name] | ConvertTo-Json -Depth 30 -Compress
        $current = if (Test-Path -LiteralPath $path) { Read-HarnessConfigObject $path | ConvertTo-Json -Depth 30 -Compress } else { $null }
        if ($current -cne $next) { $name }
    })
    if (-not $changed.Count) { $Config | Add-Member -NotePropertyName _configurationRevision -NotePropertyValue (Get-HarnessConfigurationRevision $Paths) -Force; return }
    New-Item -ItemType Directory -Path $directory, (Join-Path $Paths.Control 'runtime') -Force | Out-Null
    $pending = Join-Path $Paths.Control 'runtime/config.pending.json'
    if (Test-Path -LiteralPath $pending) { throw 'Resolve the incomplete configuration update before writing.' }
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('harness-config-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temporary | Out-Null
    $originals = @{}
    $finished = $false
    try {
        foreach ($name in $changed) {
            $path = Join-Path $directory $name
            $originals[$name] = Test-Path -LiteralPath $path
            if ($originals[$name]) { Copy-Item -LiteralPath $path -Destination (Join-Path $temporary $name) }
        }
        Write-HarnessJson $pending ([ordered]@{ operation = 'configuration'; originals = $temporary; files = $originals })
        try {
            foreach ($name in $changed) { Write-HarnessJson (Join-Path $directory $name) $writes[$name] }
            $finished = $true
        }
        catch {
            foreach ($name in $changed) {
                $path = Join-Path $directory $name
                if ($originals[$name]) { Copy-Item -LiteralPath (Join-Path $temporary $name) -Destination $path -Force }
                elseif (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
            }
            $finished = $true
            throw
        }
    }
    finally {
        if ($finished) {
            Remove-Item -LiteralPath $pending -Force
            Remove-Item -LiteralPath $temporary -Recurse -Force
        }
        elseif (-not (Test-Path -LiteralPath $pending)) { Remove-Item -LiteralPath $temporary -Recurse -Force }
    }
    $Config | Add-Member -NotePropertyName _configurationRevision -NotePropertyValue (Get-HarnessConfigurationRevision $Paths) -Force
}

function Get-HarnessScheduleRuntimeFields {
    @('nextDue', 'active', 'lastResult', 'recoveryRequired', 'staleSince', 'refreshRetry', 'legacy')
}

function Read-HarnessProjectSchedules {
    param($Paths)
    if (Test-Path -LiteralPath (Join-Path $Paths.Control 'runtime/schedules.pending.json')) { throw 'Schedule update is incomplete; preserve runtime/schedules.pending.json for recovery.' }
    if (-not (Test-Path -LiteralPath $Paths.ScheduleConfig)) { return $null }
    $declaration = Read-HarnessConfigObject $Paths.ScheduleConfig
    if ($Paths.LayoutVersion -ne 2) { return $declaration }
    if ($declaration.schemaVersion -ne 1 -or $declaration.jobs -isnot [array]) { throw 'Invalid schedule declaration.' }
    if (-not (Test-Path -LiteralPath $Paths.ScheduleState -PathType Leaf)) { throw 'Schedule runtime state is missing; restore it before dispatching work.' }
    $runtime = Read-HarnessConfigObject $Paths.ScheduleState
    if ($runtime.schemaVersion -ne 1 -or $runtime.jobs -isnot [array]) { throw 'Invalid schedule runtime state.' }
    $runtimeFields = Get-HarnessScheduleRuntimeFields
    foreach ($job in $declaration.jobs) {
        if (@($job.PSObject.Properties.Name | Where-Object { $_ -in $runtimeFields }).Count) { throw 'Execution progress belongs in runtime/schedules.json, not the schedule declaration.' }
        $job.anchor = ([datetimeoffset]$job.anchor).ToUniversalTime().ToString('o')
        $saved = @($runtime.jobs | Where-Object id -CEQ $job.id)
        if ($saved.Count -gt 1) { throw 'Duplicate schedule runtime identity.' }
        $saved = $saved | Select-Object -First 1
        $cadence = $job | Select-Object interval, anchor, timeZoneId | ConvertTo-Json -Compress
        if (($saved.active -or $saved.recoveryRequired) -and $saved.invocation) {
            foreach ($property in $saved.invocation.PSObject.Properties) {
                if ($property.Name -ne 'enabled') { $job | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value -Force }
            }
            $job.anchor = ([datetimeoffset]$job.anchor).ToUniversalTime().ToString('o')
        }
        foreach ($field in $runtimeFields) { $job | Add-Member -NotePropertyName $field -NotePropertyValue $saved.$field -Force }
        $job.recoveryRequired = [bool]$job.recoveryRequired
        if ($job.recoveryRequired -or $job.staleSince) { $job.enabled = $false }
        if (-not $job.active -and -not $job.recoveryRequired -and $saved.cadence -and $saved.cadence -cne $cadence) {
            $after = if ($saved.lastDispatchedAt) { [datetimeoffset]$saved.lastDispatchedAt } else { [datetimeoffset]$job.anchor }
            $job.nextDue = (Get-HarnessNextDue $job.interval ([datetimeoffset]$job.anchor) $after $job.timeZoneId).ToString('o')
        }
        if (-not $job.nextDue) { $job.nextDue = $job.anchor }
        $job.nextDue = ([datetimeoffset]$job.nextDue).ToUniversalTime().ToString('o')
    }
    foreach ($saved in @($runtime.jobs | Where-Object { ($_.active -or $_.recoveryRequired) -and $_.id -cnotin @($declaration.jobs.id) })) {
        if (-not $saved.invocation) { throw 'An unregistered active schedule requires recovery.' }
        $job = $saved.invocation
        foreach ($field in $runtimeFields) { $job | Add-Member -NotePropertyName $field -NotePropertyValue $saved.$field -Force }
        $job.enabled = $false
        $declaration.jobs += $job
    }
    $declaration
}

function Write-HarnessProjectSchedules {
    param($Paths, $Value, [switch]$RuntimeOnly, [string[]]$ChangedJobIds)
    if ($Paths.LayoutVersion -ne 2) { Write-HarnessJson $Paths.ScheduleConfig $Value; return }
    $declaration = $Value | ConvertTo-Json -Depth 30 | ConvertFrom-Json -NoEnumerate
    $previous = if (Test-Path -LiteralPath $Paths.ScheduleState) { Read-HarnessConfigObject $Paths.ScheduleState } else { [pscustomobject]@{ jobs = @() } }
    $progress = @(
        foreach ($job in $declaration.jobs) {
            $job.anchor = ([datetimeoffset]$job.anchor).ToUniversalTime().ToString('o')
            $old = $previous.jobs | Where-Object id -CEQ $job.id | Select-Object -First 1
            $entry = [ordered]@{ id = $job.id; cadence = ($job | Select-Object interval, anchor, timeZoneId | ConvertTo-Json -Compress); lastDispatchedAt = $old.lastDispatchedAt }
            foreach ($field in (Get-HarnessScheduleRuntimeFields)) {
                $entry[$field] = $job.$field
                $job.PSObject.Properties.Remove($field)
            }
            if ($entry.active -or $entry.recoveryRequired) {
                $entry.invocation = $job | ConvertTo-Json -Depth 30 | ConvertFrom-Json -NoEnumerate
                if ($entry.active.claimedAt) { $entry.lastDispatchedAt = $entry.active.claimedAt }
            }
            [pscustomobject]$entry
        }
    )
    $writes = [ordered]@{ $Paths.ScheduleState = [pscustomobject]@{ schemaVersion = 1; jobs = $progress } }
    if (-not $RuntimeOnly -and $null -ne $ChangedJobIds -and (Test-Path -LiteralPath $Paths.ScheduleConfig)) {
        $savedDeclaration = Read-HarnessConfigObject $Paths.ScheduleConfig
        $declaration.jobs = @($savedDeclaration.jobs | Where-Object { $_.id -cnotin $ChangedJobIds }) + @($declaration.jobs | Where-Object { $_.id -cin $ChangedJobIds })
    }
    if (-not $RuntimeOnly) { $writes[$Paths.ScheduleConfig] = $declaration }
    $pending = Join-Path $Paths.Control 'runtime/schedules.pending.json'
    if (Test-Path -LiteralPath $pending) { throw 'Recover the incomplete schedule update before writing.' }
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('harness-schedules-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temporary -Force | Out-Null
    $originals = @()
    $finished = $false
    try {
        foreach ($path in $writes.Keys) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
            $backup = Join-Path $temporary ([string]$originals.Count)
            $exists = Test-Path -LiteralPath $path
            if ($exists) { Copy-Item -LiteralPath $path -Destination $backup }
            $originals += [pscustomobject]@{ path = $path; original = $backup; existed = $exists }
        }
        Write-HarnessJson $pending ([pscustomobject]@{ operation = 'schedules'; originals = $originals })
        try {
            foreach ($path in $writes.Keys) {
                $current = if (Test-Path -LiteralPath $path) { Read-HarnessConfigObject $path | ConvertTo-Json -Depth 30 -Compress } else { '' }
                if ($current -cne ($writes[$path] | ConvertTo-Json -Depth 30 -Compress)) { Write-HarnessJson $path $writes[$path] }
            }
            $finished = $true
        }
        catch {
            foreach ($original in $originals) {
                if ($original.existed) { Copy-Item -LiteralPath $original.original -Destination $original.path -Force }
                elseif (Test-Path -LiteralPath $original.path) { Remove-Item -LiteralPath $original.path -Force }
            }
            $finished = $true
            throw
        }
    }
    finally {
        if ($finished) { Remove-Item -LiteralPath $pending -Force; Remove-Item -LiteralPath $temporary -Recurse -Force }
        elseif (-not (Test-Path -LiteralPath $pending)) { Remove-Item -LiteralPath $temporary -Recurse -Force }
    }
}