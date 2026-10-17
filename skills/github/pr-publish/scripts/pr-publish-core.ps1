$ErrorActionPreference = 'Stop'

function Invoke-PrPublishGh {
    param([string[]]$Arguments)
    $previous = [Console]::OutputEncoding
    # Captured UTF-8 output is corrupted when the console uses another code page.
    try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { }
    try {
        $output = & gh @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally { try { [Console]::OutputEncoding = $previous } catch { } }
    $errors = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }) -join "`n"
    if ($exitCode -ne 0) { throw "gh $($Arguments[0]) failed (exit $exitCode): $errors" }
    @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) -join "`n"
}

function Invoke-PrPublishGit {
    param([string]$Path, [string[]]$Arguments, [switch]$AllowFailure)
    $output = & git -C $Path @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        if ($AllowFailure) { return $null }
        throw "git $($Arguments -join ' ') failed (exit $LASTEXITCODE)."
    }
    (@($output) -join "`n").Trim()
}

# Reads git output as UTF-8 so non-ASCII file names survive; -z output stays NUL-separated.
function Invoke-PrPublishGitRaw {
    param([string]$Path, [string[]]$Arguments)
    $previous = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { }
    try {
        $output = & git -C $Path @Arguments 2>$null
        $exitCode = $LASTEXITCODE
    }
    finally { try { [Console]::OutputEncoding = $previous } catch { } }
    if ($exitCode -ne 0) { throw "git $($Arguments[0]) failed (exit $exitCode)." }
    @($output) -join "`n"
}

function Get-PrPublishDefaultBase {
    param([string]$Root)
    $originHead = Invoke-PrPublishGit $Root @('symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD') -AllowFailure
    if ($originHead) { $originHead -replace '^origin/', '' }
}

