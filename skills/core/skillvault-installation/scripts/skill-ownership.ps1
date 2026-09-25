function New-SkillOwnershipFailure {
    param([string]$Status, [string]$Message, $Owner)
    $failure = [InvalidOperationException]::new($Message)
    $failure.Data['SkillOwnershipStatus'] = $Status
    if ($Owner) { $failure.Data['SkillOwnershipOwner'] = $Owner }
    $failure
}

function Get-SkillOwnershipRoot {
    param([string]$Root)
    if (-not $Root) { $Root = $env:SKILLVAULT_OWNERSHIP_ROOT }
    if (-not $Root) { $Root = Join-Path $HOME '.copilot/skillvault/ownership' }
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
}

function ConvertTo-SkillOwnershipResource {
    param($Resource)
    if ($Resource.kind -cnotin @('checkout', 'runtime') -or $Resource.mode -cnotin @('Read', 'Write') -or
        [string]::IsNullOrWhiteSpace([string]$Resource.path)) { throw 'Ownership resources require kind, mode, and an absolute path.' }
    if (-not [IO.Path]::IsPathRooted([string]$Resource.path)) { throw 'Ownership paths must be absolute.' }
    $path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath([string]$Resource.path)
    $parent = $path
    while ($parent) {
        if (Test-Path -LiteralPath $parent) {
            $item = Get-Item -LiteralPath $parent -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Ownership path crosses a linked filesystem entry: $parent" }
        }
        $parent = Split-Path -Parent $parent
    }
    $path = $path.TrimEnd([char[]]'\/')
    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { $path = $path.ToUpperInvariant() }
    if ($Resource.kind -ceq 'checkout' -and $Resource.mode -ceq 'Read' -and
        [string]::IsNullOrWhiteSpace([string]$Resource.snapshot)) { throw 'A shared checkout reader requires a stable snapshot identity.' }
    [pscustomobject]@{ kind = $Resource.kind; path = $path; mode = $Resource.mode; snapshot = [string]$Resource.snapshot }
}

function Enter-SkillOwnershipRegistry {
    param([string]$Root)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Root.ToUpperInvariant())
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $key = ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '') }
    finally { $hasher.Dispose() }
    $prefix = if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { 'Global\SkillVaultOwnership-' } else { 'SkillVaultOwnership-' }
    $mutex = [Threading.Mutex]::new($false, ($prefix + $key))
    try {
        try { $acquired = $mutex.WaitOne(5000) }
        catch [Threading.AbandonedMutexException] { $acquired = $true }
        if (-not $acquired) { throw (New-SkillOwnershipFailure Busy 'Ownership registry is busy; no operation started.') }
        $mutex
    }
    catch { $mutex.Dispose(); throw }
}

function Read-SkillOwnershipClaims {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return }
    foreach ($file in Get-ChildItem -LiteralPath $Root -Filter '*.json' -File) {
        try {
            $claim = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
            if ($claim.schemaVersion -ne 1 -or $claim.id -cnotmatch '^[a-f0-9]{32}$' -or
                $file.BaseName -cne $claim.id -or $claim.resources -isnot [array] -or $claim.resources.Count -eq 0) { throw 'Invalid claim shape.' }
            foreach ($resource in $claim.resources) { $null = ConvertTo-SkillOwnershipResource $resource }
            $claim
        }
        catch { throw (New-SkillOwnershipFailure NeedsRecovery "Unreadable ownership evidence: $($file.FullName)") }
    }
}

function Test-SkillOwnershipClaimActive {
    param([string]$Root, $Claim)
    $path = Join-Path $Root ($Claim.id + '.lock')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    try {
        $probe = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $probe.Dispose()
        $false
    }
    catch [IO.IOException] { $true }
}

