$ErrorActionPreference = 'Stop'

# Real Git against local bare repositories. An isolated Git configuration maps the fixture URLs to
# those repositories, so no network, user configuration, or real checkout is touched.
. (Join-Path $PSScriptRoot '../skills/core/skillvault-installation/scripts/skill-files.ps1')
$refreshScript = Join-Path $PSScriptRoot '../skills/core/skillvault-refresh/scripts/skillvault-fresh.ps1'
$installScript = Join-Path $PSScriptRoot 'install-skills.ps1'
$verifyScript = Join-Path $PSScriptRoot 'verify-installed-skills.ps1'
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-sync-test-' + [guid]::NewGuid().ToString('N'))
$savedEnvironment = @{}
foreach ($variable in @('GIT_CONFIG_GLOBAL', 'GIT_CONFIG_NOSYSTEM', 'SKILLVAULT_OWNERSHIP_ROOT', 'SKILLVAULT_TRANSACTION_ROOT')) {
    $savedEnvironment[$variable] = [Environment]::GetEnvironmentVariable($variable)
}
$upstreamUrl = 'https://example.invalid/upstream.git'
$vaultUrl = 'https://example.invalid/vault.git'
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Test-Throws {
    param([scriptblock]$Script, [string]$Like = '*')
    try { & $Script | Out-Null; return $false } catch { return $_.Exception.Message -like $Like }
}

function Invoke-FixtureGit {
    $ErrorActionPreference = 'Continue'
    $output = @(git @args 2>&1 | ForEach-Object { [string]$_ })
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed: $($output -join ' ')" }
    return $output
}

function Set-FixtureFile {
    param([string]$Path, [string]$Text)
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Add-FixtureLine {
    param([string]$Path, [string]$Line)
    [System.IO.File]::AppendAllText($Path, "$Line`n", $utf8)
}

function Read-FixtureText {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path)
}

function Save-FixtureCommit {
    param([string]$Repo, [string]$Message)
    Invoke-FixtureGit -C $Repo add --all | Out-Null
    Invoke-FixtureGit -C $Repo commit -q -m $Message | Out-Null
}

function Publish-Upstream {
    param([string]$Label, [scriptblock]$Change)
    if ($Change) { & $Change }
    else { Set-FixtureFile (Join-Path $upstreamWork 'skills/up/SKILL.md') "---`nname: up-ref`ndescription: Upstream fixture`n---`n# Original $Label`n`nBody text.`n" }
    Save-FixtureCommit $upstreamWork $Label
    Invoke-FixtureGit -C $upstreamWork push -q $upstreamBare main | Out-Null
}

function Set-UpstreamAdapt {
    param([string]$Last, [string]$Description = 'Upstream adapt')
    Set-FixtureFile (Join-Path $upstreamWork 'skills/ad/SKILL.md') "---`nname: adapt`ndescription: $Description`n---`n# Adapt`nfirst line`nmiddle line`n$Last`n"
}

function Edit-OtherFile {
    param([string]$RelativePath, [string]$Pattern, [string]$Replacement)
    $path = Join-Path $otherClone $RelativePath
    Set-FixtureFile $path ((Read-FixtureText $path) -replace $Pattern, $Replacement)
}

function Push-OtherChange {
    param([scriptblock]$Change, [string]$Message)
    Invoke-FixtureGit -C $otherClone pull -q --ff-only | Out-Null
    & $Change
    Save-FixtureCommit $otherClone $Message
    Invoke-FixtureGit -C $otherClone push -q origin HEAD | Out-Null
}

function Invoke-Refresh {
    $json = & $refreshScript -RunOnce -ResultJson -GlobalSkillsPath $globalRoot -CachePath $cacheRoot
    return ($json | Out-String | ConvertFrom-Json)
}

function Get-Unresolved {
    param($Result, [string]$Name)
    return @($Result.unresolved | Where-Object { $_.name -ceq $Name })
}

function Get-Head {
    param([string]$Repo, [string]$Ref = 'HEAD')
    return @(Invoke-FixtureGit -C $Repo rev-parse $Ref)[0]
}

