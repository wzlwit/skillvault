$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$bootstrapScript = Join-Path $PSScriptRoot 'install-global.ps1'
$bootstrapShellScript = Join-Path $PSScriptRoot 'install-global.sh'
. (Join-Path $repositoryRoot 'skills\core\skillvault-installation\scripts\skill-files.ps1')
. (Join-Path $PSScriptRoot 'setup.ps1')

$catalog = Get-Content -LiteralPath (Join-Path $repositoryRoot 'catalog.json') -Raw | ConvertFrom-Json

$expectedBootstrapSkills = @(Read-BootstrapSkillNames -RepositoryRoot $repositoryRoot)

$expectedLegacySkills = @(
    'skillvault:skills/public/core/skillvault',
    'sv-sync:skills/public/sv-sync',
    'skillvault-sync:skills/public/skillvault-sync',
    'ai-principles:skills/public/core/ai-principles',
    'rule-update:skills/public/core/rule-update'
)

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Test-Throws {
    param([scriptblock]$Action)
    try { & $Action | Out-Null; return $false }
    catch { return $true }
}

function Get-InstallResidue {
    param([string]$Root)
    return @(Get-ChildItem -LiteralPath $Root -Force | Where-Object { $_.Name -like '.skillvault-stage-*' -or $_.Name -like '.skillvault-backup-*' })
}

function Assert-SetupPrompt {
    $cases = @(
        @{ Name = 'idle'; Seconds = @(30); Keys = @(); Expected = $null },
        @{ Name = 'empty'; Seconds = @(0); Keys = @(13); Expected = '' },
        @{ Name = 'accepted'; Seconds = @(29, 29); Keys = @(89, 13); Expected = 'Y' },
        @{ Name = 'partial-idle'; Seconds = @(0, 30); Keys = @(89); Expected = $null },
        @{ Name = 'escape'; Seconds = @(0); Keys = @(27); Expected = $null },
        @{ Name = 'backspace'; Seconds = @(0, 0, 0, 0); Keys = @(89, 8, 78, 13); Expected = 'N' }
    )
    foreach ($case in $cases) {
        $clock = [pscustomobject]@{ Times = (New-Object 'System.Collections.Generic.Queue[int]'); Restarts = 0 }
        foreach ($seconds in $case.Seconds) { $clock.Times.Enqueue($seconds) }
        $clock | Add-Member -MemberType ScriptProperty -Name Elapsed -Value {
            if ($this.Times.Count -eq 0) { throw 'Unexpected clock read.' }
            return [timespan]::FromSeconds($this.Times.Dequeue())
        }
        $clock | Add-Member -MemberType ScriptMethod -Name Restart -Value { $this.Restarts++ }
        $rawUI = [pscustomobject]@{ KeyAvailable = $true; Keys = (New-Object 'System.Collections.Generic.Queue[int]') }
        foreach ($keyCode in $case.Keys) { $rawUI.Keys.Enqueue($keyCode) }
        $rawUI | Add-Member -MemberType ScriptMethod -Name ReadKey -Value {
            param($Options)
            if ($this.Keys.Count -eq 0) { throw 'Unexpected key read.' }
            $keyCode = $this.Keys.Dequeue()
            return [pscustomobject]@{ VirtualKeyCode = $keyCode; Character = [char]$keyCode }
        }
        $response = Read-SetupResponse -Prompt $case.Name -RawUI $rawUI -Clock $clock 6>$null
        if ($null -eq $case.Expected) {
            Assert-True ($null -eq $response) "$($case.Name) cancels without accepting partial input"
        }
        else { Assert-True ($response -ceq $case.Expected) "$($case.Name) returns only submitted input" }
        Assert-True ($clock.Restarts -eq $case.Keys.Count) "$($case.Name) restarts the idle timer after each keypress"
    }
}

