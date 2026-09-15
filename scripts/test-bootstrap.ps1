$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$bootstrapScript = Join-Path $PSScriptRoot 'install-global.ps1'
$bootstrapShellScript = Join-Path $PSScriptRoot 'install-global.sh'
. (Join-Path $repositoryRoot 'skills\public\core\skillvault-install\scripts\skill-files.ps1')

$catalog = Get-Content -LiteralPath (Join-Path $repositoryRoot 'catalog.json') -Raw | ConvertFrom-Json

$expectedBootstrapSkills = @(
    'skillvault-install',
    'skillvault-evaluate',
    'skillvault-fresh',
    'skillvault-list',
    'skillvault-remove',
    'skillvault-search',
    'skillvault-uninstall',
    'skillvault-upsert',
    'rules',
    'rules-core',
    'schedule-manager'
)

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

function Get-ScriptListValues {
    param([string]$Path, [string]$Pattern)

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

$powerShellSkillNames = Get-ScriptListValues -Path $bootstrapScript -Pattern '\$bootstrapSkillNames\s*=\s*@\((?<body>[^)]*)\)'
$shellSkillNames = Get-ScriptListValues -Path $bootstrapShellScript -Pattern 'bootstrap_skill_names=\((?<body>[^)]*)\)'
$powerShellLegacySkills = Get-ScriptListValues -Path $bootstrapScript -Pattern '\$legacySkillEntries\s*=\s*@\((?<body>[^)]*)\)'
$shellLegacySkills = Get-ScriptListValues -Path $bootstrapShellScript -Pattern 'legacy_skill_entries=\((?<body>[^)]*)\)'

Assert-True (($powerShellSkillNames -join ',') -ceq ($expectedBootstrapSkills -join ',')) 'install-global.ps1 installs the canonical bootstrap skill list'
Assert-True (($shellSkillNames -join ',') -ceq ($expectedBootstrapSkills -join ',')) 'install-global.sh installs the canonical bootstrap skill list'
Assert-True (($powerShellLegacySkills -join ',') -ceq ($expectedLegacySkills -join ',')) 'install-global.ps1 migrates the canonical legacy skill list'
Assert-True (($shellLegacySkills -join ',') -ceq ($expectedLegacySkills -join ',')) 'install-global.sh migrates the canonical legacy skill list'

$shellScriptBytes = [System.IO.File]::ReadAllBytes($bootstrapShellScript)
Assert-True (-not ($shellScriptBytes -contains 13)) 'install-global.sh uses LF line endings so bash can run it'

$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-bootstrap-test-' + [guid]::NewGuid().ToString('N'))
$globalRoot = Join-Path $fixtureRoot 'global'

try {
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null

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

    $pinnedMetadataPath = Join-Path $globalRoot 'rules-core\.skillvault-install.json'
    $pinnedMetadata = Get-Content -LiteralPath $pinnedMetadataPath -Raw | ConvertFrom-Json
    $pinnedMetadata.requestedVersion = 'v1.0.0'
    $pinnedMetadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $pinnedMetadataPath -Encoding utf8
    Assert-True (Test-Throws { & $bootstrapScript -RepoRoot $repositoryRoot -GlobalSkillsPath $globalRoot }) 'a pinned install is not overwritten without -Force'
    Assert-True ((Get-Content -LiteralPath $pinnedMetadataPath -Raw | ConvertFrom-Json).requestedVersion -ceq 'v1.0.0') 'a pinned install keeps its requested version'

    $modifiedTarget = Join-Path $globalRoot 'rules'
    'local edit' | Set-Content -LiteralPath (Join-Path $modifiedTarget 'marker.txt') -Encoding utf8
    Remove-Item -LiteralPath (Join-Path $globalRoot 'skillvault-search') -Recurse -Force
    Assert-True (Test-Throws { & $bootstrapScript -RepoRoot $repositoryRoot -GlobalSkillsPath $globalRoot }) 'a locally modified install is not overwritten without -Force'
    Assert-True (Test-Path -LiteralPath (Join-Path $modifiedTarget 'marker.txt')) 'a failed preflight does not delete an existing install'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $globalRoot 'skillvault-search'))) 'a failed preflight installs nothing, including skills that were ready to install'
    Assert-True ((Get-InstallResidue -Root $globalRoot).Count -eq 0) 'a failed preflight leaves no staging or backup residue'

    & $bootstrapScript -RepoRoot $repositoryRoot -GlobalSkillsPath $globalRoot -Force | Out-Null
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $modifiedTarget 'marker.txt'))) '-Force replaces a locally modified install'
    Assert-True ((Get-Content -LiteralPath $pinnedMetadataPath -Raw | ConvertFrom-Json).requestedVersion -ceq 'latest') '-Force replaces a pinned install'
    Assert-True (Test-Path -LiteralPath $unmanagedSkillPath) '-Force preserves an unmanaged global skill'
    Assert-BootstrapInstalls -SkillsRoot $globalRoot -Label 'powershell -Force'
    Assert-True ((Get-InstallResidue -Root $globalRoot).Count -eq 0) 'a forced reinstall leaves no staging or backup residue'

    Assert-True (Test-Throws { & $bootstrapScript -RepoRoot (Join-Path $fixtureRoot 'missing-checkout') -GlobalSkillsPath $globalRoot }) 'a missing catalog fails before any writes'

    Write-Output 'PowerShell bootstrap checks passed: catalog-backed metadata, staged replacement, legacy migration, preservation, and batched preflight.'

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

        $bashModifiedTarget = Join-Path $bashSkillsRoot 'rules'
        'local edit' | Set-Content -LiteralPath (Join-Path $bashModifiedTarget 'marker.txt') -Encoding utf8
        $bashBlocked = Invoke-GitBash -BashPath $gitBashPath -HomePath $bashHome -Arguments @($bashScriptPath)
        Assert-True ($bashBlocked.ExitCode -ne 0) 'the bash bootstrap refuses to overwrite a locally modified install without --force'
        Assert-True (Test-Path -LiteralPath (Join-Path $bashModifiedTarget 'marker.txt')) 'a failed bash preflight does not delete an existing install'

        $bashForced = Invoke-GitBash -BashPath $gitBashPath -HomePath $bashHome -Arguments @($bashScriptPath, '--force')
        Assert-True ($bashForced.ExitCode -eq 0) "the bash bootstrap replaces a modified install with --force: $($bashForced.Output)"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $bashModifiedTarget 'marker.txt'))) '--force replaces a locally modified install'
        Assert-BootstrapInstalls -SkillsRoot $bashSkillsRoot -Label 'bash --force'
        Assert-True ((Get-InstallResidue -Root $bashSkillsRoot).Count -eq 0) 'a forced bash run leaves no staging or backup residue'

        Write-Output 'Bash bootstrap checks passed: syntax, isolated HOME install, repeat skip, legacy migration, preservation, and --force replacement.'
    }
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
