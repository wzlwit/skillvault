$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'The harness runtime requires PowerShell 7 or later.' }
. (Join-Path $PSScriptRoot 'harness-configuration.ps1')
. (Join-Path $PSScriptRoot 'harness-discovery.ps1')

function Get-HarnessPaths {
    param([Parameter(Mandatory = $true)][string]$ProjectPath, [ValidateSet(0, 1, 2)][int]$LayoutVersion = 0)
    $projectRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectPath)
    if (-not (Test-Path -LiteralPath $projectRoot -PathType Container)) { throw "Project directory not found: $projectRoot" }
    $controlRoot = Join-Path $projectRoot '.harness_sv'
    $legacyRoot = Join-Path $projectRoot '.harness'
    $legacyConfigPath = Join-Path $legacyRoot 'config.json'
    if (Test-Path -LiteralPath (Join-Path $legacyRoot 'config/project.json')) { $legacyConfigPath = Join-Path $legacyRoot 'config/project.json' }
    if (-not (Test-Path -LiteralPath $controlRoot) -and (Test-Path -LiteralPath $legacyConfigPath -PathType Leaf)) {
        $legacyConfig = $null
        try { $legacyConfig = Get-Content -LiteralPath $legacyConfigPath -Raw | ConvertFrom-Json }
        catch { $legacyConfig = $null }
        $legacyId = [guid]::Empty
        if ($legacyConfig.schemaVersion -eq 1 -and $legacyConfig.projectRoot -ieq $projectRoot -and
            [guid]::TryParse([string]$legacyConfig.projectId, [ref]$legacyId) -and $null -ne $legacyConfig.runner) {
            $controlRoot = $legacyRoot
        }
    }
    if (-not $LayoutVersion) {
        $LayoutVersion = if (Test-Path -LiteralPath (Join-Path $controlRoot 'config/project.json')) { 2 }
            elseif ((Test-Path -LiteralPath (Join-Path $controlRoot 'config.json')) -or (Test-Path -LiteralPath (Join-Path $controlRoot 'state.json'))) { 1 }
            else { 2 }
    }
    $runtimeRoot = if ($LayoutVersion -eq 2) { Join-Path $controlRoot 'runtime' } else { $controlRoot }
    $lockRoot = if ($LayoutVersion -eq 2) { Join-Path $runtimeRoot 'locks' } else { $runtimeRoot }
    [pscustomobject]@{
        Project = $projectRoot
        Control = $controlRoot
        LayoutVersion = $LayoutVersion
        Config = Join-Path $controlRoot $(if ($LayoutVersion -eq 2) { 'config/project.json' } else { 'config.json' })
        State = Join-Path $runtimeRoot 'state.json'
        Lock = Join-Path $lockRoot 'store.lock'
        RunLock = Join-Path $lockRoot 'runner.lock'
        ScheduleConfig = Join-Path $controlRoot $(if ($LayoutVersion -eq 2) { 'config/schedules.json' } else { 'schedules.json' })
        ScheduleState = Join-Path $runtimeRoot 'schedules.json'
        ScheduleLock = Join-Path $lockRoot 'schedules.lock'
    }
}

function Write-HarnessJson {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Value)
    $temporary = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [System.IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Depth 30), (New-Object System.Text.UTF8Encoding($false)))
        [System.IO.File]::Move($temporary, $Path, $true)
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Read-HarnessConfig {
    param([Parameter(Mandatory = $true)]$Paths)
    if (Test-Path -LiteralPath (Join-Path $Paths.Control 'move.pending.json')) { throw 'Harness relocation is incomplete. Inspect move.pending.json and preserve both locations before recovery.' }
    if (Test-Path -LiteralPath (Join-Path $Paths.Control 'migrate.pending.json')) { throw 'Harness layout migration is incomplete. Inspect migrate.pending.json and preserve its temporary originals before recovery.' }
    if (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $Paths.State) 'board-name.pending.json')) { throw 'Board filename update is incomplete. Preserve board-name.pending.json and its temporary originals for recovery.' }
    if ($Paths.LayoutVersion -eq 2 -and (Test-Path -LiteralPath (Join-Path $Paths.Control 'config.json'))) { throw 'Both legacy and declarative configurations exist. Resolve the interrupted layout transition before continuing.' }
    if (-not (Test-Path -LiteralPath $Paths.Config -PathType Leaf)) { throw 'Harness is not initialized. Run /hn-init for this project first.' }
    $config = if ($Paths.LayoutVersion -eq 2) { Read-HarnessDeclarativeConfig $Paths } else { Get-Content -LiteralPath $Paths.Config -Raw | ConvertFrom-Json }
    if ($config.schemaVersion -ne 1 -or $config.projectRoot -ine $Paths.Project) { throw 'Harness config version or project root does not match this project.' }
    $projectId = [guid]::Empty
    if (-not [guid]::TryParse([string]$config.projectId, [ref]$projectId)) { throw 'Harness config has an invalid projectId.' }
    $null = Get-HarnessCurrentFileName $config
    $config
}

function Get-HarnessExecutionRoot {
    param($Config)
    if ($Config.executionRoot) { return [string]$Config.executionRoot }
    [string]$Config.projectRoot
}

function Get-HarnessBoard {
    param([Parameter(Mandatory = $true)]$Paths, [Parameter(Mandatory = $true)]$Config)
    $board = [string]$Config.boardPath
    if ([string]::IsNullOrWhiteSpace($board)) { throw 'Harness boardPath is empty.' }
    if (-not [System.IO.Path]::IsPathRooted($board)) { $board = Join-Path $Paths.Project $board }
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($board)
}

function Get-HarnessCurrentFileName {
    param($Config)
    if (-not $Config.PSObject.Properties['currentFileName']) { return 'current.csv' }
    $name = $Config.currentFileName
    if ($name -isnot [string] -or $name.Length -gt 255 -or $name -cnotmatch '^current(?:-[a-z0-9]+(?:-[a-z0-9]+)*)?\.csv$') {
        throw 'currentFileName must be current.csv or a lowercase current-<project>.csv filename without directories.'
    }
    $name
}

function Get-HarnessCurrentPath {
    param($Paths, $Config)
    Join-Path (Get-HarnessBoard $Paths $Config) (Get-HarnessCurrentFileName $Config)
}

function Assert-HarnessMigrationPath {
    param([string]$Path)
    $current = $Path
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if ($item.LinkTarget -or $item.LinkType -in @('SymbolicLink', 'Junction')) { throw "Layout updates do not follow linked paths: $current" }
        }
        $current = Split-Path -Parent $current
    }
}

