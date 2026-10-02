. (Join-Path $PSScriptRoot 'skill-ownership.ps1')
. (Join-Path $PSScriptRoot 'skill-transactions.ps1')

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

function Test-SkillUpstreamVersion {
    param([string]$Version)

    return $Version -ceq 'latest' -or
        ($Version -cmatch '^[A-Za-z0-9][A-Za-z0-9._/-]{0,199}\z' -and $Version -notmatch '\.\.|//|/\z|\.\z|\.lock\z')
}

function Assert-SkillUpstreamReference {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ($null -eq $Manifest.upstream -or $Manifest.upstream -isnot [System.Management.Automation.PSCustomObject]) { throw "Missing upstream source: $Label" }
    $upstream = $Manifest.upstream
    $uri = $null
    if ($upstream.repo -isnot [string] -or $upstream.repo -match '\s' -or
        -not [uri]::TryCreate($upstream.repo, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -cne 'https' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) {
        throw "Upstream repo must be an HTTPS URL without credentials, query, or fragment: $Label"
    }
    if ($upstream.path -isnot [string] -or [string]::IsNullOrWhiteSpace($upstream.path) -or [System.IO.Path]::IsPathRooted($upstream.path)) {
        throw "Upstream path must be relative to the upstream repository: $Label"
    }
    if ($upstream.version -isnot [string] -or -not (Test-SkillUpstreamVersion $upstream.version)) {
        throw "Upstream version must be 'latest', a tag, or a full commit: $Label"
    }
}

function Assert-SkillUpstreamFolder {
    param(
        [Parameter(Mandatory = $true)][string]$SkillPath,
        [Parameter(Mandatory = $true)][string]$ExpectedName
    )

    $skillFile = Join-Path $SkillPath 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        throw "Missing SKILL.md for upstream skill '$ExpectedName': $SkillPath"
    }
    $lines = [System.IO.File]::ReadAllLines($skillFile)
    $frontmatterName = $null
    if ($lines.Count -gt 0 -and $lines[0].Trim() -ceq '---') {
        for ($index = 1; $index -lt $lines.Count -and $lines[$index].Trim() -cne '---'; $index++) {
            if ($lines[$index] -cmatch '^name:\s*(.*?)\s*$') {
                $frontmatterName = $Matches[1].Trim([char[]]@('"', "'"))
                break
            }
        }
    }
    if ($frontmatterName -cne $ExpectedName) {
        throw "Upstream SKILL.md name '$frontmatterName' does not match '$ExpectedName': $skillFile"
    }
}

function Get-SkillFormerNames {
    # Former SkillVault folder names mapped to the catalog names that replace them.
    @{
        'harness-init' = 'harness'; 'harness-root' = 'harness'; 'harness-loc' = 'harness'; 'harness-context' = 'harness'; 'harness-management' = 'harness'
        'harness-decide' = 'harness-decision'; 'harness-ref' = 'harness-link'; 'harness-report-create' = 'harness-report'
        'harness-fallback' = 'harness-policy'; 'harness-restrict' = 'harness-policy'
        'sv-installation' = 'skillvault-installation'; 'sv-discovery' = 'skillvault-discovery'
        'sv-refresh' = 'skillvault-refresh'; 'sv-source' = 'skillvault-authoring'; 'skillvault-source' = 'skillvault-authoring'
        'skillvault-install' = 'skillvault-installation'; 'skillvault-list' = 'skillvault-installation'; 'skillvault-uninstall' = 'skillvault-installation'
        'skillvault-upsert' = 'skillvault-authoring'; 'skillvault-remove' = 'skillvault-authoring'; 'skillvault-fresh' = 'skillvault-refresh'
        'skillvault-evaluate' = 'skillvault-discovery'; 'skillvault-search' = 'skillvault-discovery'; 'skillvault-key-points' = 'skillvault-discovery'
        'pr-review-add' = 'pr-watch'; 'pr-review-list' = 'pr-watch'; 'pr-review-remove' = 'pr-watch'; 'pr-review-timer' = 'harness-timer'
        'rules-core' = 'rules'; 'jarvis-metrics-create' = 'jarvis-metrics'; 'kpi-dashboard-design' = 'kpi-dashboard'; 'openapi-spec-generation' = 'openapi-spec'
    }
}

