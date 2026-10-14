function Get-HarnessTestSettings {
    param($Config)
    if ($null -ne $Config.testing) { return $Config.testing }
    [pscustomobject]@{ environments = @(); flows = @(); afterDev = @(); afterReview = @() }
}

function Get-HarnessUnitTestLevel {
    param($Config)
    $settings = Get-HarnessTestSettings $Config
    if ('unitTests' -cin $settings.PSObject.Properties.Name -and $settings.unitTests) { return ConvertTo-HarnessUnitTestLevel $settings.unitTests }
    'blocking'
}

# The unit-test level critical was renamed blocking on 2026-10-09; saved settings and declaration files keep their meaning.
function ConvertTo-HarnessUnitTestLevel {
    param($Level)
    $value = [string]$Level
    if (-not $value -or $value -ceq 'critical') { return 'blocking' }
    $value
}

function Get-HarnessTestHooks {
    param($Config, [ValidateSet('afterDev', 'afterReview')][string]$Stage)
    $settings = Get-HarnessTestSettings $Config
    if ($Stage -cnotin $settings.PSObject.Properties.Name) { return @() }
    @($settings.$Stage | Where-Object { $null -ne $_ })
}

# The read-only "how this project is tested" view shared by context, policy, and the developer prompt.
function Get-HarnessTestingSummary {
    param($Config)
    $settings = Get-HarnessTestSettings $Config
    $flows = @($settings.flows | Where-Object { $null -ne $_ })
    $describe = {
        param($Hook)
        $flow = @($flows | Where-Object { $_.name -eq $Hook.flow }) | Select-Object -First 1
        [pscustomobject]@{
            flow = [string]$Hook.flow
            environment = $(if ($Hook.environment) { [string]$Hook.environment } else { [string]$flow.defaultEnvironment })
            method = [string]$flow.method
            effects = $(if ($flow.effects) { [string]$flow.effects } else { 'undeclared' })
            maxMinutes = $flow.maxMinutes
        }
    }
    $withReview = @(foreach ($hook in (Get-HarnessTestHooks $Config afterDev)) { & $describe $hook })
    $afterReview = @(foreach ($hook in (Get-HarnessTestHooks $Config afterReview)) { & $describe $hook })
    $listed = @(@($withReview.flow) + @($afterReview.flow) | Where-Object { $_ })
    [pscustomobject]@{
        unitTests = Get-HarnessUnitTestLevel $Config
        commands = @($Config.runner.validationCommands | Where-Object { $null -ne $_ } | ForEach-Object { (@($_.executable) + @($_.arguments)) -join ' ' })
        withReview = $withReview
        afterReview = $afterReview
        onDemand = @(foreach ($flow in @($flows | Where-Object { $_.name -notin $listed })) {
            [pscustomobject]@{ flow = [string]$flow.name; environment = [string]$flow.defaultEnvironment; method = [string]$flow.method; effects = $(if ($flow.effects) { [string]$flow.effects } else { 'undeclared' }) }
        })
        environments = @(foreach ($environment in @($settings.environments | Where-Object { $null -ne $_ })) { [pscustomobject]@{ name = [string]$environment.name; allowScheduled = [bool]$environment.allowScheduled } })
        note = $(if (-not $withReview.Count -and -not $afterReview.Count) { 'No declared test flow runs during development; the harness runs runner.validationCommands or the repository test entry (scripts/test-all.ps1, then npm test). Declare real tests with /harness-dev test declare.' } else { '' })
        warnings = @(Get-HarnessTestWarnings $settings)
    }
}

function Get-HarnessExternalFlowNames {
    param($Settings, [string[]]$Names)
    $external = @($Settings.flows | Where-Object { $null -ne $_ -and $_.effects -ceq 'external' } | ForEach-Object { [string]$_.name })
    @($Names | Where-Object { $_ -and $_ -in $external } | Select-Object -Unique)
}

# An external flow in afterDev is allowed, but it runs on code that review has not passed yet.
function Get-HarnessTestWarnings {
    param($Settings)
    $names = @($Settings.afterDev | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_.flow })
    foreach ($name in @(Get-HarnessExternalFlowNames $Settings $names)) {
        "Flow $name declares external effects, and afterDev runs it on code that review has not passed yet, at the same time as the first review. Keep it there if that is intended, or move it to afterReview to run it only on reviewed code."
    }
}

