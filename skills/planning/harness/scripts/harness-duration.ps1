$ErrorActionPreference = 'Stop'

function ConvertTo-HarnessDuration {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ($Value -cnotmatch '^(?<amount>(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+))(?<unit>[mhdny])$') { throw 'Use a positive duration with m, h, d, n (calendar months), or y (calendar years).' }
    $amount = [double]::Parse($Matches.amount, [Globalization.CultureInfo]::InvariantCulture)
    $unit = $Matches.unit
    if (-not [double]::IsFinite($amount) -or $amount -le 0) { throw 'Duration must be positive and finite.' }
    if ($unit -in @('n', 'y') -and ($amount -ne [math]::Truncate($amount) -or $amount -gt [int]::MaxValue)) { throw 'Calendar months and years require positive whole numbers.' }
    $seconds = switch ($unit) { 'm' { $amount * 60 }; 'h' { $amount * 3600 }; 'd' { $amount * 86400 }; default { $null } }
    if ($null -ne $seconds -and (-not [double]::IsFinite($seconds) -or $seconds -lt 1 -or $seconds -gt [timespan]::MaxValue.TotalSeconds)) { throw 'Fixed durations must fit a TimeSpan and be at least one second.' }
    [pscustomobject]@{ value = $Value; amount = $amount; unit = $unit; seconds = $seconds }
}

function ConvertFrom-HarnessLocalTime {
    param([datetime]$LocalTime, [TimeZoneInfo]$TimeZone)
    $local = [datetime]::SpecifyKind($LocalTime, [DateTimeKind]::Unspecified)
    while ($TimeZone.IsInvalidTime($local)) { $local = $local.AddMinutes(1) }
    if ($TimeZone.IsAmbiguousTime($local)) {
        $offset = $TimeZone.GetAmbiguousTimeOffsets($local) | Sort-Object -Descending | Select-Object -First 1
        return [datetimeoffset]::new($local, $offset).ToUniversalTime()
    }
    [datetimeoffset]::new([TimeZoneInfo]::ConvertTimeToUtc($local, $TimeZone))
}

function Get-HarnessNextDue {
    param([string]$Interval, [datetimeoffset]$Anchor, [datetimeoffset]$After, [string]$TimeZoneId = [TimeZoneInfo]::Local.Id)
    $duration = ConvertTo-HarnessDuration $Interval
    if ($null -ne $duration.seconds) {
        $periods = [math]::Max(1, [math]::Floor(($After - $Anchor).TotalSeconds / $duration.seconds) + 1)
        return $Anchor.AddSeconds($periods * $duration.seconds).ToUniversalTime()
    }
    $zone = [TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId)
    $localAnchor = [TimeZoneInfo]::ConvertTime($Anchor, $zone).DateTime
    $localAfter = [TimeZoneInfo]::ConvertTime($After, $zone).DateTime
    $difference = if ($duration.unit -eq 'n') { ($localAfter.Year - $localAnchor.Year) * 12 + $localAfter.Month - $localAnchor.Month } else { $localAfter.Year - $localAnchor.Year }
    $periods = [math]::Max(1, [math]::Floor($difference / $duration.amount))
    do {
        $amount = [int]($periods * $duration.amount)
        $localDue = if ($duration.unit -eq 'n') { $localAnchor.AddMonths($amount) } else { $localAnchor.AddYears($amount) }
        $due = ConvertFrom-HarnessLocalTime $localDue $zone
        $periods++
    } while ($due -le $After)
    $due
}

function Get-HarnessRetentionCutoff {
    param([string]$MaxAge, [datetimeoffset]$Now, [string]$TimeZoneId = [TimeZoneInfo]::Local.Id)
    $duration = ConvertTo-HarnessDuration $MaxAge
    if ($null -ne $duration.seconds) { return $Now.AddSeconds(-$duration.seconds).ToUniversalTime() }
    $zone = [TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId)
    $local = [TimeZoneInfo]::ConvertTime($Now, $zone).DateTime
    $cutoff = if ($duration.unit -eq 'n') { $local.AddMonths(-[int]$duration.amount) } else { $local.AddYears(-[int]$duration.amount) }
    ConvertFrom-HarnessLocalTime $cutoff $zone
}

function Test-HarnessMaintenanceWindow {
    param([datetimeoffset]$Now, [string]$TimeZoneId = [TimeZoneInfo]::Local.Id, [string]$LastCompletedDate)
    $local = [TimeZoneInfo]::ConvertTime($Now, [TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId))
    $local.DayOfWeek -eq [DayOfWeek]::Saturday -and $local.TimeOfDay -ge [timespan]::FromHours(8.5) -and
        $local.TimeOfDay -lt [timespan]::FromHours(9) -and $local.ToString('yyyy-MM-dd') -cne $LastCompletedDate
}