param(
    [switch]$Uninstall,
    [string]$Selector,
    [string]$ProjectPath = (Get-Location).Path,
    [ValidateSet('all', 'global', 'project', 'session')]
    [string]$Scope = 'all',
    [switch]$Force,
    [string]$GlobalSkillsPath = (Join-Path $HOME '.copilot/skills')
)

$ErrorActionPreference = 'Stop'

function Get-SkillVaultInstallMetadata {
    param([string]$SkillPath)

    $metadataPath = Join-Path $SkillPath '.skillvault-install.json'
    if (Test-Path $metadataPath) {
        return Get-Content $metadataPath -Raw | ConvertFrom-Json
    }

    return $null
}

function Get-SkillEntry {
    param(
        [string]$Scope,
        [string]$SkillPath,
        [string]$ProjectName = ''
    )

    $manifestPath = Join-Path $SkillPath 'skill.json'
    $manifest = $null
    if (Test-Path $manifestPath) {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    }

    $metadata = Get-SkillVaultInstallMetadata $SkillPath

    [pscustomobject]@{
        Scope = if ($ProjectName) { $ProjectName } else { $Scope }
        ScopeType = $Scope
        Project = $ProjectName
        Name = if ($manifest) { $manifest.name } else { Split-Path -Leaf $SkillPath }
        Version = if ($manifest) { $manifest.version } else { '' }
        RequestedVersion = if ($metadata) { $metadata.requestedVersion } else { '' }
        Managed = if ($metadata -and $metadata.installedBy -in @('skillvault', 'skillvault-bootstrap')) { 'yes' } else { 'no' }
        SourcePath = if ($metadata) { $metadata.sourcePath } else { '' }
        InstalledAt = if ($metadata) { $metadata.installedAt } else { '' }
        Path = $SkillPath
    }
}

function Get-ProjectSkillRoots {
    $candidateParents = @(
        (Get-Location).Path,
        (Split-Path -Parent (Get-Location).Path),
        (Join-Path $HOME 'source'),
        (Join-Path $HOME 'repos'),
        'C:\repos',
        'C:\ghe'
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    $roots = New-Object 'System.Collections.Generic.List[string]'
    $currentProjectRoot = Join-Path $ProjectPath '.github\skills'
    if (Test-Path $currentProjectRoot) { [void]$roots.Add((Resolve-Path $currentProjectRoot).Path) }

    foreach ($parent in $candidateParents) {
        Get-ChildItem -Path $parent -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $skillRoot = Join-Path $_.FullName '.github\skills'
            if (Test-Path $skillRoot) {
                $resolved = (Resolve-Path $skillRoot).Path
                if (-not $roots.Contains($resolved)) { [void]$roots.Add($resolved) }
            }
        }
    }

    $roots
}

function Get-SessionSkillRoots {
    $candidateRoots = @(
        (Join-Path $HOME '.copilot\skills\session'),
        (Join-Path $HOME '.copilot\session\skills'),
        (Join-Path $HOME '.copilot\skills-session')
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    foreach ($candidateRoot in $candidateRoots) {
        (Resolve-Path $candidateRoot).Path
    }
}

function Get-InstalledSkills {
    $roots = New-Object 'System.Collections.Generic.List[object]'

    if ($Scope -in @('all', 'global')) {
        [void]$roots.Add([pscustomobject]@{ Scope = 'global'; Path = $GlobalSkillsPath })
    }

    if ($Scope -in @('all', 'project')) {
        foreach ($projectSkillRoot in Get-ProjectSkillRoots) {
            [void]$roots.Add([pscustomobject]@{ Scope = 'project'; Path = $projectSkillRoot })
        }
    }

    if ($Scope -eq 'session') {
        foreach ($sessionSkillRoot in Get-SessionSkillRoots) {
            [void]$roots.Add([pscustomobject]@{ Scope = 'session'; Path = $sessionSkillRoot })
        }
    }

    $entries = foreach ($root in $roots) {
        if (-not (Test-Path $root.Path)) { continue }
        Get-ChildItem -Path $root.Path -Directory | ForEach-Object {
            if ($_.Name -like '.skillvault-stage-*' -or $_.Name -like '.skillvault-backup-*') { return }
            if ($root.Scope -eq 'global' -and $_.Name -eq 'session') { return }
            $projectName = ''
            if ($root.Scope -eq 'project') {
                $projectName = Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent $root.Path))
            }
            Get-SkillEntry -Scope $root.Scope -SkillPath $_.FullName -ProjectName $projectName
        }
    }

    $index = 1
    $entries |
        Where-Object { $null -ne $_ } |
        Sort-Object Scope, Name, Path |
        ForEach-Object {
            $_ | Add-Member -NotePropertyName Index -NotePropertyValue $index -PassThru
            $index++
        }
}

