$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '..\skills\planning\harness-comms\scripts\rank-slots.ps1'
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('harness-comms-' + [guid]::NewGuid().ToString('N'))

function Get-Index {
    param([int]$Day, [string]$Time)
    $parts = $Time.Split(':')
    return ($Day * 48) + ([int]$parts[0] * 2) + [int]([int]$parts[1] / 30)
}

function New-View {
    param([hashtable]$Codes)
    $chars = ('0' * 240).ToCharArray()
    foreach ($index in $Codes.Keys) { $chars[$index] = [char]$Codes[$index] }
    return -join $chars
}

function New-Person {
    param([string]$Id, [string]$Zone, [string]$From, [string]$To, [hashtable]$Codes = @{})
    [pscustomobject][ordered]@{
        scheduleId = $Id
        availabilityView = (New-View $Codes)
        scheduleItems = @()
        workingHours = [pscustomobject][ordered]@{
            daysOfWeek = @('monday', 'tuesday', 'wednesday', 'thursday', 'friday')
            startTime = "$From`:00.0000000"
            endTime = "$To`:00.0000000"
            timeZone = [pscustomobject]@{ name = $Zone }
        }
    }
}

function Assert-RankFailure {
    param([scriptblock]$Operation, [string]$Expected)
    $failed = $false
    try { & $Operation | Out-Null }
    catch {
        $failed = $true
        if ($_.Exception.Message -notlike "*$Expected*") { throw }
    }
    if (-not $failed) { throw "Expected failure: $Expected" }
}

function Invoke-Rank {
    param([hashtable]$Options = @{})
    $arguments = @{
        SchedulePath = $schedulePath
        Start = '2026-10-01T00:00:00'
        TimeZone = 'Eastern Standard Time'
        Organizer = 'org@example.com'
        Required = @('pat@example.com', 'lee@example.com')
        Optional = @('ind@example.com')
        NotBefore = '2026-10-01T00:00'
        Format = 'json'
        Top = 1000
    }
    foreach ($key in $Options.Keys) { $arguments[$key] = $Options[$key] }
    return (& $scriptPath @arguments | ConvertFrom-Json)
}

function Get-Slot {
    param($Result, [string]$Start)
    return @($Result.slots | Where-Object { $_.start -eq $Start })[0]
}

