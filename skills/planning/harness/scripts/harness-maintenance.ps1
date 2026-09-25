. (Join-Path $PSScriptRoot 'harness-duration.ps1')
. (Join-Path $PSScriptRoot 'harness-policy.ps1')

function Get-HarnessMaintenancePolicy {
    param($Config)
    $policy = [pscustomobject]@{ enabled = $null; maxAge = '90d'; maxEntries = 5000; maxEntriesPerTopic = $null; timeZoneId = [TimeZoneInfo]::Local.Id; pinnedRunIds = @() }
    foreach ($property in @($Config.maintenance.PSObject.Properties)) {
        if ($null -eq $property) { continue }
        if ($property.Name -notin $policy.PSObject.Properties.Name) { throw "Unknown maintenance setting: $($property.Name)" }
        $policy.($property.Name) = $property.Value
    }
    if ($null -ne $policy.enabled -and $policy.enabled -isnot [bool]) { throw 'Maintenance enabled must be a boolean or null to inherit the shared opt-in.' }
    foreach ($name in @('maxEntries', 'maxEntriesPerTopic')) {
        $value = $policy.$name
        if ($null -ne $value -and ($value -isnot [int] -and $value -isnot [long] -or $value -le 0)) { throw "$name must be a positive integer or null." }
    }
    if ($policy.maxAge) { $null = ConvertTo-HarnessDuration $policy.maxAge }
    $null = [TimeZoneInfo]::FindSystemTimeZoneById($policy.timeZoneId)
    if ($policy.pinnedRunIds -isnot [array]) { throw 'pinnedRunIds must be an array.' }
    $policy
}

function Set-HarnessMaintenancePolicy {
    param($Paths, [string]$DefinitionPath, [switch]$Apply)
    if (-not [IO.Path]::IsPathRooted($DefinitionPath)) { $DefinitionPath = Join-Path $Paths.Project $DefinitionPath }
    $config = Read-HarnessConfig $Paths
    $config | Add-Member -NotePropertyName maintenance -NotePropertyValue (Get-Content -LiteralPath $DefinitionPath -Raw | ConvertFrom-Json -NoEnumerate) -Force
    $policy = Get-HarnessMaintenancePolicy $config
    if ($Apply) {
        $lock = Enter-HarnessLock $Paths.Lock
        try {
            $current = Read-HarnessConfig $Paths
            $current | Add-Member -NotePropertyName maintenance -NotePropertyValue $policy -Force
            Write-HarnessJson $Paths.Config $current
        }
        finally { $lock.Dispose() }
    }
    [pscustomobject]@{ preview = -not $Apply; policy = $policy; project = $Paths.Project }
}

function Get-HarnessHistoryTopic {
    param($Run)
    if ($Run.taskId -and $Run.phase -notin @('Test', 'Monitor')) { return 'dev' }
    ([string]$Run.phase).ToLowerInvariant()
}

function Test-HarnessOwnedHistoryPath {
    param([string]$Board, [string]$Report, [string]$RunId, [ValidateSet('runs', 'prReviews')][string]$Collection = 'runs')
    if (-not $Report) { return $true }
    if ($RunId -cnotmatch '^[A-Za-z0-9_-]+$') { return $false }
    $history = [IO.Path]::GetFullPath((Join-Path $Board $(if ($Collection -eq 'prReviews') { 'pr' } else { 'history' })))
    $expected = Join-Path $history ($RunId + '.md')
    if (-not [IO.Path]::IsPathRooted($Report) -or [IO.Path]::GetFullPath($Report) -ine $expected) { return $false }
    $current = $expected
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { return $false }
        }
        $current = Split-Path -Parent $current
    }
    $true
}