function Test-SkillInstalledOriginal {
    param([Parameter(Mandatory = $true)][string]$SkillPath)

    $metadataPath = Join-Path $SkillPath '.skillvault-install.json'
    (Test-Path -LiteralPath $metadataPath) -and [string](Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json).sourceType -ceq 'upstream'
}

function Read-SkillManifest {
    param(
        [Parameter(Mandatory = $true)][string]$SkillPath,
        [Parameter(Mandatory = $true)][string]$ExpectedName,
        [switch]$AllowReference
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

    $strategy = if ($manifest.install) { [string]$manifest.install.strategy } else { '' }
    $hasSkillFile = Test-Path -LiteralPath (Join-Path $SkillPath 'SKILL.md') -PathType Leaf
    if ($strategy -cin @('upstream', 'adapted')) { Assert-SkillUpstreamReference -Manifest $manifest -Label $manifestPath }
    if ($strategy -ceq 'upstream') {
        if ($manifest.kind -cne 'reference') { throw "A reference requires kind 'reference': $manifestPath" }
        if ($hasSkillFile) { throw "A reference keeps no SKILL.md; make it an adapted skill instead: $SkillPath" }
        if (-not $AllowReference) { throw "Skill '$ExpectedName' is a reference; install fetches its original from $($manifest.upstream.repo)." }
        return $manifest
    }
    if ($strategy -ceq 'adapted' -and [string]$manifest.upstream.commit -cnotmatch '^[0-9a-f]{40}\z') {
        throw "An adapted skill records the upstream commit it includes as upstream.commit: $manifestPath"
    }

    if (-not $hasSkillFile) {
        throw "Missing SKILL.md for skill '$ExpectedName': $SkillPath"
    }

    return $manifest
}

function Find-SkillCatalogEntry {
    param(
        [Parameter(Mandatory = $true)][object[]]$Catalog,
        [Parameter(Mandatory = $true)][string]$Query,
        [switch]$Exact
    )

    $queryText = $Query.Trim()
    if (-not $queryText) { throw 'Supply a skill name, name fragment, or keyword.' }
    if ($Exact) {
        $selectedEntries = @($Catalog | Where-Object { $_.name -ceq $queryText })
    }
    elseif ($queryText -ieq 'public') {
        $selectedEntries = @($Catalog)
    }
    elseif ([Management.Automation.WildcardPattern]::ContainsWildcardCharacters($queryText)) {
        $pattern = [Management.Automation.WildcardPattern]::new($queryText, [Management.Automation.WildcardOptions]::IgnoreCase)
        $selectedEntries = @($Catalog | Where-Object { $pattern.IsMatch([string]$_.name) })
    }
    else {
        $selectedEntries = @($Catalog | Where-Object { ([string]$_.name).IndexOf($queryText, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
        if (-not $selectedEntries.Count) {
            $selectedEntries = @($Catalog | Where-Object {
                ([string]$_.description).IndexOf($queryText, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                ([string]$_.path).IndexOf($queryText, [StringComparison]::OrdinalIgnoreCase) -ge 0
            })
        }
    }
    if (-not $selectedEntries.Count) { throw "No catalog skills match '$queryText'." }
    $selectedEntries | Sort-Object name
}

function Read-BootstrapSkillNames {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

    $selectionPath = Join-Path $RepositoryRoot 'scripts/bootstrap-skills.json'
    if (-not (Test-Path -LiteralPath $selectionPath -PathType Leaf)) {
        throw "Missing bootstrap selection: $selectionPath"
    }
    $content = Get-Content -LiteralPath $selectionPath -Raw -ErrorAction Stop
    $jsonParameters = @{ InputObject = $content; ErrorAction = 'Stop' }
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('NoEnumerate')) {
        $jsonParameters.NoEnumerate = $true
    }
    $names = ConvertFrom-Json @jsonParameters
    if ($names -isnot [System.Array]) { throw "Bootstrap selection must be a JSON array: $selectionPath" }
    if ($names.Count -eq 0) { throw "Bootstrap selection must not be empty: $selectionPath" }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($name in $names) {
        if ($name -isnot [string] -or $name.Length -gt 64 -or $name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
            throw "Bootstrap selection must contain exact skill names: $selectionPath"
        }
        if (-not $seen.Add($name)) { throw "Duplicate bootstrap skill '$name' in $selectionPath" }
    }
    return $names
}

function Sync-SkillSourceRepository {
    param(
        [Parameter(Mandatory = $true)][string]$RepoUrl,
        [Parameter(Mandatory = $true)][string]$CacheRoot,
        [string]$Version = 'latest'
    )

    $previousGitPrompt = $env:GIT_TERMINAL_PROMPT
    $previousGcmInteractive = $env:GCM_INTERACTIVE
    $authenticationGuidance = 'Interactive Git/GCM prompts are disabled; authenticate separately if required, then rerun.'
    try {
        $env:GIT_TERMINAL_PROMPT = '0'
        $env:GCM_INTERACTIVE = 'Never'
        if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
            throw 'Source repository is empty.'
        }
        if ($RepoUrl.StartsWith('-')) {
            throw "Source repository must not start with '-': $RepoUrl"
        }
        if (-not (Test-SkillUpstreamVersion $Version)) {
            throw "Invalid source version '$Version'. Use 'latest', a tag, or a full commit."
        }

        $repoPath = Join-Path $CacheRoot (($RepoUrl -replace '[^A-Za-z0-9._-]', '_').Trim('_'))
        if (Test-Path -LiteralPath $repoPath) {
            if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) {
                throw "Source cache is not a Git repository; inspect and remove it manually: $repoPath"
            }

            $remoteUrl = [string](git -C $repoPath config --get remote.origin.url | Select-Object -First 1)
            if ($LASTEXITCODE -ne 0) { throw "Git remote lookup failed for $repoPath" }
            if ($remoteUrl.Trim() -cne $RepoUrl) {
                throw "Source cache $repoPath tracks '$($remoteUrl.Trim())', not '$RepoUrl'."
            }

            $status = git -C $repoPath status --porcelain
            if ($LASTEXITCODE -ne 0) { throw "Git status failed for $repoPath" }
            if ($status) { throw "Refusing to refresh from a modified source cache: $repoPath" }

            if ($Version -ceq 'latest') { git -C $repoPath fetch --prune origin | Out-Null }
            else { git -C $repoPath fetch --prune --tags origin | Out-Null }
            if ($LASTEXITCODE -ne 0) { throw "Git fetch failed for $RepoUrl. $authenticationGuidance" }

            if ($Version -ceq 'latest') {
                git -C $repoPath remote set-head origin --auto | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Git remote set-head failed for $RepoUrl. $authenticationGuidance" }

                $defaultRef = [string](git -C $repoPath symbolic-ref --quiet --short refs/remotes/origin/HEAD | Select-Object -First 1)
                if ($LASTEXITCODE -ne 0) { throw "Git symbolic-ref failed for $RepoUrl" }
                $defaultRef = $defaultRef.Trim()
                if ($defaultRef -cnotmatch '^origin/\S+$') {
                    throw "Unexpected default branch ref for ${RepoUrl}: '$defaultRef'"
                }

                git -C $repoPath checkout --detach $defaultRef | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Git checkout failed for $RepoUrl" }
            }
        }
        else {
            New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null
            git clone -- $RepoUrl $repoPath | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Git clone failed for $RepoUrl. $authenticationGuidance" }
        }

        if ($Version -cne 'latest') {
            $versionSpec = if ($Version -cmatch '^[0-9a-f]{40}$') { "${Version}^{commit}" } else { "refs/tags/${Version}^{commit}" }
            $commit = [string](git -C $repoPath rev-parse --verify --quiet $versionSpec | Select-Object -First 1)
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($commit)) {
                throw "Version '$Version' was not found as a tag or commit in $RepoUrl."
            }
            git -C $repoPath checkout --detach $commit.Trim() | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Git checkout failed for $RepoUrl at $Version" }
        }

        return $repoPath
    }
    finally {
        $env:GIT_TERMINAL_PROMPT = $previousGitPrompt
        $env:GCM_INTERACTIVE = $previousGcmInteractive
    }
}

function Get-SkillSourceRevision {
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][string]$SourcePath
    )

    $revisionSpec = if ($SourcePath -ceq '.') { 'HEAD^{tree}' } else { "HEAD:$SourcePath" }
    try {
        $revision = [string](git -C $RepoPath rev-parse $revisionSpec 2>$null | Select-Object -First 1)
    }
    catch {
        return $null
    }

    if ($LASTEXITCODE -ne 0) { return $null }
    if ([string]::IsNullOrWhiteSpace($revision)) { return $null }
    return $revision.Trim()
}

