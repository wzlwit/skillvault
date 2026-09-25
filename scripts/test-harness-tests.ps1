$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness-store.ps1')
. (Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness-runner.ps1')
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('harness-tests-' + [guid]::NewGuid().ToString('N'))
$savedFixtureOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
$env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixtureRoot 'runtime-ownership'

function Assert-TestFlowFailure {
    param([scriptblock]$Operation, [string]$Expected)
    $failed = $false
    try { & $Operation | Out-Null }
    catch { $failed = $true; if ($_.Exception.Message -notlike "*$Expected*") { throw } }
    if (-not $failed) { throw "Expected failure: $Expected" }
}

try {
    New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'ppe') -Force | Out-Null
    $paths = Get-HarnessPaths $fixtureRoot
    $config = Initialize-Harness $paths
    $settings = [pscustomobject]@{
        environments = @(
            [pscustomobject]@{ name = 'local'; workingDirectory = '.'; variables = @{ SKILLVAULT_TEST_MODE = 'local' }; requiredVariables = @(); allowScheduled = $false }
            [pscustomobject]@{ name = 'localPPE'; workingDirectory = 'ppe'; variables = @{ SKILLVAULT_TEST_MODE = 'localPPE' }; requiredVariables = @(); allowScheduled = $true }
        )
        flows = @([pscustomobject]@{
            name = 'smoke'; method = 'Check the configured target'; defaultEnvironment = 'local'; maxMinutes = 1
            steps = @([pscustomobject]@{ name = 'environment'; executable = 'pwsh'; arguments = @('-NoProfile', '-NonInteractive', '-Command', 'if ($env:CHECK_DISPATCHER_OWNERSHIP) { $claims = @(Get-ChildItem -LiteralPath $env:SKILLVAULT_OWNERSHIP_ROOT -Filter *.json | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json }); if (-not @($claims | Where-Object { $_.owner.role -eq "dispatcher" }).Count) { exit 17 } }; [Console]::Write("{0}|{1}", $env:SKILLVAULT_TEST_MODE, (Get-Location).Path)') })
        })
        afterDev = @()
    }
    $config.testing = $settings
    $parentValue = [Environment]::GetEnvironmentVariable('SKILLVAULT_TEST_MODE')
    $local = Invoke-HarnessTestFlow -Config $config -Flow smoke -Workspace $fixtureRoot
    $ppe = Invoke-HarnessTestFlow -Config $config -Flow smoke -Environment localPPE -Workspace $fixtureRoot
    if (-not $local.passed -or $local.environment -cne 'local' -or $local.checks[0].output -cne "local|$fixtureRoot") { throw 'Local flow did not use its default environment.' }
    if (-not $ppe.passed -or $ppe.checks[0].output -cne "localPPE|$(Join-Path $fixtureRoot 'ppe')") { throw 'The localPPE fixture did not use its declared directory and variables.' }
    if ([Environment]::GetEnvironmentVariable('SKILLVAULT_TEST_MODE') -cne $parentValue) { throw 'Test variables leaked into the parent process.' }
    $discoveryRoot = Join-Path $fixtureRoot 'discovered checks'
    New-Item -ItemType Directory -Path (Join-Path $discoveryRoot 'scripts') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $discoveryRoot 'scripts/test-all.ps1'), '[Console]::Out.Write("Discovered validation ran")')
    $discoveryConfig = Initialize-Harness (Get-HarnessPaths $discoveryRoot)
    $discoveredValidation = Invoke-HarnessValidation (Resolve-HarnessRunnerConfig $discoveryConfig) $discoveryRoot
    if (-not $discoveredValidation.passed -or $discoveredValidation.checks.Count -ne 1 -or $discoveredValidation.checks[0].output -cne 'Discovered validation ran') { throw 'Missing validation settings did not discover and execute the repository check without an invented time cap.' }
    Remove-Item -LiteralPath (Join-Path $discoveryRoot 'scripts/test-all.ps1')
    $unverifiedValidation = Invoke-HarnessValidation (Resolve-HarnessRunnerConfig $discoveryConfig) $discoveryRoot
    if ($unverifiedValidation.passed -or $unverifiedValidation.checks.Count -ne 0) { throw 'An empty validation phase was reported as a passing check.' }
    $ruleFile = Join-Path $fixtureRoot 'rules.md'
    'Fixture rule: only execute approved tests.' | Set-Content -LiteralPath $ruleFile -Encoding UTF8
    $config.runner.rulesPath = $ruleFile
    Write-HarnessJson $paths.Config $config
    $definitionFile = Join-Path $fixtureRoot 'test-definition.json'
    $settings | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $definitionFile -Encoding UTF8
    $dispatcher = Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness.ps1'
    $beforeState = [System.IO.File]::ReadAllText($paths.State)
    $null = & $dispatcher -ProjectPath $fixtureRoot -Action TestConfig -DefinitionPath 'test-definition.json'
    $beforeConfig = [System.IO.File]::ReadAllText($paths.Config)
    $listing = & $dispatcher -ProjectPath $fixtureRoot -Action Test | ConvertFrom-Json
    if ($listing.flows[0].name -cne 'smoke' -or [System.IO.File]::ReadAllText($paths.State) -cne $beforeState -or [System.IO.File]::ReadAllText($paths.Config) -cne $beforeConfig) { throw 'Declarations or listing executed tests or changed board state.' }
    @{ afterDev = @(@{ flow = 'missing' }) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $definitionFile -Encoding UTF8
    Assert-TestFlowFailure { & $dispatcher -ProjectPath $fixtureRoot -Action TestConfig -DefinitionPath 'test-definition.json' } 'Unknown afterDev'
    if ([System.IO.File]::ReadAllText($paths.Config) -cne $beforeConfig) { throw 'Invalid test declarations changed configuration.' }
    $savedDispatcherCheck = $env:CHECK_DISPATCHER_OWNERSHIP
    try {
        $env:CHECK_DISPATCHER_OWNERSHIP = '1'
        $run = & $dispatcher -ProjectPath $fixtureRoot -Action Test -Flow smoke -TestEnvironment localPPE | ConvertFrom-Json
    }
    finally { $env:CHECK_DISPATCHER_OWNERSHIP = $savedDispatcherCheck }
    if ($run.status -cne 'Passed' -or -not (Test-Path -LiteralPath $run.report)) { throw 'Ad-hoc tests did not save their report.' }
    if ([IO.Path]::GetRelativePath($paths.Control, $run.report).StartsWith('..')) { throw 'Default test evidence was written outside .harness_sv.' }
    $history = @(Import-Csv -LiteralPath (Join-Path $paths.Control 'history.csv'))
    if ($history.Count -ne 1 -or $history[0].environment -cne 'localPPE' -or $history[0].model) { throw 'Test-only history lost its environment or claimed an AI model.' }
    if (@((Read-HarnessState $paths).tasks).Count -ne 0 -or (Read-HarnessState $paths).active) { throw 'Test-only execution created work or left an active run.' }
    $scheduledRun = & $dispatcher -ProjectPath $fixtureRoot -Action Test -Flow smoke -TestEnvironment localPPE -Scheduled | ConvertFrom-Json
    if ($scheduledRun.status -cne 'Passed' -or $scheduledRun.result.environment -cne 'localPPE') { throw 'Scheduled dispatch did not execute the declared test without an AI model.' }
    $codeProject = Join-Path $fixtureRoot 'code repository'
    New-Item -ItemType Directory -Path $codeProject | Out-Null
    $null = Invoke-HarnessGit $codeProject @('init', '--quiet')
    $null = Invoke-HarnessGit $codeProject @('-c', 'user.name=Harness Test', '-c', 'user.email=harness@example.invalid', '-c', 'commit.gpgSign=false', '-c', ('core.hooksPath=' + (Join-Path $codeProject 'no-hooks')), 'commit', '--quiet', '--allow-empty', '-m', 'Test repository fixture')
    $repositoryReference = Set-HarnessReference -Paths $paths -Source $codeProject
    $repositoryTask = Add-HarnessTask -Paths $paths -Title 'Repository tests' -Description 'Use the selected checkout' -Scope 'fixture' -Acceptance 'No implicit development' -RepoRef $repositoryReference.id
    $repositoryRun = & $dispatcher -ProjectPath $fixtureRoot -Action Test -Flow smoke -Id $repositoryTask.id | ConvertFrom-Json
    if ($repositoryRun.status -cne 'Passed' -or $repositoryRun.result.checks[0].output -cne "local|$codeProject" -or $repositoryRun.repositoryRef -cne $repositoryReference.id -or $repositoryRun.repositoryRoot -cne $codeProject) { throw 'A model-free task-linked test did not resolve its reference before development allocated a workspace.' }
    $workspaceConfig = $config | ConvertTo-Json -Depth 15 | ConvertFrom-Json
    $workspaceConfig.runner.workspaceMode = 'worktree'
    $testWorkspace = Get-HarnessWorkspace $paths $workspaceConfig $repositoryTask
    $null = Update-HarnessState $paths {
        param($saved)
        $selected = Get-HarnessTask $saved $repositoryTask.id
        $selected.workspace = $testWorkspace
        $selected.repositoryRoot = $repositoryTask.repositoryRoot
    }
    $worktreeRun = & $dispatcher -ProjectPath $fixtureRoot -Action Test -Flow smoke -Id $repositoryTask.id | ConvertFrom-Json
    if ($worktreeRun.status -cne 'Passed' -or $worktreeRun.result.checks[0].output -cne "local|$testWorkspace" -or (Get-HarnessTask (Read-HarnessState $paths) $repositoryTask.id).status -cne $repositoryTask.status -or (Test-Path -LiteralPath (Join-Path $codeProject '.harness_sv'))) { throw 'Task-linked tests lost the saved worktree, completed development implicitly, or moved controller state.' }
    $linkedTask = Add-HarnessTask -Paths $paths -Title 'Linked task' -Description 'Keep status' -Scope 'fixture' -Acceptance 'No implicit completion'
    $null = Update-HarnessState $paths {
        param($saved)
        $saved.active = [pscustomobject]@{ taskId = $linkedTask.id; runId = 'interrupted-test'; phase = 'Test'; ownerProcessId = 0; target = 'test:smoke:localPPE' }
        $saved.runs = @($saved.runs) + @([pscustomobject]@{ id = 'interrupted-test'; status = 'Running'; phase = 'Test'; finishedAt = '' })
    }
    $null = & $dispatcher -ProjectPath $fixtureRoot -Action Recover -ConfirmStopped
    if ((Get-HarnessTask (Read-HarnessState $paths) $linkedTask.id).status -cne $linkedTask.status) { throw 'Recovering a test-only run changed its linked development task.' }
    $runLock = Enter-HarnessLock $paths.RunLock
    try {
        $busy = Invoke-HarnessTests $paths smoke local
        if ($busy.status -cne 'Busy') { throw 'Tests bypassed the shared runner lock.' }
    }
    finally { $runLock.Dispose() }
    Assert-TestFlowFailure { Resolve-HarnessTestPlan $config smoke local $fixtureRoot -Scheduled } 'not approved'
    $null = Resolve-HarnessTestPlan $config smoke localPPE $fixtureRoot -Scheduled
    $settings.afterDev = @([pscustomobject]@{ flow = 'smoke'; environment = 'localPPE' })
    $config.runner.maxMinutes = 1
    $config.runner.validationCommands = @([pscustomobject]@{ executable = 'pwsh'; arguments = @('-NoProfile', '-NonInteractive', '-Command', 'exit 0') })
    $validation = Invoke-HarnessValidation $config $fixtureRoot -Scheduled
    if (-not $validation.passed -or $validation.checks.Count -ne 1 -or $validation.flows.Count -ne 1 -or $validation.flows[0].environment -cne 'localPPE') { throw 'Post-development validation did not run both legacy commands and declared flows.' }
    $settings.afterDev[0].environment = 'local'
    $denied = Invoke-HarnessValidation $config $fixtureRoot -Scheduled
    if ($denied.passed -or $denied.status -cne 'Blocked' -or $denied.flows[0].checks.Count -ne 0) { throw 'Scheduled development bypassed test-environment approval.' }
    $config.runner.validationCommands = @()
    $hookOnly = Invoke-HarnessValidation $config $fixtureRoot
    if (-not $hookOnly.passed -or $hookOnly.flows.Count -ne 1) { throw 'Named-flow-only validation did not execute its gate.' }
    $missing = Invoke-HarnessTestFlow -Config $config -Flow missing -Workspace $fixtureRoot
    if ($missing.status -cne 'Blocked' -or $missing.passed) { throw 'An undeclared flow was treated as a passing test.' }
    $settings.environments[0].requiredVariables = @('HARNESS_MISSING_' + [guid]::NewGuid().ToString('N'))
    $blocked = Invoke-HarnessTestFlow -Config $config -Flow smoke -Workspace $fixtureRoot
    if ($blocked.status -cne 'Blocked' -or $blocked.checks.Count -ne 0) { throw 'Missing environment prerequisites did not block before execution.' }
    $settings.environments[0].requiredVariables = @()
    $settings.flows[0].steps = @(
        [pscustomobject]@{ name = 'fail'; executable = 'pwsh'; arguments = @('fixture') }
        [pscustomobject]@{ name = 'must-not-run'; executable = 'pwsh'; arguments = @('fixture') }
    )
    $calls = [System.Collections.Generic.List[object]]::new()
    function Invoke-HarnessProcess {
        param($Executable, $Arguments, $Directory, $MaxMinutes, $EnvironmentVariables)
        $calls.Add($Arguments)
        [pscustomobject]@{ ExitCode = 7; Output = ''; Error = 'Fixture failure'; TimedOut = $false }
    }
    $failed = Invoke-HarnessTestFlow -Config $config -Flow smoke -Workspace $fixtureRoot
    if ($failed.status -cne 'Failed' -or $failed.exitCode -ne 7 -or $calls.Count -ne 1) { throw 'Test flow did not stop at the first real failure.' }
    $failedHook = Invoke-HarnessValidation $config $fixtureRoot
    if ($failedHook.passed -or $failedHook.flows[0].exitCode -ne 7) { throw 'Failing post-development flow was reported as successful validation.' }
    function Invoke-HarnessProcess {
        param($Executable, $Arguments, $Directory, $MaxMinutes, $EnvironmentVariables)
        [pscustomobject]@{ ExitCode = 124; Output = ''; Error = 'Fixture timeout'; TimedOut = $true }
    }
    $timeout = Invoke-HarnessTestFlow -Config $config -Flow smoke -Workspace $fixtureRoot
    if ($timeout.passed -or $timeout.exitCode -ne 124 -or -not $timeout.checks[0].timedOut) { throw 'Timed-out tests lost their failure evidence.' }
    Write-Output 'Test flow checks passed: declarations, local/localPPE fixtures, read-only listing, model-free ad-hoc/scheduled runs, post-dev gates, reports, recovery, prerequisites, and failures/timeouts. No real localPPE environment was contacted.'
}
finally {
    $env:SKILLVAULT_OWNERSHIP_ROOT = $savedFixtureOwnershipRoot
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}