function Get-HarnessHistoryCleanupPlan {
    param($Paths, $Config, $State, [datetimeoffset]$Now = [datetimeoffset]::UtcNow)
    $policy = Get-HarnessMaintenancePolicy $Config
    $board = Get-HarnessBoard $Paths $Config
    Assert-HarnessRestrictions -Config $Config -ProjectRoot $Paths.Project -Workspace $board
    $protectedIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $protectedReports = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($id in @($policy.pinnedRunIds) + @($State.active.runId) + @($State.safety.targets.lastRunId) + @($State.safety.targets.lastFailureRunId)) {
        if ($id) { $null = $protectedIds.Add($id) }
    }
    $openTasks = @($State.tasks | Where-Object { $_.status -notin @('Completed', 'Cancelled', 'Unsupported', 'Stale', 'AlreadyFixed') })
    $requiredTaskIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($openTask in $openTasks) {
        $task = $openTask
        while ($task -and $requiredTaskIds.Add($task.id)) {
            if ($task.lastReport) { $null = $protectedReports.Add([string]$task.lastReport) }
            $parentId = [string]$task.followUpOf
            $task = if ($parentId) { $State.tasks | Where-Object id -CEQ $parentId | Select-Object -First 1 } else { $null }
        }
    }
    foreach ($run in @($State.runs | Where-Object { $requiredTaskIds.Contains([string]$_.taskId) -or $_.pinned -eq $true })) { $null = $protectedIds.Add($run.id) }
    foreach ($reference in @($State.references | Where-Object active)) {
        if ($reference.source) { $null = $protectedReports.Add([string]$reference.source) }
    }
    foreach ($reading in @($State.monitoring.latest)) {
        if ($reading.runId) { $null = $protectedIds.Add($reading.runId) }
        if ($reading.report) { $null = $protectedReports.Add($reading.report) }
    }
    foreach ($incident in @($State.monitoring.incidents | Where-Object { $_.status -ne 'Recovered' })) {
        foreach ($report in @($incident.firstReport, $incident.latestReport)) { if ($report) { $null = $protectedReports.Add($report) } }
    }
    $reviews = @($State.runs | Where-Object { $_.phase -eq 'Review' -and -not $_.taskId -and $_.status -in @('clean', 'findings') })
    foreach ($group in @($reviews | Group-Object { @($_.review.repositoryRef, $_.review.repositoryRoot, $_.review.scope, $_.review.baseline.reference, $_.review.baseline.commit, $_.review.securityReview) | ConvertTo-Json -Compress })) {
        $null = $protectedIds.Add(($group.Group | Select-Object -Last 1).id)
    }
    foreach ($entry in @($State.prReviews | Group-Object key | ForEach-Object { $_.Group | Select-Object -Last 1 })) {
        if ($entry.id) { $null = $protectedIds.Add($entry.id) }
        if ($entry.report) { $null = $protectedReports.Add($entry.report) }
        if ($entry.engineReport) { $null = $protectedReports.Add($entry.engineReport) }
    }
    $cutoff = if ($policy.maxAge) { Get-HarnessRetentionCutoff $policy.maxAge $Now $policy.timeZoneId } else { $null }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $completed = @(foreach ($collection in @('runs', 'prReviews')) {
        foreach ($run in @($State.$collection | Where-Object { $null -ne $_ })) {
            if (-not $run.id -or -not $seen.Add($collection + ':' + $run.id)) { throw 'History contains missing or duplicate run IDs.' }
            $finished = [datetimeoffset]::MinValue
            $timestamp = if ($collection -eq 'prReviews') { $run.at } else { $run.finishedAt }
            if ($run.status -ne 'Running' -and [datetimeoffset]::TryParse([string]$timestamp, [ref]$finished) -and $finished -le $Now) {
                [pscustomobject]@{ run = $run; finished = $finished; collection = $collection; topic = $(if ($collection -eq 'prReviews') { 'pr' } else { Get-HarnessHistoryTopic $run }) }
            }
        }
    }) | Sort-Object @{ Expression = 'finished'; Descending = $true }, @{ Expression = { $_.run.id } }
    $topicCounts = @{}
    $candidates = [Collections.Generic.List[object]]::new()
    $protected = [Collections.Generic.List[object]]::new()
    $position = 0
    foreach ($item in $completed) {
        $position++
        $topicCounts[$item.topic]++
        $reasons = @()
        if ($null -ne $cutoff -and $item.finished -lt $cutoff) { $reasons += 'Age' }
        if ($null -ne $policy.maxEntries -and $position -gt $policy.maxEntries) { $reasons += 'TotalCount' }
        if ($null -ne $policy.maxEntriesPerTopic -and $topicCounts[$item.topic] -gt $policy.maxEntriesPerTopic) { $reasons += 'TopicCount' }
        if (-not $reasons.Count) { continue }
        $run = $item.run
        $reason = if ($protectedIds.Contains($run.id) -or $protectedReports.Contains([string]$run.report)) { 'RequiredEvidence' }
            elseif (-not (Test-HarnessOwnedHistoryPath $board $run.report $run.id $item.collection)) { 'UnownedPath' } else { '' }
        if ($reason) { $protected.Add([pscustomobject]@{ id = $run.id; reason = $reason }); continue }
        $candidates.Add([pscustomobject]@{ id = $run.id; report = [string]$run.report; collection = $item.collection; topic = $item.topic; finishedAt = $item.finished.ToString('o'); reasons = $reasons })
    }
    $total = @(@($State.runs) + @($State.prReviews) | Where-Object { $null -ne $_ }).Count
    [pscustomobject]@{ preview = $true; project = $Paths.Project; policy = $policy; total = $total; candidates = @($candidates); protected = @($protected); retained = $total - $candidates.Count }
}

