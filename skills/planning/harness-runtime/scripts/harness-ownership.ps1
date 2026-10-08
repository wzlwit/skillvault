$ownershipHelper = Join-Path $PSScriptRoot '../../skillvault-installation/scripts/skill-ownership.ps1'
if (-not (Test-Path -LiteralPath $ownershipHelper -PathType Leaf)) {
    $ownershipHelper = Join-Path $PSScriptRoot '../../../core/skillvault-installation/scripts/skill-ownership.ps1'
}
if (-not (Test-Path -LiteralPath $ownershipHelper -PathType Leaf)) { throw 'Install the matching skillvault-installation ownership helper beside harness before execution.' }
. $ownershipHelper

function Enter-HarnessOwnership {
    param($Paths, [string]$Role, [string]$TaskId, [string]$Workspace, [ValidateSet('Read', 'Write')][string]$Mode = 'Write', [string]$Snapshot, [string[]]$AdditionalWorkspaces)
    $resources = @()
    foreach ($directory in @(@($Workspace) + @($AdditionalWorkspaces) | Where-Object { $_ } | Select-Object -Unique)) {
        $checkout = $directory
        $parent = $directory
        while ($parent) {
            if (Test-Path -LiteralPath (Join-Path $parent '.git')) { $checkout = $parent; break }
            $parent = Split-Path -Parent $parent
        }
        $identity = $Snapshot
        if ($Mode -eq 'Read' -and $Snapshot) {
            $hasher = [Security.Cryptography.SHA256]::Create()
            try { $identity = ([BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($Snapshot)))).Replace('-', '') }
            finally { $hasher.Dispose() }
        }
        $resources += [pscustomobject]@{ kind = 'checkout'; path = $checkout; mode = $Mode; snapshot = $identity }
    }
    if (-not (Get-Command Enter-SkillRuntimeOwnership).Parameters.ContainsKey('InterfaceVersion')) { throw 'Incompatible runtime helper. Update skillvault-installation and harness together before execution; compatibility interface v1 is required.' }
    Enter-SkillRuntimeOwnership -SkillPath (Split-Path -Parent $PSScriptRoot) -Resources $resources -Owner ([pscustomobject]@{ controller = $Paths.Project; role = $Role; task = $TaskId }) -InterfaceVersion 1
}

function Exit-HarnessOwnership {
    param($Lease, $Paths)
    if (-not $Lease) { return }
    $uncertain = $true
    try { $uncertain = (Read-HarnessState $Paths).active.ownershipClaim -ceq $Lease.id }
    finally { Exit-SkillOwnership $Lease -Uncertain:$uncertain }
}

function Clear-HarnessOwnership {
    param($Paths, [switch]$ConfirmStopped)
    if (-not $ConfirmStopped) { throw 'ConfirmStopped is required for ownership recovery.' }
    $root = Get-SkillOwnershipRoot
    foreach ($claim in @(Read-SkillOwnershipClaims $root | Where-Object { $_.owner.controller -ceq $Paths.Project })) {
        Clear-SkillOwnership -Id $claim.id -Root $root -ConfirmStopped
    }
}