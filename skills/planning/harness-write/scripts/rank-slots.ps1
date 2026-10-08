<#
.SYNOPSIS
Ranks meeting slots from a saved Microsoft Graph getSchedule response.

.DESCRIPTION
Reads the free/busy JSON returned by POST /me/calendar/getSchedule and ranks candidate slots
for required and optional attendees. Each attendee's working hours and local lunch window are
checked in that attendee's own time zone. The script is read-only: it calls no service and
writes no files.

Pass the same -Start, -TimeZone, and -IntervalMinutes values that were sent to getSchedule
(StartTime.dateTime, StartTime.timeZone, and AvailabilityViewInterval).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SchedulePath,
    [Parameter(Mandatory = $true)][string]$Start,
    [Parameter(Mandatory = $true)][string]$TimeZone,
    [Parameter(Mandatory = $true)][string]$Organizer,
    [string[]]$Required = @(),
    [string[]]$Optional = @(),
    [ValidateRange(5, 1440)][int]$IntervalMinutes = 30,
    [ValidateRange(5, 1440)][int]$DurationMinutes = 30,
    [string[]]$Days = @(),
    [string[]]$ExcludeDates = @(),
    [string]$LunchStart = '12:00',
    [string]$LunchEnd = '13:00',
    [switch]$NoLunch,
    [string[]]$IgnoreOrganizerBusyAt = @(),
    [string]$NotBefore = '',
    [ValidateRange(0, 1000)][int]$MinRequiredFree = 0,
    [ValidateSet('rank', 'time')][string]$SortBy = 'rank',
    [ValidateRange(1, 1000)][int]$Top = 10,
    [ValidateSet('table', 'json', 'object')][string]$Format = 'table'
)

$ErrorActionPreference = 'Stop'
$culture = [Globalization.CultureInfo]::InvariantCulture
$severity = @{ free = 0; tentative = 1; unknown = 2; lunch = 3; off = 4; busy = 5; oof = 6 }
$blocking = @('off', 'busy', 'oof')

function Get-Prop {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

function Split-List {
    param([string[]]$Values)
    foreach ($value in $Values) {
        foreach ($part in ([string]$value -split '[,;]')) {
            $trimmed = $part.Trim()
            if ($trimmed) { $trimmed }
        }
    }
}

function ConvertTo-LocalTime {
    param([string]$Text, [string]$Label)
    $clean = $Text.Trim()
    if ($clean.Length -gt 19 -and $clean[19] -eq '.') { $clean = $clean.Substring(0, 19) }
    $formats = [string[]]@('yyyy-MM-ddTHH:mm:ss', 'yyyy-MM-ddTHH:mm', 'yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd HH:mm', 'yyyy-MM-dd')
    $value = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($clean, $formats, $culture, [Globalization.DateTimeStyles]::None, [ref]$value)) {
        throw "$Label must use yyyy-MM-ddTHH:mm[:ss]: '$Text'"
    }
    return [datetime]::SpecifyKind($value, [DateTimeKind]::Unspecified)
}

function ConvertTo-TimeOfDay {
    param([string]$Text, [string]$Label)
    $value = [timespan]::Zero
    $clean = ([string]$Text).Trim()
    if ($clean.Length -gt 8) { $clean = $clean.Substring(0, 8) }
    if (-not [timespan]::TryParse($clean, $culture, [ref]$value) -or $value -lt [timespan]::Zero -or $value -gt [timespan]::FromHours(24)) {
        throw "$Label must be a time of day such as 09:00: '$Text'"
    }
    return $value
}

function Get-Zone {
    param([string]$Id, [string]$Label)
    try { return [TimeZoneInfo]::FindSystemTimeZoneById($Id) }
    catch { throw "$Label is not a known time zone id: '$Id'" }
}

function Get-ZoneLabel {
    param([TimeZoneInfo]$Zone)
    $label = $Zone.Id -replace ' (Standard|Daylight) Time$', ''
    if ($label.Contains('/')) { $label = $label.Substring($label.LastIndexOf('/') + 1).Replace('_', ' ') }
    return $label
}

function Get-DisplayName {
    param([string]$Id)
    $at = $Id.IndexOf('@')
    if ($at -gt 0) { return $Id.Substring(0, $at) }
    return $Id
}