# Runs a network git command that must fail instead of waiting for a credential prompt no one can answer.
function Invoke-PrPublishGitRemote {
    param([string]$Root, [string[]]$Arguments)
    $savedPrompt = $env:GIT_TERMINAL_PROMPT
    $env:GIT_TERMINAL_PROMPT = '0'
    try {
        $output = & git -C $Root @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally { $env:GIT_TERMINAL_PROMPT = $savedPrompt }
    [pscustomobject]@{ exitCode = $exitCode; output = ((@($output) | ForEach-Object { "$_" }) -join ' ').Trim() }
}

# Updates origin's copies of the base and of this branch so behind counts are current. A failed fetch is
# reported rather than thrown: publishing can still go ahead on what was fetched before.
function Invoke-PrPublishFetch {
    param([string]$Root, [string]$Base, [string]$Branch)
    $targets = [Collections.Generic.List[string]]::new()
    if ($Base) { $targets.Add($Base) }
    $remote = Invoke-PrPublishGit $Root @('config', "branch.$Branch.remote") -AllowFailure
    $merge = Invoke-PrPublishGit $Root @('config', "branch.$Branch.merge") -AllowFailure
    if ($remote -ceq 'origin' -and $merge -match '^refs/heads/(.+)$' -and $Matches[1] -cnotin $targets) { $targets.Add($Matches[1]) }
    if (-not $targets.Count) { return [pscustomobject]@{ fetched = $false; error = 'The base branch is unknown, so there was nothing to fetch.' } }
    $result = Invoke-PrPublishGitRemote $Root (@('fetch', '--quiet', '--no-tags', 'origin') + $targets)
    if ($result.exitCode -ne 0) { return [pscustomobject]@{ fetched = $false; error = "git fetch failed (exit $($result.exitCode)): $($result.output)" } }
    [pscustomobject]@{ fetched = $true; error = $null }
}

# Every uncommitted change: staged, unstaged, and untracked files. A rename keeps its original path.
function Get-PrPublishChanges {
    param([string]$Root)
    $tokens = @((Invoke-PrPublishGitRaw $Root @('status', '--porcelain=v1', '-z', '--untracked-files=all')) -split "`0" | Where-Object { $_ })
    for ($index = 0; $index -lt $tokens.Count; $index++) {
        $entry = $tokens[$index]
        $code = $entry.Substring(0, 2)
        $original = $null
        if ($code -match '[RC]') { $index++; $original = $tokens[$index] }
        [pscustomobject]@{ code = $code; path = $entry.Substring(3); originalPath = $original }
    }
}

function Get-PrPublishRepository {
    param([string]$RemoteUrl)
    if ($RemoteUrl -notmatch '^(?:https://(?<host>[^/@:]+)/|git@(?<host>[^:/]+):|ssh://git@(?<host>[^/:]+)(?::\d+)?/)(?<owner>[A-Za-z0-9_.-]+)/(?<repo>[A-Za-z0-9_.-]+?)(?:\.git)?/?$') {
        throw 'The origin remote must be an HTTPS or SSH GitHub URL without credentials.'
    }
    [pscustomobject]@{ host = $Matches.host.ToLowerInvariant(); owner = $Matches.owner; repository = $Matches.repo }
}

function Find-PrPublishTemplate {
    param([string]$Root)
    foreach ($relative in @('pull_request_template.md', '.github/pull_request_template.md', 'docs/pull_request_template.md')) {
        $path = Join-Path $Root $relative
        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }
    $null
}

function Get-PrPublishStatus {
    param([string]$RepositoryPath = (Get-Location).Path, [string]$Base, [switch]$Fetch)
    $root = Invoke-PrPublishGit $RepositoryPath @('rev-parse', '--show-toplevel')
    $branch = Invoke-PrPublishGit $root @('branch', '--show-current')
    if (-not $branch) { throw 'Check out a branch; a detached HEAD has no pull request.' }
    $repository = Get-PrPublishRepository (Invoke-PrPublishGit $root @('remote', 'get-url', 'origin'))
    if (-not $Base) { $Base = Get-PrPublishDefaultBase $root }
    $fetched = if ($Fetch) { Invoke-PrPublishFetch $root $Base $branch } else { [pscustomobject]@{ fetched = $false; error = $null } }
    $head = Invoke-PrPublishGit $root @('rev-parse', 'HEAD')
    $upstream = Invoke-PrPublishGit $root @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}') -AllowFailure
    $upstreamHead = if ($upstream) { Invoke-PrPublishGit $root @('rev-parse', '@{u}') } else { $null }
    $dirty = @((Invoke-PrPublishGit $root @('status', '--porcelain')) -split "`n" | Where-Object { $_ }).Count
    $behind = $null; $ahead = $null
    if ($Base -and (Invoke-PrPublishGit $root @('rev-parse', '--verify', '--quiet', "refs/remotes/origin/$Base") -AllowFailure)) {
        $counts = (Invoke-PrPublishGit $root @('rev-list', '--left-right', '--count', "origin/$Base...HEAD")) -split '\s+'
        $behind = [int]$counts[0]; $ahead = [int]$counts[1]
    }
    $endpoint = "repos/$($repository.owner)/$($repository.repository)/pulls?head=$($repository.owner):$branch&state=all&per_page=20"
    $pulls = @(ConvertFrom-Json -InputObject (Invoke-PrPublishGh @('api', '--hostname', $repository.host, $endpoint)) -NoEnumerate | ForEach-Object { $_ })
    $open = $pulls | Where-Object state -CEQ 'open' | Select-Object -First 1
    [pscustomobject]@{
        root = $root; host = $repository.host; owner = $repository.owner; repository = $repository.repository
        branch = $branch; base = $Base; head = $head; upstream = $upstream; pushed = ($upstreamHead -and $upstreamHead -ceq $head)
        uncommittedFiles = $dirty; behind = $behind; ahead = $ahead; fetched = $fetched.fetched; fetchError = $fetched.error; template = Find-PrPublishTemplate $root
        pullRequest = $(if ($open) { [pscustomobject]@{ number = $open.number; url = $open.html_url; draft = [bool]$open.draft; base = $open.base.ref; head = $open.head.sha; title = $open.title; nodeId = $open.node_id } })
        closedPullRequests = @($pulls | Where-Object state -CNE 'open' | ForEach-Object number)
    }
}

