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
    param([string]$RepositoryPath = (Get-Location).Path, [string]$Base)
    $root = Invoke-PrPublishGit $RepositoryPath @('rev-parse', '--show-toplevel')
    $branch = Invoke-PrPublishGit $root @('branch', '--show-current')
    if (-not $branch) { throw 'Check out a branch; a detached HEAD has no pull request.' }
    $repository = Get-PrPublishRepository (Invoke-PrPublishGit $root @('remote', 'get-url', 'origin'))
    if (-not $Base) {
        $originHead = Invoke-PrPublishGit $root @('symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD') -AllowFailure
        if ($originHead) { $Base = $originHead -replace '^origin/', '' }
    }
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
        uncommittedFiles = $dirty; behind = $behind; ahead = $ahead; template = Find-PrPublishTemplate $root
        pullRequest = $(if ($open) { [pscustomobject]@{ number = $open.number; url = $open.html_url; draft = [bool]$open.draft; base = $open.base.ref; head = $open.head.sha; title = $open.title; nodeId = $open.node_id } })
        closedPullRequests = @($pulls | Where-Object state -CNE 'open' | ForEach-Object number)
    }
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
    if ($Template) {
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
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if ($line -match '^\s*```') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        if ($line -match '^\s*\|') {
            $width = @(Get-PrPublishCells $line).Count
            if ($null -eq $tableWidth) { $tableWidth = $width }
            elseif ($width -ne $tableWidth) { $findings.Add([pscustomobject]@{ code = 'TableColumns'; message = "Line $($index + 1) has $width cells; its table header has $tableWidth." }) }
        }
        else { $tableWidth = $null }
        if (($line -replace '`[^`]*`', '') -match '[\u2013\u2014]') { $findings.Add([pscustomobject]@{ code = 'Dash'; message = "Line $($index + 1) has an em or en dash outside code." }) }
    }
    if ($PreviousBody) {
        foreach ($target in @([regex]::Matches($PreviousBody, '\]\(([^)\s]+)\)|<(https?://[^>\s]+)>') | ForEach-Object { if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value } } | Select-Object -Unique)) {
            if (-not $text.Contains($target)) { $findings.Add([pscustomobject]@{ code = 'LinkRemoved'; message = "Link target removed: $target" }) }
        }
    }
    if ($RepositoryPath) {
        $proof = @($sections | Where-Object { $_.heading -match '(?i)^Test Validation Proof' }) | Select-Object -First 1
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
    $previous = if ($PreviousBodyFile) { [IO.File]::ReadAllText((Resolve-Path -LiteralPath $PreviousBodyFile).Path) } elseif ($BodyFile -and $live) { $live.body } else { $null }
    $template = if ($status.template) { [IO.File]::ReadAllText($status.template) } else { $null }
    [pscustomobject]@{ checked = $(if ($BodyFile) { $BodyFile } else { $live.url }); template = $status.template; findings = (Test-PrPublishBody $body -Template $template -PreviousBody $previous -RepositoryPath $status.root) }
}

function ConvertTo-PrPublishComparable {
    param([string]$Text)
    ($Text -replace "`r`n", "`n").TrimStart([char]0xFEFF).Trim()
}

