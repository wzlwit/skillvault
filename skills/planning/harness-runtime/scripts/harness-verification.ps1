function New-HarnessVerificationSnapshot {
    param($Paths, $Config, $Authority, [string]$RepositoryRoot, [string]$MonitorName, [double]$MaxMinutes)
    Assert-HarnessRestrictions -Config $Config -ProjectRoot $Paths.Project -Workspace $RepositoryRoot -Executable git
    $root = Join-Path $Paths.Control ('runtime/verification/' + [guid]::NewGuid().ToString('N'))
    $workspace = Join-Path $root 'checkout'
    Assert-HarnessRestrictions -Config $Config -ProjectRoot $Paths.Project -Workspace $workspace -Executable git
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $snapshotConfig = $Config | ConvertTo-Json -Depth 30 | ConvertFrom-Json -NoEnumerate
    $snapshotConfig.runner.maxMinutes = Get-HarnessExecutionLimit $Config maxProcessMinutes $MaxMinutes
    $context = [pscustomobject]@{ Paths = $Paths; Config = $snapshotConfig; Targets = @('monitor:' + $MonitorName); Environment = @{ GIT_TERMINAL_PROMPT = '0'; GCM_INTERACTIVE = 'Never' } }
    $invoke = {
        param([string]$Directory, [string[]]$Arguments)
        $remainingMinutes = $MaxMinutes - $clock.Elapsed.TotalMinutes
        if ($remainingMinutes -le 0) { Stop-HarnessBudget 'Authoritative repository inspection exhausted the monitor budget.' }
        $context.Config.runner.maxMinutes = Get-HarnessExecutionLimit $Config maxProcessMinutes $remainingMinutes
        Invoke-HarnessGit $Directory $Arguments -Context $context
    }
    try {
        $url = [string](& $invoke $RepositoryRoot @('remote', 'get-url', '--', $Authority.remote))
        $uri = $null
        if (-not [uri]::TryCreate($url, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -cne 'https' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) { throw 'Authoritative repository evidence requires the selected remote to be HTTPS without embedded credentials.' }
        $null = & $invoke $RepositoryRoot @('check-ref-format', "refs/heads/$($Authority.branch)")
        New-Item -ItemType Directory -Path $workspace -Force | Out-Null
        $template = Join-Path $root 'git-control'
        New-Item -ItemType Directory -Path $template | Out-Null
        $emptyConfig = Join-Path $template 'config'
        [IO.File]::WriteAllText($emptyConfig, '')
        $context.Environment = @{ GIT_CONFIG_GLOBAL = $emptyConfig; GIT_CONFIG_SYSTEM = $emptyConfig; GIT_CONFIG_NOSYSTEM = '1'; GIT_CONFIG_COUNT = '0'; GIT_CONFIG_PARAMETERS = ''; GIT_ATTR_NOSYSTEM = '1'; GIT_TERMINAL_PROMPT = '0'; GCM_INTERACTIVE = 'Never' }
        $options = @('-c', "core.hooksPath=$template", '-c', 'core.fsmonitor=false', '-c', 'core.symlinks=false', '-c', 'protocol.file.allow=never', '-c', 'credential.helper=')
        if ($Authority.credentialHelper -ceq 'manager') { $options += @('-c', 'credential.helper=manager') }
        if ($Authority.credentialHelper -ceq 'gh') {
            Assert-HarnessRestrictions -Config $Config -ProjectRoot $Paths.Project -Workspace $workspace -Executable gh
            $options += @('-c', 'credential.helper=!gh auth git-credential')
        }
        $null = & $invoke $workspace ($options + @('init', '--quiet', "--template=$template"))
        $null = & $invoke $workspace ($options + @('fetch', '--quiet', '--no-tags', '--no-recurse-submodules', '--no-write-fetch-head', $url, "+refs/heads/$($Authority.branch):refs/monitor/authority"))
        $commit = [string](& $invoke $workspace @('rev-parse', '--verify', 'refs/monitor/authority^{commit}'))
        if ($commit -cnotmatch '^[a-f0-9]{40,64}$') { throw 'The authoritative branch commit could not be verified.' }
        $remoteHead = [string](& $invoke $workspace ($options + @('ls-remote', '--exit-code', $url, "refs/heads/$($Authority.branch)")))
        if (($remoteHead -split '\s+')[0] -cne $commit) { throw 'The remote branch changed while preparing evidence; retry on a stable revision.' }
        $null = & $invoke $workspace ($options + @('checkout', '--quiet', '--detach', $commit))
        [pscustomobject]@{ root = $root; workspace = $workspace; gitContext = $context; authority = [pscustomobject]@{ remote = $Authority.remote; url = $url; branch = $Authority.branch; commit = $commit; observedAt = [datetimeoffset]::UtcNow.ToString('o') } }
    }
    catch {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        throw
    }
}

function Test-HarnessVerificationPath {
    param([string]$Path, [string[]]$Roots)
    foreach ($root in $Roots) {
        $relative = [IO.Path]::GetRelativePath($root, $Path)
        if (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and -not $relative.StartsWith('..' + [IO.Path]::DirectorySeparatorChar)) { return $true }
    }
    $false
}

function Confirm-HarnessVerificationEvidence {
    param($Payload, $Config, $Paths, [string]$Workspace, [string[]]$Roots, [bool]$HasRepository)
    $evidence = @(
        foreach ($entry in $Payload.evidence) {
            $path = [IO.Path]::GetFullPath([string]$entry.path, $Workspace)
            if (-not (Test-HarnessVerificationPath $path $Roots)) { throw 'Verification cited evidence outside its approved roots.' }
            $null = Assert-HarnessDiscoveryPath $path $Config $Paths.Project
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Verification cited unavailable evidence.' }
            $lines = [IO.File]::ReadAllLines($path)
            if ($entry.line -gt $lines.Count -or $lines[$entry.line - 1] -cne $entry.quote) { throw 'Verification evidence does not match the cited source line.' }
            if ($entry.kind -in @('implementation', 'test') -and (-not $HasRepository -or -not (Test-HarnessVerificationPath $path @($Workspace)))) { throw 'Implementation and test evidence require the selected repository snapshot.' }
            [pscustomobject]@{
                path = $path; line = $entry.line; quote = $entry.quote; kind = $entry.kind
                hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
                repositoryPath = $(if ($HasRepository -and (Test-HarnessVerificationPath $path @($Workspace))) { [IO.Path]::GetRelativePath($Workspace, $path) })
            }
        }
    )
    if ($Payload.outcome -ceq 'already-fixed' -and ('implementation' -cnotin $evidence.kind -or
        -not @($evidence | Where-Object { $_.kind -in @('test', 'authority') -and $_.path -cnotin @($evidence | Where-Object kind -CEQ implementation | ForEach-Object path) }).Count)) { throw 'Already-fixed requires implementation and independent test or authority evidence.' }
    if ($Payload.outcome -ceq 'stale' -and -not @($evidence | Where-Object { $_.kind -ceq 'authority' -and $_.quote -notmatch '^\s*\*{0,2}Status\*{0,2}\s*:' }).Count) { throw 'Stale requires an authoritative supersession or withdrawal, not a source status alone.' }
    $evidence
}

function Get-HarnessVerificationEvidenceState {
    param($Record, $Config, $Paths, [string]$Workspace, [string[]]$Roots, [string]$Snapshot)
    $current = [Collections.Generic.List[object]]::new()
    if (-not @($Record.evidence).Count -or -not $Record.report -or -not (Test-Path -LiteralPath $Record.report -PathType Leaf)) {
        return [pscustomobject]@{ status = 'Unavailable'; evidence = @() }
    }
    $status = if ($Record.snapshot -ceq $Snapshot) { 'Current' } else { 'Changed' }
    foreach ($proof in $Record.evidence) {
        $path = if ($proof.repositoryPath) { [IO.Path]::GetFullPath($proof.repositoryPath, $Workspace) } else { [string]$proof.path }
        if (-not $path -or -not (Test-HarnessVerificationPath $path $Roots)) { return [pscustomobject]@{ status = 'Unavailable'; evidence = @() } }
        $null = Assert-HarnessDiscoveryPath $path $Config $Paths.Project
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return [pscustomobject]@{ status = 'Unavailable'; evidence = @() } }
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash -cne $proof.hash) { $status = 'Changed' }
        $rebased = $proof | Select-Object *
        $rebased.path = $path
        $current.Add($rebased)
    }
    [pscustomobject]@{ status = $status; evidence = @($current) }
}

