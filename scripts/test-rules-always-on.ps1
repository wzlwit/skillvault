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
    foreach ($expected in @('<!-- rules:core:begin -->', '<!-- rules:core:end -->', '**Use current evidence.**', '**Deliver simply and stay in scope.**', '**Do not overdefend.**', '**Verify proportionately.**', '# Personal rules')) {
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

    Write-Output 'Rules always-on checks passed: read-only check, creation, sync, drift repair that keeps personal rules, adoption of an existing file, line endings, and malformed markers.'
}
finally {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}
