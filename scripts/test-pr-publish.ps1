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
    # Previews and backups go to the system temp folder; keep this run's files inside the fixture.
    $savedTemp = @($env:TMP, $env:TEMP)
    $env:TMP = $fixtureRoot
    $env:TEMP = $fixtureRoot
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
        if ($Arguments[1] -ceq 'graphql') { throw 'pr-publish never changes the draft state.' }
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
    $realFetch = ${function:Invoke-PrPublishFetch}
    $script:fetchCalls = [Collections.Generic.List[object]]::new()
    function Invoke-PrPublishFetch { param($Root, $Base, $Branch) $script:fetchCalls.Add(@($Base, $Branch)); [pscustomobject]@{ fetched = $false; error = 'offline fixture' } }
    $fetchedStatus = Get-PrPublishStatus $script:repo -Fetch
    Set-Item -LiteralPath Function:Invoke-PrPublishFetch -Value $realFetch
    if ($script:fetchCalls.Count -ne 1 -or ($script:fetchCalls[0] -join ',') -cne 'develop,users/me/fix' -or $fetchedStatus.fetched -or $fetchedStatus.fetchError -cne 'offline fixture' -or $fetchedStatus.behind -ne 0) { throw 'Status did not fetch the base and branch first, or a failed fetch stopped it.' }
    if ((Get-PrPublishStatus $script:repo).fetched -or $script:fetchCalls.Count -ne 1) { throw 'Status fetched without being asked.' }

    $good = "## Description`n`nFixes [issue 12](https://example.ghe.com/team/tool/issues/12). Rounding now goes up at .5.`n`n- ``widget.txt``: rounds half up (row 1)`n`n## Current vs. to-be`n`n| # | Scenario | Current (``develop``) | To-be (this PR) |`n|---|---|---|---|`n| 1 | Round 2.5 | 2 | 3 |`n`n## Checklist:`n`n- [x] All new and existing unit tests passed.`n`n## Test Validation Proof`n`n- Row 1: ``Widget_RoundsUp_WhenHalf```n"
    $findings = Test-PrPublishBody $good -Template $template -RepositoryPath $script:repo
    if ($findings.Count) { throw ('A complete description had findings: ' + ($findings | ConvertTo-Json)) }
    $cases = [ordered]@{
        'Dash' = $good.Replace('Rounding now', "Rounding $([char]0x2014) now")
        'MissingSection' = $good.Replace('## Checklist:', 'Checklist')
        'TemplateText' = $good.Replace('## Test Validation Proof', "## Test Validation Proof`nFor each scenario row above, name the tests that cover it.")
        'TableColumns' = $good.Replace('| 1 | Round 2.5 | 2 | 3 |', '| 1 | Round 2.5 | 2 |')
        'UnknownTest' = $good.Replace('Widget_RoundsUp_WhenHalf', 'Widget_Never_Written')
        'ScenarioTable' = $good.Replace('| 1 | Round 2.5 | 2 | 3 |', '| 1 |  |  |  |')
        'ExtraTable' = $good.Replace("- ``widget.txt``: rounds half up (row 1)", "| Path | What changed |`n|---|---|`n| ``widget.txt`` | Rounds half up |")
    }
    foreach ($expected in $cases.Keys) {
        $codes = Get-FixtureCodes (Test-PrPublishBody $cases[$expected] -Template $template -RepositoryPath $script:repo)
        if ($codes -cne $expected) { throw "Expected only $expected, got '$codes'." }
    }
    $templateTable = "| Risk | Mitigation |`n|---|---|`n"
    $riskTemplate = $template.Replace('## Checklist:', "## Risk`n`n$templateTable`n## Checklist:")
    $riskBody = $good.Replace('## Checklist:', "## Risk`n`n$templateTable| Rounding changes totals | Covered by row 1 |`n`n## Checklist:")
    if ((Get-FixtureCodes (Test-PrPublishBody $riskBody -Template $riskTemplate -RepositoryPath $script:repo)) -cne '') { throw 'A table the repository template asks for was reported as extra.' }
    $noChange = $good -replace '(?s)\| # \| Scenario.*?\| 3 \|', 'No behavior change.'
    if ((Get-FixtureCodes (Test-PrPublishBody $noChange -Template $template)) -cne '') { throw 'A no-behavior-change description still required a scenario table.' }
    if ((Get-FixtureCodes (Test-PrPublishBody $good.Replace('https://example.ghe.com/team/tool/issues/12', 'issue-12') -Template $template -PreviousBody $good)) -cne 'LinkRemoved') { throw 'A removed link target was not reported.' }

    $newTable = "| # | Scenario | Current (``develop``) | To-be (this PR) |`n|---|---|---|---|`n| 1 | Round 2.5 | 2 | 3 |`n| 2 | Round 2.4 | 2 | Same as current |"
    $expectedReplaced = $good.Replace('| 1 | Round 2.5 | 2 | 3 |', "| 1 | Round 2.5 | 2 | 3 |`n| 2 | Round 2.4 | 2 | Same as current |")
    $replaced = Set-PrPublishScenarioTable $good $newTable
    if ($replaced.operation -cne 'Replaced' -or $replaced.body -cne $expectedReplaced) { throw 'Replacing the scenario table changed other text or lost its heading.' }
    if ((Get-FixtureCodes (Test-PrPublishBody $replaced.body -Template $template -PreviousBody $good -RepositoryPath $script:repo)) -cne '') { throw 'A table-only update had findings.' }
    $summary = "This pull request makes rounding go up at .5 for [issue 12](https://example.ghe.com/team/tool/issues/12).`n`nThe most important changes include:`n`n**Rounding:**`n`n* ``widget.txt`` rounds halves up $([char]0x2014) as agreed."
    $added = Set-PrPublishScenarioTable $summary "### Current vs. to-be`n`n$newTable"
    if ($added.operation -cne 'Added' -or -not $added.body.StartsWith($summary) -or ([regex]::Matches($added.body, 'Current vs\. to-be')).Count -ne 1 -or $added.body -notmatch '(?s)as agreed\.\n\n### Current vs\. to-be\n\n\| #') { throw 'A table was not appended after a summary without sections.' }
    if ((Get-FixtureCodes (Test-PrPublishBody $added.body -PreviousBody $summary)) -cne '') { throw 'Kept text was checked for style.' }
    if ((Get-FixtureCodes (Test-PrPublishBody $added.body.Replace('as agreed.', "as agreed.`n* A new line $([char]0x2014) added.") -PreviousBody $summary)) -cne 'Dash') { throw 'A dash in new text was not reported.' }
    $sectioned = "## Description`n`nRounds halves up.`n`n## Checklist`n`n- [x] Tests pass.`n"
    if ((Set-PrPublishScenarioTable $sectioned $newTable).body -notmatch '(?s)Rounds halves up\.\n\n### Current vs\. to-be\n\n\| # .*?\n\n## Checklist') { throw 'A table was not added at the end of the first section.' }
    $crlf = (Set-PrPublishScenarioTable ($summary -replace "`n", "`r`n") $newTable).body
    if (-not $crlf.Contains("`r`n") -or $crlf -match "(?<!`r)`n") { throw 'The line endings of the kept description were not preserved.' }
    Assert-PublishFailure { Set-PrPublishScenarioTable $summary '### Current vs. to-be' } 'no scenario table'
    if ((Get-FixtureCodes (Test-PrPublishBody $good.Replace('## Test Validation Proof', '## Validation').Replace('Widget_RoundsUp_WhenHalf', 'Widget_Never_Written') -RepositoryPath $script:repo)) -cne 'UnknownTest') { throw 'A missing test under Validation was not reported.' }
    $summaryFile = Join-Path $fixtureRoot 'summary.md'
    $tableFile = Join-Path $fixtureRoot 'table.md'
    [IO.File]::WriteAllText($summaryFile, $summary)
    [IO.File]::WriteAllText($tableFile, $newTable)
    $dispatcher = Join-Path $PSScriptRoot '../skills/github/pr-publish/scripts/pr-publish.ps1'
    foreach ($command in @((Get-Command Publish-PrPublishPullRequest), (Get-Command $dispatcher))) {
        foreach ($name in 'Draft', 'Ready') { if ($command.Parameters.ContainsKey($name)) { throw "$($command.Name) still has -$name." } }
    }
    if ((@((Get-Command $dispatcher).Parameters['Action'].Attributes.ValidValues) -join ',') -cne 'Status,Check,Commit,Rebase,Push,Publish') { throw 'The helper has actions beyond Status, Check, Commit, Rebase, Push, and Publish.' }
    $newPreview = Publish-PrPublishPullRequest $script:repo -Title 'Round halves up' -BodyFile $summaryFile -TableFile $tableFile
    if (-not $newPreview.preview -or $newPreview.operation -cne 'Create' -or $newPreview.draft -or ([IO.File]::ReadAllText($newPreview.bodyFile)) -cne $added.body -or 'Dash' -cnotin @($newPreview.findings.code) -or $script:gh.Calls.Where({ $_ -ccontains '-X' }).Count) { throw 'Publishing a new PR did not preview the summary with its table and checks, or it wrote to the remote.' }

    $bodyFile = Join-Path $fixtureRoot 'body.md'
    [IO.File]::WriteAllText($bodyFile, $good)
    [IO.File]::WriteAllText((Join-Path $script:repo 'widget.txt'), 'rounded twice')
    Invoke-FixtureGit @('add', '--all')
    Invoke-FixtureGit ($commit + @('unpushed'))
    Assert-PublishFailure { Publish-PrPublishPullRequest $script:repo -Title 'Round halves up' -BodyFile $bodyFile -Apply } 'Push the branch'
    $unpushedPreview = Publish-PrPublishPullRequest $script:repo -Title 'Round halves up' -BodyFile $bodyFile
    if (-not $unpushedPreview.preview -or $unpushedPreview.pushed -or $script:gh.Calls.Where({ $_ -ccontains '-X' }).Count) { throw 'A preview before the push failed, wrote, or claimed the branch was pushed.' }
    Invoke-FixtureGit @('update-ref', 'refs/remotes/origin/users/me/fix', 'HEAD')

    $preview = Publish-PrPublishPullRequest $script:repo -Title 'Round halves up' -BodyFile $bodyFile
    if (-not $preview.preview -or $preview.operation -cne 'Create' -or $preview.draft -or ([IO.File]::ReadAllText($preview.bodyFile)) -cne $good -or $preview.findings.Count -or $script:gh.Calls.Where({ $_ -ccontains '-X' }).Count) { throw 'Preview wrote to the remote, planned the wrong operation, or lost the description or its checks.' }
    $created = Publish-PrPublishPullRequest $script:repo -Title 'Round halves up' -BodyFile $bodyFile -Apply
    $post = $script:gh.Calls.Where({ $_ -ccontains 'POST' })
    if ($created.number -ne 7 -or $created.draft -or $created.url -notlike '*/pull/7' -or $post.Count -ne 1 -or $post[0] -cnotcontains 'draft=false' -or $post[0] -cnotcontains 'head=users/me/fix' -or $post[0] -cnotcontains 'base=develop') { throw 'Create did not open one ready PR for the branch against its base.' }
    if ((Get-FixtureCodes (Invoke-PrPublishCheck $script:repo).findings) -cne '') { throw 'Checking the live description reported findings.' }
    $rewrite = Join-Path $fixtureRoot 'rewrite.md'
    [IO.File]::WriteAllText($rewrite, $good.Replace('https://example.ghe.com/team/tool/issues/12', 'issue-12'))
    if ((Get-FixtureCodes (Invoke-PrPublishCheck $script:repo -BodyFile $rewrite).findings) -cne 'LinkRemoved') { throw 'A rewrite was not compared with the live description.' }
    $tablePreview = Publish-PrPublishPullRequest $script:repo -TableFile $tableFile
    if (-not $tablePreview.preview -or $tablePreview.operation -cne 'Update' -or -not $tablePreview.body -or $tablePreview.title -or ([IO.File]::ReadAllText($tablePreview.bodyFile)) -cne $expectedReplaced -or $tablePreview.findings.Count -or $script:gh.Calls.Where({ $_ -ccontains 'PATCH' }).Count) { throw 'A table update preview did not keep the live description, or it wrote to the PR.' }
    $tableApplied = Publish-PrPublishPullRequest $script:repo -TableFile $tableFile -Apply
    $patches = $script:gh.Calls.Where({ $_ -ccontains 'PATCH' })
    if ($script:gh.Pull.body -cne $expectedReplaced -or -not $tableApplied.backup -or $patches.Count -ne 1 -or $patches[0] -ccontains 'title=Round halves up') { throw 'A table update did not replace only the table, with a backup.' }
    $null = Publish-PrPublishPullRequest $script:repo -TableFile $tableFile -Apply
    if ($script:gh.Calls.Where({ $_ -ccontains 'PATCH' }).Count -ne 1) { throw 'An unchanged table was written again.' }

    $updated = $good.Replace('Rounding now goes up at .5.', 'Halves now round up.')
    [IO.File]::WriteAllText($bodyFile, $updated)
    $result = Publish-PrPublishPullRequest $script:repo -Title 'Round halves up' -BodyFile $bodyFile -Apply
    if ($script:gh.Pull.body -cne $updated -or -not $result.backup -or ([IO.File]::ReadAllText($result.backup)) -notlike '*Rounding now goes up at .5.*') { throw 'Update did not back up and replace the description.' }
    $lastPatch = $script:gh.Calls.Where({ $_ -ccontains 'PATCH' })[-1]
    if ($lastPatch -ccontains 'title=Round halves up') { throw 'An unchanged title was sent again.' }
    $script:gh.CorruptReadBack = $true
    Assert-PublishFailure { Publish-PrPublishPullRequest $script:repo -BodyFile $bodyFile -Apply } 'Read-back description differs'
    $script:gh.CorruptReadBack = $false

    # A draft made outside pr-publish, for example on the PR page, stays a draft.
    $script:gh.Pull.draft = $true
    $kept = Publish-PrPublishPullRequest $script:repo -TableFile $tableFile -Apply
    if (-not $kept.draft -or $script:gh.Calls.Where({ $_[1] -ceq 'graphql' }).Count) { throw 'Publishing changed the draft state.' }

    Invoke-FixtureGit @('switch', '--quiet', 'develop')
    Assert-PublishFailure { Publish-PrPublishPullRequest $script:repo -Title 'Wrong' -BodyFile $bodyFile -Apply } 'base branch'

    # Commits and pushes use a second repository whose origin pushes to a local bare remote.
    $remote = Join-Path $fixtureRoot 'remote.git'
    $null = & git init --quiet --bare -b develop $remote
    $script:repo = Join-Path $fixtureRoot 'commit-repo'
    New-Item -ItemType Directory -Path (Join-Path $script:repo 'src'), (Join-Path $script:repo 'docs') -Force | Out-Null
    Invoke-FixtureGit @('init', '--quiet', '-b', 'develop')
    foreach ($setting in @(@('user.name', 'Fixture'), @('user.email', 'fixture@example.invalid'), @('commit.gpgSign', 'false'))) { Invoke-FixtureGit (@('config') + $setting) }
    foreach ($file in 'src/widget.txt', 'old.txt', 'a.txt') { [IO.File]::WriteAllText((Join-Path $script:repo $file), "$file`n") }
    Invoke-FixtureGit @('add', '--all')
    Invoke-FixtureGit @('commit', '--quiet', '-m', 'base')
    Invoke-FixtureGit @('remote', 'add', 'origin', 'https://example.ghe.com/team/tool.git')
    Invoke-FixtureGit @('config', 'remote.origin.pushurl', $remote)
    Invoke-FixtureGit @('push', '--quiet', 'origin', 'develop')
    Invoke-FixtureGit @('symbolic-ref', 'refs/remotes/origin/HEAD', 'refs/remotes/origin/develop')
    $baseHead = (& git -C $script:repo rev-parse HEAD)
    [IO.File]::WriteAllText((Join-Path $script:repo 'src/widget.txt'), "rounded`n")
    [IO.File]::WriteAllText((Join-Path $script:repo 'src/widget.tests.txt'), "test`n")
    [IO.File]::WriteAllText((Join-Path $script:repo 'docs/rounding.md'), "# Rounding`n")
    [IO.File]::WriteAllText((Join-Path $script:repo 'scratch.log'), "debug`n")
    Invoke-FixtureGit @('rm', '--quiet', 'old.txt')
    Invoke-FixtureGit @('mv', 'a.txt', 'b.txt')
    Invoke-FixtureGit @('add', 'docs/rounding.md')
    $planFile = Join-Path $fixtureRoot 'plan.json'
    function Write-FixturePlan { param($Plan) $Plan | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $planFile -Encoding utf8 }
    function Copy-FixturePlan { param($Plan) $Plan | ConvertTo-Json -Depth 5 | ConvertFrom-Json }
    $goodPlan = [pscustomobject]@{ branch = 'users/me/rounding'; exclude = @('scratch.log'); commits = @(
        [pscustomobject]@{ message = "Round halves up`n`n- Widget rounds half up.`n- Remove the old helper."; files = @('src/widget.txt', 'src/widget.tests.txt', 'old.txt') }
        [pscustomobject]@{ message = "Document rounding`n`n# Kept: a line that starts with a hash"; files = @('docs/rounding.md', 'b.txt') }) }
    $variant = Copy-FixturePlan $goodPlan; $variant.exclude = @()
    Write-FixturePlan $variant
    Assert-PublishFailure { Invoke-PrPublishCommit $script:repo -PlanFile $planFile } 'Every change must be committed or excluded'
    $variant = Copy-FixturePlan $goodPlan; $variant.commits[1].files += 'missing.txt'
    Write-FixturePlan $variant
    Assert-PublishFailure { Invoke-PrPublishCommit $script:repo -PlanFile $planFile } 'not an uncommitted change'
    $variant = Copy-FixturePlan $goodPlan; $variant.commits[0].files += 'b.txt'
    Write-FixturePlan $variant
    Assert-PublishFailure { Invoke-PrPublishCommit $script:repo -PlanFile $planFile } 'more than one commit'
    $variant = Copy-FixturePlan $goodPlan; $variant.branch = ''
    Write-FixturePlan $variant
    Assert-PublishFailure { Invoke-PrPublishCommit $script:repo -PlanFile $planFile } 'base branch'
    $variant = Copy-FixturePlan $goodPlan; $variant.branch = 'develop'
    Write-FixturePlan $variant
    Assert-PublishFailure { Invoke-PrPublishCommit $script:repo -PlanFile $planFile } 'already exists'
    Write-FixturePlan $goodPlan
    $commitPreview = Invoke-PrPublishCommit $script:repo -PlanFile $planFile
    if (-not $commitPreview.preview -or $commitPreview.branch -cne 'users/me/rounding' -or -not $commitPreview.newBranch -or $commitPreview.commits.Count -ne 2 -or
        $commitPreview.commits[0].subject -cne 'Round halves up' -or ($commitPreview.excluded -join ',') -cne 'scratch.log') { throw 'The commit preview misread the plan.' }
    if ((& git -C $script:repo rev-parse HEAD) -cne $baseHead -or (& git -C $script:repo branch --show-current) -cne 'develop') { throw 'The commit preview changed the repository.' }
    $committed = Invoke-PrPublishCommit $script:repo -PlanFile $planFile -Apply
    if ($committed.preview -or (& git -C $script:repo branch --show-current) -cne 'users/me/rounding' -or (& git -C $script:repo rev-parse develop) -cne $baseHead) { throw 'Committing did not move the work to the new branch, or it changed the base branch.' }
    $first = @(& git -C $script:repo show --no-renames --name-only --format= $committed.commits[0].sha | Sort-Object) -join ','
    $second = @(& git -C $script:repo show --no-renames --name-only --format= $committed.commits[1].sha | Sort-Object) -join ','
    if ($first -cne 'old.txt,src/widget.tests.txt,src/widget.txt' -or $second -cne 'a.txt,b.txt,docs/rounding.md') { throw "Commits did not hold exactly their planned files: [$first] [$second]." }
    if (((& git -C $script:repo log -1 --format=%B) -join "`n") -notmatch '# Kept: a line that starts with a hash') { throw 'A message line that starts with # was stripped.' }
    if (((& git -C $script:repo status --porcelain) -join ',') -cne '?? scratch.log') { throw 'The excluded file was committed, or a planned change was left behind.' }
    $pushPreview = Push-PrPublishBranch $script:repo
    $null = & git --git-dir $remote rev-parse --verify --quiet refs/heads/users/me/rounding
    if (-not $pushPreview.preview -or -not $pushPreview.setUpstream -or $pushPreview.pushed -or $LASTEXITCODE -eq 0) { throw 'The push preview pushed or misread the upstream.' }
    $pushed = Push-PrPublishBranch $script:repo -Apply
    $localHead = & git -C $script:repo rev-parse HEAD
    if (-not $pushed.pushed -or $pushed.upstream -cne 'origin/users/me/rounding' -or (& git --git-dir $remote rev-parse refs/heads/users/me/rounding) -cne $localHead) { throw 'The push did not set the upstream or reach the remote.' }
    $again = Push-PrPublishBranch $script:repo -Apply
    if (-not $again.pushed -or $again.ahead -ne 0) { throw 'An up-to-date branch was pushed again.' }
    Invoke-FixtureGit @('commit', '--quiet', '--allow-empty', '-m', 'pushed later')
    $null = Push-PrPublishBranch $script:repo -Apply
    $remoteHead = & git --git-dir $remote rev-parse refs/heads/users/me/rounding
    Invoke-FixtureGit @('reset', '--quiet', '--hard', 'HEAD~1')
    Invoke-FixtureGit @('commit', '--quiet', '--allow-empty', '-m', 'diverged')
    Assert-PublishFailure { Push-PrPublishBranch $script:repo -Apply } "commits this branch doesn't have"
    if ((& git --git-dir $remote rev-parse refs/heads/users/me/rounding) -cne $remoteHead) { throw 'A diverged branch was pushed.' }
    Invoke-FixtureGit @('switch', '--quiet', 'develop')
    Assert-PublishFailure { Push-PrPublishBranch $script:repo -Apply } 'base branch'
    Invoke-FixtureGit @('switch', '--quiet', 'users/me/rounding')
    # A hook that rejects the second commit leaves the first one, reports it, and pushes nothing.
    [IO.File]::WriteAllText((Join-Path $script:repo '.git/hooks/commit-msg'), "#!/bin/sh`ngrep -q REJECT `"`$1`" && exit 1`nexit 0`n")
    [IO.File]::WriteAllText((Join-Path $script:repo 'src/widget.txt'), "rounded twice`n")
    [IO.File]::WriteAllText((Join-Path $script:repo 'docs/rounding.md'), "# Rounding again`n")
    Write-FixturePlan ([pscustomobject]@{ exclude = @('scratch.log'); commits = @(
        [pscustomobject]@{ message = 'Round twice'; files = @('src/widget.txt') }
        [pscustomobject]@{ message = 'REJECT this one'; files = @('docs/rounding.md') }) })
    $hookFailure = $null
    try { $null = Invoke-PrPublishCommit $script:repo -PlanFile $planFile -Apply } catch { $hookFailure = $_.Exception.Message }
    if ($hookFailure -notmatch "Committing 'REJECT this one' failed" -or $hookFailure -notmatch 'Commits made: [0-9a-f]{7} Round twice' -or $hookFailure -notmatch 'Nothing was pushed') { throw "A rejected commit was not reported with the commits already made: $hookFailure" }

    # Fetch, rebase, and force push use a third repository; a second clone moves the remote base ahead.
    $rebaseRemote = Join-Path $fixtureRoot 'rebase-remote.git'
    $null = & git init --quiet --bare -b develop $rebaseRemote
    $script:repo = Join-Path $fixtureRoot 'rebase-repo'
    New-Item -ItemType Directory -Path $script:repo | Out-Null
    Invoke-FixtureGit @('init', '--quiet', '-b', 'develop')
    foreach ($setting in @(@('user.name', 'Fixture'), @('user.email', 'fixture@example.invalid'), @('commit.gpgSign', 'false'))) { Invoke-FixtureGit (@('config') + $setting) }
    foreach ($file in 'widget.txt', 'notes.txt') { [IO.File]::WriteAllText((Join-Path $script:repo $file), "$file`n") }
    Invoke-FixtureGit @('add', '--all')
    Invoke-FixtureGit @('commit', '--quiet', '-m', 'base')
    Invoke-FixtureGit @('remote', 'add', 'origin', $rebaseRemote)
    Invoke-FixtureGit @('push', '--quiet', 'origin', 'develop')
    Invoke-FixtureGit @('symbolic-ref', 'refs/remotes/origin/HEAD', 'refs/remotes/origin/develop')
    Invoke-FixtureGit @('switch', '--quiet', '-c', 'users/me/feature')
    [IO.File]::WriteAllText((Join-Path $script:repo 'widget.txt'), "two`n")
    Invoke-FixtureGit @('commit', '--quiet', '-am', 'Change widget')
    Invoke-FixtureGit @('push', '--quiet', '--set-upstream', 'origin', 'users/me/feature')
    $other = Join-Path $fixtureRoot 'rebase-other'
    $null = & git clone --quiet $rebaseRemote $other 2>&1
    function Move-FixtureBase {
        param([string]$File, [string]$Text)
        [IO.File]::WriteAllText((Join-Path $other $File), $Text)
        $null = & git -C $other -c user.name=Other -c user.email=other@example.invalid -c commit.gpgSign=false commit --quiet -am "Move base: $File" 2>&1
        $null = & git -C $other push --quiet origin develop 2>&1
        if ($LASTEXITCODE -ne 0) { throw 'The fixture could not move the remote base.' }
    }
    Move-FixtureBase 'notes.txt' "moved`n"
    if ((Invoke-PrPublishRebase $script:repo).behind -ne 0) { throw 'The fixture saw the moved base before fetching.' }
    $fetch = Invoke-PrPublishFetch $script:repo 'develop' 'users/me/feature'
    if (-not $fetch.fetched -or $fetch.error) { throw "Fetching the base and branch failed: $($fetch.error)" }
    $beforeRebase = & git -C $script:repo rev-parse HEAD
    $rebasePreview = Invoke-PrPublishRebase $script:repo
    $pushedHead = & git -C $script:repo rev-parse 'origin/users/me/feature'
    if (-not $rebasePreview.preview -or $rebasePreview.behind -ne 1 -or $rebasePreview.rebased -or -not $rebasePreview.forcePush -or $rebasePreview.expectedRemoteHead -cne $pushedHead) { throw 'The rebase preview misread how far behind the branch is or which force push it needs.' }
    if ((& git -C $script:repo rev-parse HEAD) -cne $beforeRebase) { throw 'The rebase preview changed the branch.' }
    [IO.File]::WriteAllText((Join-Path $script:repo 'scratch.log'), "debug`n")
    $rebased = Invoke-PrPublishRebase $script:repo -Apply
    $null = & git -C $script:repo merge-base --is-ancestor origin/develop HEAD
    if (-not $rebased.rebased -or $rebased.head -ceq $beforeRebase -or $LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $script:repo 'scratch.log'))) { throw 'The rebase did not move the branch onto the base, or it lost an untracked file.' }
    Assert-PublishFailure { Push-PrPublishBranch $script:repo -Apply } "commits this branch doesn't have"
    Assert-PublishFailure { Push-PrPublishBranch $script:repo -Apply -ExpectedRemoteHead ('0' * 40) } 'not at the approved commit'
    if ((& git --git-dir $rebaseRemote rev-parse refs/heads/users/me/feature) -cne $pushedHead) { throw 'A rebased branch was pushed without the approved commit.' }
    $forced = Push-PrPublishBranch $script:repo -Apply -ExpectedRemoteHead $rebasePreview.expectedRemoteHead
    if (-not $forced.pushed -or -not $forced.force -or (& git --git-dir $rebaseRemote rev-parse refs/heads/users/me/feature) -cne $rebased.head) { throw 'The approved force push did not replace exactly the approved remote commit.' }
    Move-FixtureBase 'widget.txt' "three`n"
    $null = Invoke-PrPublishFetch $script:repo 'develop' 'users/me/feature'
    $beforeConflict = & git -C $script:repo rev-parse HEAD
    Assert-PublishFailure { Invoke-PrPublishRebase $script:repo -Apply } 'so it was undone'
    $inProgress = @('rebase-merge', 'rebase-apply' | Where-Object { Test-Path -LiteralPath (Join-Path $script:repo ".git/$_") })
    if ((& git -C $script:repo rev-parse HEAD) -cne $beforeConflict -or $inProgress.Count -or (& git -C $script:repo branch --show-current) -cne 'users/me/feature') { throw 'A conflicting rebase changed the branch or was left in progress.' }
    Invoke-FixtureGit @('remote', 'set-url', 'origin', (Join-Path $fixtureRoot 'missing.git'))
    $failedFetch = Invoke-PrPublishFetch $script:repo 'develop' 'users/me/feature'
    if ($failedFetch.fetched -or -not $failedFetch.error) { throw 'A failed fetch was not reported.' }
    Write-Output 'PR publish checks passed: remote parsing, branch status, description findings, table-only updates that keep the rest of the description, preview with checks and no writes, preview before the push, create as ready, backed-up update, read-back, unchanged draft state, no extra actions or options, and guards. All GitHub calls were fake.'
    Write-Output 'Commit and push checks passed: plans that cover every change exactly once, preview without changes, grouped commits on a new branch with deletes, renames, and exclusions, kept message lines, upstream setup, no repeat push, refused diverged and base-branch pushes, and a rejected commit reported with the commits already made.'
    Write-Output 'Fetch and rebase checks passed: fetch on request, failed fetches reported, behind counts after a fetch, rebase previews naming the force push, rebase onto the moved base keeping untracked files, force push only over the approved remote commit, and conflicts undone.'
}
finally {
    if ($savedTemp) { $env:TMP = $savedTemp[0]; $env:TEMP = $savedTemp[1] }
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