function Invoke-HarnessDiscoveryVerification {
    param($Paths, $Config, $Definition, [string]$CollectionRunId, [double]$MaxMinutes, [object[]]$SourceItems, [object[]]$CollectedSources, $BatchVerification)
    if ($Definition.verification.enabled -eq $false) { return [pscustomobject]@{ status = 'Disabled'; model = 'auto'; outcomes = @(); report = '' } }
    $target = 'monitor:' + $Definition.name
    $baseContract = [ordered]@{ source = Get-HarnessMonitorContract $Definition; repositoryRef = $Definition.verification.repositoryRef; authority = $Definition.verification.authority; correlations = @($Config.monitoring.correlations | Where-Object { $_ }) } | ConvertTo-Json -Depth 15 -Compress
    $state = Read-HarnessState $Paths
    $latest = $state.monitoring.latest | Where-Object monitor -CEQ $Definition.name | Select-Object -First 1
    if ($latest.runId -cne $CollectionRunId -or $latest.result.status -cne 'Succeeded' -or
        ([datetimeoffset]::UtcNow - (ConvertTo-HarnessMonitorTime $latest.result.observedAt)).TotalMinutes -gt $Definition.maxAgeMinutes) { return [pscustomobject]@{ status = 'AwaitingCollection'; model = 'auto'; outcomes = @(); report = '' } }
    $progress = @($state.monitoring.coverage | Where-Object monitor -CEQ $Definition.name) | Select-Object -First 1
    $resuming = @($progress.pending | Where-Object { $_ }).Count -gt 0
    $candidates = @($state.monitoring.candidates | Where-Object monitor -CEQ $Definition.name | Sort-Object @{
        Expression = { if ($_.id -cin $progress.pending -or -not $_.verificationCheckpoint -or $_.verificationCheckpoint.sourceRevision -cne $_.revision) { 0 } else { 1 } }
    }, @{ Expression = { if ($_.verificationAttemptedRevision -ceq $_.revision) { [string]$_.verificationAttemptedAt } else { '' } } }, priority, id)
    if (-not $candidates.Count) { return [pscustomobject]@{ status = 'NoCandidates'; model = 'auto'; outcomes = @(); report = '' } }
    if ($state.active) { throw 'Recover active work before verifying source status.' }
    $runId = [guid]::NewGuid().ToString('N')
    $startedAt = [datetimeoffset]::UtcNow
    $reportPath = Get-HarnessReportPath $Paths $Config $runId Verify $startedAt
    $ownership = Enter-HarnessOwnership -Paths $Paths -Role verification
    $readLeases = [Collections.Generic.List[object]]::new()
    $repositorySnapshots = @{}
    $outcomes = [Collections.Generic.List[object]]::new()
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $interrupted = $false
    $failureKind = 'Success'
    $attemptCount = 0
    $attemptMinutes = 0.0
    $batched = $false
    try {
        Assert-HarnessTargetRunning $Paths @($target)
        $null = Update-HarnessState $Paths -Config $Config -Operation {
            param($saved)
            $saved.runs += [pscustomobject]@{ id = $runId; taskId = ''; phase = 'Verify'; status = 'Running'; startedAt = $startedAt.ToString('o'); finishedAt = ''; model = 'auto'; effort = 'auto'; workspace = $Paths.Project; report = $reportPath; exitCode = ''; monitor = $Definition.name }
            $saved.active = [pscustomobject]@{ taskId = ''; runId = $runId; phase = 'Verify'; ownerProcessId = $PID; target = $target; ownershipClaim = $ownership.id }
        }
        foreach ($candidate in $candidates) {
            $entry = [pscustomobject]@{ candidateId = $candidate.id; sourceRevision = $candidate.revision; collectionRunId = $CollectionRunId; outcome = 'unverified'; summary = ''; assessment = $candidate.assessment; evidence = @(); snapshot = ''; repositoryRoot = ''; workspace = ''; taskSnapshot = ''; report = $reportPath; model = 'auto'; verifiedAt = ''; reconciledTask = ''; attempted = $false; deferred = $false; durationMinutes = 0.0 }
            $correlation = Get-HarnessDiscoveryCorrelation $Config $state $candidate
            $completionContract = $baseContract + ($correlation.members | Select-Object source, requirementFingerprint, sameRequirementAs, claims | ConvertTo-Json -Depth 12 -Compress)
            $entry | Add-Member -NotePropertyName contract -NotePropertyValue $completionContract
            $readOwnership = $null
            $gitContext = $null
            try {
                if ($interrupted) { throw 'A previous verifier requires explicit recovery.' }
                Assert-HarnessTargetRunning $Paths @($target)
                if ($candidate.disposition -ceq 'Missing') { throw 'The source is missing; absence is not completion or supersession evidence.' }
                $linkedTask = if ($candidate.taskId) { Get-HarnessTask $state $candidate.taskId } else { $null }
                $completion = $candidate.completion
                $remaining = $MaxMinutes - $clock.Elapsed.TotalMinutes
                if ($remaining -le 0) {
                    $entry.deferred = $true; $entry.summary = 'Verification coverage is deferred to the next approved check within its existing budget.'
                    $outcomes.Add($entry)
                    continue
                }
                if ($linkedTask) { $entry.taskSnapshot = $linkedTask | ConvertTo-Json -Depth 30 -Compress }
                $repositoryRef = if ($linkedTask.repositoryRef) { $linkedTask.repositoryRef } else { $Definition.verification.repositoryRef }
                if ($linkedTask.repositoryRef -and $Definition.verification.repositoryRef -and $linkedTask.repositoryRef -cne $Definition.verification.repositoryRef) { throw 'The linked task and monitor select different repositories.' }
                $workspace = Get-HarnessExecutionRoot $Config
                $repositoryRoot = ''
                if ($repositoryRef -or (Test-Path -LiteralPath (Join-Path $workspace '.git'))) {
                    $repositoryTask = [pscustomobject]@{ id = $linkedTask.id; repositoryRef = $repositoryRef; repositoryRoot = $linkedTask.repositoryRoot }
                    $repositoryRoot = Resolve-HarnessRepository $Paths $Config $repositoryTask
                    $workspace = if ($linkedTask.workspace) { $linkedTask.workspace } else { $repositoryRoot }
                    Assert-HarnessRepositoryWorkspace $repositoryRoot $workspace
                }
                if ($Definition.verification.authority) {
                    if (-not $repositoryRoot) { throw 'Select a registered repository before inspecting its authoritative branch.' }
                    if (-not $repositorySnapshots.ContainsKey($repositoryRoot)) { $repositorySnapshots[$repositoryRoot] = New-HarnessVerificationSnapshot $Paths $Config $Definition.verification.authority $repositoryRoot $Definition.name $remaining }
                    $authoritySnapshot = $repositorySnapshots[$repositoryRoot]
                    $workspace = $authoritySnapshot.workspace; $repositoryRoot = $workspace; $gitContext = $authoritySnapshot.gitContext
                    $entry | Add-Member -NotePropertyName authority -NotePropertyValue $authoritySnapshot.authority
                }
                Assert-HarnessRestrictions -Config $Config -ProjectRoot $Paths.Project -Workspace $workspace
                $roots = @($workspace)
                if ($Definition.source.type -ceq 'folder') { $roots += [IO.Path]::GetFullPath($Definition.source.path, $Paths.Project) }
                $sourceUri = [uri]$candidate.source
                $fullSource = @($SourceItems | Where-Object { $_.id -ceq $candidate.sourceId -and $_.revision -ceq $candidate.revision }) | Select-Object -First 1
                if (-not $sourceUri.IsFile -and $candidate.evidenceTruncated -and -not $fullSource) { throw 'Recollect the complete owning source before verification; its stored excerpt is truncated.' }
                $sourceHash = ''
                if ($sourceUri.IsFile) {
                    if (-not (Test-HarnessVerificationPath $sourceUri.LocalPath $roots)) { throw 'The local source is outside the selected verification roots.' }
                    $null = Assert-HarnessDiscoveryPath $sourceUri.LocalPath $Config $Paths.Project
                    $sourceHash = (Get-FileHash -LiteralPath $sourceUri.LocalPath -Algorithm SHA256 -ErrorAction Stop).Hash
                    if ($Definition.source.type -ceq 'folder' -and $sourceHash -ine $candidate.revision) { throw 'Source content changed after collection.' }
                }
                $snapshot = if ($repositoryRoot) { Get-HarnessSnapshot $Paths $Config $workspace -RepositoryRoot $repositoryRoot -GitContext $gitContext -IncludeAllFiles:([bool]$gitContext) } else { 'No coding repository selected; implementation completion cannot be established.' }
                $readOwnership = Enter-HarnessOwnership -Paths $Paths -Role verification -TaskId $linkedTask.id -Workspace $workspace -AdditionalWorkspaces $roots -Mode Read -Snapshot $snapshot
                $readLeases.Add($readOwnership)
                $entry.snapshot = $snapshot; $entry.repositoryRoot = $repositoryRoot; $entry.workspace = $workspace
                $null = Update-HarnessState $Paths -SkipViews -Operation { param($saved); $saved.active.ownershipClaim = $readOwnership.id }
                if ($completion -and $completion.contract -ceq $completionContract) {
                    $completionEvidence = Get-HarnessVerificationEvidenceState $completion $Config $Paths $workspace $roots $snapshot
                    $entry | Add-Member -NotePropertyName evidenceChanged -NotePropertyValue ($completionEvidence.status -ceq 'Changed')
                    if ($completionEvidence.status -ceq 'Current' -and $completion.requirementFingerprint -ceq $candidate.requirementFingerprint -and
                        (-not $linkedTask -or ($linkedTask.status -in @('Completed', 'AlreadyFixed', 'Stale') -and $completion.taskContract -ceq (Get-HarnessTaskContract $linkedTask)))) {
                        $entry.outcome = $completion.outcome; $entry.summary = 'Retained completion after checking unchanged requirements and current evidence.'
                        $entry.evidence = @($completionEvidence.evidence); $entry.report = $completion.report; $entry.verifiedAt = $completion.verifiedAt
                        $entry | Add-Member -NotePropertyName retainedCompletion -NotePropertyValue $true
                        $outcomes.Add($entry)
                        continue
                    }
                }
                $checkpoint = $candidate.verificationCheckpoint
                if ($resuming -and $checkpoint -and $checkpoint.contract -ceq $completionContract -and
                    $checkpoint.sourceRevision -ceq $candidate.revision -and $checkpoint.requirementFingerprint -ceq $candidate.requirementFingerprint -and
                    $checkpoint.taskContract -ceq $(if ($linkedTask) { Get-HarnessTaskContract $linkedTask } else { '' }) -and
                    $checkpoint.verifiedAt -and ([datetimeoffset]::UtcNow - [datetimeoffset]$checkpoint.verifiedAt).TotalMinutes -le $Definition.maxAgeMinutes) {
                    $checkpointEvidence = Get-HarnessVerificationEvidenceState $checkpoint $Config $Paths $workspace $roots $snapshot
                    if ($checkpointEvidence.status -ceq 'Current') {
                        $entry.outcome = $checkpoint.outcome; $entry.summary = 'Reused current evidence while continuing incomplete verification coverage.'
                        $entry.evidence = @($checkpointEvidence.evidence); $entry.report = $checkpoint.report; $entry.verifiedAt = $checkpoint.verifiedAt
                        $entry | Add-Member -NotePropertyMembers @{ regression = $checkpoint.regression; changeReason = $checkpoint.changeReason }
                        $outcomes.Add($entry)
                        continue
                    }
                }
                $verifierConfig = $Config | ConvertTo-Json -Depth 30 | ConvertFrom-Json -NoEnumerate
                $verifierConfig.runner.model = 'auto'; $verifierConfig.runner.reasoningEffort = 'auto'
                $remaining = $MaxMinutes - $clock.Elapsed.TotalMinutes
                $estimate = if ($candidate.verificationDurationMinutes -gt 0) { $candidate.verificationDurationMinutes } elseif ($attemptCount) { $attemptMinutes / $attemptCount } else { 0 }
                if ($remaining -le 0 -or ($attemptCount -gt 0 -and $estimate -gt $remaining)) {
                    $entry.deferred = $true; $entry.summary = 'Remaining capacity cannot accommodate another verification; resume on the next approved check.'
                    $outcomes.Add($entry)
                    continue
                }
                $verifierConfig.runner.maxMinutes = Get-HarnessExecutionLimit $Config maxProcessMinutes $remaining
                $credits = Get-HarnessExecutionLimit $Config maxAgentCredits $Config.runner.maxCredits
                if ($null -ne $credits) { $verifierConfig.runner.maxCredits = $credits / $candidates.Count }
                $relatedSources = @(foreach ($related in $correlation.members) {
                    $collection = @($CollectedSources | Where-Object monitor -CEQ $related.monitor) | Select-Object -First 1
                    $relatedItem = @($collection.items | Where-Object { $_.id -ceq $related.sourceId -and $_.revision -ceq $related.revision }) | Select-Object -First 1
                    if ($related.id -ceq $candidate.id) { $relatedItem = $fullSource }
                    [pscustomobject]@{ source = $related.source; revision = $related.revision; acceptance = $related.acceptance; text = $(if ($relatedItem) { $relatedItem.text } else { $related.evidence }); truncated = (-not $relatedItem -and $related.evidenceTruncated); claims = $related.claims; sourceOwner = $related.sourceOwner }
                })
                $task = [pscustomobject]@{ id = ''; kind = 'verify'; title = $candidate.title; scope = $Definition.scope; candidate = $candidate; sourceContent = [string]$fullSource.text; relatedSources = $relatedSources; factAuthorities = $correlation.authorities; authority = $entry.authority; acceptance = @($candidate.acceptance, $linkedTask.acceptance | Where-Object { $_ }); monitorTarget = $target; repositoryRef = $repositoryRef; repositoryRoot = $repositoryRoot; evidenceRoots = $roots; untrustedInput = $true }
                $entry.attempted = $true; $attemptStarted = $clock.Elapsed.TotalMinutes; $attemptCount++
                $payload = Invoke-HarnessAgent $Paths $verifierConfig $task $workspace Verify $snapshot
                Assert-HarnessTargetRunning $Paths @($target)
                if ($repositoryRoot -and (Get-HarnessSnapshot $Paths $Config $workspace -RepositoryRoot $repositoryRoot -GitContext $gitContext -IncludeAllFiles:([bool]$gitContext)) -cne $snapshot) { throw 'Repository inputs changed during verification.' }
                if ($sourceHash -and (Get-FileHash -LiteralPath $sourceUri.LocalPath -Algorithm SHA256).Hash -cne $sourceHash) { throw 'Source content changed during verification.' }
                if ($Definition.scope) {
                    if ($payload.assessment) { $entry.assessment = ConvertTo-HarnessDiscoveryAssessment $payload.assessment $Definition $candidate.revision }
                    if (-not $entry.assessment -or $entry.assessment.scope -cne $Definition.scope.description -or $entry.assessment.sourceRevision -cne $candidate.revision -or $entry.assessment.relevance -cne 'Relevant') {
                        $payload.outcome = 'unverified'
                    }
                }
                if ($entry.assessment.classification -in @('Informational', 'OutOfScope') -or ($candidate.isContainer -and -not $entry.assessment.independentConcern)) { $payload.outcome = 'unverified' }
                $entry.evidence = @(Confirm-HarnessVerificationEvidence $payload $Config $Paths $workspace $roots ([bool]$repositoryRoot))
                $entry.outcome = $payload.outcome; $entry.summary = $payload.summary
                if ($payload.requirementChanged -eq $true -and $payload.changeReason -is [string] -and -not [string]::IsNullOrWhiteSpace($payload.changeReason)) {
                    $entry | Add-Member -NotePropertyName requirementChanged -NotePropertyValue $true
                    $entry | Add-Member -NotePropertyName changeReason -NotePropertyValue $payload.changeReason
                }
                if ($payload.regression -eq $true -and $entry.evidenceChanged -and $payload.changeReason -is [string] -and -not [string]::IsNullOrWhiteSpace($payload.changeReason)) {
                    $entry | Add-Member -NotePropertyName regression -NotePropertyValue $true
                    $entry | Add-Member -NotePropertyName changeReason -NotePropertyValue $payload.changeReason -Force
                }
                if ($entry.assessment.relevance -ceq 'NotRelevant' -or $entry.assessment.classification -in @('Informational', 'OutOfScope') -or ($candidate.isContainer -and -not $entry.assessment.independentConcern)) { $entry.outcome = 'excluded' }
                $entry.verifiedAt = [datetimeoffset]::UtcNow.ToString('o')
            }
            catch {
                $entry.outcome = 'unverified'; $entry.summary = $_.Exception.Message
                $kind = Get-HarnessFailureKind $_
                if ($kind -eq 'Interrupted') { $interrupted = $true }
                if ($kind -in @('Interrupted', 'Budget', 'Restriction', 'Stopped', 'PolicyPaused')) { $failureKind = $kind }
                elseif ($failureKind -eq 'Success') { $failureKind = 'Blocked' }
            }
            finally {
                if ($entry.attempted) {
                    $entry.durationMinutes = $clock.Elapsed.TotalMinutes - $attemptStarted
                    $attemptMinutes += $entry.durationMinutes
                }
                if ($readOwnership) {
                    if (-not $interrupted) { $null = Update-HarnessState $Paths -SkipViews -Operation { param($saved); $saved.active.ownershipClaim = $ownership.id } }
                }
            }
            $outcomes.Add($entry)
        }
        $appliedTasks = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        if ($BatchVerification) { $appliedTasks = $BatchVerification.appliedTasks }
        $context = [pscustomobject]@{
            Paths = $Paths; Config = $Config; Definition = $Definition; CollectionRunId = $CollectionRunId; target = $target
            runId = $runId; reportPath = $reportPath; outcomes = @($outcomes); repositorySnapshots = $repositorySnapshots
            interrupted = $interrupted; failureKind = $failureKind; attemptCount = $attemptCount; readLeases = @($readLeases); ownership = $ownership
            appliedTasks = $appliedTasks
        }
        if ($BatchVerification) { $BatchVerification.runs.Add($context); $batched = $true }
        Save-HarnessDiscoveryVerification $context -PublishOnly:([bool]$BatchVerification)
    }
    finally {
        if (-not $batched) {
            foreach ($lease in $readLeases) { Exit-HarnessOwnership $lease $Paths }
            Exit-HarnessOwnership $ownership $Paths
            if (-not $interrupted) { foreach ($snapshot in $repositorySnapshots.Values) { if (Test-Path -LiteralPath $snapshot.root) { Remove-Item -LiteralPath $snapshot.root -Recurse -Force } } }
        }
    }
}