try {
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
    $env:SKILLVAULT_OWNERSHIP_ROOT = Join-Path $fixtureRoot 'ownership'
    $env:SKILLVAULT_TRANSACTION_ROOT = Join-Path $fixtureRoot 'updates'
    $env:GIT_CONFIG_GLOBAL = Join-Path $fixtureRoot 'gitconfig'
    $env:GIT_CONFIG_NOSYSTEM = '1'
    New-Item -ItemType File -Path $env:GIT_CONFIG_GLOBAL -Force | Out-Null
    $upstreamWork = Join-Path $fixtureRoot 'upstream-work'
    $upstreamBare = Join-Path $fixtureRoot 'upstream.git'
    $vaultWork = Join-Path $fixtureRoot 'vault-work'
    $vaultBare = Join-Path $fixtureRoot 'vault.git'
    $checkout = Join-Path $fixtureRoot 'checkout'
    $otherClone = Join-Path $fixtureRoot 'other'
    $globalRoot = Join-Path $fixtureRoot 'global'
    $originRoot = Join-Path $fixtureRoot 'origin-global'
    $cacheRoot = Join-Path $fixtureRoot 'cache'
    $projectRoot = Join-Path $fixtureRoot 'project'
    $settings = [ordered]@{
        'user.name' = 'SkillVault Fixture'
        'user.email' = 'fixture@example.invalid'
        'init.defaultBranch' = 'main'
        'core.autocrlf' = 'false'
        'advice.detachedHead' = 'false'
        "url.$($upstreamBare -replace '\\', '/').insteadOf" = $upstreamUrl
        "url.$($vaultBare -replace '\\', '/').insteadOf" = $vaultUrl
    }
    foreach ($key in $settings.Keys) { Invoke-FixtureGit config --global $key $settings[$key] | Out-Null }
    New-Item -ItemType Directory -Path $globalRoot, $projectRoot -Force | Out-Null

    # Unit checks: three-way folder merge and reference content rules.
    $unitRoot = Join-Path $fixtureRoot 'unit'
    foreach ($side in @('base', 'ours', 'theirs')) {
        Set-FixtureFile (Join-Path $unitRoot "$side/kept.md") "same`n"
        Set-FixtureFile (Join-Path $unitRoot "$side/SKILL.md") "one`ntwo`nthree`n"
    }
    Set-FixtureFile (Join-Path $unitRoot 'ours/SKILL.md') "one local`r`ntwo`r`nthree`r`n"
    Set-FixtureFile (Join-Path $unitRoot 'theirs/SKILL.md') "one`ntwo`nthree remote`n"
    Set-FixtureFile (Join-Path $unitRoot 'ours/kept.md') "same`r`n"
    Set-FixtureFile (Join-Path $unitRoot 'base/removed.md') "old`n"
    Set-FixtureFile (Join-Path $unitRoot 'ours/removed.md') "old`n"
    Set-FixtureFile (Join-Path $unitRoot 'theirs/added.md') "new`n"
    $conflicts = Merge-SkillFolder -Base (Join-Path $unitRoot 'base') -Ours (Join-Path $unitRoot 'ours') -Theirs (Join-Path $unitRoot 'theirs') -Destination (Join-Path $unitRoot 'merged')
    Assert-True ($conflicts.Count -eq 0) 'separate edits to one file merge cleanly'
    Assert-True ((Read-FixtureText (Join-Path $unitRoot 'merged/SKILL.md')) -ceq "one local`ntwo`nthree remote`n") 'a merged file has both edits in the committed line endings'
    Assert-True ((Read-FixtureText (Join-Path $unitRoot 'merged/kept.md')) -ceq "same`n") 'a line-ending-only difference is not a change'
    Assert-True ((Test-Path (Join-Path $unitRoot 'merged/added.md')) -and -not (Test-Path (Join-Path $unitRoot 'merged/removed.md'))) 'committed additions and deletions are applied'
    Set-FixtureFile (Join-Path $unitRoot 'ours/SKILL.md') "one`ntwo`nthree local`n"
    $conflicts = Merge-SkillFolder -Base (Join-Path $unitRoot 'base') -Ours (Join-Path $unitRoot 'ours') -Theirs (Join-Path $unitRoot 'theirs') -Destination (Join-Path $unitRoot 'merged-conflict')
    Assert-True (($conflicts -join ',') -ceq 'SKILL.md') 'edits to the same line conflict'

    $unitUpstream = Join-Path $unitRoot 'upstream-repo'
    Set-FixtureFile (Join-Path $unitUpstream 'skills/x/SKILL.md') "---`nname: x`ndescription: Fixture`n---`nline`n"
    Invoke-FixtureGit init -q $unitUpstream | Out-Null
    Save-FixtureCommit $unitUpstream 'one'
    $unitBase = Get-Head $unitUpstream
    Add-FixtureLine (Join-Path $unitUpstream 'skills/x/SKILL.md') 'more'
    Save-FixtureCommit $unitUpstream 'two'
    $unitHead = Get-Head $unitUpstream
    $unitAdaptation = Join-Path $unitRoot 'x'
    Set-FixtureFile (Join-Path $unitAdaptation 'skill.json') "{`"name`":`"x`",`"version`":null,`"upstream`":{`"commit`":`"$unitBase`"}}"
    Set-FixtureFile (Join-Path $unitAdaptation 'SKILL.md') "---`nname: x`ndescription: Ours`n---`n# Ours`n"
    $unitManifest = [pscustomobject]@{ name = 'x'; upstream = [pscustomobject]@{ repo = $upstreamUrl; path = 'skills/x'; version = 'latest'; commit = $unitBase } }
    $merge = @{ SkillPath = $unitAdaptation; Manifest = $unitManifest; UpstreamRoot = $unitUpstream; Commit = $unitHead }
    Assert-True (Test-Throws { Merge-SkillAdaptation @merge } '*No license*') 'upstream changes are not copied without a license'
    Set-FixtureFile (Join-Path $unitUpstream 'LICENSE') "MIT`n"
    Assert-True (Test-Throws { Merge-SkillAdaptation @merge } '*exactly one*') 'an adaptation without its original section is rejected'
    Set-FixtureFile (Join-Path $unitAdaptation 'SKILL.md') "---`nname: x`ndescription: Ours`n---`n# Ours`n<!-- upstream:begin -->`n<!-- upstream:end -->`n"
    $result = Merge-SkillAdaptation @merge
    $unitText = Read-FixtureText (Join-Path $unitAdaptation 'SKILL.md')
    Assert-True ($result.Changed -and $unitText.StartsWith("---`nname: x`ndescription: Ours`n---`n# Ours`n<!-- upstream:begin -->") -and
        $unitText.EndsWith("`n`nline`nmore`n<!-- upstream:end -->`n") -and $unitText -notlike '*description: Fixture*') 'the new original fills its section and our changes stay'
    Assert-True ((Read-FixtureText (Join-Path $unitAdaptation 'skill.json')) -like "*`"commit`":`"$unitHead`"*" -and (Test-Path (Join-Path $unitAdaptation 'UPSTREAM-LICENSE'))) 'the merged commit and the license are recorded'

    $unitReference = Join-Path $unitRoot 'ref'
    Set-FixtureFile (Join-Path $unitReference 'skill.json') (ConvertTo-Json -Depth 5 -InputObject ([ordered]@{ name = 'ref'; version = $null; kind = 'reference'
        upstream = [ordered]@{ repo = $upstreamUrl; path = 'skills/up'; version = 'latest' }; install = [ordered]@{ strategy = 'upstream' } }))
    Assert-True (Test-Throws { Read-SkillManifest -SkillPath $unitReference -ExpectedName ref } '*is a reference*') 'copying a bundle rejects a reference'
    Assert-True ((Read-SkillManifest -SkillPath $unitReference -ExpectedName ref -AllowReference).kind -ceq 'reference') 'a caller that fetches originals can read a reference'
    Set-FixtureFile (Join-Path $unitReference 'SKILL.md') "---`nname: ref`n---`n"
    Assert-True (Test-Throws { Read-SkillManifest -SkillPath $unitReference -ExpectedName ref -AllowReference } '*keeps no SKILL.md*') 'a reference with its own SKILL.md is rejected'

    # Fixture repositories: an upstream with two skills, and a SkillVault repository with plain skills,
    # a reference (up-ref), and an adapted skill (adapt).
    Set-FixtureFile (Join-Path $upstreamWork 'LICENSE') "MIT License`n`nFixture.`n"
    Set-FixtureFile (Join-Path $upstreamWork 'skills/up/SKILL.md') "---`nname: up-ref`ndescription: Upstream fixture`n---`n# Original v1`n`nBody text.`n"
    Set-UpstreamAdapt -Last 'last line v1'
    Invoke-FixtureGit init -q $upstreamWork | Out-Null
    Save-FixtureCommit $upstreamWork 'v1'
    Invoke-FixtureGit -C $upstreamWork tag v1 | Out-Null
    Invoke-FixtureGit clone -q --bare $upstreamWork $upstreamBare | Out-Null
    $upstreamV1 = Get-Head $upstreamWork

    $catalog = foreach ($name in @('adapt', 'conf', 'plain', 'up-ref')) { [ordered]@{ name = $name; description = "Fixture $name"; path = "skills/core/$name"; version = $null } }
    Set-FixtureFile (Join-Path $vaultWork 'catalog.json') (ConvertTo-Json -InputObject @($catalog) -Depth 5)
    foreach ($name in @('conf', 'plain')) {
        Set-FixtureFile (Join-Path $vaultWork "skills/core/$name/skill.json") (ConvertTo-Json -InputObject ([ordered]@{ name = $name; version = $null; description = "Fixture $name" }))
        Set-FixtureFile (Join-Path $vaultWork "skills/core/$name/SKILL.md") "---`nname: $name`ndescription: Fixture $name`n---`n# $name`nline one`n"
    }
    Set-FixtureFile (Join-Path $vaultWork 'skills/core/up-ref/skill.json') (ConvertTo-Json -Depth 5 -InputObject ([ordered]@{
        name = 'up-ref'; version = $null; kind = 'reference'; upstream = [ordered]@{ repo = $upstreamUrl; path = 'skills/up'; version = 'latest' }
        install = [ordered]@{ defaultScope = 'global'; strategy = 'upstream' } }))
    Set-FixtureFile (Join-Path $vaultWork 'skills/core/adapt/skill.json') (ConvertTo-Json -Depth 5 -InputObject ([ordered]@{
        name = 'adapt'; version = $null; kind = 'agent'; upstream = [ordered]@{ repo = $upstreamUrl; path = 'skills/ad'; version = 'latest'; commit = $upstreamV1 }
        install = [ordered]@{ defaultScope = 'global'; strategy = 'adapted' } }))
    Set-FixtureFile (Join-Path $vaultWork 'skills/core/adapt/SKILL.md') "---`nname: adapt`ndescription: Our adaptation`n---`n# Adapt (ours)`nOur note.`n<!-- upstream:begin -->`n<!-- upstream:end -->`n"
    Copy-Item -LiteralPath (Join-Path $upstreamWork 'LICENSE') -Destination (Join-Path $vaultWork 'skills/core/adapt/UPSTREAM-LICENSE')
    Invoke-FixtureGit init -q $vaultWork | Out-Null
    Save-FixtureCommit $vaultWork 'initial'
    Invoke-FixtureGit clone -q --bare $vaultWork $vaultBare | Out-Null
    Invoke-FixtureGit clone -q $vaultUrl $checkout | Out-Null
    Invoke-FixtureGit clone -q $vaultUrl $otherClone | Out-Null
    $checkoutPath = [System.IO.Path]::GetFullPath($checkout).TrimEnd([char[]]'\/')
    $install = @{ RepoRoot = $checkout; ProjectPath = $projectRoot; GlobalSkillsPath = $globalRoot; Scope = 'global'; SourceRepo = $vaultUrl; UpstreamCachePath = (Join-Path $fixtureRoot 'install-cache') }

    # Install: the adaptation by default, the original for a reference or on request.
    $preview = @(& $installScript -Name adapt, up-ref @install -Preview | ConvertFrom-Json)
    $referencePreview = $preview | Where-Object Name -CEQ 'up-ref'
    Assert-True (($preview | Where-Object Name -CEQ 'adapt').Variant -ceq 'adapt' -and $referencePreview.Variant -ceq 'origin' -and
        $referencePreview.Commit -ceq $upstreamV1 -and (@($referencePreview.Files) -join ',') -ceq 'SKILL.md') 'preview shows the adaptation by default, and the commit and files of an original'
    Assert-True (@(Get-ChildItem -LiteralPath $globalRoot -Force).Count -eq 0) 'preview installs nothing'
    $originPreview = @(& $installScript -Name adapt @install -Variant origin -Preview | ConvertFrom-Json)
    Assert-True ($originPreview[0].Variant -ceq 'origin' -and $originPreview[0].UpstreamPath -ceq 'skills/ad') 'origin selects the original of an adapted skill'
    Assert-True (Test-Throws { & $installScript -Name up-ref @install -Variant adapt -Preview } '*no adaptation*') 'adapt needs an adaptation'
    Assert-True (Test-Throws { & $installScript -Name plain @install -Variant origin -Preview } '*no upstream original*') 'origin needs an upstream source'

    & $installScript -Name adapt, conf, plain, up-ref @install | Out-Null
    $plainMetadata = Get-Content -LiteralPath (Join-Path $globalRoot 'plain/.skillvault-install.json') -Raw | ConvertFrom-Json
    Assert-True ($plainMetadata.sourceCheckout -ceq $checkoutPath -and $plainMetadata.sourceRevision -ceq (Get-Head $checkout 'HEAD:skills/core/plain')) "install records the checkout and its committed version as the merge base: $($plainMetadata | ConvertTo-Json -Compress)"
    $referenceMetadata = Get-Content -LiteralPath (Join-Path $globalRoot 'up-ref/.skillvault-install.json') -Raw | ConvertFrom-Json
    Assert-True ($referenceMetadata.sourceType -ceq 'upstream' -and $referenceMetadata.sourceRepo -ceq $upstreamUrl -and $referenceMetadata.sourcePath -ceq 'skills/up' -and
        $referenceMetadata.requestedVersion -ceq 'latest' -and $referenceMetadata.sourceRevision -ceq (Get-Head $upstreamWork 'HEAD:skills/up')) 'an original records its upstream source and revision'
    Assert-True ((Read-FixtureText (Join-Path $globalRoot 'up-ref/SKILL.md')) -like '*# Original v1*' -and -not (Test-Path (Join-Path $globalRoot 'up-ref/skill.json'))) 'a reference installs the original as-is'
    Assert-True ((Read-FixtureText (Join-Path $globalRoot 'adapt/SKILL.md')) -like '*Our note.*') 'an adapted skill installs the adaptation by default'
    $originInstall = @{} + $install
    $originInstall.GlobalSkillsPath = $originRoot
    & $installScript -Name adapt @originInstall -Variant origin | Out-Null
    Assert-True ((Read-FixtureText (Join-Path $originRoot 'adapt/SKILL.md')) -like '*description: Upstream adapt*') 'origin installs the original of an adapted skill'
    $verified = @(& $verifyScript -RepoRoot $checkout -SkillsPath $globalRoot -Name up-ref)
    Assert-True (($verified -join ' ') -like '*1 of them install an original*') 'verification checks an original by its recorded source'

    # Refresh 1 merges upstream changes into the adaptation and pushes; refresh 2 brings them to the checkout and installed copies.
    $result = Invoke-Refresh
    Assert-True ($result.status -ceq 'Succeeded' -and @(Invoke-FixtureGit -C $vaultBare rev-list main).Count -eq 1) "an unchanged upstream adds no commits: $($result | ConvertTo-Json -Depth 5 -Compress)"
    Publish-Upstream 'ad v2' { Set-UpstreamAdapt -Last 'last line v2' }
    $upstreamV2 = Get-Head $upstreamWork
    $result = Invoke-Refresh
    Assert-True ($result.status -ceq 'Succeeded') "an upstream change merges: $($result | ConvertTo-Json -Depth 5 -Compress)"
    $subjects = @(Invoke-FixtureGit -C $vaultBare log --format=%s main)
    Assert-True (@($subjects -ceq "refresh: merge example.invalid/upstream@$($upstreamV2.Substring(0, 7)) into adapt").Count -eq 1) 'refresh 1 commits the merge and pushes it'
    Assert-True ((Get-Head $checkout) -ceq (Get-Head $vaultBare 'main') -and -not (Invoke-FixtureGit -C $checkout status --porcelain)) 'refresh 2 fast-forwards a clean checkout'
    $adaptText = Read-FixtureText (Join-Path $globalRoot 'adapt/SKILL.md')
    Assert-True ($adaptText -like '*Our note.*' -and $adaptText -like '*last line v2*' -and $adaptText -like '*description: Our adaptation*') 'the installed adaptation keeps our changes and gets the upstream change'
    Assert-True ((Read-FixtureText (Join-Path $checkout 'skills/core/adapt/skill.json')) -like "*$upstreamV2*") 'the adaptation records the merged upstream commit'

    $commitCount = @(Invoke-FixtureGit -C $vaultBare rev-list main).Count
    Publish-Upstream 'up v2'
    $result = Invoke-Refresh
    Assert-True ($result.status -ceq 'Succeeded' -and @(Invoke-FixtureGit -C $vaultBare rev-list main).Count -eq $commitCount) 'an upstream change outside the adapted folder adds no commit'
    Assert-True ((Read-FixtureText (Join-Path $globalRoot 'up-ref/SKILL.md')) -like '*# Original up v2*') "an installed original follows upstream: $($result.messages -join ' | ')"
    Add-FixtureLine (Join-Path $globalRoot 'up-ref/SKILL.md') 'local note'
    Publish-Upstream 'up v3'
    $result = Invoke-Refresh
    $referenceText = Read-FixtureText (Join-Path $globalRoot 'up-ref/SKILL.md')
    Assert-True ($referenceText -like '*# Original up v3*' -and $referenceText -like '*local note*' -and
        @($result.messages -like 'Updated: up-ref*merged with your local changes*').Count -eq 1) 'local edits to an installed original are merged with upstream changes'

    # A pinned adaptation merges to its pin.
    Push-OtherChange { Edit-OtherFile 'skills/core/adapt/skill.json' '"version": "latest"' '"version": "v1"' } 'pin adapt'
    $result = Invoke-Refresh
    Assert-True ($result.status -ceq 'Succeeded' -and (Read-FixtureText (Join-Path $globalRoot 'adapt/SKILL.md')) -like '*last line v1*') "an adaptation follows its pinned upstream version: $($result | ConvertTo-Json -Depth 5 -Compress)"
    Push-OtherChange { Edit-OtherFile 'skills/core/adapt/skill.json' '"version": "v1"' '"version": "latest"' } 'unpin adapt'

    # Upstream edits merge automatically, even to its own frontmatter; only an upstream file the adaptation also edited can conflict.
    Publish-Upstream 'ad description' { Set-UpstreamAdapt -Last 'last line v2' -Description 'Upstream renamed' }
    $result = Invoke-Refresh
    $adaptText = Read-FixtureText (Join-Path $globalRoot 'adapt/SKILL.md')
    Assert-True ($result.status -ceq 'Succeeded' -and $adaptText -like '*description: Our adaptation*' -and $adaptText -like '*last line v2*' -and
        $adaptText -notlike '*Upstream renamed*') "an upstream edit merges automatically: $($result | ConvertTo-Json -Depth 5 -Compress)"
    Publish-Upstream 'notes v1' { Set-FixtureFile (Join-Path $upstreamWork 'skills/ad/notes.md') "note v1`n" }
    $result = Invoke-Refresh
    Assert-True ($result.status -ceq 'Succeeded' -and (Read-FixtureText (Join-Path $globalRoot 'adapt/notes.md')) -ceq "note v1`n") 'a new upstream file joins the adaptation'
    Push-OtherChange { Set-FixtureFile (Join-Path $otherClone 'skills/core/adapt/notes.md') "note ours`n" } 'edit notes'
    Publish-Upstream 'notes v2' { Set-FixtureFile (Join-Path $upstreamWork 'skills/ad/notes.md') "note v2`n" }
    $commitCount = @(Invoke-FixtureGit -C $vaultBare rev-list main).Count
    $result = Invoke-Refresh
    Assert-True ($result.status -ceq 'Deferred' -and (Get-Unresolved $result 'adapt').reason -ceq 'AdaptationConflict: notes.md' -and
        @(Invoke-FixtureGit -C $vaultBare rev-list main).Count -eq $commitCount) 'only an upstream file the adaptation also edited can conflict, and nothing is committed'
    Push-OtherChange { Set-FixtureFile (Join-Path $otherClone 'skills/core/adapt/notes.md') "note v1`n" } 'undo our notes edit'
    $result = Invoke-Refresh
    Assert-True ($result.status -ceq 'Succeeded' -and (Read-FixtureText (Join-Path $globalRoot 'adapt/notes.md')) -ceq "note v2`n") "undoing the SkillVault change lets the next refresh merge: $($result | ConvertTo-Json -Depth 5 -Compress)"

    # Uncommitted development work that was already installed is merged, not overwritten.
    Add-FixtureLine (Join-Path $checkout 'skills/core/plain/SKILL.md') 'dev note'
    & $installScript -Name plain @install -Force | Out-Null
    Push-OtherChange { Set-FixtureFile (Join-Path $otherClone 'skills/core/plain/extra.md') "extra`n" } 'add extra'
    $result = Invoke-Refresh
    Assert-True ($result.status -ceq 'Succeeded') "a non-overlapping change refreshes: $($result | ConvertTo-Json -Depth 5 -Compress)"
    Assert-True ((Read-FixtureText (Join-Path $globalRoot 'plain/SKILL.md')) -like '*dev note*' -and (Test-Path -LiteralPath (Join-Path $globalRoot 'plain/extra.md'))) 'the installed copy keeps the development work and gets the committed change'
    Assert-True (@($result.messages -like 'Updated: plain*merged with your local changes*').Count -eq 1) 'the report says local changes were merged'
    Assert-True ((Read-FixtureText (Join-Path $checkout 'skills/core/plain/SKILL.md')) -like '*dev note*') 'the checkout keeps its uncommitted work'
    $result = Invoke-Refresh
    Assert-True (@($result.messages -like 'Updated: plain*').Count -eq 0) 'a merged copy that matches the working copy is left alone'

    # Edits to the same lines wait for a decision.
    Add-FixtureLine (Join-Path $globalRoot 'conf/SKILL.md') 'installed edit'
    Push-OtherChange { Add-FixtureLine (Join-Path $otherClone 'skills/core/conf/SKILL.md') 'remote edit' } 'remote edit'
    $result = Invoke-Refresh
    $confText = Read-FixtureText (Join-Path $globalRoot 'conf/SKILL.md')
    Assert-True ($result.status -ceq 'Deferred' -and (Get-Unresolved $result 'conf').reason -ceq 'MergeConflict: SKILL.md') 'a conflicting installed edit is deferred'
    Assert-True ($confText -like '*installed edit*' -and $confText -notlike '*remote edit*') 'a deferred copy is left unchanged'

    # A checkout whose commits conflict with GitHub is left as it was.
    Invoke-FixtureGit -C $checkout commit -q -am 'local dev note' | Out-Null
    $localHead = Get-Head $checkout
    Push-OtherChange { Add-FixtureLine (Join-Path $otherClone 'skills/core/plain/SKILL.md') 'other note' } 'other note'
    $result = Invoke-Refresh
    Assert-True ((Get-Unresolved $result "checkout:$checkoutPath").reason -ceq 'CheckoutConflict') 'a conflicting checkout merge is reported'
    $mergeHead = & { $ErrorActionPreference = 'Continue'; git -C $checkout rev-parse -q --verify MERGE_HEAD 2>$null; $LASTEXITCODE }
    Assert-True ((Get-Head $checkout) -ceq $localHead -and $mergeHead[-1] -ne 0 -and -not (Invoke-FixtureGit -C $checkout status --porcelain)) 'the conflicting merge is aborted and the checkout is unchanged'

    Invoke-FixtureGit -C $checkout reset -q --hard origin/main | Out-Null
    & $installScript -Name conf, plain @install -Force | Out-Null
    Invoke-FixtureGit -C $checkout switch -q -c feature | Out-Null
    $result = Invoke-Refresh
    Assert-True ((Get-Unresolved $result 'plain').reason -ceq 'CheckoutOnOtherBranch') 'installs wait while the checkout is on another branch'
    Invoke-FixtureGit -C $checkout switch -q main | Out-Null

    # Publishing needs permission: without it nothing is merged; the checkout push URL is a fallback.
    Publish-Upstream 'ad v3' { Set-UpstreamAdapt -Last 'last line v3' -Description 'Upstream renamed' }
    $missingRemote = (Join-Path $fixtureRoot 'missing.git') -replace '\\', '/'
    Invoke-FixtureGit config --global "url.$missingRemote.pushInsteadOf" $vaultUrl | Out-Null
    $mainBefore = Get-Head $vaultBare 'main'
    $result = Invoke-Refresh
    Assert-True ($result.status -ceq 'Succeeded' -and @($result.messages -like '*no permission*').Count -eq 1) 'without push permission the adaptation update is skipped'
    Assert-True ((Get-Head $vaultBare 'main') -ceq $mainBefore -and (Read-FixtureText (Join-Path $globalRoot 'adapt/SKILL.md')) -like '*last line v2*') 'a skipped update changes nothing'
    Invoke-FixtureGit -C $checkout config remote.origin.pushurl ($vaultBare -replace '\\', '/') | Out-Null
    $result = Invoke-Refresh
    Assert-True ($result.status -ceq 'Succeeded' -and (Get-Head $vaultBare 'main') -cne $mainBefore) 'the checkout push URL publishes when the refresh clone cannot'
    Assert-True ((Read-FixtureText (Join-Path $globalRoot 'adapt/SKILL.md')) -like '*last line v3*') 'the published update reaches the installed copy'
    Invoke-FixtureGit config --global --unset "url.$missingRemote.pushInsteadOf" | Out-Null
    Invoke-FixtureGit -C $checkout config --unset remote.origin.pushurl | Out-Null

    # A rejected push leaves GitHub, the checkout, and installed copies unchanged.
    Publish-Upstream 'ad v4' { Set-UpstreamAdapt -Last 'last line v4' -Description 'Upstream renamed' }
    Set-FixtureFile (Join-Path $vaultBare 'hooks/pre-receive') "#!/bin/sh`necho 'fixture: push denied' >&2`nexit 1`n"
    $mainBefore = Get-Head $vaultBare 'main'
    $result = Invoke-Refresh
    $cacheClone = Join-Path $cacheRoot 'https___example.invalid_vault.git'
    Assert-True ($result.status -ceq 'Deferred' -and (Get-Unresolved $result 'adapt').reason -ceq 'PublishFailed') 'a rejected push is deferred'
    Assert-True ((Get-Head $vaultBare 'main') -ceq $mainBefore -and (Get-Head $checkout) -ceq $mainBefore) 'a rejected push changes neither GitHub nor the checkout'
    Assert-True ((Get-Head $cacheClone) -ceq (Get-Head $cacheClone 'origin/main')) 'the refresh clone drops its unpublished commit'
    Assert-True ((Read-FixtureText (Join-Path $globalRoot 'adapt/SKILL.md')) -like '*last line v3*') 'installed copies do not get unpublished content'
    Remove-Item -LiteralPath (Join-Path $vaultBare 'hooks/pre-receive') -Force

    Write-Output 'Sync checks passed: adapt/origin installs, adaptation merges, originals, publishing with permission, checkout updates, and deferrals.'
}
finally {
    foreach ($variable in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($variable, $savedEnvironment[$variable]) }
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    $global:LASTEXITCODE = 0
}