function Publish-PrPublishPullRequest {
    param([string]$RepositoryPath = (Get-Location).Path, [string]$Title, [string]$BodyFile, [string]$Base, [switch]$Draft, [switch]$Ready, [switch]$Apply)
    if ($Draft -and $Ready) { throw 'Choose -Draft or -Ready, not both.' }
    $status = Get-PrPublishStatus $RepositoryPath -Base $Base
    if ($status.base -and $status.branch -ceq $status.base) { throw "The current branch is the base branch '$($status.base)'; publish from a feature branch." }
    $body = $null; $bodyPath = $null
    if ($BodyFile) {
        $body = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $BodyFile).Path).TrimStart([char]0xFEFF)
        $bodyPath = Join-Path ([IO.Path]::GetTempPath()) ('pr-publish-body-' + [guid]::NewGuid().ToString('N') + '.md')
        [IO.File]::WriteAllText($bodyPath, $body, [Text.UTF8Encoding]::new($false))
    }
    $pulls = "repos/$($status.owner)/$($status.repository)/pulls"
    $pull = $status.pullRequest
    $backup = $null
    try {
        if (-not $pull) {
            if (-not $Title -or -not $bodyPath) { throw 'A new pull request needs -Title and -BodyFile.' }
            if (-not $status.base) { throw 'Supply -Base; the remote default branch is unknown.' }
            if (-not $status.pushed) { throw 'Push the branch so its upstream matches HEAD before creating the pull request.' }
            $plan = [pscustomobject]@{ operation = 'Create'; head = $status.branch; base = $status.base; title = $Title; draft = [bool]$Draft }
            if (-not $Apply) { $plan | Add-Member -NotePropertyName preview -NotePropertyValue $true; return $plan }
            $created = ConvertFrom-Json -InputObject (Invoke-PrPublishGh @('api', '--hostname', $status.host, '-X', 'POST', $pulls, '-f', "title=$Title", '-f', "head=$($status.branch)", '-f', "base=$($status.base)", '-F', "body=@$bodyPath", '-F', "draft=$(([bool]$Draft).ToString().ToLowerInvariant())"))
            $number = $created.number
            $expectedDraft = [bool]$Draft
        }
        else {
            $changeDraft = ($Draft -and -not $pull.draft) -or ($Ready -and $pull.draft)
            $plan = [pscustomobject]@{ operation = 'Update'; number = $pull.number; url = $pull.url; title = [bool]($Title -and $Title -cne $pull.title); body = [bool]$bodyPath
                draft = $(if ($changeDraft) { [bool]$Draft } else { $pull.draft }) }
            if (-not $Apply) { $plan | Add-Member -NotePropertyName preview -NotePropertyValue $true; return $plan }
            $number = $pull.number
            if ($plan.title -or $plan.body) {
                $current = Get-PrPublishLiveBody $status
                $backupRoot = Join-Path ([IO.Path]::GetTempPath()) 'pr-publish'
                New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
                $backup = Join-Path $backupRoot ('{0}-{1}-{2}-{3}-{4:yyyyMMddHHmmss}.md' -f $status.host, $status.owner, $status.repository, $number, (Get-Date))
                [IO.File]::WriteAllText($backup, "Title: $($current.title)`n`n$($current.body)", [Text.UTF8Encoding]::new($false))
                $fields = @()
                if ($plan.title) { $fields += @('-f', "title=$Title") }
                if ($plan.body) { $fields += @('-F', "body=@$bodyPath") }
                $null = Invoke-PrPublishGh (@('api', '--hostname', $status.host, '-X', 'PATCH', "$pulls/$number") + $fields)
            }
            if ($changeDraft) {
                $mutation = if ($Draft) { 'convertPullRequestToDraft' } else { 'markPullRequestReadyForReview' }
                $query = 'query=mutation($id:ID!){' + $mutation + '(input:{pullRequestId:$id}){pullRequest{isDraft}}}'
                $null = Invoke-PrPublishGh @('api', 'graphql', '--hostname', $status.host, '-f', $query, '-f', "id=$($pull.nodeId)")
            }
            $expectedDraft = $plan.draft
        }
        $live = Get-PrPublishLiveBody ([pscustomobject]@{ host = $status.host; owner = $status.owner; repository = $status.repository; pullRequest = [pscustomobject]@{ number = $number } })
        if ($Title -and $live.title -cne $Title) { throw "Read-back title differs on pull request $number." }
        if ($bodyPath -and (ConvertTo-PrPublishComparable $live.body) -cne (ConvertTo-PrPublishComparable $body)) { throw "Read-back description differs on pull request $number." }
        if ($live.draft -ne $expectedDraft) { throw "Read-back draft state differs on pull request $number." }
        [pscustomobject]@{ operation = $plan.operation; number = $number; url = $live.url; base = $live.base; head = $live.head; draft = $live.draft; backup = $backup }
    }
    finally { if ($bodyPath) { Remove-Item -LiteralPath $bodyPath -Force -ErrorAction SilentlyContinue } }
}
