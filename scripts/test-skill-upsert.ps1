$ErrorActionPreference = 'Stop'
$resolveScript = Join-Path $PSScriptRoot '..\skills\core\skillvault-author\scripts\resolve-source-repo.ps1'
$installResolveScript = Join-Path $PSScriptRoot '..\skills\core\skillvault-install\scripts\resolve-source-repo.ps1'

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

function New-SourceFixture {
    param([string]$Path, [string]$Remote = 'https://github.com/wzlwit/skillvault.git')
    New-Item -ItemType Directory -Path (Join-Path $Path 'skills') -Force | Out-Null
    '[]' | Set-Content -LiteralPath (Join-Path $Path 'catalog.json') -Encoding utf8
    git init --quiet $Path
    if ($LASTEXITCODE -ne 0) { throw 'Fixture Git initialization failed.' }
    git -C $Path remote add origin $Remote
    if ($LASTEXITCODE -ne 0) { throw 'Fixture origin setup failed.' }
}

$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skill-upsert-test-' + [guid]::NewGuid().ToString('N'))
$projectPath = Join-Path $fixtureRoot 'working project'
$knownPath = Join-Path $fixtureRoot 'known checkout'
$cachePath = Join-Path $fixtureRoot 'source cache'
$explicitPath = Join-Path $fixtureRoot 'explicit checkout'
$foreignPath = Join-Path $fixtureRoot 'unrelated checkout'
$missingPath = Join-Path $fixtureRoot 'missing'