function Enter-SkillOwnership {
    param([Parameter(Mandatory = $true)][object[]]$Resources, [Parameter(Mandatory = $true)]$Owner, [string]$Root)
    $ErrorActionPreference = 'Stop'
    $Root = Get-SkillOwnershipRoot $Root
    $resources = @($Resources | ForEach-Object { ConvertTo-SkillOwnershipResource $_ })
    if ($resources.Count -eq 0) { throw 'At least one ownership resource is required.' }
    $mutex = Enter-SkillOwnershipRegistry $Root
    $stream = $null
    $id = [guid]::NewGuid().ToString('N')
    try {
        foreach ($claim in @(Read-SkillOwnershipClaims $Root)) {
            foreach ($requested in $resources) {
                foreach ($held in $claim.resources) {
                    if ($held.kind -cne $requested.kind -or $held.path -cne $requested.path) { continue }
                    $ownerText = $claim.owner | ConvertTo-Json -Compress -Depth 6
                    if (-not (Test-SkillOwnershipClaimActive $Root $claim)) {
                        throw (New-SkillOwnershipFailure NeedsRecovery "Ownership requires recovery for $($requested.path); owner: $ownerText; claim: $($claim.id)." $claim.owner)
                    }
                    if ($held.mode -ceq 'Read' -and $requested.mode -ceq 'Read' -and
                        ($requested.kind -ceq 'runtime' -or $held.snapshot -ceq $requested.snapshot)) { continue }
                    $failure = New-SkillOwnershipFailure Busy "Resource is busy: $($requested.path); owner: $ownerText; claim: $($claim.id)." $claim.owner
                    $failure.Data['SkillOwnershipProcessId'] = $claim.processId
                    throw $failure
                }
            }
        }
        New-Item -ItemType Directory -Path $Root -Force | Out-Null
        $stream = [IO.File]::Open((Join-Path $Root ($id + '.lock')), [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $process = Get-Process -Id $PID
        $claim = [ordered]@{ schemaVersion = 1; id = $id; processId = $PID; processStartedAt = $process.StartTime.ToUniversalTime().ToString('o'); owner = $Owner; resources = $resources }
        [IO.File]::WriteAllText((Join-Path $Root ($id + '.json')), ($claim | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
        [pscustomobject]@{ id = $id; root = $Root; stream = $stream }
    }
    catch {
        if ($stream) { $stream.Dispose() }
        foreach ($extension in @('.json', '.lock')) {
            $path = Join-Path $Root ($id + $extension)
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
        }
        throw
    }
    finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
}

function Exit-SkillOwnership {
    param($Lease, [switch]$Uncertain)
    if (-not $Lease) { return }
    $mutex = $null
    try {
        $mutex = Enter-SkillOwnershipRegistry $Lease.root
        $Lease.stream.Dispose()
        if (-not $Uncertain) {
            foreach ($extension in @('.json', '.lock')) {
                $path = Join-Path $Lease.root ($Lease.id + $extension)
                if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
            }
        }
    }
    finally {
        $Lease.stream.Dispose()
        if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
    }
}

function Clear-SkillOwnership {
    param([Parameter(Mandatory = $true)][string]$Id, [switch]$ConfirmStopped, [string]$Root)
    if (-not $ConfirmStopped) { throw 'ConfirmStopped is required after inspecting the owner and stopping prior workers.' }
    $Root = Get-SkillOwnershipRoot $Root
    $mutex = Enter-SkillOwnershipRegistry $Root
    try {
        $claims = @(Read-SkillOwnershipClaims $Root | Where-Object { $_.id -ceq $Id })
        if ($claims.Count -ne 1) { throw 'Select one exact ownership claim to recover.' }
        if (Test-SkillOwnershipClaimActive $Root $claims[0]) { throw 'The ownership claim is still active; do not recover a running operation.' }
        foreach ($extension in @('.json', '.lock')) {
            $path = Join-Path $Root ($Id + $extension)
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
        }
    }
    finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
}

function Get-SkillRuntimeResources {
    param([Parameter(Mandatory = $true)][string]$SkillPath)
    $pending = [Collections.Generic.Queue[string]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $pending.Enqueue($SkillPath)
    while ($pending.Count) {
        $directory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($pending.Dequeue())
        $resource = ConvertTo-SkillOwnershipResource ([pscustomobject]@{ kind = 'runtime'; path = $directory; mode = 'Read' })
        if (-not $seen.Add($resource.path)) { continue }
        $resource
        $manifestPath = Join-Path $directory 'skill.json'
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Runtime manifest is missing: $manifestPath" }
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $parent = Split-Path -Parent $directory
        $repository = Split-Path -Parent (Split-Path -Parent $parent)
        $catalogPath = Join-Path $repository 'catalog.json'
        $catalog = if (Test-Path -LiteralPath $catalogPath -PathType Leaf) { @(Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json) } else { @() }
        $sourceEntry = @($catalog | Where-Object { $_.name -ceq $manifest.name })
        if ($sourceEntry.Count -ne 1 -or (ConvertTo-SkillOwnershipResource @{ kind = 'runtime'; path = (Join-Path $repository $sourceEntry[0].path); mode = 'Read' }).path -cne $resource.path) { $catalog = @() }
        foreach ($dependency in @($manifest.dependencies | Where-Object { $null -ne $_ })) {
            if ($dependency -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { throw 'Invalid runtime dependency name.' }
            $candidate = Join-Path $parent $dependency
            if (Test-Path -LiteralPath (Join-Path $candidate 'skill.json') -PathType Leaf) { $pending.Enqueue($candidate); continue }
            $candidateResource = ConvertTo-SkillOwnershipResource ([pscustomobject]@{ kind = 'runtime'; path = $candidate; mode = 'Read' })
            $claims = @(Read-SkillOwnershipClaims (Get-SkillOwnershipRoot))
            if (@($claims.resources | Where-Object { $_.kind -ceq 'runtime' -and $_.path -ceq $candidateResource.path }).Count) {
                $candidateResource
                continue
            }
            $entries = @($catalog | Where-Object { $_.name -ceq $dependency })
            if ($entries.Count -eq 1) {
                if ($entries[0].path -cnotmatch ('^skills/[a-z0-9-]+/' + [regex]::Escape($dependency) + '$')) { throw 'Invalid runtime dependency source path.' }
                $pending.Enqueue((Join-Path $repository $entries[0].path))
            }
        }
    }
}

function Assert-SkillOwnershipLease {
    param($Lease, [string[]]$Paths)
    if (-not $Lease -or $Lease.stream -isnot [IO.FileStream] -or -not $Lease.stream.CanRead) { throw 'An active ownership reservation is required.' }
    $claim = Get-Content -LiteralPath (Join-Path $Lease.root ($Lease.id + '.json')) -Raw | ConvertFrom-Json
    if ($claim.processId -ne $PID) { throw 'An ownership reservation belongs to another process.' }
    foreach ($path in $Paths) {
        $resource = ConvertTo-SkillOwnershipResource ([pscustomobject]@{ kind = 'runtime'; path = $path; mode = 'Write' })
        if (-not @($claim.resources | Where-Object { $_.kind -ceq 'runtime' -and $_.mode -ceq 'Write' -and $_.path -ceq $resource.path }).Count) { throw "Update is outside its reserved target set: $path" }
    }
}

function Enter-SkillUpdateOwnership {
    param([Parameter(Mandatory = $true)][string[]]$Paths, [switch]$ConfirmStopped)
    $resources = @($Paths | ForEach-Object { [pscustomobject]@{ kind = 'runtime'; path = $_; mode = 'Write' } })
    $lease = Enter-SkillOwnership -Resources $resources -Owner ([pscustomobject]@{ operation = 'skill update'; targets = $Paths })
    try {
        $normalized = @($resources | ForEach-Object { (ConvertTo-SkillOwnershipResource $_).path })
        $legacy = @()
        foreach ($root in @($Paths | ForEach-Object { Split-Path -Parent $_ } | Sort-Object -Unique)) {
            if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
            foreach ($directory in Get-ChildItem -LiteralPath $root -Directory -Force) {
                if ($directory.Name -like '.skillvault-*') { continue }
                $manifestPath = Join-Path $directory.FullName 'skill.json'
                if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { continue }
                $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
                if ($manifest.name -cnotin @('harness', 'harness-init', 'harness-root', 'harness-timer', 'pr-review', 'pr-review-timer', 'skillvault-refresh', 'skillvault-fresh', 'sv-refresh') -or $manifest.ownershipProtocol -eq 1) { continue }
                $used = @(Get-SkillRuntimeResources $directory.FullName)
                if (@($used | Where-Object { $_.path -cin $normalized }).Count) { $legacy += $directory.FullName }
            }
        }
        if ($legacy.Count -and -not $ConfirmStopped) {
            throw (New-SkillOwnershipFailure NeedsTransition ('Older runtimes cannot report ownership: ' + ($legacy -join ', ') + '. Use an attended transition with ConfirmStopped after stopping workers and preventing restarts; temporary originals protect the in-progress replacement only.'))
        }
        $lease | Add-Member -NotePropertyName legacyTransition -NotePropertyValue ([bool]$legacy.Count)
        $lease
    }
    catch { Exit-SkillOwnership $lease; throw }
}

function Get-SkillRuntimeCompatibility {
    param([string]$SkillPath, [object[]]$Resources, [string]$Interface, [int]$Version = 1, [string]$Consumer = 'caller')
    if (-not $Resources) { $Resources = @(Get-SkillRuntimeResources $SkillPath) }
    $bundles = @(foreach ($resource in @($Resources | Where-Object { $_.kind -ceq 'runtime' })) {
        $path = Join-Path $resource.path 'skill.json'
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            [pscustomobject]@{ path = $resource.path; manifest = (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) }
        }
    })
    $issues = [Collections.Generic.List[object]]::new()
    if ($Interface) {
        $root = (ConvertTo-SkillOwnershipResource @{ kind = 'runtime'; path = $SkillPath; mode = 'Read' }).path
        $provider = @($bundles | Where-Object { $_.path -ceq $root })
        $actual = if ($provider.Count -eq 1) { $provider[0].manifest.runtimeInterfaces.$Interface } else { $null }
        if (($actual -isnot [int] -and $actual -isnot [long]) -or $actual -ne $Version) {
            $issues.Add([pscustomobject]@{ consumer = $Consumer; dependency = $(if ($provider.Count -eq 1) { $provider[0].manifest.name } else { Split-Path -Leaf $SkillPath }); interface = $Interface; required = $Version; provided = $actual })
        }
    }
    foreach ($bundle in $bundles) {
        $manifest = $bundle.manifest
        foreach ($field in @('runtimeInterfaces', 'requiredInterfaces')) {
            if ($null -ne $manifest.$field -and $manifest.$field -isnot [pscustomobject]) { throw "Invalid $field in runtime '$($manifest.name)'." }
        }
        foreach ($provided in @($manifest.runtimeInterfaces.PSObject.Properties | Where-Object { $null -ne $_ })) {
            if ($provided.Name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -or ($provided.Value -isnot [int] -and $provided.Value -isnot [long]) -or $provided.Value -lt 1) { throw "Invalid provided interface in runtime '$($manifest.name)'." }
        }
        foreach ($dependency in @($manifest.requiredInterfaces.PSObject.Properties | Where-Object { $null -ne $_ })) {
            if ($dependency.Name -cnotin @($manifest.dependencies) -or $dependency.Value -isnot [pscustomobject]) { throw "Interface requirements must name declared dependencies of '$($manifest.name)'." }
            $provider = @($bundles | Where-Object { $_.manifest.name -ceq $dependency.Name })
            foreach ($requirement in $dependency.Value.PSObject.Properties) {
                if ($requirement.Name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -or ($requirement.Value -isnot [int] -and $requirement.Value -isnot [long]) -or $requirement.Value -lt 1) { throw "Invalid required interface in runtime '$($manifest.name)'." }
                $actual = if ($provider.Count -eq 1) { $provider[0].manifest.runtimeInterfaces.($requirement.Name) } else { $null }
                if (($actual -isnot [int] -and $actual -isnot [long]) -or $actual -ne $requirement.Value) {
                    $issues.Add([pscustomobject]@{ consumer = $manifest.name; dependency = $dependency.Name; interface = $requirement.Name; required = $requirement.Value; provided = $actual })
                }
            }
        }
    }
    [pscustomobject]@{ compatible = ($issues.Count -eq 0); issues = @($issues); requiredUpdates = @(@($issues.consumer) + @($issues.dependency) | Where-Object { $_ } | Sort-Object -Unique) }
}

function Assert-SkillRuntimeCompatibility {
    param([string]$SkillPath, [object[]]$Resources, [string]$Interface, [int]$Version = 1, [string]$Consumer = 'caller')
    $result = Get-SkillRuntimeCompatibility -SkillPath $SkillPath -Resources $Resources -Interface $Interface -Version $Version -Consumer $Consumer
    if (-not $result.compatible) {
        $details = @($result.issues | ForEach-Object { "$($_.consumer) requires $($_.dependency)/$($_.interface) v$($_.required), found '$($_.provided)'" }) -join '; '
        $failure = [InvalidOperationException]::new("Incompatible runtime interfaces. Install a compatible update set: $($result.requiredUpdates -join ', '). $details")
        $failure.Data['SkillRuntimeStatus'] = 'Incompatible'
        $failure.Data['SkillRuntimeRequiredUpdates'] = $result.requiredUpdates
        $failure.Data['SkillRuntimeIssues'] = $result.issues
        throw $failure
    }
}

function Enter-SkillRuntimeOwnership {
    param([Parameter(Mandatory = $true)][string]$SkillPath, [Parameter(Mandatory = $true)]$Owner, [object[]]$Resources = @(),
        [ValidateSet(1)][int]$InterfaceVersion = 1, [string]$RequiredInterface, [int]$RequiredVersion = 1, [string]$Consumer = 'caller')
    $root = Get-SkillOwnershipRoot
    $mutex = Enter-SkillOwnershipRegistry $root
    $lease = $null
    try {
        $runtime = @(Get-SkillRuntimeResources $SkillPath)
        $lease = Enter-SkillOwnership -Resources ($runtime + $Resources) -Owner $Owner -Root $root
        Assert-SkillRuntimeCompatibility -SkillPath $SkillPath -Resources $runtime -Interface $RequiredInterface -Version $RequiredVersion -Consumer $Consumer
        $lease
    }
    catch { Exit-SkillOwnership $lease; throw }
    finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
}