$dayMap = @{
    sun = [DayOfWeek]::Sunday; mon = [DayOfWeek]::Monday; tue = [DayOfWeek]::Tuesday; wed = [DayOfWeek]::Wednesday
    thu = [DayOfWeek]::Thursday; fri = [DayOfWeek]::Friday; sat = [DayOfWeek]::Saturday
}
$allowedDays = @()
foreach ($name in @(Split-List $Days)) {
    $key = $name.ToLowerInvariant()
    if ($key.Length -lt 3 -or -not $dayMap.ContainsKey($key.Substring(0, 3))) { throw "Unknown day: '$name'" }
    $allowedDays += $dayMap[$key.Substring(0, 3)]
}
if (-not $allowedDays.Count) {
    $allowedDays = @([DayOfWeek]::Monday, [DayOfWeek]::Tuesday, [DayOfWeek]::Wednesday, [DayOfWeek]::Thursday, [DayOfWeek]::Friday)
}

$excluded = New-Object 'System.Collections.Generic.HashSet[datetime]'
foreach ($date in @(Split-List $ExcludeDates)) { [void]$excluded.Add((ConvertTo-LocalTime $date 'ExcludeDates').Date) }
$ignoredOrganizerSlots = New-Object 'System.Collections.Generic.HashSet[long]'
foreach ($slot in @(Split-List $IgnoreOrganizerBusyAt)) { [void]$ignoredOrganizerSlots.Add((ConvertTo-LocalTime $slot 'IgnoreOrganizerBusyAt').Ticks) }
$lunchFrom = ConvertTo-TimeOfDay $LunchStart 'LunchStart'
$lunchTo = ConvertTo-TimeOfDay $LunchEnd 'LunchEnd'
if (-not $NoLunch -and $lunchTo -le $lunchFrom) { throw 'LunchEnd must be later than LunchStart.' }

$organizerZone = Get-Zone $TimeZone 'TimeZone'
$startLocal = ConvertTo-LocalTime $Start 'Start'
$notBeforeUtc = [datetime]::UtcNow
if ($NotBefore) { $notBeforeUtc = [TimeZoneInfo]::ConvertTimeToUtc((ConvertTo-LocalTime $NotBefore 'NotBefore'), $organizerZone) }
$span = [int][math]::Ceiling($DurationMinutes / [double]$IntervalMinutes)

if (-not (Test-Path -LiteralPath $SchedulePath -PathType Leaf)) { throw "Schedule file not found: $SchedulePath" }
$raw = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $SchedulePath).ProviderPath)
$jsonStart = $raw.IndexOfAny([char[]]@('{', '['))
if ($jsonStart -lt 0) { throw "Schedule file contains no JSON: $SchedulePath" }
$data = $raw.Substring($jsonStart) | ConvertFrom-Json
$items = @(Get-Prop $data 'value')
if (-not (Get-Prop $data 'value')) { $items = @($data) }

$people = @{}
$order = @()
foreach ($item in $items) {
    $id = [string](Get-Prop $item 'scheduleId')
    if (-not $id) { continue }
    $key = $id.ToLowerInvariant()
    $view = [string](Get-Prop $item 'availabilityView')
    if (-not $view) { Write-Warning "No availability for $id; treating it as unknown." }
    $hours = Get-Prop $item 'workingHours'
    $zone = $organizerZone
    $zoneKnown = $false
    $zoneName = [string](Get-Prop (Get-Prop $hours 'timeZone') 'name')
    if ($zoneName) {
        try { $zone = [TimeZoneInfo]::FindSystemTimeZoneById($zoneName); $zoneKnown = $true }
        catch { Write-Warning "Unknown time zone '$zoneName' for $id; skipping its working-hours and lunch checks." }
    }
    $workDays = @()
    $rawDays = Get-Prop $hours 'daysOfWeek'
    if ($rawDays) { $workDays = @($rawDays | ForEach-Object { ([string]$_).ToLowerInvariant() }) }
    $workStart = $null
    $workEnd = $null
    if ((Get-Prop $hours 'startTime') -and (Get-Prop $hours 'endTime')) {
        $workStart = ConvertTo-TimeOfDay (Get-Prop $hours 'startTime') "$id working-hours start"
        $workEnd = ConvertTo-TimeOfDay (Get-Prop $hours 'endTime') "$id working-hours end"
    }
    $people[$key] = [pscustomobject]@{
        Id = $id; Name = (Get-DisplayName $id); View = $view; Zone = $zone; ZoneKnown = $zoneKnown
        WorkDays = $workDays; WorkStart = $workStart; WorkEnd = $workEnd
    }
    $order += $key
}

