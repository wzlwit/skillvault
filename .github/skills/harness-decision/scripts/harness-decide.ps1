param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$BoardPath = '.harness_sv',
    [ValidateSet('Show', 'Record')][string]$Action = 'Show',
    [string]$Id,
    [string]$Question,
    [string]$Choice,
    [string]$Rationale,
    [string]$Owner,
    [string]$Reference,
    [string]$Task,
    [ValidateRange(1, 100)][int]$RecentCount = 5,
    [ValidateSet('Open', 'Closed', 'All')][string]$Filter = 'Open'
)

$ErrorActionPreference = 'Stop'
if ($Action -ne 'Show' -and $PSBoundParameters.ContainsKey('Filter')) { throw 'Filter applies only to Show.' }
$projectRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectPath)
if (-not (Test-Path -LiteralPath $projectRoot -PathType Container)) { throw "Project directory not found: $projectRoot" }
$configPath = Join-Path $projectRoot '.harness_sv/config.json'
$legacyConfigPath = Join-Path $projectRoot '.harness/config.json'
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.harness_sv')) -and (Test-Path -LiteralPath $legacyConfigPath -PathType Leaf)) {
    $legacyConfig = $null
    try { $legacyConfig = [IO.File]::ReadAllText($legacyConfigPath) | ConvertFrom-Json }
    catch { $legacyConfig = $null }
    $legacyId = [guid]::Empty
    if ($legacyConfig.schemaVersion -eq 1 -and $legacyConfig.projectRoot -ieq $projectRoot -and
        [guid]::TryParse([string]$legacyConfig.projectId, [ref]$legacyId) -and $null -ne $legacyConfig.runner) {
        $configPath = $legacyConfigPath
    }
}
if (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $configPath) 'move.pending.json')) { throw 'Harness relocation is incomplete. Preserve both locations before recording decisions.' }
if (-not $PSBoundParameters.ContainsKey('BoardPath') -and (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    $config = [System.IO.File]::ReadAllText($configPath) | ConvertFrom-Json
    if ($config.schemaVersion -ne 1 -or $config.projectRoot -ine $projectRoot -or [string]::IsNullOrWhiteSpace([string]$config.boardPath)) { throw 'Harness board configuration is invalid for this project.' }
    $BoardPath = [string]$config.boardPath
}
$boardRoot = $BoardPath
if (-not [System.IO.Path]::IsPathRooted($boardRoot)) { $boardRoot = Join-Path $projectRoot $boardRoot }
$boardRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($boardRoot)
$registerPath = Join-Path $boardRoot 'decisions.csv'
$columns = @('id', 'status', 'question', 'choice', 'recommendation', 'rationale', 'owner', 'recordedAt', 'reference', 'task', 'supersedes')

if ($Action -eq 'Show' -and @('Question', 'Choice', 'Rationale', 'Owner', 'Reference', 'Task' | Where-Object { $PSBoundParameters.ContainsKey($_) }).Count -gt 0) {
    throw 'Show is read-only. Use -Action Record for an explicit human choice.'
}

$exists = Test-Path -LiteralPath $registerPath -PathType Leaf
$registerSnapshot = if ($exists) { [IO.File]::ReadAllText($registerPath) } else { $null }
$decisions = @()
if ($exists) { $decisions = @($registerSnapshot | ConvertFrom-Csv) }
$seenIds = @{}
foreach ($decision in $decisions) {
    if (@($decision.PSObject.Properties.Name).Count -ne $columns.Count -or @($columns | Where-Object { $_ -cnotin $decision.PSObject.Properties.Name }).Count -gt 0) {
        throw 'Unsupported decision CSV schema. Preserve the project format; do not overwrite it with this helper.'
    }
    if ([string]::IsNullOrWhiteSpace($decision.id) -or $seenIds.ContainsKey($decision.id)) { throw 'Missing or duplicate decision ID.' }
    $seenIds[$decision.id] = $true
    if ($decision.status -notin @('Open', 'Proposed', 'Accepted', 'Rejected', 'Superseded')) { throw "Unknown decision status: $($decision.status)" }
    if ($decision.status -in @('Accepted', 'Rejected', 'Superseded')) {
        $parsedTime = [datetimeoffset]::MinValue
        if (-not [datetimeoffset]::TryParse($decision.recordedAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedTime)) {
            throw "Missing or invalid recordedAt for resolved decision $($decision.id)."
        }
    }
}

$selected = $null
if ($Id) {
    $selected = $decisions | Where-Object { $_.id -eq $Id }
    if ($null -eq $selected) { throw "Decision ID not found in register: $Id" }
}

if ($Action -eq 'Show') {
    $visible = $decisions
    if ($null -ne $selected) { $visible = @($selected) }
    elseif ($Filter -eq 'Open') { $visible = @($visible | Where-Object { $_.status -in @('Open', 'Proposed') }) }
    elseif ($Filter -eq 'Closed') { $visible = @($visible | Where-Object { $_.status -in @('Accepted', 'Rejected', 'Superseded') }) }
    [ordered]@{
        Open = @($visible | Where-Object { $_.status -in @('Open', 'Proposed') })
        Recent = @($visible | Where-Object { $_.status -in @('Accepted', 'Rejected', 'Superseded') } |
            Sort-Object @{ Expression = { [datetimeoffset]::Parse($_.recordedAt, [Globalization.CultureInfo]::InvariantCulture) }; Descending = $true }, id |
            Select-Object -First $RecentCount)
        Register = $registerPath
        Exists = $exists
        Filter = if ($Id) { 'Id' } else { $Filter }
    } | ConvertTo-Json -Depth 5
    return
}

if ([string]::IsNullOrWhiteSpace($Choice) -or [string]::IsNullOrWhiteSpace($Owner)) { throw 'Recording requires an explicit Choice and human Owner.' }
if ($null -ne $selected) {
    if ($selected.status -eq 'Superseded') { throw 'This decision is superseded. Select its current replacement before recording a new choice.' }
    if ($selected.status -in @('Accepted', 'Rejected') -and $selected.choice -ceq $Choice) {
        $selected | ConvertTo-Json -Depth 5
        return
    }
    if (-not $Question) { $Question = $selected.question }
    if (-not $PSBoundParameters.ContainsKey('Reference')) { $Reference = $selected.reference }
    if (-not $PSBoundParameters.ContainsKey('Task')) { $Task = $selected.task }
}
if ([string]::IsNullOrWhiteSpace($Question)) { throw 'A new decision requires a Question.' }

$supersedes = ''
$recommendation = ''
if ($null -ne $selected -and $selected.status -in @('Open', 'Proposed')) {
    $newId = $selected.id
    $recommendation = $selected.recommendation
}
else {
    $numbers = @($decisions | Where-Object { $_.id -match '^D-[0-9]+$' } | ForEach-Object { [int]$_.id.Substring(2) })
    $nextNumber = 1
    if ($numbers.Count -gt 0) { $nextNumber = [int]($numbers | Measure-Object -Maximum).Maximum + 1 }
    $newId = 'D-{0:D3}' -f $nextNumber
    if ($null -ne $selected) {
        $supersedes = $selected.id
        $selected.status = 'Superseded'
    }
}

$record = [pscustomobject][ordered]@{
    id = $newId
    status = 'Accepted'
    question = $Question
    choice = $Choice
    recommendation = $recommendation
    rationale = $Rationale
    owner = $Owner
    recordedAt = [datetimeoffset]::UtcNow.ToString('o')
    reference = $Reference
    task = $Task
    supersedes = $supersedes
}
$decisions = @($decisions | Where-Object { $_.id -ne $newId }) + @($record)
$csvLines = @($decisions | Select-Object -Property $columns | ConvertTo-Csv -NoTypeInformation)
if (-not (Test-Path -LiteralPath $boardRoot)) { New-Item -ItemType Directory -Path $boardRoot -Force | Out-Null }
$temporaryPath = Join-Path $boardRoot ('.decisions-' + [guid]::NewGuid().ToString('N') + '.tmp')
$recordLock = [IO.File]::Open((Join-Path $boardRoot 'decisions.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
    if (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $configPath) 'move.pending.json')) { throw 'Harness relocation is incomplete. Read the selected controller again before recording.' }
    $currentSnapshot = if (Test-Path -LiteralPath $registerPath) { [IO.File]::ReadAllText($registerPath) } else { $null }
    if ($currentSnapshot -cne $registerSnapshot) { throw 'The decision register changed. Read its latest records before applying this choice.' }
    [System.IO.File]::WriteAllLines($temporaryPath, [string[]]$csvLines, (New-Object System.Text.UTF8Encoding($false)))
    if ($exists) { [System.IO.File]::Replace($temporaryPath, $registerPath, [NullString]::Value) }
    else { [System.IO.File]::Move($temporaryPath, $registerPath) }
}
finally {
    if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force }
    $recordLock.Dispose()
}
$record | ConvertTo-Json -Depth 5