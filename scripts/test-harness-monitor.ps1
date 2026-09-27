param([switch]$DiscoveryOnly, [switch]$VerificationOnly, [switch]$ProjectionOnly, [switch]$BatchOnly, [switch]$RepositoryOnly, [switch]$CorrelationOnly)

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

if ($CorrelationOnly) {
    $now = [datetimeoffset]::UtcNow.ToString('o')
    $definitions = @(foreach ($name in @('tracker', 'specification', 'other')) {
        [pscustomobject]@{ name = $name; kind = 'discovery'; source = [pscustomobject]@{ type = 'json-feed'; path = "$name.json" }; environment = 'local'; maxMinutes = 1; maxAgeMinutes = 60 }
    })
    $config = [pscustomobject]@{ monitoring = [pscustomobject]@{ monitors = $definitions } }
    $state = [pscustomobject]@{ tasks = @(); monitoring = [pscustomobject]@{ candidates = @(); latest = @() } }
    foreach ($definition in $definitions) {
        $source = "https://example.invalid/$($definition.name)"
        $item = [pscustomobject]@{ id = $definition.name; source = $source; revision = 'one'; title = 'The same title is not an identity'; text = 'The required value is 42.'; disposition = 'Open'; sourceOwner = $definition.name }
        if ($definition.name -ceq 'specification') { $item | Add-Member -NotePropertyName sameRequirementAs -NotePropertyValue @('https://example.invalid/tracker') }
        $reading = Get-HarnessDiscoveryResult $definition ([pscustomobject]@{ schemaVersion = 1; complete = $true; observedAt = $now; items = @($item) })
        $null = Register-HarnessDiscoveryObservation $state $definition $reading $definition.name 'fixture-report.md'
    }
    foreach ($candidate in $state.monitoring.candidates) {
        $candidate | Add-Member -NotePropertyName verification -NotePropertyValue ([pscustomobject]@{ outcome = 'open'; sourceRevision = 'one'; collectionRunId = $candidate.lastRunId; summary = 'Implementation evidence establishes unfinished work.' })
    }
    $group = Get-HarnessDiscoveryCorrelation $config $state $state.monitoring.candidates[0]
    if (-not $group.correlated -or -not $group.ready -or $group.members.Count -ne 2 -or $group.provenance.sourceOwner.Count -ne 2 -or
        (Get-HarnessDiscoveryCorrelation $config $state $state.monitoring.candidates[2]).correlated) { throw 'Explicit source correlation lost provenance or fuzzy-merged a similar title.' }
    $intakeMonitoring = $state.monitoring | ConvertTo-Json -Depth 20
    $state.monitoring.candidates[1].disposition = 'Resolved'
    if (-not (Get-HarnessDiscoveryCorrelation $config $state $state.monitoring.candidates[0]).ready) { throw 'Different source status labels or owners became a substantive conflict.' }
    $state.monitoring.candidates[0].claims = @(ConvertTo-HarnessSourceClaims @([pscustomobject]@{ fact = 'acceptance.value'; value = '42'; quote = 'The required value is 42.' }) 'The required value is 42.')
    $state.monitoring.candidates[1].claims = @(ConvertTo-HarnessSourceClaims @([pscustomobject]@{ fact = 'acceptance.value'; value = '43'; quote = 'The required value is 43.' }) 'The required value is 43.')
    $conflicting = Get-HarnessDiscoveryCorrelation $config $state $state.monitoring.candidates[0]
    if ($conflicting.ready -or $conflicting.outcome -cne 'unverified' -or $conflicting.conflicts.Count -ne 1 -or $conflicting.conflicts[0].claims.Count -ne 2) { throw 'Contradictory acceptance facts were hidden or treated as settled.' }
    $config.monitoring | Add-Member -NotePropertyName correlations -NotePropertyValue @([pscustomobject]@{ name = 'value'; sources = @('https://example.invalid/tracker', 'https://example.invalid/specification'); authorities = [pscustomobject]@{ 'acceptance.value' = 'https://example.invalid/specification' } })
    Assert-HarnessMonitorSettings $config.monitoring
    $resolved = Get-HarnessDiscoveryCorrelation $config $state $state.monitoring.candidates[0]
    if (-not $resolved.ready -or -not $resolved.conflicts[0].resolved -or $resolved.conflicts[0].authority -cne 'https://example.invalid/specification') { throw 'The declared authority did not resolve its exact disputed fact.' }
    $state.monitoring.candidates[1].verification.outcome = 'already-fixed'
    if ((Get-HarnessDiscoveryCorrelation $config $state $state.monitoring.candidates[0]).ready) { throw 'Acceptance authority incorrectly overrode contradictory completion evidence.' }
    $config.monitoring.correlations[0].authorities | Add-Member -NotePropertyName completion -NotePropertyValue 'https://example.invalid/tracker'
    if ((Get-HarnessDiscoveryCorrelation $config $state $state.monitoring.candidates[0]).outcome -cne 'open') { throw 'Completion authority was not applied independently of acceptance authority.' }
    $state.monitoring.candidates[0].verification.outcome = 'already-fixed'
    $state.monitoring.candidates[1].verification.outcome = 'open'
    $config.monitoring.correlations[0].authorities.completion = 'https://example.invalid/specification'
    if (@(Get-HarnessVerifiedMonitorSubset $config $state).Count -ne 2) { throw 'A non-authoritative representative status hid a verified open group.' }
    $state.monitoring.candidates[0].verification | Add-Member -NotePropertyName snapshot -NotePropertyValue 'earlier'
    $state.monitoring.candidates[1].verification | Add-Member -NotePropertyName snapshot -NotePropertyValue 'current'
    if ((Get-HarnessDiscoveryCorrelation $config $state $state.monitoring.candidates[0]).ready) { throw 'A group mixed incompatible verification snapshots.' }
    $state.monitoring.candidates[0].verification.PSObject.Properties.Remove('snapshot')
    $state.monitoring.candidates[1].verification.PSObject.Properties.Remove('snapshot')
    $state.monitoring.candidates[1].evidenceStatus = 'Uncertain'
    if ((Get-HarnessDiscoveryCorrelation $config $state $state.monitoring.candidates[0]).ready) { throw 'An unavailable linked source was treated as current evidence.' }
    Assert-MonitorFailure { ConvertTo-HarnessSourceClaims @([pscustomobject]@{ fact = 'completion'; value = 'fixed'; quote = 'Status: Fixed' }) 'Status: Fixed' } 'substantive quote'
    Assert-MonitorFailure { ConvertTo-HarnessRelatedSources @('https://secret@example.invalid/source') } 'without credentials'
    $fixture = Join-Path ([IO.Path]::GetTempPath()) ('harness-correlations-' + [guid]::NewGuid().ToString('N'))
    $previousOwnership = $env:SKILLVAULT_OWNERSHIP_ROOT
    $env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixture 'ownership'
    try {
        New-Item -ItemType Directory -Path $fixture | Out-Null
        $paths = Get-HarnessPaths $fixture
        $intakeConfig = Initialize-Harness $paths
        $intakeConfig | Add-Member -NotePropertyName monitoring -NotePropertyValue ([pscustomobject]@{ monitors = $definitions }) -Force
        Write-HarnessConfig $paths $intakeConfig
        $report = Join-Path $fixture 'source-report.md'
        [IO.File]::WriteAllText($report, 'Fixture evidence only.')
        $null = Update-HarnessState $paths -Config $intakeConfig -Operation {
            param($saved)
            $saved | Add-Member -NotePropertyName monitoring -NotePropertyValue ($intakeMonitoring | ConvertFrom-Json) -Force
            foreach ($candidate in $saved.monitoring.candidates) { $candidate.firstReport = $report; $candidate.latestReport = $report }
        }
        $rows = @(Get-HarnessCurrentRows $intakeConfig (Read-HarnessState $paths))
        if ($rows.Count -ne 2 -or ($rows[0].sourceEvidence | ConvertFrom-Json).Count -ne 2) { throw 'The canonical board did not project one related requirement with both source records.' }
        $preview = Add-HarnessMonitorTask $paths 'C-002'
        if (-not $preview.preview -or $preview.proposal.candidateId -cne 'C-001' -or $preview.proposal.sourceEvidence.Count -ne 2) { throw 'Alias acceptance did not preview the canonical requirement and all its evidence.' }
        $accepted = Add-HarnessMonitorTask $paths 'C-002' -Apply -Actor Fixture -Reason 'Accept one explicitly related requirement'
        $repeated = Add-HarnessMonitorTask $paths 'C-001' -Apply -Actor Fixture -Reason 'Repeat'
        $saved = Read-HarnessState $paths
        if ($saved.tasks.Count -ne 1 -or $accepted.task.id -cne $repeated.task.id -or $saved.monitoring.candidates[1].taskId -cne $accepted.task.id -or
            $accepted.task.sourceEvidence.Count -ne 2 -or $accepted.task.autoEligible) { throw 'Cross-source acceptance duplicated tasks or lost provenance/approval boundaries.' }
        $null = Update-HarnessState $paths -Config $intakeConfig -Operation {
            param($saved)
            $saved.monitoring.candidates[1].verification.outcome = 'already-fixed'
        }
        Assert-MonitorFailure { Add-HarnessMonitorTask $paths 'C-002' -Apply -Actor Fixture -Reason 'Conflicted evidence' } 'Unverified'
        $viewRows = @(Get-HarnessCurrentRows $intakeConfig (Read-HarnessState $paths))
        if (($viewRows | Where-Object recordType -CEQ task).correlationStatus -cne 'Unverified' -or (Read-HarnessState $paths).tasks[0].status -cne 'Queued') { throw 'A correlation conflict hid the task or overwrote its execution status.' }
    }
    finally { $env:SKILLVAULT_OWNERSHIP_ROOT = $previousOwnership; if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force } }
    Write-Output 'Correlation checks passed: exact relationships, all provenance, scoped fact authority, independent conflicts, unavailable sources, and no owner/status or fuzzy matching.'
    return
}