function ConvertTo-SkillRepoIdentity {
    param([string]$Url)

    $identity = ([string]$Url).Trim() -replace '^[A-Za-z][A-Za-z0-9+.-]*://', '' -replace '^[^@/]+@', ''
    $identity = ($identity -replace '^([^/:]+):(?!\d)', '$1/') -replace '(\.git)?/*$', ''
    return $identity.ToLowerInvariant()
}

function Test-SkillGitTopLevel {
    param([Parameter(Mandatory = $true)][string]$Path)

    $ErrorActionPreference = 'Continue'
    $output = @(git -C $Path rev-parse --is-inside-work-tree --show-prefix 2>$null | ForEach-Object { [string]$_ })
    return $LASTEXITCODE -eq 0 -and $output.Count -ge 1 -and $output[0] -ceq 'true' -and ($output.Count -eq 1 -or [string]::IsNullOrEmpty($output[1]))
}

function Export-SkillGitTree {
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][string]$TreeIsh,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $ErrorActionPreference = 'Continue'
    $indexPath = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-index-' + [guid]::NewGuid().ToString('N'))
    $previousIndex = $env:GIT_INDEX_FILE
    try {
        # A private index keeps the repository's own index and working tree untouched.
        $env:GIT_INDEX_FILE = $indexPath
        git -C $RepoPath read-tree $TreeIsh 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { return $false }
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        git -C $RepoPath checkout-index --all --force ('--prefix=' + ($Destination -replace '\\', '/').TrimEnd('/') + '/') 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    }
    finally {
        $env:GIT_INDEX_FILE = $previousIndex
        Remove-Item -LiteralPath $indexPath -Force -ErrorAction SilentlyContinue
    }
}

