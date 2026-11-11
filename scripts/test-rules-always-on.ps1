$ErrorActionPreference = 'Stop'

# Temporary files only; the real ~/.copilot/copilot-instructions.md is never touched.
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('rules-always-on-test-' + [guid]::NewGuid().ToString('N'))
$script = Join-Path $PSScriptRoot '..\skills\core\rules\scripts\always-on.ps1'
$realCore = Join-Path $PSScriptRoot '..\skills\core\rules\references\core.md'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Invoke-AlwaysOn {
    param([string]$Path, [string]$CorePath, [switch]$Apply)
    (& $script -Path $Path -CorePath $CorePath -Apply:$Apply) | ConvertFrom-Json
}

try {
    $references = Join-Path $fixtureRoot 'skill\references'
    New-Item -ItemType Directory -Path $references -Force | Out-Null
    $core = Join-Path $references 'core.md'
    Copy-Item -LiteralPath $realCore -Destination $core
    Set-Content -LiteralPath (Join-Path $references 'ai-principles.md') -Value '# Detail'
    $target = Join-Path $fixtureRoot 'home\.copilot\copilot-instructions.md'

    $result = Invoke-AlwaysOn $target $core
    Assert-True ($result.status -eq 'Missing' -and -not $result.applied -and -not (Test-Path $target)) 'a check never creates the file'
    $result = Invoke-AlwaysOn $target $core -Apply
    $text = [IO.File]::ReadAllText($target)
    Assert-True ($result.status -eq 'Missing' -and $result.applied) 'apply creates a missing file'
    foreach ($expected in @('<!-- rules:core:begin -->', '<!-- rules:core:end -->', '**Start from the real need.**', '**Use current evidence.**', '**Deliver simply and stay in scope.**', '**Do not overdefend.**', '**Verify proportionately.**', '# Personal rules')) {
        Assert-True $text.Contains($expected) "the generated file contains $expected"
    }
    Assert-True (-not $text.Contains('For `/rules apply`')) 'the generated block copies the rules, not the skill introduction'
    Assert-True ((Invoke-AlwaysOn $target $core).status -eq 'InSync') 'a fresh copy is in sync'

    [IO.File]::AppendAllText($target, "- Prefer short status updates.`n")
    $changed = [IO.File]::ReadAllText($core).Replace('Verify proportionately.', 'Verify proportionately, always.')
    [IO.File]::WriteAllText($core, $changed)
    Assert-True ((Invoke-AlwaysOn $target $core).status -eq 'Drifted') 'a core change is reported as drift'
    $result = Invoke-AlwaysOn $target $core -Apply
    $text = [IO.File]::ReadAllText($target)
    Assert-True ($result.applied -and $text.Contains('Verify proportionately, always.') -and $text.Contains('- Prefer short status updates.')) 'regeneration updates the core block and keeps personal rules'
    Assert-True ((Invoke-AlwaysOn $target $core).status -eq 'InSync') 'the regenerated copy is in sync'
    Assert-True (-not $text.Contains('# Extra rules')) 'no extra rules file means no extra rules section'

    $extra = Join-Path $references 'extra.md'
    $extraText = "# Extra Rules`n`nIntro that stays in the skill.`n`n- **Fixture rule one.** Keep replies short.`n- **Fixture rule two.** Wrap long`n  explanations.`n"
    [IO.File]::WriteAllText($extra, $extraText)
    Assert-True ((Invoke-AlwaysOn $target $core).status -eq 'Drifted') 'a new extra rule is reported as drift'
    $null = Invoke-AlwaysOn $target $core -Apply
    $text = [IO.File]::ReadAllText($target)
    $block = $text.Substring(0, $text.IndexOf('<!-- rules:core:end -->'))
    Assert-True ($block.Contains('# Extra rules') -and $block.Contains('- **Fixture rule one.** Keep replies short.') -and $block.Contains('  explanations.')) 'the extra rules are copied into the generated block'
    Assert-True ($block.IndexOf('**Verify proportionately') -lt $block.IndexOf('# Extra rules') -and -not $text.Contains('Intro that stays in the skill.')) 'extra rules follow the core rules without the file introduction'
    Assert-True ($text.Contains('- Prefer short status updates.') -and (Invoke-AlwaysOn $target $core).status -eq 'InSync') 'adding extra rules keeps personal rules and ends in sync'
    [IO.File]::WriteAllText($extra, "# Extra Rules`n`nNo rules yet.`n")
    $null = Invoke-AlwaysOn $target $core -Apply
    Assert-True (-not [IO.File]::ReadAllText($target).Contains('# Extra rules')) 'removing the last extra rule removes the section'

    [IO.File]::WriteAllText($extra, $extraText)
    $null = Invoke-AlwaysOn $target $core -Apply
    Assert-True ([IO.File]::ReadAllText($target).Contains('(set: all)') -and [IO.File]::ReadAllText($target).Contains('/rules apply global rewrites this block')) 'the block records that it holds all rules and names the command that rewrites it'
    $coreOnly = (& $script -Path $target -CorePath $core -Set core) | ConvertFrom-Json
    Assert-True ($coreOnly.status -eq 'Drifted' -and $coreOnly.set -eq 'core') 'choosing only the core rules is reported as drift'
    $null = & $script -Path $target -CorePath $core -Set core -Apply
    $text = [IO.File]::ReadAllText($target)
    Assert-True (-not $text.Contains('# Extra rules') -and $text.Contains('(set: core)') -and $text.Contains('- Prefer short status updates.') -and $text.Contains('/rules apply core rewrites this block')) 'core only leaves out the extra rules, keeps personal rules, and names its command'
    $kept = Invoke-AlwaysOn $target $core
    Assert-True ($kept.status -eq 'InSync' -and $kept.set -eq 'core') 'a later run without a set keeps the recorded set'
    $null = & $script -Path $target -CorePath $core -Set all -Apply
    Assert-True ([IO.File]::ReadAllText($target).Contains('# Extra rules')) 'applying all rules brings the extra rules back'

    $project = Join-Path $fixtureRoot 'project'
    New-Item -ItemType Directory -Path $project | Out-Null
    $projectFile = Join-Path $project '.github\copilot-instructions.md'
    $projectResult = (& $script -Scope project -ProjectPath $project -CorePath $core -Apply) | ConvertFrom-Json
    $projectText = [IO.File]::ReadAllText($projectFile)
    Assert-True ($projectResult.scope -eq 'project' -and $projectResult.path -eq $projectFile -and $projectText.Contains('# Extra rules') -and $projectText.Contains('# Project rules') -and -not $projectText.Contains('# Personal rules') -and $projectText.Contains('/rules apply project rewrites this block')) 'project scope writes the block and a Project rules section'
    Assert-True (-not $projectText.Contains('For clarification')) 'a project file never links a local path'
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'skill\skill.json') -Value '{"homepage":"https://example.com/vault","source":{"path":"skills/core/rules"}}'
    $null = & $script -Scope project -ProjectPath $project -CorePath $core -Apply
    Assert-True ([IO.File]::ReadAllText($projectFile).Contains('(https://example.com/vault/blob/main/skills/core/rules/references/ai-principles.md)')) 'a project file links the public detailed reference'
    $team = Join-Path $fixtureRoot 'team'
    New-Item -ItemType Directory -Path (Join-Path $team '.github') -Force | Out-Null
    $teamFile = Join-Path $team '.github\copilot-instructions.md'
    [IO.File]::WriteAllText($teamFile, "Use the team style guide.`n")
    $null = & $script -Scope project -ProjectPath $team -CorePath $core -Set core -Apply
    $teamText = [IO.File]::ReadAllText($teamFile)
    Assert-True ($teamText.Contains('Use the team style guide.') -and -not $teamText.Contains('# Project rules') -and -not $teamText.Contains('# Extra rules') -and $teamText.IndexOf('<!-- rules:core:end -->') -lt $teamText.IndexOf('Use the team style guide.') -and $teamText.Contains('/rules apply core project rewrites this block')) 'an existing project file keeps its instructions below the block without a new heading'
    # The extra rules default to a project, where they can sit alone because the global file holds the core rules.
    $extraProject = Join-Path $fixtureRoot 'extra project'
    New-Item -ItemType Directory -Path $extraProject | Out-Null
    $extraFile = Join-Path $extraProject '.github\copilot-instructions.md'
    $extraResult = (& $script -Scope project -ProjectPath $extraProject -CorePath $core -Set extra -Apply) | ConvertFrom-Json
    $extraOnly = [IO.File]::ReadAllText($extraFile)
    Assert-True ($extraResult.set -eq 'extra' -and $extraOnly.Contains('(set: extra)') -and $extraOnly.Contains('- **Fixture rule one.** Keep replies short.') -and $extraOnly.Contains('# Project rules') -and -not $extraOnly.Contains('# Core working rules') -and -not $extraOnly.Contains('**Start from the real need.**') -and -not $extraOnly.Contains('For clarification') -and $extraOnly.Contains('/rules apply extra rewrites this block')) 'the extra set writes only the extra rules into a project'
    $keptExtra = (& $script -Scope project -ProjectPath $extraProject -CorePath $core) | ConvertFrom-Json
    Assert-True ($keptExtra.status -eq 'InSync' -and $keptExtra.set -eq 'extra') 'a later run without a set keeps the extra set'
    $extraGlobal = Join-Path $fixtureRoot 'extra-global.md'
    $null = & $script -Path $extraGlobal -CorePath $core -Set extra -Apply
    Assert-True ([IO.File]::ReadAllText($extraGlobal).Contains('/rules apply extra global rewrites this block')) 'a set written outside its default scope names that scope'

    $unmanaged = Join-Path $fixtureRoot 'unmanaged.md'
    [IO.File]::WriteAllText($unmanaged, "Existing personal preference.`r`n")
    Assert-True ((Invoke-AlwaysOn $unmanaged $core).status -eq 'Unmanaged') 'a file without markers is unmanaged'
    $null = Invoke-AlwaysOn $unmanaged $core -Apply
    $text = [IO.File]::ReadAllText($unmanaged)
    Assert-True ($text.Contains('Existing personal preference.') -and $text.IndexOf('<!-- rules:core:begin -->') -lt $text.IndexOf('Existing personal preference.')) 'adopting a file keeps its content below the generated block'
    Assert-True ($text.Contains("`r`n") -and -not ($text -replace "`r`n", '').Contains("`n")) 'Windows line endings are preserved'

    $malformed = Join-Path $fixtureRoot 'malformed.md'
    $broken = "<!-- rules:core:begin -->`n<!-- rules:core:begin -->`n<!-- rules:core:end -->`n"
    [IO.File]::WriteAllText($malformed, $broken)
    $failed = $false
    try { $null = Invoke-AlwaysOn $malformed $core -Apply } catch { $failed = $true }
    Assert-True ($failed -and [IO.File]::ReadAllText($malformed) -ceq $broken) 'malformed markers stop without changing the file'

    Write-Output 'Rules always-on checks passed: read-only check, creation, sync, drift repair that keeps personal rules, extra rules after the core rules, core-only and extra-only sets that later runs keep, the command each block names, project files with a public link and kept instructions, adoption of an existing file, line endings, and malformed markers.'
}
finally {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}
