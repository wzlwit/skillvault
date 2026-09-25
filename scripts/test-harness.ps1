$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness-store.ps1')
. (Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness-runner.ps1')
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('harness-' + [guid]::NewGuid().ToString('N'))
$savedFixtureOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
$env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixtureRoot 'runtime-ownership'

function Assert-HarnessFailure {
    param([scriptblock]$Operation, [string]$Expected)
    $failed = $false
    try { & $Operation | Out-Null }
    catch {
        $failed = $true
        if ($_.Exception.Message -notlike "*$Expected*") { throw }
    }
    if (-not $failed) { throw "Expected failure: $Expected" }
}

try {
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    $paths = Get-HarnessPaths $fixtureRoot
    Assert-HarnessFailure { Read-HarnessConfig $paths } 'not initialized'
    if (Test-Path -LiteralPath $paths.Control) { throw 'Reading uninitialized config created state.' }
    $config = Initialize-Harness $paths
    $before = [System.IO.File]::ReadAllText($paths.Config)
    $stateBefore = [System.IO.File]::ReadAllText($paths.State)
    $again = Initialize-Harness $paths
    if ($again.projectId -cne $config.projectId -or [System.IO.File]::ReadAllText($paths.Config) -cne $before -or [System.IO.File]::ReadAllText($paths.State) -cne $stateBefore) { throw 'Reinitialization changed saved state.' }
    if ($null -ne $config.runner.model -or $null -ne $config.runner.workspaceMode) { throw 'Initialization silently chose execution policy.' }
    if ((Get-HarnessBoard $paths $config) -ine $paths.Control) { throw 'Board did not default to .harness_sv inside the selected root.' }
    Write-HarnessViews $paths $config (Read-HarnessState $paths)
    foreach ($name in @('current.csv', 'history.csv', 'references.csv', '.harness-board.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $paths.Control $name))) { throw "Default view was not saved under .harness_sv: $name" }
    }
    if (@(Get-ChildItem -LiteralPath $fixtureRoot -Force | Where-Object Name -NE '.harness_sv').Count) { throw 'Default initialization or board views wrote outside .harness_sv.' }
    $legacyProject = Join-Path $fixtureRoot 'legacy-controller'
    New-Item -ItemType Directory -Path $legacyProject | Out-Null
    $legacyPaths = Get-HarnessPaths $legacyProject
    $legacyConfig = Initialize-Harness $legacyPaths
    $legacyConfig.boardPath = '.harness'
    Write-HarnessJson $legacyPaths.Config $legacyConfig
    Move-Item -LiteralPath $legacyPaths.Control -Destination (Join-Path $legacyProject '.harness')
    $legacyPaths = Get-HarnessPaths $legacyProject
    if ($legacyPaths.Control -ine (Join-Path $legacyProject '.harness') -or (Initialize-Harness $legacyPaths).projectId -cne $legacyConfig.projectId) { throw 'Legacy controller identity or location changed.' }
    if (Test-Path -LiteralPath (Join-Path $legacyProject '.harness_sv')) { throw 'Reading legacy state migrated it.' }
    $lock = Enter-HarnessLock $paths.Lock
    try { Assert-HarnessFailure { Enter-HarnessLock $paths.Lock } 'busy' }
    finally { $lock.Dispose() }
    $config = Set-HarnessBoard $paths 'board'
    if ((Get-HarnessBoard $paths $config) -ine (Join-Path $fixtureRoot 'board')) { throw 'An explicit board destination was not honored.' }
    $task = Add-HarnessTask -Paths $paths -Title 'Fixture task' -Description 'Do the fixture work' -Scope 'fixture.txt' -Acceptance 'Fixture passes' -Source 'https://example.invalid/task/1' -Risk Low -AutoEligible
    $duplicate = Add-HarnessTask -Paths $paths -Title 'Duplicate' -Scope 'fixture.txt' -Source 'https://example.invalid/task/1'
    if ($duplicate.id -cne $task.id -or @((Read-HarnessState $paths).tasks).Count -ne 1) { throw 'Task intake duplicated one source/scope.' }
    if ($task.status -cne 'Queued' -or (Read-HarnessState $paths).active) { throw 'Task intake launched work or did not queue it.' }
    $referenceFile = Join-Path $fixtureRoot 'support.md'
    'Support material' | Set-Content -LiteralPath $referenceFile
    $reference = Set-HarnessReference -Paths $paths -Source 'support.md' -Note 'First note' -TaskId $task.id
    $updated = Set-HarnessReference -Paths $paths -Source 'support.md' -Note 'Updated, quoted note' -TaskId $task.id
    if ($reference.id -cne $updated.id -or @((Read-HarnessState $paths).references).Count -ne 1) { throw 'Reference upsert created duplicates.' }
    $null = Set-HarnessReference -Paths $paths -RemoveId $reference.id
    if (-not (Test-Path -LiteralPath $referenceFile) -or (Read-HarnessState $paths).references[0].active) { throw 'Removing a reference deleted the source or kept the link active.' }
    $current = @(Import-Csv -LiteralPath (Join-Path $fixtureRoot 'board/current.csv'))
    if ($current.Count -ne 1 -or $current[0].id -cne $task.id) { throw 'Current CSV view is not projected from task state.' }
    $identityProject = Join-Path $fixtureRoot 'identity controller'
    New-Item -ItemType Directory -Path $identityProject | Out-Null
    $identityPaths = Get-HarnessPaths $identityProject
    $null = Initialize-Harness $identityPaths
    $identityTask = Add-HarnessTask -Paths $identityPaths -Title 'Identity fixture' -Scope ' DoWork ' -Source ' https://EXAMPLE.invalid:443/Task/1?field=Value '
    $normalizedTask = Add-HarnessTask -Paths $identityPaths -Title 'Same request' -Scope 'DoWork' -Source 'https://example.invalid/Task/1?field=Value'
    if ($normalizedTask.id -cne $identityTask.id) { throw 'Harmless whitespace, URL host case, or a default port created a duplicate task.' }
    foreach ($variant in @(
        @{ Scope = 'doWork'; Source = 'https://example.invalid/Task/1?field=Value' },
        @{ Scope = 'DoWork'; Source = 'https://example.invalid/task/1?field=Value' },
        @{ Scope = 'DoWork'; Source = 'https://example.invalid/Task/1?field=value' },
        @{ Scope = 'Do Work'; Source = 'https://example.invalid/Task/1?field=Value' }
    )) {
        $differentTask = Add-HarnessTask -Paths $identityPaths -Title 'Distinct request' @variant
        if ($differentTask.id -ceq $identityTask.id) { throw 'Task normalization merged meaningful code, path, query, or internal whitespace differences.' }
    }
    $fileSource = Join-Path $identityProject 'spec.md'
    $fileTask = Add-HarnessTask -Paths $identityPaths -Title 'Local source' -Scope 'file' -Source $fileSource
    $sameFileTask = Add-HarnessTask -Paths $identityPaths -Title 'Same local source' -Scope 'file' -Source (Join-Path $identityProject './spec.md')
    if ($sameFileTask.id -cne $fileTask.id) { throw 'Absolute source-path normalization did not remove a dot segment.' }
    if ((Get-HarnessTaskIdentity 'Requirement-A' 'file' '') -ceq (Get-HarnessTaskIdentity 'requirement-a' 'file' '')) { throw 'Opaque source identifiers lost meaningful case.' }
    $linkedFolder = Join-Path $fixtureRoot 'linked folder'
    New-Item -ItemType Directory -Path $linkedFolder | Out-Null
    foreach ($source in @('https://example.invalid/reference', $linkedFolder)) {
        $link = Set-HarnessReference -Paths $paths -Source $source -Note 'Shared link registry' -TaskId $task.id
        $repeatedLink = Set-HarnessReference -Paths $paths -Source $source -Note 'Updated link note' -TaskId $task.id
        if ($link.id -cne $repeatedLink.id -or $repeatedLink.source -cne $source) { throw 'URL or folder link upsert changed its source or identity.' }
        $null = Set-HarnessReference -Paths $paths -RemoveId $link.id
    }
    if (-not (Test-Path -LiteralPath $linkedFolder) -or -not (Test-Path -LiteralPath $referenceFile)) { throw 'Unregistering a link deleted its target.' }
    Assert-HarnessFailure { Set-HarnessBoard $paths 'other-board' } 'contains records'
    $dispatcher = Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness.ps1'
    $commandProject = Join-Path $fixtureRoot 'command-project'
    New-Item -ItemType Directory -Path $commandProject | Out-Null
    $selectedRoot = & $dispatcher -ProjectPath $commandProject -Action Root | ConvertFrom-Json
    if ($selectedRoot.project -ine $commandProject -or $selectedRoot.initialized -or (Test-Path -LiteralPath (Join-Path $commandProject '.harness_sv'))) { throw 'Root selection changed or initialized its target.' }
    if ($selectedRoot.board -ine (Join-Path $commandProject '.harness_sv')) { throw 'Root inspection did not display the .harness_sv default before initialization.' }
    Push-Location $commandProject
    try {
        $defaultRoot = & $dispatcher -Action Root | ConvertFrom-Json
        if ($defaultRoot.project -ine $commandProject -or $defaultRoot.selection -cne 'CurrentDirectory' -or (Test-Path -LiteralPath (Join-Path $commandProject '.harness_sv'))) { throw 'Unanswered root selection did not resolve the current folder without writes.' }
        Assert-HarnessFailure { & $dispatcher -Action Init -ConfirmLocation } 'explicit -ProjectPath'
        Assert-HarnessFailure { & $dispatcher -Action Root -Apply } 'read-only'
        Assert-HarnessFailure { & $dispatcher -Action Root -Scheduled } 'cannot run unattended'
        Assert-HarnessFailure { & $dispatcher -Action Root -Move -DestinationPath $fixtureRoot } 'selected -ProjectPath'
        Assert-HarnessFailure { & $dispatcher -ProjectPath $commandProject -Action Root -DestinationPath $fixtureRoot } 'read-only'
        Assert-HarnessFailure { & $dispatcher -ProjectPath $commandProject -Action Status -Move } 'only to Root'
    }
    finally { Pop-Location }
    Assert-HarnessFailure { & $dispatcher -ProjectPath (Join-Path $commandProject 'missing') -Action Root } 'Project directory not found'
    if (@(Get-ChildItem -LiteralPath $commandProject -Force).Count -ne 0) { throw 'Root selection or an unconfirmed initialization attempt created files.' }
    $status = & $dispatcher -ProjectPath $commandProject -Action Status | ConvertFrom-Json
    if ($status.initialized -or (Test-Path -LiteralPath (Join-Path $commandProject '.harness_sv'))) { throw 'Public status initialized a project.' }
    Assert-HarnessFailure { & $dispatcher -ProjectPath $commandProject -Action Init } 'ConfirmLocation'
    if (Test-Path -LiteralPath (Join-Path $commandProject '.harness_sv')) { throw 'Initialization without caller location acknowledgement wrote project state.' }
    $otherRoot = Join-Path $fixtureRoot 'other root'
    New-Item -ItemType Directory -Path $otherRoot | Out-Null
    Push-Location $otherRoot
    try {
        $null = & $dispatcher -ProjectPath $defaultRoot.project -Action Init -ConfirmLocation
        $inheritedStatus = & $dispatcher -ProjectPath $defaultRoot.project -Action Status | ConvertFrom-Json
        if ($inheritedStatus.project -ine $commandProject -or (Test-Path -LiteralPath (Join-Path $otherRoot '.harness_sv'))) { throw 'Root handoff followed the changed terminal directory instead of the selected fallback.' }
    }
    finally { Pop-Location }
    $confirmedConfigPath = Join-Path $commandProject '.harness_sv/config.json'
    $confirmedConfig = [System.IO.File]::ReadAllText($confirmedConfigPath)
    $null = & $dispatcher -ProjectPath $selectedRoot.project -Action Init -ConfirmLocation
    if ([System.IO.File]::ReadAllText($confirmedConfigPath) -cne $confirmedConfig) { throw 'Reconnect through the selected Root changed saved configuration.' }
    Assert-HarnessFailure { & $dispatcher -ProjectPath $commandProject -Action Init } 'ConfirmLocation'
    Assert-HarnessFailure { & $dispatcher -ProjectPath $commandProject -Action Init -ConfirmLocation -Scheduled } 'scheduled initialization is not allowed'
    if ([System.IO.File]::ReadAllText($confirmedConfigPath) -cne $confirmedConfig) { throw 'An unconfirmed or scheduled reconnect changed configuration.' }
    Assert-HarnessFailure { & $dispatcher -ProjectPath $commandProject -Action Status -ConfirmLocation } 'only to Init'
    $placement = & $dispatcher -ProjectPath $commandProject -Action Board -BoardPath 'relocated board' | ConvertFrom-Json
    $initializedRoot = & $dispatcher -ProjectPath $commandProject -Action Root | ConvertFrom-Json
    if (-not $initializedRoot.initialized -or $initializedRoot.board -cne $placement.board -or $initializedRoot.control -ine (Join-Path $commandProject '.harness_sv')) { throw 'Root inspection lost existing controller state or reallocated board placement.' }
    $relocatedConfig = [IO.File]::ReadAllText($confirmedConfigPath)
    $reselectedRoot = & $dispatcher -ProjectPath $otherRoot -Action Root | ConvertFrom-Json
    if ($reselectedRoot.project -ine $otherRoot -or $reselectedRoot.initialized -or [IO.File]::ReadAllText($confirmedConfigPath) -cne $relocatedConfig -or @(Get-ChildItem -LiteralPath $otherRoot -Force).Count -ne 0) { throw 'Explicit root reselection moved old records or initialized the new controller.' }
    $commandTask = & $dispatcher -ProjectPath $commandProject -Action Task -Title 'Public task' -Text 'Input' -Scope 'file' -Acceptance 'Check' | ConvertFrom-Json
    $updatedTask = & $dispatcher -ProjectPath $commandProject -Action UpdateTask -Id $commandTask.id -Risk Low -AutoEligible | ConvertFrom-Json
    if ($updatedTask.risk -cne 'Low' -or -not $updatedTask.autoEligible) { throw 'Public task update did not retain explicit fields.' }
    $null = & $dispatcher -ProjectPath $commandProject -Action Ref -Source 'https://example.invalid/spec' -Note 'Public reference' -Id $commandTask.id
    $context = & $dispatcher -ProjectPath $commandProject -Action Context -Id $commandTask.id | ConvertFrom-Json
    if (@($context.references).Count -ne 1 -or $context.task.id -cne $commandTask.id) { throw 'Public context did not select task references.' }
    $commandPaths = Get-HarnessPaths $commandProject
    $completionReport = Join-Path $placement.board 'completed.md'
    [IO.File]::WriteAllText($completionReport, 'Completed task evidence')
    $null = Update-HarnessState $commandPaths {
        param($saved)
        $completed = Get-HarnessTask $saved $commandTask.id
        $completed.status = 'Completed'
        $completed.phase = 'Critical'
        $completed.workspace = $commandProject
        $completed.baseCommit = 'completed-base'
        $completed.snapshot = 'completed-snapshot'
        $completed.lastReport = $completionReport
    }
    $completedBefore = Get-HarnessTask (Read-HarnessState $commandPaths) $commandTask.id | ConvertTo-Json -Depth 10
    $followUp = & $dispatcher -ProjectPath $commandProject -Action UpdateTask -Id $commandTask.id -Text 'Revised requirements' -Acceptance 'Additional check' | ConvertFrom-Json
    if ($followUp.id -ceq $commandTask.id -or $followUp.followUpOf -cne $commandTask.id -or $followUp.status -cne 'Queued' -or $followUp.phase -cne 'Develop' -or $followUp.autoEligible -or $followUp.risk -cne 'Unknown') { throw 'Revised completed work did not create a separate manual follow-up.' }
    if ($followUp.workspace -cne $commandProject -or $followUp.baseCommit -cne 'completed-base' -or $followUp.scope -cne $commandTask.scope -or $followUp.snapshot -or $followUp.lastReport) { throw 'A follow-up lost its prior workspace or reused a completed validation verdict.' }
    $sameFollowUp = & $dispatcher -ProjectPath $commandProject -Action UpdateTask -Id $commandTask.id -Text 'Revised requirements' -Acceptance 'Additional check' | ConvertFrom-Json
    if ($sameFollowUp.id -cne $followUp.id) { throw 'Repeating a completed-task revision duplicated its follow-up.' }
    $noChange = & $dispatcher -ProjectPath $commandProject -Action UpdateTask -Id $commandTask.id -Text 'Input' -Acceptance 'Check' | ConvertFrom-Json
    if ($noChange.id -cne $commandTask.id -or $noChange.status -cne 'Completed') { throw 'An unchanged completed request created new work.' }
    if ((Get-HarnessTask (Read-HarnessState $commandPaths) $commandTask.id | ConvertTo-Json -Depth 10) -cne $completedBefore -or [IO.File]::ReadAllText($completionReport) -cne 'Completed task evidence') { throw 'A follow-up rewrote its original task or evidence.' }
    $followUpView = Import-Csv -LiteralPath (Join-Path $placement.board 'current.csv') | Where-Object id -CEQ $followUp.id
    if ($followUpView.followUpOf -cne $commandTask.id) { throw 'The current task view lost its follow-up link.' }
    Assert-HarnessFailure { & $dispatcher -ProjectPath $commandProject -Action Task -FollowUpOf $followUp.id } 'requires a completed task'
    $queuedFollowUp = & $dispatcher -ProjectPath $commandProject -Action Dev -Id $commandTask.id -Text 'Another explicit revision' -Risk Low -Mode next | ConvertFrom-Json
    $queuedFollowUpTask = Get-HarnessTask (Read-HarnessState $commandPaths) $queuedFollowUp.taskId
    if ($queuedFollowUp.status -cne 'Queued' -or $queuedFollowUpTask.followUpOf -cne $commandTask.id -or (Read-HarnessState $commandPaths).active) { throw 'Dev did not reuse follow-up intake or queue-only semantics.' }
    $sourceTask = Add-HarnessTask -Paths $identityPaths -Title 'Completed source task' -Description 'Original requirement' -Scope 'source' -Acceptance 'Original check' -Source 'https://example.invalid/revised'
    $null = Update-HarnessState $identityPaths { param($saved); (Get-HarnessTask $saved $sourceTask.id).status = 'Completed' }
    $revisionOnly = Add-HarnessTask -Paths $identityPaths -Title 'Same source task' -Scope 'source' -Source 'https://example.invalid/revised' -SourceRevision 'new-revision'
    if ($revisionOnly.id -cne $sourceTask.id) { throw 'A source revision alone created follow-up work.' }
    $sameKind = Add-HarnessTask -Paths $identityPaths -Title 'Same source task' -Scope 'source' -Source 'https://example.invalid/revised' -Kind Feature
    if ($sameKind.id -cne $sourceTask.id) { throw 'A known task-kind casing difference created new requirements.' }
    $sourceFollowUp = Add-HarnessTask -Paths $identityPaths -Title 'New requirement' -Description 'Explicit new requirement' -Scope 'source' -Source 'https://example.invalid/revised'
    if ($sourceFollowUp.followUpOf -cne $sourceTask.id -or $sourceFollowUp.acceptance -cne 'Original check') { throw 'Ad-hoc revised requirements did not use the shared follow-up intake.' }
    $processResult = Invoke-HarnessProcess -Executable 'pwsh' -Arguments @('-NoProfile', '-NonInteractive', '-Command', '[Console]::Out.Write("fixture out"); [Console]::Error.Write("fixture err"); exit 7') -Directory $fixtureRoot -MaxMinutes 1
    if ($processResult.ExitCode -ne 7 -or $processResult.Output -cne 'fixture out' -or $processResult.Error -cne 'fixture err') { throw 'Actual subprocess handling lost exit code or output streams.' }
    $nativeBudgetResult = Invoke-HarnessProcess -Executable pwsh -Arguments @('-NoProfile', '-NonInteractive', '-Command', '[Console]::Out.Write("native limit"); exit 0') -Directory $fixtureRoot
    if ($nativeBudgetResult.ExitCode -ne 0 -or $nativeBudgetResult.Output -cne 'native limit') { throw 'An omitted process budget was converted to an invalid zero limit.' }
    $savedApproval = $env:COPILOT_ALLOW_ALL
    try {
        $env:COPILOT_ALLOW_ALL = 'fixture-approval'
        $permissionProbe = @('-NoProfile', '-NonInteractive', '-Command', '[Console]::Out.Write($env:COPILOT_ALLOW_ALL)')
        $inheritedProcess = Invoke-HarnessProcess -Executable pwsh -Arguments $permissionProbe -Directory $fixtureRoot -MaxMinutes 1 -InheritPermissions
        $isolatedProcess = Invoke-HarnessProcess -Executable pwsh -Arguments $permissionProbe -Directory $fixtureRoot -MaxMinutes 1
        if ($inheritedProcess.Output -cne 'fixture-approval' -or $isolatedProcess.Output -or $inheritedProcess.ExitCode -ne 0 -or $isolatedProcess.ExitCode -ne 0) { throw 'Native permission inheritance or reviewer environment isolation was lost.' }
    }
    finally { $env:COPILOT_ALLOW_ALL = $savedApproval }
    $largeInput = 'Fixture input ' * 8000
    $inputResult = Invoke-HarnessProcess -Executable pwsh -Arguments @('-NoProfile', '-NonInteractive', '-Command', '[Console]::Out.Write([Console]::In.ReadToEnd().Length)') -Directory $fixtureRoot -MaxMinutes 1 -InputText $largeInput
    if ($inputResult.ExitCode -ne 0 -or [int]$inputResult.Output -ne $largeInput.Length) { throw 'Large worker standard input was truncated or blocked.' }

    $gitProject = Join-Path $fixtureRoot 'git project'
    New-Item -ItemType Directory -Path $gitProject | Out-Null
    $null = Invoke-HarnessGit $gitProject @('init', '--quiet')
    $fixtureSource = Join-Path $gitProject 'source.txt'
    'Committed fixture input' | Set-Content -LiteralPath $fixtureSource -Encoding UTF8
    $null = Invoke-HarnessGit $gitProject @('add', '--', 'source.txt')
    $null = Invoke-HarnessGit $gitProject @('-c', 'user.name=Harness Test', '-c', 'user.email=harness@example.invalid', '-c', 'commit.gpgSign=false', '-c', ('core.hooksPath=' + (Join-Path $gitProject 'no-hooks')), 'commit', '--quiet', '-m', 'Harness fixture')
    $folderProject = Join-Path $fixtureRoot 'folder controller'
    New-Item -ItemType Directory -Path $folderProject | Out-Null
    $folderPaths = Get-HarnessPaths $folderProject
    $folderConfig = Initialize-Harness $folderPaths
    $folderConfig.runner.workspaceMode = 'current'
    $repoReference = Set-HarnessReference -Paths $folderPaths -Source $gitProject -Note 'Coding repository'
    $folderTask = & $dispatcher -ProjectPath $folderProject -Action Task -Title 'Referenced repository task' -Text 'Work in the registered repository' -Scope 'source.txt' -Acceptance 'Use the selected repository only' -Risk Low -RepoRef $repoReference.id | ConvertFrom-Json
    $folderWorkspace = Get-HarnessWorkspace $folderPaths $folderConfig $folderTask
    if ($folderWorkspace -ine $gitProject -or $folderTask.repositoryRef -cne $repoReference.id -or (Test-Path -LiteralPath (Join-Path $folderProject '.git'))) { throw 'A folder-based harness did not select its referenced coding repository without becoming a Git repository.' }
    $otherPurpose = & $dispatcher -ProjectPath $folderProject -Action Dev -Title 'Queued reference task' -Text 'Work later' -Scope 'source.txt' -Acceptance 'Retain repository choice' -Risk Low -RepoRef $repoReference.id -Mode next | ConvertFrom-Json
    if ($otherPurpose.status -cne 'Queued' -or (Get-HarnessTask (Read-HarnessState $folderPaths) $otherPurpose.taskId).repositoryRef -cne $repoReference.id) { throw 'The public dev queue lost its explicit repository target.' }
    $sourceHistory = Join-Path $gitProject 'history'
    New-Item -ItemType Directory -Path $sourceHistory | Out-Null
    [IO.File]::WriteAllText((Join-Path $sourceHistory 'repository-code.txt'), 'Source, not harness history')
    $referenceSnapshot = Get-HarnessSnapshot $folderPaths $folderConfig $gitProject -RepositoryRoot $gitProject | ConvertFrom-Json
    if (@($referenceSnapshot.untracked | Where-Object path -CEQ 'history/repository-code.txt').Count -ne 1) { throw 'The external repository snapshot excluded a source path that resembled controller records.' }
    Remove-Item -LiteralPath $sourceHistory -Recurse -Force

    $otherGitProject = Join-Path $fixtureRoot 'other git project'
    New-Item -ItemType Directory -Path $otherGitProject | Out-Null
    $null = Invoke-HarnessGit $otherGitProject @('init', '--quiet')
    $null = Invoke-HarnessGit $otherGitProject @('-c', 'user.name=Harness Test', '-c', 'user.email=harness@example.invalid', '-c', 'commit.gpgSign=false', '-c', ('core.hooksPath=' + (Join-Path $otherGitProject 'no-hooks')), 'commit', '--quiet', '--allow-empty', '-m', 'Other repository fixture')
    $otherRepoReference = Set-HarnessReference -Paths $folderPaths -Source $otherGitProject
    $trailingRepository = Set-HarnessReference -Paths $folderPaths -Source ($gitProject + [IO.Path]::DirectorySeparatorChar)
    if ((Get-HarnessWorkspace $folderPaths $folderConfig ([pscustomobject]@{ id = 'T-trailing'; repositoryRef = $trailingRepository.id })) -cne $gitProject) { throw 'A trailing directory separator rejected a valid coding repository root.' }
    $intake = @{ Paths = $folderPaths; Title = 'Shared requirement'; Description = 'Per repository work'; Scope = 'source.txt'; Acceptance = 'Separate repository tasks'; Source = 'https://example.invalid/shared'; Risk = 'Low' }
    $firstRepoTask = Add-HarnessTask @intake -RepoRef $repoReference.id
    $sameRepoTask = Add-HarnessTask @intake -RepoRef $repoReference.id
    $otherRepoTask = Add-HarnessTask @intake -RepoRef $otherRepoReference.id
    if ($firstRepoTask.id -cne $sameRepoTask.id -or $firstRepoTask.id -ceq $otherRepoTask.id) { throw 'Task intake did not deduplicate within, and distinguish between, selected repositories.' }
    $normalizedRepoTask = Add-HarnessTask @intake -RepoRef (' ' + $repoReference.id.ToLowerInvariant() + ' ')
    if ($normalizedRepoTask.id -cne $firstRepoTask.id -or $normalizedRepoTask.repositoryRef -cne $repoReference.id) { throw 'Normalized repository IDs duplicated or retargeted an existing task.' }
    $newNormalizedRepoTask = Add-HarnessTask -Paths $folderPaths -Title 'Canonical binding' -RepoRef (' ' + $repoReference.id.ToLowerInvariant() + ' ')
    if ($newNormalizedRepoTask.repositoryRef -cne $repoReference.id) { throw 'New task binding did not save the canonical repository ID.' }
    $allocatedTask = [pscustomobject]@{ id = $firstRepoTask.id; repositoryRef = $repoReference.id; workspace = $gitProject }
    Set-HarnessTaskRepository (Read-HarnessState $folderPaths) $allocatedTask (' ' + $repoReference.id.ToLowerInvariant() + ' ')
    if ($allocatedTask.repositoryRef -cne $repoReference.id) { throw 'Equivalent repository spelling changed an allocated task binding.' }

    $urlReference = Set-HarnessReference -Paths $folderPaths -Source 'https://example.invalid/repository.git'
    $fileReference = Set-HarnessReference -Paths $folderPaths -Source $fixtureSource
    $missingReference = Set-HarnessReference -Paths $folderPaths -Source (Join-Path $fixtureRoot 'missing checkout')
    $nonGitReference = Set-HarnessReference -Paths $folderPaths -Source $folderProject
    $scopedReference = Set-HarnessReference -Paths $folderPaths -Source $gitProject -TaskId $firstRepoTask.id
    $boundTask = & $dispatcher -ProjectPath $folderProject -Action UpdateTask -Id $firstRepoTask.id -RepoRef $scopedReference.id | ConvertFrom-Json
    if ($boundTask.repositoryRef -cne $scopedReference.id) { throw 'A task could not select its own task-scoped repository reference.' }
    $beforeRejectedReference = [IO.File]::ReadAllText($folderPaths.State)
    Assert-HarnessFailure { Add-HarnessTask @intake -RepoRef 'R-missing' } 'active repository reference'
    foreach ($invalidReference in @($urlReference, $fileReference, $missingReference)) {
        Assert-HarnessFailure { Add-HarnessTask @intake -RepoRef $invalidReference.id } 'existing local directory'
    }
    Assert-HarnessFailure { & $dispatcher -ProjectPath $folderProject -Action UpdateTask -Id $otherRepoTask.id -RepoRef $scopedReference.id } 'belongs to another task'
    Assert-HarnessFailure { Get-HarnessWorkspace $folderPaths $folderConfig ([pscustomobject]@{ id = 'T-unselected' }) } 'local Git repository root'
    Assert-HarnessFailure { Get-HarnessWorkspace $folderPaths $folderConfig ([pscustomobject]@{ id = 'T-nongit'; repositoryRef = $nonGitReference.id }) } 'local Git repository root'
    if ([IO.File]::ReadAllText($folderPaths.State) -cne $beforeRejectedReference -or (Test-Path -LiteralPath (Join-Path $folderProject '.git'))) { throw 'Rejecting a repository target changed task state or initialized Git.' }
    $null = Set-HarnessReference -Paths $folderPaths -RemoveId $repoReference.id
    Assert-HarnessFailure { Get-HarnessWorkspace $folderPaths $folderConfig $folderTask } 'active repository reference'
    $reactivatedRepository = Set-HarnessReference -Paths $folderPaths -Source $gitProject
    if ($reactivatedRepository.id -cne $repoReference.id) { throw 'Repository-reference reactivation changed its stable ID.' }
    $folderConfig | Add-Member -NotePropertyName restrictions -NotePropertyValue ([pscustomobject]@{ workingRoots = @('.') })
    Assert-HarnessFailure { Get-HarnessWorkspace $folderPaths $folderConfig $folderTask } 'outside the approved workingRoots'
    $folderConfig.PSObject.Properties.Remove('restrictions')

    $folderConfig.runner.workspaceMode = 'worktree'
    $folderWorktreeTask = Add-HarnessTask -Paths $folderPaths -Title 'Referenced worktree' -Description 'Use an isolated checkout' -Scope 'source.txt' -Acceptance 'Preserve controller and repository' -Risk Low -RepoRef $repoReference.id
    $folderWorktree = Get-HarnessWorkspace $folderPaths $folderConfig $folderWorktreeTask
    if ([IO.File]::ReadAllText((Join-Path $folderWorktree 'source.txt')) -cne [IO.File]::ReadAllText($fixtureSource) -or (Test-Path -LiteralPath (Join-Path $gitProject '.harness_sv')) -or (Test-Path -LiteralPath (Join-Path $gitProject 'current.csv'))) { throw 'A referenced worktree lost source contents or wrote controller records into the coding repository.' }
    $folderWorktreeTask.workspace = $folderWorktree
    $null = Update-HarnessState $folderPaths {
        param($saved)
        $selected = Get-HarnessTask $saved $folderWorktreeTask.id
        $selected.workspace = $folderWorktree
        $selected.repositoryRoot = $folderWorktreeTask.repositoryRoot
    }
    if ((Get-HarnessWorkspace $folderPaths $folderConfig $folderWorktreeTask) -cne $folderWorktree) { throw 'A referenced task did not reuse its recorded worktree.' }
    Assert-HarnessFailure { & $dispatcher -ProjectPath $folderProject -Action UpdateTask -Id $folderWorktreeTask.id -RepoRef $otherRepoReference.id } 'cannot be retargeted'
    Assert-HarnessFailure { & $dispatcher -ProjectPath $folderProject -Action Dev -Id $folderWorktreeTask.id -RepoRef $otherRepoReference.id -Mode next } 'cannot be retargeted'
    $folderWorktreeTask.workspace = $otherGitProject
    Assert-HarnessFailure { Get-HarnessWorkspace $folderPaths $folderConfig $folderWorktreeTask } 'does not belong to the selected repository'
    $folderWorktreeTask.workspace = $folderWorktree
    $null = Update-HarnessState $folderPaths {
        param($saved)
        ($saved.references | Where-Object id -CEQ $repoReference.id).source = $otherGitProject
    }
    Assert-HarnessFailure { Get-HarnessWorkspace $folderPaths $folderConfig $folderWorktreeTask } 'repository changed after workspace selection'
    $null = Update-HarnessState $folderPaths {
        param($saved)
        ($saved.references | Where-Object id -CEQ $repoReference.id).source = $gitProject
    }
    $folderConfig.runner.workspaceMode = 'current'
    $gitPaths = Get-HarnessPaths $gitProject
    $gitConfig = Initialize-Harness $gitPaths
    $allFilesSnapshot = Get-HarnessSnapshot $gitPaths $gitConfig $gitProject -IncludeAllFiles | ConvertFrom-Json
    if (@($allFilesSnapshot.untracked | Where-Object path -EQ '.harness_sv/config.json').Count -ne 1) { throw 'Explicit complete snapshots excluded source paths named like harness records.' }
    $initialBase = Resolve-HarnessReviewBaseline $gitPaths
    if ($initialBase.selection -cne 'WorkingChangesOnly' -or $initialBase.reference -cne 'HEAD') { throw 'A repository without a comparison ref silently invented an ahead baseline.' }
    $branchName = [string](Invoke-HarnessGit $gitProject @('rev-parse', '--abbrev-ref', 'HEAD'))
    $null = Invoke-HarnessGit $gitProject @('config', 'remote.origin.url', 'https://example.invalid/fixture.git')
    $null = Invoke-HarnessGit $gitProject @('config', 'remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*')
    $null = Invoke-HarnessGit $gitProject @('config', "branch.$branchName.remote", 'origin')
    $null = Invoke-HarnessGit $gitProject @('config', "branch.$branchName.merge", 'refs/heads/main')
    $null = Invoke-HarnessGit $gitProject @('update-ref', 'refs/remotes/origin/main', $initialBase.commit)
    'Committed ahead fixture' | Set-Content -LiteralPath (Join-Path $gitProject 'ahead.txt') -Encoding UTF8
    $null = Invoke-HarnessGit $gitProject @('add', '--', 'ahead.txt')
    $null = Invoke-HarnessGit $gitProject @('-c', 'user.name=Harness Test', '-c', 'user.email=harness@example.invalid', '-c', 'commit.gpgSign=false', '-c', ('core.hooksPath=' + (Join-Path $gitProject 'no-hooks')), 'commit', '--quiet', '-m', 'Ahead fixture')
    $aheadBase = Resolve-HarnessReviewBaseline $gitPaths
    $aheadSnapshot = Get-HarnessSnapshot $gitPaths $gitConfig $gitProject $aheadBase.commit | ConvertFrom-Json
    if ($aheadBase.reference -cne 'origin/main' -or $aheadBase.commit -cne $initialBase.commit -or $aheadSnapshot.diff -notmatch 'Committed ahead fixture') { throw 'Default review baseline lost committed-ahead changes.' }
    $null = Invoke-HarnessGit $gitProject @('update-ref', 'refs/remotes/origin/develop', $initialBase.commit)
    if ((Resolve-HarnessReviewBaseline $gitPaths).reference -cne 'origin/develop') { throw 'Available origin/develop was not preferred for the branch comparison.' }
    $explicitBase = Resolve-HarnessReviewBaseline $gitPaths HEAD
    if ($explicitBase.selection -cne 'Explicit' -or $explicitBase.commit -ceq $initialBase.commit) { throw 'Explicit review baseline did not override automatic selection.' }
    $gitConfig.runner.workspaceMode = 'worktree'
    $gitTask = Add-HarnessTask -Paths $gitPaths -Title 'Git fixture' -Description 'Fixture work' -Scope 'source.txt' -Acceptance 'Preserve input' -Risk Low
    $cleanSnapshot = Get-HarnessSnapshot $gitPaths $gitConfig $gitProject | ConvertFrom-Json
    if ($cleanSnapshot.diff -or @($cleanSnapshot.untracked).Count -ne 0) { throw 'Harness-owned state/views made clean Git input appear dirty.' }
    $worktree = Get-HarnessWorkspace $gitPaths $gitConfig $gitTask
    if ([System.IO.File]::ReadAllText((Join-Path $worktree 'source.txt')) -cne [System.IO.File]::ReadAllText($fixtureSource)) { throw 'Detached worktree did not contain committed fixture input.' }
    'Worker-only change' | Set-Content -LiteralPath (Join-Path $worktree 'source.txt') -Encoding UTF8
    if ([System.IO.File]::ReadAllText($fixtureSource) -notmatch 'Committed fixture input') { throw 'Worktree edits changed the original checkout.' }
    'User change' | Set-Content -LiteralPath $fixtureSource -Encoding UTF8
    'Untracked evidence' | Set-Content -LiteralPath (Join-Path $gitProject 'extra input.txt') -Encoding UTF8
    $dirtySnapshot = Get-HarnessSnapshot $gitPaths $gitConfig $gitProject | ConvertFrom-Json
    if (-not $dirtySnapshot.diff -or @($dirtySnapshot.untracked).Count -ne 1 -or $dirtySnapshot.untracked[0].path -cne 'extra input.txt') { throw 'Snapshot lost tracked or untracked input evidence.' }
    $combinedSnapshot = Get-HarnessSnapshot $gitPaths $gitConfig $gitProject $aheadBase.commit | ConvertFrom-Json
    if ($combinedSnapshot.diff -notmatch 'Committed ahead fixture' -or $combinedSnapshot.diff -notmatch 'User change' -or $combinedSnapshot.untracked[0].path -cne 'extra input.txt') { throw 'Ahead review did not include committed, working, and untracked changes in the same snapshot.' }
    $gitTask.id = 'T-002'
    Assert-HarnessFailure { Get-HarnessWorkspace $gitPaths $gitConfig $gitTask } 'Uncommitted project inputs'
    $gitConfig.runner.workspaceMode = 'current'
    Assert-HarnessFailure { Get-HarnessWorkspace $gitPaths $gitConfig $gitTask } 'Uncommitted project inputs'
    $gitTask.useWorkingChanges = $true
    if ((Get-HarnessWorkspace $gitPaths $gitConfig $gitTask) -ine $gitProject) { throw 'Explicit current-checkout approval was ignored.' }
    $gitTask.workspace = $gitProject
    $gitConfig.runner.workspaceMode = 'worktree'
    $gitConfig | Add-Member -NotePropertyName restrictions -NotePropertyValue ([pscustomobject]@{ workspaceModes = @('worktree') })
    Assert-HarnessFailure { Get-HarnessWorkspace $gitPaths $gitConfig $gitTask } 'workspaceModes'

    $queuedState = Read-HarnessState $paths
    $queuedState.nextQueue = @($task.id)
    $queuedTask = Get-HarnessTask $queuedState $task.id
    $queuedTask.risk = 'High'
    if ($null -ne (Select-HarnessTask $queuedState)) { throw 'A queued task bypassed its revised risk gate.' }
    $queuedTask.risk = 'Low'
    $queuedTask.acceptance = ' '
    if ($null -ne (Select-HarnessTask $queuedState)) { throw 'A queued task bypassed its missing acceptance gate.' }
    $queuedState.nextQueue = @()
    if ($null -ne (Select-HarnessTask $queuedState)) { throw 'Automatic pickup bypassed its missing acceptance gate.' }

    Assert-HarnessFailure { Assert-HarnessRunnerConfig $config } 'runner.model'
    $config.runner.model = 'fixture-model'
    $config.runner.reasoningEffort = 'high'
    $config.runner.maxMinutes = 2
    $config.runner.maxCredits = 1
    $config.runner.criticalReview = $true
    $config.runner.maxTasksPerCycle = 3
    $config.runner.workspaceMode = 'current'
    $config.runner.allowedTools = @('write')
    $config.runner.availableTools = @('view', 'edit')
    $config.runner.validationCommands = @([pscustomobject]@{ executable = 'fixture-check'; arguments = @('test') })
    $ruleFile = Join-Path $fixtureRoot 'rules.md'
    'Fixture rule: preserve all user decisions.' | Set-Content -LiteralPath $ruleFile
    $config.runner.rulesPath = $ruleFile
    Assert-HarnessRunnerConfig $config
    $script:agentArguments = @()
    $script:agentOutput = '{"outcome":"ready","summary":"Fixture implementation ready"}'
    $script:agentExitCode = 0
    $script:agentError = ''
    $script:phaseResponses = $false
    $script:processDirectories = @()
    function Invoke-HarnessProcess {
        param($Executable, $Arguments, $Directory, $MaxMinutes, $InputText)
        $script:agentArguments = $Arguments
        $script:agentInput = $InputText
        $script:processDirectories += $Directory
        $output = $script:agentOutput
        if ($script:phaseResponses -and ($Arguments -join "`n") -match 'Phase: Develop') { $output = '{"outcome":"ready","summary":"Referenced fixture ready"}' }
        [pscustomobject]@{ ExitCode = $script:agentExitCode; Output = $output; Error = $script:agentError; TimedOut = $false }
    }
    $developmentResult = Invoke-HarnessAgent $paths $config $task $fixtureRoot 'Develop' 'fixture-snapshot'
    if ($script:agentArguments -notcontains '--silent' -or $script:agentArguments -notcontains '--model' -or $script:agentArguments -notcontains '--max-ai-credits' -or $script:agentArguments -contains '--allow-all-tools') { throw 'Runner arguments lost explicit settings or granted unrestricted tools.' }
    $formatIndex = [Array]::IndexOf($script:agentArguments, '--output-format')
    $streamIndex = [Array]::IndexOf($script:agentArguments, '--stream')
    if ($formatIndex -lt 0 -or $script:agentArguments[$formatIndex + 1] -cne 'text' -or $streamIndex -lt 0 -or $script:agentArguments[$streamIndex + 1] -cne 'off') { throw 'The single-envelope parser requires silent text output with streaming explicitly off, not CLI JSONL events.' }
    if ($developmentResult.outcome -cne 'ready' -or $developmentResult.summary -cne 'Fixture implementation ready') { throw 'Development output did not round-trip through the actual envelope parser.' }
    if (($script:agentArguments -join "`n") -notmatch 'preserve all user decisions') { throw 'Worker did not receive Rules Core.' }
    $nativeConfig = $config | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $nativeConfig.runner = [pscustomobject]@{ command = 'copilot'; rulesPath = $ruleFile; model = 'Max'; workspaceMode = 'None'; maxMinutes = 'Max'; maxCredits = 'None'; allowedTools = @(); availableTools = 'None' }
    $nativeConfig | Add-Member -NotePropertyName restrictions -NotePropertyValue ([pscustomobject]@{ allowedModels = @(); allowedTools = ''; availableTools = @(' '); maxAgentCredits = 'Max' }) -Force
    $nativeDevelopment = Invoke-HarnessAgent $paths $nativeConfig $task $fixtureRoot Develop 'native-fixture'
    if ($nativeDevelopment.outcome -cne 'ready' -or $script:agentArguments -notcontains '--auto-tier' -or $script:agentArguments -notcontains 'intelligence' -or $script:agentArguments -contains '--max-ai-credits' -or $script:agentArguments -contains '--reasoning-effort' -or @($script:agentArguments | Where-Object { $_ -like '--available-tools=*' -or $_ -like '--allow-tool=*' -or $_ -eq '--no-auto-login' -or $_ -eq '--disable-builtin-mcps' -or $_ -eq '--disallow-temp-dir' }).Count -gt 0) { throw 'Native development inheritance added caps, permissions, authentication suppression, or tool restrictions that were not supplied.' }
    [IO.File]::WriteAllText((Join-Path $folderProject 'AGENTS.md'), 'Controller convention fixture.')
    [IO.File]::WriteAllText((Join-Path $gitProject 'AGENTS.md'), 'Referenced repository convention fixture.')
    [IO.File]::WriteAllText((Join-Path $otherGitProject 'AGENTS.md'), 'Other coding repository convention fixture.')
    $null = Invoke-HarnessAgent $folderPaths $config $folderWorktreeTask $folderWorktree Develop 'referenced-worktree-snapshot'
    if ($script:agentArguments[1] -ine $folderWorktree -or ($script:agentArguments -join "`n") -notmatch 'Controller convention fixture' -or ($script:agentArguments -join "`n") -notmatch 'Referenced repository convention fixture') { throw 'A referenced worktree worker lost its controller or coding repository instructions.' }
    $folderContext = & $dispatcher -ProjectPath $folderProject -Action Context -Id $folderWorktreeTask.id | ConvertFrom-Json
    if ($folderContext.project -cne $folderProject -or $folderContext.repository.id -cne $repoReference.id -or $folderContext.instructionCandidates -notcontains (Join-Path $gitProject 'AGENTS.md')) { throw 'Task context did not distinguish the controller and selected coding repository.' }
    $script:agentOutput = '{"verdict":"clean","summary":"Fixture clean","findings":[]}'
    $null = Invoke-HarnessAgent $paths $config $task $fixtureRoot 'Review' 'fixture-snapshot'
    if ($script:agentArguments -notcontains '--deny-tool=write' -or $script:agentArguments -notcontains '--deny-tool=shell' -or $script:agentArguments -contains '--allow-tool=write') { throw 'Reviewer received mutating permissions.' }
    if ($script:agentArguments -contains '--deny-tool=') { throw 'An absent restriction policy emitted an empty CLI denial.' }
    $config.runner | Add-Member -NotePropertyName contextTier -NotePropertyValue long_context
    $prTask = [pscustomobject]@{ id = ''; kind = 'verify'; untrustedInput = $true; reviewWorkspace = $gitProject }
    $null = Invoke-HarnessAgent $paths $config $prTask $gitProject Review 'large-pr-snapshot'
    if ($script:agentArguments[1] -cne $paths.Project -or $script:agentArguments -notcontains '--no-custom-instructions' -or $script:agentArguments -notcontains 'long_context' -or $script:agentInput -notmatch 'untrusted review evidence' -or $script:agentInput -notmatch 'large-pr-snapshot' -or $script:agentArguments[3] -match 'large-pr-snapshot') { throw 'PR review lost trusted launch, context tier, or streamed untrusted evidence.' }
    if ($script:agentInput -match 'Referenced repository convention fixture') { throw 'Untrusted PR repository instructions were injected as trusted worker rules.' }
    $config.runner.PSObject.Properties.Remove('contextTier')
    $config | Add-Member -NotePropertyName restrictions -NotePropertyValue ([pscustomobject]@{ deniedTools = @('url'); maxAgentCredits = 0.5 })
    $null = Invoke-HarnessAgent $paths $config $task $fixtureRoot 'Review' 'fixture-snapshot'
    $creditIndex = [Array]::IndexOf($script:agentArguments, '--max-ai-credits')
    if ($script:agentArguments[$creditIndex + 1] -cne '0.5' -or $script:agentArguments -notcontains '--deny-tool=url') { throw 'Agent arguments did not retain the stricter credit cap and declared denial.' }
    $config.PSObject.Properties.Remove('restrictions')
    $folderConfig.runner = $config.runner | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    Write-HarnessJson $folderPaths.Config $folderConfig
    $null = Queue-HarnessTask -Paths $folderPaths -Id $otherRepoTask.id -Mode now -UseWorkingChanges
    $script:processDirectories = @()
    $script:phaseResponses = $true
    $folderOutcome = Invoke-HarnessCycle $folderPaths
    $script:phaseResponses = $false
    $folderState = Read-HarnessState $folderPaths
    $completedRepoTask = Get-HarnessTask $folderState $otherRepoTask.id
    if ($folderOutcome.status -cne 'Completed' -or $completedRepoTask.repositoryRef -cne $otherRepoReference.id -or $completedRepoTask.repositoryRoot -cne $otherGitProject -or $script:processDirectories.Count -ne 4 -or @($script:processDirectories | Where-Object { $_ -ine $otherGitProject }).Count -ne 0) { throw 'A complete referenced-repository cycle did not persist and use the selected target through all four phases.' }
    if (@($folderState.runs | Where-Object { $_.repositoryRef -cne $otherRepoReference.id -or $_.repositoryRoot -cne $otherGitProject -or -not (Test-Path -LiteralPath $_.report) -or [IO.Path]::GetRelativePath($folderPaths.Control, $_.report).StartsWith('..') }).Count -ne 0 -or (Test-Path -LiteralPath (Join-Path $otherGitProject '.harness_sv')) -or (Test-Path -LiteralPath (Join-Path $otherGitProject 'current.csv'))) { throw 'Referenced development placed default state or reports outside the controller .harness_sv directory.' }
    $folderReview = Invoke-HarnessReview $folderPaths -RepoRef $otherRepoReference.id
    if ($folderReview.status -cne 'clean' -or $folderReview.passes -ne 2 -or $folderReview.repositoryRoot -cne $otherGitProject -or $folderReview.baseline.selection -cne 'WorkingChangesOnly') { throw 'Standalone referenced review did not resolve its own repository baseline and independent passes.' }
    if ([IO.Path]::GetRelativePath($folderPaths.Control, $folderReview.report).StartsWith('..')) { throw 'Standalone review wrote default evidence outside .harness_sv.' }
    $inheritedTask = Add-HarnessTask -Paths $folderPaths -Title 'Inherited worker cycle' -Description 'Use the parent allowances' -Scope 'source.txt' -Acceptance 'Complete all real harness phases in the fixture' -Risk Low -RepoRef $otherRepoReference.id
    $null = Queue-HarnessTask -Paths $folderPaths -Id $inheritedTask.id -Mode now -UseWorkingChanges
    $emptyRunnerConfig = $folderConfig | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $emptyRunnerConfig.runner = [pscustomobject]@{ rulesPath = $ruleFile }
    Write-HarnessJson $folderPaths.Config $emptyRunnerConfig
    $script:processDirectories = @()
    $script:phaseResponses = $true
    $inheritedOutcome = Invoke-HarnessCycle -Paths $folderPaths -RunnerContext ([pscustomobject]@{ runner = $config.runner })
    $script:phaseResponses = $false
    $inheritedRuns = @((Read-HarnessState $folderPaths).runs | Where-Object taskId -CEQ $inheritedTask.id)
    if ($inheritedOutcome.status -cne 'Completed' -or $script:processDirectories.Count -ne 4 -or $inheritedRuns.Count -ne 4 -or @($inheritedRuns | Where-Object model -CNE $config.runner.model).Count -ne 0 -or $null -ne (Read-HarnessConfig $folderPaths).runner.model) { throw 'Parent allowances did not reach a complete development/validation/review cycle without persistence.' }
    Write-HarnessJson $folderPaths.Config $folderConfig
    $securityDirectory = Join-Path $fixtureRoot '.github/skills/differential-review'
    New-Item -ItemType Directory -Path $securityDirectory -Force | Out-Null
    'Fixture security methodology: verify the actor and reachable impact.' | Set-Content -LiteralPath (Join-Path $securityDirectory 'SKILL.md') -Encoding UTF8
    $securityContext = Get-HarnessReviewSecurityContext $paths
    $null = Invoke-HarnessAgent $paths $config $task $fixtureRoot Fresh 'fixture-snapshot' -ReviewGuidance $securityContext.content
    if (($script:agentArguments -join "`n") -notmatch 'Fixture security methodology' -or ($script:agentArguments -join "`n") -notmatch 'one fresh full-scope pass' -or $script:agentArguments -notcontains '--deny-tool=shell') { throw 'Fresh security review lost its supplied methodology, fresh instruction, or read-only permissions.' }
    $freshPrompt = $script:agentArguments[3]
    if ($freshPrompt -notmatch 'whole selected repository, including unchanged code' -or $freshPrompt -notmatch 'return blocked' -or $freshPrompt -match 'in the requested change set\.' -or $task.scope -cne 'fixture.txt') { throw 'Fresh retained a change-only contract, lost its coverage gate, or mutated the original task scope.' }
    foreach ($reviewPhase in @('Review', 'Critical')) {
        $null = Invoke-HarnessAgent $paths $config $task $fixtureRoot $reviewPhase 'fixture-snapshot'
        if ($script:agentArguments[3] -notmatch 'in the requested change set\.' -or $script:agentArguments[3] -match 'changeScope identifies the first pass' -or $script:agentArguments -notcontains '--deny-tool=shell') { throw 'Ordinary or critical review widened its scope or permissions.' }
    }
    $recheckTask = $task | Select-Object *
    $recheckTask | Add-Member -NotePropertyName recheckFindings -NotePropertyValue @([pscustomobject]@{ file = 'unchanged.txt'; line = 2; severity = 'P2'; message = 'Earlier unresolved fixture issue' })
    foreach ($reviewPhase in @('Review', 'Fresh')) {
        $null = Invoke-HarnessAgent $paths $config $recheckTask $fixtureRoot $reviewPhase 'fixture-snapshot'
        if ($script:agentArguments[3] -notmatch 'Earlier unresolved fixture issue' -or $script:agentArguments[3] -notmatch 'not trusted conclusions' -or $script:agentArguments[3] -notmatch 'including issues outside the latest diff' -or $script:agentArguments -notcontains '--deny-tool=write') { throw 'A continued reviewer lost prior issues, current-evidence rechecking, or read-only permissions.' }
    }
    $script:agentOutput = '{"verdict":"findings","summary":"Fixture malformed finding","findings":[{"file":"fixture.txt","line":0,"message":"No valid anchor"}]}'
    Assert-HarnessFailure { Invoke-HarnessAgent $paths $config $task $fixtureRoot Review '' } 'positive line number'
    foreach ($phase in @('Develop', 'Review', 'Critical', 'Fresh')) {
        $validOutput = if ($phase -eq 'Develop') { '{"outcome":"ready","summary":"Parsed final response"}' } else { '{"verdict":"clean","summary":"Parsed final response","findings":[]}' }
        $script:agentOutput = $validOutput
        $parsedResult = Invoke-HarnessAgent $paths $config $task $fixtureRoot $phase 'parser-fixture'
        if ($parsedResult.summary -cne 'Parsed final response') { throw "The $phase worker did not return its parsed result." }
        if ($phase -eq 'Develop') {
            $null = Invoke-HarnessAgent $commandPaths $config $followUp $fixtureRoot $phase 'follow-up-fixture'
            if (($script:agentArguments -join "`n") -notmatch 'Completed task evidence') { throw 'The follow-up developer did not receive the prior completion evidence.' }
        }
        foreach ($emptyOutput in @('', " `r`n ")) {
            $script:agentOutput = $emptyOutput
            Assert-HarnessFailure { Invoke-HarnessAgent $paths $config $task $fixtureRoot $phase '' } 'no final response'
        }
        foreach ($invalidObject in @('null', '[]', "[$validOutput]", '"scalar response"', 'true', '42')) {
            $script:agentOutput = $invalidObject
            Assert-HarnessFailure { Invoke-HarnessAgent $paths $config $task $fixtureRoot $phase '' } 'exactly one JSON object'
        }
        $script:agentOutput = '{"event":"result","content":' + $validOutput + '}'
        Assert-HarnessFailure { Invoke-HarnessAgent $paths $config $task $fixtureRoot $phase '' } 'result envelope'
        foreach ($invalidSummary in @(' ', @('not a string'))) {
            $invalidPayload = $validOutput | ConvertFrom-Json
            $invalidPayload.summary = $invalidSummary
            $script:agentOutput = $invalidPayload | ConvertTo-Json -Depth 5 -Compress
            Assert-HarnessFailure { Invoke-HarnessAgent $paths $config $task $fixtureRoot $phase '' } 'result envelope'
        }
        $script:agentOutput = '{"event":"started"}' + "`n" + $validOutput
        Assert-HarnessFailure { Invoke-HarnessAgent $paths $config $task $fixtureRoot $phase '' } 'required JSON result'
        $script:agentOutput = '```json' + "`n" + $validOutput + "`n" + '```'
        Assert-HarnessFailure { Invoke-HarnessAgent $paths $config $task $fixtureRoot $phase '' } 'required JSON result'
    }
    $script:agentOutput = 'not JSON'
    Assert-HarnessFailure { Invoke-HarnessAgent $paths $config $task $fixtureRoot 'Review' '' } 'required JSON'
    $script:agentExitCode = 23
    $script:agentError = 'Fixture process failure'
    $script:agentOutput = '{"outcome":"ready","summary":"Must not override a failed process"}'
    Assert-HarnessFailure { Invoke-HarnessAgent $paths $config $task $fixtureRoot Develop '' } 'exit 23'
    $script:agentExitCode = 0
    $script:agentError = ''
    $script:agentOutput = 'Invalid output that an Idle cycle must never read'
    $idleProject = Join-Path $fixtureRoot 'idle output contract'
    New-Item -ItemType Directory -Path $idleProject | Out-Null
    $idlePaths = Get-HarnessPaths $idleProject
    $idleConfig = Initialize-Harness $idlePaths
    $idleConfig.runner = $config.runner | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    Write-HarnessJson $idlePaths.Config $idleConfig
    $callsBeforeIdle = $script:processDirectories.Count
    $idleResult = Invoke-HarnessCycle $idlePaths
    if ($idleResult.status -cne 'Idle' -or $script:processDirectories.Count -ne $callsBeforeIdle -or @((Read-HarnessState $idlePaths).runs).Count -ne 0) { throw 'An Idle cycle launched a worker or recorded evidence of a result it never parsed.' }
    $config.testing = [pscustomobject]@{
        environments = @([pscustomobject]@{ name = 'local'; workingDirectory = '.'; variables = @{}; requiredVariables = @(); allowScheduled = $false })
        flows = @([pscustomobject]@{ name = 'regression'; method = 'Verify task regression'; defaultEnvironment = 'local'; maxMinutes = 1; steps = @([pscustomobject]@{ name = 'checks'; executable = 'pwsh'; arguments = @('fixture') }) })
        afterDev = @([pscustomobject]@{ flow = 'regression'; environment = 'local' })
    }
    $config.runner.validationCommands = @()
    Assert-HarnessRunnerConfig $config
    Write-HarnessJson $paths.Config $config
    function Get-HarnessWorkspace { param($Paths, $Config, $Task); $fixtureRoot }
    function Resolve-HarnessReviewBaseline { param($Paths, $BaseRef); [pscustomobject]@{ reference = 'fixture-upstream'; commit = 'fixture-base'; selection = 'Upstream' } }
    function Get-HarnessSnapshot { param($Paths, $Config, $Workspace, $BaseRef); '{"head":"fixture-head","base":"fixture-head","diff":"","untracked":[]}' }
    $script:phases = @()
    $script:reviewGuidance = @()
    function Invoke-HarnessAgent {
        param($Paths, $Config, $Task, $Workspace, $Phase, $Snapshot, $ReviewGuidance)
        $script:phases += $Phase
        if ($ReviewGuidance) { $script:reviewGuidance += $ReviewGuidance }
        if ($Phase -eq 'Develop') { return [pscustomobject]@{ outcome = 'ready'; summary = 'Fixture ready' } }
        [pscustomobject]@{ verdict = 'clean'; summary = 'Fixture clean'; findings = @() }
    }
    function Invoke-HarnessProcess { param($Executable, $Arguments, $Directory, $MaxMinutes); [pscustomobject]@{ ExitCode = 0; Output = 'Fixture checks passed'; Error = ''; TimedOut = $false } }
    $null = Queue-HarnessTask $paths $task.id 'next'
    $otherControllerLease = Enter-SkillOwnership -Resources @([pscustomobject]@{ kind = 'checkout'; path = $fixtureRoot; mode = 'Write' }) -Owner ([pscustomobject]@{ controller = 'other fixture controller' })
    try {
        $busyRun = Invoke-HarnessCycle $paths
        if ($busyRun.status -cne 'Busy' -or $busyRun.owner.controller -cne 'other fixture controller' -or $script:phases.Count) { throw 'Cross-controller ownership did not block development before starting a worker.' }
    }
    finally { Exit-SkillOwnership $otherControllerLease }
    $outcome = Invoke-HarnessCycle $paths
    if ($outcome.status -cne 'Completed' -or ($script:phases -join ',') -cne 'Develop,Review,Critical') { throw 'Task did not complete through distinct development and review passes.' }
    $state = Read-HarnessState $paths
    if (@($state.runs).Count -ne 4 -or $state.active -or @((Import-Csv -LiteralPath (Join-Path $fixtureRoot 'board/current.csv'))).Count -ne 0) { throw 'Completed task state or CSV view is incorrect.' }
    if (-not (Test-Path -LiteralPath $outcome.report)) { throw 'Run report was not written.' }
    $review = Invoke-HarnessReview $paths
    if ($review.passes -ne 2 -or $review.status -cne 'clean' -or $script:phases[-1] -cne 'Fresh') { throw 'Independent clean review did not run exactly one fresh full-scope pass.' }
    if (-not $review.complete -or $review.nextPhase) { throw 'A stable clean Changes/Full round did not complete the review.' }
    if ($review.baseline.reference -cne 'fixture-upstream' -or [System.IO.File]::ReadAllText($review.report) -notmatch 'Base commit: fixture-base') { throw 'Independent review did not report its selected comparison baseline.' }
    if ([IO.File]::ReadAllText($review.report) -notmatch '"requestedScope": "Whole selected repository"') { throw 'The review report did not identify the Fresh pass scope.' }
    $securityReview = Invoke-HarnessReview $paths -SecurityReview
    if ($securityReview.passes -ne 2 -or $securityReview.securityGuide -cne $securityContext.path -or $script:reviewGuidance.Count -ne 2 -or @($script:reviewGuidance | Where-Object { $_ -cne $securityContext.content }).Count -ne 0) { throw 'The security sub-skill was not delivered to both independent passes.' }
    if ($securityReview.previousReport) { throw 'General-review history was reused as a security-specific comparison.' }
    $beforeMissingGuide = @((Read-HarnessState $paths).runs).Count
    '' | Set-Content -LiteralPath $securityContext.path -Encoding UTF8
    Assert-HarnessFailure { Invoke-HarnessReview $paths -SecurityReview } 'guide is empty'
    if (@((Read-HarnessState $paths).runs).Count -ne $beforeMissingGuide -or $script:reviewGuidance.Count -ne 2) { throw 'Unavailable requested security guidance started a review or silently fell back to general review.' }
    $securityContext.content | Set-Content -LiteralPath $securityContext.path -Encoding UTF8
    Assert-HarnessFailure { & $dispatcher -ProjectPath $fixtureRoot -Action Status -SecurityReview } 'only to the independent Review'
    $reviewFinding = [pscustomobject]@{ file = 'fixture.txt'; line = 1; severity = 'P2'; message = 'Supported fixture defect' }
    function Invoke-HarnessAgent {
        param($Paths, $Config, $Task, $Workspace, $Phase, $Snapshot)
        if ($Phase -eq 'Fresh') { return [pscustomobject]@{ verdict = 'clean'; summary = 'No additional findings'; findings = @() } }
        [pscustomobject]@{ verdict = 'findings'; summary = 'Fixture defect'; findings = @($reviewFinding) }
    }
    $firstFinding = Invoke-HarnessReview $paths
    $repeatedFinding = Invoke-HarnessReview $paths
    if ($firstFinding.passes -ne 1 -or $firstFinding.newFindingCount -ne 1 -or $repeatedFinding.passes -ne 2 -or $repeatedFinding.newFindingCount -ne 0 -or $repeatedFinding.status -cne 'findings' -or $repeatedFinding.findings.Count -ne 1) { throw 'No-new-finding refresh either repeated indefinitely or erased an unresolved finding.' }
    if ($firstFinding.complete -or $repeatedFinding.complete -or $firstFinding.nextPhase -cne 'Review' -or $repeatedFinding.nextPhase -cne 'Review') { throw 'Unfixed findings were treated as workflow completion instead of a Changes-review continuation.' }
    $checkpointState = Read-HarnessState $paths
    $checkpointRun = $checkpointState.runs | Select-Object -Last 1
    if ($checkpointState.active -or $checkpointRun.review.complete -or $checkpointRun.review.nextPhase -cne 'Review') { throw 'The findings checkpoint retained execution ownership or lost its continuation state.' }
    $fixerLock = Enter-HarnessLock $paths.RunLock
    $fixerLock.Dispose()
    if ($repeatedFinding.previousReport -cne $firstFinding.report -or -not (Test-Path -LiteralPath $firstFinding.report)) { throw 'Review comparison lost the earlier evidence report.' }
    $referenceFinding = Invoke-HarnessReview $folderPaths -RepoRef $otherRepoReference.id
    $referenceRepeat = Invoke-HarnessReview $folderPaths -RepoRef $otherRepoReference.id
    $differentRepositoryFinding = Invoke-HarnessReview $folderPaths -RepoRef $repoReference.id
    if ($referenceFinding.newFindingCount -ne 1 -or $referenceRepeat.newFindingCount -ne 0 -or $referenceRepeat.previousReport -cne $referenceFinding.report -or $differentRepositoryFinding.newFindingCount -ne 1 -or $differentRepositoryFinding.previousReport) { throw 'Independent reviews mixed finding history between selected repository references.' }
    $reviewLoopFixture = [pscustomobject]@{ Revision = 0; Phases = @(); Rechecks = @() }
    $fullFinding = [pscustomobject]@{ file = 'unchanged.txt'; line = 2; severity = 'P2'; message = 'Whole-repository fixture defect' }
    function Get-HarnessSnapshot {
        param($Paths, $Config, $Workspace, $BaseRef)
        if ($BaseRef -cne 'fixture-base') { throw 'Review continuation lost the comparison baseline.' }
        "fix-revision-$($reviewLoopFixture.Revision)"
    }
    function Invoke-HarnessAgent {
        param($Paths, $Config, $Task, $Workspace, $Phase, $Snapshot)
        $reviewLoopFixture.Phases += $Phase
        $reviewLoopFixture.Rechecks += [pscustomobject]@{ revision = $reviewLoopFixture.Revision; findings = @($Task.recheckFindings) }
        if ($reviewLoopFixture.Revision -eq 0) { return [pscustomobject]@{ verdict = 'findings'; summary = 'Change needs a fix'; findings = @($reviewFinding) } }
        if ($reviewLoopFixture.Revision -eq 1 -and $Phase -eq 'Fresh') { return [pscustomobject]@{ verdict = 'findings'; summary = 'Full review needs a fix'; findings = @($fullFinding) } }
        [pscustomobject]@{ verdict = 'clean'; summary = 'Earlier issues rechecked and fixed'; findings = @() }
    }
    $roundWithChanges = Invoke-HarnessReview $paths -Scope 'Reviewer-only loop fixture'
    $reviewLoopFixture.Revision = 1
    $roundWithFullFindings = Invoke-HarnessReview $paths -Scope 'Reviewer-only loop fixture'
    $reviewLoopFixture.Revision = 2
    $clearRound = Invoke-HarnessReview $paths -Scope 'Reviewer-only loop fixture'
    if ($roundWithChanges.complete -or $roundWithFullFindings.complete -or -not $clearRound.complete -or $clearRound.findings.Count) { throw 'The review workflow completed before externally fixed Changes and Full findings were cleared.' }
    if (($reviewLoopFixture.Phases -join ',') -cne 'Review,Review,Fresh,Review,Fresh') { throw 'A fix did not resume from Changes before Full, or a reviewer attempted to develop code.' }
    if ($reviewLoopFixture.Rechecks[1].findings[0].message -cne $reviewFinding.message -or $reviewLoopFixture.Rechecks[3].findings[0].message -cne $fullFinding.message) { throw 'Resumed review lost an unresolved issue from the earlier Changes or Full pass.' }
    if (-not (Test-Path -LiteralPath $roundWithChanges.report) -or -not (Test-Path -LiteralPath $roundWithFullFindings.report)) { throw 'Review continuation replaced earlier findings reports.' }
    function Invoke-HarnessAgent {
        param($Paths, $Config, $Task, $Workspace, $Phase, $Snapshot)
        if ($Phase -eq 'Develop') { return [pscustomobject]@{ outcome = 'ready'; summary = 'Fixture ready' } }
        [pscustomobject]@{ verdict = 'blocked'; summary = 'Insufficient fixture evidence'; findings = @() }
    }
    $blockedReview = Invoke-HarnessReview $paths
    if ($blockedReview.status -cne 'blocked' -or $blockedReview.passes -ne 1) { throw 'A blocked review was treated as a no-new-findings trigger.' }
    $acquisitionCheck = [pscustomobject]@{ Reads = 0; Workers = 0 }
    function Get-HarnessSnapshot {
        param($Paths, $Config, $Workspace, $BaseRef)
        $acquisitionCheck.Reads++
        "acquisition-$($acquisitionCheck.Reads)"
    }
    function Invoke-HarnessAgent { $acquisitionCheck.Workers++; throw 'A reviewer started on unstable acquisition inputs.' }
    Assert-HarnessFailure { Invoke-HarnessReview $paths } 'changed while acquiring checkout ownership'
    if ($acquisitionCheck.Workers) { throw 'Ownership acquisition started a reviewer before verifying stable inputs.' }
    $reviewSnapshotCheck = [pscustomobject]@{ Reads = 0; Workers = 0; Phases = @(); Snapshots = @() }
    function Get-HarnessSnapshot {
        param($Paths, $Config, $Workspace, $BaseRef)
        $reviewSnapshotCheck.Reads++
        if ($BaseRef -cne 'fixture-base') { throw 'The resolved baseline was not pinned for snapshot verification.' }
        if ($reviewSnapshotCheck.Workers -gt 0) { return 'changed-snapshot' }
        'initial-snapshot'
    }
    function Invoke-HarnessAgent {
        param($Paths, $Config, $Task, $Workspace, $Phase, $Snapshot)
        $reviewSnapshotCheck.Workers++
        $reviewSnapshotCheck.Phases += $Phase
        $reviewSnapshotCheck.Snapshots += $Snapshot
        if ($reviewSnapshotCheck.Workers -eq 1) { return [pscustomobject]@{ verdict = 'findings'; summary = 'Outdated fixture finding'; findings = @($reviewFinding) } }
        [pscustomobject]@{ verdict = 'clean'; summary = 'Fixture claims clean'; findings = @() }
    }
    $changedReview = Invoke-HarnessReview $paths
    if ($changedReview.status -cne 'clean' -or $changedReview.restarts -ne 1 -or $changedReview.passes -ne 3 -or $changedReview.findings.Count) { throw 'A changed local review did not restart or carried stale findings forward.' }
    if (($reviewSnapshotCheck.Phases -join ',') -cne 'Review,Review,Fresh' -or ($reviewSnapshotCheck.Snapshots -join ',') -cne 'initial-snapshot,changed-snapshot,changed-snapshot') { throw 'Review did not restart both passes on the updated snapshot.' }
    if ([IO.File]::ReadAllText($changedReview.report) -notmatch 'Outdated fixture finding') { throw 'Restart discarded superseded review evidence instead of preserving it in the report.' }
    $reviewSnapshotCheck = [pscustomobject]@{ Workers = 0; Revision = 0; Phases = @(); Snapshots = @(); KeepChanging = $false }
    function Get-HarnessSnapshot {
        param($Paths, $Config, $Workspace, $BaseRef)
        if ($BaseRef -cne 'fixture-base') { throw 'A restarted review changed its comparison baseline.' }
        "snapshot-$($reviewSnapshotCheck.Revision)"
    }
    function Invoke-HarnessAgent {
        param($Paths, $Config, $Task, $Workspace, $Phase, $Snapshot)
        $reviewSnapshotCheck.Workers++
        $reviewSnapshotCheck.Phases += $Phase
        $reviewSnapshotCheck.Snapshots += $Snapshot
        if ($Phase -eq 'Fresh' -and ($reviewSnapshotCheck.KeepChanging -or $reviewSnapshotCheck.Workers -eq 2)) {
            $reviewSnapshotCheck.Revision++
            return [pscustomobject]@{ verdict = 'findings'; summary = 'Superseded fresh finding'; findings = @($reviewFinding) }
        }
        [pscustomobject]@{ verdict = 'clean'; summary = 'Stable fixture review'; findings = @() }
    }
    $changedFreshReview = Invoke-HarnessReview $folderPaths -RepoRef $otherRepoReference.id
    if ($changedFreshReview.status -cne 'clean' -or $changedFreshReview.restarts -ne 1 -or $changedFreshReview.passes -ne 4 -or $changedFreshReview.findings.Count -or $changedFreshReview.repositoryRef -cne $otherRepoReference.id) { throw 'A changed Fresh pass did not restart in the selected repository without stale findings.' }
    if (($reviewSnapshotCheck.Phases -join ',') -cne 'Review,Fresh,Review,Fresh' -or ($reviewSnapshotCheck.Snapshots -join ',') -cne 'snapshot-0,snapshot-0,snapshot-1,snapshot-1') { throw 'Fresh-pass changes did not start a new independent review of the new snapshot.' }
    $reviewSnapshotCheck.Workers = 0
    $reviewSnapshotCheck.KeepChanging = $true
    $beforeReviewFailures = @((Read-HarnessState $paths).safety.targets | Where-Object target -EQ review)[0].consecutiveFailures
    $continuousReview = Invoke-HarnessReview $paths
    $continuousState = Read-HarnessState $paths
    $continuousRun = $continuousState.runs | Select-Object -Last 1
    if ($continuousReview.status -cne 'Partial' -or $continuousReview.restarts -ne 2 -or $continuousReview.passes -ne 6 -or $reviewSnapshotCheck.Workers -ne 6 -or $continuousReview.findings.Count -or $continuousReview.newFindingCount) { throw 'Continuously changing reviews were unbounded or reported stale findings as current.' }
    if ($continuousState.active -or $continuousRun.exitCode -ne '1' -or $continuousRun.review.restarts -ne 2 -or @($continuousState.safety.targets | Where-Object target -EQ review)[0].consecutiveFailures -ne $beforeReviewFailures) { throw 'Snapshot churn left an active run, counted as a worker failure, or lost restart evidence.' }
    $reviewSnapshotCheck = [pscustomobject]@{ Reads = 0; Workers = 0 }
    function Get-HarnessSnapshot {
        param($Paths, $Config, $Workspace, $BaseRef)
        $reviewSnapshotCheck.Reads++
        [ordered]@{ head = 'fixture-head'; base = 'fixture-base'; diff = "revision-$($reviewSnapshotCheck.Workers)"; untracked = @() } | ConvertTo-Json -Compress
    }
    function Invoke-HarnessAgent {
        param($Paths, $Config, $Task, $Workspace, $Phase, $Snapshot)
        $reviewSnapshotCheck.Workers++
        [pscustomobject]@{ verdict = 'clean'; summary = 'Pinned PR fixture'; findings = @() }
    }
    $changedPrReview = Invoke-HarnessReview $paths -BaseRef fixture-base -Workspace $gitProject -ExpectedHead fixture-head -UntrustedInput
    if ($changedPrReview.status -cne 'Failed' -or $changedPrReview.restarts -ne 0 -or $reviewSnapshotCheck.Workers -ne 1) { throw 'Snapshot restart bypassed the pinned PR review contract.' }
    function Get-HarnessSnapshot { param($Paths, $Config, $Workspace, $BaseRef); 'stable-error-snapshot' }
    function Invoke-HarnessAgent {
        param($Paths, $Config, $Task, $Workspace, $Phase, $Snapshot)
        $reviewSnapshotCheck.Workers++
        throw 'Fixture reviewer process failure'
    }
    $reviewSnapshotCheck.Workers = 0
    $workerFailure = Invoke-HarnessReview $paths
    if ($workerFailure.status -cne 'Failed' -or $workerFailure.restarts -ne 0 -or $reviewSnapshotCheck.Workers -ne 1) { throw 'Snapshot restart retried an actual reviewer failure.' }
    function Get-HarnessSnapshot { param($Paths, $Config, $Workspace, $BaseRef); '{"head":"fixture-head","base":"fixture-head","diff":"","untracked":[]}' }
    function Invoke-HarnessAgent {
        param($Paths, $Config, $Task, $Workspace, $Phase, $Snapshot)
        if ($Phase -eq 'Develop') { return [pscustomobject]@{ outcome = 'ready'; summary = 'Fixture ready' } }
        [pscustomobject]@{ verdict = 'clean'; summary = 'Fixture clean'; findings = @() }
    }
    $externalReview = Invoke-HarnessReview $paths -Scope 'Verified PR fixture' -BaseRef fixture-base -Workspace $gitProject -ExpectedHead fixture-head -UntrustedInput
    $externalRun = (Read-HarnessState $paths).runs | Select-Object -Last 1
    if ($externalReview.status -cne 'clean' -or $externalRun.workspace -cne $gitProject) { throw 'Explicit PR review did not retain the selected workspace.' }
    $beforeHeadMismatch = @((Read-HarnessState $paths).runs).Count
    Assert-HarnessFailure { Invoke-HarnessReview $paths -BaseRef fixture-base -Workspace $gitProject -ExpectedHead wrong-head -UntrustedInput } 'does not match the verified PR head'
    if (@((Read-HarnessState $paths).runs).Count -ne $beforeHeadMismatch) { throw 'A mismatched PR head started a review.' }
    $failedTask = Add-HarnessTask -Paths $paths -Title 'Validation failure' -Description 'Fixture work' -Scope 'failure' -Acceptance 'Fails clearly' -Kind fix -Risk Low -AutoEligible
    function Invoke-HarnessProcess { param($Executable, $Arguments, $Directory, $MaxMinutes); [pscustomobject]@{ ExitCode = 9; Output = ''; Error = 'Fixture failure'; TimedOut = $false } }
    $failedRun = Invoke-HarnessCycle $paths
    if ($failedRun.status -cne 'Failed' -or (Get-HarnessTask (Read-HarnessState $paths) $failedTask.id).status -cne 'Failed') { throw 'Failed validation was reported as completion.' }
    $config.runner.workspaceMode = 'worktree'
    Write-HarnessJson $paths.Config $config
    $interruptedTask = Add-HarnessTask -Paths $paths -Title 'Interrupted' -Description 'Fixture work' -Scope 'interrupt' -Acceptance 'Resume' -Risk Low -AutoEligible
    $urgentTask = Add-HarnessTask -Paths $paths -Title 'Urgent' -Description 'Fixture work' -Scope 'urgent' -Acceptance 'Run first' -Risk Low
    $preemption = [pscustomobject]@{ Requested = $false }
    function Invoke-HarnessAgent {
        param($Paths, $Config, $Task, $Workspace, $Phase, $Snapshot)
        if ($Task.id -eq $interruptedTask.id -and $Phase -eq 'Develop' -and -not $preemption.Requested) {
            $null = Queue-HarnessTask $Paths $urgentTask.id 'now'
            $preemption.Requested = $true
        }
        if ($Phase -eq 'Develop') { return [pscustomobject]@{ outcome = 'ready'; summary = 'Ready' } }
        [pscustomobject]@{ verdict = 'clean'; summary = 'Clean'; findings = @() }
    }
    function Invoke-HarnessProcess { param($Executable, $Arguments, $Directory, $MaxMinutes); [pscustomobject]@{ ExitCode = 0; Output = 'Pass'; Error = ''; TimedOut = $false } }
    $paused = Invoke-HarnessCycle $paths
    if ($paused.status -cne 'Paused' -or (Select-HarnessTask (Read-HarnessState $paths)).id -cne $urgentTask.id) { throw 'Now did not checkpoint at a phase boundary.' }
    $urgentOutcome = Invoke-HarnessCycle $paths
    if ($urgentOutcome.taskId -cne $urgentTask.id -or (Select-HarnessTask (Read-HarnessState $paths)).id -cne $interruptedTask.id) { throw 'Interrupted work was not first after urgent work.' }
    $resumed = Invoke-HarnessCycle $paths
    if ($resumed.status -cne 'Completed' -or $resumed.taskId -cne $interruptedTask.id) { throw 'Paused task did not resume from its saved phase.' }
    $timerPath = Join-Path $PSScriptRoot '..\skills\planning\harness-timer\scripts\harness-project-timer.ps1'
    $timerState = [pscustomobject]@{ Tasks = @(); Calls = (New-Object 'System.Collections.Generic.List[string]'); EnabledName = ''; DisabledName = '' }
    function Get-ScheduledTask { param($TaskPath); $timerState.Tasks }
    function New-ScheduledTaskAction { param($Execute, $Argument); [pscustomobject]@{ Execute = $Execute; Arguments = $Argument } }
    function New-ScheduledTaskTrigger { param([switch]$Once, $At, $RepetitionInterval); [pscustomobject]@{ At = $At; Interval = $RepetitionInterval; Repetition = [pscustomobject]@{ Interval = [System.Xml.XmlConvert]::ToString([timespan]$RepetitionInterval) } } }
    function New-ScheduledTaskSettingsSet { param($MultipleInstances, [switch]$StartWhenAvailable, [switch]$AllowStartIfOnBatteries, [switch]$DontStopIfGoingOnBatteries, $ExecutionTimeLimit); [pscustomobject]@{ Instances = $MultipleInstances; Limit = $ExecutionTimeLimit } }
    function Register-ScheduledTask {
        param($TaskName, $TaskPath, $Action, $Trigger, $Settings, $Description, [switch]$Force)
        $timerState.Calls.Add('Set')
        $timerState.Tasks = @($timerState.Tasks | Where-Object { $_.TaskName -cne $TaskName }) + @([pscustomobject]@{ TaskName = $TaskName; TaskPath = $TaskPath; State = 'Ready'; Description = $Description; Action = $Action; Actions = @($Action); Trigger = $Trigger; Triggers = @($Trigger); Settings = $Settings })
    }
    function Enable-ScheduledTask { param($TaskName, $TaskPath); $timerState.Calls.Add('Resume'); $timerState.EnabledName = $TaskName }
    function Disable-ScheduledTask { param($TaskName, $TaskPath); $timerState.Calls.Add('Disable'); $timerState.DisabledName = $TaskName }
    $timer = & $timerPath -ProjectPath $fixtureRoot -Action Status | ConvertFrom-Json
    if ($timer.exists -or $timerState.Calls.Count -ne 0) { throw 'Timer status created a schedule.' }
    Assert-HarnessFailure { & $timerPath -ProjectPath $fixtureRoot -Apply } 'No single saved cadence'
    if ($timerState.Calls.Count -ne 0) { throw 'Bare timer invented a cadence and created a task.' }
    Assert-HarnessFailure { & $timerPath -ProjectPath $fixtureRoot -Action Set -IntervalDay 0.5 -Apply } 'not approved'
    if ($timerState.Calls.Count -ne 0) { throw 'Unapproved scheduled validation registered a timer.' }
    $config.testing.environments[0].allowScheduled = $true
    Write-HarnessJson $paths.Config $config
    $createPreview = & $timerPath -ProjectPath $fixtureRoot -Action Set -IntervalDay 0.5 | ConvertFrom-Json
    if ($createPreview.operation -cne 'Create' -or $createPreview.taskPath -cne '\' -or $timerState.Calls.Count -ne 0) { throw 'Timer preview failed to identify a new schedule or changed a live task.' }
    $null = & $timerPath -ProjectPath $fixtureRoot -Action Set -IntervalDay 0.5 -Apply
    if ($timerState.Tasks[0].Trigger.Interval.TotalHours -ne 12 -or $timerState.Tasks[0].Settings.Instances -cne 'IgnoreNew' -or $timerState.Tasks[0].Action.Arguments -notmatch '-Action Cycle') { throw "Timer mismatch: hours=$($timerState.Tasks[0].Trigger.Interval.TotalHours); instances=$($timerState.Tasks[0].Settings.Instances); arguments=$($timerState.Tasks[0].Action.Arguments)" }
    $null = & $timerPath -ProjectPath $fixtureRoot -Action Disable -Apply
    $null = & $timerPath -ProjectPath $fixtureRoot -Action Resume -Apply
    if (($timerState.Calls -join ',') -cne 'Set,Disable,Resume') { throw 'Timer operations changed the wrong actions.' }
    $choicePreview = & $timerPath -ProjectPath $fixtureRoot | ConvertFrom-Json
    if ($choicePreview.status -cne 'NeedsInstanceChoice' -or -not $choicePreview.requiresInstanceChoice -or @($choicePreview.instances).Count -ne 1 -or $timerState.Calls.Count -ne 3) { throw 'A matching timer did not request Reuse or New without changing schedules.' }
    Assert-HarnessFailure { & $timerPath -ProjectPath $fixtureRoot -Apply } 'Confirm Reuse'
    $defaultPreview = & $timerPath -ProjectPath $fixtureRoot -InstanceMode Reuse | ConvertFrom-Json
    $devPreview = & $timerPath -ProjectPath $fixtureRoot -Topic dev -InstanceMode Reuse | ConvertFrom-Json
    if (-not $defaultPreview.preview -or $defaultPreview.action -cne 'Set' -or $defaultPreview.topic -cne 'e2e' -or $defaultPreview.runnerAction -cne 'Cycle' -or $defaultPreview.intervalDay -ne 0.5 -or $devPreview.taskName -cne $defaultPreview.taskName -or $timerState.Calls.Count -ne 3) { throw 'Default E2E setup did not reuse cadence or dev created a competing timer identity.' }
    $null = & $timerPath -ProjectPath $fixtureRoot -InstanceMode Reuse -Apply
    if ($timerState.Tasks.Count -ne 1 -or $timerState.Tasks[0].Trigger.Interval.TotalHours -ne 12) { throw 'Bare applied E2E setup did not retain the exact existing target and cadence.' }
    $updatedE2E = & $timerPath -ProjectPath $fixtureRoot -Topic DEV -IntervalDay 1 -InstanceMode Reuse -Apply | ConvertFrom-Json
    if ($updatedE2E.operation -cne 'Update' -or $updatedE2E.taskName -cne $createPreview.taskName -or $timerState.Tasks.Count -ne 1 -or $timerState.Tasks[0].Trigger.Interval.TotalHours -ne 24) { throw 'Changing the E2E/dev interval created a duplicate or failed to update its existing timer.' }
    $updatedE2E = & $timerPath -ProjectPath $fixtureRoot -Topic e2e -IntervalDay 0.5 -InstanceMode Reuse -Apply | ConvertFrom-Json
    if ($updatedE2E.operation -cne 'Update' -or $timerState.Tasks.Count -ne 1) { throw 'Explicit E2E did not upsert the same default/dev schedule.' }
    $config.runner.criticalReview = $false
    Write-HarnessJson $paths.Config $config
    $reviewPreview = & $timerPath -ProjectPath $fixtureRoot -Topic review -IntervalDay 1 | ConvertFrom-Json
    if ($reviewPreview.runnerAction -cne 'Review' -or $reviewPreview.taskName -ceq $defaultPreview.taskName) { throw 'Review topic did not select its independent review timer.' }
    $null = & $timerPath -ProjectPath $fixtureRoot -Topic review -IntervalDay 1 -Apply
    $reviewTimer = $timerState.Tasks | Where-Object { $_.TaskName -ceq $reviewPreview.taskName }
    if ($reviewTimer.Action.Arguments -notmatch '-Action Review -Scheduled' -or $reviewTimer.Settings.Limit.TotalMinutes -ne 6) { throw 'Review timer lost its read-only runner action or bounded review budget.' }
    $updatedReview = & $timerPath -ProjectPath $fixtureRoot -Topic REVIEW -IntervalDay 0.5 -InstanceMode Reuse -Apply | ConvertFrom-Json
    $reviewTimer = $timerState.Tasks | Where-Object { $_.TaskName -ceq $reviewPreview.taskName }
    if ($updatedReview.operation -cne 'Update' -or $timerState.Tasks.Count -ne 2 -or $reviewTimer.Trigger.Interval.TotalHours -ne 12) { throw 'Repeating the review purpose failed to upsert its existing timer.' }
    $null = Set-HarnessPause $paths review 'Fixture review paused' 'Fixture owner'
    Assert-HarnessFailure { & $timerPath -ProjectPath $fixtureRoot -Topic review -Action Resume -Apply } 'paused'
    $null = Resume-HarnessTarget $paths review -Actor 'Fixture owner' -Reason 'Reviewed cause' -ConfirmStopped
    Assert-HarnessFailure { & $timerPath -ProjectPath $fixtureRoot -Action Set -IntervalDay 0 -InstanceMode Reuse -Apply } 'positive interval'
    $timerState.Tasks[0].Description = 'Unrelated task'
    Assert-HarnessFailure { & $timerPath -ProjectPath $fixtureRoot -Action Disable -Apply } 'different task'
    $originalTimer = $timerState.Tasks[0] | ConvertTo-Json -Depth 10
    $config.runner.model = $null
    Write-HarnessJson $paths.Config $config
    $preview = & $timerPath -ProjectPath $fixtureRoot -Action Set -IntervalDay 0.25 -TestFlow regression -TestEnvironment local | ConvertFrom-Json
    if (-not $preview.preview -or $timerState.Tasks.Count -ne 2) { throw 'Test timer preview created a schedule or required an AI model.' }
    $null = & $timerPath -ProjectPath $fixtureRoot -Action Set -IntervalDay 0.25 -TestFlow regression -TestEnvironment local -Apply
    $testTimer = $timerState.Tasks | Where-Object { $_.TaskName -ceq $preview.taskName }
    if ($timerState.Tasks.Count -ne 3 -or $testTimer.Trigger.Interval.TotalHours -ne 6 -or $testTimer.Action.Arguments -notmatch '-Action Test -Flow "regression" -TestEnvironment "local" -Scheduled' -or $testTimer.Settings.Limit.TotalMinutes -ne 3) { throw 'Test timer did not target its selected flow/environment and budget.' }
    if (($timerState.Tasks[0] | ConvertTo-Json -Depth 10) -cne $originalTimer) { throw 'Test scheduling changed the existing development timer.' }
    $flowUpdatePreview = & $timerPath -ProjectPath $fixtureRoot -Topic TEST -TestFlow REGRESSION -TestEnvironment LOCAL -IntervalDay 0.5 -InstanceMode Reuse | ConvertFrom-Json
    if ($flowUpdatePreview.operation -cne 'Update' -or $flowUpdatePreview.taskName -cne $preview.taskName -or $flowUpdatePreview.testFlow -cne 'regression' -or $flowUpdatePreview.testEnvironment -cne 'local') { throw 'Equivalent flow/environment casing did not resolve the same scheduled purpose.' }
    $updatedFlow = & $timerPath -ProjectPath $fixtureRoot -Topic test -TestFlow REGRESSION -IntervalDay 0.5 -InstanceMode Reuse -Apply | ConvertFrom-Json
    $testTimer = $timerState.Tasks | Where-Object { $_.TaskName -ceq $preview.taskName }
    if ($updatedFlow.operation -cne 'Update' -or $timerState.Tasks.Count -ne 3 -or $testTimer.Trigger.Interval.TotalHours -ne 12) { throw 'The explicit/default flow environment did not upsert a single timer.' }
    $testTimer.TaskName = $testTimer.TaskName.ToUpperInvariant()
    $testTimer.Description = $testTimer.Description.ToUpperInvariant()
    $caseUpdate = & $timerPath -ProjectPath $fixtureRoot -TestFlow regression -IntervalDay 0.25 -InstanceMode Reuse -Apply | ConvertFrom-Json
    if ($caseUpdate.operation -cne 'Update' -or $caseUpdate.taskName -cne $testTimer.TaskName -or $timerState.Tasks.Count -ne 3) { throw 'A differently cased saved timer was missed or duplicated.' }
    $testTimer = $timerState.Tasks | Where-Object { $_.TaskName -ieq $preview.taskName }
    $ownedDescription = $testTimer.Description
    $testTimer.Description = 'Unrelated task'
    $callsBeforeConflict = $timerState.Calls.Count
    Assert-HarnessFailure { & $timerPath -ProjectPath $fixtureRoot -TestFlow regression -TestEnvironment local -IntervalDay 1 -Apply } 'different task'
    if ($timerState.Calls.Count -ne $callsBeforeConflict -or $testTimer.Description -cne 'Unrelated task') { throw 'A case-variant name bypassed timer ownership checks.' }
    $testTimer.Description = $ownedDescription
    Assert-HarnessFailure { & $timerPath -ProjectPath $fixtureRoot -Topic monitor -IntervalDay 0.25 -Apply } 'explicitly declared flow'
    $monitor = & $timerPath -ProjectPath $fixtureRoot -Topic monitor -Flow regression -Environment local -IntervalDay 0.25 -Apply | ConvertFrom-Json
    $monitorTimer = $timerState.Tasks | Where-Object { $_.TaskName -ceq $monitor.taskName }
    if ($timerState.Tasks.Count -ne 4 -or $monitor.taskName -ceq $preview.taskName -or $monitorTimer.Action.Arguments -notmatch '-Action Test -Flow "regression" -TestEnvironment "local" -Scheduled') { throw 'Monitor topic did not use a separately identified approved command flow.' }
    $updatedMonitorFlow = & $timerPath -ProjectPath $fixtureRoot -Topic MONITOR -Flow REGRESSION -Environment LOCAL -IntervalDay 0.5 -InstanceMode Reuse -Apply | ConvertFrom-Json
    $monitorTimer = $timerState.Tasks | Where-Object { $_.TaskName -ceq $monitor.taskName }
    if ($updatedMonitorFlow.operation -cne 'Update' -or $timerState.Tasks.Count -ne 4 -or $monitorTimer.Trigger.Interval.TotalHours -ne 12) { throw 'Repeating a custom-topic flow duplicated its schedule instead of updating it.' }
    $custom = & $timerPath -ProjectPath $fixtureRoot -Topic health -Flow regression -Environment local -IntervalDay 1 | ConvertFrom-Json
    if ($custom.runnerAction -cne 'Test' -or $custom.topic -cne 'health' -or $timerState.Tasks.Count -ne 4) { throw 'Custom topic did not preview its declared command flow without fallback to development.' }
    $null = & $timerPath -ProjectPath $fixtureRoot -Action Resume -TestFlow regression -TestEnvironment local -Apply
    $null = Set-HarnessPause $paths 'test:regression:local' 'Fixture test target paused' 'Fixture owner'
    $callsBeforePause = $timerState.Calls.Count
    Assert-HarnessFailure { & $timerPath -ProjectPath $fixtureRoot -Action Resume -TestFlow regression -TestEnvironment local -Apply } 'paused'
    if ($timerState.Calls.Count -ne $callsBeforePause -or -not (Get-HarnessPause $paths 'test:regression:local')) { throw 'Timer resume bypassed a safety pause or enabled a task.' }
    $timerStatus = & $timerPath -ProjectPath $fixtureRoot -Action Status -TestFlow regression -TestEnvironment local | ConvertFrom-Json
    if (-not $timerStatus.safetyPause.active) { throw 'Timer status hid the persistent safety pause.' }
    $null = Resume-HarnessTarget $paths 'test:regression:local' -Actor 'Fixture owner' -Reason 'Cause inspected' -ConfirmStopped
    $config.testing.flows = @()
    Write-HarnessJson $paths.Config $config
    $null = & $timerPath -ProjectPath $fixtureRoot -Action Disable -TestFlow regression -TestEnvironment local -Apply
    Assert-HarnessFailure { & $timerPath -ProjectPath $fixtureRoot -Action Resume -TestFlow regression -TestEnvironment local -Apply } 'Unknown afterDev'
    $snapshotFile = Join-Path $fixtureRoot 'observation.json'
    '{}' | Set-Content -LiteralPath $snapshotFile
    $monitorDefinition = [pscustomobject]@{
        name = 'health'; source = [pscustomobject]@{ type = 'json-file'; path = $snapshotFile }
        environment = 'local'; resource = 'fixture-api'; metric = 'errors'; windowMinutes = 5; maxAgeMinutes = 10; maxMinutes = 1
        condition = [pscustomobject]@{ operator = 'gt'; threshold = 0 }; allowScheduled = $false
    }
    $config | Add-Member -NotePropertyName monitoring -NotePropertyValue ([pscustomobject]@{ monitors = @($monitorDefinition) })
    Write-HarnessJson $paths.Config $config
    $beforeMonitorTasks = $timerState.Tasks | ConvertTo-Json -Depth 10
    Assert-HarnessFailure { & $timerPath -ProjectPath $fixtureRoot -Topic monitor -MonitorName health -IntervalDay 0.5 -Apply } 'not approved'
    if (($timerState.Tasks | ConvertTo-Json -Depth 10) -cne $beforeMonitorTasks) { throw 'Unapproved monitor created or changed schedules.' }
    $monitorDefinition.allowScheduled = $true
    Write-HarnessJson $paths.Config $config
    $monitorPreview = & $timerPath -ProjectPath $fixtureRoot -MonitorName health -IntervalDay 0.5 | ConvertFrom-Json
    if (-not $monitorPreview.preview -or $monitorPreview.runnerAction -cne 'Monitor' -or ($timerState.Tasks | ConvertTo-Json -Depth 10) -cne $beforeMonitorTasks) { throw 'Named monitor preview used the Test executor, required an AI model, or changed schedules.' }
    $null = & $timerPath -ProjectPath $fixtureRoot -MonitorName health -IntervalDay 0.5 -Apply
    $namedMonitor = $timerState.Tasks | Where-Object { $_.TaskName -ceq $monitorPreview.taskName }
    if ($timerState.Tasks.Count -ne 5 -or $namedMonitor.Action.Arguments -notmatch '-Action Monitor -MonitorName "health" -Scheduled' -or $namedMonitor.Settings.Limit.TotalMinutes -ne 3) { throw 'Named monitor timer lost its isolated identity, executor, or budget.' }
    if (($timerState.Tasks[0] | ConvertTo-Json -Depth 10) -cne $originalTimer) { throw 'Monitor setup changed the unrelated development schedule.' }
    $null = Set-HarnessPause $paths 'monitor:health' 'Fixture pause' Owner
    Assert-HarnessFailure { & $timerPath -ProjectPath $fixtureRoot -MonitorName health -Action Resume -Apply } 'paused'
    $null = Resume-HarnessTarget $paths 'monitor:health' -Actor Owner -Reason Checked -ConfirmStopped
    $monitorReuse = & $timerPath -ProjectPath $fixtureRoot -MonitorName health -InstanceMode Reuse | ConvertFrom-Json
    if ($monitorReuse.intervalDay -ne 0.5) { throw 'Named monitor setup did not reuse its own saved cadence.' }
    $updatedMonitor = & $timerPath -ProjectPath $fixtureRoot -Topic MONITOR -MonitorName HEALTH -IntervalDay 0.25 -InstanceMode Reuse -Apply | ConvertFrom-Json
    $namedMonitor = $timerState.Tasks | Where-Object { $_.TaskName -ceq $monitorPreview.taskName }
    if ($updatedMonitor.operation -cne 'Update' -or $updatedMonitor.monitorName -cne 'health' -or $timerState.Tasks.Count -ne 5 -or $namedMonitor.Trigger.Interval.TotalHours -ne 6) { throw 'Repeating a named monitor purpose duplicated its timer or lost its new interval.' }
    $config.monitoring.monitors = @()
    Write-HarnessJson $paths.Config $config
    $null = & $timerPath -ProjectPath $fixtureRoot -MonitorName health -Action Disable -Apply
    Assert-HarnessFailure { & $timerPath -ProjectPath $fixtureRoot -MonitorName health -Action Resume -Apply } 'Monitor not found'
    $nativeTimerProject = Join-Path $fixtureRoot 'native timer'
    New-Item -ItemType Directory -Path $nativeTimerProject | Out-Null
    $nativeTimerPaths = Get-HarnessPaths $nativeTimerProject
    $nativeTimerConfig = Initialize-Harness $nativeTimerPaths
    $nativeTimerConfig.runner.rulesPath = $ruleFile
    Write-HarnessJson $nativeTimerPaths.Config $nativeTimerConfig
    $nativeTimer = & $timerPath -ProjectPath $nativeTimerProject -IntervalDay 1 -Apply | ConvertFrom-Json
    $nativeSchedule = $timerState.Tasks | Where-Object TaskName -CEQ $nativeTimer.taskName
    if ($nativeSchedule.Settings.Limit -ne [timespan]::Zero) { throw 'A timer with inherited/native allowances invented an execution cap from missing settings.' }
    $timerContext = Join-Path $nativeTimerProject 'session context.json'
    Write-HarnessJson $timerContext ([pscustomobject]@{ runner = [pscustomobject]@{ model = 'inherited-timer'; reasoningEffort = 'high'; maxMinutes = 3; maxCredits = 5; maxTasksPerCycle = 2 } })
    $contextTimer = & $timerPath -ProjectPath $nativeTimerProject -RunnerContextPath $timerContext -InstanceMode Reuse -Apply | ConvertFrom-Json
    $contextSchedule = $timerState.Tasks | Where-Object TaskName -CEQ $nativeTimer.taskName
    if ($contextSchedule.Settings.Limit.TotalMinutes -ne 26 -or $contextSchedule.Action.Arguments -notlike '*-RunnerContextPath*' -or $contextTimer.runnerContextPath -cne $timerContext) { throw 'The timer did not carry inherited limits and its context-file handoff into scheduled execution.' }
    $contextResume = & $timerPath -ProjectPath $nativeTimerProject -Action Resume | ConvertFrom-Json
    if ($contextResume.runnerContextPath -cne $timerContext -or $null -ne (Read-HarnessConfig $nativeTimerPaths).runner.model) { throw 'Timer resume lost the saved context or persisted inherited runner overrides.' }
    $schedulesBeforeNew = $timerState.Tasks | ConvertTo-Json -Depth 15
    $callsBeforeNew = $timerState.Calls.Count
    Assert-HarnessFailure { & $timerPath -ProjectPath $nativeTimerProject -InstanceMode New -IntervalDay 0.25 -Apply } 'distinct -InstanceName'
    Assert-HarnessFailure { & $timerPath -ProjectPath $nativeTimerProject -InstanceMode New -InstanceName secondary -Apply } 'No single saved cadence'
    $namedPreview = & $timerPath -ProjectPath $nativeTimerProject -Topic dev -InstanceMode New -InstanceName secondary -IntervalDay 0.25 | ConvertFrom-Json
    if ($namedPreview.operation -cne 'Create' -or $namedPreview.instanceName -cne 'secondary' -or $timerState.Calls.Count -ne $callsBeforeNew -or ($timerState.Tasks | ConvertTo-Json -Depth 15) -cne $schedulesBeforeNew) { throw 'New instance preview modified an existing schedule.' }
    $namedTimer = & $timerPath -ProjectPath $nativeTimerProject -Topic dev -InstanceMode New -InstanceName secondary -IntervalDay 0.25 -RunnerContextPath $timerContext -Apply | ConvertFrom-Json
    $namedSchedule = $timerState.Tasks | Where-Object TaskName -CEQ $namedTimer.taskName
    $remainingSchedules = @($timerState.Tasks | Where-Object TaskName -CNE $namedTimer.taskName) | ConvertTo-Json -Depth 15
    if ($namedTimer.taskName -cne ($nativeTimer.taskName + ' Instance secondary') -or $namedSchedule.Settings.Instances -cne 'IgnoreNew' -or $namedSchedule.Action.Arguments -notmatch '-Action Cycle -Scheduled' -or $remainingSchedules -cne $schedulesBeforeNew) { throw 'Named development scheduling lost its identity or changed a sibling schedule.' }
    $afterNamed = $timerState.Tasks | ConvertTo-Json -Depth 15
    Assert-HarnessFailure { & $timerPath -ProjectPath $nativeTimerProject -InstanceMode New -InstanceName SECONDARY -IntervalDay 1 -Apply } 'already exists'
    Assert-HarnessFailure { & $timerPath -ProjectPath $nativeTimerProject -InstanceMode Reuse -InstanceName missing -IntervalDay 1 -Apply } 'does not exist to reuse'
    if (($timerState.Tasks | ConvertTo-Json -Depth 15) -cne $afterNamed) { throw 'Rejecting a conflicting New or missing Reuse mutated schedules.' }
    $namedReuse = & $timerPath -ProjectPath $nativeTimerProject -Topic e2e -InstanceMode Reuse -InstanceName SECONDARY -Apply | ConvertFrom-Json
    if ($namedReuse.operation -cne 'Update' -or $namedReuse.taskName -cne $namedTimer.taskName -or $namedReuse.intervalDay -ne 0.25 -or $namedReuse.runnerContextPath -cne $timerContext) { throw 'Reusing a named schedule lost its identity, cadence, or context.' }
    $instanceStatus = & $timerPath -ProjectPath $nativeTimerProject -Action Status -InstanceName secondary | ConvertFrom-Json
    if (-not $instanceStatus.exists -or @($instanceStatus.instances).Count -ne 2 -or @($instanceStatus.instances | Where-Object { -not $_.owned }).Count -gt 0) { throw 'Schedule status did not show both owned instances for the same purpose.' }
    $namedReview = & $timerPath -ProjectPath $nativeTimerProject -Topic review -InstanceMode New -InstanceName independent -IntervalDay 1 -Apply | ConvertFrom-Json
    $reviewInstance = $timerState.Tasks | Where-Object TaskName -CEQ $namedReview.taskName
    if ($reviewInstance.Action.Arguments -notmatch '-Action Review -Scheduled' -or $namedReview.taskName -ceq $namedTimer.taskName) { throw 'Named review did not retain its separate review-only action.' }
    $reviewChoice = & $timerPath -ProjectPath $nativeTimerProject -Topic review | ConvertFrom-Json
    if ($reviewChoice.status -cne 'NeedsInstanceChoice' -or $reviewChoice.instances[0].instanceName -cne 'independent') { throw 'A named-only target silently selected another singleton schedule.' }
    $beforeNamedManagement = $timerState.Tasks | ConvertTo-Json -Depth 15
    $null = & $timerPath -ProjectPath $nativeTimerProject -Action Disable -InstanceName secondary -Apply
    $null = & $timerPath -ProjectPath $nativeTimerProject -Action Resume -InstanceName SECONDARY -Apply
    if ($timerState.DisabledName -cne $namedTimer.taskName -or $timerState.EnabledName -cne $namedTimer.taskName -or ($timerState.Tasks | ConvertTo-Json -Depth 15) -cne $beforeNamedManagement) { throw 'Named management selected a sibling schedule or rewrote its saved configuration.' }
    $null = Set-HarnessPause $nativeTimerPaths development 'Named timer pause fixture' 'Fixture owner'
    $callsBeforeNamedPause = $timerState.Calls.Count
    Assert-HarnessFailure { & $timerPath -ProjectPath $nativeTimerProject -Action Resume -InstanceName secondary -Apply } 'paused'
    if ($timerState.Calls.Count -ne $callsBeforeNamedPause) { throw 'A named schedule bypassed the shared development safety pause.' }
    $null = Resume-HarnessTarget $nativeTimerPaths development -Actor 'Fixture owner' -Reason 'Fixture pause inspected' -ConfirmStopped
    $namedSchedule = $timerState.Tasks | Where-Object TaskName -CEQ $namedTimer.taskName
    $namedSchedule.Description = 'Different owner'
    Assert-HarnessFailure { & $timerPath -ProjectPath $nativeTimerProject -InstanceMode Reuse -InstanceName secondary -IntervalDay 1 -Apply } 'different task'
    Write-Output 'Harness checks passed: board, queue, bounded worker/validation/review flow, explicit timers, and unrelated-task preservation. All agents and schedules were fake.'
}
finally {
    $env:SKILLVAULT_OWNERSHIP_ROOT = $savedFixtureOwnershipRoot
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}