$organizerKey = $Organizer.Trim().ToLowerInvariant()
if (-not $people.ContainsKey($organizerKey)) { throw "Organizer '$Organizer' is not in the schedule file; include the organizer in getSchedule." }
$organizerPerson = $people[$organizerKey]
if (-not $organizerPerson.View) { throw "Organizer '$Organizer' has no availability view." }

$requiredKeys = @(Split-List $Required | ForEach-Object { $_.ToLowerInvariant() })
$optionalKeys = @(Split-List $Optional | ForEach-Object { $_.ToLowerInvariant() })
foreach ($key in ($requiredKeys + $optionalKeys)) {
    if (-not $people.ContainsKey($key)) { throw "Attendee '$key' is not in the schedule file. Available: $($order -join ', ')" }
}
if (-not $requiredKeys.Count) { $requiredKeys = @($order | Where-Object { $_ -ne $organizerKey -and $optionalKeys -notcontains $_ }) }
$requiredKeys = @($requiredKeys | Where-Object { $_ -ne $organizerKey } | Select-Object -Unique)
$optionalKeys = @($optionalKeys | Where-Object { $_ -ne $organizerKey -and $requiredKeys -notcontains $_ } | Select-Object -Unique)

function Test-WithinHours {
    param($Person, [datetime]$LocalStart, [datetime]$LocalEnd)
    if ($null -eq $Person.WorkStart -or $null -eq $Person.WorkEnd) { return $true }
    if ($Person.WorkDays.Count -and $Person.WorkDays -notcontains $LocalStart.DayOfWeek.ToString().ToLowerInvariant()) { return $false }
    $endOffset = $LocalEnd - $LocalStart.Date
    if ($Person.WorkEnd -gt $Person.WorkStart) {
        return ($LocalStart.TimeOfDay -ge $Person.WorkStart -and $endOffset -le $Person.WorkEnd)
    }
    return ($LocalStart.TimeOfDay -ge $Person.WorkStart -or $endOffset -le $Person.WorkEnd)
}

function Get-PersonStatus {
    param($Person, [int]$Index, [datetime]$SlotUtc, [bool]$ApplyLunch, [bool]$IgnoreCalendar)
    $worst = 'free'
    if (-not $IgnoreCalendar) {
        for ($offset = 0; $offset -lt $span; $offset++) {
            $position = $Index + $offset
            $code = '?'
            if ($position -lt $Person.View.Length) { $code = [string]$Person.View[$position] }
            $status = switch ($code) { '0' { 'free' } '4' { 'free' } '1' { 'tentative' } '2' { 'busy' } '3' { 'oof' } default { 'unknown' } }
            if ($severity[$status] -gt $severity[$worst]) { $worst = $status }
        }
    }
    if ($Person.ZoneKnown) {
        $localStart = [TimeZoneInfo]::ConvertTimeFromUtc($SlotUtc, $Person.Zone)
        $localEnd = [TimeZoneInfo]::ConvertTimeFromUtc($SlotUtc.AddMinutes($DurationMinutes), $Person.Zone)
        $local = $null
        if (-not (Test-WithinHours $Person $localStart $localEnd)) { $local = 'off' }
        elseif ($ApplyLunch -and $localStart -lt ($localStart.Date + $lunchTo) -and $localEnd -gt ($localStart.Date + $lunchFrom)) { $local = 'lunch' }
        if ($local -and $severity[$local] -gt $severity[$worst]) { $worst = $local }
    }
    return $worst
}

$attendeeZones = @()
foreach ($key in ($requiredKeys + $optionalKeys)) {
    $zone = $people[$key].Zone
    if ($people[$key].ZoneKnown -and $zone.Id -ne $organizerZone.Id -and -not ($attendeeZones | Where-Object { $_.Id -eq $zone.Id })) { $attendeeZones += $zone }
}