function Assert-SetupClone {
    param([string]$FixtureRoot)

    $cases = @(
        @{ Name = 'idle'; Responses = @($null); Clones = 0; Opens = 0 },
        @{ Name = 'empty'; Responses = @(''); Clones = 0; Opens = 0 },
        @{ Name = 'decline'; Responses = @('N'); Clones = 0; Opens = 0 },
        @{ Name = 'destination-idle'; Responses = @('yes', $null); Clones = 0; Opens = 0 },
        @{ Name = 'existing'; Responses = @('y', $FixtureRoot); Clones = 0; Opens = 0 },
        @{ Name = 'open-idle'; Responses = @('y', (Join-Path $FixtureRoot 'clone-only'), $null); Clones = 1; Opens = 0 },
        @{ Name = 'open'; Responses = @('y', (Join-Path $FixtureRoot 'clone-and-open'), 'yes'); Clones = 1; Opens = 1 },
        @{ Name = 'clone-failure'; Responses = @('y', (Join-Path $FixtureRoot 'clone-failed')); Clones = 1; Opens = 0; FailClone = $true }
    )
    $savedExitCode = $global:LASTEXITCODE
    try {
        foreach ($case in $cases) {
            $responses = New-Object 'System.Collections.Generic.Queue[object]'
            foreach ($response in $case.Responses) { $responses.Enqueue($response) }
            $cloneCalls = New-Object 'System.Collections.Generic.List[object]'
            $openCalls = New-Object 'System.Collections.Generic.List[object]'
            function Read-SetupResponse {
                param([string]$Prompt)
                if ($responses.Count -eq 0) { throw 'Unexpected optional prompt.' }
                return $responses.Dequeue()
            }
            function git {
                $cloneCalls.Add(@($args))
                if ($case.FailClone) { $global:LASTEXITCODE = 1 }
                else {
                    New-Item -ItemType Directory -Path $args[-1] | Out-Null
                    $global:LASTEXITCODE = 0
                }
            }
            function code {
                $openCalls.Add(@($args))
                $global:LASTEXITCODE = 0
            }
            Request-SetupClone -WarningAction SilentlyContinue | Out-Null
            Assert-True ($cloneCalls.Count -eq $case.Clones) "$($case.Name) clones only after explicit approval and destination"
            Assert-True ($openCalls.Count -eq $case.Opens) "$($case.Name) opens VS Code only after explicit approval"
            Assert-True ($responses.Count -eq 0) "$($case.Name) asks no later questions after cancellation or failure"
            if ($cloneCalls.Count -gt 0) {
                Assert-True ($cloneCalls[0][0] -ceq 'clone' -and 'https://github.com/wzlwit/skillvault.git' -cin $cloneCalls[0]) 'optional setup performs a real clone operation rather than git init'
                Assert-True ($cloneCalls[0][-1] -ceq $case.Responses[1]) 'cloning uses only the chosen destination'
            }
            if ($openCalls.Count -gt 0) {
                Assert-True ($openCalls[0][0] -ceq '--new-window' -and $openCalls[0][-1] -ceq $case.Responses[1]) 'VS Code opens the chosen clone in a new window'
            }
        }
    }
    finally { $global:LASTEXITCODE = $savedExitCode }
}

