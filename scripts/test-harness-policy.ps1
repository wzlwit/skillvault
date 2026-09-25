$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness-store.ps1')
. (Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness-policy.ps1')
. (Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness-runner.ps1')
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('harness-policy-' + [guid]::NewGuid().ToString('N'))
$savedFixtureOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
$env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixtureRoot 'runtime-ownership'

function Assert-PolicyFailure {
    param([scriptblock]$Operation, [string]$Expected)
    $failed = $false
    try { & $Operation | Out-Null }
    catch { $failed = $true; if ($_.Exception.Message -notlike "*$Expected*") { throw } }
    if (-not $failed) { throw "Expected policy failure: $Expected" }
}

try {
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    $paths = Get-HarnessPaths $fixtureRoot
    $dispatcher = Join-Path $PSScriptRoot '..\skills\planning\harness\scripts\harness.ps1'
    $view = Get-HarnessPolicyView $paths fallback
    if ($view.initialized -or (Test-Path -LiteralPath $paths.Control)) { throw 'Policy inspection initialized project state.' }
    foreach ($action in @('Restrict', 'Fallback')) {
        $view = & $dispatcher -ProjectPath $fixtureRoot -Action $action | ConvertFrom-Json
        if ($view.initialized -or (Test-Path -LiteralPath $paths.Control)) { throw 'Bare public policy commands initialized state.' }
    }
    $config = Initialize-Harness $paths
    $legacyRulesPath = Join-Path $fixtureRoot '.github/skills/rules-core/SKILL.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $legacyRulesPath) -Force | Out-Null
    'Legacy fixture core rules.' | Set-Content -LiteralPath $legacyRulesPath
    $legacyRules = Get-HarnessRuleContext -Paths $paths -Config $config -Workspace $fixtureRoot
    if ($legacyRules -notlike '*Legacy fixture core rules.*') { throw 'An existing project rules-core installation was ignored.' }
    $canonicalRulesPath = Join-Path $fixtureRoot '.github/skills/rules/references/core.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $canonicalRulesPath) -Force | Out-Null
    'Canonical fixture core rules.' | Set-Content -LiteralPath $canonicalRulesPath
    $canonicalRules = Get-HarnessRuleContext -Paths $paths -Config $config -Workspace $fixtureRoot
    if ($canonicalRules -notlike '*Canonical fixture core rules.*' -or $canonicalRules -like '*Legacy fixture core rules.*') { throw 'Canonical core guidance was not preferred over the legacy copy.' }
    foreach ($folder in @('docs', 'artifacts', 'definitions')) {
        if (-not $canonicalRules.Contains((Join-Path $paths.Control $folder))) { throw "Worker context did not specify the harness artifact destination: $folder" }
        if (Test-Path -LiteralPath (Join-Path $paths.Control $folder)) { throw 'Reading worker context created an artifact folder.' }
    }
    if ($canonicalRules -notlike '*unless the user explicitly selected another destination*' -or $canonicalRules -notlike '*do not grant write access*') { throw 'Worker storage guidance lost output overrides or execution boundaries.' }
    $config.runner.rulesPath = 'missing-approved-rules.md'
    Assert-PolicyFailure { Get-HarnessRuleContext -Paths $paths -Config $config -Workspace $fixtureRoot } 'Rules Core is unavailable'
    $config.runner.rulesPath = $null
    if ($null -ne $config.runner.allowedTools -or $null -ne $config.runner.availableTools -or $null -ne $config.restrictions) { throw 'Initialization introduced default tool or model restrictions instead of None.' }
    $parentRunner = [pscustomobject]@{
        command = 'pwsh'; model = 'parent-fixture'; reasoningEffort = 'high'
        workspaceMode = 'current'; maxMinutes = 10; maxCredits = 8
        maxTasksPerCycle = 4; criticalReview = $true
        allowedTools = @('write'); availableTools = @('view', 'edit')
        validationCommands = @([pscustomobject]@{ executable = 'pwsh'; arguments = @('-NoProfile', '-Command', 'exit 0') })
    }
    $inherited = Resolve-HarnessRunnerConfig -Config $config -RunnerContext ([pscustomobject]@{ runner = $parentRunner })
    Assert-HarnessRunnerConfig $inherited
    if ($inherited.runner.model -cne 'parent-fixture' -or $inherited.runner.maxMinutes -ne 10 -or $inherited.runner.maxCredits -ne 8 -or $inherited.runner.workspaceMode -cne 'current' -or $inherited.runner.allowedTools[0] -cne 'write') { throw 'Missing runner settings did not inherit the parent execution context.' }
    if ($null -ne $config.runner.model -or $null -ne (Read-HarnessConfig $paths).runner.model) { throw 'Resolving inherited settings changed the supplied or saved configuration.' }
    $native = Resolve-HarnessRunnerConfig $config
    Assert-HarnessRunnerConfig $native
    if ($native.runner.model -cne 'auto' -or $native.runner.reasoningEffort -cne 'auto' -or $null -ne $native.runner.maxCredits -or $null -ne $native.runner.maxMinutes -or $null -ne $native.runner.allowedTools) { throw 'Absent allowances did not defer to native routing and permissions without artificial caps.' }
    foreach ($emptyContext in @('null', '', ' ', 'None', 'Max', '[]', '{"parent":[]}', '{"restrictions":[]}')) { Assert-HarnessRunnerConfig (Resolve-HarnessRunnerConfig $config $emptyContext) }
    foreach ($invalidContext in @('[{"runner":{}}]', 'true', '{"parent":true}', '{"runner":false}', '{"restrictions":false}')) {
        Assert-PolicyFailure { Resolve-HarnessRunnerConfig $config $invalidContext } 'JSON object'
    }
    $partialRunner = $config | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $partialRunner.runner.reasoningEffort = 'max'
    $nativePartial = Resolve-HarnessRunnerConfig $partialRunner
    Assert-HarnessRunnerConfig $nativePartial
    if ($nativePartial.runner.model -cne 'auto' -or $nativePartial.runner.reasoningEffort -cne 'auto' -or $partialRunner.runner.reasoningEffort -cne 'max') { throw 'Missing model selection created an incompatible auto/effort pair or rewrote the saved preference.' }
    $context = [pscustomobject]@{
        runner = [pscustomobject]@{ maxMinutes = 9 }
        parent = [pscustomobject]@{ runner = $parentRunner }
        restrictions = [pscustomobject]@{ maxProcessMinutes = 6; deniedTools = @('url'); allowedModels = @('parent-fixture') }
    }
    $overrides = $config | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $overrides.runner.maxCredits = 3
    $overrides.runner.criticalReview = $false
    $overrides | Add-Member -NotePropertyName restrictions -NotePropertyValue ([pscustomobject]@{ maxProcessMinutes = 4 })
    $combined = Resolve-HarnessRunnerConfig $overrides $context
    if ($combined.runner.maxMinutes -ne 4 -or $combined.runner.maxCredits -ne 3 -or $combined.runner.criticalReview -ne $false) { throw 'Explicit values or inherited stricter ceilings were lost during resolution.' }
    Assert-PolicyFailure { Assert-HarnessRestrictions -Config $combined -Model other } 'allowedModels'
    $largerRequest = $config | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $largerRequest.runner.maxMinutes = 30
    $largerRequest.runner.maxCredits = 20
    $largerRequest.runner.maxTasksPerCycle = 9
    $parentCapped = Resolve-HarnessRunnerConfig $largerRequest ([pscustomobject]@{ parent = [pscustomobject]@{ runner = $parentRunner } })
    if ($parentCapped.runner.maxMinutes -ne 10 -or $parentCapped.runner.maxCredits -ne 8 -or $parentCapped.runner.maxTasksPerCycle -ne 4) { throw 'A child runner exceeded resource ceilings supplied by its parent context.' }
    $profileContext = [pscustomobject]@{ profiles = @(
        [pscustomobject]@{ model = 'strongest-fixture'; efforts = @('high', 'max'); contexts = @('default', 'long_context') }
        [pscustomobject]@{ model = 'other-fixture'; efforts = @('high'); contexts = @('default') }
    ) }
    $maximum = Resolve-HarnessRunnerConfig $config $profileContext
    if ($maximum.runner.model -cne 'strongest-fixture' -or $maximum.runner.reasoningEffort -cne 'max' -or $maximum.runner.contextTier -cne 'long_context') { throw 'Unset settings did not select the strongest verified profile and maximum supported effort/context.' }
    $contextFile = Join-Path $fixtureRoot 'runner-context.json'
    Write-HarnessJson $contextFile $profileContext
    $contextView = & $dispatcher -ProjectPath $fixtureRoot -Action Context -RunnerContextPath $contextFile | ConvertFrom-Json
    if ($contextView.effectiveRunner.model -cne 'strongest-fixture' -or $contextView.effectiveRunner.reasoningEffort -cne 'max') { throw 'The public context handoff lost maximum available model settings.' }
    $inheritedView = & $dispatcher -ProjectPath $fixtureRoot -Action Restrict -RunnerContext ([pscustomobject]@{ runner = $parentRunner }) | ConvertFrom-Json
    if ($inheritedView.effectiveRunner.model -cne 'parent-fixture' -or $inheritedView.effectiveRunner.maxCredits -ne 8) { throw 'Policy inspection did not show effective inherited allowances.' }
    $inheritedIdle = & $dispatcher -ProjectPath $fixtureRoot -Action Dev -RunnerContext ([pscustomobject]@{ runner = $parentRunner }) | ConvertFrom-Json
    $nativeIdle = & $dispatcher -ProjectPath $fixtureRoot -Action Dev | ConvertFrom-Json
    if ($inheritedIdle.status -cne 'Idle' -or $nativeIdle.status -cne 'Idle' -or $null -ne (Read-HarnessConfig $paths).runner.model) { throw 'Missing optional settings blocked the public runner or persisted inherited defaults.' }
    $overrides.runner.maxMinutes = 0
    Assert-PolicyFailure { Assert-HarnessRunnerConfig (Resolve-HarnessRunnerConfig $overrides) } 'positive finite'
    $nullPolicyConfig = $config | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $nullPolicyConfig | Add-Member -NotePropertyName restrictions -NotePropertyValue ('{"allowedModels":null,"allowedTools":null,"availableTools":null,"workingRoots":null,"workspaceModes":null,"allowedExecutables":null,"maxProcessMinutes":null,"maxAgentCredits":null}' | ConvertFrom-Json)
    $nullPolicy = Resolve-HarnessRunnerConfig $nullPolicyConfig $profileContext
    Assert-HarnessRunnerConfig $nullPolicy
    Assert-HarnessRestrictions -Config $nullPolicy -Model strongest-fixture -Tools view -PermissionRules write -Workspace $fixtureRoot -Executable pwsh -WorkspaceMode current
    if ($nullPolicy.runner.model -cne 'strongest-fixture' -or $null -ne $nullPolicy.runner.maxMinutes -or $null -ne $nullPolicy.runner.maxCredits) { throw 'Null allowances were treated as denials or zero caps instead of inheritance.' }
    $nullPolicyConfig.restrictions.allowedModels = @()
    foreach ($placeholder in @($null, '', ' ', @(), @(''), @(' '), 'None', 'Max', @('None'), @('Max'))) {
        $placeholderConfig = $config | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        $placeholderPolicy = [ordered]@{}
        foreach ($field in @('allowedModels', 'allowedTools', 'availableTools', 'workingRoots', 'workspaceModes', 'allowedExecutables', 'testEnvironments', 'deniedTools', 'maxProcessMinutes', 'maxAgentCredits', 'maxTasksPerCycle')) { $placeholderPolicy[$field] = $placeholder }
        $placeholderConfig | Add-Member -NotePropertyName restrictions -NotePropertyValue ([pscustomobject]$placeholderPolicy)
        foreach ($field in @('model', 'contextTier', 'workspaceMode', 'maxMinutes', 'maxCredits', 'maxTasksPerCycle', 'allowedTools', 'availableTools')) { $placeholderConfig.runner | Add-Member -NotePropertyName $field -NotePropertyValue $placeholder -Force }
        $effective = Resolve-HarnessRunnerConfig $placeholderConfig ([pscustomobject]@{ runner = $parentRunner })
        Assert-HarnessRunnerConfig $effective
        Assert-HarnessRestrictions -Config $effective -Model parent-fixture -Tools view -PermissionRules write -Workspace $fixtureRoot -Executable pwsh -WorkspaceMode current -TestEnvironment local
        if ($effective.runner.maxMinutes -ne 10 -or $effective.runner.maxCredits -ne 8 -or $effective.runner.maxTasksPerCycle -ne 4) { throw 'An empty, None, or Max allowance blocked or replaced inherited resource limits.' }
        $parentPlaceholders = Resolve-HarnessRunnerConfig $config ([pscustomobject]@{ runner = $placeholderConfig.runner; restrictions = $placeholderConfig.restrictions; parent = [pscustomobject]@{ runner = $parentRunner } })
        Assert-HarnessRunnerConfig $parentPlaceholders
        if ($parentPlaceholders.runner.model -cne 'parent-fixture' -or $parentPlaceholders.runner.maxCredits -ne 8) { throw 'A placeholder in current-session context hid a valid parent allowance.' }
    }
    foreach ($effort in @('none', 'max')) {
        $effortConfig = $config | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        $effortConfig.runner.model = 'explicit-fixture'
        $effortConfig.runner.reasoningEffort = $effort
        if ((Resolve-HarnessRunnerConfig $effortConfig).runner.reasoningEffort -cne $effort) { throw 'A valid reasoning-effort value was mistaken for an allowance placeholder.' }
    }
    if ($null -ne (Get-HarnessExecutionLimit ([pscustomobject]@{ restrictions = [pscustomobject]@{ maxAgentCredits = 'None' } }) maxAgentCredits 'Max')) { throw 'None/Max resource markers became a numeric restriction.' }
    $nativeView = Get-HarnessPolicyView $paths restrictions
    if ($null -ne $nativeView.effectiveRunner.allowedTools -or $null -ne $nativeView.effectiveRunner.availableTools) { throw 'Effective native allowances were exposed as empty tool restrictions.' }
    $declarationRoot = Join-Path $fixtureRoot 'allowance declarations'
    New-Item -ItemType Directory -Path $declarationRoot | Out-Null
    $declarationPaths = Get-HarnessPaths $declarationRoot
    $null = Initialize-Harness $declarationPaths
    $markerFile = Join-Path $declarationRoot 'allowances.json'
    Write-HarnessJson $markerFile ([pscustomobject]@{ allowedModels = @(); allowedTools = 'None'; workspaceModes = ' '; maxAgentCredits = 'Max' })
    $beforeDeclaration = [IO.File]::ReadAllText($declarationPaths.Config)
    $markerPreview = Set-HarnessPolicy $declarationPaths restrictions $markerFile
    if ($null -ne $markerPreview.proposed.allowedModels -or $null -ne $markerPreview.proposed.maxAgentCredits -or [IO.File]::ReadAllText($declarationPaths.Config) -cne $beforeDeclaration) { throw 'Restriction preview did not normalize placeholders without writes.' }
    $null = Set-HarnessPolicy $declarationPaths restrictions $markerFile -Apply -Actor 'Fixture owner' -Reason 'Use inherited allowances'
    $savedPolicy = Read-HarnessConfig $declarationPaths
    if ($null -ne $savedPolicy.restrictions.allowedModels -or $null -ne $savedPolicy.restrictions.allowedTools -or $null -ne $savedPolicy.restrictions.maxAgentCredits) { throw 'Approved placeholder declarations were not stored as canonical no-restriction values.' }
    Assert-HarnessRestrictions -Config $savedPolicy -Model any-fixture -Tools view -PermissionRules write -WorkspaceMode current
    $beforeState = [System.IO.File]::ReadAllText($paths.State)
    $beforeConfig = [System.IO.File]::ReadAllText($paths.Config)
    $view = Get-HarnessPolicyView $paths fallback
    if ($view.declared -or $null -ne $view.policy.failureThreshold -or $view.policy.transientRetry.maxRetries -ne 1 -or $view.policy.transientRetry.delaySeconds -ne 5 -or $view.policy.transientRetry.exitCodes.Count) { throw 'Inspection did not expose bounded retry defaults with an empty transient-code set.' }
    if ([IO.File]::ReadAllText($paths.State) -cne $beforeState -or [IO.File]::ReadAllText($paths.Config) -cne $beforeConfig) { throw 'Inspecting retry defaults changed saved policy or state.' }
    $declaration = Join-Path $fixtureRoot 'fallback.json'
    '{"failureThreshold":2}' | Set-Content -LiteralPath $declaration -Encoding UTF8
    $preview = Set-HarnessPolicy $paths fallback $declaration
    if (-not $preview.preview -or [System.IO.File]::ReadAllText($paths.State) -cne $beforeState -or [System.IO.File]::ReadAllText($paths.Config) -cne $beforeConfig) { throw 'Policy preview changed state.' }
    $preview = & $dispatcher -ProjectPath $fixtureRoot -Action Fallback -PolicyAction Declare -DefinitionPath $declaration | ConvertFrom-Json
    if (-not $preview.preview -or [System.IO.File]::ReadAllText($paths.Config) -cne $beforeConfig) { throw 'Public declaration implicitly applied policy.' }
    Assert-PolicyFailure { & $dispatcher -ProjectPath $fixtureRoot -Action Restrict -PolicyAction Pause -Target project -Apply -Actor Owner -Reason Fixture } 'Only Fallback'
    $null = Set-HarnessPolicy $paths fallback $declaration -Apply -Actor 'Fixture owner' -Reason 'Approve two-failure fixture policy'
    $config = Read-HarnessConfig $paths
    foreach ($runId in @('failure-1', 'failure-1', 'failure-2')) {
        $null = Update-HarnessState -Paths $paths -SkipViews -Operation {
            param($state)
            Register-HarnessPolicyOutcome $state $config 'test:smoke:local' $runId Failure 'Fixture failure'
        }
    }
    $pause = Get-HarnessPause $paths 'test:smoke:local'
    if (-not $pause.active -or (Get-HarnessPolicyView $paths fallback).targets[0].consecutiveFailures -ne 2) { throw 'Repeated failures were not counted once per run and persisted as a pause.' }
    if ($null -ne (Get-HarnessPause $paths 'development')) { throw 'Target pause leaked into unrelated development.' }
    $configBeforeResume = [System.IO.File]::ReadAllText($paths.Config)
    Assert-PolicyFailure { Resume-HarnessTarget $paths 'test:smoke:local' -Actor 'Owner' -Reason 'Checked' } 'confirmation'
    $null = Resume-HarnessTarget $paths 'test:smoke:local' -Actor 'Owner' -Reason 'Investigated fixture failure' -ConfirmStopped
    if ($null -ne (Get-HarnessPause $paths 'test:smoke:local') -or [System.IO.File]::ReadAllText($paths.Config) -cne $configBeforeResume) { throw 'Resume changed policy or left the selected target paused.' }
    $null = Set-HarnessPause $paths project 'Fixture emergency stop' Owner -Stop
    if (-not (Get-HarnessPause $paths review).stopRequested) { throw 'Project stop did not apply to other execution targets.' }
    $state = Read-HarnessState $paths
    if ($state.tasks.Count -ne 0 -or $state.runs.Count -ne 0) { throw 'Policy operations created tasks or runs.' }
    Assert-PolicyFailure { Assert-HarnessPolicyDefinition fallback ('{"failureThreshold":0}' | ConvertFrom-Json) } 'positive'
    Assert-PolicyFailure { Assert-HarnessPolicyDefinition fallback ('{"transientRetry":{"maxRetries":1,"delaySeconds":0,"exitCodes":[124]}}' | ConvertFrom-Json) } 'timeout'
    Assert-HarnessPolicyDefinition fallback ('{"transientRetry":{"exitCodes":[75]}}' | ConvertFrom-Json)
    Assert-HarnessPolicyDefinition fallback ('{"transientRetry":{"maxRetries":0}}' | ConvertFrom-Json)
    $retryDeclaration = Join-Path $declarationRoot 'retries.json'
    Write-HarnessJson $retryDeclaration ('{"transientRetry":{"exitCodes":[75]}}' | ConvertFrom-Json)
    $beforeRetryDeclaration = [IO.File]::ReadAllText($declarationPaths.Config)
    $retryPreview = Set-HarnessPolicy $declarationPaths fallback $retryDeclaration
    if (-not $retryPreview.preview -or [IO.File]::ReadAllText($declarationPaths.Config) -cne $beforeRetryDeclaration) { throw 'Previewing default retries persisted a declaration.' }
    $null = Set-HarnessPolicy $declarationPaths fallback $retryDeclaration -Apply -Actor 'Fixture owner' -Reason 'Classified fixture exit 75 as transient'
    $reloadedRetryConfig = Read-HarnessConfig $declarationPaths
    $effectiveRetry = (Get-HarnessFallbackPolicy $reloadedRetryConfig).transientRetry
    if ($effectiveRetry.maxRetries -ne 1 -or $effectiveRetry.delaySeconds -ne 5 -or ($effectiveRetry.exitCodes -join ',') -ne '75' -or ($reloadedRetryConfig.fallback.transientRetry.PSObject.Properties.Name -join ',') -cne 'exitCodes') { throw 'Saved retry declarations lost their defaults or were silently expanded.' }
    foreach ($invalidRetry in @(
        '{"transientRetry":{"exitCodes":[]}}',
        '{"transientRetry":{"maxRetries":1}}',
        '{"transientRetry":{"exitCodes":[0]}}',
        '{"transientRetry":{"exitCodes":[124]}}',
        '{"transientRetry":{"exitCodes":["75"]}}',
        '{"transientRetry":{"exitCodes":75}}',
        '{"transientRetry":{"maxRetries":null,"exitCodes":[75]}}',
        '{"transientRetry":{"maxRetries":6,"exitCodes":[75]}}',
        '{"transientRetry":{"delaySeconds":null,"exitCodes":[75]}}',
        '{"transientRetry":{"delaySeconds":301,"exitCodes":[75]}}',
        '{"transientRetry":{"unknown":true,"exitCodes":[75]}}'
    )) { Assert-PolicyFailure { Assert-HarnessPolicyDefinition fallback ($invalidRetry | ConvertFrom-Json) } }
    Assert-PolicyFailure { Assert-HarnessPolicyDefinition restrictions ('{"allowAll":true}' | ConvertFrom-Json) } 'Unsupported'
    $config | Add-Member -NotePropertyName restrictions -NotePropertyValue ('{"allowedModels":["fixture-model"],"allowedTools":["write"],"availableTools":["view"],"workspaceModes":["worktree"],"workingRoots":["work"],"testEnvironments":["local"],"allowedExecutables":["pwsh"],"maxProcessMinutes":2,"maxAgentCredits":3}' | ConvertFrom-Json)
    $working = Join-Path $fixtureRoot 'work'
    Assert-HarnessRestrictions -Config $config -ProjectRoot $fixtureRoot -Workspace (Join-Path $working 'child') -Model fixture-model -Tools view -PermissionRules write -WorkspaceMode worktree -TestEnvironment local -Executable pwsh
    Assert-PolicyFailure { Assert-HarnessRestrictions -Config $config -ProjectRoot $fixtureRoot -Workspace (Join-Path $fixtureRoot 'work-other') } 'workingRoots'
    Assert-PolicyFailure { Assert-HarnessRestrictions -Config $config -Model 'unapproved-model' } 'allowedModels'
    Assert-PolicyFailure { Assert-HarnessRestrictions -Config $config -PermissionRules 'shell' } 'allowedTools'
    Assert-PolicyFailure { Assert-HarnessRestrictions -Config $config -Tools 'edit' } 'availableTools'
    Assert-PolicyFailure { Assert-HarnessRestrictions -Config $config -TestEnvironment localPPE } 'testEnvironments'
    Assert-PolicyFailure { Assert-HarnessRestrictions -Config $config -WorkspaceMode current } 'workspaceModes'
    if ((Get-HarnessExecutionLimit $config maxProcessMinutes 5) -ne 2 -or (Get-HarnessExecutionLimit $config maxAgentCredits 1) -ne 1) { throw 'Restrictions did not retain the stricter limit.' }
    try { Assert-HarnessRestrictions -Config $config -Model other }
    catch { if ((Get-HarnessFailureKind $_) -cne 'Restriction') { throw 'Restriction violations lost their structured failure kind.' } }
    $null = Resume-HarnessTarget $paths project -Actor Owner -Reason 'Fixture stop checked' -ConfirmStopped
    Assert-PolicyFailure { Invoke-HarnessProcess -Executable pwsh -Arguments @('-NoProfile', '-Command', 'exit 0') -Directory $fixtureRoot -MaxMinutes 1 -Config $config -Paths $paths -Targets development } 'workingRoots'
    $childScript = Join-Path $fixtureRoot 'owned-child.ps1'
    @'
param([string]$ProjectPath, [string]$RuntimePath)
$ErrorActionPreference = 'Stop'
. (Join-Path $RuntimePath 'harness-store.ps1')
. (Join-Path $RuntimePath 'harness-policy.ps1')
$paths = Get-HarnessPaths $ProjectPath
$null = Set-HarnessPause $paths project 'Fixture child requests its own stop' 'Fixture owner' -Stop
[Console]::Out.Write('fixture stop requested')
[System.Threading.ManualResetEventSlim]::new($false).Wait()
'@ | Set-Content -LiteralPath $childScript -Encoding UTF8
    $runtimePath = Join-Path $PSScriptRoot '..\skills\planning\harness\scripts'
    $stoppedChild = Invoke-HarnessProcess -Executable pwsh -Arguments @('-NoProfile', '-NonInteractive', '-File', $childScript, '-ProjectPath', $fixtureRoot, '-RuntimePath', $runtimePath) -Directory $fixtureRoot -MaxMinutes 0.2 -Paths $paths -Targets development
    if (-not $stoppedChild.Stopped -or $stoppedChild.TimedOut -or $stoppedChild.ExitCode -ne 125 -or $stoppedChild.Output -cne 'fixture stop requested') { throw 'The runner did not stop its owned child after a persistent stop request.' }
    $null = Resume-HarnessTarget $paths project -Actor Owner -Reason 'Owned fixture child confirmed stopped' -ConfirmStopped
    $boundedConfig = Read-HarnessConfig $paths
    $boundedConfig | Add-Member -NotePropertyName restrictions -NotePropertyValue ([pscustomobject]@{ maxProcessMinutes = 0.01 })
    $boundedChild = Invoke-HarnessProcess -Executable pwsh -Arguments @('-NoProfile', '-NonInteractive', '-Command', '[System.Threading.ManualResetEventSlim]::new($false).Wait()') -Directory $fixtureRoot -MaxMinutes 1 -Paths $paths -Config $boundedConfig -Targets development
    if (-not $boundedChild.TimedOut -or $boundedChild.Stopped -or $boundedChild.ExitCode -ne 124) { throw 'The restriction time cap did not stop an owned process.' }
    $flowConfig = Read-HarnessConfig $paths
    $flowConfig.runner.rulesPath = Join-Path $fixtureRoot 'fixture-rules.md'
    'Fixture rules: no live operations.' | Set-Content -LiteralPath $flowConfig.runner.rulesPath
    $flowConfig.testing = ('{"environments":[{"name":"local","workingDirectory":".","variables":{},"requiredVariables":[],"allowScheduled":true}],"flows":[{"name":"smoke","method":"fixture","defaultEnvironment":"local","maxMinutes":1,"steps":[{"name":"probe","executable":"pwsh","arguments":[],"repeatable":true}]}],"afterDev":[]}' | ConvertFrom-Json)
    $flowConfig.fallback = ('{"failureThreshold":2,"transientRetry":{"maxRetries":1,"delaySeconds":0,"exitCodes":[75]}}' | ConvertFrom-Json)
    Write-HarnessJson $paths.Config $flowConfig
    $script:policyProcessCalls = 0
    $script:policyExitCodes = @(75, 0)
    $script:policyTimeout = $false
    $script:policyStopped = $false
    function Invoke-HarnessProcess {
        param($Executable, $Arguments, $Directory, $MaxMinutes, $EnvironmentVariables, $Paths, $Config, $Targets)
        $exitCode = $script:policyExitCodes[[Math]::Min($script:policyProcessCalls, $script:policyExitCodes.Count - 1)]
        $script:policyProcessCalls++
        [pscustomobject]@{ ExitCode = $exitCode; Output = 'Fixture output'; Error = ''; TimedOut = $script:policyTimeout; Stopped = $script:policyStopped }
    }
    $flowResult = Invoke-HarnessTestFlow -Config $flowConfig -Flow smoke -Workspace $fixtureRoot -Paths $paths
    if (-not $flowResult.passed -or $flowResult.checks.Count -ne 2 -or $script:policyProcessCalls -ne 2) { throw 'Approved transient repeatable step did not retry within one flow.' }
    $defaultRetryConfig = $flowConfig | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    $defaultRetryConfig.fallback = ('{"transientRetry":{"exitCodes":[75]}}' | ConvertFrom-Json)
    $retryPolicyBefore = $defaultRetryConfig.fallback | ConvertTo-Json -Depth 5 -Compress
    $script:policyProcessCalls = 0
    $flowResult = Invoke-HarnessTestFlow -Config $defaultRetryConfig -Flow smoke -Workspace $fixtureRoot -Paths $paths
    if (-not $flowResult.passed -or $script:policyProcessCalls -ne 2 -or ($flowResult.checks.attempt -join ',') -ne '1,2') { throw 'A declared transient failure did not use the default additional attempt.' }
    if (($defaultRetryConfig.fallback | ConvertTo-Json -Depth 5 -Compress) -cne $retryPolicyBefore) { throw 'Resolving retry defaults changed the supplied declaration.' }
    $defaultRetryConfig.fallback.transientRetry | Add-Member -NotePropertyName delaySeconds -NotePropertyValue 0
    $defaultRetryConfig.testing.flows[0].steps = @([pscustomobject]@{ name = 'prepare'; executable = 'pwsh'; arguments = @() }) + @($defaultRetryConfig.testing.flows[0].steps)
    $script:policyExitCodes = @(0, 75, 0)
    $script:policyProcessCalls = 0
    $flowResult = Invoke-HarnessTestFlow -Config $defaultRetryConfig -Flow smoke -Workspace $fixtureRoot -Paths $paths
    if (-not $flowResult.passed -or $script:policyProcessCalls -ne 3 -or ($flowResult.checks.name -join ',') -cne 'prepare,probe,probe' -or ($flowResult.checks.attempt -join ',') -ne '1,1,2') { throw 'Retrying a failed step repeated earlier successful work or lost attempt evidence.' }
    $defaultRetryConfig.testing.flows[0].steps = @($defaultRetryConfig.testing.flows[0].steps[1])
    $script:policyExitCodes = @(75)
    $script:policyProcessCalls = 0
    $flowResult = Invoke-HarnessTestFlow -Config $defaultRetryConfig -Flow smoke -Workspace $fixtureRoot -Paths $paths
    if ($flowResult.passed -or $script:policyProcessCalls -ne 2) { throw 'Default retries were unbounded or failed to retain a persistent error.' }
    $script:policyStopped = $true
    $script:policyProcessCalls = 0
    $flowResult = Invoke-HarnessTestFlow -Config $defaultRetryConfig -Flow smoke -Workspace $fixtureRoot -Paths $paths
    if ($flowResult.failureKind -cne 'Stopped' -or $script:policyProcessCalls -ne 1) { throw 'A stop request was treated as a transient failure.' }
    $script:policyStopped = $false
    $defaultRetryConfig.fallback.transientRetry | Add-Member -NotePropertyName maxRetries -NotePropertyValue 0
    $script:policyProcessCalls = 0
    $flowResult = Invoke-HarnessTestFlow -Config $defaultRetryConfig -Flow smoke -Workspace $fixtureRoot -Paths $paths
    if ($flowResult.passed -or $script:policyProcessCalls -ne 1) { throw 'Explicitly disabled retries were overridden by the new default.' }
    $defaultRetryConfig.fallback = $null
    $script:policyProcessCalls = 0
    $flowResult = Invoke-HarnessTestFlow -Config $defaultRetryConfig -Flow smoke -Workspace $fixtureRoot -Paths $paths
    if ($flowResult.passed -or $script:policyProcessCalls -ne 1) { throw 'A code was treated as transient without an explicit declaration.' }
    $script:policyExitCodes = @(75, 0)
    $script:policyProcessCalls = 0
    $flowConfig.testing.flows[0].steps[0].repeatable = $false
    $flowResult = Invoke-HarnessTestFlow -Config $flowConfig -Flow smoke -Workspace $fixtureRoot -Paths $paths
    if ($flowResult.passed -or $script:policyProcessCalls -ne 1) { throw 'A nonrepeatable step was retried.' }
    $flowConfig.testing.flows[0].steps[0].repeatable = $true
    $script:policyProcessCalls = 0
    $script:policyExitCodes = @(1)
    $flowResult = Invoke-HarnessTestFlow -Config $flowConfig -Flow smoke -Workspace $fixtureRoot -Paths $paths
    if ($flowResult.passed -or $script:policyProcessCalls -ne 1) { throw 'An unclassified test failure was retried.' }
    $script:policyExitCodes = @(75)
    $script:policyProcessCalls = 0
    $flowConfig.fallback.transientRetry.delaySeconds = 0.1
    $delayResult = Invoke-HarnessTestFlow -Config $flowConfig -Flow smoke -Workspace $fixtureRoot -Paths $paths -MaxMinutes 0.001
    if ($delayResult.failureKind -cne 'Budget' -or $script:policyProcessCalls -ne 1) { throw 'A retry delay reset the flow budget or launched another attempt after exhaustion.' }
    $flowConfig.fallback.transientRetry.delaySeconds = 0
    $script:policyExitCodes = @(1)
    $script:policyProcessCalls = 0
    $null = Invoke-HarnessTests -Paths $paths -Flow smoke
    $null = Invoke-HarnessTests -Paths $paths -Flow smoke -Scheduled
    $savedState = [System.IO.File]::ReadAllText($paths.State)
    $blockedRun = Invoke-HarnessTests -Paths $paths -Flow smoke -Scheduled
    if ($blockedRun.status -cne 'PolicyPaused' -or $script:policyProcessCalls -ne 2 -or [System.IO.File]::ReadAllText($paths.State) -cne $savedState) { throw 'Later scheduled test bypassed persistent failure-threshold pause or mutated its queue/history.' }
    $null = Resume-HarnessTarget $paths 'test:smoke:local' -Actor Owner -Reason 'Fixture failure investigated' -ConfirmStopped
    $script:policyProcessCalls = 0
    $script:policyExitCodes = @(124)
    $script:policyTimeout = $true
    $timedOut = Invoke-HarnessTests -Paths $paths -Flow smoke
    if ($timedOut.result.failureKind -cne 'Budget' -or $script:policyProcessCalls -ne 1 -or -not (Get-HarnessPause $paths 'test:smoke:local')) { throw 'Timeout retried or failed to persist a target pause.' }
    $flowConfig.runner.maxMinutes = 1
    $flowConfig.testing.afterDev = @([pscustomobject]@{ flow = 'smoke'; environment = 'local' })
    $pausedGate = Invoke-HarnessValidation -Config $flowConfig -Workspace $fixtureRoot -Paths $paths
    if ($pausedGate.status -cne 'PolicyPaused' -or $script:policyProcessCalls -ne 1) { throw 'A post-development validation bypassed the paused test target.' }
    $null = Resume-HarnessTarget $paths 'test:smoke:local' -Actor Owner -Reason 'Timeout investigated' -ConfirmStopped
    $script:policyExitCodes = @(1)
    $script:policyTimeout = $false
    $script:policyProcessCalls = 0
    $null = Invoke-HarnessValidation -Config $flowConfig -Workspace $fixtureRoot -Paths $paths
    $null = Invoke-HarnessTests -Paths $paths -Flow smoke -Scheduled
    if (-not (Get-HarnessPause $paths 'test:smoke:local') -or $script:policyProcessCalls -ne 2) { throw 'Ad-hoc and post-development flow failures did not share target counters.' }
    $flowConfig.runner.command = 'pwsh'
    $flowConfig.runner.model = 'fixture-model'
    $flowConfig.runner.reasoningEffort = 'high'
    $flowConfig.runner.maxCredits = 1
    $flowConfig.runner.criticalReview = $false
    Write-HarnessJson $paths.Config $flowConfig
    $script:policyReviewCalls = 0
    function Resolve-HarnessReviewBaseline { param($Paths, $BaseRef); [pscustomobject]@{ reference = 'fixture-upstream'; commit = 'fixture-base'; selection = 'Upstream' } }
    function Get-HarnessSnapshot { param($Paths, $Config, $Workspace, $BaseRef) 'fixture-snapshot' }
    function Invoke-HarnessAgent {
        param($Paths, $Config, $Task, $Workspace, $Phase, $Snapshot)
        $script:policyReviewCalls++
        Assert-PolicyFailure { Enter-HarnessLock $Paths.RunLock } 'busy'
        [pscustomobject]@{ verdict = 'clean'; summary = 'Fixture clean'; findings = @() }
    }
    $review = Invoke-HarnessReview -Paths $paths
    if ($review.status -cne 'clean' -or $script:policyReviewCalls -ne 2 -or (Read-HarnessState $paths).active) { throw 'Independent review did not finish its fresh pass with shared-lock tracking.' }
    $null = Set-HarnessPause $paths review 'Review pause fixture' Owner
    $review = Invoke-HarnessReview -Paths $paths
    if ($review.status -cne 'PolicyPaused' -or $script:policyReviewCalls -ne 2) { throw 'Independent review bypassed its target pause.' }
    $runLock = Enter-HarnessLock $paths.RunLock
    try { Assert-PolicyFailure { Resume-HarnessTarget $paths review -Actor Owner -Reason Checked -ConfirmStopped } 'busy' }
    finally { $runLock.Dispose() }
    $null = Resume-HarnessTarget $paths review -Actor Owner -Reason Checked -ConfirmStopped
    $beforeState = [System.IO.File]::ReadAllText($paths.State)
    $preview = & $dispatcher -ProjectPath $fixtureRoot -Action Fallback -PolicyAction Stop -Target project -Actor Owner -Reason Fixture | ConvertFrom-Json
    if (-not $preview.preview -or [System.IO.File]::ReadAllText($paths.State) -cne $beforeState) { throw 'Public stop preview changed state.' }
    $null = & $dispatcher -ProjectPath $fixtureRoot -Action Fallback -PolicyAction Pause -Target development -Actor Owner -Reason 'Fixture development pause' -Apply
    $beforeState = [System.IO.File]::ReadAllText($paths.State)
    $cycle = & $dispatcher -ProjectPath $fixtureRoot -Action Cycle -Scheduled | ConvertFrom-Json
    if ($cycle.status -cne 'PolicyPaused' -or [System.IO.File]::ReadAllText($paths.State) -cne $beforeState) { throw 'A paused scheduled cycle launched or mutated queues/history.' }
    $null = & $dispatcher -ProjectPath $fixtureRoot -Action Recover -ConfirmStopped
    if (-not (Get-HarnessPause $paths development)) { throw 'Recovery bypassed a safety pause.' }
    $null = & $dispatcher -ProjectPath $fixtureRoot -Action Fallback -PolicyAction Resume -Target development -Actor Owner -Reason 'Fixture cause checked' -ConfirmStopped -Apply
    if (Get-HarnessPause $paths development) { throw 'Explicit public resume did not clear the selected pause.' }
    '{"allowedModels":["different-model"]}' | Set-Content -LiteralPath $declaration -Encoding UTF8
    $null = & $dispatcher -ProjectPath $fixtureRoot -Action Restrict -PolicyAction Declare -DefinitionPath $declaration -Apply -Actor Owner -Reason 'Fixture model boundary'
    Assert-PolicyFailure { Invoke-HarnessReview -Paths $paths } 'allowedModels'
    if (-not (Get-HarnessPause $paths project).stopRequested -or $script:policyReviewCalls -ne 2) { throw 'A runtime restriction violation failed to stop/pause the project before launching a reviewer.' }
    $beforeState = [System.IO.File]::ReadAllText($paths.State)
    $blockedCycle = Invoke-HarnessCycle $paths -Scheduled
    $blockedTest = Invoke-HarnessTests $paths smoke
    $blockedReview = Invoke-HarnessReview $paths
    if ($blockedCycle.status -cne 'PolicyPaused' -or $blockedTest.status -cne 'PolicyPaused' -or $blockedReview.status -cne 'PolicyPaused' -or [System.IO.File]::ReadAllText($paths.State) -cne $beforeState) { throw 'A project restriction pause was bypassed by an execution entrypoint.' }
    Write-Output 'Policy checks passed: bounded default retries, explicit opt-out and transient-code gates, no-write declarations, persistent pauses/resume, once-per-run failure counts, restrictions, and stricter caps. No live policy changed.'
}
finally {
    $env:SKILLVAULT_OWNERSHIP_ROOT = $savedFixtureOwnershipRoot
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}