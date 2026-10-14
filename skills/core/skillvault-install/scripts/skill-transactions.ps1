function Get-SkillTransactionRoot {
    param([string]$InstallationRoot)
    $root = if ($env:SKILLVAULT_TRANSACTION_ROOT) { $env:SKILLVAULT_TRANSACTION_ROOT } else { Join-Path ([IO.Path]::GetTempPath()) 'skillvault-updates' }
    $root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($root).TrimEnd([char[]]'\/')
    $null = ConvertTo-SkillOwnershipResource @{ kind = 'runtime'; path = $root; mode = 'Write' }
    if ($root -match '[\\/](\.github|\.agents|\.claude|\.copilot)[\\/]skills([\\/]|$)') { throw 'Temporary update storage must be outside skill discovery.' }
    if ($InstallationRoot) {
        $installed = [IO.Path]::GetFullPath($InstallationRoot).TrimEnd([char[]]'\/')
        if ($root -eq $installed -or $root.StartsWith($installed + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Temporary update storage must be outside the installation root.' }
    }
    $root
}

function Write-SkillTransactionJson {
    param([string]$Path, $Value)
    $temporary = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temporary, ($Value | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    }
    finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
}

function New-SkillUpdateTransaction {
    param([Parameter(Mandatory = $true)][object[]]$Targets)
    if (-not $Targets.Count) { throw 'An update transaction requires existing targets.' }
    $root = Get-SkillTransactionRoot
    $entries = @()
    $payloads = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($target in $Targets) {
        $null = Get-SkillTransactionRoot -InstallationRoot (Split-Path -Parent $target.target)
        $payload = if ($target.payload) { [string]$target.payload } else { [string]$target.name }
        if ($payload -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -or -not $payloads.Add($payload) -or
            -not [IO.Path]::IsPathRooted([string]$target.target)) { throw 'Update targets require unique payload names and absolute installation paths.' }
        $source = [IO.Path]::GetFullPath($target.path).TrimEnd([char[]]'\/')
        if ($source -eq $root -or $root.StartsWith($source + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Temporary storage cannot be inside the original bundle.' }
        $null = @(Get-SkillFiles -SkillPath $source -Complete)
        $entries += [pscustomobject]@{ name = $target.name; target = [IO.Path]::GetFullPath($target.target); payload = $payload; verified = $false }
    }
    $id = [guid]::NewGuid().ToString('N')
    $path = Join-Path $root ('update-' + $id)
    $record = [pscustomobject]@{ schemaVersion = 1; kind = 'SkillVaultUpdateTransaction'; id = $id; status = 'Prepared'; entries = $entries }
    try {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        for ($index = 0; $index -lt $Targets.Count; $index++) {
            $destination = Join-Path $path $entries[$index].payload
            Copy-Item -LiteralPath $Targets[$index].path -Destination $destination -Recurse -Force
            if (-not (Test-SkillContentEqual -Source $Targets[$index].path -Target $destination -Complete)) { throw 'Temporary rollback copy did not verify; original installation is unchanged.' }
            $entries[$index].verified = $true
        }
        Write-SkillTransactionJson (Join-Path $path 'transaction.json') $record
        [pscustomobject]@{ path = $path; record = $record }
    }
    catch {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
        throw
    }
}

function Complete-SkillUpdateTransaction {
    param($Transaction)
    if (-not $Transaction) { return }
    $root = Get-SkillTransactionRoot
    if ((Split-Path -Parent $Transaction.path) -ne $root -or (Split-Path -Leaf $Transaction.path) -cne ('update-' + $Transaction.record.id)) { throw 'Invalid temporary transaction path.' }
    $null = @(Get-SkillFiles -SkillPath $Transaction.path -Complete)
    Remove-Item -LiteralPath $Transaction.path -Recurse -Force -ErrorAction Stop
    try { [IO.Directory]::Delete($root, $false) }
    catch [IO.IOException] { }
}

function Restore-SkillUpdateTransaction {
    param($Transaction)
    if (-not $Transaction) { return }
    try {
        foreach ($entry in $Transaction.record.entries) {
            $original = Join-Path $Transaction.path $entry.payload
            if (-not $entry.verified -or -not (Test-Path -LiteralPath $original -PathType Container)) { throw 'Verified rollback content is unavailable.' }
            if (Test-SkillContentEqual -Source $original -Target $entry.target -Complete) { continue }
            if (Test-Path -LiteralPath $entry.target) {
                $null = @(Get-SkillFiles -SkillPath $entry.target -Complete)
                Remove-Item -LiteralPath $entry.target -Recurse -Force
            }
            Copy-Item -LiteralPath $original -Destination $entry.target -Recurse -Force
            if (-not (Test-SkillContentEqual -Source $original -Target $entry.target -Complete)) { throw 'Restored installation did not verify.' }
        }
    }
    catch {
        $Transaction.record.status = 'RollbackFailed'
        Write-SkillTransactionJson (Join-Path $Transaction.path 'transaction.json') $Transaction.record
        throw "Update rollback failed. Original files remain temporarily at $($Transaction.path). Resolve this interrupted update before discarding them. $($_.Exception.Message)"
    }
    Complete-SkillUpdateTransaction $Transaction
}