function Get-ScriptListValues {
    param([string]$Path, [string]$Pattern, [string]$VariableName)

    if ($VariableName) {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors.Count) { throw "Cannot parse registration list: $Path" }
        $registration = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and $node.Left.VariablePath.UserPath -ceq $VariableName
        }, $true)
        if (-not $registration) { throw "Registration variable not found in ${Path}: $VariableName" }
        return @($registration.Right.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.StringConstantExpressionAst]
        }, $true) | ForEach-Object { $_.Value })
    }

    $content = Get-Content -LiteralPath $Path -Raw
    $listMatch = [regex]::Match($content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $listMatch.Success) { throw "List not found in ${Path}: $Pattern" }

    return @([regex]::Matches($listMatch.Groups['body'].Value, "['`"]([^'`"]+)['`"]") | ForEach-Object { $_.Groups[1].Value })
}

function Split-LegacyEntry {
    param([string]$Entry)

    $separatorIndex = $Entry.IndexOf(':')
    return [pscustomobject]@{
        Name = $Entry.Substring(0, $separatorIndex)
        SourcePath = $Entry.Substring($separatorIndex + 1)
    }
}

function New-LegacyInstall {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$InstalledBy = 'skillvault-bootstrap',
        [string]$SourcePath,
        [string]$SourceRepo = 'https://github.com/wzlwit/skillvault.git',
        [switch]$WithoutMetadata
    )

    $skillPath = Join-Path $Root $Name
    if (Test-Path -LiteralPath $skillPath) { Remove-Item -LiteralPath $skillPath -Recurse -Force }
    New-Item -ItemType Directory -Path $skillPath -Force | Out-Null
    "# $Name" | Set-Content -LiteralPath (Join-Path $skillPath 'SKILL.md') -Encoding utf8

    if (-not $WithoutMetadata) {
        [ordered]@{
            installedBy = $InstalledBy
            sourceRepo = $SourceRepo
            sourcePath = $SourcePath
            scope = 'global'
            requestedVersion = 'latest'
            installedVersion = '0.0.1'
            installedAt = (Get-Date).ToUniversalTime().ToString('o')
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $skillPath '.skillvault-install.json') -Encoding utf8
    }

    return $skillPath
}

function Get-SkillSourcePath {
    param([string]$SkillName)

    $catalogMatches = @($catalog | Where-Object { $_.name -ceq $SkillName })
    Assert-True ($catalogMatches.Count -eq 1) "the catalog contains exactly one '$SkillName' entry"
    return (Join-Path $repositoryRoot ([string]$catalogMatches[0].path).Replace('/', '\'))
}

function Assert-BootstrapInstalls {
    param([Parameter(Mandatory = $true)][string]$SkillsRoot, [Parameter(Mandatory = $true)][string]$Label)

    foreach ($skillName in $expectedBootstrapSkills) {
        $catalogEntry = @($catalog | Where-Object { $_.name -ceq $skillName })[0]
        $sourcePath = Get-SkillSourcePath -SkillName $skillName
        $targetPath = Join-Path $SkillsRoot $skillName
        $metadataPath = Join-Path $targetPath '.skillvault-install.json'

        Assert-True (Test-Path -LiteralPath $targetPath -PathType Container) "$Label installed '$skillName'"
        Assert-True (Test-Path -LiteralPath $metadataPath -PathType Leaf) "$Label wrote install metadata for '$skillName'"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $targetPath '.git'))) "$Label excluded .git from '$skillName'"
        Assert-True (Test-SkillContentEqual -Source $sourcePath -Target $targetPath) "$Label copied every '$skillName' file byte for byte"

        $manifest = Get-Content -LiteralPath (Join-Path $sourcePath 'skill.json') -Raw | ConvertFrom-Json
        Assert-True ($manifest.version -ceq $catalogEntry.version) "$Label found matching catalog and manifest versions for '$skillName'"

        $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
        Assert-True ($metadata.installedBy -ceq 'skillvault-bootstrap') "$Label recorded installedBy for '$skillName'"
        Assert-True ($metadata.sourceRepo -ceq 'https://github.com/wzlwit/skillvault.git') "$Label recorded sourceRepo for '$skillName'"
        Assert-True ($metadata.sourcePath -ceq ([string]$catalogEntry.path)) "$Label recorded the catalog sourcePath for '$skillName'"
        Assert-True ($metadata.scope -ceq 'global') "$Label recorded global scope for '$skillName'"
        Assert-True ($metadata.requestedVersion -ceq 'latest') "$Label recorded requestedVersion latest for '$skillName'"
        Assert-True ('installedVersion' -in $metadata.PSObject.Properties.Name) "$Label kept installedVersion for '$skillName'"
        Assert-True ($metadata.installedVersion -ceq $catalogEntry.version) "$Label recorded the catalog version for '$skillName'"

        $installedAt = [datetime]::MinValue
        Assert-True ([datetime]::TryParse($metadata.installedAt, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$installedAt)) "$Label recorded a round-trip installedAt for '$skillName'"
    }
}

function ConvertTo-GitBashPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if ($fullPath -match '^[A-Za-z]:') {
        return '/' + $fullPath.Substring(0, 1).ToLowerInvariant() + $fullPath.Substring(2).Replace('\', '/')
    }

    return $fullPath.Replace('\', '/')
}

function Assert-BootstrapSelection {
    param([string]$FixtureRoot, [string]$Label, [scriptblock]$InvokeInstaller)

    $selectionRepository = Join-Path $FixtureRoot "$Label-selection-repo"
    $selectionPath = Join-Path $selectionRepository 'scripts/bootstrap-skills.json'
    New-Item -ItemType Directory -Path (Split-Path -Parent $selectionPath) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repositoryRoot 'catalog.json') -Destination $selectionRepository
    $sampleName = $expectedBootstrapSkills[0]
    $sampleEntry = @($catalog | Where-Object { $_.name -ceq $sampleName })[0]
    $sampleSource = Get-SkillSourcePath -SkillName $sampleName
    $sampleDestination = Join-Path $selectionRepository $sampleEntry.path
    New-Item -ItemType Directory -Path (Split-Path -Parent $sampleDestination) -Force | Out-Null
    Copy-Item -LiteralPath $sampleSource -Destination $sampleDestination -Recurse

    $selections = @(
        @{ Name = 'single'; Content = (ConvertTo-Json -InputObject @($sampleName)); Succeeds = $true },
        @{ Name = 'duplicate'; Content = (ConvertTo-Json -InputObject @($sampleName, $sampleName)) },
        @{ Name = 'unknown'; Content = (ConvertTo-Json -InputObject @($sampleName, 'missing-bootstrap-skill')) },
        @{ Name = 'empty'; Content = '[]' },
        @{ Name = 'scalar'; Content = '"fixture-skill"' },
        @{ Name = 'null'; Content = 'null' },
        @{ Name = 'object'; Content = '{}' },
        @{ Name = 'invalid-member'; Content = '[null]' },
        @{ Name = 'nested-array'; Content = '[["fixture-skill"]]' },
        @{ Name = 'path'; Content = '["../fixture-skill"]' },
        @{ Name = 'malformed'; Content = '[' },
        @{ Name = 'missing'; Content = $null }
    )
    foreach ($selection in $selections) {
        if ($null -eq $selection.Content) { Remove-Item -LiteralPath $selectionPath }
        else { [System.IO.File]::WriteAllText($selectionPath, $selection.Content) }
        $skillsRoot = Join-Path $FixtureRoot "$Label-selection-$($selection.Name)"
        $legacyPath = New-LegacyInstall -Root $skillsRoot -Name 'sv-sync' -SourcePath 'skills/public/sv-sync'
        $result = & $InvokeInstaller $selectionRepository $skillsRoot
        if ($selection.Succeeds) {
            Assert-True ($result.ExitCode -eq 0) "$Label accepts a one-name JSON selection: $($result.Output)"
            $installedNames = @(Get-ChildItem -LiteralPath $skillsRoot -Directory | ForEach-Object Name)
            Assert-True ($installedNames.Count -eq 1 -and $installedNames[0] -ceq $sampleName) "$Label installs only the name selected in the JSON"
            Assert-True (Test-SkillContentEqual -Source $sampleSource -Target (Join-Path $skillsRoot $sampleName)) "$Label copies the selected bundle"
        }
        else {
            Assert-True ($result.ExitCode -ne 0) "$Label rejects the $($selection.Name) selection"
            Assert-True (Test-Path -LiteralPath $legacyPath) "$Label preserves legacy installs on invalid selection"
            Assert-True (@(Get-ChildItem -LiteralPath $skillsRoot -Force).Count -eq 1) "$Label writes no installs or staging files on invalid selection"
        }
    }
}

function Invoke-GitBash {
    param(
        [Parameter(Mandatory = $true)][string]$BashPath,
        [Parameter(Mandatory = $true)][string]$HomePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    # Native stderr must not terminate the test run, and HOME must only change for the child process.
    $ErrorActionPreference = 'Continue'
    $previousHome = $env:HOME
    try {
        $env:HOME = ConvertTo-GitBashPath -Path $HomePath
        $output = & $BashPath @Arguments 2>&1
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output = (@($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine)
        }
    }
    finally {
        if ([string]::IsNullOrEmpty($previousHome)) {
            Remove-Item -LiteralPath 'Env:\HOME' -ErrorAction SilentlyContinue
        }
        else {
            $env:HOME = $previousHome
        }
    }
}

$powerShellLegacySkills = Get-ScriptListValues -Path $bootstrapScript -VariableName legacySkillEntries
$shellLegacySkills = Get-ScriptListValues -Path $bootstrapShellScript -Pattern 'legacy_skill_entries=\((?<body>[^)]*)\)'

Assert-True (($powerShellLegacySkills -join ',') -ceq ($expectedLegacySkills -join ',')) 'install-global.ps1 migrates the canonical legacy skill list'
Assert-True (($shellLegacySkills -join ',') -ceq ($expectedLegacySkills -join ',')) 'install-global.sh migrates the canonical legacy skill list'

$shellScriptBytes = [System.IO.File]::ReadAllBytes($bootstrapShellScript)
Assert-True (-not ($shellScriptBytes -contains 13)) 'install-global.sh uses LF line endings so bash can run it'

$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-bootstrap-test-' + [guid]::NewGuid().ToString('N'))
$savedFixtureOwnershipRoot = $env:SKILLVAULT_OWNERSHIP_ROOT
$env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixtureRoot 'runtime-ownership'
$savedFixtureTransactionRoot = $env:SKILLVAULT_TRANSACTION_ROOT
$env:SKILLVAULT_TRANSACTION_ROOT = Join-Path $fixtureRoot 'updates'
$globalRoot = Join-Path $fixtureRoot 'global'

try {
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null

    Assert-SetupPrompt
    Assert-SetupClone -FixtureRoot $fixtureRoot
    Write-Output 'Optional setup checks passed: 30-second idle cancellation, keypress resets, explicit clone/open approval, and existing-folder preservation.'

    $registrationFixture = Join-Path $fixtureRoot 'registration.ps1'
    [System.IO.File]::WriteAllText($registrationFixture, @'
$legacySkillEntries = @(
    'legacy-a',
    # 'ignored-a',
    'legacy-b' # 'ignored-b'
)
'@)
    $parsedNames = Get-ScriptListValues -Path $registrationFixture -VariableName legacySkillEntries
    Assert-True (($parsedNames -join ',') -ceq 'legacy-a,legacy-b') 'registration parsing excludes full-line and inline comments'

    & $bootstrapScript -RepoRoot $repositoryRoot -GlobalSkillsPath $globalRoot | Out-Null
    Assert-BootstrapInstalls -SkillsRoot $globalRoot -Label 'powershell'
    Assert-True ((Get-InstallResidue -Root $globalRoot).Count -eq 0) 'a first install leaves no staging or backup residue'

    $repeatOutput = @(& $bootstrapScript -RepoRoot $repositoryRoot -GlobalSkillsPath $globalRoot)
    Assert-True (@($repeatOutput | Where-Object { $_ -like 'Already current:*' }).Count -eq $expectedBootstrapSkills.Count) 'a repeat run skips current installs without -Force'
    Assert-BootstrapInstalls -SkillsRoot $globalRoot -Label 'powershell repeat'

    $unmanagedSkillPath = New-LegacyInstall -Root $globalRoot -Name 'local-notes' -WithoutMetadata

    $legacyInstallerPath = New-LegacyInstall -Root $globalRoot -Name 'skillvault' -InstalledBy 'skillvault-bootstrap' -SourcePath 'skills/public/core/skillvault'
    New-LegacyInstall -Root $globalRoot -Name 'sv-sync' -InstalledBy 'skillvault-bootstrap' -SourcePath 'skills/public/sv-sync' -SourceRepo 'https://github.com/wzlwit/skillvault.git' | Out-Null
    New-LegacyInstall -Root $globalRoot -Name 'skillvault-sync' -InstalledBy 'skillvault' -SourcePath 'skills/public/skillvault-sync' -SourceRepo 'https://github.com/wzlwit/skillvault' | Out-Null
    New-LegacyInstall -Root $globalRoot -Name 'ai-principles' -InstalledBy 'skillvault' -SourcePath 'skills/public/core/ai-principles' -SourceRepo 'https://github.com/wzlwit/skillvault.git' | Out-Null
    New-LegacyInstall -Root $globalRoot -Name 'rule-update' -InstalledBy 'skillvault-bootstrap' -SourcePath 'skills/public/core/rule-update' -SourceRepo 'https://github.com/wzlwit/skillvault/' | Out-Null

    & $bootstrapScript -RepoRoot $repositoryRoot -GlobalSkillsPath $globalRoot | Out-Null
    Assert-True (Test-Path -LiteralPath $legacyInstallerPath) 'the renamed installer is preserved until migration is explicitly approved with -Force'
    & $bootstrapScript -RepoRoot $repositoryRoot -GlobalSkillsPath $globalRoot -Force | Out-Null
    foreach ($legacyEntry in $expectedLegacySkills) {
        $legacySkill = Split-LegacyEntry -Entry $legacyEntry
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $globalRoot $legacySkill.Name))) "a managed legacy install is removed: $($legacySkill.Name)"
    }
    Assert-True (Test-Path -LiteralPath $unmanagedSkillPath) 'an unmanaged global skill is preserved'
    Assert-BootstrapInstalls -SkillsRoot $globalRoot -Label 'powershell after legacy removal'

    New-LegacyInstall -Root $globalRoot -Name 'skillvault' -WithoutMetadata | Out-Null
    New-LegacyInstall -Root $globalRoot -Name 'sv-sync' -InstalledBy 'other-tool' -SourcePath 'skills/public/sv-sync' | Out-Null
    New-LegacyInstall -Root $globalRoot -Name 'skillvault-sync' -InstalledBy 'skillvault' -SourcePath 'skills/public/core/skillvault' | Out-Null
    New-LegacyInstall -Root $globalRoot -Name 'ai-principles' -InstalledBy 'skillvault' -SourcePath 'skills/public/core/ai-principles' -SourceRepo 'https://github.com/someone-else/skillvault.git' | Out-Null
    New-LegacyInstall -Root $globalRoot -Name 'rule-update' -WithoutMetadata | Out-Null

    & $bootstrapScript -RepoRoot $repositoryRoot -GlobalSkillsPath $globalRoot | Out-Null
    foreach ($legacyEntry in $expectedLegacySkills) {
        $legacySkill = Split-LegacyEntry -Entry $legacyEntry
        Assert-True (Test-Path -LiteralPath (Join-Path $globalRoot $legacySkill.Name)) "an unmanaged legacy install is preserved: $($legacySkill.Name)"
    }

    $pinnedMetadataPath = Join-Path (Join-Path $globalRoot $expectedBootstrapSkills[0]) '.skillvault-install.json'
    $pinnedMetadata = Get-Content -LiteralPath $pinnedMetadataPath -Raw | ConvertFrom-Json
    $pinnedMetadata.requestedVersion = 'v1.0.0'
    $pinnedMetadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $pinnedMetadataPath -Encoding utf8
    Assert-True (Test-Throws { & $bootstrapScript -RepoRoot $repositoryRoot -GlobalSkillsPath $globalRoot }) 'a pinned install is not overwritten without -Force'
    Assert-True ((Get-Content -LiteralPath $pinnedMetadataPath -Raw | ConvertFrom-Json).requestedVersion -ceq 'v1.0.0') 'a pinned install keeps its requested version'

    $modifiedTarget = Join-Path $globalRoot $expectedBootstrapSkills[0]
    'local edit' | Set-Content -LiteralPath (Join-Path $modifiedTarget 'marker.txt') -Encoding utf8
    $pendingTarget = $null
    if ($expectedBootstrapSkills.Count -gt 1) {
        $pendingTarget = Join-Path $globalRoot $expectedBootstrapSkills[-1]
        Remove-Item -LiteralPath $pendingTarget -Recurse -Force
    }
    Assert-True (Test-Throws { & $bootstrapScript -RepoRoot $repositoryRoot -GlobalSkillsPath $globalRoot }) 'a locally modified install is not overwritten without -Force'
    Assert-True (Test-Path -LiteralPath (Join-Path $modifiedTarget 'marker.txt')) 'a failed preflight does not delete an existing install'
    if ($pendingTarget) {
        Assert-True (-not (Test-Path -LiteralPath $pendingTarget)) 'a failed preflight installs nothing, including skills that were ready to install'
    }
    Assert-True ((Get-InstallResidue -Root $globalRoot).Count -eq 0) 'a failed preflight leaves no staging or backup residue'

    & $bootstrapScript -RepoRoot $repositoryRoot -GlobalSkillsPath $globalRoot -Force | Out-Null
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $modifiedTarget 'marker.txt'))) '-Force replaces a locally modified install'
    Assert-True ((Get-Content -LiteralPath $pinnedMetadataPath -Raw | ConvertFrom-Json).requestedVersion -ceq 'latest') '-Force replaces a pinned install'
    Assert-True (Test-Path -LiteralPath $unmanagedSkillPath) '-Force preserves an unmanaged global skill'
    Assert-BootstrapInstalls -SkillsRoot $globalRoot -Label 'powershell -Force'
    Assert-True ((Get-InstallResidue -Root $globalRoot).Count -eq 0) 'a forced reinstall leaves no staging or backup residue'

    Assert-True (Test-Throws { & $bootstrapScript -RepoRoot (Join-Path $fixtureRoot 'missing-checkout') -GlobalSkillsPath $globalRoot }) 'a missing catalog fails before any writes'

    Assert-BootstrapSelection -FixtureRoot $fixtureRoot -Label 'powershell' -InvokeInstaller {
        param($SelectionRepository, $SkillsRoot)
        try {
            $output = @(& $bootstrapScript -RepoRoot $SelectionRepository -GlobalSkillsPath $SkillsRoot)
            [pscustomobject]@{ ExitCode = 0; Output = ($output -join "`n") }
        }
        catch { [pscustomobject]@{ ExitCode = 1; Output = $_.Exception.Message } }
    }

    Write-Output 'PowerShell bootstrap checks passed: catalog-backed metadata, staged replacement, legacy migration, preservation, and batched preflight.'

    $readme = Get-Content -LiteralPath (Join-Path $repositoryRoot 'README.md') -Raw
    $downloadCommand = [regex]::Match($readme, 'One-line download \(Windows PowerShell 5\.1\+\):\r?\n\r?\n```powershell\r?\n(?<command>[^\r\n]+)\r?\n```')
    Assert-True $downloadCommand.Success 'README provides a single-line PowerShell download command'
    $launcherRevision = '1234567890123456789012345678901234567890'
    $launcherFixture = Join-Path $fixtureRoot 'launcher-fixture.ps1'
    [System.IO.File]::WriteAllText($launcherFixture, @'
param([string]$Revision)
Write-Output "Launched revision: $Revision"
'@)
    $downloadPaths = New-Object 'System.Collections.Generic.List[string]'
    function Invoke-RestMethod {
        param([string]$Uri, $Headers)
        Assert-True ($Uri -ceq 'https://api.github.com/repos/wzlwit/skillvault/commits/main') 'the one-line command resolves the canonical main revision'
        return [pscustomobject]@{ sha = $launcherRevision }
    }
    function Invoke-WebRequest {
        param([string]$Uri, [string]$OutFile, [switch]$UseBasicParsing)
        Assert-True ($Uri -ceq "https://raw.githubusercontent.com/wzlwit/skillvault/$launcherRevision/scripts/setup.ps1") 'the one-line command downloads setup from the resolved revision'
        $downloadPaths.Add($OutFile)
        Copy-Item -LiteralPath $launcherFixture -Destination $OutFile
    }
    try { $launcherOutput = @(& ([scriptblock]::Create($downloadCommand.Groups['command'].Value))) }
    finally { Remove-Item -LiteralPath Function:\Invoke-RestMethod, Function:\Invoke-WebRequest }
    Assert-True ("Launched revision: $launcherRevision" -cin $launcherOutput) 'the one-line command runs setup using the same resolved revision'
    Assert-True ($downloadPaths.Count -eq 1) 'the one-line command downloads only the setup script'
    Assert-True (-not (Test-Path -LiteralPath $downloadPaths[0])) 'the one-line command cleans up its downloaded script'
    Write-Output 'One-line download checks passed with a local launcher fixture; no network request or live installation was made.'

    $originalCloneFunction = (Get-Command Request-SetupClone).ScriptBlock
    $originalInteractiveFunction = (Get-Command Test-SetupInteractive).ScriptBlock
    $setupPrompts = New-Object 'System.Collections.Generic.List[string]'
    function Test-SetupInteractive { return $true }
    function Request-SetupClone {
        Assert-BootstrapInstalls -SkillsRoot $onlineRoot -Label 'before optional prompt'
        foreach ($target in $setupTargets) {
            Assert-True (-not (Test-Path -LiteralPath $target)) 'temporary downloads are removed before optional prompts'
        }
        $setupPrompts.Add('clone')
    }

    $setupRevision = '1234567890123456789012345678901234567890'
    $setupTreeRevision = 'abcdefabcdefabcdefabcdefabcdefabcdefabcd'
    $setupFiles = @('catalog.json', 'scripts/bootstrap-skills.json', 'scripts/install-global.ps1', 'skills/core/skillvault-installation/scripts/skill-files.ps1', 'README.md')
    foreach ($name in $expectedBootstrapSkills) {
        $sourcePath = Get-SkillSourcePath -SkillName $name
        foreach ($file in @(Get-SkillFiles -SkillPath $sourcePath)) {
            $setupFiles += $sourcePath.Substring($repositoryRoot.Length + 1).Replace('\', '/') + '/' + $file.RelativePath
        }
    }
    $setupTree = [pscustomobject]@{
        sha = $setupTreeRevision
        truncated = $false
        tree = @($setupFiles | Select-Object -Unique | ForEach-Object { [pscustomobject]@{ path = $_; mode = '100644'; type = 'blob' } })
    }
    $setupDownloads = New-Object 'System.Collections.Generic.List[string]'
    $setupTargets = New-Object 'System.Collections.Generic.List[string]'
    $setupRequests = New-Object 'System.Collections.Generic.List[string]'
    $failedDownloadPath = $null
    function Invoke-RestMethod {
        param([string]$Uri, $Headers)
        $setupRequests.Add($Uri)
        if ($Uri -ceq "https://api.github.com/repos/wzlwit/skillvault/commits/$setupRevision") {
            return [pscustomobject]@{ sha = $setupRevision; commit = @{ tree = @{ sha = $setupTreeRevision } } }
        }
        Assert-True ($Uri -ceq "https://api.github.com/repos/wzlwit/skillvault/git/trees/${setupTreeRevision}?recursive=1") 'setup enumerates the resolved tree'
        return $setupTree
    }
    function Invoke-WebRequest {
        param([string]$Uri, [string]$OutFile, [switch]$UseBasicParsing, $ErrorAction)
        $prefix = "https://raw.githubusercontent.com/wzlwit/skillvault/$setupRevision/"
        Assert-True ($Uri.StartsWith($prefix, [System.StringComparison]::Ordinal)) 'setup pins every resource to the resolved revision'
        $relativePath = [uri]::UnescapeDataString($Uri.Substring($prefix.Length))
        $setupDownloads.Add($relativePath)
        $setupTargets.Add($OutFile)
        if ($relativePath -ceq $failedDownloadPath) { throw 'Injected download failure.' }
        Copy-Item -LiteralPath (Join-Path $repositoryRoot $relativePath) -Destination $OutFile
    }
    try {
        $onlineRoot = Join-Path $fixtureRoot 'online-skills'
        Invoke-SkillVaultSetup -Revision $setupRevision -GlobalSkillsPath $onlineRoot -NonInteractive | Out-Null
        Assert-BootstrapInstalls -SkillsRoot $onlineRoot -Label 'selective online setup'
        Assert-True ($setupDownloads.Count -eq $setupTree.tree.Count - 1) 'online setup downloads only required resources, without the repository README'
        Assert-True ('README.md' -cnotin $setupDownloads) 'online setup skips unselected repository files'
        Assert-True (@($setupDownloads | Select-Object -Unique).Count -eq $setupDownloads.Count) 'shared helper downloads are deduplicated'
        Assert-True ($setupRequests.Count -eq 2) 'online setup uses one revision lookup and one tree lookup'
        Assert-True ($setupPrompts.Count -eq 0) 'explicit noninteractive setup never asks to clone'
        foreach ($target in $setupTargets) {
            Assert-True (-not (Test-Path -LiteralPath $target)) 'online setup removes all temporary downloads after installation'
        }

        Invoke-SkillVaultSetup -Revision $setupRevision -GlobalSkillsPath $onlineRoot | Out-Null
        Assert-True ($setupPrompts.Count -eq 1) 'interactive setup offers cloning only after successful installation'

        $failedOnlineRoot = Join-Path $fixtureRoot 'failed-online-skills'
        $preservedLegacy = New-LegacyInstall -Root $failedOnlineRoot -Name 'sv-sync' -SourcePath 'skills/public/sv-sync'
        $setupTree.truncated = $true
        $downloadsBeforeFailure = $setupDownloads.Count
        Assert-True (Test-Throws { Invoke-SkillVaultSetup -Revision $setupRevision -GlobalSkillsPath $failedOnlineRoot }) 'an incomplete remote tree blocks installation'
        Assert-True ($setupDownloads.Count -eq $downloadsBeforeFailure) 'an incomplete tree downloads no payload files'
        $setupTree.truncated = $false

        $installerEntry = @($setupTree.tree | Where-Object path -CEQ 'scripts/install-global.ps1')[0]
        $installerEntry.mode = '120000'
        Assert-True (Test-Throws { Invoke-SkillVaultSetup -Revision $setupRevision -GlobalSkillsPath $failedOnlineRoot }) 'a symlink resource is not downloaded or executed'
        $installerEntry.mode = '100644'

        $failedDownloadPath = 'scripts/install-global.ps1'
        Assert-True (Test-Throws { Invoke-SkillVaultSetup -Revision $setupRevision -GlobalSkillsPath $failedOnlineRoot }) 'a download failure blocks installation'
        Assert-True ($setupPrompts.Count -eq 1) 'failed setup never offers a clone'
        Assert-True (Test-Path -LiteralPath $preservedLegacy) 'failed setup preserves existing legacy installations'
        Assert-True (@(Get-ChildItem -LiteralPath $failedOnlineRoot -Force).Count -eq 1) 'failed setup installs nothing'
        foreach ($target in $setupTargets) {
            Assert-True (-not (Test-Path -LiteralPath $target)) 'online setup cleans temporary downloads after failures as well as success'
        }
    }
    finally {
        Remove-Item -LiteralPath Function:\Invoke-RestMethod, Function:\Invoke-WebRequest
        Set-Item -LiteralPath Function:\Request-SetupClone -Value $originalCloneFunction
        Set-Item -LiteralPath Function:\Test-SetupInteractive -Value $originalInteractiveFunction
    }
    Write-Output 'Selective online setup checks passed with local resource fixtures; no network or live installation was used.'

    $gitBashPath = 'C:\Program Files\Git\bin\bash.exe'
    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue

    if (-not (Test-Path -LiteralPath $gitBashPath -PathType Leaf)) {
        Write-Output "Skipped bash bootstrap checks: Git Bash was not found at $gitBashPath."
    }
    elseif ($null -eq $nodeCommand) {
        Write-Output 'Skipped bash bootstrap checks: node was not found on PATH.'
    }
    else {
        $bashHome = Join-Path $fixtureRoot 'bash-home'
        New-Item -ItemType Directory -Path $bashHome -Force | Out-Null
        $bashSkillsRoot = Join-Path $bashHome '.copilot\skills'
        $bashScriptPath = ConvertTo-GitBashPath -Path $bootstrapShellScript

        $syntaxCheck = Invoke-GitBash -BashPath $gitBashPath -HomePath $bashHome -Arguments @('-n', $bashScriptPath)
        Assert-True ($syntaxCheck.ExitCode -eq 0) "bash -n accepts install-global.sh: $($syntaxCheck.Output)"

        $bashInstall = Invoke-GitBash -BashPath $gitBashPath -HomePath $bashHome -Arguments @($bashScriptPath)
        Assert-True ($bashInstall.ExitCode -eq 0) "the bash bootstrap installs into an isolated HOME: $($bashInstall.Output)"
        Assert-BootstrapInstalls -SkillsRoot $bashSkillsRoot -Label 'bash'
        Assert-True ((Get-InstallResidue -Root $bashSkillsRoot).Count -eq 0) 'the bash bootstrap leaves no staging or backup residue'

        $bashRepeat = Invoke-GitBash -BashPath $gitBashPath -HomePath $bashHome -Arguments @($bashScriptPath)
        Assert-True ($bashRepeat.ExitCode -eq 0) "a repeat bash run succeeds: $($bashRepeat.Output)"
        Assert-True ($bashRepeat.Output -match 'Already current:') 'a repeat bash run skips current installs without --force'

        $bashLegacyInstallerPath = New-LegacyInstall -Root $bashSkillsRoot -Name 'skillvault' -InstalledBy 'skillvault' -SourcePath 'skills/public/core/skillvault'
        New-LegacyInstall -Root $bashSkillsRoot -Name 'sv-sync' -InstalledBy 'skillvault-bootstrap' -SourcePath 'skills/public/sv-sync' -SourceRepo 'https://github.com/wzlwit/skillvault.git' | Out-Null
        New-LegacyInstall -Root $bashSkillsRoot -Name 'skillvault-sync' -InstalledBy 'skillvault' -SourcePath 'skills/public/skillvault-sync' -SourceRepo 'https://github.com/wzlwit/skillvault' | Out-Null
        $bashUnmanagedLegacy = New-LegacyInstall -Root $bashSkillsRoot -Name 'ai-principles' -InstalledBy 'other-tool' -SourcePath 'skills/public/core/ai-principles'
        $bashUnmanagedSkill = New-LegacyInstall -Root $bashSkillsRoot -Name 'local-notes' -WithoutMetadata

        $bashLegacy = Invoke-GitBash -BashPath $gitBashPath -HomePath $bashHome -Arguments @($bashScriptPath)
        Assert-True ($bashLegacy.ExitCode -eq 0) "the bash bootstrap migrates legacy installs: $($bashLegacy.Output)"
        Assert-True (Test-Path -LiteralPath $bashLegacyInstallerPath) 'bash preserves the renamed installer without --force'
        $bashRename = Invoke-GitBash -BashPath $gitBashPath -HomePath $bashHome -Arguments @($bashScriptPath, '--force')
        Assert-True ($bashRename.ExitCode -eq 0) "the bash bootstrap completes the approved rename: $($bashRename.Output)"
        Assert-True (-not (Test-Path -LiteralPath $bashLegacyInstallerPath)) 'bash removes the managed old installer after installing the new name'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $bashSkillsRoot 'sv-sync'))) 'the bash bootstrap removes a managed legacy install written by the bootstrap'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $bashSkillsRoot 'skillvault-sync'))) 'the bash bootstrap removes a managed legacy install written by skillvault'
        Assert-True (Test-Path -LiteralPath $bashUnmanagedLegacy) 'the bash bootstrap preserves an unmanaged legacy install'
        Assert-True (Test-Path -LiteralPath $bashUnmanagedSkill) 'the bash bootstrap preserves an unmanaged global skill'

        $bashModifiedTarget = Join-Path $bashSkillsRoot $expectedBootstrapSkills[0]
        'local edit' | Set-Content -LiteralPath (Join-Path $bashModifiedTarget 'marker.txt') -Encoding utf8
        $bashBlocked = Invoke-GitBash -BashPath $gitBashPath -HomePath $bashHome -Arguments @($bashScriptPath)
        Assert-True ($bashBlocked.ExitCode -ne 0) 'the bash bootstrap refuses to overwrite a locally modified install without --force'
        Assert-True (Test-Path -LiteralPath (Join-Path $bashModifiedTarget 'marker.txt')) 'a failed bash preflight does not delete an existing install'

        $bashForced = Invoke-GitBash -BashPath $gitBashPath -HomePath $bashHome -Arguments @($bashScriptPath, '--force')
        Assert-True ($bashForced.ExitCode -eq 0) "the bash bootstrap replaces a modified install with --force: $($bashForced.Output)"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $bashModifiedTarget 'marker.txt'))) '--force replaces a locally modified install'
        Assert-BootstrapInstalls -SkillsRoot $bashSkillsRoot -Label 'bash --force'
        Assert-True ((Get-InstallResidue -Root $bashSkillsRoot).Count -eq 0) 'a forced bash run leaves no staging or backup residue'

        Assert-BootstrapSelection -FixtureRoot $fixtureRoot -Label 'bash' -InvokeInstaller {
            param($SelectionRepository, $SkillsRoot)
            Invoke-GitBash -BashPath $gitBashPath -HomePath $bashHome -Arguments @(
                $bashScriptPath, '--repo-root', (ConvertTo-GitBashPath -Path $SelectionRepository),
                '--skills-dir', (ConvertTo-GitBashPath -Path $SkillsRoot)
            )
        }

        Write-Output 'Bash bootstrap checks passed: syntax, isolated HOME install, repeat skip, legacy migration, preservation, and --force replacement.'
    }
}
finally {
    $env:SKILLVAULT_OWNERSHIP_ROOT = $savedFixtureOwnershipRoot
    $env:SKILLVAULT_TRANSACTION_ROOT = $savedFixtureTransactionRoot
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