try {
    New-Item -ItemType Directory -Path $projectPath -Force | Out-Null
    New-SourceFixture -Path $knownPath
    New-SourceFixture -Path $cachePath
    New-SourceFixture -Path $explicitPath
    New-SourceFixture -Path $foreignPath -Remote 'https://github.com/wzlwit/skillvault-other.git'
    $markerPath = Join-Path $knownPath 'uncommitted.txt'
    'preserve local source work' | Set-Content -LiteralPath $markerPath
    $originalMarker = [System.IO.File]::ReadAllText($markerPath)
    $originalCatalog = [System.IO.File]::ReadAllText((Join-Path $knownPath 'catalog.json'))

    foreach ($workingPath in @($projectPath, $cachePath, $explicitPath)) {
        $installResult = & $installResolveScript -ProjectPath $workingPath -KnownRepoPath $knownPath -CachePath $cachePath
        Assert-True ($installResult.Selection -eq 'KnownCheckout' -and $installResult.RepoRoot -eq $knownPath) 'install selects the intended checkout even from another same-origin clone'
        Assert-True ($installResult.ProjectPath -eq $workingPath) 'install keeps the original target project separate'
        $installResult = & $installResolveScript -ProjectPath $workingPath -KnownRepoPath $missingPath -CachePath $cachePath
        Assert-True ($installResult.Status -eq 'NeedsSource' -and $null -eq $installResult.RepoRoot) 'install never silently substitutes a workspace clone or cache when the intended source is absent'
    }
    $installResult = & $installResolveScript -ProjectPath $projectPath -RepoPath '../explicit checkout' -KnownRepoPath $knownPath -CachePath $cachePath
    Assert-True ($installResult.Selection -eq 'Explicit' -and $installResult.RepoRoot -eq $explicitPath) 'install accepts a different verified checkout only through an explicit path'
    $installResult = & $installResolveScript -ProjectPath $cachePath -KnownRepoPath '' -CachePath $cachePath
    Assert-True ($installResult.Status -eq 'NeedsSource') 'install without a known path requires an explicit source on any platform'
    Assert-Throws { & $installResolveScript -ProjectPath $cachePath -KnownRepoPath $foreignPath -CachePath $cachePath } '*origin must identify*'
    Assert-Throws { & $installResolveScript -ProjectPath $projectPath -RepoPath $missingPath -KnownRepoPath $knownPath } '*does not exist*'
    Assert-Throws { & $installResolveScript -ProjectPath $projectPath -RepoPath $foreignPath -KnownRepoPath $knownPath } '*origin must identify*'
    Assert-Throws { & $installResolveScript -ProjectPath $projectPath -RepoPath '' -KnownRepoPath $knownPath } '*cannot be empty*'

    Push-Location $projectPath
    try { $result = & $resolveScript -KnownRepoPath $knownPath -CachePath $cachePath }
    finally { Pop-Location }
    Assert-True ($result.Status -eq 'Resolved' -and $result.Selection -eq 'KnownCheckout' -and $result.RepoRoot -eq $knownPath) 'another project selects the known checkout before the cache'
    Assert-True ($result.ProjectPath -eq $projectPath -and $result.SkillsPath -eq (Join-Path $knownPath 'skills')) 'source and working-project paths stay separate'

    $result = & $resolveScript -ProjectPath $knownPath -KnownRepoPath $explicitPath -CachePath $cachePath
    Assert-True ($result.Selection -eq 'Workspace' -and $result.RepoRoot -eq $knownPath) 'a verified SkillVault workspace wins by default'
    $result = & $resolveScript -ProjectPath $projectPath -RepoPath '../explicit checkout' -KnownRepoPath $knownPath -CachePath $cachePath
    Assert-True ($result.Selection -eq 'Explicit' -and $result.RepoRoot -eq $explicitPath) 'an explicit relative source resolves against the working project'
    Assert-Throws { & $resolveScript -ProjectPath $projectPath -RepoPath $missingPath -KnownRepoPath $knownPath -CachePath $cachePath } '*does not exist*'
    Assert-Throws { & $resolveScript -ProjectPath $projectPath -RepoPath '' -KnownRepoPath $knownPath -CachePath $cachePath } '*cannot be empty*'
    Assert-Throws { & $resolveScript -ProjectPath $projectPath -RepoPath $foreignPath -KnownRepoPath $knownPath -CachePath $cachePath } '*origin must identify*'

    $result = & $resolveScript -ProjectPath $foreignPath -KnownRepoPath $knownPath -CachePath $cachePath
    Assert-True ($result.Selection -eq 'KnownCheckout' -and $result.SkippedWorkspace -like '*origin must identify*') 'a lookalike working project is not treated as SkillVault'
    Assert-Throws { & $resolveScript -ProjectPath $projectPath -KnownRepoPath $foreignPath -CachePath $cachePath } '*origin must identify*'
    $result = & $resolveScript -ProjectPath $projectPath -KnownRepoPath $missingPath -CachePath $cachePath
    Assert-True ($result.Selection -eq 'Cache' -and $result.RepoRoot -eq $cachePath) 'the cache is used only when the known checkout is absent'
    Assert-Throws { & $resolveScript -ProjectPath $projectPath -KnownRepoPath $missingPath -CachePath $foreignPath } '*origin must identify*'

    $nestedPath = Join-Path $knownPath 'nested'
    New-Item -ItemType Directory -Path (Join-Path $nestedPath 'skills') -Force | Out-Null
    '[]' | Set-Content -LiteralPath (Join-Path $nestedPath 'catalog.json') -Encoding utf8
    Assert-Throws { & $resolveScript -ProjectPath $projectPath -RepoPath $nestedPath -KnownRepoPath $knownPath -CachePath $cachePath } '*Git checkout root*'
    Assert-Throws { & $resolveScript -ProjectPath $projectPath -RepoPath $projectPath -KnownRepoPath $knownPath -CachePath $cachePath } '*lacks catalog.json*'

    foreach ($remote in @('https://github.com/wzlwit/skillvault/', 'git@github.com:wzlwit/skillvault.git', 'ssh://git@github.com/wzlwit/skillvault.git')) {
        git -C $explicitPath remote set-url origin $remote
        if ($LASTEXITCODE -ne 0) { throw 'Fixture origin update failed.' }
        $result = & $resolveScript -ProjectPath $projectPath -RepoPath $explicitPath -KnownRepoPath $missingPath -CachePath $missingPath
        Assert-True ($result.RepoRoot -eq $explicitPath) 'standard HTTPS and SSH origin forms identify the same repository'
    }
    git -C $explicitPath remote remove origin
    if ($LASTEXITCODE -ne 0) { throw 'Fixture origin removal failed.' }
    Assert-Throws { & $resolveScript -ProjectPath $projectPath -RepoPath $explicitPath -KnownRepoPath $knownPath -CachePath $cachePath } '*Git remote failed*'

    $result = & $resolveScript -ProjectPath $projectPath -KnownRepoPath $missingPath -CachePath $missingPath
    Assert-True ($result.Status -eq 'NeedsSource' -and $null -eq $result.RepoRoot -and $null -eq $result.CatalogPath) 'no source returns an explicit decision state, not the working project'
    Assert-True (-not (Test-Path -LiteralPath $missingPath)) 'resolution never creates a cache or clones a repository'
    Assert-True (@(Get-ChildItem -LiteralPath $projectPath -Force).Count -eq 0) 'resolution writes nothing into the unrelated working project'
    Assert-True ([System.IO.File]::ReadAllText($markerPath) -ceq $originalMarker) 'dirty source work remains untouched'
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $knownPath 'catalog.json')) -ceq $originalCatalog) 'resolution does not modify the source catalog'

    $checkScript = Join-Path $PSScriptRoot '..\skills\core\skillvault-author\scripts\check-origins.ps1'
    $originRepo = Join-Path $fixtureRoot 'origin source'
    $vaultPath = Join-Path $fixtureRoot 'vault checkout'
    $commitArgs = @('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgSign=false', '-c', "core.hooksPath=$fixtureRoot/no-hooks", 'commit', '--quiet', '-m')
    git init --quiet $originRepo
    New-Item -ItemType Directory -Path (Join-Path $originRepo 'skills/source') -Force | Out-Null
    'first' | Set-Content -LiteralPath (Join-Path $originRepo 'skills/source/SKILL.md')
    git -C $originRepo add --all
    git -C $originRepo @commitArgs 'first version'
    $recorded = [string](git -C $originRepo rev-parse HEAD)
    'unrelated' | Set-Content -LiteralPath (Join-Path $originRepo 'other.txt')
    git -C $originRepo add --all
    git -C $originRepo @commitArgs 'unrelated change'
    git -C $originRepo remote add origin 'git@git.example.invalid:Team/Source.git'
    git -C $originRepo update-ref refs/remotes/origin/develop HEAD
    New-SourceFixture -Path $vaultPath
    New-Item -ItemType Directory -Path (Join-Path $vaultPath 'skills/data/derived') -Force | Out-Null
    '[{"name":"derived","description":"Derived fixture","path":"skills/data/derived","version":"1.0.0"}]' | Set-Content -LiteralPath (Join-Path $vaultPath 'catalog.json')
    $manifestPath = Join-Path $vaultPath 'skills/data/derived/skill.json'
    $writeOrigins = {
        param([string]$Commit)
        (@{ name = 'derived'; origins = @(
                    [ordered]@{ repo = 'https://git.example.invalid/team/source'; branch = 'develop'; path = 'skills/source'; commit = $Commit },
                    [ordered]@{ repo = 'https://git.example.invalid/other/missing'; branch = 'main'; path = 'x'; commit = ('f' * 40) }
                ) } | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $manifestPath
    }
    & $writeOrigins $recorded
    $manifestBefore = [System.IO.File]::ReadAllText($manifestPath)
    $check = @(& $checkScript -RepoPath $vaultPath -Checkout $originRepo -Json | ConvertFrom-Json | ForEach-Object { $_ })
    Assert-True ($check.Count -eq 2 -and $check[0].status -eq 'Current' -and $check[0].latest) 'a commit outside the origin path leaves it current, and an SSH clone matches its HTTPS origin URL'
    Assert-True ($check[1].status -eq 'NoCheckout') 'an origin without a local clone is reported, not guessed'
    Assert-True ($check[0].local -eq '') 'a clean clone reports no local changes'
    'second' | Set-Content -LiteralPath (Join-Path $originRepo 'skills/source/SKILL.md')
    $check = @(& $checkScript -RepoPath $vaultPath -Name derived -Checkout $originRepo -Diff -Json | ConvertFrom-Json | ForEach-Object { $_ })
    Assert-True ($check[0].status -eq 'Current' -and $check[0].local -eq 'uncommitted edits' -and $check[0].localDiff -match '\+second') 'an uncommitted edit to the origin is reported with its diff, while the branch stays current'
    Assert-True ((& $checkScript -RepoPath $vaultPath -Checkout $originRepo | Out-String) -match 'derived: .*Current; in .*: uncommitted edits') 'the text report names local edits'
    git -C $originRepo add --all
    git -C $originRepo @commitArgs 'improve the source skill'
    $check = @(& $checkScript -RepoPath $vaultPath -Name derived -Checkout $originRepo -Json | ConvertFrom-Json | ForEach-Object { $_ })
    Assert-True ($check[0].status -eq 'Current' -and $check[0].local -eq '1 commit(s) not on develop') 'a local commit that has not reached the branch is reported'
    git -C $originRepo update-ref refs/remotes/origin/develop HEAD
    $check = @(& $checkScript -RepoPath $vaultPath -Name derived -Checkout $originRepo -Diff -Json | ConvertFrom-Json | ForEach-Object { $_ })
    Assert-True ($check[0].status -eq 'Changed' -and @($check[0].commits).Count -eq 1 -and $check[0].commits[0].subject -eq 'improve the source skill') 'a commit to the origin path is listed'
    Assert-True ($check[0].local -eq '' -and -not $check[0].localDiff) 'once the branch has the commit, nothing is local'
    Assert-True ($check[0].diff -match '\+second') 'the diff shows what changed'
    Assert-True ((& $checkScript -RepoPath $vaultPath -Checkout $originRepo | Out-String) -match 'derived: .* 1 new commit') 'the text report counts the new commits'
    git -C $originRepo rm --quiet -r skills/source
    git -C $originRepo @commitArgs 'remove the source skill'
    git -C $originRepo update-ref refs/remotes/origin/develop HEAD
    Assert-True ((@(& $checkScript -RepoPath $vaultPath -Checkout $originRepo -Json | ConvertFrom-Json | ForEach-Object { $_ }))[0].status -eq 'Removed') 'a removed origin is reported'
    Assert-True ([System.IO.File]::ReadAllText($manifestPath) -ceq $manifestBefore) 'the check never rewrites the recorded commit'
    & $writeOrigins ('e' * 40)
    Assert-True ((@(& $checkScript -RepoPath $vaultPath -Checkout $originRepo -Json | ConvertFrom-Json | ForEach-Object { $_ }))[0].status -eq 'UnknownCommit') 'a recorded commit missing from the clone is reported'
    Assert-Throws { & $checkScript -RepoPath $vaultPath -Name missing } '*Not in the catalog*'
    Write-Output 'Source checks passed: install requires the intended or explicit checkout without clone/cache fallback; upsert retains its selection order. Git identity, separate project paths, and read-only resolution verified using temporary repositories only.'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}