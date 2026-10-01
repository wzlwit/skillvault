param(
    [switch]$Uninstall,
    [switch]$Check,
    [string]$Selector,
    [string]$ProjectPath = (Get-Location).Path,
    [ValidateSet('all', 'global', 'project', 'session')]
    [string]$Scope = 'all',
    [switch]$Force,
    [switch]$ConfirmStopped,
    [string]$GlobalSkillsPath = (Join-Path $HOME '.copilot/skills'),
    [string]$RepoPath,
    [string[]]$OtherSkillRoots = @((Join-Path $HOME '.agents/skills'), (Join-Path $HOME '.claude/skills'))
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

function Get-SkillHeader {
    param([string]$SkillPath)

    $skillFile = Join-Path $SkillPath 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { return $null }
    $lines = [System.IO.File]::ReadAllLines($skillFile)
    $name = $null
    $hasDescription = $false
    if ($lines.Count -gt 0 -and $lines[0].Trim() -ceq '---') {
        for ($index = 1; $index -lt $lines.Count -and $lines[$index].Trim() -cne '---'; $index++) {
            if (-not $name -and $lines[$index] -cmatch '^name:\s*(.*?)\s*$') { $name = $Matches[1].Trim([char[]]@('"', "'")) }
            if ($lines[$index] -cmatch '^description:\s*(\S.*)?$') {
                $hasDescription = [bool]$Matches[1] -or ($index + 1 -lt $lines.Count -and $lines[$index + 1] -match '^\s+\S')
            }
        }
    }
    [pscustomobject]@{ Name = $name; HasDescription = $hasDescription }
}

function New-SkillCleanCopy {
    param([string]$Path, [string]$Place, [string]$Group, $Index)

    $metadata = Get-SkillVaultInstallMetadata $Path
    $header = Get-SkillHeader $Path
    $managed = [bool]($metadata -and $metadata.installedBy -in @('skillvault', 'skillvault-bootstrap'))
    [pscustomobject]@{
        Index = $Index
        Place = $Place
        Group = $Group
        Path = $Path
        Folder = Split-Path -Leaf $Path
        Name = if ($header -and $header.Name) { $header.Name } else { Split-Path -Leaf $Path }
        Managed = $managed
        Original = $managed -and (Test-SkillInstalledOriginal -SkillPath $Path)
        Pinned = $managed -and [string]$metadata.requestedVersion -notin @('', 'latest')
        Loadable = [bool]($header -and $header.Name -and $header.HasDescription)
    }
}

function Get-SkillCleanCopies {
    param([object[]]$Entries, [string[]]$OtherRoots)

    foreach ($entry in $Entries) {
        # A project's skills load together with the global ones, never with another project's.
        $group = if ($entry.ScopeType -eq 'project') { Split-Path -Parent $entry.Path } else { $entry.ScopeType }
        New-SkillCleanCopy -Path $entry.Path -Place $entry.Scope -Group $group -Index $entry.Index
    }
    $globalRoot = [System.IO.Path]::GetFullPath($GlobalSkillsPath)
    foreach ($root in $OtherRoots) {
        if (-not $root -or -not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        if ([System.IO.Path]::GetFullPath($root) -ieq $globalRoot) { continue }
        Get-ChildItem -LiteralPath $root -Directory | Where-Object { $_.Name -notlike '.*' } | ForEach-Object {
            New-SkillCleanCopy -Path $_.FullName -Place $root -Group 'global' -Index $null
        }
    }
}

function Get-SkillCleanCatalog {
    param([string]$ProjectPath, [string]$RepoPath)

    $options = @{ ProjectPath = $ProjectPath; Mode = 'Install' }
    if ($RepoPath) { $options.RepoPath = $RepoPath }
    $source = & (Join-Path $PSScriptRoot 'resolve-source-repo.ps1') @options
    if ($source.Status -ne 'Resolved') { throw 'A verified SkillVault source is required for clean.' }
    $descriptions = @{}
    $renamed = @{}
    foreach ($entry in @(Get-Content -LiteralPath $source.CatalogPath -Raw | ConvertFrom-Json)) {
        $descriptions[$entry.name] = [string]$entry.description
        $manifest = Get-Content -LiteralPath (Join-Path $source.RepoRoot "$($entry.path)/skill.json") -Raw | ConvertFrom-Json
        $original = if ($manifest.upstream.path) { Split-Path -Leaf ([string]$manifest.upstream.path) } else { '' }
        if ([string]$manifest.install.strategy -ceq 'adapted' -and $original -notin @('', '.') -and $original -cne $entry.name) { $renamed[$original] = $entry.name }
    }
    [pscustomobject]@{ RepoRoot = $source.RepoRoot; Descriptions = $descriptions; RenamedOriginals = $renamed }
}

function Test-SkillCleanTogether {
    param([string[]]$GroupsA, [string[]]$GroupsB)

    ($GroupsA -contains 'global') -or ($GroupsB -contains 'global') -or @($GroupsA | Where-Object { $GroupsB -contains $_ }).Count -gt 0
}

function Get-SkillCleanFindings {
    param(
        [object[]]$Copies,
        [hashtable]$Descriptions,
        [hashtable]$RenamedOriginals,
        [hashtable]$FormerNames
    )

    $findings = [Collections.Generic.List[object]]::new()
    $removeAction = {
        param($copy)
        if (-not $copy.Managed -or $null -eq $copy.Index) { 'report' } elseif ($copy.Pinned) { 'decide' } else { 'uninstall' }
    }
    $describe = {
        param($copy, [string]$Action)
        [pscustomobject]@{ index = $copy.Index; place = $copy.Place; path = $copy.Path; managed = $copy.Managed; original = $copy.Original; pinned = $copy.Pinned; action = $Action }
    }
    $unique = {
        param([object[]]$Items)
        $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        @($Items | Where-Object { $paths.Add($_.Path) })
    }

    foreach ($group in @($Copies | Group-Object { $_.Name.ToLowerInvariant() })) {
        $globalCopies = @($group.Group | Where-Object Group -eq 'global')
        $involved = @(& $unique @(
            $(if ($globalCopies.Count -ge 2) { $globalCopies })
            foreach ($project in @($group.Group | Where-Object Group -ne 'global' | Group-Object Group)) {
                if ($globalCopies.Count + $project.Count -ge 2) { $globalCopies; $project.Group }
            }
        ))
        if ($involved.Count -lt 2) { continue }
        $adaptations = @($involved | Where-Object { $_.Managed -and -not $_.Original })
        $isPair = [bool](@($involved | Where-Object Original).Count -and $adaptations.Count)
        $keep = if ($isPair) { @($adaptations | Sort-Object { $_.Group -ne 'global' })[0] }
            else { @($involved | Sort-Object { -not $_.Managed }, { $_.Group -ne 'global' })[0] }
        $findings.Add([pscustomobject]@{
            kind = $(if ($isPair) { 'AdaptationAndOriginal' } else { 'Duplicate' })
            name = $involved[0].Name
            copies = @(foreach ($copy in $involved) { & $describe $copy $(if ($copy.Path -ceq $keep.Path) { 'keep' } else { & $removeAction $copy }) })
            note = $(if ($isPair) { 'Keep the adaptation, the install default.' } else { 'The same skill loads twice; keep one copy.' })
        })
    }

    foreach ($originalName in @($RenamedOriginals.Keys)) {
        $adaptationName = $RenamedOriginals[$originalName]
        $originals = @($Copies | Where-Object { $_.Name -ieq $originalName -and -not ($_.Managed -and -not $_.Original) })
        $adaptations = @($Copies | Where-Object { $_.Name -ieq $adaptationName })
        $involved = @(& $unique @(foreach ($original in $originals) { foreach ($adaptation in $adaptations) {
            if (Test-SkillCleanTogether @($original.Group) @($adaptation.Group)) { $original; $adaptation }
        } }))
        if (-not $involved.Count) { continue }
        $findings.Add([pscustomobject]@{
            kind = 'AdaptationAndOriginal'
            name = "$adaptationName + $originalName"
            copies = @(foreach ($copy in $involved) { & $describe $copy $(if ($copy.Name -ieq $adaptationName) { 'keep' } else { & $removeAction $copy }) })
            note = "$originalName is the original of the renamed adaptation $adaptationName; keep the adaptation, the install default."
        })
    }

    foreach ($copy in @($Copies | Where-Object { $_.Managed -and -not $_.Original -and ($FormerNames.ContainsKey($_.Folder) -or $FormerNames.ContainsKey($_.Name)) })) {
        $current = if ($FormerNames.ContainsKey($copy.Folder)) { $FormerNames[$copy.Folder] } else { $FormerNames[$copy.Name] }
        $findings.Add([pscustomobject]@{ kind = 'FormerName'; name = $copy.Name; copies = @(& $describe $copy 'update-topics'); note = "Current name: $current." })
    }

    foreach ($copy in @($Copies | Where-Object { $_.Managed -and -not $Descriptions.ContainsKey($_.Name) -and -not $FormerNames.ContainsKey($_.Folder) -and -not $FormerNames.ContainsKey($_.Name) })) {
        $findings.Add([pscustomobject]@{ kind = 'NotInCatalog'; name = $copy.Name; copies = @(& $describe $copy (& $removeAction $copy)); note = 'No catalog skill has this name.' })
    }

    foreach ($copy in @($Copies | Where-Object { -not $_.Loadable })) {
        $action = if ($copy.Managed -and $null -ne $copy.Index -and $Descriptions.ContainsKey($copy.Name)) { 'reinstall' } else { 'report' }
        $findings.Add([pscustomobject]@{ kind = 'CannotLoad'; name = $copy.Name; copies = @(& $describe $copy $action); note = 'SKILL.md is missing or has no name or description header.' })
    }

    $groupsByName = @{}
    foreach ($copy in $Copies) {
        $key = $copy.Name.ToLowerInvariant()
        if (-not $groupsByName.ContainsKey($key)) { $groupsByName[$key] = [Collections.Generic.List[string]]::new() }
        $groupsByName[$key].Add($copy.Group)
    }
    $overlaps = [Collections.Generic.List[object]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new()
    foreach ($name in @($groupsByName.Keys | Sort-Object)) {
        if (-not $Descriptions.ContainsKey($name)) { continue }
        # Only the "Overlaps with ..." clause counts, so ordinary words in a description do not.
        foreach ($clause in [regex]::Matches($Descriptions[$name], '(?i)overlaps?\s+with\s+([^;]+?)(?=;|\.(?:\s|$)|$)')) {
            foreach ($other in @($groupsByName.Keys | Sort-Object)) {
                if ($other -eq $name -or $clause.Groups[1].Value -notmatch "(?i)(?<![\w-])$([regex]::Escape($other))(?![\w-])") { continue }
                if (-not (Test-SkillCleanTogether @($groupsByName[$name]) @($groupsByName[$other]))) { continue }
                $pair = @(@($name, $other) | Sort-Object)
                if ($seen.Add($pair -join '|')) { $overlaps.Add([pscustomobject]@{ skills = $pair; namedBy = $name }) }
            }
        }
    }

    [pscustomobject]@{ findings = @($findings); catalogOverlaps = @($overlaps) }
}

$entries = @(Get-InstalledSkills)

if ($Check) {
    . (Join-Path $PSScriptRoot 'skill-files.ps1')
    $catalog = Get-SkillCleanCatalog -ProjectPath $ProjectPath -RepoPath $RepoPath
    $copies = @(Get-SkillCleanCopies -Entries $entries -OtherRoots $OtherSkillRoots)
    $result = Get-SkillCleanFindings -Copies $copies -Descriptions $catalog.Descriptions -RenamedOriginals $catalog.RenamedOriginals -FormerNames (Get-SkillFormerNames)
    [pscustomobject]@{
        repository = $catalog.RepoRoot
        places = @($copies | Group-Object Place | ForEach-Object { [pscustomobject]@{ place = $_.Name; copies = $_.Count; managed = @($_.Group | Where-Object Managed).Count } })
        findings = $result.findings
        catalogOverlaps = $result.catalogOverlaps
    } | ConvertTo-Json -Depth 8
    return
}

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

. (Join-Path $PSScriptRoot 'skill-files.ps1')
$updatePaths = @($matchedEntries | Where-Object {
    [IO.Path]::GetFullPath((Split-Path -Parent $_.Path)) -in $allowedRoots -and
    -not ((Get-Item -LiteralPath $_.Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)
} | ForEach-Object { $_.Path })
$updateLease = if ($updatePaths.Count) { Enter-SkillUpdateOwnership -Paths $updatePaths -ConfirmStopped:$ConfirmStopped } else { $null }
try {
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

    $backup = New-SkillUpdateTransaction -Targets @(@{ path = $fullPath; target = $fullPath; name = $match.Name })
    try {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }
    catch { Restore-SkillUpdateTransaction $backup; throw }
    Complete-SkillUpdateTransaction $backup
    Write-Output "Uninstalled: $($match.Scope) $($match.Name) -> $fullPath"
}
}
finally { Exit-SkillOwnership $updateLease }