# Commits the working changes as planned. Every change must be in exactly one planned commit or
# listed in "exclude", so nothing is committed or left behind by accident. Files are committed whole.
function Invoke-PrPublishCommit {
    param([string]$RepositoryPath = (Get-Location).Path, [string]$PlanFile, [string]$Base, [switch]$Apply)
    if (-not $PlanFile) { throw 'Supply -PlanFile with the planned commits.' }
    $root = Invoke-PrPublishGit $RepositoryPath @('rev-parse', '--show-toplevel')
    $plan = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $PlanFile).Path).TrimStart([char]0xFEFF) | ConvertFrom-Json
    $changes = @(Get-PrPublishChanges $root)
    if (-not $changes.Count) { throw 'There are no uncommitted changes to commit.' }
    if (@($changes | Where-Object { $_.code -match '^(DD|AU|UD|UA|DU|AA|UU)$' }).Count) { throw 'Resolve the merge conflicts before committing.' }
    $changed = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($change in $changes) { $changed[$change.path] = $change }
    $planned = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $commits = @(foreach ($entry in @($plan.commits | Where-Object { $null -ne $_ })) {
        $message = [string]$entry.message
        if (-not $message.Trim()) { throw 'Every planned commit needs a message.' }
        $subject = ($message.Trim() -split "`r?`n")[0]
        $files = @($entry.files | Where-Object { $_ } | ForEach-Object { ([string]$_).Replace('\', '/') })
        if (-not $files.Count) { throw "Planned commit '$subject' lists no files." }
        foreach ($file in $files) {
            if (-not $changed.ContainsKey($file)) { throw "Planned file is not an uncommitted change: $file" }
            if (-not $planned.Add($file)) { throw "A file is planned in more than one commit: $file" }
        }
        [pscustomobject]@{ message = $message; subject = $subject; files = $files }
    })
    if (-not $commits.Count) { throw 'The plan needs at least one commit.' }
    $excluded = @($plan.exclude | Where-Object { $_ } | ForEach-Object { ([string]$_).Replace('\', '/') })
    foreach ($file in $excluded) {
        if (-not $changed.ContainsKey($file)) { throw "Excluded file is not an uncommitted change: $file" }
        if ($planned.Contains($file)) { throw "A file is both planned and excluded: $file" }
    }
    $missing = @($changes | Where-Object { -not $planned.Contains($_.path) -and $_.path -cnotin $excluded } | ForEach-Object path)
    if ($missing.Count) { throw ('Every change must be committed or excluded. Not in the plan: ' + ($missing -join ', ')) }
    $branch = Invoke-PrPublishGit $root @('branch', '--show-current')
    if (-not $branch) { throw 'Check out a branch; a detached HEAD has no pull request.' }
    if (-not $Base) { $Base = Get-PrPublishDefaultBase $root }
    $newBranch = [string]$plan.branch
    if ($newBranch) {
        if (-not (Invoke-PrPublishGit $root @('check-ref-format', '--branch', $newBranch) -AllowFailure)) { throw "Not a valid branch name: $newBranch" }
        if (Invoke-PrPublishGit $root @('rev-parse', '--verify', '--quiet', "refs/heads/$newBranch") -AllowFailure) { throw "Branch '$newBranch' already exists." }
        if (Invoke-PrPublishGit $root @('rev-parse', '--verify', '--quiet', "refs/remotes/origin/$newBranch") -AllowFailure) { throw "Branch '$newBranch' already exists on origin." }
    }
    elseif ($Base -and $branch -ceq $Base) { throw "The current branch is the base branch '$Base'; name a new branch in the plan." }
    $result = [pscustomobject]@{
        preview = -not $Apply; branch = $(if ($newBranch) { $newBranch } else { $branch }); newBranch = [bool]$newBranch
        commits = @($commits | ForEach-Object { [pscustomobject]@{ sha = $null; subject = $_.subject; files = $_.files } }); excluded = $excluded
    }
    if (-not $Apply) { return $result }
    if ($newBranch) { $null = Invoke-PrPublishGit $root @('switch', '--quiet', '-c', $newBranch) }
    # Start from an empty index, so partly staged files are committed whole and nothing unplanned rides along.
    $null = Invoke-PrPublishGit $root @('reset', '--quiet')
    for ($index = 0; $index -lt $commits.Count; $index++) {
        $commit = $commits[$index]
        $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($file in $commit.files) {
            $null = $paths.Add($file)
            if ($changed[$file].originalPath) { $null = $paths.Add($changed[$file].originalPath) }
        }
        $messageFile = Join-Path ([IO.Path]::GetTempPath()) ('pr-publish-commit-' + [guid]::NewGuid().ToString('N') + '.txt')
        try {
            $null = Invoke-PrPublishGit $root (@('--literal-pathspecs', 'add', '--all', '--') + @($paths))
            $staged = @((Invoke-PrPublishGitRaw $root @('diff', '--cached', '--name-only', '--no-renames', '-z')) -split "`0" | Where-Object { $_ })
            if ($staged.Count -ne $paths.Count -or @($staged | Where-Object { -not $paths.Contains($_) }).Count) { throw 'the staged files differ from the plan' }
            [IO.File]::WriteAllText($messageFile, $commit.message, [Text.UTF8Encoding]::new($false))
            $null = Invoke-PrPublishGit $root @('commit', '--quiet', '--cleanup=whitespace', '--file', $messageFile)
            $result.commits[$index].sha = Invoke-PrPublishGit $root @('rev-parse', 'HEAD')
        }
        catch {
            $made = @($result.commits | Where-Object sha | ForEach-Object { "$($_.sha.Substring(0, 7)) $($_.subject)" })
            $done = if ($made.Count) { ' Commits made: ' + ($made -join '; ') + '.' } else { ' No commit was made.' }
            throw "Committing '$($commit.subject)' failed: $($_.Exception.Message.TrimEnd('.')).$done Nothing was pushed."
        }
        finally { Remove-Item -LiteralPath $messageFile -Force -ErrorAction SilentlyContinue }
    }
    $result
}

# Rebases the branch onto origin's base. A conflict or failure undoes the rebase, leaving the branch as it was.
function Invoke-PrPublishRebase {
    param([string]$RepositoryPath = (Get-Location).Path, [string]$Base, [switch]$Apply)
    $root = Invoke-PrPublishGit $RepositoryPath @('rev-parse', '--show-toplevel')
    $branch = Invoke-PrPublishGit $root @('branch', '--show-current')
    if (-not $branch) { throw 'Check out a branch; a detached HEAD has no pull request.' }
    if (-not $Base) { $Base = Get-PrPublishDefaultBase $root }
    if (-not $Base) { throw 'Supply -Base; the remote default branch is unknown.' }
    if ($branch -ceq $Base) { throw "The current branch is the base branch '$Base'; rebase a feature branch." }
    foreach ($name in 'rebase-merge', 'rebase-apply') {
        $path = Invoke-PrPublishGit $root @('rev-parse', '--git-path', $name)
        if (Test-Path -LiteralPath $(if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $root $path })) { throw 'A rebase is already in progress; finish or abort it first.' }
    }
    $baseRef = "origin/$Base"
    if (-not (Invoke-PrPublishGit $root @('rev-parse', '--verify', '--quiet', "refs/remotes/$baseRef") -AllowFailure)) { throw "$baseRef is unknown; fetch it first." }
    $counts = (Invoke-PrPublishGit $root @('rev-list', '--left-right', '--count', "$baseRef...HEAD")) -split '\s+'
    $upstreamHead = Invoke-PrPublishGit $root @('rev-parse', '--verify', '--quiet', '@{u}') -AllowFailure
    $published = if ($upstreamHead) { [int](Invoke-PrPublishGit $root @('rev-list', '--count', "$baseRef..$upstreamHead")) } else { 0 }
    # Rebasing rewrites the branch's own commits, so any that were already pushed need a force push.
    $plan = [pscustomobject]@{
        preview = -not $Apply; base = $Base; behind = [int]$counts[0]; ahead = [int]$counts[1]; rebased = $false
        head = (Invoke-PrPublishGit $root @('rev-parse', 'HEAD')); forcePush = ($published -gt 0); expectedRemoteHead = $(if ($published -gt 0) { $upstreamHead })
    }
    if (-not $Apply -or $plan.behind -eq 0) { return $plan }
    $output = & git -C $root -c rebase.autoStash=true rebase --quiet $baseRef 2>&1
    if ($LASTEXITCODE -ne 0) {
        $null = & git -C $root rebase --abort 2>&1
        throw "Rebasing onto $baseRef hit conflicts or failed, so it was undone; nothing was pushed. $((@($output) | ForEach-Object { "$_" } | Select-Object -First 3) -join ' ')"
    }
    $plan.rebased = $true
    $plan.head = Invoke-PrPublishGit $root @('rev-parse', 'HEAD')
    $plan
}

# Pushes the branch. A remote branch with commits the local one lacks is pushed over only with
# -ExpectedRemoteHead, the exact remote commit the user approved replacing, as a force-with-lease.
function Push-PrPublishBranch {
    param([string]$RepositoryPath = (Get-Location).Path, [string]$Base, [string]$ExpectedRemoteHead, [switch]$Apply)
    $root = Invoke-PrPublishGit $RepositoryPath @('rev-parse', '--show-toplevel')
    $branch = Invoke-PrPublishGit $root @('branch', '--show-current')
    if (-not $branch) { throw 'Check out a branch; a detached HEAD has no pull request.' }
    if (-not $Base) { $Base = Get-PrPublishDefaultBase $root }
    if ($Base -and $branch -ceq $Base) { throw "The current branch is the base branch '$Base'; publish from a feature branch." }
    $head = Invoke-PrPublishGit $root @('rev-parse', 'HEAD')
    $upstream = Invoke-PrPublishGit $root @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}') -AllowFailure
    $plan = [pscustomobject]@{ preview = -not $Apply; branch = $branch; head = $head; upstream = $upstream; setUpstream = -not $upstream; ahead = $null; force = $false; pushed = $false }
    if ($upstream) {
        $remote = Invoke-PrPublishGit $root @('config', "branch.$branch.remote")
        if ($remote -ceq '.') { throw "The branch tracks the local branch '$upstream'; set its upstream on origin first." }
        $mergeRef = Invoke-PrPublishGit $root @('config', "branch.$branch.merge")
        $counts = (Invoke-PrPublishGit $root @('rev-list', '--left-right', '--count', '@{u}...HEAD')) -split '\s+'
        $plan.ahead = [int]$counts[1]
        if ([int]$counts[0] -gt 0) {
            $upstreamHead = Invoke-PrPublishGit $root @('rev-parse', '@{u}')
            if (-not $ExpectedRemoteHead) { throw "The remote branch '$upstream' has commits this branch doesn't have. Pulling or a force push needs your decision; nothing was pushed." }
            if ($ExpectedRemoteHead -cne $upstreamHead) { throw "The remote branch '$upstream' is not at the approved commit; nothing was pushed." }
            if ($plan.ahead -eq 0) { throw "The remote branch '$upstream' is ahead and this branch has nothing new; pull it instead." }
            $plan.force = $true
        }
        elseif ($plan.ahead -eq 0) { $plan.pushed = $true; return $plan }
        $arguments = if ($plan.force) { @('push', "--force-with-lease=$($mergeRef):$ExpectedRemoteHead", $remote, "HEAD:$mergeRef") } else { @('push', $remote, "HEAD:$mergeRef") }
    }
    else { $arguments = @('push', '--set-upstream', 'origin', $branch) }
    if (-not $Apply) { return $plan }
    $result = Invoke-PrPublishGitRemote $root $arguments
    if ($result.exitCode -ne 0) { throw "git push failed (exit $($result.exitCode)): $($result.output)" }
    $pushedHead = Invoke-PrPublishGit $root @('rev-parse', '@{u}') -AllowFailure
    if ($pushedHead -cne $head) { throw 'The push could not be verified: the upstream does not match HEAD.' }
    $plan.upstream = Invoke-PrPublishGit $root @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}')
    $plan.pushed = $true
    $plan
}

function Get-PrPublishSections {
    param([string]$Text)
    $sections = [Collections.Generic.List[object]]::new()
    $current = [pscustomobject]@{ heading = ''; lines = [Collections.Generic.List[string]]::new() }
    $inFence = $false
    foreach ($line in ($Text -split "`n")) {
        if ($line -match '^\s*```') { $inFence = -not $inFence }
        if (-not $inFence -and $line -match '^#{1,6}\s+(.+?)\s*$') {
            $sections.Add($current)
            $current = [pscustomobject]@{ heading = $Matches[1].Trim().TrimEnd(':').Trim(); lines = [Collections.Generic.List[string]]::new() }
            continue
        }
        $current.lines.Add($line)
    }
    $sections.Add($current)
    $sections
}

function Get-PrPublishCells {
    param([string]$Row)
    $cells = @($Row.Trim() -split '(?<!\\)\|')
    if ($cells.Count -lt 3) { return @() }
    @($cells[1..($cells.Count - 2)] | ForEach-Object { $_.Trim() })
}

function Test-PrPublishBody {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body, [string]$Template, [string]$PreviousBody, [string]$RepositoryPath)
    $findings = [Collections.Generic.List[object]]::new()
    $text = ($Body -replace "`r`n", "`n").TrimStart([char]0xFEFF)
    $sections = Get-PrPublishSections $text
    # An update keeps the existing description as written, so style checks cover only text it adds or changes.
    $keeping = -not [string]::IsNullOrWhiteSpace($PreviousBody)
    $previousLines = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    if ($keeping) { foreach ($previousLine in (($PreviousBody -replace "`r`n", "`n") -split "`n")) { $null = $previousLines.Add($previousLine.Trim()) } }
    if ($Template -and -not $keeping) {
        $templateText = $Template -replace "`r`n", "`n"
        foreach ($heading in @(Get-PrPublishSections $templateText | Where-Object heading | ForEach-Object heading)) {
            if (-not @($sections | Where-Object { $_.heading -ieq $heading }).Count) { $findings.Add([pscustomobject]@{ code = 'MissingSection'; message = "Missing template section '$heading'." }) }
        }
        foreach ($line in ($templateText -split "`n")) {
            $instruction = $line.Trim()
            if ($instruction.Length -ge 20 -and $instruction -notmatch '^(#|-|\*|\||>|\d+\.)' -and $text.Contains($instruction)) {
                $findings.Add([pscustomobject]@{ code = 'TemplateText'; message = "Template instruction left in: $instruction" })
            }
        }
    }
    if ($text -notmatch '(?i)\bNo behavior change\b') {
        $scenario = @($sections | Where-Object { $_.heading -match '(?i)^Current vs\.? to-be' }) | Select-Object -First 1
        $rows = @($scenario.lines | Where-Object { $_ -match '^\s*\|' -and $_ -notmatch '^\s*\|\s*:?-{3,}' } | Select-Object -Skip 1)
        if (-not @($rows | Where-Object { @(Get-PrPublishCells $_ | Where-Object { $_ }).Count -ge 3 }).Count) {
            $findings.Add([pscustomobject]@{ code = 'ScenarioTable'; message = 'Add a current vs. to-be scenario table with filled rows, or write "No behavior change".' })
        }
    }
    $lines = $text -split "`n"
    $inFence = $false
    $tableWidth = $null
    $heading = ''
    # A table whose header row the repository template already has is the template's, not an extra one.
    $templateTables = @()
    $previousLine = ''
    foreach ($templateLine in (($Template -replace "`r`n", "`n") -split "`n")) {
        if ($templateLine -match '^\s*\|' -and $previousLine -notmatch '^\s*\|') { $templateTables += ($templateLine.Trim() -replace '\s+', ' ') }
        $previousLine = $templateLine
    }
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if ($line -match '^\s*```') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        $unchanged = $keeping -and $previousLines.Contains($line.Trim())
        if ($line -match '^#{1,6}\s+(.+?)\s*$') { $heading = $Matches[1].Trim() }
        if ($line -match '^\s*\|') {
            $width = @(Get-PrPublishCells $line).Count
            if ($null -eq $tableWidth) {
                $tableWidth = $width
                if (-not $unchanged -and $heading -notmatch '(?i)^Current vs\.? to-be' -and ($line.Trim() -replace '\s+', ' ') -cnotin $templateTables) {
                    $findings.Add([pscustomobject]@{ code = 'ExtraTable'; message = "Line $($index + 1) starts a table outside Current vs. to-be; write it as bullets." })
                }
            }
            elseif ($width -ne $tableWidth -and -not $unchanged) { $findings.Add([pscustomobject]@{ code = 'TableColumns'; message = "Line $($index + 1) has $width cells; its table header has $tableWidth." }) }
        }
        else { $tableWidth = $null }
        if (-not $unchanged -and ($line -replace '`[^`]*`', '') -match '[\u2013\u2014]') { $findings.Add([pscustomobject]@{ code = 'Dash'; message = "Line $($index + 1) has an em or en dash outside code." }) }
    }
    if ($PreviousBody) {
        foreach ($target in @([regex]::Matches($PreviousBody, '\]\(([^)\s]+)\)|<(https?://[^>\s]+)>') | ForEach-Object { if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value } } | Select-Object -Unique)) {
            if (-not $text.Contains($target)) { $findings.Add([pscustomobject]@{ code = 'LinkRemoved'; message = "Link target removed: $target" }) }
        }
    }
    if ($RepositoryPath) {
        $proof = @($sections | Where-Object { $_.heading -match '(?i)^(Test Validation Proof|Validation)\b' }) | Select-Object -First 1
        $names = @([regex]::Matches((@($proof.lines) -join "`n"), '`([A-Za-z_][A-Za-z0-9_]*_[A-Za-z0-9_]+)`') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        foreach ($name in $names) {
            $null = & git -C $RepositoryPath grep -F -q -e $name 2>$null
            if ($LASTEXITCODE -ne 0) { $findings.Add([pscustomobject]@{ code = 'UnknownTest'; message = "Test name not found in the repository: $name" }) }
        }
    }
    , @($findings)
}