if ($RepositoryOnly) {
    $fixture = Join-Path ([IO.Path]::GetTempPath()) ('harness-authority-' + [guid]::NewGuid().ToString('N'))
    try {
        $source = Join-Path $fixture 'source'
        $remote = Join-Path $fixture 'remote.git'
        New-Item -ItemType Directory -Path $source -Force | Out-Null
        $paths = Get-HarnessPaths $fixture
        $config = Initialize-Harness $paths
        $null = Invoke-HarnessGit $source @('init', '--quiet', '--initial-branch=main')
        [IO.File]::WriteAllText((Join-Path $source 'code.txt'), 'Published implementation')
        $null = Invoke-HarnessGit $source @('add', 'code.txt')
        $null = Invoke-HarnessGit $source @('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--quiet', '-m', 'Published')
        $null = Invoke-HarnessGit $fixture @('clone', '--bare', '--quiet', $source, $remote)
        $null = Invoke-HarnessGit $source @('remote', 'add', 'origin', 'https://example.invalid/service.git')
        [IO.File]::WriteAllText((Join-Path $source 'code.txt'), 'Dirty local work must remain untouched')
        $before = Invoke-HarnessGit $source @('status', '--porcelain')
        $realGit = ${function:Invoke-HarnessGit}
        function Invoke-HarnessGit {
            param($Directory, $Arguments, $Context)
            $translated = @($Arguments | ForEach-Object { if ($_ -ceq 'https://example.invalid/service.git') { $remote } elseif ($_ -ceq 'protocol.file.allow=never') { 'protocol.file.allow=always' } else { $_ } })
            & $realGit $Directory $translated -Context $Context
        }
        $snapshot = New-HarnessVerificationSnapshot $paths $config ([pscustomobject]@{ remote = 'origin'; branch = 'main'; credentialHelper = 'none' }) $source fixture 2
        if ([IO.File]::ReadAllText((Join-Path $snapshot.workspace 'code.txt')) -cne 'Published implementation' -or
            [IO.File]::ReadAllText((Join-Path $source 'code.txt')) -cne 'Dirty local work must remain untouched' -or
            (Invoke-HarnessGit $source @('status', '--porcelain')) -cne $before -or $snapshot.authority.branch -cne 'main' -or $snapshot.authority.commit -cnotmatch '^[a-f0-9]{40}$') { throw 'Authoritative repository inspection used dirty local code or modified its source checkout.' }
        Write-Output 'Repository evidence checks passed: configured remote/ref, fetched commit, isolated read-only evidence, and unchanged dirty checkout.'
    }
    finally { if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force } }
    return
}

if ($BatchOnly) {
    $fixture = Join-Path ([IO.Path]::GetTempPath()) ('harness-batch-' + [guid]::NewGuid().ToString('N'))
    $priorOwnership = $env:SKILLVAULT_OWNERSHIP_ROOT
    $env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixture 'ownership'
    try {
        New-Item -ItemType Directory -Path $fixture | Out-Null
        $paths = Get-HarnessPaths $fixture
        $config = Initialize-Harness $paths
        $config.runner.rulesPath = Join-Path $fixture 'rules.md'
        [IO.File]::WriteAllText($config.runner.rulesPath, 'Fixture only.')
        $config | Add-Member -NotePropertyName monitoring -NotePropertyValue ([pscustomobject]@{ monitors = @(foreach ($name in @('ado', 'design')) {
            [pscustomobject]@{ name = $name; kind = 'discovery'; source = [pscustomobject]@{ type = 'json-feed'; path = "$name.json" }; environment = 'local'; maxAgeMinutes = 60; maxMinutes = 1 }
        }) }) -Force
        Write-HarnessConfig $paths $config
        function Invoke-HarnessDiscoveryVerification {
            param($Paths, $Config, $Definition, $CollectionRunId, $MaxMinutes, $SourceItems)
            $null = Update-HarnessState $Paths -Config $Config -Operation {
                param($saved)
                foreach ($candidate in $saved.monitoring.candidates | Where-Object monitor -CEQ $Definition.name) {
                    $candidate | Add-Member -NotePropertyName verification -NotePropertyValue ([pscustomobject]@{ outcome = 'open'; sourceRevision = $candidate.revision; collectionRunId = $CollectionRunId }) -Force
                }
            }
            [pscustomobject]@{ status = 'Verified'; outcomes = @() }
        }
        foreach ($name in @('ado', 'design')) {
            Write-HarnessJson (Join-Path $fixture "$name.json") ([pscustomobject]@{ schemaVersion = 1; complete = $true; observedAt = [datetimeoffset]::UtcNow.ToString('o'); items = @([pscustomobject]@{ id = $name; source = "https://example.invalid/$name"; revision = 'one'; title = "$name concern"; text = 'Actionable fixture concern'; disposition = 'Deferred'; priority = 2 }) })
        }
        $batch = Invoke-HarnessMonitorBatch $paths
        if (-not $batch.complete -or $batch.sources.Count -ne 2 -or $batch.proposals.Count -ne 2 -or (Read-HarnessState $paths).tasks.Count) { throw 'Multi-source check did not cover every definition without task intake.' }
        [IO.File]::WriteAllText((Join-Path $fixture 'design.json'), '{ invalid')
        $partial = Invoke-HarnessMonitorBatch $paths
        $saved = Read-HarnessState $paths
        if ($partial.complete -or $partial.status -cne 'Partial' -or $partial.proposals.Count -or $partial.sources.Count -ne 2 -or $saved.monitoring.candidates.Count -ne 2 -or
            $saved.monitoring.batch.complete -or -not (Test-Path $partial.report)) { throw 'Partial source failure was hidden or prior candidates were discarded.' }
        $partialRows = @(Import-Csv (Get-HarnessCurrentPath $paths $config))
        if (@($partialRows | Where-Object checkStatus -CNE Partial).Count -or (Get-HarnessMonitorView $paths).proposals.Count) { throw 'A partial batch was presented as a complete pickup list in the canonical view.' }
        $partialView = Get-HarnessMonitorView $paths
        if ($partial.verifiedSubset.Count -ne 1 -or $partialView.verifiedSubset.Count -ne 1 -or $partial.verifiedSubset[0].source -cne 'https://example.invalid/ado' -or
            $partial.verifiedSubset[0].autoEligible -or $partial.verifiedSubset[0].risk -cne 'Unknown') { throw 'A partial check hid its verified subset or enabled automatic pickup.' }
        $preview = Add-HarnessMonitorTask $paths $partial.verifiedSubset[0].candidateId
        if (-not $preview.preview -or (Read-HarnessState $paths).tasks.Count) { throw 'Verified subset inspection did not retain explicit task acceptance.' }
        $unavailable = $saved.monitoring.candidates | Where-Object monitor -CEQ design
        Assert-MonitorFailure { Add-HarnessMonitorTask $paths $unavailable.id } 'fresh complete discovery evidence'
        $config.monitoring.monitors += [pscustomobject]@{ name = 'health'; maxAgeMinutes = 60; response = 'propose-task' }
        $saved.monitoring.incidents += [pscustomobject]@{ id = 'I-001'; monitor = 'health'; status = 'Open'; response = 'propose-task'; taskId = ''; resource = 'fixture'; condition = [pscustomobject]@{ operator = 'gt'; threshold = 1 } }
        $saved.monitoring.latest += [pscustomobject]@{ monitor = 'health'; result = [pscustomobject]@{ status = 'Succeeded'; health = 'Unhealthy'; windowEnd = [datetimeoffset]::UtcNow.ToString('o') } }
        if (@(Get-HarnessVerifiedMonitorSubset $config $saved).Count -ne 2) { throw 'A valid health incident was excluded solely because another source failed.' }
        $saved.monitoring.latest[-1].result.health = 'Unknown'
        if (@(Get-HarnessVerifiedMonitorSubset $config $saved).Count -ne 1) { throw 'Unknown health evidence was presented as a verified subset.' }
        $held = Enter-HarnessLock $paths.RunLock
        try { if ((Invoke-HarnessMonitorBatch $paths).status -cne 'Busy') { throw 'Batch checks bypassed the shared run lock.' } }
        finally { $held.Dispose() }
        Write-Output 'Batch checks passed: all configured sources, explicitly partial verified subsets, manual acceptance, retained uncertain candidates, diagnostics, and shared locking.'
    }
    finally { $env:SKILLVAULT_OWNERSHIP_ROOT = $priorOwnership; if (Test-Path $fixture) { Remove-Item $fixture -Recurse -Force } }
    return
}

if ($ProjectionOnly) {
    $fixture = Join-Path ([IO.Path]::GetTempPath()) ('harness-projection-' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $fixture | Out-Null
        $paths = Get-HarnessPaths $fixture
        $config = Initialize-Harness $paths
        $config | Add-Member -NotePropertyName monitoring -NotePropertyValue ([pscustomobject]@{ monitors = @(
            [pscustomobject]@{ name = 'ado'; source = [pscustomobject]@{ type = 'ado' }; maxAgeMinutes = 60; verification = [pscustomobject]@{ enabled = $false } }
            [pscustomobject]@{ name = 'design'; source = [pscustomobject]@{ type = 'folder' }; maxAgeMinutes = 60; verification = [pscustomobject]@{ enabled = $false } }
        ) }) -Force
        $state = Read-HarnessState $paths
        $state.tasks = @(
            [pscustomobject]@{ id = 'T-002'; title = 'Later'; priority = 4; status = 'Queued'; source = 'manual'; sourceOwner = '' }
            [pscustomobject]@{ id = 'T-001'; title = 'First'; priority = 1; status = 'Queued'; source = 'https://dev.azure.com/example/work/1'; sourceOwner = 'Source owner' }
            [pscustomobject]@{ id = 'T-003'; title = 'Done'; priority = 1; status = 'Done'; source = 'manual' }
        )
        $state | Add-Member -NotePropertyName monitoring -NotePropertyValue ([pscustomobject]@{
            candidates = @(
                [pscustomobject]@{ id = 'C-001'; title = 'ADO accepted'; monitor = 'ado'; taskId = 'T-001'; source = 'https://dev.azure.com/example/work/1'; disposition = 'Open'; priority = 1; revision = '1'; lastSeenAt = [datetimeoffset]::UtcNow.ToString('o') }
                [pscustomobject]@{ id = 'C-002'; title = 'Design backlog'; monitor = 'design'; taskId = ''; source = 'file:///fixture.md'; disposition = 'Deferred'; priority = 2; revision = '1'; lastSeenAt = [datetimeoffset]::UtcNow.ToString('o') }
            )
            latest = @([pscustomobject]@{ monitor = 'ado'; result = [pscustomobject]@{ status = 'Succeeded'; observedAt = [datetimeoffset]::UtcNow.ToString('o') } }, [pscustomobject]@{ monitor = 'design'; result = [pscustomobject]@{ status = 'Failed' } })
        })
        $before = $state | ConvertTo-Json -Depth 20 -Compress
        Write-HarnessViews $paths $config $state
        $rows = @(Import-Csv (Get-HarnessCurrentPath $paths $config))
        if (($rows.id -join ',') -cne 'T-001,C-002,T-002' -or $rows[0].sourceType -cne 'ado' -or $rows[1].sourceType -cne 'design' -or
            $rows[1].recordType -cne 'candidate' -or $rows[1].status -cne 'Uncertain' -or $rows[0].sourceOwner -cne 'Source owner' -or
            ($state | ConvertTo-Json -Depth 20 -Compress) -cne $before) { throw 'Canonical board projection lost source coverage, priority ordering, uncertainty, or task/candidate separation.' }
        Write-Output 'Projection checks passed: one schema, source coverage, stable priority ordering, terminal exclusion, no duplicate accepted candidate, and unchanged task state.'
    }
    finally { if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force } }
    return
}

