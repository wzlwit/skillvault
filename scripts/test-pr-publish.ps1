$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../skills/github/pr-publish/scripts/pr-publish-core.ps1')
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('pr-publish-' + [guid]::NewGuid().ToString('N'))

function Assert-PublishFailure {
    param([scriptblock]$Operation, [string]$Expected)
    try { & $Operation | Out-Null }
    catch { if ($_.Exception.Message -notlike "*$Expected*") { throw }; return }
    throw "Expected failure: $Expected"
}

function Invoke-FixtureGit {
    param([string[]]$Arguments)
    $output = & git -C $script:repo @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $output" }
}

function Get-FixtureCodes {
    param($Findings)
    @($Findings | ForEach-Object code | Sort-Object -Unique) -join ','
}

try {
    foreach ($case in @(
        @('https://github.com/Owner/Repo.git', 'github.com', 'Owner', 'Repo'),
        @('git@Example.ghe.com:team/tool.git', 'example.ghe.com', 'team', 'tool'),
        @('ssh://git@example.ghe.com:22/team/tool', 'example.ghe.com', 'team', 'tool'))) {
        $parsed = Get-PrPublishRepository $case[0]
        if ($parsed.host -cne $case[1] -or $parsed.owner -cne $case[2] -or $parsed.repository -cne $case[3]) { throw "Remote parsing failed for $($case[0])." }
    }
    Assert-PublishFailure { Get-PrPublishRepository 'https://user:secret@github.com/owner/repo' } 'without credentials'

    $script:repo = Join-Path $fixtureRoot 'repo'
    New-Item -ItemType Directory -Path (Join-Path $script:repo 'tests') -Force | Out-Null
    Invoke-FixtureGit @('init', '--quiet', '-b', 'develop')
    $template = "## Description`n`nPlease include a summary of the change and which issue is fixed.`n`n## Current vs. to-be`n`nFor a bug fix or behavior change, compare each affected scenario.`n`n| # | Scenario | Current (``develop``) | To-be (this PR) |`n|---|---|---|---|`n| 1 |  |  |  |`n`n## Checklist:`n`n- [ ] All new and existing unit tests passed.`n`n## Test Validation Proof`nFor each scenario row above, name the tests that cover it.`n"
    [IO.File]::WriteAllText((Join-Path $script:repo 'pull_request_template.md'), $template)
    [IO.File]::WriteAllText((Join-Path $script:repo 'tests/WidgetTests.cs'), "public void Widget_RoundsUp_WhenHalf() { }`n")
    $commit = @('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgSign=false', 'commit', '--quiet', '-m')
    Invoke-FixtureGit @('add', '--all')
    Invoke-FixtureGit ($commit + @('base'))
    Invoke-FixtureGit @('remote', 'add', 'origin', 'https://example.ghe.com/team/tool.git')
    Invoke-FixtureGit @('update-ref', 'refs/remotes/origin/develop', 'HEAD')
    Invoke-FixtureGit @('symbolic-ref', 'refs/remotes/origin/HEAD', 'refs/remotes/origin/develop')
    Invoke-FixtureGit @('switch', '--quiet', '-c', 'users/me/fix')
    [IO.File]::WriteAllText((Join-Path $script:repo 'widget.txt'), 'rounded')
    Invoke-FixtureGit @('add', '--all')
    Invoke-FixtureGit ($commit + @('fix rounding'))
    Invoke-FixtureGit @('update-ref', 'refs/remotes/origin/users/me/fix', 'HEAD')
    Invoke-FixtureGit @('branch', '--quiet', '--set-upstream-to=origin/users/me/fix')

    $script:gh = [pscustomobject]@{ Calls = [Collections.Generic.List[object]]::new(); Pull = $null; CorruptReadBack = $false }
    function Invoke-PrPublishGh {
        param([string[]]$Arguments)
        $script:gh.Calls.Add(@($Arguments))
        $fields = @{}
        for ($index = 0; $index -lt $Arguments.Count - 1; $index++) {
            if ($Arguments[$index] -cin @('-f', '-F')) {
                $name, $value = $Arguments[$index + 1] -split '=', 2
                if ($Arguments[$index] -ceq '-F' -and $value.StartsWith('@')) { $value = [IO.File]::ReadAllText($value.Substring(1)) }
                elseif ($Arguments[$index] -ceq '-F' -and $value -cin @('true', 'false')) { $value = $value -ceq 'true' }
                $fields[$name] = $value
            }
        }
        $pull = $script:gh.Pull
        if ($Arguments[1] -ceq 'graphql') {
            if ($fields.id -cne $pull.node_id) { throw 'GraphQL used the wrong pull request ID.' }
            $pull.draft = $fields.query -match 'convertPullRequestToDraft'
            return '{"data":{}}'
        }
        $endpoint = @($Arguments | Where-Object { $_ -like 'repos/*' })[0]
        $method = if ($Arguments -ccontains '-X') { $Arguments[[array]::IndexOf($Arguments, '-X') + 1] } else { 'GET' }
        if ($endpoint -match '/pulls\?head=team:([^&]+)&') {
            $matching = @($pull | Where-Object { $_ -and $_.head.ref -ceq $Matches[1] })
            return ConvertTo-Json -InputObject $matching -Depth 6
        }
        if ($method -ceq 'POST') {
            $script:gh.Pull = [pscustomobject]@{ number = 7; html_url = 'https://example.ghe.com/team/tool/pull/7'; state = 'open'; draft = $fields.draft; title = $fields.title; body = $fields.body
                base = [pscustomobject]@{ ref = $fields.base }; head = [pscustomobject]@{ ref = $fields.head; sha = 'a' * 40 }; node_id = 'PR_fixture' }
            return $script:gh.Pull | ConvertTo-Json -Depth 6
        }
        if ($method -ceq 'PATCH') {
            if ($fields.ContainsKey('title')) { $pull.title = $fields.title }
            if ($fields.ContainsKey('body')) { $pull.body = $fields.body }
            return $pull | ConvertTo-Json -Depth 6
        }
        if ($endpoint -match '/pulls/7$') {
            $copy = $pull | ConvertTo-Json -Depth 6 | ConvertFrom-Json
            if ($script:gh.CorruptReadBack) { $copy.body = 'changed by someone else' }
            return $copy | ConvertTo-Json -Depth 6
        }
        throw "Unexpected gh call: $($Arguments -join ' ')"
    }

    $status = Get-PrPublishStatus $script:repo
    if ($status.branch -cne 'users/me/fix' -or $status.base -cne 'develop' -or -not $status.pushed -or $status.ahead -ne 1 -or $status.behind -ne 0 -or $status.pullRequest -or -not $status.template) { throw ('Status misread the branch: ' + ($status | ConvertTo-Json -Depth 4)) }

    $good = "## Description`n`nFixes [issue 12](https://example.ghe.com/team/tool/issues/12). Rounding now goes up at .5.`n`n## Current vs. to-be`n`n| # | Scenario | Current (``develop``) | To-be (this PR) |`n|---|---|---|---|`n| 1 | Round 2.5 | 2 | 3 |`n`n## Checklist:`n`n- [x] All new and existing unit tests passed.`n`n## Test Validation Proof`n`n| Row | Tests |`n|---|---|`n| 1 | ``Widget_RoundsUp_WhenHalf`` |`n"
    $findings = Test-PrPublishBody $good -Template $template -RepositoryPath $script:repo
    if ($findings.Count) { throw ('A complete description had findings: ' + ($findings | ConvertTo-Json)) }
    $cases = [ordered]@{
        'Dash' = $good.Replace('Rounding now', "Rounding $([char]0x2014) now")
        'MissingSection' = $good.Replace('## Checklist:', 'Checklist')
        'TemplateText' = $good.Replace('## Test Validation Proof', "## Test Validation Proof`nFor each scenario row above, name the tests that cover it.")
        'TableColumns' = $good.Replace('| 1 | Round 2.5 | 2 | 3 |', '| 1 | Round 2.5 | 2 |')
        'UnknownTest' = $good.Replace('Widget_RoundsUp_WhenHalf', 'Widget_Never_Written')
        'ScenarioTable' = $good.Replace('| 1 | Round 2.5 | 2 | 3 |', '| 1 |  |  |  |')
    }
    foreach ($expected in $cases.Keys) {
        $codes = Get-FixtureCodes (Test-PrPublishBody $cases[$expected] -Template $template -RepositoryPath $script:repo)
        if ($codes -cne $expected) { throw "Expected only $expected, got '$codes'." }
    }
    $noChange = $good -replace '(?s)\| # \| Scenario.*?\| 3 \|', 'No behavior change.'
    if ((Get-FixtureCodes (Test-PrPublishBody $noChange -Template $template)) -cne '') { throw 'A no-behavior-change description still required a scenario table.' }
    if ((Get-FixtureCodes (Test-PrPublishBody $good.Replace('https://example.ghe.com/team/tool/issues/12', 'issue-12') -Template $template -PreviousBody $good)) -cne 'LinkRemoved') { throw 'A removed link target was not reported.' }

    $bodyFile = Join-Path $fixtureRoot 'body.md'
    [IO.File]::WriteAllText($bodyFile, $good)
    [IO.File]::WriteAllText((Join-Path $script:repo 'widget.txt'), 'rounded twice')
    Invoke-FixtureGit @('add', '--all')
    Invoke-FixtureGit ($commit + @('unpushed'))
    Assert-PublishFailure { Publish-PrPublishPullRequest $script:repo -Title 'Round halves up' -BodyFile $bodyFile -Apply } 'Push the branch'
    Invoke-FixtureGit @('update-ref', 'refs/remotes/origin/users/me/fix', 'HEAD')
    Assert-PublishFailure { Publish-PrPublishPullRequest $script:repo -Draft -Ready } 'not both'

    $preview = Publish-PrPublishPullRequest $script:repo -Title 'Round halves up' -BodyFile $bodyFile
    if (-not $preview.preview -or $preview.operation -cne 'Create' -or $preview.draft -or $script:gh.Calls.Where({ $_ -ccontains '-X' }).Count) { throw 'Preview wrote to the remote or planned the wrong operation.' }
    $created = Publish-PrPublishPullRequest $script:repo -Title 'Round halves up' -BodyFile $bodyFile -Apply
    $post = $script:gh.Calls.Where({ $_ -ccontains 'POST' })
    if ($created.number -ne 7 -or $created.draft -or $created.url -notlike '*/pull/7' -or $post.Count -ne 1 -or $post[0] -cnotcontains 'draft=false' -or $post[0] -cnotcontains 'head=users/me/fix' -or $post[0] -cnotcontains 'base=develop') { throw 'Create did not open one ready PR for the branch against its base.' }
    if ((Get-FixtureCodes (Invoke-PrPublishCheck $script:repo).findings) -cne '') { throw 'Checking the live description reported findings.' }
    $rewrite = Join-Path $fixtureRoot 'rewrite.md'
    [IO.File]::WriteAllText($rewrite, $good.Replace('https://example.ghe.com/team/tool/issues/12', 'issue-12'))
    if ((Get-FixtureCodes (Invoke-PrPublishCheck $script:repo -BodyFile $rewrite).findings) -cne 'LinkRemoved') { throw 'A rewrite was not compared with the live description.' }

    $updated = $good.Replace('Rounding now goes up at .5.', 'Halves now round up.')
    [IO.File]::WriteAllText($bodyFile, $updated)
    $result = Publish-PrPublishPullRequest $script:repo -Title 'Round halves up' -BodyFile $bodyFile -Apply
    if ($script:gh.Pull.body -cne $updated -or -not $result.backup -or ([IO.File]::ReadAllText($result.backup)) -notlike '*Rounding now goes up at .5.*') { throw 'Update did not back up and replace the description.' }
    $lastPatch = $script:gh.Calls.Where({ $_ -ccontains 'PATCH' })[-1]
    if ($lastPatch -ccontains 'title=Round halves up') { throw 'An unchanged title was sent again.' }
    $script:gh.CorruptReadBack = $true
    Assert-PublishFailure { Publish-PrPublishPullRequest $script:repo -BodyFile $bodyFile -Apply } 'Read-back description differs'
    $script:gh.CorruptReadBack = $false

    $toDraft = Publish-PrPublishPullRequest $script:repo -Draft -Apply
    $toReady = Publish-PrPublishPullRequest $script:repo -Ready -Apply
    $mutations = @($script:gh.Calls.Where({ $_[1] -ceq 'graphql' }) | ForEach-Object { if (($_ -join ' ') -match 'convertPullRequestToDraft') { 'draft' } else { 'ready' } }) -join ','
    if (-not $toDraft.draft -or $toReady.draft -or $mutations -cne 'draft,ready' -or $toDraft.backup) { throw 'Draft and ready state changes were not applied through GraphQL and read back.' }
    $callsBefore = $script:gh.Calls.Count
    $null = Publish-PrPublishPullRequest $script:repo -Ready -Apply
    $newCalls = $script:gh.Calls.GetRange($callsBefore, $script:gh.Calls.Count - $callsBefore)
    if ($newCalls.Where({ $_[1] -ceq 'graphql' -or $_ -ccontains 'PATCH' }).Count) { throw 'An unchanged state was written again.' }

    Invoke-FixtureGit @('switch', '--quiet', 'develop')
    Assert-PublishFailure { Publish-PrPublishPullRequest $script:repo -Title 'Wrong' -BodyFile $bodyFile -Apply } 'base branch'
    Write-Output 'PR publish checks passed: remote parsing, branch status, description findings, preview without writes, create, backed-up update, read-back, draft/ready switching, and guards. All GitHub calls were fake.'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