function Get-PrPublishLiveBody {
    param($Status)
    $pull = ConvertFrom-Json -InputObject (Invoke-PrPublishGh @('api', '--hostname', $Status.host, "repos/$($Status.owner)/$($Status.repository)/pulls/$($Status.pullRequest.number)"))
    [pscustomobject]@{ title = $pull.title; body = [string]$pull.body; draft = [bool]$pull.draft; url = $pull.html_url; head = $pull.head.sha; base = $pull.base.ref }
}

function Invoke-PrPublishCheck {
    param([string]$RepositoryPath = (Get-Location).Path, [string]$BodyFile, [string]$PreviousBodyFile, [string]$Base)
    $status = Get-PrPublishStatus $RepositoryPath -Base $Base
    $live = if ($status.pullRequest) { Get-PrPublishLiveBody $status } else { $null }
    if (-not $BodyFile -and -not $live) { throw 'No open pull request for this branch; supply -BodyFile to check a draft.' }
    $body = if ($BodyFile) { [IO.File]::ReadAllText((Resolve-Path -LiteralPath $BodyFile).Path) } else { $live.body }
    # The live description is the text an update keeps, including when it is checked on its own.
    $previous = if ($PreviousBodyFile) { [IO.File]::ReadAllText((Resolve-Path -LiteralPath $PreviousBodyFile).Path) } elseif ($live) { $live.body } else { $null }
    $template = if ($status.template) { [IO.File]::ReadAllText($status.template) } else { $null }
    [pscustomobject]@{ checked = $(if ($BodyFile) { $BodyFile } else { $live.url }); template = $status.template; findings = (Test-PrPublishBody $body -Template $template -PreviousBody $previous -RepositoryPath $status.root) }
}

