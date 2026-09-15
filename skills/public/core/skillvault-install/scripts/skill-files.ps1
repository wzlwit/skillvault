function Test-SkillReparsePoint {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileSystemInfo]$Item
    )

    return (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint)
}

function Resolve-SkillSourcePath {
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryRoot,
        [Parameter(Mandatory = $true)][string]$SourcePath
    )

    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        throw 'Skill source path is empty.'
    }

    if ([System.IO.Path]::IsPathRooted($SourcePath)) {
        throw "Skill source path must be relative to the repository root: $SourcePath"
    }

    $normalizedSourcePath = $SourcePath.Replace('\', '/')
    if ($normalizedSourcePath -ne '.' -and ($normalizedSourcePath.StartsWith('/') -or $normalizedSourcePath.EndsWith('/') -or
        $normalizedSourcePath.Contains('//') -or
        $normalizedSourcePath -match '(^|/)\.{1,2}(/|$)' -or
        $normalizedSourcePath -match '[:*?<>|"]')) {
        throw "Skill source path must be a canonical relative path: $SourcePath"
    }

    $repositoryRootItem = Get-Item -LiteralPath $RepositoryRoot -Force -ErrorAction SilentlyContinue
    if ($null -eq $repositoryRootItem -or $repositoryRootItem -isnot [System.IO.DirectoryInfo]) {
        throw "Repository root is not a directory: $RepositoryRoot"
    }
    if (Test-SkillReparsePoint -Item $repositoryRootItem) { throw "Repository root is a reparse point: $RepositoryRoot" }
    if ($normalizedSourcePath -eq '.') { return $repositoryRootItem.FullName }

    $resolvedPath = $repositoryRootItem.FullName.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    foreach ($segment in $normalizedSourcePath.Split('/')) {
        $resolvedPath = Join-Path $resolvedPath $segment
        $segmentItem = Get-Item -LiteralPath $resolvedPath -Force -ErrorAction SilentlyContinue
        if ($null -eq $segmentItem -or $segmentItem -isnot [System.IO.DirectoryInfo]) {
            throw "Skill source directory not found: $SourcePath"
        }
        if (Test-SkillReparsePoint -Item $segmentItem) {
            throw "Skill source path crosses a reparse point: $resolvedPath"
        }
        $resolvedPath = $segmentItem.FullName.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    }

    return $resolvedPath
}

function Read-SkillManifest {
    param(
        [Parameter(Mandatory = $true)][string]$SkillPath,
        [Parameter(Mandatory = $true)][string]$ExpectedName
    )

    $ErrorActionPreference = 'Stop'

    $manifestPath = Join-Path $SkillPath 'skill.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Missing skill manifest: $manifestPath"
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($null -eq $manifest -or $manifest -isnot [System.Management.Automation.PSCustomObject]) {
        throw "Skill manifest must be a JSON object: $manifestPath"
    }

    if ($manifest.name -cne $ExpectedName) {
        throw "Skill manifest name mismatch in ${manifestPath}: expected '$ExpectedName', found '$($manifest.name)'"
    }

    if ('version' -notin $manifest.PSObject.Properties.Name) {
        throw "Missing skill manifest version: $manifestPath"
    }

    if ($null -ne $manifest.version -and
        ($manifest.version -isnot [string] -or [string]::IsNullOrWhiteSpace($manifest.version))) {
        throw "Invalid skill manifest version in ${manifestPath}: expected a non-empty string or null"
    }

    if (-not (Test-Path -LiteralPath (Join-Path $SkillPath 'SKILL.md') -PathType Leaf)) {
        throw "Missing SKILL.md for skill '$ExpectedName': $SkillPath"
    }

    return $manifest
}