if ($VerificationOnly) {
    $fixture = Join-Path ([IO.Path]::GetTempPath()) ('harness-verifier-' + [guid]::NewGuid().ToString('N'))
    $savedOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
    $env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixture 'ownership'
    try {
        New-Item -ItemType Directory -Path $fixture -Force | Out-Null
        $paths = Get-HarnessPaths $fixture
        $config = Initialize-Harness $paths
        $config.runner.command = 'fixture-agent'
        $config.runner.model = 'strong-development-model'
        $config.runner.reasoningEffort = 'high'
        $config.runner.rulesPath = Join-Path $fixture 'rules.md'
        [IO.File]::WriteAllText($config.runner.rulesPath, 'Read only temporary fixture evidence.')
        Write-HarnessConfig $paths $config
        $script:agentArguments = @()
        $script:verificationResponse = [pscustomobject]@{ outcome = 'unverified'; summary = 'No completion proof'; evidence = @() }
        $script:verificationDefinition = $null
        $script:verificationMutation = $null
        $script:expectedSourceTail = ''
        $script:fixtureBlockers = @()
        $script:verificationCalls = @()
        $script:verificationByMonitor = @{}
        function Invoke-HarnessProcess {
            param($Executable, $Arguments, $Directory, $MaxMinutes, $Paths, $Config, $Targets, [switch]$InheritPermissions, $InputText)
            if ($Executable -ceq 'pwsh' -and $script:verificationDefinition) {
                $definitionIndex = [array]::IndexOf($Arguments, '-DefinitionJson')
                $collectorDefinition = if ($definitionIndex -ge 0) { $Arguments[$definitionIndex + 1] | ConvertFrom-Json } else { $script:verificationDefinition }
                $collected = Read-HarnessDiscoverySource $collectorDefinition $Paths.Project $Config
                return [pscustomobject]@{ ExitCode = 0; Output = ([pscustomobject]@{ succeeded = $true; observation = $collected } | ConvertTo-Json -Depth 15 -Compress); Error = ''; TimedOut = $false; Stopped = $false }
            }
            $script:agentArguments = @($Arguments)
            if ($script:verificationDefinition) {
                $script:verificationCalls += [string]$Task.candidate.id
                if ($script:expectedSourceTail -and $Task.sourceContent -notlike "*$script:expectedSourceTail*") { throw 'The verifier received only a truncated source excerpt.' }
                $script:verificationResponse | Add-Member -NotePropertyName assessment -NotePropertyValue ([pscustomobject]@{ scope = $script:verificationDefinition.scope.description; sourceRevision = $Task.candidate.revision; relevance = 'Relevant'; reason = 'This is the selected service concern.'; priority = 1; priorityReason = 'The service behavior is affected.'; blockers = @($script:fixtureBlockers) }) -Force
                if ($script:verificationMutation) { & $script:verificationMutation }
            }
            if ($script:verificationByMonitor.ContainsKey([string]$Task.candidate.monitor)) {
                return [pscustomobject]@{ ExitCode = 0; Output = ($script:verificationByMonitor[$Task.candidate.monitor] | ConvertTo-Json -Depth 10 -Compress); Error = ''; TimedOut = $false; Stopped = $false }
            }
            [pscustomobject]@{ ExitCode = 0; Output = ($script:verificationResponse | ConvertTo-Json -Depth 10 -Compress); Error = ''; TimedOut = $false; Stopped = $false }
        }
        $task = [pscustomobject]@{ id = ''; kind = 'verify'; scope = 'fixture'; monitorTarget = 'monitor:fixture' }
        $response = Invoke-HarnessAgent $paths $config $task $fixture Verify 'fixture-snapshot'
        $modelIndex = [array]::IndexOf($script:agentArguments, '--model')
        if ($response.outcome -cne 'unverified' -or $script:agentArguments[$modelIndex + 1] -cne 'auto' -or '--auto-tier' -in $script:agentArguments -or
            '--reasoning-effort' -in $script:agentArguments -or '--deny-tool=write' -notin $script:agentArguments -or '--deny-tool=shell' -notin $script:agentArguments -or
            '--deny-tool=url' -notin $script:agentArguments -or $config.runner.model -cne 'strong-development-model') { throw 'Verification did not isolate model auto and read-only permissions from development settings.' }
        $script:verificationResponse.outcome = 'already-fixed'
        Assert-MonitorFailure { Invoke-HarnessAgent $paths $config $task $fixture Verify 'snapshot' } 'without evidence'
        $script:verificationResponse.outcome = 'ready'
        Assert-MonitorFailure { Invoke-HarnessAgent $paths $config $task $fixture Verify 'snapshot' } 'Invalid verification result'
        $repository = Join-Path $fixture 'code'
        $sources = Join-Path $fixture 'sources'
        New-Item -ItemType Directory -Path $repository, $sources | Out-Null
        $null = Invoke-HarnessGit $repository @('init', '--quiet')
        $null = Invoke-HarnessGit $repository @('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '--allow-empty', '-m', 'fixture', '--quiet')
        $implementation = Join-Path $repository 'implementation.ps1'
        $testEvidence = Join-Path $repository 'assertion.ps1'
        $sourceFile = Join-Path $sources 'concern.md'
        [IO.File]::WriteAllText($implementation, 'function Get-FixtureValue { 42 }')
        [IO.File]::WriteAllText($testEvidence, 'if ((Get-FixtureValue) -ne 42) { throw "Regression" }')
        [IO.File]::WriteAllText($sourceFile, "# DAS service value`nStatus: Open`nThe current service must return 42.")
        $reference = Set-HarnessReference $paths -Source $repository -Note 'Approved fixture coding repository'
        $script:verificationDefinition = [pscustomobject]@{
            name = 'fixture'; kind = 'discovery'; source = [pscustomobject]@{ type = 'folder'; path = $sources }
            scope = [pscustomobject]@{ description = 'DAS service'; terms = @('DAS') }
            environment = 'local'; maxMinutes = 2; maxAgeMinutes = 60; response = 'propose-task'
            verification = [pscustomobject]@{ repositoryRef = $reference.id }
        }
        $config = Read-HarnessConfig $paths
        $config.monitoring.monitors = @($script:verificationDefinition)
        Write-HarnessConfig $paths $config
        $script:verificationResponse = [pscustomobject]@{ outcome = 'open'; summary = 'The concern remains actionable.'; evidence = @([pscustomobject]@{ path = $implementation; line = 1; quote = 'function Get-FixtureValue { 42 }'; kind = 'implementation' }) }
        $openRun = Invoke-HarnessMonitor $paths fixture
        if ($openRun.verification.status -cne 'Verified' -or $openRun.proposal.Count -ne 1 -or $openRun.proposal[0].priority -ne 1 -or $openRun.candidates[0].verification.model -cne 'auto') { throw "Monitor did not qualify and verify current work before prioritizing it: $($openRun.verification | ConvertTo-Json -Depth 8)" }
        $accepted = Add-HarnessMonitorTask $paths $openRun.candidates[0].id -Apply -Actor Fixture -Reason 'Track verified unfinished work'
        if ($accepted.task.autoEligible -or $accepted.task.risk -cne 'Unknown') { throw 'Verification bypassed development pickup approval.' }
        $script:fixtureBlockers = @('Awaiting the explicit dependency approval')
        $blockedRun = Invoke-HarnessMonitor $paths fixture
        if ((Get-HarnessTask (Read-HarnessState $paths) $accepted.task.id).status -cne 'Blocked') { throw 'A verified blocker was ignored on a monitor-owned task.' }
        $script:fixtureBlockers = @()
        $null = Invoke-HarnessMonitor $paths fixture
        if ((Get-HarnessTask (Read-HarnessState $paths) $accepted.task.id).status -cne 'Queued') { throw 'A verified cleared blocker left a monitor-owned task permanently blocked.' }
        $script:expectedSourceTail = 'The final owning-section requirement must also be reviewed.'
        $null = Update-HarnessTask $paths $accepted.task.id @{ Risk = 'Low'; AutoEligible = $true }
        $script:verificationResponse | Add-Member -NotePropertyMembers @{ requirementChanged = $true; changeReason = 'The source now explicitly requires agreement validation.' }
        [IO.File]::WriteAllText($sourceFile, ("# DAS service value`nStatus: Open`nThe current service must return 42 with explicit agreement validation.`n" + ('Full governing context. ' * 300) + $script:expectedSourceTail))
        $updatedOpen = Invoke-HarnessMonitor $paths fixture
        $script:expectedSourceTail = ''
        $script:verificationResponse.PSObject.Properties.Remove('requirementChanged')
        $script:verificationResponse.PSObject.Properties.Remove('changeReason')
        $updatedTask = Get-HarnessTask (Read-HarnessState $paths) $accepted.task.id
        if ($updatedTask.sourceRevision -cne $updatedOpen.candidates[0].revision -or $updatedTask.description -notmatch 'explicit agreement validation' -or $updatedTask.risk -cne 'Unknown' -or $updatedTask.autoEligible -or $updatedTask.phase -cne 'Develop') { throw 'Material open requirements did not refresh the source-owned contract and restart risk/validation approval.' }
        $null = Update-HarnessState $paths { param($saved); $saved.nextQueue = @($accepted.task.id) }
        $script:verificationResponse.outcome = 'already-fixed'
        $script:verificationResponse.summary = 'The implementation and regression assertion establish the expected behavior; tests were not executed by this verifier.'
        $script:verificationResponse | Add-Member -NotePropertyMembers @{ acceptanceReviewed = $true; remainingAcceptance = @() }
        $script:verificationResponse.evidence += [pscustomobject]@{ path = $testEvidence; line = 1; quote = 'if ((Get-FixtureValue) -ne 42) { throw "Regression" }'; kind = 'test' }
        $fixedRun = Invoke-HarnessMonitor $paths fixture
        $fixedState = Read-HarnessState $paths
        if ($fixedRun.verification.status -cne 'Verified' -or $fixedState.tasks[0].status -cne 'AlreadyFixed' -or $fixedState.nextQueue.Count -or
            $fixedState.tasks[0].lastReport -cne $fixedRun.verification.report -or $fixedRun.proposal.Count) { throw "Evidence-backed verification did not reconcile local status: $($fixedRun.verification | ConvertTo-Json -Depth 8)" }
        $script:verificationResponse.outcome = 'open'
        $retained = Invoke-HarnessMonitor $paths fixture
        if ((Read-HarnessState $paths).tasks[0].status -cne 'AlreadyFixed' -or $retained.proposal.Count -or $retained.candidates[0].verification.outcome -cne 'already-fixed' -or
            $retained.candidates[0].verification.report -cne $fixedRun.verification.report) { throw 'An unchanged still-active source reopened verified completion or replaced its durable evidence.' }
        [IO.File]::WriteAllText($implementation, 'function Get-FixtureValue { 7 }')
        $script:verificationResponse.evidence[0].quote = 'function Get-FixtureValue { 7 }'
        $script:verificationResponse | Add-Member -NotePropertyMembers @{ regression = $true; changeReason = 'The implementation now returns 7 instead of the unchanged required value 42.' }
        $regression = Invoke-HarnessMonitor $paths fixture
        if ($regression.proposal.Count -ne 1 -or $regression.proposal[0].followUpOf -cne $accepted.task.id -or
            (Read-HarnessState $paths).tasks[0].status -cne 'AlreadyFixed' -or (Read-HarnessState $paths).tasks.Count -ne 1) { throw 'Changed implementation evidence failed to produce a verified regression follow-up without reopening completed history.' }
        $script:verificationResponse.PSObject.Properties.Remove('regression')
        $script:verificationResponse.PSObject.Properties.Remove('changeReason')
        [IO.File]::WriteAllText($implementation, 'function Get-FixtureValue { 42 }')
        $script:verificationResponse.evidence[0].quote = 'function Get-FixtureValue { 42 }'
        $null = Update-HarnessState $paths { param($saved); $saved.monitoring.candidates[0].PSObject.Properties.Remove('followUpOf') }
        $script:verificationResponse.outcome = 'unverified'
        $script:verificationResponse.evidence = @()
        Remove-Item -LiteralPath $testEvidence
        $unavailableProof = Invoke-HarnessMonitor $paths fixture
        if ($unavailableProof.verification.status -cne 'Unverified' -or $unavailableProof.proposal.Count -or (Read-HarnessState $paths).tasks[0].status -cne 'AlreadyFixed') { throw 'Missing completion evidence was silently reused or reopened historical work.' }
        [IO.File]::WriteAllText($testEvidence, 'if ((Get-FixtureValue) -ne 42) { throw "Regression" }')
        $script:verificationResponse.evidence = @(
            [pscustomobject]@{ path = $implementation; line = 1; quote = 'function Get-FixtureValue { 42 }'; kind = 'implementation' }
            [pscustomobject]@{ path = $testEvidence; line = 1; quote = 'if ((Get-FixtureValue) -ne 42) { throw "Regression" }'; kind = 'test' }
        )
        $script:verificationResponse.outcome = 'already-fixed'
        $null = Update-HarnessState $paths { param($saved); $saved.tasks[0].status = 'Queued' }
        $script:verificationResponse.remainingAcceptance = @('PPE validation is pending')
        $acceptancePending = Invoke-HarnessMonitor $paths fixture
        if ((Read-HarnessState $paths).tasks[0].status -cne 'Queued' -or $acceptancePending.verification.status -cne 'Unverified') { throw 'Implemented code was treated as complete while explicit acceptance remained pending.' }
        $script:verificationResponse.remainingAcceptance = @()
        [IO.File]::WriteAllText($sourceFile, "# DAS service value`nStatus: Fixed`nThe current service must return 42.")
        $script:verificationResponse.evidence[0].quote = 'invented implementation'
        $unsupported = Invoke-HarnessMonitor $paths fixture
        if ($unsupported.verification.status -cne 'Unverified' -or (Read-HarnessState $paths).tasks[0].status -cne 'Queued') { throw 'A source Closed status or fabricated code quote caused local closure.' }
        $script:verificationResponse.evidence[0].quote = 'function Get-FixtureValue { 42 }'
        $script:verificationMutation = { [IO.File]::WriteAllText($implementation, 'function Get-FixtureValue { 7 }') }
        $changed = Invoke-HarnessMonitor $paths fixture
        if ($changed.verification.status -cne 'Unverified' -or (Read-HarnessState $paths).tasks[0].status -cne 'Queued') { throw 'A changed code snapshot was used for status reconciliation.' }
        [IO.File]::WriteAllText($implementation, 'function Get-FixtureValue { 42 }')
        $script:verificationMutation = { $null = Update-HarnessState $paths { param($saved); $saved.tasks[0].priority = 5 } }
        $concurrent = Invoke-HarnessMonitor $paths fixture
        if ($concurrent.verification.status -cne 'Unverified' -or (Read-HarnessState $paths).tasks[0].priority -ne 5 -or (Read-HarnessState $paths).tasks[0].status -cne 'Queued') { throw 'Verification overwrote a concurrent human task update.' }
        $script:verificationMutation = $null
        $script:verificationResponse.outcome = 'stale'
        $script:verificationResponse.summary = 'An explicit authoritative withdrawal superseded this concern.'
        [IO.File]::WriteAllText($sourceFile, "# DAS service value`nThe owner withdrew this requirement in favor of the current value contract.")
        $script:verificationResponse.evidence = @([pscustomobject]@{ path = $sourceFile; line = 2; quote = 'The owner withdrew this requirement in favor of the current value contract.'; kind = 'authority' })
        $sourceBefore = [IO.File]::ReadAllText($sourceFile)
        $staleRun = Invoke-HarnessMonitor $paths fixture
        if ($staleRun.verification.status -cne 'Verified' -or (Read-HarnessState $paths).tasks[0].status -cne 'Stale' -or
            [IO.File]::ReadAllText($sourceFile) -cne $sourceBefore -or (Read-HarnessConfig $paths).runner.model -cne 'strong-development-model') { throw 'Stale reconciliation changed external source content or development model settings.' }
        $null = Update-HarnessState $paths { param($saved); $saved.tasks[0].status = 'AlreadyFixed' }
        [IO.File]::WriteAllText($sourceFile, "# DAS changed requirement`nThe service must now return 43, replacing the old requirement.")
        $script:verificationResponse.outcome = 'open'
        $script:verificationResponse.evidence = @([pscustomobject]@{ path = $implementation; line = 1; quote = 'function Get-FixtureValue { 42 }'; kind = 'implementation' })
        $script:verificationResponse | Add-Member -NotePropertyMembers @{ requirementChanged = $true; changeReason = 'The required return value changed from 42 to 43.' }
        $followUpRun = Invoke-HarnessMonitor $paths fixture
        if ($followUpRun.proposal.Count -ne 1 -or $followUpRun.proposal[0].followUpOf -cne $accepted.task.id -or (Read-HarnessState $paths).tasks.Count -ne 1 -or (Read-HarnessState $paths).tasks[0].status -cne 'AlreadyFixed') { throw 'Materially changed completed work was reopened or failed to produce an explicit follow-up proposal.' }
        $followUp = Add-HarnessMonitorTask $paths $followUpRun.candidates[0].id -Apply -Actor Fixture -Reason 'Accept changed requirement'
        if ($followUp.task.followUpOf -cne $accepted.task.id -or $followUp.task.autoEligible -or $followUp.task.risk -cne 'Unknown') { throw 'Follow-up acceptance bypassed task identity or execution approval.' }
        $feedPath = Join-Path $fixture 'coverage.json'
        $script:verificationDefinition = [pscustomobject]@{
            name = 'coverage'; kind = 'discovery'; source = [pscustomobject]@{ type = 'json-feed'; path = $feedPath }
            environment = 'local'; maxMinutes = 2; maxAgeMinutes = 60; verification = [pscustomobject]@{ repositoryRef = $reference.id }
        }
        $feed = [pscustomobject]@{ schemaVersion = 1; observedAt = [datetimeoffset]::UtcNow.ToString('o'); complete = $true; items = @(foreach ($number in 1..3) {
            [pscustomobject]@{ id = "work-$number"; source = "https://example.invalid/requirements/$number"; revision = 'one'; title = "Concern $number"; text = 'Current requirement'; disposition = 'Open'; priority = $number }
        }) }
        Write-HarnessJson $feedPath $feed
        $config = Read-HarnessConfig $paths
        $config.monitoring.monitors += $script:verificationDefinition
        Write-HarnessConfig $paths $config
        $reading = Get-HarnessDiscoveryResult $script:verificationDefinition $feed
        $null = Update-HarnessState $paths -Config $config -Operation {
            param($saved)
            $null = Register-HarnessDiscoveryObservation $saved $script:verificationDefinition $reading coverage-start $fixedRun.report
            foreach ($candidate in $saved.monitoring.candidates | Where-Object monitor -CEQ coverage) { $candidate | Add-Member -NotePropertyName verificationDurationMinutes -NotePropertyValue 1000.0 }
        }
        $emptyBudget = Invoke-HarnessDiscoveryVerification $paths $config $script:verificationDefinition coverage-start 0 -SourceItems $feed.items
        if ($emptyBudget.status -cne 'Partial' -or $emptyBudget.coverage.pending.Count -ne 3 -or (Get-HarnessPause $paths 'monitor:coverage')) { throw 'Normal coverage exhaustion caused a safety pause or lost pending work.' }
        $script:verificationCalls = @()
        $script:verificationResponse = [pscustomobject]@{ outcome = 'open'; summary = 'The current concern is verified open.'; evidence = @([pscustomobject]@{ path = $implementation; line = 1; quote = 'function Get-FixtureValue { 42 }'; kind = 'implementation' }) }
        $firstCoverage = Invoke-HarnessMonitor $paths coverage
        $secondCoverage = Invoke-HarnessMonitor $paths coverage
        $thirdCoverage = Invoke-HarnessMonitor $paths coverage
        if ($firstCoverage.status -cne 'Partial' -or $secondCoverage.verification.coverage.pending.Count -ne 1 -or -not $thirdCoverage.complete -or
            $thirdCoverage.proposal.Count -ne 3 -or $script:verificationCalls.Count -ne 3 -or @($script:verificationCalls | Select-Object -Unique).Count -ne 3 -or
            (Get-HarnessPause $paths 'monitor:coverage') -or (Read-HarnessState $paths).tasks.Count -ne 2) { throw 'Approved checks failed to resume pending candidates, reuse valid evidence, or preserve task intake boundaries.' }
        $config = Read-HarnessConfig $paths
        $config.monitoring.monitors = @(foreach ($name in @('source-one', 'source-two', 'independent')) {
            $source = "https://example.invalid/$name"
            $item = [pscustomobject]@{ id = $name; source = $source; revision = 'one'; title = "$name requirement"; text = 'The current contract requires 42.'; disposition = 'Open' }
            if ($name -ceq 'source-two') { $item | Add-Member -NotePropertyName sameRequirementAs -NotePropertyValue @('https://example.invalid/source-one') }
            $sourcePath = Join-Path $fixture "$name.json"
            Write-HarnessJson $sourcePath ([pscustomobject]@{ schemaVersion = 1; observedAt = [datetimeoffset]::UtcNow.ToString('o'); complete = $true; items = @($item) })
            $script:verificationByMonitor[$name] = [pscustomobject]@{ outcome = 'open'; summary = 'Current implementation evidence shows the concern remains open.'; evidence = @([pscustomobject]@{ path = $implementation; line = 1; quote = 'function Get-FixtureValue { 42 }'; kind = 'implementation' }) }
            [pscustomobject]@{ name = $name; kind = 'discovery'; source = [pscustomobject]@{ type = 'json-feed'; path = $sourcePath }; environment = 'local'; maxMinutes = 2; maxAgeMinutes = 60; verification = [pscustomobject]@{ repositoryRef = $reference.id } }
        })
        Write-HarnessConfig $paths $config
        $initialBatch = Invoke-HarnessMonitorBatch $paths
        if (-not $initialBatch.complete -or $initialBatch.proposals.Count -ne 2) { throw "The real verifier batch did not qualify one shared requirement and one unrelated item: $($initialBatch.sources | ConvertTo-Json -Depth 8)" }
        $shared = $initialBatch.proposals | Where-Object source -CEQ 'https://example.invalid/source-one'
        $sharedTask = Add-HarnessMonitorTask $paths $shared.candidateId -Apply -Actor Fixture -Reason 'Shared-source acceptance'
        $fixed = $script:verificationByMonitor['source-one']
        $fixed.outcome = 'already-fixed'
        $fixed | Add-Member -NotePropertyMembers @{ acceptanceReviewed = $true; remainingAcceptance = @() }
        $fixed.evidence += [pscustomobject]@{ path = $testEvidence; line = 1; quote = 'if ((Get-FixtureValue) -ne 42) { throw "Regression" }'; kind = 'test' }
        $conflictBatch = Invoke-HarnessMonitorBatch $paths
        if ($conflictBatch.complete -or $conflictBatch.status -cne 'Partial' -or $conflictBatch.verifiedSubset.Count -ne 1 -or
            (Get-HarnessTask (Read-HarnessState $paths) $sharedTask.task.id).status -cne 'Queued') { throw 'An earlier fixed result closed shared work before contradictory later-source evidence, or hid unrelated verified work.' }
        $config = Read-HarnessConfig $paths
        $config.monitoring | Add-Member -NotePropertyName correlations -NotePropertyValue @([pscustomobject]@{ name = 'shared-contract'; sources = @('https://example.invalid/source-one', 'https://example.invalid/source-two'); authorities = [pscustomobject]@{ completion = 'https://example.invalid/source-one' } })
        Write-HarnessConfig $paths $config
        $authorityBatch = Invoke-HarnessMonitorBatch $paths
        if (-not $authorityBatch.complete -or (Get-HarnessTask (Read-HarnessState $paths) $sharedTask.task.id).status -cne 'AlreadyFixed') { throw "Declared completion authority did not reconcile the shared task under the retained snapshots: $($authorityBatch.sources | ConvertTo-Json -Depth 8)" }
        Write-Output 'Auto verification worker checks passed: explicit auto mode, unchanged development model, read-only tools, and evidence-required result contract.'
        Write-Output 'Monitor status checks passed: service assessment, priority, checked source quotes, local closure, snapshot/task conflicts, explicit supersession, and no external writes.'
    }
    finally {
        $env:SKILLVAULT_OWNERSHIP_ROOT = $savedOwnershipRoot
        if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
    }
    return
}

if ($DiscoveryOnly) {
    $discovery = [pscustomobject]@{
        name = 'design-work'; kind = 'discovery'; environment = 'local'; maxMinutes = 1; maxAgeMinutes = 60
        source = [pscustomobject]@{ type = 'folder'; path = 'design'; include = @('*.md'); exclude = @('history/*') }
        topics = @('BI', 'DAS'); response = 'propose-task'; allowScheduled = $false
        verification = [pscustomobject]@{ enabled = $false }
    }
    $settings = [pscustomobject]@{ monitors = @($discovery) }
    Assert-HarnessMonitorSettings $settings
    $discovery.source = [pscustomobject]@{ type = 'ado'; url = 'https://dev.azure.com/example/project/_backlogs/backlog/team/Stories'; tokenEnvironment = 'HARNESS_ADO_TOKEN' }
    Assert-MonitorFailure { Assert-HarnessMonitorSettings $settings } 'explicit service scope'
    $platformScope = [pscustomobject]@{ description = 'DAS/PACS platform service including DaaP'; terms = @('DAS', 'PACS', 'DaaP') }
    $discovery | Add-Member -NotePropertyName scope -NotePropertyValue $platformScope
    Assert-HarnessMonitorSettings $settings
    if (Test-HarnessDiscoveryScope $discovery 'BI sales dashboard colors' '') { throw 'Generic BI work matched the platform-service scope.' }
    if (-not (Test-HarnessDiscoveryScope $discovery 'DaaP platform provisioning' '')) { throw 'Platform-service work was excluded.' }
    $areaScoped = [pscustomobject]@{ scope = [pscustomobject]@{ description = 'Platform service'; areaPaths = @('Example\Platform') } }
    if (-not (Test-HarnessDiscoveryScope $areaScoped 'Runtime fix' 'Example\Platform\Lifecycle') -or
        (Test-HarnessDiscoveryScope $areaScoped 'Runtime fix' 'Example\PlatformReports')) { throw 'ADO area scoping did not respect path boundaries.' }
    $discovery.source.url = 'https://dev.azure.com@example.invalid/project'
    Assert-MonitorFailure { Assert-HarnessMonitorSettings $settings } 'dev.azure.com HTTPS'
    $discovery.source = [pscustomobject]@{ type = 'json-feed'; path = 'observations/other-source.json' }
    Assert-HarnessMonitorSettings $settings
    $discovery.source | Add-Member -NotePropertyName token -NotePropertyValue 'must-not-be-saved'
    Assert-MonitorFailure { Assert-HarnessMonitorSettings $settings } 'never store credentials'
    $discovery.source.PSObject.Properties.Remove('token')
    $discovery.PSObject.Properties.Remove('scope')
    $discovery.response = 'create-task'
    Assert-MonitorFailure { Assert-HarnessMonitorSettings $settings } 'never create tasks automatically'
    $discoveryRoot = Join-Path ([IO.Path]::GetTempPath()) ('harness-discovery-' + [guid]::NewGuid().ToString('N'))
    $savedDiscoveryOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
    $env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $discoveryRoot 'ownership'
    try {
        New-Item -ItemType Directory -Path (Join-Path $discoveryRoot 'design folder/history') -Force | Out-Null
        "# DAS lock ownership`n`n**Status:** Postponed by owner; known and unfixed`n**Priority:** P1 when resumed`n- **Owner:** Taylor Example`nResume through prioritized task intake." | Set-Content (Join-Path $discoveryRoot 'design folder/deferred.md')
        "# BI provision`nStatus: Open`nPending source-policy check." | Set-Content (Join-Path $discoveryRoot 'design folder/open.md')
        "# Old DAS proposal`nStatus: Open" | Set-Content (Join-Path $discoveryRoot 'design folder/history/old.md')
        "# Availability`nStatus: Open" | Set-Content (Join-Path $discoveryRoot 'design folder/unrelated.md')
        '' | Set-Content (Join-Path $discoveryRoot 'design folder/empty.md')
        $discovery.response = 'propose-task'
        $discovery.source = [pscustomobject]@{ type = 'folder'; path = 'design folder'; exclude = @('history/*') }
        $found = Read-HarnessDiscoverySource $discovery $discoveryRoot
        if ($found.items.Count -ne 2 -or @($found.items | Where-Object disposition -EQ Deferred).Count -ne 1 -or -not $found.complete) { throw 'Folder discovery lost deferrals, ignored pruning, or matched BI inside availability.' }
        if (($found.items | Where-Object disposition -CEQ Deferred).sourceOwner -cne 'Taylor Example' -or ($found.items | Where-Object disposition -CEQ Open).sourceOwner -cne '') { throw 'Document ownership was not limited to explicit header metadata.' }
        if (@($found.items | Where-Object { -not $_.source.StartsWith('file:///') -or -not $_.revision }).Count) { throw 'Folder evidence lost stable source or revision.' }
        $sourcePaths = Get-HarnessPaths $discoveryRoot -LayoutVersion 1
        $sourceConfig = Initialize-Harness $sourcePaths
        $sourceConfig.runner.rulesPath = Join-Path $discoveryRoot 'rules.md'
        'Fixture rules: no live access.' | Set-Content $sourceConfig.runner.rulesPath
        Write-HarnessJson $sourcePaths.Config $sourceConfig
        $declarationPath = Join-Path $discoveryRoot 'sources.json'
        Write-HarnessJson $declarationPath ([pscustomobject]@{ monitors = @($discovery) })
        $null = Set-HarnessMonitorSettings $sourcePaths $declarationPath -Apply -Actor Owner -Reason 'Fixture source only'
        $sourceRun = Invoke-HarnessMonitor $sourcePaths design-work
        if ($sourceRun.status -cne 'Succeeded' -or $sourceRun.candidates.Count -ne 2 -or (Read-HarnessState $sourcePaths).tasks.Count) { throw "Discovery did not collect through the bounded runtime without auto intake: $($sourceRun.result.reason)" }
        $repeatedRun = Invoke-HarnessMonitor $sourcePaths design-work
        if (($sourceRun.candidates.id -join ',') -cne ($repeatedRun.candidates.id -join ',')) { throw 'Repeated discovery duplicated source candidates.' }
        $changedDefinition = $discovery | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $changedDefinition.source.path = 'another folder'
        Write-HarnessJson $declarationPath ([pscustomobject]@{ monitors = @($changedDefinition) })
        Assert-MonitorFailure { Set-HarnessMonitorSettings $sourcePaths $declarationPath -Apply -Actor Owner -Reason Retarget } 'new monitor name'
        $deferredCandidate = $repeatedRun.candidates | Where-Object disposition -CEQ Deferred
        if ($deferredCandidate.priority -ne 1) { throw 'Discovery lost the source backlog priority.' }
        $beforeAcceptance = [IO.File]::ReadAllText($sourcePaths.State)
        $acceptPreview = Add-HarnessMonitorTask $sourcePaths $deferredCandidate.id
        if (-not $acceptPreview.preview -or [IO.File]::ReadAllText($sourcePaths.State) -cne $beforeAcceptance) { throw 'Discovery task preview wrote state.' }
        $acceptedDeferred = Add-HarnessMonitorTask $sourcePaths $deferredCandidate.id -Apply -Actor Owner -Reason 'Prioritize discovered backlog'
        if ($acceptedDeferred.task.status -cne 'Queued' -or $acceptedDeferred.task.priority -ne 1 -or $acceptedDeferred.task.autoEligible -or $acceptedDeferred.task.risk -cne 'Unknown') { throw 'Postponed work did not enter the priority queue under the existing execution gates.' }
        $ownerRow = Import-Csv (Get-HarnessCurrentPath $sourcePaths (Read-HarnessConfig $sourcePaths)) | Where-Object id -CEQ $acceptedDeferred.task.id
        if ($acceptedDeferred.task.sourceOwner -cne 'Taylor Example' -or $ownerRow.sourceOwner -cne 'Taylor Example') { throw 'Source owner was not carried through task intake to the CSV view.' }
        $ownerDocument = Join-Path $discoveryRoot 'design folder/deferred.md'
        $ownerText = [IO.File]::ReadAllText($ownerDocument)
        [IO.File]::WriteAllText($ownerDocument, $ownerText.Replace('Taylor Example', 'Morgan Example'))
        $null = Invoke-HarnessMonitor $sourcePaths design-work
        $reassigned = Get-HarnessTask (Read-HarnessState $sourcePaths) $acceptedDeferred.task.id
        if ($reassigned.sourceOwner -cne 'Morgan Example' -or $reassigned.priority -ne 1 -or $reassigned.status -cne 'Queued') { throw 'A fresh reassignment changed task priority/status or failed to update owner metadata.' }
        $null = Invoke-HarnessMonitor $sourcePaths design-work -Scheduled
        if ((Get-HarnessTask (Read-HarnessState $sourcePaths) $acceptedDeferred.task.id).sourceOwner -cne 'Morgan Example') { throw 'A failed collection cleared the last known source owner.' }
        [IO.File]::WriteAllText($ownerDocument, $ownerText.Replace('Taylor Example', 'Unassigned'))
        $null = Invoke-HarnessMonitor $sourcePaths design-work
        if ((Get-HarnessTask (Read-HarnessState $sourcePaths) $acceptedDeferred.task.id).sourceOwner -cne '') { throw 'Fresh explicit unassignment did not clear sourceOwner.' }
        if (Select-HarnessTask (Read-HarnessState $sourcePaths)) { throw 'Discovery bypassed risk or automatic-pickup approval.' }
        $selectionState = Read-HarnessState $sourcePaths
        $selectionState.tasks[0].risk = 'Low'; $selectionState.tasks[0].autoEligible = $true
        $lowerPriority = $selectionState.tasks[0] | Select-Object *
        $lowerPriority.id = 'T-999'; $lowerPriority.priority = 3
        $selectionState.tasks = @($lowerPriority, $selectionState.tasks[0])
        if ((Select-HarnessTask $selectionState).id -cne $acceptedDeferred.task.id) { throw 'Approved postponed work was not selected by priority.' }
        $repeatAcceptance = Add-HarnessMonitorTask $sourcePaths $deferredCandidate.id -Apply -Actor Owner -Reason 'Repeat'
        if ($repeatAcceptance.task.id -cne $acceptedDeferred.task.id -or (Read-HarnessState $sourcePaths).tasks.Count -ne 1) { throw 'Repeated source acceptance duplicated the task.' }
        Remove-Item (Join-Path $discoveryRoot 'design folder/open.md')
        $missingRun = Invoke-HarnessMonitor $sourcePaths design-work
        if (@($missingRun.candidates | Where-Object disposition -CEQ Missing).Count -ne 1 -or (Get-HarnessTask (Read-HarnessState $sourcePaths) $acceptedDeferred.task.id).status -cne 'Queued') { throw 'Missing source evidence implied completion or lost the preserved task.' }
        $deniedRun = Invoke-HarnessMonitor $sourcePaths design-work -Scheduled
        if ($deniedRun.status -cne 'Blocked') { throw 'Unapproved scheduled source discovery was permitted.' }
        $feedPath = Join-Path $discoveryRoot 'feed.json'
        Write-HarnessJson $feedPath $found
        $discovery.source = [pscustomobject]@{ type = 'json-feed'; path = $feedPath }
        if ((Read-HarnessDiscoverySource $discovery $discoveryRoot).items.Count -ne 2) { throw 'Another adapter cannot supply the normalized discovery feed.' }
        $feedDefinition = $discovery | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $feedDefinition.name = 'adapter-work'
        Write-HarnessJson $declarationPath ([pscustomobject]@{ monitors = @($feedDefinition) })
        $null = Set-HarnessMonitorSettings $sourcePaths $declarationPath -Apply -Actor Owner -Reason 'Fixture adapter only'
        $feedRun = Invoke-HarnessMonitor $sourcePaths adapter-work
        if ($feedRun.status -cne 'Succeeded' -or $feedRun.candidates.Count -ne 2 -or (Read-HarnessState $sourcePaths).tasks.Count -ne 1) { throw 'The bounded adapter reader lost its candidates or created tasks.' }
        if (($feedRun.candidates | Where-Object disposition -CEQ Deferred).sourceOwner -cne 'Taylor Example') { throw 'Adapter sourceOwner evidence was not retained.' }
        'private fixture malformed feed' | Set-Content $feedPath
        $failedFeed = Invoke-HarnessMonitor $sourcePaths adapter-work
        if ($failedFeed.status -cne 'Failed' -or ($failedFeed.candidates.disposition -join ',') -cne ($feedRun.candidates.disposition -join ',') -or
            [IO.File]::ReadAllText($failedFeed.report) -match 'private fixture malformed feed') { throw 'Failed adapter collection changed candidates or leaked raw input.' }
        if (($failedFeed.candidates | Where-Object disposition -CEQ Deferred).sourceOwner -cne 'Taylor Example') { throw 'A failed feed discarded previously captured owner evidence.' }
        $unaccepted = $feedRun.candidates | Where-Object disposition -CEQ Open
        Assert-MonitorFailure { Add-HarnessMonitorTask $sourcePaths $unaccepted.id -Apply -Actor Owner -Reason 'Stale preview' } 'fresh complete discovery evidence'
        Write-HarnessJson $feedPath $found
        $noAuthDefinition = $feedDefinition | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $noAuthDefinition.name = 'ado-access'
        $noAuthDefinition.source = [pscustomobject]@{ type = 'ado'; url = 'https://dev.azure.com/example/project/_backlogs/backlog/team/Stories'; tokenEnvironment = 'HARNESS_TEST_MISSING_' + [guid]::NewGuid().ToString('N') }
        $noAuthDefinition | Add-Member -NotePropertyName scope -NotePropertyValue $platformScope
        Write-HarnessJson $declarationPath ([pscustomobject]@{ monitors = @($noAuthDefinition) })
        $null = Set-HarnessMonitorSettings $sourcePaths $declarationPath -Apply -Actor Owner -Reason 'Fixture missing credential only'
        $noAuthRun = Invoke-HarnessMonitor $sourcePaths ado-access
        if ($noAuthRun.status -cne 'Blocked' -or $noAuthRun.candidates.Count -ne 0 -or $noAuthRun.assessment.status -cne 'AwaitingCollection' -or (Read-HarnessState $sourcePaths).active) { throw 'Missing ADO authentication did not block safely.' }
        $unknownFolder = Join-Path $discoveryRoot 'status examples'
        New-Item -ItemType Directory -Path $unknownFolder | Out-Null
        "# DAS example`nAuthor: Not The Owner`n## Sample`nStatus: Fixed`nOwner: Example Only" | Set-Content (Join-Path $unknownFolder 'example.md')
        $unknownDefinition = [pscustomobject]@{ source = [pscustomobject]@{ type = 'folder'; path = $unknownFolder }; topics = @() }
        if ((Read-HarnessFolderDiscovery $unknownDefinition $discoveryRoot).items[0].disposition -cne 'Unknown') { throw 'A status example inside a document section was mistaken for authoritative metadata.' }
        if ((Read-HarnessFolderDiscovery $unknownDefinition $discoveryRoot).items[0].sourceOwner -cne '') { throw 'An author or section example was guessed as the source owner.' }
        $sectionText = "# DAS design`nOwner: Source Owner`n## Mapping agreement`nEntityMappings are duplicated across producers.`n## Representative selection`nThe representative depends on enumeration order.`n~~~text`n## Not a section`n~~~"
        $sections = @(Get-HarnessDocumentSections $sectionText 'DAS design')
        if ($sections.Count -ne 3 -or $sections[0].id -cne '#overview' -or $sections[1].id -cne '#mapping-agreement' -or $sections[1].text -notmatch 'EntityMappings' -or $sections[2].text -notmatch 'enumeration order') { throw 'Owning-section discovery missed introductory context, implicit design debt, or parsed a code example as a section.' }
        $linkPath = Join-Path $discoveryRoot 'linked folder'
        $linkKind = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $linkKind -Path $linkPath -Target $unknownFolder | Out-Null
        try { Assert-MonitorFailure { Assert-HarnessDiscoveryPath $linkPath $null $discoveryRoot } 'does not follow linked' }
        finally { Remove-Item -LiteralPath $linkPath -Force }
        $partial = $found | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $partial.complete = $false
        $badReading = Get-HarnessDiscoveryResult $discovery $partial
        $savedDiscoveryState = Read-HarnessState $sourcePaths
        $candidateStates = @($savedDiscoveryState.monitoring.candidates.disposition) -join ','
        $null = Register-HarnessDiscoveryObservation $savedDiscoveryState $discovery $badReading partial 'partial.md'
        if ($badReading.status -cne 'Blocked' -or ($savedDiscoveryState.monitoring.candidates.disposition -join ',') -cne $candidateStates) { throw 'A partial adapter feed changed existing candidate dispositions.' }
        if (($savedDiscoveryState.monitoring.candidates | Where-Object { $_.monitor -ceq 'adapter-work' -and $_.disposition -ceq 'Deferred' }).sourceOwner -cne 'Taylor Example') { throw 'A partial collection cleared a known owner.' }
        $oldFeed = $found | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $oldFeed.observedAt = [datetimeoffset]::UtcNow.AddHours(-2).ToString('o')
        if ((Get-HarnessDiscoveryResult $discovery $oldFeed).status -cne 'Blocked') { throw 'Stale discovery evidence was accepted.' }
        $badIdentity = $found | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $badIdentity.observedAt = [datetimeoffset]::UtcNow.ToString('o')
        $badIdentity.items[0].source = 'https://example.invalid/different-item'
        $identityReading = Get-HarnessDiscoveryResult $discovery $badIdentity
        $null = Register-HarnessDiscoveryObservation $savedDiscoveryState $discovery $identityReading identity 'identity.md'
        if ($identityReading.status -cne 'Blocked' -or ($savedDiscoveryState.monitoring.candidates.disposition -join ',') -cne $candidateStates) { throw 'An adapter silently retargeted an existing candidate.' }
        Assert-MonitorFailure { Invoke-HarnessAdoRead ([pscustomobject]@{ tokenEnvironment = 'HARNESS_TEST_MISSING_' + [guid]::NewGuid().ToString('N') }) 'https://dev.azure.com/example/project/_apis/work/backlogs?api-version=7.1' } 'existing Entra bearer token'
        $global:discoveryRequests = @()
        $global:discoveryFixtureIds = @([long]42)
        $global:discoveryOmitItem = $false
        $global:discoveryFixtureFields = @{}
        $global:discoveryRelations = @{}
        $global:discoveryRootIds = @()
        function Invoke-HarnessAdoRead {
            param($Source, $Uri, $Body)
            $global:discoveryRequests += $Uri
            if ($Uri -match '/backlogs\?') { return [pscustomobject]@{ value = @([pscustomobject]@{ id = 'Microsoft.RequirementCategory'; name = 'Stories'; workItemCountLimit = 1000 }) } }
            if ($Uri -match '/workItems\?') { return [pscustomobject]@{ workItems = @($(if ($global:discoveryRootIds.Count) { $global:discoveryRootIds } else { $global:discoveryFixtureIds }) | ForEach-Object { [pscustomobject]@{ target = [pscustomobject]@{ id = $_ } } }) } }
            if ($Uri -match '/wiql/') { return [pscustomobject]@{ workItems = @($global:discoveryFixtureIds | ForEach-Object { [pscustomobject]@{ id = $_ } }) } }
            if ($Uri -match '/workitemsbatch\?') {
                if ($Body.ids.Count -gt 200 -or @($Body.ids | Where-Object { $_ -notin $global:discoveryFixtureIds }).Count -or $Body.errorPolicy -cne 'Fail') { throw 'ADO batch changed membership or permitted silent omissions.' }
                return [pscustomobject]@{ value = @(foreach ($workItemId in $Body.ids) {
                    if ($global:discoveryOmitItem -and $workItemId -eq $Body.ids[0]) { continue }
                    $fields = if ($global:discoveryFixtureFields.ContainsKey([int]$workItemId)) { $global:discoveryFixtureFields[[int]$workItemId] } else { @{ 'System.Title' = 'DAS source discovery'; 'System.State' = 'New'; 'System.Tags' = 'BI; Postponed'; 'Microsoft.VSTS.Common.Priority' = 2; 'System.AssignedTo' = [pscustomobject]@{ displayName = 'Alex Example'; uniqueName = 'private@example.invalid' } } }
                    [pscustomobject]@{ id = $workItemId; rev = 3; fields = $fields; relations = @($global:discoveryRelations[[int]$workItemId]) }
                }) }
            }
            throw 'Unexpected fixture ADO request.'
        }
        $discovery.source = [pscustomobject]@{ type = 'ado'; url = 'https://dev.azure.com/example/project/_backlogs/backlog/team/Stories' }
        $discovery | Add-Member -NotePropertyName scope -NotePropertyValue $platformScope
        $ado = Read-HarnessDiscoverySource $discovery $discoveryRoot
        if ($ado.items.Count -ne 1 -or $ado.items[0].source -cne 'https://dev.azure.com/example/project/_workitems/edit/42' -or $ado.items[0].revision -cne '3' -or $ado.items[0].disposition -cne 'Deferred' -or $ado.items[0].priority -ne 2 -or $global:discoveryRequests.Count -ne 3) { throw 'ADO discovery lost exact backlog membership, work-item identity, priority, or source disposition.' }
        if ($ado.items[0].sourceOwner -cne 'Alex Example') { throw 'ADO ownership did not use the explicit assignment display name.' }
        $global:discoveryFixtureIds = @(42, 43, 44)
        $global:discoveryRootIds = @(42)
        $global:discoveryRelations = @{
            42 = @([pscustomobject]@{ rel = 'System.LinkTypes.Hierarchy-Forward'; url = 'https://dev.azure.com/example/project/_apis/wit/workItems/43' })
            43 = @([pscustomobject]@{ rel = 'System.LinkTypes.Hierarchy-Forward'; url = 'https://dev.azure.com/example/project/_apis/wit/workItems/44' })
            44 = @([pscustomobject]@{ rel = 'System.LinkTypes.Hierarchy-Forward'; url = 'https://dev.azure.com/example/project/_apis/wit/workItems/42' })
        }
        $global:discoveryFixtureFields[44] = @{ 'System.Title' = 'DAS completed child'; 'System.State' = 'Closed'; 'Microsoft.VSTS.Common.AcceptanceCriteria' = 'PPE validation required' }
        $expanded = Read-HarnessAdoDiscovery $discovery
        if ($expanded.items.Count -ne 3 -or $expanded.diagnostics.containers -ne 3 -or $expanded.diagnostics.terminal -ne 1 -or $expanded.diagnostics.descendants -ne 2 -or
            ($expanded.items | Where-Object id -CEQ '44').acceptance -cne 'PPE validation required' -or -not ($expanded.items | Where-Object id -CEQ '43').parentContext) { throw 'ADO hierarchy traversal lost child identity, acceptance, terminal classification, or parent context.' }
        $global:discoveryRelations = @{}
        $global:discoveryRootIds = @()
        $global:discoveryFixtureIds = @(42, 43, 44)
        $global:discoveryFixtureFields = @{
            43 = @{ 'System.Title' = 'BI report colors'; 'System.State' = 'New'; 'System.Tags' = 'BI' }
            44 = @{ 'System.Title' = 'DaaP PACS platform lifecycle'; 'System.State' = 'Active'; 'System.Tags' = 'Platform'; 'Microsoft.VSTS.Common.Priority' = 1 }
        }
        $scopeOnly = $discovery | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $scopeOnly.topics = @()
        $narrowReading = Read-HarnessAdoDiscovery $scopeOnly
        if (($narrowReading.items.id -join ',') -cne '42,44') { throw 'ADO collection included general BI work or excluded DaaP/PACS platform work.' }
        if (($narrowReading.items | Where-Object id -CEQ '44').sourceOwner -cne '') { throw 'An unassigned ADO item acquired a guessed owner.' }
        $global:discoveryFixtureFields = @{}
        $discovery.source.url = 'https://dev.azure.com/example/project/_queries/query/11111111-1111-1111-1111-111111111111'
        $global:discoveryFixtureIds = @(1..201)
        $global:discoveryRequests = @()
        $queryReading = Read-HarnessAdoDiscovery $discovery
        if ($queryReading.items.Count -ne 201 -or @($global:discoveryRequests | Where-Object { $_ -match '/workitemsbatch\?' }).Count -ne 2) { throw 'Saved-query discovery did not preserve all members across 200-item batches.' }
        $global:discoveryOmitItem = $true
        Assert-MonitorFailure { Read-HarnessAdoDiscovery $discovery } 'every selected work item'
        Assert-MonitorFailure { Get-HarnessAdoSource 'https://dev.azure.com/example/project/_workitems/edit/42' } 'backlog or saved-query'
        $invalidPriority = $found | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $invalidPriority.items[0].priority = 0
        if ((Get-HarnessDiscoveryResult $discovery $invalidPriority).status -cne 'Blocked') { throw 'Out-of-range source priority was accepted.' }
        $invalidOwner = $found | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $invalidOwner.items[0].sourceOwner = [pscustomobject]@{ author = 'Not an owner' }
        if ((Get-HarnessDiscoveryResult $discovery $invalidOwner).status -cne 'Blocked') { throw 'A feed bypassed the normalized owner contract.' }
        if ((Get-HarnessSourceOwner ([pscustomobject]@{ uniqueName = 'not-a-display-name' })) -cne '' -or (Get-HarnessSourceOwner ' N/A ') -cne '') { throw 'Missing owner evidence was guessed from an unrelated identity field.' }
        if ((Get-HarnessDiscoveryDisposition 'On Hold for dependency') -cne 'Blocked' -or (Get-HarnessDiscoveryDisposition 'Postponed') -cne 'Deferred') { throw 'Historical postponement was conflated with a current blocker.' }
        if ((Get-HarnessDiscoveryDisposition 'On-Hold') -cne 'Deferred') { throw 'A generic On-Hold label became a permanent execution block without dependency evidence.' }
        $blockedFeed = $found | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $blockedFeed.items = @($blockedFeed.items[0])
        $blockedFeed.items[0].id = 'current-blocker'
        $blockedFeed.items[0].source = 'https://example.invalid/work/current-blocker'
        $blockedFeed.items[0].disposition = 'Blocked'
        $blockedFeed.items[0].priority = 1
        $blockedFeed.observedAt = [datetimeoffset]::UtcNow.ToString('o')
        Write-HarnessJson $feedPath $blockedFeed
        $blockedDefinition = $feedDefinition | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $blockedDefinition.name = 'blocked-work'
        Write-HarnessJson $declarationPath ([pscustomobject]@{ monitors = @($blockedDefinition) })
        $null = Set-HarnessMonitorSettings $sourcePaths $declarationPath -Apply -Actor Owner -Reason 'Fixture blocker only'
        $blockedRun = Invoke-HarnessMonitor $sourcePaths blocked-work
        $blockedTask = Add-HarnessMonitorTask $sourcePaths $blockedRun.candidates[0].id -Apply -Actor Owner -Reason 'Track actual dependency'
        if ($blockedTask.task.status -cne 'Blocked' -or $blockedTask.task.priority -ne 1) { throw 'Priority incorrectly bypassed a current source blocker.' }
        $scopedDefinition = $feedDefinition | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $scopedDefinition.name = 'platform-work'
        $scopedDefinition.topics = @()
        $scopedDefinition | Add-Member -NotePropertyName scope -NotePropertyValue $platformScope
        $scopedFeed = $found | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $scopedFeed.observedAt = [datetimeoffset]::UtcNow.ToString('o')
        $scopedFeed.items[0].title = 'DaaP platform lifecycle fix'
        $scopedFeed.items[0].text = 'PACS-owned provisioning handler has an unresolved DaaP lifecycle concern.'
        $scopedFeed.items[0].source = 'https://example.invalid/platform/1'
        $scopedFeed.items[1].title = 'DAS consumer report colors'
        $scopedFeed.items[1].text = 'The report consumes DAS output but does not change the platform service.'
        $scopedFeed.items[1].source = 'https://example.invalid/reports/2'
        Write-HarnessJson $feedPath $scopedFeed
        Write-HarnessJson $declarationPath ([pscustomobject]@{ monitors = @($scopedDefinition) })
        $null = Set-HarnessMonitorSettings $sourcePaths $declarationPath -Apply -Actor Owner -Reason 'Fixture platform scope'
        $scopedRun = Invoke-HarnessMonitor $sourcePaths platform-work
        if ($scopedRun.candidates.Count -ne 2 -or @($scopedRun.proposal).Count -or $scopedRun.assessment.status -cne 'NeedsAssessment') { throw 'Keyword matches were treated as assessed relevant work.' }
        $assessmentPath = Join-Path $discoveryRoot 'assessment.json'
        $assessments = @(
            [pscustomobject]@{ candidateId = $scopedRun.candidates[0].id; scope = $platformScope.description; sourceRevision = $scopedRun.candidates[0].revision; relevance = 'Relevant'; reason = 'Direct change to the PACS-owned provisioning lifecycle.'; priority = 1; priorityReason = 'Blocks platform provisioning; fix before lower-impact cleanup.' },
            [pscustomobject]@{ candidateId = $scopedRun.candidates[1].id; scope = $platformScope.description; sourceRevision = $scopedRun.candidates[1].revision; relevance = 'NotRelevant'; reason = 'Downstream visual change, not platform-service work.' }
        )
        $policyDefinition = $scopedDefinition | ConvertTo-Json -Depth 15 | ConvertFrom-Json
        $policyDefinition.scope | Add-Member -NotePropertyMembers @{ excludedCategories = @('security-compliance', 'operations'); priorityFloors = [pscustomobject]@{ reporting = 4; realtime = 4 } }
        $policyAssessment = $assessments[0] | Select-Object *
        $policyAssessment | Add-Member -NotePropertyMembers @{ category = 'reporting'; classification = 'Deferred'; blockers = @() }
        $prioritized = ConvertTo-HarnessDiscoveryAssessment $policyAssessment $policyDefinition $policyAssessment.sourceRevision
        if ($prioritized.priority -ne 4 -or $prioritized.classification -cne 'Deferred') { throw 'Declared local priority policy discarded deferred reporting or ignored its priority floor.' }
        $policyAssessment.category = 'security-compliance'
        if ((ConvertTo-HarnessDiscoveryAssessment $policyAssessment $policyDefinition $policyAssessment.sourceRevision).relevance -cne 'NotRelevant') { throw 'An explicit local category exclusion was ignored.' }
        $policyAssessment.category = 'platform-defect'
        if ((ConvertTo-HarnessDiscoveryAssessment $policyAssessment $policyDefinition $policyAssessment.sourceRevision).priority -ne 1) { throw 'A reporting policy incorrectly demoted a platform-service defect.' }
        $assessmentInput = [pscustomobject]@{ monitor = 'platform-work'; runId = $scopedRun.candidates[0].lastRunId; assessments = $assessments }
        Write-HarnessJson $assessmentPath $assessmentInput
        $beforeAssessment = [IO.File]::ReadAllText($sourcePaths.State)
        $assessmentPreview = Set-HarnessDiscoveryAssessment $sourcePaths platform-work $assessmentPath
        if (-not $assessmentPreview.preview -or [IO.File]::ReadAllText($sourcePaths.State) -cne $beforeAssessment) { throw 'Assessment preview changed state.' }
        $dispatcher = Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness.ps1'
        $assessed = & $dispatcher -ProjectPath $discoveryRoot -Action MonitorAssess -MonitorName platform-work -DefinitionPath $assessmentPath -Apply | ConvertFrom-Json
        if ($assessed.proposals.Count -ne 1 -or $assessed.proposals[0].priority -ne 1 -or -not $assessed.proposals[0].relevanceReason -or $assessed.assessment.status -cne 'Assessed') { throw 'Relevance/priority assessment failed to produce the narrow ranked proposal.' }
        $rankedView = Get-HarnessMonitorView $sourcePaths
        if ($rankedView.assessments.Count -ne 2 -or @($rankedView.proposals | Where-Object candidateId -EQ $scopedRun.candidates[1].id).Count) { throw 'The monitor view lost assessment status or offered irrelevant work.' }
        $sameRevision = Invoke-HarnessMonitor $sourcePaths platform-work
        if (@($sameRevision.proposal).Count -ne 1) { throw 'An unchanged source unnecessarily lost its assessment.' }
        Assert-MonitorFailure { Add-HarnessMonitorTask $sourcePaths $scopedRun.candidates[1].id -Apply -Actor Owner -Reason 'Not relevant' } 'no pending task proposal'
        $oldConfig = Read-HarnessConfig $sourcePaths
        $legacyAdo = $noAuthDefinition | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $legacyAdo.name = 'legacy-unscoped'
        $legacyAdo.PSObject.Properties.Remove('scope')
        $oldConfig.monitoring.monitors += $legacyAdo
        Write-HarnessJson $sourcePaths.Config $oldConfig
        $legacyCandidate = $scopedRun.candidates[0] | Select-Object *
        $legacyCandidate.monitor = 'legacy-unscoped'
        if (Get-HarnessDiscoveryProposal $oldConfig $legacyCandidate) { throw 'Old unscoped ADO candidates remained eligible for intake.' }
        $legacyCandidate.monitor = 'adapter-work'
        $legacyCandidate.source = 'https://dev.azure.com/example/project/_workitems/edit/42'
        if (Get-HarnessDiscoveryProposal $oldConfig $legacyCandidate) { throw 'Old ADO feed candidates bypassed service scoping.' }
        $unscopedAdoFeed = $found | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $unscopedAdoFeed.items[0].source = 'https://dev.azure.com/example/project/_workitems/edit/42'
        $unscopedReading = Get-HarnessDiscoveryResult $feedDefinition $unscopedAdoFeed
        if ($unscopedReading.status -cne 'Blocked' -or $unscopedReading.reason -notlike '*explicit service scope*') { throw 'An adapter feed bypassed ADO service scoping.' }
        if ((Get-HarnessMonitorDefinition $oldConfig platform-work).name -cne 'platform-work') { throw 'An old unscoped ADO definition poisoned unrelated monitor lookup.' }
        $legacyRun = Invoke-HarnessMonitor $sourcePaths legacy-unscoped
        if ($legacyRun.status -cne 'Blocked' -or $legacyRun.result.reason -notlike '*explicit service scope*') { throw 'An old unscoped ADO source continued broad collection.' }
        $newScopedDefinition = $scopedDefinition | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $newScopedDefinition.name = 'new-scoped-work'
        Write-HarnessJson $declarationPath ([pscustomobject]@{ monitors = @($newScopedDefinition) })
        $null = Set-HarnessMonitorSettings $sourcePaths $declarationPath -Apply -Actor Owner -Reason 'Narrow replacement'
        if ((Get-HarnessMonitorDefinition (Read-HarnessConfig $sourcePaths) new-scoped-work).name -cne 'new-scoped-work') { throw 'An old monitor prevented declaring its scoped replacement.' }
        $adapterAssessment = $assessments[0] | Select-Object scope, sourceRevision, relevance, reason, priority, priorityReason
        $scopedFeed.items[0] | Add-Member -NotePropertyName assessment -NotePropertyValue $adapterAssessment
        $adapterResult = Get-HarnessDiscoveryResult $scopedDefinition $scopedFeed
        if ($adapterResult.status -cne 'Succeeded' -or $adapterResult.items[0].assessment.relevance -cne 'Relevant') { throw 'A reviewed adapter assessment was not retained.' }
        $scopedFeed.items[0].assessment.sourceRevision = 'wrong-revision'
        if ((Get-HarnessDiscoveryResult $scopedDefinition $scopedFeed).status -cne 'Blocked') { throw 'An adapter assessment was accepted for a different source revision.' }
        $scopedFeed.items[0].PSObject.Properties.Remove('assessment')
        $scopedFeed.items[0].revision = 'changed-revision'
        $scopedFeed.observedAt = [datetimeoffset]::UtcNow.ToString('o')
        Write-HarnessJson $feedPath $scopedFeed
        $newRevision = Invoke-HarnessMonitor $sourcePaths platform-work
        if (@($newRevision.proposal).Count) { throw 'Changed source content reused an old relevance assessment.' }
        Assert-MonitorFailure { Set-HarnessDiscoveryAssessment $sourcePaths platform-work $assessmentPath -Apply } 'latest fresh successful collection'
    }
    finally {
        $env:SKILLVAULT_OWNERSHIP_ROOT = $savedDiscoveryOwnershipRoot
        Remove-Item -LiteralPath $discoveryRoot -Recurse -Force
        Remove-Variable discoveryRequests, discoveryFixtureIds, discoveryOmitItem, discoveryFixtureFields, discoveryRelations, discoveryRootIds -Scope Global -ErrorAction SilentlyContinue
    }
    Write-Output 'Discovery checks passed: declarations, folder evidence and deferrals, adapter feeds, and mocked ADO backlog collection.'
    return
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
    $paths = Get-HarnessPaths $fixtureRoot -LayoutVersion 1
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