# Adds the Current vs. to-be section, or replaces the existing one, and keeps every other line as written.
function Set-PrPublishScenarioTable {
    param([AllowEmptyString()][string]$Body, [Parameter(Mandatory = $true)][string]$Table)
    $newline = if ($Body -match "`r`n") { "`r`n" } else { "`n" }
    $lines = [Collections.Generic.List[string]]::new()
    $existing = ($Body -replace "`r`n", "`n").TrimStart([char]0xFEFF).TrimEnd()
    if ($existing) { foreach ($line in ($existing -split "`n")) { $lines.Add($line) } }
    $content = @(($Table -replace "`r`n", "`n").TrimStart([char]0xFEFF).Trim() -split "`n")
    if ($content[0] -match '^#{1,6}\s+Current vs\.? to-be') { $content = @((@($content | Select-Object -Skip 1) -join "`n").Trim() -split "`n") }
    if (-not ($content -join '').Trim()) { throw 'The table file has no scenario table or "No behavior change" line.' }
    $start = -1
    $end = $lines.Count
    $level = 0
    $topHeadings = [Collections.Generic.List[int]]::new()
    $inFence = $false
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^\s*```') { $inFence = -not $inFence; continue }
        if ($inFence -or $lines[$index] -notmatch '^(#{1,6})\s+(.+?)\s*$') { continue }
        $headingLevel = $Matches[1].Length
        if ($start -ge 0 -and $end -eq $lines.Count -and $headingLevel -le $level) { $end = $index }
        if ($start -lt 0 -and $Matches[2] -match '(?i)^Current vs\.? to-be') { $start = $index; $level = $headingLevel }
        if ($headingLevel -le 2) { $topHeadings.Add($index) }
    }
    if ($start -ge 0) {
        $lines.RemoveRange($start + 1, $end - $start - 1)
        $lines.InsertRange($start + 1, [string[]](@('') + $content + @('')))
        $operation = 'Replaced'
    }
    else {
        $section = [string[]](@('### Current vs. to-be', '') + $content)
        # With sections, the table closes the first one, as a subsection of the summary; otherwise it follows the text.
        if ($topHeadings.Count -ge 2) {
            $at = $topHeadings[1]
            while ($at -gt 0 -and -not $lines[$at - 1].Trim()) { $lines.RemoveAt($at - 1); $at-- }
            $lines.InsertRange($at, [string[]](@('') + $section + @('')))
        }
        else {
            if ($lines.Count) { $lines.Add('') }
            $lines.AddRange($section)
        }
        $operation = 'Added'
    }
    [pscustomobject]@{ body = ((($lines -join "`n").TrimEnd() + "`n") -replace "`n", $newline); operation = $operation }
}

