<#
.SYNOPSIS
Lists what changed in the skills a SkillVault skill was written from, since the commits its origins record.

.DESCRIPTION
Reads each catalog skill's skill.json "origins" (repo, branch, path, commit) and compares the recorded
commit with origin/<branch> in a local clone of that repository: the SkillVault checkout itself, or a
clone passed with -Checkout. It also notes changes to an origin that are only in that clone: uncommitted
edits, or commits not yet on the branch. It writes nothing except remote-tracking refs when -Fetch is
given; porting a change into the skill and moving its recorded commit forward stay manual.
#>
[CmdletBinding()]
param(
    [string]$RepoPath = (Get-Location).ProviderPath,
    [string[]]$Name,
    [string[]]$Checkout,
    [switch]$Fetch,
    [switch]$Diff,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

function ConvertTo-OriginKey {
    param([string]$Url)
    $value = $Url.Trim()
    if ($value -match '^[^@/\s]+@([^:/\s]+):(.+)$') { $value = "https://$($Matches[1])/$($Matches[2])" }
    if ($value -match '^ssh://(?:[^@/]+@)?([^/:]+)(?::\d+)?/(.+)$') { $value = "https://$($Matches[1])/$($Matches[2])" }
    $value = $value -replace '\.git/?$', '' -replace '/+$', ''
    if ($value -match '^(https?)://([^/]+)(/.*)?$') { $value = $Matches[1].ToLowerInvariant() + '://' + $Matches[2].ToLowerInvariant() + $Matches[3] }
    $value
}

function Invoke-OriginGit {
    param([string]$Directory, [string[]]$Arguments)
    # Windows PowerShell turns native stderr into errors under Stop; exit codes decide here instead.
    $ErrorActionPreference = 'Continue'
    # A fetch must fail instead of prompting: no terminal prompt and no credential-manager window.
    $savedPrompt = $env:GIT_TERMINAL_PROMPT
    $savedInteractive = $env:GCM_INTERACTIVE
    $env:GIT_TERMINAL_PROMPT = '0'
    $env:GCM_INTERACTIVE = 'never'
    try { $output = & git -C $Directory @Arguments 2>$null; $code = $LASTEXITCODE }
    finally { $env:GIT_TERMINAL_PROMPT = $savedPrompt; $env:GCM_INTERACTIVE = $savedInteractive }
    [pscustomobject]@{ ExitCode = $code; Output = @($output) }
}

$root = (Resolve-Path -LiteralPath $RepoPath).ProviderPath
$catalogPath = Join-Path $root 'catalog.json'
if (-not (Test-Path -LiteralPath $catalogPath)) { throw "No catalog.json in $root; pass the SkillVault checkout with -RepoPath." }
$catalog = @(Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json | ForEach-Object { $_ })
if ($Name) {
    $unknown = @($Name | Where-Object { $_ -notin $catalog.name })
    if ($unknown) { throw "Not in the catalog: $($unknown -join ', ')" }
}

$clones = @{}
foreach ($candidate in @($root) + @($Checkout | Where-Object { $_ })) {
    $path = (Resolve-Path -LiteralPath $candidate).ProviderPath
    $remote = Invoke-OriginGit $path @('remote', 'get-url', 'origin')
    if ($remote.ExitCode -ne 0 -or -not $remote.Output) {
        if ($path -ne $root) { throw "$path is not a Git clone with an origin remote." }
        continue
    }
    $key = ConvertTo-OriginKey ([string]$remote.Output[0])
    if (-not $clones.ContainsKey($key)) { $clones[$key] = $path }
}

$fetched = @{}
$results = foreach ($entry in $catalog) {
    if ($Name -and $entry.name -notin $Name) { continue }
    $manifestPath = Join-Path (Join-Path $root $entry.path) 'skill.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) { continue }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if (-not ($manifest.PSObject.Properties.Name -contains 'origins')) { continue }
    foreach ($origin in @($manifest.origins)) {
        $result = [ordered]@{
            skill = $entry.name; repo = $origin.repo; branch = $origin.branch; path = $origin.path
            recorded = $origin.commit; status = ''; latest = $null; commits = @(); diff = $null; checkout = $null
            local = ''; localDiff = $null
        }
        $clone = $clones[(ConvertTo-OriginKey $origin.repo)]
        if (-not $clone) { $result.status = 'NoCheckout'; [pscustomobject]$result; continue }
        $result.checkout = $clone
        $fetchKey = "$clone|$($origin.branch)"
        if ($Fetch -and -not $fetched.ContainsKey($fetchKey)) {
            $fetched[$fetchKey] = (Invoke-OriginGit $clone @('fetch', '--quiet', 'origin', "+refs/heads/$($origin.branch):refs/remotes/origin/$($origin.branch)")).ExitCode -eq 0
        }
        $target = "refs/remotes/origin/$($origin.branch)"
        $latest = Invoke-OriginGit $clone @('rev-parse', '--verify', '--quiet', "$target^{commit}")
        if ($latest.ExitCode -ne 0) { $result.status = if ($Fetch -and -not $fetched[$fetchKey]) { 'FetchFailed' } else { 'NoBranch' }; [pscustomobject]$result; continue }
        $result.latest = [string]$latest.Output[0]
        if ((Invoke-OriginGit $clone @('cat-file', '-e', "$($origin.commit)^{commit}")).ExitCode -ne 0) {
            $result.status = 'UnknownCommit'; [pscustomobject]$result; continue
        }
        $log = Invoke-OriginGit $clone @('-c', 'core.quotePath=false', 'log', '--format=%H%x09%ad%x09%an%x09%s', '--date=short', "$($origin.commit)..$target", '--', $origin.path)
        $result.commits = @($log.Output | Where-Object { $_ } | ForEach-Object {
                $hash, $date, $author, $subject = $_ -split "`t", 4
                [pscustomobject]@{ commit = $hash; date = $date; author = $author; subject = $subject }
            })
        $present = (Invoke-OriginGit $clone @('cat-file', '-e', "$($target):$($origin.path)")).ExitCode -eq 0
        $result.status = if (-not $present) { 'Removed' } elseif ($result.commits.Count) { 'Changed' } else { 'Current' }
        if ($Diff -and $result.commits.Count) {
            $result.diff = (Invoke-OriginGit $clone @('-c', 'core.quotePath=false', 'diff', '--no-ext-diff', $origin.commit, $target, '--', $origin.path)).Output -join "`n"
        }
        # Work on the origin that has not reached the branch yet: uncommitted edits, or commits only on this clone's HEAD.
        $notes = @()
        if (@((Invoke-OriginGit $clone @('status', '--porcelain', '--', $origin.path)).Output | Where-Object { $_ }).Count) { $notes += 'uncommitted edits' }
        $ahead = @((Invoke-OriginGit $clone @('rev-list', "$target..HEAD", '--', $origin.path)).Output | Where-Object { $_ }).Count
        # A squash-merged branch keeps commits the branch never gets, but its content is already there.
        if ($ahead -and @((Invoke-OriginGit $clone @('diff', '--name-only', $target, 'HEAD', '--', $origin.path)).Output | Where-Object { $_ }).Count) {
            $notes += "$ahead commit(s) not on $($origin.branch)"
        }
        $result.local = $notes -join ', '
        if ($Diff -and $notes) {
            $result.localDiff = (Invoke-OriginGit $clone @('-c', 'core.quotePath=false', 'diff', '--no-ext-diff', $origin.commit, '--', $origin.path)).Output -join "`n"
        }
        if ($Fetch -and -not $fetched[$fetchKey]) { $result.status += ' (fetch failed; local refs used)' }
        [pscustomobject]$result
    }
}

if ($Json) { ConvertTo-Json -InputObject @($results) -Depth 5; return }
if (-not $results) { Write-Output 'No catalog skill lists origins.'; return }
foreach ($item in $results) {
    $count = @($item.commits).Count
    $summary = switch -Wildcard ($item.status) {
        'Changed*' { "$count new commit(s) since $($item.recorded.Substring(0, 9))" }
        'NoCheckout' { 'no local clone; pass one with -Checkout' }
        default { $item.status }
    }
    if ($item.local) { $summary += "; in $($item.checkout): $($item.local)" }
    Write-Output ("{0}: {1} {2} [{3}] - {4}" -f $item.skill, $item.repo, $item.path, $item.branch, $summary)
    foreach ($commit in @($item.commits)) { Write-Output ("    {0} {1} {2}: {3}" -f $commit.commit.Substring(0, 9), $commit.date, $commit.author, $commit.subject) }
    if ($item.diff) { Write-Output $item.diff }
    if ($item.localDiff) { Write-Output "    Local changes since $($item.recorded.Substring(0, 9)), including uncommitted edits:"; Write-Output $item.localDiff }
}