try {
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    $schedule = [pscustomobject]@{
        value = @(
            (New-Person 'org@example.com' 'Eastern Standard Time' '09:00' '17:30' @{ (Get-Index 0 '14:00') = '2' }),
            (New-Person 'pat@example.com' 'Pacific Standard Time' '09:00' '17:00' @{ (Get-Index 1 '13:30') = '2' }),
            (New-Person 'lee@example.com' 'Eastern Standard Time' '09:00' '17:00' @{ (Get-Index 0 '13:00') = '1' }),
            (New-Person 'ind@example.com' 'India Standard Time' '09:00' '18:00')
        )
    }
    $schedulePath = Join-Path $fixtureRoot 'schedule.json'
    ("Action completed (HTTP 200):`n" + ($schedule | ConvertTo-Json -Depth 6)) | Set-Content -LiteralPath $schedulePath -Encoding UTF8

    $ranked = Invoke-Rank @{ Top = 5 }
    $best = $ranked.slots[0]
    if ($best.start -ne '2026-10-01T13:30' -or $best.requiredFree -ne 2 -or $best.requiredTotal -ne 2) { throw "Unexpected best slot: $($best.start) $($best.requiredFree)/$($best.requiredTotal)" }
    if (@($best.localTimes) -notcontains 'Pacific Thu 10:30' -or @($best.localTimes) -notcontains 'India Thu 23:00') { throw "Local times were not converted per attendee zone: $($best.localTimes -join '; ')" }
    if (@($best.optional) -notcontains 'ind: off') { throw 'Optional attendee outside working hours was not reported.' }
    if (@($ranked.slots).Count -ne 5) { throw 'Top did not limit the results.' }

    $all = Invoke-Rank @{ SortBy = 'time' }
    if (Get-Slot $all '2026-10-01T14:00') { throw 'A slot where the organizer is busy was ranked.' }
    if (Get-Slot $all '2026-10-01T17:30') { throw 'A slot outside the organizer working hours was ranked.' }
    if (@($all.slots | Where-Object { $_.start -like '2026-10-03*' -or $_.start -like '2026-10-04*' }).Count) { throw 'Weekend slots were ranked by default.' }
    $starts = @($all.slots | ForEach-Object { $_.start })
    if (($starts -join '|') -ne ((@($starts | Sort-Object)) -join '|')) { throw 'SortBy time did not return chronological slots.' }
    if (@((Get-Slot $all '2026-10-01T15:00').lunch) -notcontains 'pat') { throw 'Local lunch was not detected in the attendee time zone.' }
    if (@((Get-Slot $all '2026-10-01T12:00').lunch) -notcontains 'lee') { throw 'Local lunch was not detected in the organizer time zone.' }
    if (@((Get-Slot $all '2026-10-01T16:00').lunch).Count) { throw 'A slot after local lunch was marked as lunch.' }
    $early = Get-Slot $all '2026-10-01T11:30'
    if (@($early.offHours) -notcontains 'pat' -or $early.blockedCount -ne 1) { throw 'Working hours were not checked in the attendee time zone.' }
    if (@((Get-Slot $all '2026-10-01T17:00').offHours) -notcontains 'lee') { throw 'Attendee working-hours end was not honored.' }
    if (@((Get-Slot $all '2026-10-02T13:30').busy) -notcontains 'pat') { throw 'A busy required attendee was not reported.' }
    if (@((Get-Slot $all '2026-10-01T13:00').tentative) -notcontains 'lee') { throw 'A tentative attendee was not reported.' }

    $ignored = Invoke-Rank @{ IgnoreOrganizerBusyAt = @('2026-10-01T14:00') }
    if (-not (Get-Slot $ignored '2026-10-01T14:00')) { throw 'The organizer hold being moved was not treated as free.' }

    $hour = Invoke-Rank @{ DurationMinutes = 60 }
    if (-not (Get-Slot $all '2026-10-01T13:30') -or (Get-Slot $hour '2026-10-01T13:30')) { throw 'A 60-minute slot did not include its second interval.' }

    $holiday = Invoke-Rank @{ ExcludeDates = @('2026-10-02') }
    if (@($holiday.slots | Where-Object { $_.start -like '2026-10-02*' }).Count) { throw 'Excluded dates were ranked.' }
    $mondays = Invoke-Rank @{ Days = @('Mon') }
    if (-not @($mondays.slots).Count -or @($mondays.slots | Where-Object { $_.start -notlike '2026-10-05*' }).Count) { throw 'Day filtering did not keep only Monday slots.' }
    $later = Invoke-Rank @{ NotBefore = '2026-10-02T00:00' }
    if (@($later.slots | Where-Object { $_.start -like '2026-10-01*' }).Count) { throw 'NotBefore did not remove earlier slots.' }
    $strict = Invoke-Rank @{ MinRequiredFree = 2 }
    if (@($strict.slots | Where-Object { $_.requiredFree -lt 2 }).Count) { throw 'MinRequiredFree did not filter slots.' }
    $noLunch = Invoke-Rank @{ NoLunch = $true }
    if (@((Get-Slot $noLunch '2026-10-01T15:00').lunch).Count) { throw 'NoLunch still marked lunch.' }

    $table = & $scriptPath -SchedulePath $schedulePath -Start '2026-10-01T00:00:00' -TimeZone 'Eastern Standard Time' -Organizer 'org@example.com' -NotBefore '2026-10-01T00:00' -Top 3
    $text = ($table | Out-String)
    if ($text -notmatch 'Organizer org \(Eastern Standard Time\); 3 required, 0 optional' -or $text -notmatch 'Thu 2026-10-01 13:30') { throw "Table output was not readable: $text" }

    Assert-RankFailure { Invoke-Rank @{ Organizer = 'missing@example.com' } } 'is not in the schedule file'
    Assert-RankFailure { Invoke-Rank @{ Required = @('nobody@example.com') } } 'is not in the schedule file'
    Assert-RankFailure { Invoke-Rank @{ Start = 'tomorrow' } } 'Start must use'
    Assert-RankFailure { Invoke-Rank @{ Days = @('Funday') } } 'Unknown day'
    Assert-RankFailure { Invoke-Rank @{ TimeZone = 'Not A Zone' } } 'not a known time zone'
    Assert-RankFailure { & $scriptPath -SchedulePath (Join-Path $fixtureRoot 'missing.json') -Start '2026-10-01T00:00' -TimeZone 'Eastern Standard Time' -Organizer 'org@example.com' } 'Schedule file not found'
    Write-Output 'Slot ranking checks passed: per-zone working hours and lunch, organizer busy and moved holds, weekends, excluded dates, day filters, durations, sorting, and input errors.'
}
finally {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}
