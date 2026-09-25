$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../skills/planning/harness/scripts/harness-store.ps1')
. (Join-Path $PSScriptRoot '../skills/planning/harness/scripts/harness-maintenance.ps1')
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('sv-retention-' + [guid]::NewGuid().ToString('N'))
$savedFixtureOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
$env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixture 'runtime-ownership'
try {
    New-Item -ItemType Directory -Path $fixture | Out-Null
    $paths = Get-HarnessPaths $fixture
    $config = Initialize-Harness $paths
    $defaults = Get-HarnessMaintenancePolicy $config
    if ($defaults.maxEntries -ne 5000 -or $defaults.maxAge -ne '90d' -or $defaults.enabled -or $null -ne $defaults.maxEntriesPerTopic) { throw 'Retention defaults changed or auto-enabled cleanup.' }
    $dispatcher = Join-Path $PSScriptRoot '../skills/planning/harness/scripts/harness.ps1'
    $policyFile = Join-Path $fixture 'retention.json'
    Write-HarnessJson $policyFile ([pscustomobject]@{ maxEntries = 2; maxAge = '90d'; pinnedRunIds = @('pinned') })
    $configBefore = [IO.File]::ReadAllText($paths.Config)
    $policyPreview = & $dispatcher -ProjectPath $fixture -Action Clean -DefinitionPath 'retention.json' | ConvertFrom-Json
    if (-not $policyPreview.preview -or $policyPreview.policy.maxEntries -ne 2 -or [IO.File]::ReadAllText($paths.Config) -cne $configBefore) { throw 'Retention policy preview changed settings or lost the project-relative definition.' }
    $null = & $dispatcher -ProjectPath $fixture -Action Clean -DefinitionPath 'retention.json' -Apply
    $config = Read-HarnessConfig $paths
    if ($config.maintenance.maxEntries -ne 2 -or (Read-HarnessState $paths).maintenance.lastCleanup) { throw 'Declaring retention failed or unexpectedly ran cleanup.' }
    $now = [datetimeoffset]::UtcNow
    $history = Join-Path $paths.Control 'history'
    New-Item -ItemType Directory -Path $history | Out-Null
    $state = Read-HarnessState $paths
    foreach ($entry in @(@('old', 100), @('pinned', 95), @('referenced', 94), @('recent', 1), @('newest', 0))) {
        $report = Join-Path $history ($entry[0] + '.md')
        [IO.File]::WriteAllText($report, 'Fixture evidence')
        $state.runs += [pscustomobject]@{ id = $entry[0]; taskId = ''; phase = 'Test'; status = 'Passed'; finishedAt = $now.AddDays(-$entry[1]).ToString('o'); report = $report }
    }
    $state.references = @([pscustomobject]@{ active = $true; source = Join-Path $history 'referenced.md' })
    Write-HarnessJson $paths.State $state
    Write-HarnessViews $paths $config $state
    $before = [IO.File]::ReadAllText($paths.State)
    $preview = & $dispatcher -ProjectPath $fixture -Action Clean | ConvertFrom-Json
    if ($preview.candidates.Count -ne 1 -or $preview.candidates[0].id -ne 'old' -or $preview.protected.Count -ne 2) { throw 'Retention selection did not protect pinned and referenced evidence.' }
    if ([IO.File]::ReadAllText($paths.State) -cne $before -or -not (Test-Path (Join-Path $history 'old.md'))) { throw 'Preview changed records or files.' }
    $result = & $dispatcher -ProjectPath $fixture -Action Clean -Apply | ConvertFrom-Json
    if ($result.status -ne 'Cleaned' -or (Test-Path (Join-Path $history 'old.md')) -or @((Import-Csv (Join-Path $paths.Control 'history.csv'))).Count -ne 4) { throw 'Run records, CSV, and report files were not pruned together.' }
    if ((Invoke-HarnessHistoryCleanup $paths -Now $now -Apply).pruned.Count) { throw 'Cleanup was not idempotent.' }
    $state = Read-HarnessState $paths
    $state.active = [pscustomobject]@{ runId = 'active' }
    Write-HarnessJson $paths.State $state
    $blocked = $false
    try { Invoke-HarnessHistoryCleanup $paths -Now $now -Apply | Out-Null } catch { $blocked = $true }
    if (-not $blocked) { throw 'Cleanup ignored active work.' }
    if (Test-HarnessOwnedHistoryPath $paths.Control (Join-Path $fixture 'user.md') 'user') { throw 'Cleanup accepted an external report path.' }
    $state.active = $null
    $config.maintenance = [pscustomobject]@{ maxAge = $null; maxEntries = $null; maxEntriesPerTopic = 1 }
    Write-HarnessJson $paths.Config $config
    $topicPreview = Get-HarnessHistoryCleanupPlan $paths $config $state $now
    if ($topicPreview.candidates.Count -ne 2 -or 'recent' -notin $topicPreview.candidates.id) { throw 'Count-only per-topic retention was not applied.' }
    $retryReport = Join-Path $history 'retry.md'
    [IO.File]::WriteAllText($retryReport, 'Pending evidence')
    $state.maintenance.pendingDeletes = @([pscustomobject]@{ id = 'retry'; report = $retryReport; collection = 'runs' })
    $state.references += [pscustomobject]@{ active = $true; source = $retryReport }
    Write-HarnessJson $paths.State $state
    $retry = Invoke-HarnessHistoryCleanup $paths -Now $now -Apply
    if ($retry.status -ne 'Partial' -or -not (Test-Path $retryReport)) { throw 'A newly linked pending report was deleted on retry.' }
    $state = Read-HarnessState $paths
    $state.references = @($state.references | Where-Object source -NE $retryReport)
    Write-HarnessJson $paths.State $state
    $null = Invoke-HarnessHistoryCleanup $paths -Now $now -Apply
    if (Test-Path $retryReport) { throw 'A pending unlinked report was not retried.' }
    $prDirectory = Join-Path $paths.Control 'pr'
    New-Item -ItemType Directory -Path $prDirectory | Out-Null
    $state = Read-HarnessState $paths
    $state | Add-Member -NotePropertyName prReviews -NotePropertyValue @(
        [pscustomobject]@{ id = 'pr-old'; key = 'fixture'; at = $now.AddDays(-100).ToString('o'); status = 'clean'; report = Join-Path $prDirectory 'pr-old.md'; engineReport = '' }
        [pscustomobject]@{ id = 'pr-latest'; key = 'fixture'; at = $now.ToString('o'); status = 'findings'; report = Join-Path $prDirectory 'pr-latest.md'; engineReport = '' }
    ) -Force
    foreach ($review in $state.prReviews) { [IO.File]::WriteAllText($review.report, 'PR fixture') }
    Write-HarnessJson $paths.State $state
    $null = Invoke-HarnessHistoryCleanup $paths -Now $now -Apply
    if ((Read-HarnessState $paths).prReviews.Count -ne 1 -or (Test-Path (Join-Path $prDirectory 'pr-old.md')) -or -not (Test-Path (Join-Path $prDirectory 'pr-latest.md'))) { throw 'PR index retention lost its latest result or kept expired reports.' }
    $state = Read-HarnessState $paths
    $config.maintenance = [pscustomobject]@{ maxAge = '90d'; maxEntries = $null; maxEntriesPerTopic = $null }
    $state.tasks = @(
        [pscustomobject]@{ id = 'T-001'; status = 'Completed'; followUpOf = ''; lastReport = Join-Path $history 'parent.md' },
        [pscustomobject]@{ id = 'T-002'; status = 'Completed'; followUpOf = 'T-001'; lastReport = Join-Path $history 'child.md' },
        [pscustomobject]@{ id = 'T-003'; status = 'NeedsEvidence'; followUpOf = 'T-002'; lastReport = '' }
    )
    foreach ($entry in @(@('parent', 'T-001'), @('child', 'T-002'))) {
        $report = Join-Path $history ($entry[0] + '.md')
        [IO.File]::WriteAllText($report, 'Earlier completion evidence')
        $state.runs += [pscustomobject]@{ id = $entry[0]; taskId = $entry[1]; phase = 'Review'; status = 'Completed'; finishedAt = $now.AddDays(-100).ToString('o'); report = $report }
    }
    Write-HarnessJson $paths.Config $config
    Write-HarnessJson $paths.State $state
    $linkedCleanup = Invoke-HarnessHistoryCleanup $paths -Now $now -Apply
    if ('parent' -notin $linkedCleanup.protected.id -or 'child' -notin $linkedCleanup.protected.id -or -not (Test-Path (Join-Path $history 'parent.md')) -or -not (Test-Path (Join-Path $history 'child.md'))) { throw 'An open follow-up lost required ancestor completion evidence.' }
    $state = Read-HarnessState $paths
    $state.tasks[2].status = 'Completed'
    $closedFollowUp = Get-HarnessHistoryCleanupPlan $paths $config $state $now
    if ('parent' -notin $closedFollowUp.candidates.id -or 'child' -notin $closedFollowUp.candidates.id) { throw 'Completed follow-ups permanently bypassed ordinary retention.' }
    Write-Output 'Retention checks passed: aggregate defaults, age/count limits, no-write preview, protected evidence, coordinated pruning, and active-run isolation.'
}
finally {
    $env:SKILLVAULT_OWNERSHIP_ROOT = $savedFixtureOwnershipRoot
    Remove-Item -LiteralPath $fixture -Recurse -Force
}