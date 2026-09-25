$ErrorActionPreference = 'Stop'

$managerPath = Join-Path $PSScriptRoot '..\skills\system\schedule-manager\scripts\schedule-manager.ps1'
$calls = New-Object 'System.Collections.Generic.List[object]'

function Get-ScheduledTask {
    foreach ($taskPath in @('\Other\', '\Jobs\')) {
        [pscustomobject]@{
            TaskName = 'Fixture'
            TaskPath = $taskPath
            State = 'Ready'
            Actions = @()
            Description = 'Schedule manager test fixture'
        }
    }
}

function Get-ScheduledTaskInfo {
    [CmdletBinding()]
    param([string]$TaskName, [string]$TaskPath)

    [pscustomobject]@{ NextRunTime = ''; LastRunTime = '' }
}

function Enable-ScheduledTask {
    param([string]$TaskName, [string]$TaskPath)

    $calls.Add([pscustomobject]@{ Action = 'Enable'; Name = $TaskName; Path = $TaskPath })
}

function Disable-ScheduledTask {
    param([string]$TaskName, [string]$TaskPath)

    $calls.Add([pscustomobject]@{ Action = 'Disable'; Name = $TaskName; Path = $TaskPath })
}

function Unregister-ScheduledTask {
    param([string]$TaskName, [string]$TaskPath, [switch]$Confirm)

    $calls.Add([pscustomobject]@{ Action = 'Delete'; Name = $TaskName; Path = $TaskPath })
}

foreach ($action in @('Enable', 'Disable', 'Delete')) {
    $calls.Clear()
    $parameters = @{ Selector = '1' }
    $parameters[$action] = $true

    $preview = @(& $managerPath @parameters) -join "`n"
    if ($calls.Count -ne 0 -or $preview -notmatch 'Re-run with -Force') {
        throw "$action must preview without changing any task."
    }

    $parameters.Force = $true
    & $managerPath @parameters | Out-Null
    if ($calls.Count -ne 1 -or $calls[0].Action -ne $action -or $calls[0].Name -ne 'Fixture' -or $calls[0].Path -ne '\Jobs\') {
        throw "$action did not target only the selected task and task path."
    }

    foreach ($selector in @('Fixture', '1,Fixture', '1-2')) {
        $calls.Clear()
        $parameters.Selector = $selector
        & $managerPath @parameters | Out-Null
        if ($calls.Count -ne 2 -or $calls[0].Action -ne $action -or $calls[1].Action -ne $action -or
            $calls[0].Path -ne '\Jobs\' -or $calls[1].Path -ne '\Other\') {
            throw "$action did not resolve '$selector' to both unique task paths."
        }
    }

    $calls.Clear()
    $parameters.Selector = 'not-found'
    & $managerPath @parameters | Out-Null
    if ($calls.Count -ne 0) { throw "$action changed an unmatched task." }

    $parameters.Remove('Selector')
    $rejected = $false
    try { & $managerPath @parameters | Out-Null }
    catch { $rejected = $_.Exception.Message -like 'Selector is required*' }
    if (-not $rejected -or $calls.Count -ne 0) { throw "$action must reject a missing selector." }
}

foreach ($pair in @(@('Enable', 'Disable'), @('Enable', 'Delete'), @('Disable', 'Delete'))) {
    $parameters = @{ Selector = '1'; Force = $true }
    foreach ($action in $pair) { $parameters[$action] = $true }
    $rejected = $false
    try { & $managerPath @parameters | Out-Null }
    catch { $rejected = $_.Exception.Message -like 'Choose only one action*' }
    if (-not $rejected -or $calls.Count -ne 0) { throw 'Conflicting actions must not change any tasks.' }
}

$listing = @(& $managerPath) -join "`n"
if ($calls.Count -ne 0 -or $listing -notmatch 'Windows scheduled tasks found') {
    throw 'The default action must remain read-only listing.'
}

Write-Output 'Schedule manager action checks passed using fake tasks only.'