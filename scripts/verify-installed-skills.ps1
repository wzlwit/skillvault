param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$SkillsPath = (Join-Path (Split-Path -Parent $PSScriptRoot) '.github/skills'),
    [string[]]$Name
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\skills\core\skillvault-installation\scripts\skill-files.ps1')
$catalog = Get-Content -LiteralPath (Join-Path $RepoRoot 'catalog.json') -Raw | ConvertFrom-Json
$count = 0
$originCount = 0
$pinnedCount = 0
foreach ($directory in Get-ChildItem -LiteralPath $SkillsPath -Directory) {
    if ($directory.Name -like '.skillvault-stage-*' -or $directory.Name -like '.skillvault-backup-*') { continue }
    if ($Name -and $directory.Name -notin $Name) { continue }
    $metadataPath = Join-Path $directory.FullName '.skillvault-install.json'
    if (-not (Test-Path -LiteralPath $metadataPath)) { continue }
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    if ($metadata.installedBy -notin @('skillvault', 'skillvault-bootstrap')) { continue }
    $entry = @($catalog | Where-Object { $_.name -eq $directory.Name })
    if ($entry.Count -ne 1) { throw "Installed managed skill is not in catalog: $($directory.Name)" }
    $pinned = $metadata.sourceType -cne 'upstream' -and [string]$metadata.requestedVersion -cne 'latest'
    if ($metadata.scope -notin @('global', 'project') -or 'installedVersion' -notin $metadata.PSObject.Properties.Name -or
        (-not $pinned -and $metadata.installedVersion -cne $entry[0].version)) {
        throw "Installed scope or version differs: $($directory.Name)"
    }
    $source = Resolve-SkillSourcePath -RepositoryRoot $RepoRoot -SourcePath $entry[0].path
    if ($metadata.sourceType -ceq 'upstream') {
        # An original comes from upstream, so only its recorded source can be checked here.
        $upstream = (Read-SkillManifest -SkillPath $source -ExpectedName $directory.Name -AllowReference).upstream
        if (-not $upstream -or $metadata.sourceRepo -cne $upstream.repo -or $metadata.sourcePath -cne $upstream.path -or $metadata.requestedVersion -cne $upstream.version) {
            throw "Installed original differs from its catalog reference: $($directory.Name)"
        }
        $originCount++
        $count++
        continue
    }
    if ($metadata.sourceRepo -notin @('https://github.com/wzlwit/skillvault', 'https://github.com/wzlwit/skillvault.git') -or (-not $pinned -and $metadata.sourcePath -ne $entry[0].path)) {
        throw "Installed source identity differs from catalog: $($directory.Name)"
    }
    if ($pinned) {
        # A pinned copy is compared with its own tag, not with the current checkout.
        $tagFolder = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-verify-' + [guid]::NewGuid().ToString('N'))
        try {
            $pin = Get-SkillTagSnapshot -RepoPath $RepoRoot -Name $directory.Name -Version ([string]$metadata.requestedVersion) -Destination $tagFolder
            if ($metadata.sourcePath -cne $pin.Path -or $metadata.installedVersion -cne $pin.Manifest.version -or
                -not (Test-SkillContentEqual -Source $pin.Folder -Target $directory.FullName)) {
                throw "Installed copy differs from tag $($pin.Tag): $($directory.Name)"
            }
        }
        finally { Remove-Item -LiteralPath $tagFolder -Recurse -Force -ErrorAction SilentlyContinue }
        $pinnedCount++
        $count++
        continue
    }
    if (-not (Test-SkillContentEqual -Source $source -Target $directory.FullName)) { throw "Installed content differs: $($directory.Name)" }
    $count++
}
if ($Name -and $count -ne @($Name | Select-Object -Unique).Count) { throw 'Not all requested managed skills were verified.' }
Write-Output "Verified $count installed skill(s) against the selected local checkout."
if ($originCount) { Write-Output "$originCount of them install an original from upstream; only their source, path, and version were checked." }
if ($pinnedCount) { Write-Output "$pinnedCount of them are pinned and were checked against their own tags." }