function Resolve-Selector {
    param(
        [object[]]$Entries,
        [string]$SelectorText
    )

    if ([string]::IsNullOrWhiteSpace($SelectorText)) {
        throw 'Selector is required for uninstall. Run list first, then pass an index, range, list, or keyword.'
    }

    $selectedIndexes = New-Object 'System.Collections.Generic.HashSet[int]'
    $keywordTokens = New-Object 'System.Collections.Generic.List[string]'

    foreach ($token in ($SelectorText -split ',')) {
        $trimmed = $token.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }

        if ($trimmed -match '^\d+$') {
            [void]$selectedIndexes.Add([int]$trimmed)
            continue
        }

        if ($trimmed -match '^(\d+)-(\d+)$') {
            $start = [int]$Matches[1]
            $end = [int]$Matches[2]
            if ($start -gt $end) { throw "Invalid range: $trimmed" }
            for ($current = $start; $current -le $end; $current++) {
                [void]$selectedIndexes.Add($current)
            }
            continue
        }

        [void]$keywordTokens.Add($trimmed)
    }

    $matchedEntries = @($Entries | Where-Object { $selectedIndexes.Contains([int]$_.Index) })

    foreach ($keyword in $keywordTokens) {
        $escaped = [regex]::Escape($keyword)
        $matchedEntries += @($Entries | Where-Object {
            $_.Name -match $escaped -or $_.SourcePath -match $escaped -or $_.Path -match $escaped
        })
    }

    $matchedEntries | Sort-Object Index -Unique
}

function Write-SkillTable {
    param([object[]]$Entries)

    if (-not $Entries -or $Entries.Count -eq 0) {
        Write-Output 'No installed skills found.'
        return
    }

    $Entries |
        Select-Object Index, Scope, Name, Version, RequestedVersion, Managed, Path |
        Format-Table -AutoSize | Out-String -Width 240 | Write-Output
}

$entries = @(Get-InstalledSkills)

if (-not $Uninstall) {
    Write-SkillTable $entries
    return
}

$matchedEntries = @(Resolve-Selector -Entries $entries -SelectorText $Selector)
if ($matchedEntries.Count -eq 0) {
    Write-Output "No installed skills matched selector: $Selector"
    return
}

Write-Output 'Selected skills:'
Write-SkillTable $matchedEntries

if (-not $Force) {
    Write-Output 'Re-run with -Force after confirming the selected indexes should be uninstalled.'
    return
}

$allowedRoots = @($entries | ForEach-Object { [System.IO.Path]::GetFullPath((Split-Path -Parent $_.Path)) } | Select-Object -Unique)

foreach ($match in $matchedEntries) {
    $fullPath = [System.IO.Path]::GetFullPath($match.Path)
    $parentPath = [System.IO.Path]::GetFullPath((Split-Path -Parent $fullPath))
    $isAllowed = $parentPath -in $allowedRoots

    if (-not $isAllowed) {
        Write-Output "Skipped outside allowed roots: $fullPath"
        continue
    }

    $item = Get-Item -LiteralPath $fullPath -Force
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        Write-Output "Skipped linked skill folder: $fullPath"
        continue
    }

    Remove-Item -LiteralPath $fullPath -Recurse -Force
    Write-Output "Uninstalled: $($match.Scope) $($match.Name) -> $fullPath"
}