function Invoke-HarnessHistoryCleanup {
    param($Paths, [switch]$Apply, [datetimeoffset]$Now = [datetimeoffset]::UtcNow)
    if (-not $Apply) { return Get-HarnessHistoryCleanupPlan $Paths (Read-HarnessConfig $Paths) (Read-HarnessState $Paths) $Now }
    $runLock = Enter-HarnessLock $Paths.RunLock
    try {
        $storeLock = Enter-HarnessLock $Paths.Lock
        try {
            $config = Read-HarnessConfig $Paths
            Assert-HarnessBoard $Paths $config
            $state = Read-HarnessState $Paths
            if ($state.active) { throw 'Active or interrupted work must finish or be recovered before history cleanup.' }
            $plan = Get-HarnessHistoryCleanupPlan $Paths $config $state $Now
            $ids = @($plan.candidates | ForEach-Object { $_.id })
            $reports = @($plan.candidates.report | Where-Object { $_ })
            $maintenance = if ($state.maintenance) { $state.maintenance } else { [pscustomobject]@{} }
            $pending = @($maintenance.pendingDeletes) + @($plan.candidates | Where-Object report | Select-Object id, report, collection)
            $pending = @($pending | Where-Object { $null -ne $_ } | Sort-Object collection, id -Unique)
            $maintenance | Add-Member -NotePropertyName pendingDeletes -NotePropertyValue $pending -Force
            $state | Add-Member -NotePropertyName maintenance -NotePropertyValue $maintenance -Force
            foreach ($collection in @('runs', 'prReviews')) {
                if (-not $state.PSObject.Properties[$collection]) { continue }
                $selectedIds = @($plan.candidates | Where-Object collection -EQ $collection | ForEach-Object id)
                $state.$collection = @($state.$collection | Where-Object { $_.id -cnotin $selectedIds })
            }
            foreach ($review in @($state.prReviews | Where-Object { $_.engineReport -cin $reports })) { $review.engineReport = ''; $review | Add-Member -NotePropertyName evidenceExpired -NotePropertyValue $true -Force }
            foreach ($task in @($state.tasks | Where-Object { $_.lastReport -cin $reports })) { $task.lastReport = '' }
            foreach ($incident in @($state.monitoring.incidents | Where-Object { $_.status -eq 'Recovered' })) {
                foreach ($name in @('firstReport', 'latestReport')) {
                    if ($incident.$name -cin $reports) { $incident.$name = ''; $incident | Add-Member -NotePropertyName evidenceExpired -NotePropertyValue $true -Force }
                }
            }
            Write-HarnessJson $Paths.State $state
            Write-HarnessViews $Paths $config $state
            $remaining = [Collections.Generic.List[object]]::new()
            $failures = [Collections.Generic.List[string]]::new()
            foreach ($item in $pending) {
                try {
                    $collection = if ($item.collection) { $item.collection } else { 'runs' }
                    $linked = $item.report -iin @($state.references | Where-Object active | ForEach-Object source) -or $item.report -iin @($state.tasks.lastReport) -or $item.id -cin $plan.policy.pinnedRunIds
                    if ($linked -or $item.id -cin @($state.$collection.id) -or -not (Test-HarnessOwnedHistoryPath (Get-HarnessBoard $Paths $config) $item.report $item.id $collection)) { throw 'Pending file is no longer an owned, unreferenced report.' }
                    if (Test-Path -LiteralPath $item.report -PathType Leaf) { Remove-Item -LiteralPath $item.report -Force -ErrorAction Stop }
                }
                catch { $remaining.Add($item); $failures.Add($_.Exception.Message) }
            }
            $maintenance.pendingDeletes = @($remaining)
            $receipt = [pscustomobject]@{ at = $Now.ToString('o'); pruned = $ids.Count; pending = $remaining.Count; protected = $plan.protected.Count }
            $maintenance | Add-Member -NotePropertyName lastCleanup -NotePropertyValue $receipt -Force
            Write-HarnessJson $Paths.State $state
            [pscustomobject]@{ preview = $false; project = $Paths.Project; pruned = $ids; retained = $plan.retained; protected = $plan.protected; pending = @($remaining); errors = @($failures); status = $(if ($remaining.Count) { 'Partial' } else { 'Cleaned' }) }
        }
        finally { $storeLock.Dispose() }
    }
    finally { $runLock.Dispose() }
}