function Save-HarnessDiscoveryVerification {
    param($Context, [switch]$PublishOnly)
    $Paths = $Context.Paths; $Config = $Context.Config; $Definition = $Context.Definition
    $CollectionRunId = $Context.CollectionRunId; $target = $Context.target; $runId = $Context.runId; $reportPath = $Context.reportPath
    $outcomes = @($Context.outcomes); $repositorySnapshots = $Context.repositorySnapshots
    $interrupted = $Context.interrupted; $failureKind = $Context.failureKind; $attemptCount = $Context.attemptCount
        New-Item -ItemType Directory -Path (Split-Path -Parent $reportPath) -Force | Out-Null
        $summary = Update-HarnessState $Paths -Config $Config -Operation {
            param($saved)
            $currentLatest = $saved.monitoring.latest | Where-Object monitor -CEQ $Definition.name | Select-Object -First 1
            foreach ($entry in $outcomes) {
                $candidate = $saved.monitoring.candidates | Where-Object id -CEQ $entry.candidateId | Select-Object -First 1
                if ($currentLatest.runId -cne $CollectionRunId -or $candidate.revision -cne $entry.sourceRevision -or $candidate.lastRunId -cne $CollectionRunId) { $entry.outcome = 'unverified'; $entry.summary = 'Candidate inputs changed; verification was not applied.'; continue }
                $entryContext = @($repositorySnapshots.Values | Where-Object workspace -CEQ $entry.workspace | Select-Object -First 1).gitContext
                if ((Get-HarnessPause $Paths $target) -or ($entry.repositoryRoot -and (Get-HarnessSnapshot $Paths $Config $entry.workspace -RepositoryRoot $entry.repositoryRoot -GitContext $entryContext -IncludeAllFiles:([bool]$entryContext)) -cne $entry.snapshot)) { $entry.outcome = 'unverified'; $entry.summary = 'Execution was paused or repository inputs changed before reconciliation.' }
                foreach ($evidence in $entry.evidence) {
                    if (-not (Test-Path -LiteralPath $evidence.path) -or (Get-FileHash -LiteralPath $evidence.path -Algorithm SHA256).Hash -cne $evidence.hash) { $entry.outcome = 'unverified'; $entry.summary = 'Evidence changed before status reconciliation.'; break }
                }
                if ($candidate.taskId -and $entry.outcome -in @('already-fixed', 'stale') -and -not $entry.retainedCompletion -and -not $Context.appliedTasks.Contains($candidate.taskId) -and
                    ((Get-HarnessTask $saved $candidate.taskId) | ConvertTo-Json -Depth 30 -Compress) -cne $entry.taskSnapshot) { $entry.outcome = 'unverified'; $entry.summary = 'The linked task changed during verification; its status was preserved.' }
                if ($entry.assessment) { $candidate | Add-Member -NotePropertyName assessment -NotePropertyValue $entry.assessment -Force }
                $candidate | Add-Member -NotePropertyName verification -NotePropertyValue ($entry | Select-Object outcome, summary, sourceRevision, collectionRunId, report, model, verifiedAt, reconciledTask, evidence, snapshot, authority) -Force
            }
            foreach ($entry in $outcomes) {
                $candidate = $saved.monitoring.candidates | Where-Object id -CEQ $entry.candidateId | Select-Object -First 1
                if ($candidate.revision -cne $entry.sourceRevision -or $candidate.lastRunId -cne $CollectionRunId) { continue }
                $correlation = Get-HarnessDiscoveryCorrelation $Config $saved $candidate
                $allowed = -not $PublishOnly -and (-not $correlation.correlated -or ($correlation.ready -and (-not $correlation.outcome -or $correlation.outcome -ceq $entry.outcome)))
                $entry | Add-Member -NotePropertyMembers @{ effectiveOutcome = $(if ($correlation.correlated) { $correlation.outcome } else { $entry.outcome }); conflicts = @($correlation.conflicts) } -Force
                if ($allowed -and $candidate.taskId -and $entry.outcome -in @('already-fixed', 'stale') -and -not $entry.retainedCompletion -and -not $Context.appliedTasks.Contains($candidate.taskId)) {
                    $task = Get-HarnessTask $saved $candidate.taskId
                    if ($task.status -notin @('Running', 'Completed', 'Cancelled', 'Unsupported', 'Stale', 'AlreadyFixed')) {
                        $task.status = if ($entry.outcome -ceq 'already-fixed') { 'AlreadyFixed' } else { 'Stale' }
                        $task.lastReport = $reportPath
                        $task | Add-Member -NotePropertyName updatedAt -NotePropertyValue ([datetimeoffset]::UtcNow.ToString('o')) -Force
                        foreach ($queue in @('nowQueue', 'nextQueue', 'resumeQueue')) { $saved.$queue = @($saved.$queue | Where-Object { $_ -cne $task.id }) }
                        $entry.reconciledTask = $task.id
                        $null = $Context.appliedTasks.Add($task.id)
                    }
                }
                if (-not $PublishOnly) {
                    $candidate.PSObject.Properties.Remove('followUpOf')
                    $candidate.PSObject.Properties.Remove('changeReason')
                }
                if ($entry.attempted) {
                    $candidate | Add-Member -NotePropertyMembers @{ verificationAttemptedAt = [datetimeoffset]::UtcNow.ToString('o'); verificationAttemptedRevision = $entry.sourceRevision; verificationDurationMinutes = $entry.durationMinutes } -Force
                }
                if ($allowed -and $candidate.taskId -and $entry.outcome -ceq 'open') {
                    $task = Get-HarnessTask $saved $candidate.taskId
                    if (($task | ConvertTo-Json -Depth 30 -Compress) -ceq $entry.taskSnapshot -and $task.status -in @('Completed', 'AlreadyFixed') -and
                        (($entry.requirementChanged -and $candidate.completion.requirementFingerprint -and $candidate.completion.requirementFingerprint -cne $candidate.requirementFingerprint) -or $entry.regression)) {
                        $candidate | Add-Member -NotePropertyName followUpOf -NotePropertyValue $task.id -Force
                        $candidate | Add-Member -NotePropertyName changeReason -NotePropertyValue $entry.changeReason -Force
                    }
                    elseif ($task.source -ceq $candidate.source -and $task.status -notin @('Running', 'Completed', 'AlreadyFixed', 'Stale', 'Cancelled', 'Unsupported') -and $candidate.taskContract -and
                        (Get-HarnessTaskContract $task) -ceq $candidate.taskContract -and ($task | ConvertTo-Json -Depth 30 -Compress) -ceq $entry.taskSnapshot) {
                        $proposalCandidate = $candidate | Select-Object *
                        $proposalCandidate.taskId = ''
                        $proposal = Get-HarnessDiscoveryProposal $Config $proposalCandidate $saved
                        if ($proposal) {
                            if ($task.title -ceq $candidate.taskTitle) { $task.title = $proposal.title; $candidate.taskTitle = $proposal.title }
                            if ($task.priority -eq $candidate.taskPriority) { $task.priority = $proposal.priority; $candidate.taskPriority = $proposal.priority }
                            $task.description = $proposal.description; $task.acceptance = $proposal.acceptance; $task.sourceRevision = $candidate.revision
                            if ($candidate.taskStatus -and $task.status -ceq $candidate.taskStatus -and $task.status -in @('Queued', 'Blocked')) {
                                $task.status = if ($proposal.blocked) { 'Blocked' } else { 'Queued' }
                                $candidate.taskStatus = $task.status
                            }
                            if ($entry.requirementChanged) {
                                $task.risk = 'Unknown'; $task.autoEligible = $false; $task.phase = 'Develop'; $task.snapshot = ''
                                foreach ($queue in @('nowQueue', 'nextQueue', 'resumeQueue')) { $saved.$queue = @($saved.$queue | Where-Object { $_ -cne $task.id }) }
                            }
                            $candidate.taskContract = Get-HarnessTaskContract $task
                        }
                    }
                }
                if ($allowed -and $entry.outcome -in @('already-fixed', 'stale') -and -not $entry.retainedCompletion) {
                    $completedTask = if ($candidate.taskId) { Get-HarnessTask $saved $candidate.taskId } else { $null }
                    $candidate | Add-Member -NotePropertyName completion -NotePropertyValue ([pscustomobject]@{ outcome = $entry.outcome; requirementFingerprint = $candidate.requirementFingerprint; contract = $entry.contract; taskContract = $(if ($completedTask) { Get-HarnessTaskContract $completedTask }); report = $entry.report; verifiedAt = $entry.verifiedAt; authority = $entry.authority; evidence = @($entry.evidence); snapshot = $entry.snapshot }) -Force
                }
                if ($entry.outcome -cne 'unverified') {
                    $checkpoint = $entry | Select-Object outcome, sourceRevision, report, verifiedAt, evidence, snapshot, regression, changeReason
                    $checkpoint | Add-Member -NotePropertyMembers @{ contract = $entry.contract; requirementFingerprint = $candidate.requirementFingerprint; taskContract = $(if ($candidate.taskId) { Get-HarnessTaskContract (Get-HarnessTask $saved $candidate.taskId) } else { '' }) }
                    $candidate | Add-Member -NotePropertyName verificationCheckpoint -NotePropertyValue $checkpoint -Force
                }
                elseif (-not $entry.deferred) { $candidate.PSObject.Properties.Remove('verificationCheckpoint') }
            }
            $pending = @($outcomes | Where-Object { $_.outcome -ceq 'unverified' -or $_.effectiveOutcome -ceq 'unverified' } | ForEach-Object candidateId)
            $coverage = [pscustomobject]@{ monitor = $Definition.name; collectionRunId = $CollectionRunId; pending = $pending; checked = $outcomes.Count - $pending.Count; attempted = $attemptCount; deferred = @($outcomes | Where-Object deferred).Count }
            $saved.monitoring | Add-Member -NotePropertyName coverage -NotePropertyValue (@($saved.monitoring.coverage | Where-Object monitor -CNE $Definition.name) + @($coverage)) -Force
            $status = if ($interrupted) { 'NeedsRecovery' } elseif ($coverage.deferred) { 'Partial' } elseif ($pending.Count) { 'Unverified' } else { 'Verified' }
            $reportData = [ordered]@{ monitor = $Definition.name; collectionRunId = $CollectionRunId; model = 'auto'; status = $status; coverage = $coverage; externalWriteback = $false; outcomes = @($outcomes) }
            [IO.File]::WriteAllText($reportPath, ("# Harness status verification`n`n" + ($reportData | ConvertTo-Json -Depth 30) + "`n"), [Text.UTF8Encoding]::new($false))
            $run = $saved.runs | Where-Object id -CEQ $runId | Select-Object -First 1
            $run.status = $status; $run.finishedAt = [datetimeoffset]::UtcNow.ToString('o'); $run.exitCode = if ($status -eq 'Verified') { '0' } else { '1' }
            if (-not $interrupted) { $saved.active = $null }
            if ($coverage.deferred -and $failureKind -ceq 'Success') { $failureKind = 'Blocked' }
            if (-not $PublishOnly -and $failureKind -ne 'PolicyPaused') { Register-HarnessPolicyOutcome $saved $Config $target $runId $failureKind "Status verification: $status. Report: $reportPath" }
            [pscustomobject]@{ status = $status; model = 'auto'; runId = $runId; report = $reportPath; coverage = $coverage; outcomes = @($outcomes | Select-Object candidateId, outcome, effectiveOutcome, conflicts, summary, reconciledTask) }
        }
        $summary
}