[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).ProviderPath,
    [string]$RepoPath,
    [string]$KnownRepoPath = $(if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { 'C:\repos\skillvault' }),
    [string]$CachePath = (Join-Path $HOME '.copilot/skillvault-src')
)

$ErrorActionPreference = 'Stop'
$resolverPath = Join-Path $PSScriptRoot '../../skillvault-installation/scripts/resolve-source-repo.ps1'
& $resolverPath -Mode Upsert @PSBoundParameters