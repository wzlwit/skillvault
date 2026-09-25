$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'The harness runtime requires PowerShell 7 or later.' }

function Get-HarnessPaths {
    param([Parameter(Mandatory = $true)][string]$ProjectPath)
    $projectRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectPath)
    if (-not (Test-Path -LiteralPath $projectRoot -PathType Container)) { throw "Project directory not found: $projectRoot" }
    $controlRoot = Join-Path $projectRoot '.harness_sv'
    $legacyRoot = Join-Path $projectRoot '.harness'
    $legacyConfigPath = Join-Path $legacyRoot 'config.json'
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
    [pscustomobject]@{
        Project = $projectRoot
        Control = $controlRoot
        Config = Join-Path $controlRoot 'config.json'
        State = Join-Path $controlRoot 'state.json'
        Lock = Join-Path $controlRoot 'store.lock'
        RunLock = Join-Path $controlRoot 'runner.lock'
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
    if (-not (Test-Path -LiteralPath $Paths.Config -PathType Leaf)) { throw 'Harness is not initialized. Run /hn-init for this project first.' }
    $config = Get-Content -LiteralPath $Paths.Config -Raw | ConvertFrom-Json
    if ($config.schemaVersion -ne 1 -or $config.projectRoot -ine $Paths.Project) { throw 'Harness config version or project root does not match this project.' }
    $projectId = [guid]::Empty
    if (-not [guid]::TryParse([string]$config.projectId, [ref]$projectId)) { throw 'Harness config has an invalid projectId.' }
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

function Read-HarnessState {
    param([Parameter(Mandatory = $true)]$Paths)
    if (-not (Test-Path -LiteralPath $Paths.State -PathType Leaf)) { throw 'Harness state is missing; do not recreate it over an existing configuration.' }
    $state = Get-Content -LiteralPath $Paths.State -Raw | ConvertFrom-Json
    if ($state.schemaVersion -ne 1) { throw 'Unsupported harness state version.' }
    $state
}

function Enter-HarnessLock {
    param([Parameter(Mandatory = $true)][string]$Path)
    try { [System.IO.File]::Open($Path, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) }
    catch [System.IO.IOException] { throw 'Harness is busy. Retry after the current operation completes.' }
}

function Initialize-Harness {
    param([Parameter(Mandatory = $true)]$Paths)
    if (Test-Path -LiteralPath $Paths.Config) {
        $config = Read-HarnessConfig $Paths
        $null = Read-HarnessState $Paths
        return $config
    }
    if (Test-Path -LiteralPath $Paths.State) { throw 'Existing harness state has no config. Restore its configuration before initializing.' }
    New-Item -ItemType Directory -Path $Paths.Control -Force | Out-Null
    $lock = Enter-HarnessLock $Paths.Lock
    try {
        if (Test-Path -LiteralPath $Paths.Config) { return Read-HarnessConfig $Paths }
        $config = [pscustomobject][ordered]@{
            schemaVersion = 1
            projectId = [guid]::NewGuid().ToString('N')
            projectRoot = $Paths.Project
            boardPath = [IO.Path]::GetRelativePath($Paths.Project, $Paths.Control)
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
        Write-HarnessJson -Path $Paths.State -Value $state
        Write-HarnessJson -Path $Paths.Config -Value $config
        $config
    }
    finally { $lock.Dispose() }
}

function Write-HarnessCsv {
    param([string]$Path, [object[]]$Rows, [string[]]$Columns)
    $lines = @($Rows | Select-Object -Property $Columns | ConvertTo-Csv -NoTypeInformation)
    if ($lines.Count -eq 0) { $lines = @(($Columns | ForEach-Object { '"' + $_ + '"' }) -join ',') }
    $content = ($lines -join [Environment]::NewLine) + [Environment]::NewLine
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
    }
    else {
        foreach ($name in @('current.csv', 'history.csv', 'references.csv')) {
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
    if (-not (Test-Path -LiteralPath $marker)) { Write-HarnessJson $marker ([ordered]@{ projectId = $Config.projectId }) }
    $current = @($State.tasks | Where-Object { $_.status -notin @('Completed', 'Cancelled', 'Unsupported', 'Stale', 'AlreadyFixed') })
    Write-HarnessCsv (Join-Path $board 'current.csv') $current @('id', 'title', 'kind', 'priority', 'risk', 'autoEligible', 'status', 'phase', 'source', 'acceptance', 'repositoryRef', 'repositoryRoot', 'workspace', 'lastReport', 'followUpOf')
    Write-HarnessCsv (Join-Path $board 'history.csv') @($State.runs) @('id', 'taskId', 'phase', 'status', 'startedAt', 'finishedAt', 'model', 'effort', 'repositoryRef', 'repositoryRoot', 'workspace', 'report', 'exitCode', 'flow', 'environment', 'monitor', 'health')
    Write-HarnessCsv (Join-Path $board 'references.csv') @($State.references | Where-Object { $_.active }) @('id', 'source', 'note', 'taskId', 'updatedAt')
}

function Update-HarnessState {
    param($Paths, [scriptblock]$Operation, [switch]$SkipViews)
    $lock = Enter-HarnessLock $Paths.Lock
    try {
        $config = Read-HarnessConfig $Paths
        if (-not $SkipViews) { Assert-HarnessBoard $Paths $config }
        $state = Read-HarnessState $Paths
        $result = & $Operation $state
        Write-HarnessJson $Paths.State $state
        if (-not $SkipViews) { Write-HarnessViews $Paths $config $state }
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
        Title = ''; Description = ''; Scope = ''; Acceptance = ''; Source = ''; SourceRevision = ''
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
        if ($parent.status -ne 'Completed') { throw 'A linked follow-up requires a completed task.' }
        $FollowUpOf = $parent.id
        foreach ($field in @('Title', 'Description', 'Scope', 'Acceptance', 'Source', 'SourceRevision', 'RepositoryRef', 'Kind')) {
            if (-not $Fields.ContainsKey($field)) { $values[$field] = $parent.$field }
        }
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
        [Alias('RepoRef')][string]$RepositoryRef, [string]$FollowUpOf)
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
        foreach ($field in $editable | Where-Object { $_ -ne 'RepositoryRef' }) {
            if ($Fields.ContainsKey($field)) { $task.$field = $Fields[$field] }
        }
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
        Write-HarnessJson $Paths.Config $config
        $config
    }
    finally { $lock.Dispose() }
}