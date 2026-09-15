$ErrorActionPreference = 'Stop'
$removeScript = Join-Path $PSScriptRoot '..\skills\public\core\skillvault-remove\scripts\skillvault-remove.ps1'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Pattern)
    try { & $Action | Out-Null }
    catch {
        if ($_.Exception.Message -notlike $Pattern) { throw }
        return
    }
    throw "Expected failure matching: $Pattern"
}

$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-remove-test-' + [guid]::NewGuid().ToString('N'))
$repositoryRoot = Join-Path $fixtureRoot 'repo'
$catalogPath = Join-Path $repositoryRoot 'catalog.json'

try {
    $catalog = @(foreach ($skillName in @('alpha', 'beta', 'gamma')) {
        $relativePath = "skills/public/testing/$skillName"
        $sourcePath = Join-Path $repositoryRoot $relativePath
        New-Item -ItemType Directory -Path $sourcePath -Force | Out-Null
        [ordered]@{ name = $skillName; version = $null; dependencies = @() } |
            ConvertTo-Json | Set-Content -LiteralPath (Join-Path $sourcePath 'skill.json') -Encoding utf8
        "---`nname: $skillName`ndescription: Test fixture`n---`n# $skillName" |
            Set-Content -LiteralPath (Join-Path $sourcePath 'SKILL.md') -Encoding utf8
        [ordered]@{ name = $skillName; description = "Fixture $skillName"; path = $relativePath; version = $null }
    })
    ConvertTo-Json -InputObject $catalog -Depth 5 | Set-Content -LiteralPath $catalogPath -Encoding utf8
    $originalCatalog = [System.IO.File]::ReadAllText($catalogPath)
    $alphaPath = Join-Path $repositoryRoot $catalog[0].path
    $betaPath = Join-Path $repositoryRoot $catalog[1].path
    $gammaPath = Join-Path $repositoryRoot $catalog[2].path
    [System.IO.File]::WriteAllBytes((Join-Path $alphaPath 'payload.bin'), [byte[]](0, 1, 2, 250, 255))
    $installedPath = Join-Path $repositoryRoot '.github/skills/alpha'
    $otherRepositoryPath = Join-Path $fixtureRoot 'other-repo/skills/public/testing/alpha'
    New-Item -ItemType Directory -Path $installedPath, $otherRepositoryPath -Force | Out-Null
    'installed copy' | Set-Content -LiteralPath (Join-Path $installedPath 'marker.txt')
    'other repository' | Set-Content -LiteralPath (Join-Path $otherRepositoryPath 'marker.txt')

    $preview = @(& $removeScript -Name alpha -RepoRoot $repositoryRoot) -join "`n"
    Assert-True ($preview -like '*-Force*' -and $preview.Contains($alphaPath)) 'preview shows the exact source path and confirmation flag'
    Assert-True ((Test-Path -LiteralPath $alphaPath) -and [System.IO.File]::ReadAllText($catalogPath) -ceq $originalCatalog) 'preview writes nothing'
    Assert-True (@(Get-ChildItem -LiteralPath $repositoryRoot -Directory -Filter '.skillvault-remove-*').Count -eq 0) 'preview creates no staging directory'

    Assert-Throws { & $removeScript -Name alpha,absent -RepoRoot $repositoryRoot -Force } '*must occur exactly once*'
    Assert-Throws { & $removeScript -Name '../alpha' -RepoRoot $repositoryRoot -Force } '*exact skill name*'
    Assert-True (Test-Path -LiteralPath $alphaPath) 'all names are checked before removal'

    $catalog[0].path = '../other-repo'
    ConvertTo-Json -InputObject $catalog -Depth 5 | Set-Content -LiteralPath $catalogPath -Encoding utf8
    Assert-Throws { & $removeScript -Name alpha -RepoRoot $repositoryRoot -Force } '*Unsafe catalog path*'
    [System.IO.File]::WriteAllText($catalogPath, $originalCatalog)
    $catalog[0].path = 'skills/public/testing/alpha'

    ConvertTo-Json -InputObject @($catalog + $catalog[0]) -Depth 5 | Set-Content -LiteralPath $catalogPath -Encoding utf8
    Assert-Throws { & $removeScript -Name alpha -RepoRoot $repositoryRoot -Force } '*must occur exactly once*'
    [System.IO.File]::WriteAllText($catalogPath, $originalCatalog)

    $gammaManifestPath = Join-Path $gammaPath 'skill.json'
    $gammaManifest = [System.IO.File]::ReadAllText($gammaManifestPath)
    '{"name":"gamma","version":null,"dependencies":["alpha"]}' | Set-Content -LiteralPath $gammaManifestPath -Encoding utf8
    Assert-Throws { & $removeScript -Name alpha -RepoRoot $repositoryRoot -Force } '*still depends on*'
    [System.IO.File]::WriteAllText($gammaManifestPath, $gammaManifest)

    $bootstrapPath = Join-Path $repositoryRoot 'scripts/install-global.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $bootstrapPath) -Force | Out-Null
    '$bootstrapSkillNames = @(''alpha'')' | Set-Content -LiteralPath $bootstrapPath -Encoding utf8
    Assert-Throws { & $removeScript -Name alpha -RepoRoot $repositoryRoot -Force } '*registered for bootstrap*'
    Remove-Item -LiteralPath $bootstrapPath
    $shellBootstrapPath = Join-Path $repositoryRoot 'scripts/install-global.sh'
    'bootstrap_skill_names=("alpha")' | Set-Content -LiteralPath $shellBootstrapPath -Encoding utf8
    Assert-Throws { & $removeScript -Name alpha -RepoRoot $repositoryRoot -Force } '*registered for bootstrap*'
    Remove-Item -LiteralPath $shellBootstrapPath

    $global:skillVaultRemoveFailurePath = $betaPath
    function global:Move-Item {
        param([string]$LiteralPath, [string]$Destination)
        if ($LiteralPath -eq $global:skillVaultRemoveFailurePath) { throw 'injected staging failure' }
        Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination
    }
    try { Assert-Throws { & $removeScript -Name alpha,beta -RepoRoot $repositoryRoot -Force } '*source folders and catalog were restored*' }
    finally { Remove-Item -LiteralPath Function:\Move-Item -Force }
    Assert-True ((Test-Path -LiteralPath (Join-Path $alphaPath 'payload.bin')) -and (Test-Path -LiteralPath $betaPath)) 'a staging failure restores moved sources'
    Assert-True ([System.IO.File]::ReadAllText($catalogPath) -ceq $originalCatalog) 'a staging failure preserves the original catalog'
    Assert-True (@(Get-ChildItem -LiteralPath $repositoryRoot -Directory -Filter '.skillvault-remove-*').Count -eq 0) 'successful rollback leaves no residue'

    function global:Move-Item {
        param([string]$LiteralPath, [string]$Destination)
        if ($LiteralPath -eq $global:skillVaultRemoveFailurePath -or $LiteralPath -like '*.skillvault-remove-*') {
            throw 'injected staging or restore failure'
        }
        Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination
    }
    try { Assert-Throws { & $removeScript -Name alpha,beta -RepoRoot $repositoryRoot -Force } '*Recovery files retained*' }
    finally { Remove-Item -LiteralPath Function:\Move-Item -Force }
    $recoveryDirectories = @(Get-ChildItem -LiteralPath $repositoryRoot -Directory -Filter '.skillvault-remove-*')
    Assert-True ($recoveryDirectories.Count -eq 1) 'a failed restore keeps a recovery directory'
    $recoverableAlpha = Join-Path $recoveryDirectories[0].FullName 'alpha'
    Assert-True (Test-Path -LiteralPath (Join-Path $recoverableAlpha 'payload.bin')) 'failed recovery never discards the moved source'
    Assert-True ([System.IO.File]::ReadAllText($catalogPath) -ceq $originalCatalog) 'failed recovery leaves the original catalog unchanged'
    Move-Item -LiteralPath $recoverableAlpha -Destination $alphaPath
    Remove-Item -LiteralPath $recoveryDirectories[0].FullName -Recurse -Force

    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        $catalogLock = [System.IO.File]::Open($catalogPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        try { Assert-Throws { & $removeScript -Name alpha -RepoRoot $repositoryRoot -Force } '*source folders and catalog were restored*' }
        finally { $catalogLock.Dispose() }
        Assert-True ((Test-Path -LiteralPath $alphaPath) -and [System.IO.File]::ReadAllText($catalogPath) -ceq $originalCatalog) 'catalog replacement failure restores source folders'
    }

    & $removeScript -Name alpha,alpha -RepoRoot $repositoryRoot -Force | Out-Null
    $remaining = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
    Assert-True (-not (Test-Path -LiteralPath $alphaPath)) 'confirmed removal deletes the selected source'
    Assert-True ($remaining.Count -eq 2 -and $remaining[0].name -eq 'beta' -and $remaining[1].name -eq 'gamma') 'catalog remains sorted and excludes only selected names'
    Assert-True ($null -eq $remaining[0].version) 'explicit null versions survive catalog serialization'
    Assert-True ((Test-Path -LiteralPath (Join-Path $installedPath 'marker.txt')) -and (Test-Path -LiteralPath (Join-Path $otherRepositoryPath 'marker.txt'))) 'installed copies and other repositories are untouched'

    & $removeScript -Name beta -RepoRoot $repositoryRoot -Force | Out-Null
    Assert-True ([System.IO.File]::ReadAllText($catalogPath).TrimStart().StartsWith('[')) 'a one-entry catalog stays an array'
    & $removeScript -Name gamma -RepoRoot $repositoryRoot -Force | Out-Null
    $emptyCatalogText = [System.IO.File]::ReadAllText($catalogPath)
    $emptyCatalog = ConvertFrom-Json -InputObject $emptyCatalogText
    Assert-True ($emptyCatalogText.TrimStart().StartsWith('[') -and $emptyCatalog.Count -eq 0) 'removing the last skill leaves an empty JSON array'
    Assert-True (@(Get-ChildItem -LiteralPath $repositoryRoot -Directory -Filter '.skillvault-remove-*').Count -eq 0) 'successful removal leaves no recovery directories'
    Write-Output 'Source removal checks passed: preview, exact selection, containment, dependency checks, rollback, and installed-copy preservation.'
}
finally {
    Remove-Item -LiteralPath Function:\Move-Item -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name skillVaultRemoveFailurePath -Scope Global -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}