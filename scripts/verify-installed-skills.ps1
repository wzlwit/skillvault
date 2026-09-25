param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$SkillsPath = (Join-Path (Split-Path -Parent $PSScriptRoot) '.github/skills'),
    [string[]]$Name
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\skills\core\skillvault-installation\scripts\skill-files.ps1')
$catalog = Get-Content -LiteralPath (Join-Path $RepoRoot 'catalog.json') -Raw | ConvertFrom-Json
$count = 0
foreach ($directory in Get-ChildItem -LiteralPath $SkillsPath -Directory) {
    if ($directory.Name -like '.skillvault-stage-*' -or $directory.Name -like '.skillvault-backup-*') { continue }
    if ($Name -and $directory.Name -notin $Name) { continue }
    $metadataPath = Join-Path $directory.FullName '.skillvault-install.json'
    if (-not (Test-Path -LiteralPath $metadataPath)) { continue }
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    if ($metadata.installedBy -notin @('skillvault', 'skillvault-bootstrap')) { continue }
    $entry = @($catalog | Where-Object { $_.name -eq $directory.Name })
    if ($entry.Count -ne 1) { throw "Installed managed skill is not in catalog: $($directory.Name)" }
    if ($metadata.sourceRepo -notin @('https://github.com/wzlwit/skillvault', 'https://github.com/wzlwit/skillvault.git') -or $metadata.sourcePath -ne $entry[0].path) {
        throw "Installed source identity differs from catalog: $($directory.Name)"
    }
    if ($metadata.scope -notin @('global', 'project') -or 'installedVersion' -notin $metadata.PSObject.Properties.Name -or $metadata.installedVersion -cne $entry[0].version) {
        throw "Installed scope or version differs: $($directory.Name)"
    }
    $source = Resolve-SkillSourcePath -RepositoryRoot $RepoRoot -SourcePath $entry[0].path
    if (-not (Test-SkillContentEqual -Source $source -Target $directory.FullName)) { throw "Installed content differs: $($directory.Name)" }
    $count++
}
if ($Name -and $count -ne @($Name | Select-Object -Unique).Count) { throw 'Not all requested managed skills were verified.' }
Write-Output "Verified $count installed skill(s) against the selected local checkout."