function Merge-SkillFolder {
    param(
        [Parameter(Mandatory = $true)][string]$Base,
        [Parameter(Mandatory = $true)][string]$Ours,
        [Parameter(Mandatory = $true)][string]$Theirs,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $ErrorActionPreference = 'Stop'
    $sides = @{}
    foreach ($side in @{ Name = 'Base'; Path = $Base }, @{ Name = 'Ours'; Path = $Ours }, @{ Name = 'Theirs'; Path = $Theirs }) {
        $files = @{}
        foreach ($file in @(Get-SkillFiles -SkillPath $side.Path)) { $files[$file.RelativePath] = $file.FullName }
        $sides[$side.Name] = $files
    }
    # Latin-1 maps every byte to one character, so line endings can be compared and changed without decoding errors.
    $latin1 = [System.Text.Encoding]::GetEncoding(28591)
    $read = { param($file) $latin1.GetString([System.IO.File]::ReadAllBytes($file)) }
    $same = {
        param($left, $right)
        if (-not $left -or -not $right) { return (-not $left) -and (-not $right) }
        $leftText = & $read $left; $rightText = & $read $right
        if ($leftText.Contains([char]0) -or $rightText.Contains([char]0)) { return $leftText -ceq $rightText }
        return $leftText.Replace("`r`n", "`n") -ceq $rightText.Replace("`r`n", "`n")
    }
    $conflicts = [System.Collections.Generic.List[string]]::new()
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    $paths = @($sides.Base.Keys) + @($sides.Ours.Keys) + @($sides.Theirs.Keys) | Sort-Object -Unique
    foreach ($relativePath in $paths) {
        $basePath = $sides.Base[$relativePath]; $oursPath = $sides.Ours[$relativePath]; $theirsPath = $sides.Theirs[$relativePath]
        if (& $same $oursPath $theirsPath) { $chosen = $theirsPath }
        elseif (& $same $oursPath $basePath) { $chosen = $theirsPath }
        elseif (& $same $theirsPath $basePath) { $chosen = $oursPath }
        elseif ($basePath -and $oursPath -and $theirsPath) { $chosen = '<merge>' }
        else { $conflicts.Add($relativePath); continue }
        if (-not $chosen) { continue }
        $target = Join-Path $Destination $relativePath.Replace([char]'/', [System.IO.Path]::DirectorySeparatorChar)
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        if ($chosen -cne '<merge>') { Copy-Item -LiteralPath $chosen -Destination $target -Force; continue }
        $texts = @((& $read $basePath), (& $read $oursPath), (& $read $theirsPath))
        if (($texts -join '').Contains([char]0)) { $conflicts.Add($relativePath); continue }
        $mergeFiles = @(foreach ($text in $texts) {
            $file = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-merge-' + [guid]::NewGuid().ToString('N'))
            [System.IO.File]::WriteAllBytes($file, $latin1.GetBytes($text.Replace("`r`n", "`n")))
            $file
        })
        try {
            $ErrorActionPreference = 'Continue'
            git merge-file --quiet $mergeFiles[1] $mergeFiles[0] $mergeFiles[2] 2>$null | Out-Null
            $mergeExit = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'
            if ($mergeExit -ne 0) { $conflicts.Add($relativePath); continue }
            $merged = & $read $mergeFiles[1]
            # Keep the committed file's line endings.
            if ($texts[2].Contains("`r`n")) { $merged = $merged.Replace("`n", "`r`n") }
            [System.IO.File]::WriteAllBytes($target, $latin1.GetBytes($merged))
        }
        finally { Remove-Item -LiteralPath $mergeFiles -Force -ErrorAction SilentlyContinue }
    }
    return , @($conflicts)
}

function Find-SkillLicenseFile {
    param([string[]]$Folders)

    foreach ($folder in @($Folders | Where-Object { $_ })) {
        $match = @(Get-ChildItem -LiteralPath $folder -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^(LICEN[CS]E|COPYING)(\.(md|txt))?$' } | Sort-Object Name | Select-Object -First 1)
        if ($match.Count) { return $match[0].FullName }
    }
    return $null
}

function Get-SkillUpstreamSnapshot {
    param(
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$CacheRoot,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $ErrorActionPreference = 'Stop'
    $upstream = $Manifest.upstream
    $repoPath = Sync-SkillSourceRepository -RepoUrl ([string]$upstream.repo) -CacheRoot $CacheRoot -Version ([string]$upstream.version)
    $commit = ([string](git -C $repoPath rev-parse HEAD | Select-Object -First 1)).Trim()
    $revision = Get-SkillSourceRevision -RepoPath $repoPath -SourcePath ([string]$upstream.path)
    if (-not $revision) { throw "Path '$($upstream.path)' was not found in $($upstream.repo) at $commit." }
    if (-not (Export-SkillGitTree -RepoPath $repoPath -TreeIsh $revision -Destination $Destination)) {
        throw "Could not read '$($upstream.path)' from $($upstream.repo) at $commit."
    }
    Assert-SkillUpstreamFolder -SkillPath $Destination -ExpectedName ([string]$Manifest.name)
    return [pscustomobject]@{
        Repo = [string]$upstream.repo; Path = [string]$upstream.path; Version = [string]$upstream.version
        Commit = $commit; Revision = $revision; Folder = $Destination
        Files = @(Get-SkillFiles -SkillPath $Destination | ForEach-Object RelativePath)
    }
}

function Get-SkillTagSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    # A pin reads the skill's own tag; the checkout's branch, index, and files stay as they are.
    $ErrorActionPreference = 'Continue'
    $tag = "$Name/$Version"
    $commit = [string](git -C $RepoPath rev-parse --verify --quiet "refs/tags/${tag}^{commit}" 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0 -or -not $commit.Trim()) { throw "Tag $tag was not found in $RepoPath." }
    $commit = $commit.Trim()
    $catalogText = @(git -C $RepoPath show "${commit}:catalog.json" 2>$null) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Tag $tag has no catalog.json." }
    $catalog = $catalogText | ConvertFrom-Json
    $entry = @($catalog | Where-Object { $_.name -ceq $Name })
    if ($entry.Count -ne 1) { throw "The catalog at tag $tag does not list '$Name' exactly once." }
    $path = [string]$entry[0].path
    $revision = [string](git -C $RepoPath rev-parse --verify --quiet "${commit}:$path" 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0 -or -not $revision.Trim() -or -not (Export-SkillGitTree -RepoPath $RepoPath -TreeIsh $revision.Trim() -Destination $Destination)) {
        throw "Could not read '$path' at tag $tag."
    }
    $manifest = Read-SkillManifest -SkillPath $Destination -ExpectedName $Name
    if ("v$($manifest.version)" -cne $Version) { throw "Tag $tag holds $Name version $($manifest.version)." }
    return [pscustomobject]@{ Tag = $tag; Commit = $commit; Path = $path; Revision = $revision.Trim(); Folder = $Destination; Manifest = $manifest }
}

function Set-SkillUpstreamSection {
    param(
        [Parameter(Mandatory = $true)][string]$SkillFile,
        [Parameter(Mandatory = $true)][string]$UpstreamSkillFile,
        [Parameter(Mandatory = $true)][string]$Source
    )

    $ErrorActionPreference = 'Stop'
    $raw = [System.IO.File]::ReadAllText($SkillFile)
    $text = $raw -replace "`r`n", "`n"
    $sections = [regex]::Matches($text, '(?s)<!-- upstream:begin -->.*?<!-- upstream:end -->')
    if ($sections.Count -ne 1 -or [regex]::Matches($text, '<!-- upstream:(begin|end) -->').Count -ne 2) {
        throw "An adapted SKILL.md needs exactly one <!-- upstream:begin --> ... <!-- upstream:end --> section: $SkillFile"
    }
    $upstreamText = ([System.IO.File]::ReadAllText($UpstreamSkillFile) -replace "`r`n", "`n").TrimStart([char]0xFEFF)
    $body = ($upstreamText -replace '(?s)\A---\n.*?\n---[^\n]*\n', '').Trim()
    $section = "<!-- upstream:begin -->`n<!-- $Source. Refresh replaces this section; put SkillVault changes outside it. -->`n`n$body`n<!-- upstream:end -->"
    $updated = $text.Substring(0, $sections[0].Index) + $section + $text.Substring($sections[0].Index + $sections[0].Length)
    if ($raw.Contains("`r`n")) { $updated = $updated.Replace("`n", "`r`n") }
    [System.IO.File]::WriteAllText($SkillFile, $updated, [System.Text.UTF8Encoding]::new($false))
}

function Merge-SkillAdaptation {
    param(
        [Parameter(Mandatory = $true)][string]$SkillPath,
        [Parameter(Mandatory = $true)]$Manifest,
        [Parameter(Mandatory = $true)][string]$UpstreamRoot,
        [Parameter(Mandatory = $true)][string]$Commit
    )

    $ErrorActionPreference = 'Stop'
    $name = [string]$Manifest.name
    $path = [string]$Manifest.upstream.path
    $baseCommit = [string]$Manifest.upstream.commit
    $result = [pscustomobject]@{ Changed = $false; Conflicts = @() }
    if ($baseCommit -ceq $Commit) { return $result }
    $treeOf = {
        param($commitId)
        $spec = if ($path -ceq '.') { "$commitId^{tree}" } else { "${commitId}:$path" }
        $ErrorActionPreference = 'Continue'
        $tree = [string](git -C $UpstreamRoot rev-parse --verify --quiet $spec 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0) { $tree.Trim() }
    }
    $baseTree = & $treeOf $baseCommit
    if (-not $baseTree) { throw "The recorded upstream commit $baseCommit of '$name' is not in $($Manifest.upstream.repo); merge by hand and update upstream.commit." }
    $newTree = & $treeOf $Commit
    if (-not $newTree) { throw "Path '$path' is missing from $($Manifest.upstream.repo) at $Commit." }
    if ($baseTree -ceq $newTree) { return $result }

    $work = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-adapt-' + [guid]::NewGuid().ToString('N'))
    try {
        $base = Join-Path $work 'base'; $theirs = Join-Path $work 'theirs'; $ours = Join-Path $work 'ours'; $merged = Join-Path $work 'merged'
        if (-not (Export-SkillGitTree -RepoPath $UpstreamRoot -TreeIsh $baseTree -Destination $base) -or
            -not (Export-SkillGitTree -RepoPath $UpstreamRoot -TreeIsh $newTree -Destination $theirs)) {
            throw "Could not read '$path' from $($Manifest.upstream.repo)."
        }
        foreach ($reserved in @('skill.json', 'UPSTREAM-LICENSE')) {
            if (Test-Path -LiteralPath (Join-Path $theirs $reserved)) { throw "Upstream file '$reserved' would replace SkillVault metadata for '$name'." }
        }
        $upstreamSkill = Join-Path $work 'upstream-SKILL.md'
        if (-not (Test-Path -LiteralPath (Join-Path $theirs 'SKILL.md') -PathType Leaf)) { throw "Upstream has no SKILL.md for '$name' at $Commit." }
        Move-Item -LiteralPath (Join-Path $theirs 'SKILL.md') -Destination $upstreamSkill
        $ownLicense = Find-SkillLicenseFile -Folders @($theirs)
        $license = if ($ownLicense) { $ownLicense } else { Find-SkillLicenseFile -Folders @($UpstreamRoot) }
        if (-not $license) { throw "No license file was found for '$name' upstream; its changes are not copied without one." }

        # SKILL.md takes the new original in its marked section, so only the other files are merged.
        Copy-Item -LiteralPath $SkillPath -Destination $ours -Recurse
        Remove-Item -LiteralPath (Join-Path $ours 'SKILL.md'), (Join-Path $base 'SKILL.md') -Force -ErrorAction SilentlyContinue
        $conflicts = Merge-SkillFolder -Base $base -Ours $ours -Theirs $theirs -Destination $merged
        $result.Conflicts = @($conflicts)
        if ($result.Conflicts.Count) { return $result }
        Copy-Item -LiteralPath (Join-Path $SkillPath 'SKILL.md') -Destination (Join-Path $merged 'SKILL.md')
        Set-SkillUpstreamSection -SkillFile (Join-Path $merged 'SKILL.md') -UpstreamSkillFile $upstreamSkill -Source "Original: $($Manifest.upstream.repo) $path at $Commit"
        if (-not $ownLicense) { Copy-Item -LiteralPath $license -Destination (Join-Path $merged 'UPSTREAM-LICENSE') -Force }
        $manifestPath = Join-Path $merged 'skill.json'
        $manifestText = [System.IO.File]::ReadAllText($manifestPath)
        $updatedText = [regex]::Replace($manifestText, '("commit"\s*:\s*")' + $baseCommit + '"', '${1}' + $Commit + '"')
        if ($updatedText -ceq $manifestText) { throw "Could not record the new upstream.commit for '$name'." }
        [System.IO.File]::WriteAllText($manifestPath, $updatedText, [System.Text.UTF8Encoding]::new($false))
        Get-ChildItem -LiteralPath $SkillPath -Force | Remove-Item -Recurse -Force
        Get-ChildItem -LiteralPath $merged -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $SkillPath -Recurse -Force }
        $result.Changed = $true
        return $result
    }
    finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}

function Get-SkillFiles {
    param(
        [Parameter(Mandatory = $true)][string]$SkillPath,
        [switch]$Complete
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
                if (-not $Complete -and $child.Name -eq '.git') { continue }
                $pendingDirectories.Enqueue($child.FullName)
                continue
            }

            $relativePath = $child.FullName.Substring($rootFullPath.Length + 1).Replace('\', '/')
            if (-not $Complete -and $relativePath -eq '.skillvault-install.json') { continue }

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
        [Parameter(Mandatory = $true)][string]$Target,
        [switch]$Complete
    )

    if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
        return $false
    }

    $sourceFiles = @(Get-SkillFiles -SkillPath $Source -Complete:$Complete)
    $targetFiles = @(Get-SkillFiles -SkillPath $Target -Complete:$Complete)
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
        [switch]$Force,
        $OwnershipLease,
        [switch]$ConfirmStopped,
        $RecoveryBackup,
        $OriginManifest
    )

    $ErrorActionPreference = 'Stop'

    if ($Name -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "Unsafe skill name: $Name"
    }

    $sourceItem = Get-Item -LiteralPath $Source -Force -ErrorAction SilentlyContinue
    if ($null -eq $sourceItem -or $sourceItem -isnot [System.IO.DirectoryInfo]) {
        throw "Skill source is not a directory: $Source"
    }

    # An original from upstream has no skill.json; the catalog manifest describes it instead.
    $manifest = if ($OriginManifest) { Assert-SkillUpstreamFolder -SkillPath $sourceItem.FullName -ExpectedName $Name; $OriginManifest }
        else { Read-SkillManifest -SkillPath $sourceItem.FullName -ExpectedName $Name }
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

    $stagingPath = Join-Path $targetRootFullPath ('.skillvault-stage-' + [guid]::NewGuid().ToString('N'))
    $backupPath = $null
    $backup = $null
    $ownsBackup = $null -eq $RecoveryBackup
    $ownsLease = $null -eq $OwnershipLease

    try {
        if ($ownsLease) { $OwnershipLease = Enter-SkillUpdateOwnership -Paths @($targetPath) -ConfirmStopped:$ConfirmStopped }
        else { Assert-SkillOwnershipLease -Lease $OwnershipLease -Paths @($targetPath) }
        New-Item -ItemType Directory -Path $targetRootFullPath -Force | Out-Null
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
        if ($OriginManifest) { Assert-SkillUpstreamFolder -SkillPath $stagingPath -ExpectedName $Name }
        else { Read-SkillManifest -SkillPath $stagingPath -ExpectedName $Name | Out-Null }

        if ($targetExists) {
            $backup = if ($ownsBackup) { New-SkillUpdateTransaction -Targets @(@{ path = $targetPath; target = $targetPath; name = $Name }) } else { $RecoveryBackup }
            $entry = @($backup.record.entries | Where-Object { $_.target -eq $targetPath -and $_.verified })
            if ($entry.Count -ne 1 -or (Split-Path -Parent $backup.path) -ne (Get-SkillTransactionRoot -InstallationRoot $targetRootFullPath)) { throw 'Replacement requires its exact verified temporary rollback copy.' }
            $backupPath = Join-Path $backup.path $entry[0].payload
            if (-not (Test-SkillContentEqual -Source $targetPath -Target $backupPath -Complete)) { throw 'Replacement recovery backup no longer matches the original.' }
        }

        try {
            if ($targetExists) { Remove-Item -LiteralPath $targetPath -Recurse -Force }
            Move-Item -LiteralPath $stagingPath -Destination $targetPath
            if (-not (Test-SkillContentEqual -Source $sourceFullPath -Target $targetPath)) { throw 'Installed content did not verify.' }
        }
        catch {
            if ($ownsBackup) { Restore-SkillUpdateTransaction $backup }
            if (-not $targetExists -and (Test-Path -LiteralPath $targetPath)) {
                $null = @(Get-SkillFiles -SkillPath $targetPath -Complete)
                Remove-Item -LiteralPath $targetPath -Recurse -Force
            }
            throw
        }
        if ($ownsBackup) { Complete-SkillUpdateTransaction $backup }
    }
    finally {
        try {
            if (Test-Path -LiteralPath $stagingPath) {
                Remove-Item -LiteralPath $stagingPath -Recurse -Force
            }
        }
        finally { if ($ownsLease -and $OwnershipLease) { Exit-SkillOwnership $OwnershipLease } }
    }

    return [pscustomobject]@{
        Name = $Name
        Path = $targetPath
        Version = $manifest.version
        Replaced = $targetExists
        RecoveryBackup = $null
    }
}