function Get-SkillFiles {
    param(
        [Parameter(Mandatory = $true)][string]$SkillPath
    )

    $ErrorActionPreference = 'Stop'

    $rootItem = Get-Item -LiteralPath $SkillPath -Force -ErrorAction SilentlyContinue
    if ($null -eq $rootItem -or $rootItem -isnot [System.IO.DirectoryInfo]) {
        throw "Skill path is not a directory: $SkillPath"
    }
    if (Test-SkillReparsePoint -Item $rootItem) {
        throw "Skill path is a reparse point: $SkillPath"
    }

    $rootFullPath = $rootItem.FullName.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $skillFiles = New-Object System.Collections.ArrayList
    $pendingDirectories = New-Object System.Collections.Queue
    $pendingDirectories.Enqueue($rootFullPath)

    while ($pendingDirectories.Count -gt 0) {
        $currentDirectory = $pendingDirectories.Dequeue()
        foreach ($child in Get-ChildItem -LiteralPath $currentDirectory -Force) {
            if (Test-SkillReparsePoint -Item $child) {
                throw "Skill content contains a reparse point: $($child.FullName)"
            }

            if ($child -is [System.IO.DirectoryInfo]) {
                if ($child.Name -eq '.git') { continue }
                $pendingDirectories.Enqueue($child.FullName)
                continue
            }

            $relativePath = $child.FullName.Substring($rootFullPath.Length + 1).Replace('\', '/')
            if ($relativePath -eq '.skillvault-install.json') { continue }

            [void]$skillFiles.Add([pscustomobject]@{
                RelativePath = $relativePath
                FullName = $child.FullName
            })
        }
    }

    return @($skillFiles | Sort-Object -Property RelativePath)
}

function Test-SkillContentEqual {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Target
    )

    if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
        return $false
    }

    $sourceFiles = @(Get-SkillFiles -SkillPath $Source)
    $targetFiles = @(Get-SkillFiles -SkillPath $Target)
    if ($sourceFiles.Count -ne $targetFiles.Count) {
        return $false
    }

    $byteComparer = [System.Collections.StructuralComparisons]::StructuralEqualityComparer
    for ($index = 0; $index -lt $sourceFiles.Count; $index++) {
        if ($sourceFiles[$index].RelativePath -cne $targetFiles[$index].RelativePath) {
            return $false
        }
        $sourceBytes = [System.IO.File]::ReadAllBytes($sourceFiles[$index].FullName)
        $targetBytes = [System.IO.File]::ReadAllBytes($targetFiles[$index].FullName)
        if (-not $byteComparer.Equals($sourceBytes, $targetBytes)) {
            return $false
        }
    }

    return $true
}

