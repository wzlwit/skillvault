[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string[]]$Name,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$RepoRoot,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$helperPath = Join-Path $PSScriptRoot '..\..\skillvault-install\scripts\skill-files.ps1'
if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
    throw 'Install the sibling skillvault-install skill before using skillvault-remove.'
}
. $helperPath

$repositoryRoot = Resolve-SkillSourcePath -RepositoryRoot $RepoRoot -SourcePath '.'
$catalogPath = Join-Path $repositoryRoot 'catalog.json'
$catalogItem = Get-Item -LiteralPath $catalogPath -Force
if ($catalogItem -isnot [System.IO.FileInfo] -or (Test-SkillReparsePoint -Item $catalogItem)) {
    throw "Catalog must be a regular file: $catalogPath"
}
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$requestedNames = @($Name | Select-Object -Unique)

$removals = @(foreach ($skillName in $requestedNames) {
    if ($skillName -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
        throw "Use an exact skill name, not a selector or path: $skillName"
    }
    $entries = @($catalog | Where-Object { $_.name -ceq $skillName })
    if ($entries.Count -ne 1) { throw "Skill must occur exactly once in the catalog: $skillName" }
    $entry = $entries[0]
    $segments = ([string]$entry.path).Split('/')
    if ($segments.Count -ne 4 -or $segments[0] -cne 'skills' -or $segments[1] -cne 'public' -or
        $segments[2] -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -or $segments[3] -cne $skillName) {
        throw "Unsafe catalog path for ${skillName}: $($entry.path)"
    }
    $sourcePath = Resolve-SkillSourcePath -RepositoryRoot $repositoryRoot -SourcePath $entry.path
    $manifest = Read-SkillManifest -SkillPath $sourcePath -ExpectedName $skillName
    if ('version' -notin $entry.PSObject.Properties.Name -or $manifest.version -cne $entry.version) {
        throw "Catalog and manifest versions differ: $skillName"
    }
    Get-SkillFiles -SkillPath $sourcePath | Out-Null
    [pscustomobject]@{ Name = $skillName; Version = $entry.version; Path = $sourcePath }
})

$remaining = @($catalog | Where-Object { $_.name -cnotin $requestedNames } | Sort-Object name)
foreach ($entry in $remaining) {
    $sourcePath = Resolve-SkillSourcePath -RepositoryRoot $repositoryRoot -SourcePath $entry.path
    $manifest = Read-SkillManifest -SkillPath $sourcePath -ExpectedName $entry.name
    foreach ($dependency in @($manifest.dependencies)) {
        if ($dependency -cin $requestedNames) {
            throw "Skill '$($entry.name)' still depends on '$dependency'. Resolve that dependency before removal."
        }
    }
}

$bootstrapNames = @()
$bootstrapPath = Join-Path $repositoryRoot 'scripts/install-global.ps1'
if (Test-Path -LiteralPath $bootstrapPath -PathType Leaf) {
    $tokens = $null
    $parseErrors = $null
    $bootstrapAst = [System.Management.Automation.Language.Parser]::ParseFile($bootstrapPath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) { throw "Cannot read bootstrap registration: $bootstrapPath" }
    $registration = $bootstrapAst.Find({
        param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -ceq '$bootstrapSkillNames'
    }, $true)
    if ($null -eq $registration) { throw "Cannot locate bootstrapSkillNames in $bootstrapPath" }
    $bootstrapNames = @($registration.Right.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.StringConstantExpressionAst]
    }, $true) | ForEach-Object { $_.Value })
}
$shellBootstrapPath = Join-Path $repositoryRoot 'scripts/install-global.sh'
if (Test-Path -LiteralPath $shellBootstrapPath -PathType Leaf) {
    $shellContent = Get-Content -LiteralPath $shellBootstrapPath -Raw
    $registrationMatch = [regex]::Match($shellContent, 'bootstrap_skill_names=\((?<body>[^)]*)\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $registrationMatch.Success) { throw "Cannot locate bootstrap_skill_names in $shellBootstrapPath" }
    $bootstrapNames += @([regex]::Matches($registrationMatch.Groups['body'].Value, "['`"]([^'`"]+)['`"]") | ForEach-Object { $_.Groups[1].Value })
}
foreach ($skillName in $requestedNames) {
    if ($skillName -cin $bootstrapNames) {
        throw "Skill '$skillName' is registered for bootstrap. Update both bootstrap installers before removal."
    }
}

Write-Output "Selected source skills in ${repositoryRoot}:"
$removals | Format-Table Name, Version, Path -AutoSize | Out-String -Width 240 | Write-Output
Write-Output "Their catalog entries will be removed from $catalogPath. Installed copies are unchanged."
if (-not $Force) {
    Write-Output 'Re-run with -Force only after confirming these exact source paths and catalog entries.'
    return
}

$recoveryRoot = Join-Path $repositoryRoot ('.skillvault-remove-' + [guid]::NewGuid().ToString('N'))
$nextCatalogPath = Join-Path $recoveryRoot 'catalog.next.json'
$backupCatalogPath = Join-Path $recoveryRoot 'catalog.original.json'
New-Item -ItemType Directory -Path $recoveryRoot | Out-Null

try {
    $nextCatalog = ConvertTo-Json -InputObject $remaining -Depth 20
    [System.IO.File]::WriteAllText($nextCatalogPath, $nextCatalog + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
    foreach ($removal in $removals) {
        Move-Item -LiteralPath $removal.Path -Destination (Join-Path $recoveryRoot $removal.Name)
    }
    [System.IO.File]::Replace($nextCatalogPath, $catalogPath, $backupCatalogPath)
}
catch {
    $failure = $_.Exception.Message
    $recoveryErrors = New-Object 'System.Collections.Generic.List[string]'
    if (Test-Path -LiteralPath $backupCatalogPath -PathType Leaf) {
        try { Copy-Item -LiteralPath $backupCatalogPath -Destination $catalogPath -Force }
        catch { $recoveryErrors.Add($_.Exception.Message) }
    }
    foreach ($removal in $removals) {
        $stagedPath = Join-Path $recoveryRoot $removal.Name
        if (-not (Test-Path -LiteralPath $stagedPath)) { continue }
        try {
            if (Test-Path -LiteralPath $removal.Path) { throw "Source path reappeared: $($removal.Path)" }
            Move-Item -LiteralPath $stagedPath -Destination $removal.Path
        }
        catch { $recoveryErrors.Add($_.Exception.Message) }
    }
    if ($recoveryErrors.Count -eq 0) {
        try { Remove-Item -LiteralPath $recoveryRoot -Recurse -Force }
        catch { $recoveryErrors.Add($_.Exception.Message) }
    }
    if ($recoveryErrors.Count -gt 0) {
        throw "Source removal failed: $failure. Recovery files retained at ${recoveryRoot}: $($recoveryErrors -join '; ')"
    }
    throw "Source removal failed; source folders and catalog were restored: $failure"
}

try { Remove-Item -LiteralPath $recoveryRoot -Recurse -Force }
catch { throw "Source entries were removed, but recovery cleanup failed at ${recoveryRoot}: $($_.Exception.Message)" }
foreach ($removal in $removals) { Write-Output "Removed source skill: $($removal.Name) -> $($removal.Path)" }
Write-Output 'Installed copies, schedules, and remote repositories were not changed.'