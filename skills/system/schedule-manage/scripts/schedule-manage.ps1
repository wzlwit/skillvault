param(
    [switch]$Delete,
    [switch]$Enable,
    [switch]$Disable,
    [string]$Selector,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$selectedActions = @(
    if ($Delete) { 'delete' }
    if ($Enable) { 'enable' }
    if ($Disable) { 'disable' }
)
if ($selectedActions.Count -gt 1) {
    throw 'Choose only one action: -Delete, -Enable, or -Disable.'
}
$operation = if ($selectedActions.Count -eq 1) { $selectedActions[0] } else { 'list' }

function Get-TaskActionText {
    param($Actions)

    if (-not $Actions) { return [pscustomobject]@{ Execute = ''; Arguments = '' } }

    $execute = @($Actions | ForEach-Object { $_.Execute }) -join '; '
    $arguments = @($Actions | ForEach-Object { $_.Arguments }) -join '; '

    [pscustomobject]@{
        Execute = $execute
        Arguments = $arguments
    }
}

function Get-ScheduleEntries {
    $index = 1
    Get-ScheduledTask | Sort-Object TaskPath, TaskName | ForEach-Object {
        $info = $null
        try {
            $info = Get-ScheduledTaskInfo -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction Stop
        }
        catch {
            $info = $null
        }

        $actionText = Get-TaskActionText $_.Actions
        [pscustomobject]@{
            Index = $index
            TaskName = $_.TaskName
            TaskPath = $_.TaskPath
            State = $_.State
            NextRunTime = if ($info) { $info.NextRunTime } else { '' }
            LastRunTime = if ($info) { $info.LastRunTime } else { '' }
            Execute = $actionText.Execute
            Arguments = $actionText.Arguments
            Description = $_.Description
        }
        $index++
    }
}

function Resolve-Selector {
    param(
        [object[]]$Entries,
        [string]$SelectorText
    )

    if ([string]::IsNullOrWhiteSpace($SelectorText)) {
        throw 'Selector is required for enable, disable, or delete. Run list first, then pass an index, range, list, or keyword.'
    }

    $selectedIndexes = New-Object 'System.Collections.Generic.HashSet[int]'
    $keywordTokens = New-Object 'System.Collections.Generic.List[string]'

    foreach ($token in ($SelectorText -split ',')) {
        $trimmed = $token.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }

        if ($trimmed -match '^\d+$') {
            [void]$selectedIndexes.Add([int]$trimmed)
            continue
        }

        if ($trimmed -match '^(\d+)-(\d+)$') {
            $start = [int]$Matches[1]
            $end = [int]$Matches[2]
            if ($start -gt $end) { throw "Invalid range: $trimmed" }
            for ($current = $start; $current -le $end; $current++) {
                [void]$selectedIndexes.Add($current)
            }
            continue
        }

        [void]$keywordTokens.Add($trimmed)
    }

    $matchedEntries = @($Entries | Where-Object { $selectedIndexes.Contains([int]$_.Index) })

    foreach ($keyword in $keywordTokens) {
        $escaped = [regex]::Escape($keyword)
        $matchedEntries += @($Entries | Where-Object {
            $_.TaskName -match $escaped -or
            $_.TaskPath -match $escaped -or
            $_.Execute -match $escaped -or
            $_.Arguments -match $escaped -or
            $_.Description -match $escaped
        })
    }

    $matchedEntries | Sort-Object Index -Unique
}

function Write-ScheduleIntro {
    Write-Output 'Windows scheduled tasks found on this machine. Indexes are stable only for this listing run.'
    Write-Output 'Use them immediately with enable, disable, or delete, or use a keyword if the task name is clear.'
    Write-Output ''
}

function Write-ScheduleTable {
    param([object[]]$Entries)

    if (-not $Entries -or $Entries.Count -eq 0) {
        Write-Output 'No scheduled tasks found.'
        return
    }

    $Entries |
        Select-Object Index, TaskName, TaskPath, State, NextRunTime, LastRunTime, Execute, Arguments |
        Format-Table -AutoSize | Out-String -Width 260 | Write-Output
}

$entries = @(Get-ScheduleEntries)

if ($operation -eq 'list') {
    Write-ScheduleIntro
    Write-ScheduleTable $entries
    return
}

$matchedEntries = @(Resolve-Selector -Entries $entries -SelectorText $Selector)
if ($matchedEntries.Count -eq 0) {
    Write-Output "No scheduled tasks matched selector: $Selector"
    return
}

Write-Output "Selected scheduled tasks to ${operation}:"
Write-ScheduleTable $matchedEntries

if (-not $Force) {
    Write-Output "Re-run with -Force after confirming '$operation' for the selected tasks."
    return
}

foreach ($match in $matchedEntries) {
    switch ($operation) {
        'enable' {
            Enable-ScheduledTask -TaskName $match.TaskName -TaskPath $match.TaskPath | Out-Null
            Write-Output "Enabled scheduled task: $($match.TaskPath)$($match.TaskName)"
        }
        'disable' {
            Disable-ScheduledTask -TaskName $match.TaskName -TaskPath $match.TaskPath | Out-Null
            Write-Output "Disabled scheduled task: $($match.TaskPath)$($match.TaskName)"
        }
        'delete' {
            Unregister-ScheduledTask -TaskName $match.TaskName -TaskPath $match.TaskPath -Confirm:$false
            Write-Output "Deleted scheduled task: $($match.TaskPath)$($match.TaskName)"
        }
    }
}