function ConvertTo-PrPublishComparable {
    param([string]$Text)
    ($Text -replace "`r`n", "`n").TrimStart([char]0xFEFF).Trim()
}

# Creates the branch's pull request or updates its open one. -TableFile adds or replaces only the
# Current vs. to-be section, in -BodyFile or else in the live description, so nothing else changes.
# A new pull request always opens ready for review, and an open one keeps its draft state.
function Publish-PrPublishPullRequest {
    param([string]$RepositoryPath = (Get-Location).Path, [string]$Title, [string]$BodyFile, [string]$TableFile, [string]$Base, [switch]$Apply)
    $status = Get-PrPublishStatus $RepositoryPath -Base $Base
    if ($status.base -and $status.branch -ceq $status.base) { throw "The current branch is the base branch '$($status.base)'; publish from a feature branch." }
    $pull = $status.pullRequest
    $live = if ($pull) { Get-PrPublishLiveBody $status } else { $null }
    $body = if ($BodyFile) { [IO.File]::ReadAllText((Resolve-Path -LiteralPath $BodyFile).Path).TrimStart([char]0xFEFF) } elseif ($TableFile -and $live) { $live.body } else { $null }
    if ($TableFile) {
        if ($null -eq $body) { throw 'A new pull request needs -BodyFile with its description.' }
        $body = (Set-PrPublishScenarioTable $body ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $TableFile).Path))).body
    }
    if (-not $pull) {
        if (-not $Title -or $null -eq $body) { throw 'A new pull request needs -Title and -BodyFile.' }
        if (-not $status.base) { throw 'Supply -Base; the remote default branch is unknown.' }
        if ($Apply -and -not $status.pushed) { throw 'Push the branch so its upstream matches HEAD before creating the pull request.' }
    }
    $changeTitle = [bool]($Title -and (-not $live -or $Title -cne $live.title))
    $changeBody = $null -ne $body -and (-not $live -or (ConvertTo-PrPublishComparable $live.body) -cne (ConvertTo-PrPublishComparable $body))
    $plan = [pscustomobject]@{ operation = $(if ($pull) { 'Update' } else { 'Create' }); number = $pull.number; head = $status.branch; base = $status.base; title = $changeTitle; body = $changeBody; draft = $(if ($pull) { $pull.draft } else { $false }); pushed = [bool]$status.pushed }
    if (-not $Apply) {
        $plan | Add-Member -NotePropertyName preview -NotePropertyValue $true
        if ($null -ne $body) {
            $previewRoot = Join-Path ([IO.Path]::GetTempPath()) 'pr-publish'
            New-Item -ItemType Directory -Path $previewRoot -Force | Out-Null
            $previewPath = Join-Path $previewRoot ('preview-{0}-{1}-{2}-{3}.md' -f $status.host, $status.owner, $status.repository, ($status.branch -replace '[^A-Za-z0-9._-]', '-'))
            [IO.File]::WriteAllText($previewPath, $body, [Text.UTF8Encoding]::new($false))
            $template = if ($status.template) { [IO.File]::ReadAllText($status.template) } else { $null }
            $plan | Add-Member -NotePropertyMembers @{ bodyFile = $previewPath; findings = (Test-PrPublishBody $body -Template $template -PreviousBody $live.body -RepositoryPath $status.root) }
        }
        return $plan
    }
    $pulls = "repos/$($status.owner)/$($status.repository)/pulls"
    $bodyPath = $null
    $backup = $null
    try {
        if ($changeBody) {
            $bodyPath = Join-Path ([IO.Path]::GetTempPath()) ('pr-publish-body-' + [guid]::NewGuid().ToString('N') + '.md')
            [IO.File]::WriteAllText($bodyPath, $body, [Text.UTF8Encoding]::new($false))
        }
        if (-not $pull) {
            $created = ConvertFrom-Json -InputObject (Invoke-PrPublishGh @('api', '--hostname', $status.host, '-X', 'POST', $pulls, '-f', "title=$Title", '-f', "head=$($status.branch)", '-f', "base=$($status.base)", '-F', "body=@$bodyPath", '-F', 'draft=false'))
            $number = $created.number
        }
        else {
            $number = $pull.number
            if ($changeTitle -or $changeBody) {
                $backupRoot = Join-Path ([IO.Path]::GetTempPath()) 'pr-publish'
                New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
                $backup = Join-Path $backupRoot ('{0}-{1}-{2}-{3}-{4:yyyyMMddHHmmss}.md' -f $status.host, $status.owner, $status.repository, $number, (Get-Date))
                [IO.File]::WriteAllText($backup, "Title: $($live.title)`n`n$($live.body)", [Text.UTF8Encoding]::new($false))
                $fields = @()
                if ($changeTitle) { $fields += @('-f', "title=$Title") }
                if ($changeBody) { $fields += @('-F', "body=@$bodyPath") }
                $null = Invoke-PrPublishGh (@('api', '--hostname', $status.host, '-X', 'PATCH', "$pulls/$number") + $fields)
            }
        }
        $after = Get-PrPublishLiveBody ([pscustomobject]@{ host = $status.host; owner = $status.owner; repository = $status.repository; pullRequest = [pscustomobject]@{ number = $number } })
        if ($Title -and $after.title -cne $Title) { throw "Read-back title differs on pull request $number." }
        if ($null -ne $body -and (ConvertTo-PrPublishComparable $after.body) -cne (ConvertTo-PrPublishComparable $body)) { throw "Read-back description differs on pull request $number." }
        if ($after.draft -ne $plan.draft) { throw "Read-back draft state differs on pull request $number." }
        [pscustomobject]@{ operation = $plan.operation; number = $number; url = $after.url; base = $after.base; head = $after.head; draft = $after.draft; backup = $backup }
    }
    finally { if ($bodyPath) { Remove-Item -LiteralPath $bodyPath -Force -ErrorAction SilentlyContinue } }
}