function Assert-SkillInstallMetadata {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Metadata,
        [Parameter(Mandatory = $true)]$Manifest
    )

    foreach ($requiredField in @('installedBy', 'sourceRepo', 'sourcePath', 'scope', 'requestedVersion', 'installedVersion', 'installedAt')) {
        if (-not $Metadata.Contains($requiredField)) {
            throw "Missing install metadata field: $requiredField"
        }
    }

    if ($Metadata['installedBy'] -cnotin @('skillvault', 'skillvault-bootstrap')) {
        throw "Invalid install metadata installedBy: $($Metadata['installedBy'])"
    }

    if ($Metadata['scope'] -cnotin @('global', 'project')) {
        throw "Invalid install metadata scope: $($Metadata['scope'])"
    }

    foreach ($textField in @('sourceRepo', 'sourcePath', 'requestedVersion', 'installedAt')) {
        if ([string]::IsNullOrWhiteSpace([string]$Metadata[$textField])) {
            throw "Install metadata field '$textField' must be a non-empty string."
        }
    }

    $metadataSourcePath = [string]$Metadata['sourcePath']
    if ($metadataSourcePath -ne '.' -and ([System.IO.Path]::IsPathRooted($metadataSourcePath) -or
        $metadataSourcePath.Replace('\', '/') -match '(^|/)\.{1,2}(/|$)')) {
        throw "Install metadata sourcePath must be a canonical repository-relative path: $metadataSourcePath"
    }

    $metadataVersion = $Metadata['installedVersion']
    if ($null -ne $metadataVersion -and
        ($metadataVersion -isnot [string] -or [string]::IsNullOrWhiteSpace($metadataVersion))) {
        throw 'Install metadata installedVersion must be a non-empty string or null.'
    }

    if ($metadataVersion -cne $Manifest.version) {
        throw "Install metadata installedVersion '$metadataVersion' does not match the skill manifest version '$($Manifest.version)'."
    }
}

function Copy-SkillInstallation {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$TargetRoot,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Metadata,
        [switch]$Force
    )

    $ErrorActionPreference = 'Stop'

    if ($Name -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "Unsafe skill name: $Name"
    }

    $sourceItem = Get-Item -LiteralPath $Source -Force -ErrorAction SilentlyContinue
    if ($null -eq $sourceItem -or $sourceItem -isnot [System.IO.DirectoryInfo]) {
        throw "Skill source is not a directory: $Source"
    }

    $manifest = Read-SkillManifest -SkillPath $sourceItem.FullName -ExpectedName $Name
    Assert-SkillInstallMetadata -Metadata $Metadata -Manifest $manifest

    $sourceFullPath = $sourceItem.FullName.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $targetRootFullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $targetPath = Join-Path $targetRootFullPath $Name
    $separator = [string][System.IO.Path]::DirectorySeparatorChar

    if ($sourceFullPath -eq $targetPath -or
        $sourceFullPath.StartsWith($targetPath + $separator, [System.StringComparison]::OrdinalIgnoreCase) -or
        $targetPath.StartsWith($sourceFullPath + $separator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Skill source and install target overlap: $sourceFullPath"
    }

    $targetExists = Test-Path -LiteralPath $targetPath
    if ($targetExists) {
        $targetItem = Get-Item -LiteralPath $targetPath -Force
        if (-not $targetItem.PSIsContainer -or (Test-SkillReparsePoint -Item $targetItem)) {
            throw "Install target must be a real directory: $targetPath"
        }
    }
    if ($targetExists -and -not $Force) {
        throw "Skill '$Name' is already installed at $targetPath. Review the pending changes, then re-run with -Force to overwrite."
    }

    $sourceFiles = @(Get-SkillFiles -SkillPath $sourceFullPath)
    if ($sourceFiles.Count -eq 0) {
        throw "Skill source has no installable files: $sourceFullPath"
    }

    New-Item -ItemType Directory -Path $targetRootFullPath -Force | Out-Null
    $stagingPath = Join-Path $targetRootFullPath ('.skillvault-stage-' + [guid]::NewGuid().ToString('N'))
    $backupPath = $null
    $preserveBackup = $false

    try {
        New-Item -ItemType Directory -Path $stagingPath -Force | Out-Null

        foreach ($sourceFile in $sourceFiles) {
            $stagedFilePath = Join-Path $stagingPath $sourceFile.RelativePath.Replace([char]'/', [System.IO.Path]::DirectorySeparatorChar)
            $stagedFileParent = Split-Path -Parent $stagedFilePath
            if (-not (Test-Path -LiteralPath $stagedFileParent -PathType Container)) {
                New-Item -ItemType Directory -Path $stagedFileParent -Force | Out-Null
            }
            Copy-Item -LiteralPath $sourceFile.FullName -Destination $stagedFilePath
        }

        $Metadata | ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath (Join-Path $stagingPath '.skillvault-install.json') -Encoding utf8
        Read-SkillManifest -SkillPath $stagingPath -ExpectedName $Name | Out-Null

        if ($targetExists) {
            $backupPath = Join-Path $targetRootFullPath ('.skillvault-backup-' + [guid]::NewGuid().ToString('N'))
            Move-Item -LiteralPath $targetPath -Destination $backupPath
        }

        try {
            Move-Item -LiteralPath $stagingPath -Destination $targetPath
        }
        catch {
            $preserveBackup = $null -ne $backupPath
            if ($null -ne $backupPath -and (Test-Path -LiteralPath $backupPath) -and -not (Test-Path -LiteralPath $targetPath)) {
                try {
                    Move-Item -LiteralPath $backupPath -Destination $targetPath
                    $preserveBackup = $false
                }
                catch {
                    $preserveBackup = $true
                    throw "Install failed for skill '$Name' and the previous install could not be restored automatically. The original content is preserved at: $backupPath"
                }
            }
            if ($preserveBackup) {
                throw "Install failed for skill '$Name'. Inspect the target; the original content is preserved at: $backupPath"
            }
            throw
        }
    }
    finally {
        if (Test-Path -LiteralPath $stagingPath) {
            Remove-Item -LiteralPath $stagingPath -Recurse -Force
        }
        if ($null -ne $backupPath -and -not $preserveBackup -and (Test-Path -LiteralPath $backupPath)) {
            Remove-Item -LiteralPath $backupPath -Recurse -Force
        }
    }

    return [pscustomobject]@{
        Name = $Name
        Path = $targetPath
        Version = $manifest.version
        Replaced = $targetExists
    }
}
