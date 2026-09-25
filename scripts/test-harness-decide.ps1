$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '..\skills\planning\harness-decision\scripts\harness-decide.ps1'
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('harness-decide-' + [guid]::NewGuid().ToString('N'))

function New-TestDecision {
    param([string]$Id, [string]$Status, [string]$RecordedAt = '')
    [pscustomobject][ordered]@{
        id = $Id
        status = $Status
        question = "Question for $Id"
        choice = 'Original choice'
        recommendation = 'Existing recommendation'
        rationale = 'Original reason'
        owner = 'Fixture owner'
        recordedAt = $RecordedAt
        reference = 'plans/design.md#decision'
        task = 'T-001'
        supersedes = ''
    }
}

function Assert-DecisionFailure {
    param([scriptblock]$Operation, [string]$Expected)
    $failed = $false
    try { & $Operation | Out-Null }
    catch {
        $failed = $true
        if ($_.Exception.Message -notlike "*$Expected*") { throw }
    }
    if (-not $failed) { throw "Expected failure: $Expected" }
}

try {
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    $defaultEmpty = & $scriptPath -ProjectPath $fixtureRoot | ConvertFrom-Json
    if ($defaultEmpty.Exists -or $defaultEmpty.Register -ine (Join-Path $fixtureRoot '.harness_sv/decisions.csv')) { throw 'The default register must be under .harness_sv.' }
    if (@(Get-ChildItem -LiteralPath $fixtureRoot -Force).Count) { throw 'Default decision inspection created files.' }
    $initial = & $scriptPath -ProjectPath $fixtureRoot -Action Record -Question 'Initial decision' -Choice 'Keep it local' -Owner 'Fixture owner' | ConvertFrom-Json
    if ($initial.id -cne 'D-001' -or -not (Test-Path -LiteralPath (Join-Path $fixtureRoot '.harness_sv/decisions.csv'))) { throw 'Standalone recording did not create its register under .harness_sv.' }
    if (@(Get-ChildItem -LiteralPath $fixtureRoot -Force | Where-Object Name -NE '.harness_sv').Count) { throw 'Standalone decision recording wrote outside .harness_sv.' }
    $empty = & $scriptPath -ProjectPath $fixtureRoot -BoardPath 'board' | ConvertFrom-Json
    if ($empty.Exists -or @($empty.Open).Count -ne 0 -or @($empty.Recent).Count -ne 0) { throw 'Missing register did not return an empty bulletin.' }
    if (Test-Path -LiteralPath (Join-Path $fixtureRoot 'board')) { throw 'Read-only display created the board.' }

    $registerPath = Join-Path $fixtureRoot '.harness_sv/decisions.csv'
    $rows = @(
        New-TestDecision -Id 'D-001' -Status 'Open'
        New-TestDecision -Id 'D-002' -Status 'Proposed'
        foreach ($number in 1..6) {
            New-TestDecision -Id ('D-{0:D3}' -f (100 + $number)) -Status 'Accepted' -RecordedAt ('2026-09-{0:D2}T12:00:00+00:00' -f $number)
        }
    )
    $rows | Export-Csv -LiteralPath $registerPath -NoTypeInformation -Encoding UTF8
    $before = [System.IO.File]::ReadAllText($registerPath)
    $bulletin = & $scriptPath -ProjectPath $fixtureRoot | ConvertFrom-Json
    $propertyNames = @($bulletin.PSObject.Properties.Name)
    if ($propertyNames[0] -cne 'Open' -or $propertyNames[1] -cne 'Recent') { throw 'Bulletin must put Open before Recent.' }
    if (@($bulletin.Open).Count -ne 2 -or @($bulletin.Recent).Count -ne 0 -or $bulletin.Filter -ne 'Open') { throw 'Default display must contain unresolved decisions only.' }
    $all = & $scriptPath -ProjectPath $fixtureRoot -Filter All | ConvertFrom-Json
    if (@($all.Open).Count -ne 2 -or @($all.Recent).Count -ne 5 -or $all.Recent[0].id -cne 'D-106') { throw 'Explicit all-status display lost open questions or recent ordering.' }
    $closed = & $scriptPath -ProjectPath $fixtureRoot -Filter Closed -RecentCount 6 | ConvertFrom-Json
    if (@($closed.Open).Count -ne 0 -or @($closed.Recent).Count -ne 6 -or $closed.Recent[0].id -cne 'D-106') { throw 'Closed filtering or explicit result count failed.' }
    $closedId = & $scriptPath -ProjectPath $fixtureRoot -Id D-106 | ConvertFrom-Json
    if (@($closedId.Recent).Count -ne 1 -or $closedId.Recent[0].id -cne 'D-106') { throw 'An exact decision ID was hidden by the default open filter.' }
    $single = & $scriptPath -ProjectPath $fixtureRoot -Id D-002 | ConvertFrom-Json
    if (@($single.Open).Count -ne 1 -or @($single.Recent).Count -ne 0 -or $single.Open[0].status -ne 'Proposed') { throw 'ID-only lookup must not accept a proposal.' }
    Assert-DecisionFailure { & $scriptPath -ProjectPath $fixtureRoot -Choice 'Not authorized by Show' } 'Show is read-only'
    Assert-DecisionFailure { & $scriptPath -ProjectPath $fixtureRoot -Id 'missing' } 'Decision ID not found'
    Assert-DecisionFailure { & $scriptPath -ProjectPath $fixtureRoot -Action Record -Id D-001 -Choice 'A choice' } 'human Owner'
    Assert-DecisionFailure { & $scriptPath -ProjectPath $fixtureRoot -Action Record -Filter Closed -Question 'Must not record' -Choice 'No' -Owner 'Fixture owner' } 'Filter applies only to Show'
    if ([System.IO.File]::ReadAllText($registerPath) -cne $before) { throw 'Display or rejected recording changed the register.' }

    $choice = "Keep commas, quotes `"here`", and`na second line"
    $resolved = & $scriptPath -ProjectPath $fixtureRoot -Action Record -Id D-001 -Choice $choice -Owner 'Fixture owner' -Rationale 'Verified reason' | ConvertFrom-Json
    if ($resolved.id -cne 'D-001' -or $resolved.status -cne 'Accepted') { throw 'Open decision did not resolve in place.' }
    $persisted = @(Import-Csv -LiteralPath $registerPath -Encoding UTF8)
    $resolvedRow = $persisted | Where-Object { $_.id -eq 'D-001' }
    if ($resolvedRow.choice -cne $choice -or $resolvedRow.recommendation -cne 'Existing recommendation' -or $resolvedRow.reference -cne 'plans/design.md#decision') { throw 'CSV round-trip or preserved context failed.' }
    if (($persisted | Where-Object { $_.id -eq 'D-002' }).status -cne 'Proposed') { throw 'Recording resolved an unrelated question.' }

    $replacement = & $scriptPath -ProjectPath $fixtureRoot -Action Record -Id D-001 -Choice 'Replacement choice' -Owner 'Fixture owner' | ConvertFrom-Json
    $persisted = @(Import-Csv -LiteralPath $registerPath -Encoding UTF8)
    $original = $persisted | Where-Object { $_.id -eq 'D-001' }
    if ($replacement.id -cne 'D-107' -or $replacement.supersedes -cne 'D-001' -or $original.status -cne 'Superseded' -or $original.choice -cne $choice -or $original.rationale -cne 'Verified reason') { throw 'Supersession did not retain accepted history.' }
    $before = [System.IO.File]::ReadAllText($registerPath)
    & $scriptPath -ProjectPath $fixtureRoot -Action Record -Id D-107 -Choice 'Replacement choice' -Owner 'Fixture owner' | Out-Null
    if ([System.IO.File]::ReadAllText($registerPath) -cne $before) { throw 'Repeated identical choice should be a no-op.' }

    $new = & $scriptPath -ProjectPath $fixtureRoot -BoardPath 'board' -Action Record -Question 'New question' -Choice 'Explicit choice' -Owner 'Fixture owner' | ConvertFrom-Json
    if ($new.id -cne 'D-001' -or -not (Test-Path -LiteralPath (Join-Path $fixtureRoot 'board/decisions.csv'))) { throw 'New decision did not use the project-relative board.' }
    if ([System.IO.File]::ReadAllText($registerPath) -cne $before) { throw 'Configured board write changed the default register.' }
    if (@(Get-ChildItem -LiteralPath $fixtureRoot -Filter '.decisions-*.tmp' -Recurse).Count -gt 0) { throw 'Temporary write artifacts were not cleaned up.' }

    $control = Join-Path $fixtureRoot '.harness_sv'
    New-Item -ItemType Directory -Path $control -Force | Out-Null
    @{ schemaVersion = 1; projectRoot = $fixtureRoot; boardPath = 'board' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $control 'config.json') -Encoding UTF8
    $configured = & $scriptPath -ProjectPath $fixtureRoot -Filter All | ConvertFrom-Json
    if ($configured.Recent[0].choice -cne 'Explicit choice') { throw 'Decision bulletin ignored the configured harness board.' }
    $override = & $scriptPath -ProjectPath $fixtureRoot -BoardPath '.' | ConvertFrom-Json
    if ($override.Register -ceq $configured.Register) { throw 'Explicit decision board path did not override harness config.' }

    $externalRegisterPath = Join-Path $fixtureRoot 'decisions.csv'
    'id,status,other', 'legacy,Open,keep-this' | Set-Content -LiteralPath $externalRegisterPath -Encoding UTF8
    $before = [System.IO.File]::ReadAllText($externalRegisterPath)
    Assert-DecisionFailure { & $scriptPath -ProjectPath $fixtureRoot -BoardPath '.' -Action Record -Question 'Question' -Choice 'Choice' -Owner 'Owner' } 'Unsupported decision CSV schema'
    if ([System.IO.File]::ReadAllText($externalRegisterPath) -cne $before) { throw 'Unsupported project schema was overwritten.' }
    Write-Output 'Decision checks passed: open-only default, closed/all/ID filters, recent limits, read-only display, explicit recording, CSV quoting, supersession, and board isolation.'
}
finally {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}