function ConvertTo-HarnessLayoutReference {
    param([string]$Value, $Paths, $Mappings)
    if (-not $Value) { return $Value }
    $sourceUri = $null
    if ($Value -match '^file:' -and [uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$sourceUri) -and $sourceUri.IsFile) {
        foreach ($mapping in $Mappings) {
            if ($sourceUri.LocalPath -ieq $mapping.source) { return ([uri]$mapping.destination).AbsoluteUri + $sourceUri.Query + $sourceUri.Fragment }
        }
    }
    $parts = $Value.Split('#', 2)
    foreach ($mapping in $Mappings) {
        $relative = [IO.Path]::GetRelativePath($Paths.Project, $mapping.source).Replace('\', '/')
        if ($parts[0] -ieq $mapping.source -or $parts[0].Replace('\', '/') -ieq $relative) {
            return $mapping.destination + $(if ($parts.Count -eq 2) { '#' + $parts[1] })
        }
    }
    $Value
}

function Update-HarnessLayoutReferences {
    param($Value, $Paths, $Mappings)
    if ($Value -is [array]) { foreach ($entry in $Value) { Update-HarnessLayoutReferences $entry $Paths $Mappings }; return }
    if ($Value -isnot [pscustomobject]) { return }
    foreach ($property in $Value.PSObject.Properties) {
        if ($property.Value -is [string] -and $property.Name -in @('report', 'firstReport', 'latestReport', 'engineReport', 'lastReport', 'source', 'reference', 'path')) {
            $property.Value = ConvertTo-HarnessLayoutReference $property.Value $Paths $Mappings
        }
        elseif ($property.Value -is [array] -or $property.Value -is [pscustomobject]) { Update-HarnessLayoutReferences $property.Value $Paths $Mappings }
    }
}

function Get-HarnessProjectSlug {
    param($Paths)
    $name = [IO.Path]::GetFileName([IO.Path]::TrimEndingDirectorySeparator($Paths.Project))
    $slug = ($name.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    if (-not $slug) { return 'project' }
    $slug.Substring(0, [Math]::Min(240, $slug.Length)).TrimEnd('-')
}

function Get-HarnessDefaultBoard {
    param($Paths)
    if ($Paths.LayoutVersion -eq 2 -and -not (Test-Path -LiteralPath (Join-Path $Paths.Control 'decisions.csv'))) { return Join-Path $Paths.Control 'board' }
    $Paths.Control
}

function Read-HarnessState {
    param([Parameter(Mandatory = $true)]$Paths)
    if (-not (Test-Path -LiteralPath $Paths.State -PathType Leaf)) { throw 'Harness state is missing; do not recreate it over an existing configuration.' }
    $state = Get-Content -LiteralPath $Paths.State -Raw | ConvertFrom-Json
    if ($state.schemaVersion -ne 1) { throw 'Unsupported harness state version.' }
    $state
}

function Get-HarnessHistoryRoot {
    param($Paths, $Config)
    $board = Get-HarnessBoard $Paths $Config
    if ($Paths.LayoutVersion -eq 2 -and $board -ieq (Join-Path $Paths.Control 'board')) { return Join-Path $Paths.Control 'history' }
    Join-Path $board 'history'
}

function Get-HarnessReportPath {
    param($Paths, $Config, [string]$RunId, [string]$Topic, [datetimeoffset]$StartedAt = [datetimeoffset]::UtcNow)
    if ($RunId -cnotmatch '^[A-Za-z0-9_-]+$') { throw 'Run report requires a safe run identity.' }
    $root = Get-HarnessHistoryRoot $Paths $Config
    if ($Paths.LayoutVersion -ne 2) { return Join-Path $root ($RunId + '.md') }
    $topicName = $Topic.ToLowerInvariant() -replace '[^a-z0-9-]', '-'
    if (-not $topicName) { $topicName = 'run' }
    $time = $StartedAt.ToUniversalTime()
    Join-Path (Join-Path $root $time.ToString('yyyy-MM')) ($time.ToString('yyyyMMddTHHmmssfffZ') + '-' + $topicName + '-' + $RunId + '.md')
}

function Write-HarnessNavigation {
    param($Paths, $Config)
    if ($Paths.LayoutVersion -ne 2) { return }
    $board = Get-HarnessBoard $Paths $Config
    $links = [ordered]@{
        'Current Tasks' = (Get-HarnessCurrentPath $Paths $Config)
        'References' = (Join-Path $board 'references.csv')
        'Run History' = (Join-Path $board 'history.csv')
        'Project Configuration' = $Paths.Config
        'Monitor Configuration' = (Join-Path $Paths.Control 'config/monitors.json')
        'Test Configuration' = (Join-Path $Paths.Control 'config/tests.json')
        'Policy Configuration' = (Join-Path $Paths.Control 'config/policy.json')
        'Schedule Configuration' = $Paths.ScheduleConfig
    }
    $baseUri = [uri]($Paths.Control.TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar)
    $lines = @('<!-- harness-navigation:start -->', '# Harness', '', 'Configuration files are authoritative. Board files are generated views; runtime state and locks are internal.', '')
    foreach ($label in $links.Keys) {
        if (Test-Path -LiteralPath $links[$label]) { $lines += '- [' + $label + '](' + $baseUri.MakeRelativeUri([uri]$links[$label]).ToString() + ')' }
    }
    $lines += @('', 'Monitor checks, development, and schedules run only through their configured workflows.', '<!-- harness-navigation:end -->')
    $section = $lines -join "`n"
    $path = Join-Path $Paths.Control 'README.md'
    $existing = if (Test-Path -LiteralPath $path) { [IO.File]::ReadAllText($path) } else { '' }
    $pattern = '(?s)<!-- harness-navigation:start -->.*?<!-- harness-navigation:end -->'
    $content = if ([regex]::IsMatch($existing, $pattern)) { [regex]::Replace($existing, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $section }) }
        elseif ($existing) { $existing.TrimEnd() + "`n`n" + $section + "`n" } else { $section + "`n" }
    if ($content -cne $existing) { [IO.File]::WriteAllText($path, $content, [Text.UTF8Encoding]::new($false)) }
}

function Enter-HarnessLock {
    param([Parameter(Mandatory = $true)][string]$Path)
    try { [System.IO.File]::Open($Path, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) }
    catch [System.IO.IOException] { throw 'Harness is busy. Retry after the current operation completes.' }
}

function Initialize-Harness {
    param([Parameter(Mandatory = $true)]$Paths, [string]$CurrentFileName)
    if (Test-Path -LiteralPath (Join-Path $Paths.Control 'migrate.pending.json')) { throw 'Recover the incomplete layout migration before initialization.' }
    if (Test-Path -LiteralPath $Paths.Config) {
        $config = Read-HarnessConfig $Paths
        if ($PSBoundParameters.ContainsKey('CurrentFileName') -and $CurrentFileName -cne (Get-HarnessCurrentFileName $config)) { throw 'Init does not rename an existing board. Use Board -CurrentFileName with preview and approved Apply.' }
        $null = Read-HarnessState $Paths
        return $config
    }
    if (Test-Path -LiteralPath $Paths.State) { throw 'Existing harness state has no config. Restore its configuration before initializing.' }
    New-Item -ItemType Directory -Path $Paths.Control -Force | Out-Null
    if ($Paths.LayoutVersion -eq 2) { New-Item -ItemType Directory -Path (Split-Path -Parent $Paths.Lock), (Split-Path -Parent $Paths.Config) -Force | Out-Null }
    $lock = Enter-HarnessLock $Paths.Lock
    try {
        if (Test-Path -LiteralPath $Paths.Config) { return Read-HarnessConfig $Paths }
        $config = [pscustomobject][ordered]@{
            schemaVersion = 1
            projectId = [guid]::NewGuid().ToString('N')
            projectRoot = $Paths.Project
            boardPath = [IO.Path]::GetRelativePath($Paths.Project, (Get-HarnessDefaultBoard $Paths))
            runner = [ordered]@{
                command = 'copilot'
                workspaceMode = $null
                model = $null
                reasoningEffort = $null
                maxMinutes = $null
                maxCredits = $null
                criticalReview = $null
                maxTasksPerCycle = $null
                allowedTools = $null
                availableTools = $null
                validationCommands = @()
                rulesPath = $null
            }
            testing = [ordered]@{ environments = @(); flows = @(); afterDev = @() }
        }
        $state = [ordered]@{
            schemaVersion = 1
            tasks = @()
            references = @()
            runs = @()
            active = $null
            nextQueue = @()
            nowQueue = @()
            resumeQueue = @()
        }
        if ($PSBoundParameters.ContainsKey('CurrentFileName')) { $config | Add-Member -NotePropertyName currentFileName -NotePropertyValue $CurrentFileName }
        elseif ($Paths.LayoutVersion -eq 2) { $config | Add-Member -NotePropertyName currentFileName -NotePropertyValue ('current-' + (Get-HarnessProjectSlug $Paths) + '.csv') }
        $null = Get-HarnessCurrentFileName $config
        Write-HarnessJson -Path $Paths.State -Value $state
        Write-HarnessConfig -Paths $Paths -Config $config
        if ($Paths.LayoutVersion -eq 2) { Write-HarnessViews $Paths $config $state }
        $config
    }
    finally { $lock.Dispose() }
}

function Write-HarnessCsv {
    param([string]$Path, [object[]]$Rows, [string[]]$Columns, [switch]$ValidateProjection)
    $lines = @($Rows | Select-Object -Property $Columns | ConvertTo-Csv -NoTypeInformation)
    if ($lines.Count -eq 0) { $lines = @(($Columns | ForEach-Object { '"' + $_ + '"' }) -join ',') }
    $content = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
    if ($ValidateProjection) {
        $projected = @($content | ConvertFrom-Csv)
        if ($projected.Count -ne $Rows.Count) { throw 'Board projection row count changed during serialization.' }
        $lastPriority = 0
        $identities = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($row in $projected) {
            if (-not $row.id -or -not $identities.Add($row.id) -or -not $row.sourceType -or -not $row.recordType -or
                [int]$row.priority -lt 1 -or [int]$row.priority -gt 5 -or [int]$row.priority -lt $lastPriority -or
                @($Columns | Where-Object { $_ -cnotin $row.PSObject.Properties.Name }).Count) { throw 'Board projection has invalid columns, source type, identity, or priority order.' }
            $lastPriority = [int]$row.priority
        }
        foreach ($group in @($Rows | Group-Object sourceType)) {
            if (@($projected | Where-Object sourceType -CEQ $group.Name).Count -ne $group.Count) { throw 'Board projection source counts changed during serialization.' }
        }
    }
    if ((Test-Path -LiteralPath $Path) -and [System.IO.File]::ReadAllText($Path) -ceq $content) { return }
    $temporary = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [System.IO.File]::WriteAllText($temporary, $content, (New-Object System.Text.UTF8Encoding($false)))
        [System.IO.File]::Move($temporary, $Path, $true)
    }
    finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
}

function Assert-HarnessBoard {
    param($Paths, $Config)
    $board = Get-HarnessBoard $Paths $Config
    $marker = Join-Path $board '.harness-board.json'
    if (Test-Path -LiteralPath $marker) {
        $owner = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
        if ($owner.projectId -cne $Config.projectId) { throw 'The selected board belongs to another harness project.' }
        $recordedName = Get-HarnessCurrentFileName $owner
        if ($recordedName -cne (Get-HarnessCurrentFileName $Config)) { throw 'The current filename differs from its published board. Use Board -CurrentFileName to apply the explicit rename.' }
    }
    else {
        foreach ($name in @((Get-HarnessCurrentFileName $Config), 'current.csv', 'history.csv', 'references.csv') | Select-Object -Unique) {
            if (Test-Path -LiteralPath (Join-Path $board $name)) { throw "Existing $name is not a harness-owned view. Choose another board location." }
        }
    }
}

function Write-HarnessViews {
    param($Paths, $Config, $State)
    Assert-HarnessBoard $Paths $Config
    $board = Get-HarnessBoard $Paths $Config
    New-Item -ItemType Directory -Path $board -Force | Out-Null
    $marker = Join-Path $board '.harness-board.json'
    if (-not (Test-Path -LiteralPath $marker)) { Write-HarnessJson $marker ([ordered]@{ projectId = $Config.projectId; currentFileName = Get-HarnessCurrentFileName $Config }) }
    $current = @(Get-HarnessCurrentRows $Config $State)
    Write-HarnessCsv (Get-HarnessCurrentPath $Paths $Config) $current (Get-HarnessCurrentColumns) -ValidateProjection
    Write-HarnessCsv (Join-Path $board 'history.csv') @($State.runs) @('id', 'taskId', 'phase', 'status', 'startedAt', 'finishedAt', 'model', 'effort', 'repositoryRef', 'repositoryRoot', 'workspace', 'report', 'exitCode', 'flow', 'environment', 'monitor', 'health')
    Write-HarnessCsv (Join-Path $board 'references.csv') @($State.references | Where-Object { $_.active }) @('id', 'source', 'note', 'taskId', 'updatedAt')
    Write-HarnessNavigation $Paths $Config
}

function Get-HarnessCurrentColumns {
    @('id', 'title', 'kind', 'priority', 'risk', 'autoEligible', 'status', 'phase', 'source', 'sourceType', 'sourceOwner', 'recordType', 'monitor', 'sourceState', 'evidenceStatus', 'sourceObservedAt', 'checkStatus', 'sourceEvidence', 'correlationStatus', 'conflicts', 'acceptance', 'repositoryRef', 'repositoryRoot', 'workspace', 'lastReport', 'followUpOf')
}

function Export-HarnessCurrentView {
    param($Paths, [string]$Topic, [string[]]$MonitorNames, [switch]$Apply, $RunnerContext)
    if ($Topic -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or -not $MonitorNames.Count) { throw 'A filtered view needs a lowercase topic slug and explicit monitor names.' }
    $runLock = $null
    $storeLock = $null
    $ownership = $null
    try {
        if ($Apply) { $runLock = Enter-HarnessLock $Paths.RunLock; $storeLock = Enter-HarnessLock $Paths.Lock }
        $config = Read-HarnessConfig $Paths
        $state = Read-HarnessState $Paths
        $selected = @($MonitorNames | Sort-Object -Unique)
        foreach ($name in $selected) {
            if (@($config.monitoring.monitors | Where-Object name -CEQ $name).Count -ne 1) { throw "Select an exact configured monitor for the filtered view: $name" }
        }
        $baseName = [IO.Path]::GetFileNameWithoutExtension((Get-HarnessCurrentFileName $config))
        if ($baseName -ceq 'current') { $baseName += '-' + (Get-HarnessProjectSlug $Paths) }
        $filename = "$baseName-$Topic.csv"
        $null = Get-HarnessCurrentFileName ([pscustomobject]@{ currentFileName = $filename })
        $directory = Join-Path $Paths.Control 'artifacts/board-views'
        $destination = Join-Path $directory $filename
        $registryPath = Join-Path $directory '.harness-views.json'
        Assert-HarnessMigrationPath $destination
        Assert-HarnessMigrationPath $registryPath
        $registry = if (Test-Path -LiteralPath $registryPath) { Read-HarnessConfigObject $registryPath } else { [pscustomobject]@{ projectId = $config.projectId; views = @() } }
        if ($registry.projectId -cne $config.projectId -or $registry.views -isnot [array]) { throw 'Filtered exports belong to another controller or have invalid ownership metadata.' }
        $existing = @($registry.views | Where-Object file -CEQ $filename)
        if ($existing.Count -gt 1 -or ((Test-Path -LiteralPath $destination) -and $existing.Count -ne 1)) { throw 'The export path is not an owned filtered view; it will not be overwritten.' }
        if ($existing.Count -and ($existing[0].topic -cne $Topic -or ($existing[0].monitors -join "`n") -cne ($selected -join "`n"))) { throw 'The filtered view name already has different filters; choose a distinct topic label.' }
        $rows = @(Get-HarnessCurrentRows $config $state | Where-Object { $_.monitor -cin $selected -or @($_.monitorNames | Where-Object { $_ -cin $selected }).Count })
        $result = [pscustomobject]@{ preview = -not $Apply; operation = 'ExportFilteredView'; topic = $Topic; monitors = $selected; rows = $rows.Count; path = $destination; canonical = Get-HarnessCurrentPath $Paths $config; snapshot = $true; generatedAt = [datetimeoffset]::UtcNow.ToString('o') }
        if (-not $Apply) { return $result }
        if ($state.active) { throw 'Finish or recover active work before publishing a filtered board snapshot.' }
        $effective = Resolve-HarnessRunnerConfig $config $RunnerContext
        Assert-HarnessRestrictions -Config $effective -ProjectRoot $Paths.Project -Workspace $directory
        $ownership = Enter-HarnessOwnership $Paths -Role board-export -Workspace $directory
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        $previousContent = if (Test-Path -LiteralPath $destination) { [IO.File]::ReadAllBytes($destination) } else { $null }
        try {
            Write-HarnessCsv $destination $rows (Get-HarnessCurrentColumns) -ValidateProjection
            $registry.views = @($registry.views | Where-Object file -CNE $filename) + @([pscustomobject]@{ file = $filename; topic = $Topic; monitors = $selected; generatedAt = $result.generatedAt; rows = $rows.Count })
            Write-HarnessJson $registryPath $registry
        }
        catch {
            if ($null -ne $previousContent) { [IO.File]::WriteAllBytes($destination, $previousContent) }
            elseif (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Force }
            throw
        }
        $result
    }
    finally {
        if ($ownership) { Exit-HarnessOwnership $ownership $Paths }
        if ($storeLock) { $storeLock.Dispose() }
        if ($runLock) { $runLock.Dispose() }
    }
}

function Get-HarnessCurrentRows {
    param($Config, $State)
    $terminal = @('Completed', 'Done', 'Cancelled', 'Unsupported', 'Stale', 'AlreadyFixed')
    $rows = @(
        foreach ($task in @($State.tasks | Where-Object { $_.status -notin $terminal })) {
            $candidate = @($State.monitoring.candidates | Where-Object { $_.taskId -ceq $task.id -and $_.source -ceq $task.source }) | Select-Object -First 1
            $correlation = if ($candidate) { Get-HarnessDiscoveryCorrelation $Config $State $candidate } else { $null }
            $definition = @($Config.monitoring.monitors | Where-Object name -CEQ $candidate.monitor) | Select-Object -First 1
            $latest = @($State.monitoring.latest | Where-Object monitor -CEQ $candidate.monitor) | Select-Object -First 1
            $row = $task | Select-Object *
            if ($null -eq $row.priority) { $row | Add-Member -NotePropertyName priority -NotePropertyValue 3 -Force }
            $sourceType = if ($task.sourceType) { $task.sourceType } else { Get-HarnessSourceType $definition $task.source }
            $fresh = $candidate -and $latest.result.status -ceq 'Succeeded' -and $candidate.disposition -cne 'Missing' -and $latest.result.observedAt -and
                ([datetimeoffset]::UtcNow - [datetimeoffset]$latest.result.observedAt).TotalMinutes -le $definition.maxAgeMinutes
            $row | Add-Member -NotePropertyMembers @{ sourceType = $sourceType; recordType = 'task'; monitor = [string]$candidate.monitor; sourceState = [string]$candidate.disposition; sourceObservedAt = [string]$candidate.lastSeenAt; evidenceStatus = $(if (-not $candidate) { 'NotMonitored' } elseif ($fresh) { 'Current' } else { 'Uncertain' }) } -Force
            if ($correlation.correlated) {
                $row | Add-Member -NotePropertyMembers @{ sourceEvidence = ConvertTo-Json -InputObject @($correlation.provenance) -Depth 15 -Compress; monitorNames = @($correlation.members.monitor); correlationStatus = $(if ($correlation.ready) { 'Current' } else { 'Unverified' }); conflicts = ConvertTo-Json -InputObject @($correlation.conflicts) -Depth 10 -Compress } -Force
                if (-not $correlation.ready) { $row.evidenceStatus = 'Uncertain' }
            }
            elseif ($row.sourceEvidence) { $row.sourceEvidence = ConvertTo-Json -InputObject @($row.sourceEvidence) -Depth 15 -Compress }
            $row
        }
        foreach ($candidate in @($State.monitoring.candidates | Where-Object { $_ -and (-not $_.taskId -or $_.followUpOf) })) {
            $correlation = Get-HarnessDiscoveryCorrelation $Config $State $candidate
            if ($correlation.correlated -and $candidate.id -cne $correlation.representativeId) { continue }
            $definition = @($Config.monitoring.monitors | Where-Object name -CEQ $candidate.monitor) | Select-Object -First 1
            if (-not $definition -or $definition.response -ceq 'report-only') { continue }
            $assessment = $candidate.assessment
            $currentAssessment = $assessment -and $assessment.sourceRevision -ceq $candidate.revision -and $assessment.scope -ceq $definition.scope.description
            if ($currentAssessment -and $assessment.relevance -ceq 'NotRelevant') { continue }
            if ($currentAssessment -and $assessment.classification -in @('Informational', 'OutOfScope')) { continue }
            if ($candidate.isContainer -and -not $assessment.independentConcern) { continue }
            $verification = $candidate.verification
            if ($correlation.correlated) {
                if ($correlation.ready -and $correlation.outcome -in @('already-fixed', 'stale')) { continue }
            }
            elseif ($verification.sourceRevision -ceq $candidate.revision -and $verification.outcome -in @('already-fixed', 'stale')) { continue }
            $latest = @($State.monitoring.latest | Where-Object monitor -CEQ $candidate.monitor) | Select-Object -First 1
            $fresh = $latest.result.status -ceq 'Succeeded' -and $candidate.disposition -cne 'Missing' -and $latest.result.observedAt -and
                ([datetimeoffset]::UtcNow - [datetimeoffset]$latest.result.observedAt).TotalMinutes -le $definition.maxAgeMinutes
            $relevant = -not $definition.scope -or ($currentAssessment -and $assessment.relevance -ceq 'Relevant')
            $verifiedOpen = $verification.outcome -ceq 'open' -and $verification.sourceRevision -ceq $candidate.revision -and $verification.collectionRunId -ceq $candidate.lastRunId
            $eligible = $fresh -and $relevant -and ($verifiedOpen -or $definition.verification.enabled -eq $false)
            if ($correlation.correlated) { $eligible = $fresh -and $relevant -and $correlation.ready -and ($correlation.outcome -ceq 'open' -or $definition.verification.enabled -eq $false) }
            if ($definition.verification.enabled -eq $false -and $candidate.disposition -in @('Resolved', 'Superseded')) { $eligible = $false }
            $priority = if ($currentAssessment -and $assessment.priority) { $assessment.priority } elseif ($candidate.priority) { $candidate.priority } else { 3 }
            [pscustomobject]@{
                id = $candidate.id; title = $candidate.title; kind = 'verify'; priority = $priority; risk = 'Unknown'; autoEligible = $false
                status = $(if (-not $eligible) { 'Uncertain' } elseif ($candidate.disposition -ceq 'Blocked' -or @($assessment.blockers | Where-Object { $_ }).Count) { 'Blocked' } else { 'Proposed' }); phase = 'Monitor'
                source = $candidate.source; sourceType = Get-HarnessSourceType $definition $candidate.source; sourceOwner = [string]$candidate.sourceOwner; recordType = 'candidate'
                monitor = $candidate.monitor; sourceState = $candidate.disposition; evidenceStatus = $(if ($eligible) { 'Current' } else { 'Uncertain' }); sourceObservedAt = $candidate.lastSeenAt
                acceptance = [string]$candidate.acceptance; lastReport = $(if ($verification.report) { $verification.report } else { $candidate.latestReport })
                followUpOf = [string]$candidate.followUpOf
                sourceEvidence = ConvertTo-Json -InputObject @($correlation.provenance) -Depth 15 -Compress
                monitorNames = @($correlation.members.monitor); correlationStatus = $(if (-not $correlation.correlated) { 'Independent' } elseif ($correlation.ready) { 'Current' } else { 'Unverified' })
                conflicts = ConvertTo-Json -InputObject @($correlation.conflicts) -Depth 10 -Compress
            }
        }
    )
    foreach ($row in $rows) {
        $row | Add-Member -NotePropertyName checkStatus -NotePropertyValue $(if ($State.monitoring.batch) { [string]$State.monitoring.batch.status } else { 'NotRequested' }) -Force
    }
    $rows | Sort-Object @{ Expression = { [int]$_.priority } }, id
}

function Get-HarnessSourceType {
    param($Definition, [string]$Source)
    if ($Definition.source.type -ceq 'folder') { return 'design' }
    if ($Definition.source.type -ceq 'ado') { return 'ado' }
    $uri = $null
    if ([uri]::TryCreate($Source, [UriKind]::Absolute, [ref]$uri) -and $uri.Host -ieq 'dev.azure.com') { return 'ado' }
    if ($Definition.source.type -ceq 'json-feed') { return 'feed' }
    if ($Definition -or $Source -like 'harness-monitor://*') { return 'health' }
    'manual'
}

function Update-HarnessState {
    param($Paths, [scriptblock]$Operation, [switch]$SkipViews, [Alias('Config')]$OperationConfig)
    $lock = Enter-HarnessLock $Paths.Lock
    try {
        foreach ($transitionMarkerName in @('move.pending.json', 'migrate.pending.json')) {
            if (Test-Path -LiteralPath (Join-Path $Paths.Control $transitionMarkerName)) { throw 'Recover the incomplete harness move or migration before updating state.' }
        }
        if (-not $SkipViews -and -not $OperationConfig) { $OperationConfig = Read-HarnessConfig $Paths }
        if (-not $SkipViews) { Assert-HarnessBoard $Paths $OperationConfig }
        $state = Read-HarnessState $Paths
        $result = & $Operation $state
        Write-HarnessJson $Paths.State $state
        if (-not $SkipViews) { Write-HarnessViews $Paths $OperationConfig $state }
        $result
    }
    finally { $lock.Dispose() }
}

function Get-HarnessNextId {
    param([object[]]$Rows, [string]$Prefix)
    $number = 1
    foreach ($row in $Rows) {
        if ([string]$row.id -match ('^' + [regex]::Escape($Prefix) + '-([0-9]+)$')) {
            $number = [Math]::Max($number, ([int]$Matches[1] + 1))
        }
    }
    '{0}-{1:D3}' -f $Prefix, $number
}

function Get-HarnessTask {
    param($State, [string]$Id)
    $matchesFound = @($State.tasks | Where-Object { $_.id -ceq $Id })
    if ($matchesFound.Count -ne 1) { throw "Task not found exactly once: $Id" }
    $matchesFound[0]
}

function Get-HarnessTaskIdentity {
    param([string]$Source, [string]$Scope, [string]$RepositoryRef)
    $sourceKey = ([string]$Source).Trim()
    $sourceUri = $null
    if ([uri]::TryCreate($sourceKey, [UriKind]::Absolute, [ref]$sourceUri) -and $sourceUri.Scheme -in @('http', 'https')) {
        $sourceKey = $sourceUri.AbsoluteUri
    }
    elseif ([IO.Path]::IsPathFullyQualified($sourceKey)) { $sourceKey = [IO.Path]::GetFullPath($sourceKey) }
    [ordered]@{
        source = $sourceKey
        scope = ([string]$Scope).Trim()
        repositoryRef = ([string]$RepositoryRef).Trim().ToUpperInvariant()
    } | ConvertTo-Json -Compress
}

function Get-HarnessTaskContract {
    param($Task)
    [ordered]@{
        identity = Get-HarnessTaskIdentity $Task.source $Task.scope $Task.repositoryRef
        description = ([string]$Task.description).Trim()
        acceptance = ([string]$Task.acceptance).Trim()
        kind = ([string]$Task.kind).ToLowerInvariant()
    } | ConvertTo-Json -Compress
}

function Add-HarnessTaskRecord {
    param($State, [hashtable]$Fields, [string]$FollowUpOf)
    $values = @{
        Title = ''; Description = ''; Scope = ''; Acceptance = ''; Source = ''; SourceRevision = ''; SourceOwner = ''
        RepositoryRef = ''; Kind = 'feature'; Priority = 3; Risk = 'Unknown'; AutoEligible = $false
    }
    foreach ($field in @($values.Keys)) {
        if ($Fields.ContainsKey($field)) { $values[$field] = $Fields[$field] }
    }
    $parent = $null
    if ($FollowUpOf) { $parent = Get-HarnessTask $State $FollowUpOf.Trim().ToUpperInvariant() }
    else {
        if ([string]::IsNullOrWhiteSpace($values.Title)) { throw 'A task title is required.' }
        if (-not [string]::IsNullOrWhiteSpace($values.Source)) {
            $identity = Get-HarnessTaskIdentity $values.Source $values.Scope $values.RepositoryRef
            $existing = @($State.tasks | Where-Object { $_.status -ne 'Cancelled' -and (Get-HarnessTaskIdentity $_.source $_.scope $_.repositoryRef) -ceq $identity })
            if ($existing.Count) {
                $previous = $existing[0]
                $candidate = $previous | Select-Object *
                foreach ($field in @('Description', 'Acceptance', 'Kind')) {
                    if ($Fields.ContainsKey($field)) { $candidate.$field = $values[$field] }
                }
                if ($previous.status -eq 'Completed' -and (Get-HarnessTaskContract $candidate) -cne (Get-HarnessTaskContract $previous)) { $parent = $previous }
                else { return $previous }
            }
        }
    }
    if ($parent) {
        if ($parent.status -notin @('Completed', 'AlreadyFixed')) { throw 'A linked follow-up requires a completed task.' }
        $FollowUpOf = $parent.id
        foreach ($field in @('Title', 'Description', 'Scope', 'Acceptance', 'Source', 'SourceRevision', 'RepositoryRef', 'Kind')) {
            if (-not $Fields.ContainsKey($field)) { $values[$field] = $parent.$field }
        }
        if (-not $Fields.ContainsKey('SourceOwner') -and $values.Source -ceq $parent.source) { $values.SourceOwner = [string]$parent.sourceOwner }
        $contract = Get-HarnessTaskContract $values
        $existing = @($State.tasks | Where-Object { $_.followUpOf -ceq $FollowUpOf -and $_.status -ne 'Cancelled' -and (Get-HarnessTaskContract $_) -ceq $contract })
        if ($existing.Count) { return $existing[0] }
    }
    if ([string]::IsNullOrWhiteSpace($values.Title)) { throw 'A task title is required.' }
    $repositoryRef = ([string]$values.RepositoryRef).Trim()
    if ($repositoryRef) { $repositoryRef = (Get-HarnessRepositoryReference $State $repositoryRef).id }
    $reuseWorkspace = $parent -and $parent.workspace -and ([string]$parent.repositoryRef).Trim() -ieq $repositoryRef
    $ready = -not [string]::IsNullOrWhiteSpace($values.Description) -and -not [string]::IsNullOrWhiteSpace($values.Scope) -and -not [string]::IsNullOrWhiteSpace($values.Acceptance)
    $task = [pscustomobject][ordered]@{
        id = Get-HarnessNextId @($State.tasks) 'T'
        title = $values.Title
        description = $values.Description
        scope = $values.Scope
        acceptance = $values.Acceptance
        source = $values.Source
        sourceRevision = $values.SourceRevision
        sourceOwner = ([string]$values.SourceOwner).Trim()
        sourceType = Get-HarnessSourceType $null ([string]$values.Source)
        repositoryRef = $repositoryRef
        repositoryRoot = $(if ($reuseWorkspace) { $parent.repositoryRoot } else { '' })
        kind = $values.Kind
        priority = $values.Priority
        risk = $values.Risk
        autoEligible = [bool]$values.AutoEligible
        status = $(if ($ready) { 'Queued' } else { 'NeedsEvidence' })
        phase = 'Develop'
        workspace = $(if ($reuseWorkspace) { $parent.workspace } else { '' })
        baseCommit = $(if ($reuseWorkspace) { $parent.baseCommit } else { '' })
        snapshot = ''
        lastReport = ''
        useWorkingChanges = $false
        followUpOf = [string]$FollowUpOf
        createdAt = [datetimeoffset]::UtcNow.ToString('o')
    }
    $State.tasks = @($State.tasks) + @($task)
    $task
}

function Add-HarnessTask {
    param($Paths, [string]$Title, [string]$Description, [string]$Scope, [string]$Acceptance,
        [string]$Source, [string]$SourceRevision, [ValidateSet('feature', 'fix', 'verify')][string]$Kind = 'feature',
        [ValidateRange(1, 5)][int]$Priority = 3, [ValidateSet('Low', 'High', 'Unknown')][string]$Risk = 'Unknown', [switch]$AutoEligible,
        [Alias('RepoRef')][string]$RepositoryRef, [string]$FollowUpOf, [string]$SourceOwner)
    $fields = @{} + $PSBoundParameters
    Update-HarnessState $Paths {
        param($state)
        Add-HarnessTaskRecord -State $state -Fields $fields -FollowUpOf $FollowUpOf
    }
}

function Update-HarnessTask {
    param($Paths, [string]$Id, [hashtable]$Fields)
    Update-HarnessState $Paths {
        param($state)
        $task = Get-HarnessTask $state $Id.Trim().ToUpperInvariant()
        if ($state.active -and $state.active.taskId -eq $task.id) { throw 'Do not change the active task contract during execution.' }
        $candidate = $task | Select-Object *
        $editable = @('Title', 'Description', 'Scope', 'Acceptance', 'Source', 'SourceRevision', 'Kind', 'Priority', 'Risk', 'AutoEligible', 'RepositoryRef')
        foreach ($field in $editable) {
            if ($Fields.ContainsKey($field)) { $candidate.$field = $Fields[$field] }
        }
        if ($task.status -eq 'Completed' -and (Get-HarnessTaskContract $candidate) -cne (Get-HarnessTaskContract $task)) {
            return Add-HarnessTaskRecord -State $state -Fields $Fields -FollowUpOf $task.id
        }
        if ($Fields.ContainsKey('RepositoryRef')) { Set-HarnessTaskRepository $state $task $Fields.RepositoryRef }
        if ($Fields.ContainsKey('Source') -and $Fields.Source -cne $task.source) {
            if (-not $Fields.ContainsKey('SourceOwner')) { $task | Add-Member -NotePropertyName sourceOwner -NotePropertyValue '' -Force }
            $task | Add-Member -NotePropertyName sourceType -NotePropertyValue (Get-HarnessSourceType $null ([string]$Fields.Source)) -Force
        }
        foreach ($field in $editable | Where-Object { $_ -ne 'RepositoryRef' }) {
            if ($Fields.ContainsKey($field)) { $task.$field = $Fields[$field] }
        }
        if ($Fields.ContainsKey('SourceOwner')) { $task | Add-Member -NotePropertyName sourceOwner -NotePropertyValue ([string]$Fields.SourceOwner).Trim() -Force }
        if ($Fields.ContainsKey('AutoEligible')) { $task.autoEligible = [bool]$Fields.AutoEligible }
        if ($task.status -eq 'NeedsEvidence' -and $task.description -and $task.scope -and $task.acceptance) { $task.status = 'Queued' }
        if ($task.status -in @('Failed', 'NeedsDecision', 'Blocked')) { $task.phase = 'Develop' }
        $task
    }
}

function Set-HarnessTaskRepository {
    param($State, $Task, [string]$ReferenceId)
    $ReferenceId = ([string]$ReferenceId).Trim()
    if (([string]$Task.repositoryRef).Trim() -ine $ReferenceId -and ($Task.workspace -or $Task.baseCommit -or $Task.repositoryRoot)) { throw 'A task with an allocated workspace cannot be retargeted; preserve its work and create a new task.' }
    if ($ReferenceId) { $ReferenceId = (Get-HarnessRepositoryReference $State $ReferenceId $Task.id).id }
    $Task | Add-Member -NotePropertyName repositoryRef -NotePropertyValue $ReferenceId -Force
}

function Get-HarnessRepositoryReference {
    param($State, [string]$ReferenceId, [string]$TaskId)
    $ReferenceId = ([string]$ReferenceId).Trim()
    $references = @($State.references | Where-Object { $_.id -ieq $ReferenceId -and $_.active })
    if ($references.Count -ne 1) { throw "Select one active repository reference: $ReferenceId" }
    $reference = $references[0]
    if ($reference.taskId -and $reference.taskId -cne $TaskId) { throw 'The selected repository reference belongs to another task.' }
    if (-not [IO.Path]::IsPathFullyQualified([string]$reference.source) -or -not (Test-Path -LiteralPath $reference.source -PathType Container)) {
        throw 'A coding repository reference must identify an existing local directory; URL references do not implicitly authorize cloning.'
    }
    $reference
}

function Set-HarnessReference {
    param($Paths, [string]$Source, [string]$Note, [string]$TaskId, [string]$RemoveId)
    if (-not $Source -and -not $RemoveId) { throw 'Supply a reference source or an exact removal ID.' }
    if ($Source -and $RemoveId) { throw 'Choose either reference upsert or removal.' }
    $resolvedSource = $Source
    if ($Source -and $Source -notmatch '^https?://') {
        if (-not [System.IO.Path]::IsPathRooted($Source)) { $resolvedSource = Join-Path $Paths.Project $Source }
        $resolvedSource = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($resolvedSource)
    }
    Update-HarnessState $Paths {
        param($state)
        if ($TaskId) { $null = Get-HarnessTask $state $TaskId }
        if ($RemoveId) {
            $reference = @($state.references | Where-Object { $_.id -ceq $RemoveId })
            if ($reference.Count -ne 1) { throw "Reference not found: $RemoveId" }
            $reference[0].active = $false
            return $reference[0]
        }
        $reference = @($state.references | Where-Object { $_.source -ceq $resolvedSource -and $_.taskId -ceq $TaskId })
        if ($reference.Count -gt 0) {
            $reference[0].note = $Note
            $reference[0].active = $true
            $reference[0].updatedAt = [datetimeoffset]::UtcNow.ToString('o')
            return $reference[0]
        }
        $entry = [pscustomobject][ordered]@{
            id = Get-HarnessNextId @($state.references) 'R'
            source = $resolvedSource
            note = $Note
            taskId = $TaskId
            active = $true
            updatedAt = [datetimeoffset]::UtcNow.ToString('o')
        }
        $state.references = @($state.references) + @($entry)
        $entry
    }
}

function Set-HarnessBoard {
    param($Paths, [string]$BoardPath)
    $lock = Enter-HarnessLock $Paths.Lock
    try {
        $config = Read-HarnessConfig $Paths
        $state = Read-HarnessState $Paths
        $oldBoard = Get-HarnessBoard $Paths $config
        if (@($state.tasks).Count -gt 0 -or @($state.references).Count -gt 0 -or @($state.runs).Count -gt 0 -or (Test-Path -LiteralPath (Join-Path $oldBoard 'decisions.csv'))) {
            throw 'The board contains records. Migration requires an explicit reviewed file move; changing boardPath does not silently relocate them.'
        }
        $config.boardPath = $BoardPath
        $null = Get-HarnessBoard $Paths $config
        Assert-HarnessBoard $Paths $config
        Write-HarnessConfig $Paths $config
        $config
    }
    finally { $lock.Dispose() }
}

function Set-HarnessCurrentFileName {
    param($Paths, [string]$CurrentFileName, [switch]$Apply, $RunnerContext)
    $null = Get-HarnessCurrentFileName ([pscustomobject]@{ currentFileName = $CurrentFileName })
    $config = Read-HarnessConfig $Paths
    $board = Get-HarnessBoard $Paths $config
    $markerPath = Join-Path $board '.harness-board.json'
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) { throw 'Publish the existing owned board before renaming its current file.' }
    $marker = Read-HarnessConfigObject $markerPath
    if ($marker.projectId -cne $config.projectId) { throw 'The board belongs to another harness project.' }
    $previousName = Get-HarnessCurrentFileName $marker
    $source = Join-Path $board $previousName
    $destination = Join-Path $board $CurrentFileName
    if ($previousName -cne $CurrentFileName -and (Test-Path -LiteralPath $destination)) { throw 'The requested filename already exists; a board rename never overwrites another file.' }
    $preview = [pscustomobject]@{ preview = -not $Apply; operation = 'RenameCurrentView'; source = $source; destination = $destination; projectId = $config.projectId; status = $(if ($previousName -ceq $CurrentFileName) { 'Unchanged' } else { 'Planned' }) }
    if (-not $Apply -or ($previousName -ceq $CurrentFileName -and (Get-HarnessCurrentFileName $config) -ceq $CurrentFileName)) { return $preview }
    $runLock = Enter-HarnessLock $Paths.RunLock
    $storeLock = $null
    $decisionLock = $null
    $ownership = $null
    $pending = Join-Path (Split-Path -Parent $Paths.State) 'board-name.pending.json'
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('harness-board-name-' + [guid]::NewGuid().ToString('N'))
    $originals = @()
    try {
        $storeLock = Enter-HarnessLock $Paths.Lock
        $config = Read-HarnessConfig $Paths
        if ((Get-HarnessBoard $Paths $config) -ine $board -or (Get-HarnessCurrentFileName (Read-HarnessConfigObject $markerPath)) -cne $previousName) { throw 'Board paths changed; refresh the rename preview.' }
        $state = Read-HarnessState $Paths
        if ($state.active -or @($state.tasks | Where-Object status -EQ Running).Count) { throw 'Finish or recover active work before renaming the board.' }
        $effective = Resolve-HarnessRunnerConfig $config $RunnerContext
        foreach ($directory in @($board, $Paths.Control)) { Assert-HarnessRestrictions -Config $effective -ProjectRoot $Paths.Project -Workspace $directory }
        $ownership = Enter-HarnessOwnership $Paths -Role board-naming -Workspace $board -AdditionalWorkspaces @($Paths.Control)
        $decisionLock = Enter-HarnessLock (Join-Path $board 'decisions.lock')
        foreach ($path in @($source, $destination, $Paths.Config, $markerPath, $Paths.State)) { Assert-HarnessMigrationPath $path }
        if ($previousName -cne $CurrentFileName -and (Test-Path -LiteralPath $destination)) { throw 'The rename destination changed after preview.' }
        $updatedState = $state | ConvertTo-Json -Depth 30 | ConvertFrom-Json -NoEnumerate
        Update-HarnessLayoutReferences $updatedState $Paths @([pscustomobject]@{ source = $source; destination = $destination })
        $decisionPath = Join-Path $board 'decisions.csv'
        $files = @($Paths.Config, $Paths.State, $source, $destination, $markerPath, (Join-Path $Paths.Control 'README.md'), (Join-Path $board 'references.csv'), (Join-Path $board 'history.csv'), $decisionPath) | Select-Object -Unique
        New-Item -ItemType Directory -Path $temporary | Out-Null
        foreach ($path in $files) {
            $backup = Join-Path $temporary ([string]$originals.Count)
            $exists = Test-Path -LiteralPath $path
            if ($exists) { Copy-Item -LiteralPath $path -Destination $backup }
            $originals += [pscustomobject]@{ path = $path; original = $backup; existed = $exists }
        }
        Write-HarnessJson $pending ([pscustomobject]@{ operation = 'board-filename'; projectId = $config.projectId; source = $source; destination = $destination; originals = $originals; temporary = $temporary })
        $config | Add-Member -NotePropertyName currentFileName -NotePropertyValue $CurrentFileName -Force
        Write-HarnessConfig $Paths $config
        $marker | Add-Member -NotePropertyName currentFileName -NotePropertyValue $CurrentFileName -Force
        Write-HarnessJson $markerPath $marker
        if (($updatedState | ConvertTo-Json -Depth 30 -Compress) -cne ($state | ConvertTo-Json -Depth 30 -Compress)) { Write-HarnessJson $Paths.State $updatedState }
        if (Test-Path -LiteralPath $decisionPath) {
            $decisions = @(Import-Csv -LiteralPath $decisionPath)
            foreach ($decision in $decisions) {
                if ($decision.reference) { $decision.reference = ConvertTo-HarnessLayoutReference $decision.reference $Paths @([pscustomobject]@{ source = $source; destination = $destination }) }
            }
            if ($decisions.Count) { Write-HarnessCsv $decisionPath $decisions @($decisions[0].PSObject.Properties.Name) }
        }
        if ($previousName -cne $CurrentFileName -and (Test-Path -LiteralPath $source)) { [IO.File]::Move($source, $destination) }
        Write-HarnessViews $Paths $config $updatedState
        Remove-Item -LiteralPath $pending -Force
        $preview.status = 'Renamed'
        $preview
    }
    catch {
        $failure = $_
        if (Test-Path -LiteralPath $pending) {
            try {
                foreach ($original in $originals) {
                    if ($original.existed) { Copy-Item -LiteralPath $original.original -Destination $original.path -Force }
                    elseif (Test-Path -LiteralPath $original.path) { Remove-Item -LiteralPath $original.path -Force }
                }
                Remove-Item -LiteralPath $pending -Force
            }
            catch { throw "Board rename recovery is incomplete. Preserve $pending and $temporary. $($_.Exception.Message) Original error: $($failure.Exception.Message)" }
        }
        throw $failure
    }
    finally {
        if ($ownership) { Exit-HarnessOwnership $ownership $Paths }
        if ($decisionLock) { $decisionLock.Dispose() }
        if ($storeLock) { $storeLock.Dispose() }
        $runLock.Dispose()
        if (-not (Test-Path -LiteralPath $pending) -and (Test-Path -LiteralPath $temporary)) { Remove-Item -LiteralPath $temporary -Recurse -Force }
    }
}