# The run-report note for external afterDev flows that ran before review was clean.
function Get-HarnessExternalRunNote {
    param($Config, $Validation)
    $names = @($Validation.flows | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_.flow })
    $ran = @(Get-HarnessExternalFlowNames (Get-HarnessTestSettings $Config) $names)
    if (-not $ran.Count) { return '' }
    "External flows ran before review was clean: $($ran -join ', ')."
}

function Assert-HarnessTestName {
    param([string]$Name)
    if ($Name -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { throw 'Test flow and environment names must use letters, digits, dots, underscores, or hyphens.' }
}

function Assert-HarnessTestSettings {
    param($Settings)
    foreach ($section in @('environments', 'flows', 'afterDev')) {
        if ($Settings.$section -isnot [array]) { throw "Testing $section must be an array." }
    }
    $sections = @($Settings.PSObject.Properties.Name)
    if ('afterReview' -cin $sections -and $Settings.afterReview -isnot [array]) { throw 'Testing afterReview must be an array.' }
    if ('unitTests' -cin $sections -and $Settings.unitTests -cnotin @('blocking', 'broad', 'critical')) { throw 'Testing unitTests must be blocking or broad.' }
    $environmentNames = @{}
    foreach ($target in $Settings.environments) {
        Assert-HarnessTestName $target.name
        if ($environmentNames.ContainsKey($target.name)) { throw "Duplicate test environment: $($target.name)" }
        $environmentNames[$target.name] = $true
        if ([string]::IsNullOrWhiteSpace([string]$target.workingDirectory) -or $target.allowScheduled -isnot [bool]) {
            throw 'Test environments require workingDirectory and an explicit boolean allowScheduled.'
        }
        if ($target.requiredVariables -isnot [array]) { throw 'Environment requiredVariables must be an array of names, not secret values.' }
        if ($target.variables -isnot [System.Collections.IDictionary] -and $target.variables -isnot [pscustomobject]) { throw 'Environment variables must be a JSON object of non-secret values.' }
    }
    $flowNames = @{}
    foreach ($flow in $Settings.flows) {
        Assert-HarnessTestName $flow.name
        if ($flowNames.ContainsKey($flow.name)) { throw "Duplicate test flow: $($flow.name)" }
        $flowNames[$flow.name] = $true
        if (-not $environmentNames.ContainsKey([string]$flow.defaultEnvironment)) { throw "Unknown default environment for flow $($flow.name)." }
        $minutes = [double]$flow.maxMinutes
        if ($minutes -le 0 -or [double]::IsNaN($minutes) -or [double]::IsInfinity($minutes)) { throw "Test flow $($flow.name) requires a positive maxMinutes budget." }
        if ([string]::IsNullOrWhiteSpace([string]$flow.method) -or $flow.steps -isnot [array] -or $flow.steps.Count -eq 0) { throw 'Test flows require a method and an ordered steps array.' }
        if ('effects' -cin $flow.PSObject.Properties.Name -and $flow.effects -cnotin @('local', 'external')) { throw "Flow $($flow.name) effects must be local (writes only local files) or external." }
        foreach ($step in $flow.steps) {
            if ([string]::IsNullOrWhiteSpace([string]$step.name) -or [string]::IsNullOrWhiteSpace([string]$step.executable) -or $step.arguments -isnot [array]) { throw 'Test steps require name, executable, and an arguments array.' }
            if ('repeatable' -cin $step.PSObject.Properties.Name -and $step.repeatable -isnot [bool]) { throw 'Test step repeatable must be an explicit boolean.' }
        }
    }
    foreach ($stage in @('afterDev', 'afterReview')) {
        if ($stage -cnotin $sections) { continue }
        foreach ($hook in @($Settings.$stage | Where-Object { $null -ne $_ })) {
            if (-not $flowNames.ContainsKey([string]$hook.flow)) { throw "Unknown $stage test flow: $($hook.flow)" }
            if ($hook.environment -and -not $environmentNames.ContainsKey([string]$hook.environment)) { throw "Unknown $stage environment: $($hook.environment)" }
        }
    }
}

function Set-HarnessTestSettings {
    param($Paths, [string]$DefinitionPath)
    if (-not [System.IO.Path]::IsPathRooted($DefinitionPath)) { $DefinitionPath = Join-Path $Paths.Project $DefinitionPath }
    $incoming = [System.IO.File]::ReadAllText($DefinitionPath) | ConvertFrom-Json
    if ($incoming -isnot [pscustomobject]) { throw 'A test declaration must be a JSON object.' }
    $sections = @($incoming.PSObject.Properties.Name)
    if ($sections.Count -eq 0 -or @($sections | Where-Object { $_ -cnotin @('environments', 'flows', 'afterDev', 'afterReview', 'unitTests') }).Count -gt 0) { throw 'Test declarations contain only environments, flows, afterDev, afterReview, and unitTests sections.' }
    foreach ($section in $sections) {
        if ($section -ceq 'unitTests') {
            if ($incoming.unitTests -cnotin @('blocking', 'broad', 'critical')) { throw 'Testing unitTests must be blocking or broad.' }
            continue
        }
        if ($incoming.$section -isnot [array]) { throw "Testing $section must be an array." }
    }
    $runLock = Enter-HarnessLock $Paths.RunLock
    try {
        $lock = Enter-HarnessLock $Paths.Lock
        try {
            if ((Read-HarnessState $Paths).active) { throw 'Recover interrupted work before changing test declarations.' }
            $config = Read-HarnessConfig $Paths
            $settings = Get-HarnessTestSettings $config
            foreach ($section in @('environments', 'flows')) {
                if ($section -cin $sections) {
                    $replacedNames = @($incoming.$section | ForEach-Object { $_.name })
                    $settings.$section = @($settings.$section | Where-Object { $_.name -notin $replacedNames }) + @($incoming.$section)
                }
            }
            foreach ($section in @('afterDev', 'afterReview')) {
                if ($section -cin $sections) { $settings | Add-Member -NotePropertyName $section -NotePropertyValue @($incoming.$section) -Force }
            }
            if ('unitTests' -cin $sections) { $settings | Add-Member -NotePropertyName unitTests -NotePropertyValue (ConvertTo-HarnessUnitTestLevel $incoming.unitTests) -Force }
            Assert-HarnessTestSettings $settings
            $config | Add-Member -NotePropertyName testing -NotePropertyValue $settings -Force
            Write-HarnessConfig $Paths $config
            $saved = $settings | Select-Object -Property *
            $saved | Add-Member -NotePropertyName warnings -NotePropertyValue @(Get-HarnessTestWarnings $settings) -Force
            $saved
        }
        finally { $lock.Dispose() }
    }
    finally { $runLock.Dispose() }
}

function Resolve-HarnessTestPlan {
    param($Config, [string]$Flow, [string]$Environment, [string]$Workspace, [switch]$Scheduled)
    Assert-HarnessTestName $Flow
    $settings = Get-HarnessTestSettings $Config
    Assert-HarnessTestSettings $settings
    $flows = @($settings.flows | Where-Object { $_.name -eq $Flow })
    if ($flows.Count -ne 1) { throw "Test flow not found exactly once: $Flow" }
    $definition = $flows[0]
    if (-not $Environment) { $Environment = [string]$definition.defaultEnvironment }
    Assert-HarnessTestName $Environment
    $environments = @($settings.environments | Where-Object { $_.name -eq $Environment })
    if ($environments.Count -ne 1) { throw "Test environment not found exactly once: $Environment" }
    $target = $environments[0]
    Assert-HarnessRestrictions -Config $Config -TestEnvironment $target.name
    if ($Scheduled -and ($target.allowScheduled -isnot [bool] -or -not $target.allowScheduled)) { throw "Scheduled tests are not approved for environment $Environment." }
    $minutes = [double]$definition.maxMinutes
    if ($minutes -le 0 -or [double]::IsNaN($minutes) -or [double]::IsInfinity($minutes)) { throw "Test flow $Flow requires a positive maxMinutes budget." }
    if ([string]::IsNullOrWhiteSpace([string]$definition.method) -or @($definition.steps).Count -eq 0) { throw "Test flow $Flow requires a method and executable steps." }
    foreach ($step in @($definition.steps)) {
        if ([string]::IsNullOrWhiteSpace([string]$step.executable) -or $null -eq $step.arguments -or $step.arguments -isnot [array]) { throw 'Each test step requires executable and an arguments array.' }
        $null = Get-Command ([string]$step.executable) -ErrorAction Stop
        Assert-HarnessRestrictions -Config $Config -Executable $step.executable
    }
    $directory = [string]$target.workingDirectory
    if ([string]::IsNullOrWhiteSpace($directory)) { throw "Test environment $Environment requires workingDirectory." }
    if (-not [System.IO.Path]::IsPathRooted($directory)) { $directory = Join-Path $Workspace $directory }
    $directory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($directory)
    Assert-HarnessRestrictions -Config $Config -ProjectRoot $Config.projectRoot -Workspace $directory
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { throw "Test environment directory is unavailable: $directory" }
    $variables = @{}
    if ($target.variables -is [System.Collections.IDictionary]) {
        foreach ($name in $target.variables.Keys) { $variables[[string]$name] = [string]$target.variables[$name] }
    }
    elseif ($null -ne $target.variables) {
        foreach ($property in $target.variables.PSObject.Properties) { $variables[$property.Name] = [string]$property.Value }
    }
    foreach ($name in @($variables.Keys) + @($target.requiredVariables)) {
        if ([string]$name -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*$') { throw 'Test environment variable names are invalid.' }
    }
    foreach ($name in @($target.requiredVariables)) {
        $value = if ($variables.ContainsKey($name)) { $variables[$name] } else { [Environment]::GetEnvironmentVariable($name) }
        if ([string]::IsNullOrWhiteSpace($value)) { throw "Required environment variable is unavailable: $name" }
    }
    [pscustomobject]@{
        flow = $definition.name
        environment = $target.name
        method = $definition.method
        directory = $directory
        maxMinutes = $minutes
        steps = @($definition.steps)
        variables = $variables
    }
}

function Get-HarnessTestTarget {
    param($Config, [string]$Flow, [string]$Environment)
    $definition = @((Get-HarnessTestSettings $Config).flows | Where-Object { $_.name -eq $Flow }) | Select-Object -First 1
    if ($definition) { $Flow = [string]$definition.name }
    if (-not $Environment -and $definition) { $Environment = [string]$definition.defaultEnvironment }
    $declaredEnvironment = @((Get-HarnessTestSettings $Config).environments | Where-Object { $_.name -eq $Environment }) | Select-Object -First 1
    if ($declaredEnvironment) { $Environment = [string]$declaredEnvironment.name }
    'test:{0}:{1}' -f $Flow, $Environment
}

function Invoke-HarnessTestFlow {
    param($Config, [string]$Flow, [string]$Environment, [string]$Workspace, [switch]$Scheduled, [double]$MaxMinutes = 0, $Paths, [string]$ParentTarget, [hashtable]$ExtraVariables)
    $result = [pscustomobject][ordered]@{
        flow = $Flow; environment = $Environment; method = ''; directory = ''
        status = 'Blocked'; passed = $false; exitCode = 1
        startedAt = [datetimeoffset]::UtcNow.ToString('o'); finishedAt = ''
        checks = @(); error = ''; failureKind = 'Blocked'
    }
    try {
        $targetName = Get-HarnessTestTarget $Config $Flow $Environment
        $targets = @($targetName)
        if ($ParentTarget) { $targets += $ParentTarget }
        Assert-HarnessTargetRunning $Paths $targets
        $plan = Resolve-HarnessTestPlan -Config $Config -Flow $Flow -Environment $Environment -Workspace $Workspace -Scheduled:$Scheduled
        # Monitor workers receive their item through environment variables; arguments stay literal.
        if ($ExtraVariables) {
            foreach ($name in @($ExtraVariables.Keys)) {
                if ([string]$name -cnotmatch '^HARNESS_[A-Z0-9_]+$') { throw 'Flow item variables must be HARNESS_* names.' }
                $plan.variables[[string]$name] = [string]$ExtraVariables[$name]
            }
        }
        $result.flow = $plan.flow
        $result.environment = $plan.environment
        $result.method = $plan.method
        $result.directory = $plan.directory
        $policy = Get-HarnessFallbackPolicy $Config
        if ($Config.fallback) { Assert-HarnessPolicyDefinition fallback $Config.fallback }
        $result.status = 'Failed'
        $result.failureKind = 'Failure'
        $clock = [System.Diagnostics.Stopwatch]::StartNew()
        $budget = Get-HarnessExecutionLimit $Config maxProcessMinutes $plan.maxMinutes
        if ($MaxMinutes -gt 0) { $budget = [Math]::Min($budget, $MaxMinutes) }
        $completed = 0
        foreach ($step in $plan.steps) {
            for ($attempt = 0; ; $attempt++) {
                Assert-HarnessTargetRunning $Paths $targets
                $remaining = $budget - $clock.Elapsed.TotalMinutes
                if ($remaining -le 0) { $result.exitCode = 124; $result.failureKind = 'Budget'; throw 'Test flow exceeded its time budget.' }
                $check = Invoke-HarnessProcess -Executable $step.executable -Arguments @($step.arguments) -Directory $plan.directory -MaxMinutes $remaining -EnvironmentVariables $plan.variables -Config $Config -Paths $Paths -Targets $targets
                $result.checks += [pscustomobject]@{
                    name = $step.name; attempt = $attempt + 1; executable = $step.executable; arguments = @($step.arguments)
                    exitCode = $check.ExitCode; output = $check.Output; error = $check.Error; timedOut = $check.TimedOut; stopped = [bool]$check.Stopped
                }
                $result.exitCode = $check.ExitCode
                if ($check.Stopped) { $result.failureKind = 'Stopped'; break }
                if ($check.TimedOut) { $result.failureKind = 'Budget'; break }
                if ($check.ExitCode -eq 0 -or $step.repeatable -ne $true -or $attempt -ge $policy.transientRetry.maxRetries -or $check.ExitCode -notin $policy.transientRetry.exitCodes) { break }
                $retryAt = $clock.Elapsed.TotalSeconds + $policy.transientRetry.delaySeconds
                $wait = [System.Threading.ManualResetEventSlim]::new($false)
                try {
                    while ($clock.Elapsed.TotalSeconds -lt $retryAt) {
                        Assert-HarnessTargetRunning $Paths $targets
                        $remainingSeconds = [Math]::Min($retryAt, $budget * 60) - $clock.Elapsed.TotalSeconds
                        if ($remainingSeconds -le 0) { $result.exitCode = 124; $result.failureKind = 'Budget'; throw 'Test retry delay exhausted the shared time budget.' }
                        $null = $wait.Wait([int][Math]::Min(250, [Math]::Ceiling($remainingSeconds * 1000)))
                    }
                }
                finally { $wait.Dispose() }
            }
            if ($check.ExitCode -ne 0) { break }
            $completed++
        }
        if ($completed -eq $plan.steps.Count) {
            $result.status = 'Passed'; $result.passed = $true; $result.exitCode = 0; $result.failureKind = 'Success'
        }
    }
    catch {
        $result.error = $_.Exception.Message
        $kind = Get-HarnessFailureKind $_
        if ($kind -ne 'Failure') { $result.failureKind = $kind }
        if ($result.failureKind -eq 'PolicyPaused') { $result.status = 'PolicyPaused' }
    }
    finally { $result.finishedAt = [datetimeoffset]::UtcNow.ToString('o') }
    $result
}

function Invoke-HarnessTests {
    param($Paths, [string]$Flow, [string]$Environment, [string]$TaskId, [switch]$Scheduled, $RunnerContext)
    $config = Read-HarnessConfig $Paths
    $targetName = Get-HarnessTestTarget $config $Flow $Environment
    $pause = Get-HarnessPause $Paths $targetName
    if ($pause) { return [pscustomobject]@{ status = 'PolicyPaused'; target = $pause.target; reason = $pause.reason } }
    try { $runLock = Enter-HarnessLock $Paths.RunLock }
    catch { if ($_.Exception.Message -like '*Harness is busy*') { return [pscustomobject]@{ status = 'Busy'; message = 'Another harness run owns the workspace; no tests started.' } }; throw }
    $ownership = $null
    try {
        $config = Resolve-HarnessRunnerConfig (Read-HarnessConfig $Paths) $RunnerContext
        $targetName = Get-HarnessTestTarget $config $Flow $Environment
        Assert-HarnessTargetRunning $Paths @($targetName)
        Assert-HarnessBoard $Paths $config
        $state = Read-HarnessState $Paths
        if ($state.active) {
            Save-HarnessPolicyOutcome $Paths $config (Get-HarnessActiveTarget $state) $state.active.runId Interrupted 'Previous runner ended without a confirmed outcome.'
            throw 'Recover interrupted work before starting tests.'
        }
        $workspace = Get-HarnessExecutionRoot $config
        $repositoryRoot = $workspace
        $task = $null
        if ($TaskId) {
            $task = Get-HarnessTask $state $TaskId
            if ($task.repositoryRef) {
                $repositoryRoot = Resolve-HarnessRepository $Paths $config $task
                $workspace = $repositoryRoot
            }
            if ($task.workspace) { $workspace = [string]$task.workspace }
            if ($task.repositoryRef) {
                Assert-HarnessRestrictions -Config $config -ProjectRoot $Paths.Project -Workspace $workspace
                Assert-HarnessRepositoryWorkspace $repositoryRoot $workspace
            }
        }
        $testPlan = Resolve-HarnessTestPlan -Config $config -Flow $Flow -Environment $Environment -Workspace $workspace -Scheduled:$Scheduled
        $ownership = Enter-HarnessOwnership -Paths $Paths -Role test -TaskId $TaskId -Workspace $workspace -AdditionalWorkspaces @($testPlan.directory)
        $null = Get-HarnessRuleContext $Paths $config -Workspace $workspace -RepositoryRoot $repositoryRoot
        $snapshot = ''
        if (Test-Path -LiteralPath (Join-Path $workspace '.git')) { $snapshot = Get-HarnessSnapshot $Paths $config $workspace -RepositoryRoot $repositoryRoot }
        $runId = [guid]::NewGuid().ToString('N')
        $reportPath = Get-HarnessReportPath $Paths $config $runId Test
        $run = [pscustomobject][ordered]@{
            id = $runId; taskId = $TaskId; phase = 'Test'; status = 'Running'
            startedAt = [datetimeoffset]::UtcNow.ToString('o'); finishedAt = ''
            model = ''; effort = ''; workspace = $workspace; report = $reportPath; exitCode = ''
            flow = $Flow; environment = $Environment
            repositoryRef = $task.repositoryRef; repositoryRoot = $repositoryRoot
        }
        $null = Update-HarnessState $Paths -Config $config -Operation {
            param($saved)
            $saved.runs = @($saved.runs) + @($run)
            $saved.active = [pscustomobject]@{ taskId = $TaskId; runId = $runId; phase = 'Test'; ownerProcessId = $PID; target = $targetName; ownershipClaim = $ownership.id }
        }
        $result = Invoke-HarnessTestFlow -Config $config -Flow $Flow -Environment $Environment -Workspace $workspace -Scheduled:$Scheduled -Paths $Paths
        New-Item -ItemType Directory -Path (Split-Path -Parent $reportPath) -Force | Out-Null
        $report = "# Harness test report`n`nHarness project: $($Paths.Project)`nRepository reference: $($task.repositoryRef)`nRepository root: $repositoryRoot`nWorkspace: $workspace`nScheduled: $([bool]$Scheduled)`n`n## Result`n`n" + ($result | ConvertTo-Json -Depth 15) + "`n`n## Source Snapshot`n`n$snapshot`n"
        [System.IO.File]::WriteAllText($reportPath, $report, (New-Object System.Text.UTF8Encoding($false)))
        $null = Update-HarnessState $Paths -Config $config -Operation {
            param($saved)
            $savedRun = $saved.runs | Where-Object { $_.id -ceq $runId }
            $savedRun.status = $result.status
            $savedRun.finishedAt = $result.finishedAt
            $savedRun.exitCode = [string]$result.exitCode
            $savedRun.flow = $result.flow
            $savedRun.environment = $result.environment
            if ($result.failureKind -ne 'Interrupted') { $saved.active = $null }
            if ($result.failureKind -notin @('Blocked', 'PolicyPaused')) {
                Register-HarnessPolicyOutcome $saved $config $targetName $runId $result.failureKind "Test $($result.flow) $($result.status). Report: $reportPath"
            }
        }
        [pscustomobject]@{ status = $result.status; flow = $result.flow; environment = $result.environment; exitCode = $result.exitCode; taskId = $TaskId; repositoryRef = $task.repositoryRef; repositoryRoot = $repositoryRoot; workspace = $workspace; report = $reportPath; result = $result }
    }
    catch {
        if ($_.Exception.Data['SkillOwnershipStatus']) { return [pscustomobject]@{ status = $_.Exception.Data['SkillOwnershipStatus']; owner = $_.Exception.Data['SkillOwnershipOwner']; message = $_.Exception.Message } }
        throw
    }
    finally {
        try { Exit-HarnessOwnership $ownership $Paths }
        finally { $runLock.Dispose() }
    }
}