$slots = New-Object System.Collections.Generic.List[object]
$candidates = 0
$viewLength = $organizerPerson.View.Length
for ($index = 0; $index -le $viewLength - $span; $index++) {
    $slotLocal = $startLocal.AddMinutes($index * $IntervalMinutes)
    if ($allowedDays -notcontains $slotLocal.DayOfWeek -or $excluded.Contains($slotLocal.Date)) { continue }
    if ($organizerZone.IsInvalidTime($slotLocal)) { continue }
    $slotUtc = [TimeZoneInfo]::ConvertTimeToUtc($slotLocal, $organizerZone)
    if ($slotUtc -lt $notBeforeUtc) { continue }
    $ignoreCalendar = $ignoredOrganizerSlots.Contains($slotLocal.Ticks)
    if ((Get-PersonStatus $organizerPerson $index $slotUtc $false $ignoreCalendar) -ne 'free') { continue }
    $candidates++

    $groups = @{ free = @(); tentative = @(); unknown = @(); lunch = @(); off = @(); busy = @(); oof = @() }
    foreach ($key in $requiredKeys) {
        $status = Get-PersonStatus $people[$key] $index $slotUtc (-not $NoLunch) $false
        $groups[$status] += $people[$key].Name
    }
    $requiredFree = $groups['free'].Count
    if ($requiredFree -lt $MinRequiredFree) { continue }
    $blocked = @($blocking | ForEach-Object { $groups[$_] } | Where-Object { $_ })
    $optionalStatus = @()
    $optionalFree = 0
    foreach ($key in $optionalKeys) {
        $status = Get-PersonStatus $people[$key] $index $slotUtc (-not $NoLunch) $false
        if ($status -eq 'free') { $optionalFree++ }
        $optionalStatus += "$($people[$key].Name): $status"
    }
    $localTimes = @($attendeeZones | ForEach-Object {
            "$(Get-ZoneLabel $_) $([TimeZoneInfo]::ConvertTimeFromUtc($slotUtc, $_).ToString('ddd HH:mm', $culture))"
        })
    $slots.Add([pscustomobject][ordered]@{
            start         = $slotLocal.ToString('yyyy-MM-ddTHH:mm', $culture)
            day           = $slotLocal.ToString('ddd', $culture)
            requiredFree  = $requiredFree
            requiredTotal = $requiredKeys.Count
            blockedCount  = $blocked.Count
            optionalFree  = $optionalFree
            busy          = @($groups['busy'] + $groups['oof'])
            offHours      = @($groups['off'])
            lunch         = @($groups['lunch'])
            tentative     = @($groups['tentative'])
            unknown       = @($groups['unknown'])
            optional      = $optionalStatus
            localTimes    = $localTimes
        })
}

if ($SortBy -eq 'rank') {
    $sorted = @($slots | Sort-Object -Property @{ Expression = 'requiredFree'; Descending = $true }, @{ Expression = 'blockedCount'; Descending = $false }, @{ Expression = 'optionalFree'; Descending = $true }, @{ Expression = 'start'; Descending = $false })
}
else {
    $sorted = @($slots | Sort-Object -Property start)
}
$selected = @($sorted | Select-Object -First $Top)

if ($Format -eq 'object') { return $selected }
if ($Format -eq 'json') {
    $result = [pscustomobject][ordered]@{
        timeZone        = $organizerZone.Id
        organizer       = $organizerPerson.Id
        durationMinutes = $DurationMinutes
        required        = @($requiredKeys | ForEach-Object { $people[$_].Id })
        optional        = @($optionalKeys | ForEach-Object { $people[$_].Id })
        candidates      = $candidates
        slots           = $selected
    }
    return (ConvertTo-Json -InputObject $result -Depth 5)
}

Write-Output ("Organizer {0} ({1}); {2} required, {3} optional; {4} slot(s) where the organizer is free; showing {5} by {6}." -f `
        $organizerPerson.Name, $organizerZone.Id, $requiredKeys.Count, $optionalKeys.Count, $candidates, $selected.Count, $SortBy)
$selected | ForEach-Object {
    $soft = @($_.tentative) + @($_.lunch | ForEach-Object { "$_ (lunch)" }) + @($_.unknown | ForEach-Object { "$_ (?)" })
    [pscustomobject][ordered]@{
        Start     = "$($_.day) $($_.start.Replace('T', ' '))"
        Free      = "$($_.requiredFree)/$($_.requiredTotal)"
        Busy      = $_.busy -join ', '
        OffHours  = $_.offHours -join ', '
        Tentative = $soft -join ', '
        Optional  = $_.optional -join '; '
        Local     = $_.localTimes -join '; '
    }
} | Format-Table -AutoSize -Wrap | Out-String -Width 4096
