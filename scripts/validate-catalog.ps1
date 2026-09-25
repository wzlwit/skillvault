param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
$catalogPath = Join-Path $repoRoot 'catalog.json'
$allowedCatalogFields = @('name', 'description', 'path', 'version')
$allowedDefaultScopes = @('global', 'project', 'session')

if (-not (Test-Path $catalogPath)) {
    throw "Missing catalog: $catalogPath"
}

node (Join-Path $PSScriptRoot 'validate-skill-files.mjs') --repo $repoRoot
if ($LASTEXITCODE -ne 0) { throw 'Skill file validation failed. Run npm ci in the SkillVault checkout if dependencies are missing.' }

$catalog = Get-Content $catalogPath -Raw | ConvertFrom-Json
$names = @($catalog | ForEach-Object { $_.name })
$sortedNames = @($names | Sort-Object)
if (($names -join '|') -ne ($sortedNames -join '|')) {
    throw "Catalog is not sorted by name: $($names -join ', ')"
}

$catalogNames = New-Object 'System.Collections.Generic.HashSet[string]'

foreach ($entry in $catalog) {
    foreach ($property in @($entry.PSObject.Properties.Name)) {
        if ($property -notin $allowedCatalogFields) {
            throw "Unexpected catalog field '$property' for $($entry.name)"
        }
    }

    foreach ($required in $allowedCatalogFields) {
        if ($required -notin $entry.PSObject.Properties.Name -or
            ($required -ne 'version' -and [string]::IsNullOrWhiteSpace([string]$entry.$required))) {
            throw "Missing catalog field '$required' for $($entry.name)"
        }
    }

    if ($null -ne $entry.version -and
        ($entry.version -isnot [string] -or [string]::IsNullOrWhiteSpace($entry.version))) {
        throw "Invalid catalog version for $($entry.name): expected a non-empty string or null"
    }

    if (-not $catalogNames.Add($entry.name)) {
        throw "Duplicate catalog entry: $($entry.name)"
    }

    $skillPath = Join-Path $repoRoot $entry.path
    if (-not (Test-Path $skillPath)) {
        throw "Missing catalog path: $($entry.path)"
    }

    $manifestPath = Join-Path $skillPath 'skill.json'
    if (-not (Test-Path $manifestPath)) {
        throw "Missing manifest: $manifestPath"
    }

    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.name -ne $entry.name) {
        throw "Name mismatch for $($entry.path): catalog=$($entry.name), manifest=$($manifest.name)"
    }

    if ('version' -notin $manifest.PSObject.Properties.Name) {
        throw "Missing manifest version for $($entry.name)"
    }

    if ($null -ne $manifest.version -and
        ($manifest.version -isnot [string] -or [string]::IsNullOrWhiteSpace($manifest.version))) {
        throw "Invalid manifest version for $($entry.name): expected a non-empty string or null"
    }

    if ($manifest.version -ne $entry.version) {
        throw "Version mismatch for $($entry.name): catalog=$($entry.version), manifest=$($manifest.version)"
    }

    if ([string]::IsNullOrWhiteSpace([string]$manifest.description)) {
        throw "Missing manifest description for $($entry.name)"
    }

    if (-not $manifest.install.defaultScope) {
        throw "Missing install.defaultScope for $($entry.name)"
    }

    if ($manifest.install.defaultScope -notin $allowedDefaultScopes) {
        throw "Invalid install.defaultScope for $($entry.name): $($manifest.install.defaultScope)"
    }

    if ($manifest.readme) {
        $readmePath = Join-Path $skillPath $manifest.readme
        if (-not (Test-Path $readmePath)) {
            throw "Missing readme for $($entry.name): $($manifest.readme)"
        }
    }
}

$publicSkillRoot = Join-Path $repoRoot 'skills'
if (Test-Path $publicSkillRoot) {
    foreach ($manifestFile in Get-ChildItem -Path $publicSkillRoot -Recurse -Filter 'skill.json') {
        $manifest = Get-Content $manifestFile.FullName -Raw | ConvertFrom-Json
        if (-not $catalogNames.Contains($manifest.name)) {
            throw "Public skill missing from catalog: $($manifest.name)"
        }
    }
}

$scriptRoots = @('scripts', 'skills', '.github/skills') | ForEach-Object {
    $candidate = Join-Path $repoRoot $_
    if (Test-Path -LiteralPath $candidate) { $candidate }
}
foreach ($script in Get-ChildItem -LiteralPath $scriptRoots -Recurse -Filter '*.ps1' -File) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        $errors | ForEach-Object { Write-Output "$($script.FullName): $($_.Message)" }
        throw "PowerShell parse failed: $($script.FullName)"
    }
}

Write-Output "Validated $($catalog.Count) catalog skill(s)."