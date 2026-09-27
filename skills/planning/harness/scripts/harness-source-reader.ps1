param(
    [Parameter(Mandatory = $true)][string]$DefinitionJson,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$RestrictionsJson = '{}'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'harness-store.ps1')
. (Join-Path $PSScriptRoot 'harness-runner.ps1')
. (Join-Path $PSScriptRoot 'harness-monitor.ps1')
try {
    $definition = $DefinitionJson | ConvertFrom-Json -NoEnumerate
    $config = $RestrictionsJson | ConvertFrom-Json -NoEnumerate
    Assert-HarnessMonitorSettings ([pscustomobject]@{ monitors = @($definition) })
    $observation = Read-HarnessDiscoverySource $definition $ProjectPath $config
    [pscustomobject]@{ succeeded = $true; observation = $observation } | ConvertTo-Json -Depth 15 -Compress
}
catch {
    $kind = Get-HarnessFailureKind $_
    [pscustomobject]@{
        succeeded = $false; failureKind = $kind
        reason = $(if ($kind -eq 'Restriction') { 'Discovery source violates declared restrictions.' } else { 'Discovery source could not be read completely. Check its path, adapter output, or ADO read authentication; no source payload or credential was logged.' })
    } | ConvertTo-Json -Compress
}