[CmdletBinding()]
param(
    [string]$ProjectPath = (Get-Location).ProviderPath,
    [string]$RepoPath,
    [string]$KnownRepoPath = $(if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { 'C:\repos\skillvault' }),
    [string]$CachePath = (Join-Path $HOME '.copilot/skillvault-src'),
    [ValidateSet('Install', 'Upsert')][string]$Mode = 'Install'
)

$ErrorActionPreference = 'Stop'
$projectItem = Get-Item -LiteralPath $ProjectPath
if ($projectItem -isnot [System.IO.DirectoryInfo]) { throw 'ProjectPath must be an existing filesystem directory.' }
$projectRoot = $projectItem.FullName
$pathComparison = [StringComparison]::Ordinal
if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { $pathComparison = [StringComparison]::OrdinalIgnoreCase }

function Get-SourceCandidatePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'A source repository path cannot be empty.' }
    if (-not [System.IO.Path]::IsPathRooted($Path)) { $Path = Join-Path $projectRoot $Path }
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

function Invoke-SourceGit {
    param([string]$Path, [string[]]$GitArguments)
    $gitCommand = Get-Command git -CommandType Application -ErrorAction Stop
    $ErrorActionPreference = 'Continue'
    $output = @(& $gitCommand.Source -C $Path @GitArguments 2>$null)
    if ($LASTEXITCODE -ne 0) { throw "Cannot verify SkillVault checkout at '$Path': Git $($GitArguments[0]) failed." }
    return $output
}

function Get-VerifiedSourceRoot {
    param([string]$Path)
    $candidatePath = Get-SourceCandidatePath -Path $Path
    if (-not (Test-Path -LiteralPath $candidatePath -PathType Container)) {
        throw "Source repository directory does not exist: $candidatePath"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $candidatePath 'catalog.json') -PathType Leaf) -or
        -not (Test-Path -LiteralPath (Join-Path $candidatePath 'skills') -PathType Container)) {
        throw "Source repository lacks catalog.json or skills: $candidatePath"
    }

    $gitRoots = @(Invoke-SourceGit -Path $candidatePath -GitArguments @('rev-parse', '--show-toplevel'))
    if ($gitRoots.Count -ne 1) { throw "Cannot determine one Git root for source repository: $candidatePath" }
    $gitRoot = [System.IO.Path]::GetFullPath([string]$gitRoots[0]).TrimEnd([char[]]'\/')
    $candidatePath = [System.IO.Path]::GetFullPath($candidatePath).TrimEnd([char[]]'\/')
    if (-not [string]::Equals($gitRoot, $candidatePath, $pathComparison)) {
        throw "Source path must be the Git checkout root, not a nested directory: $candidatePath"
    }

    $remoteUrls = @(Invoke-SourceGit -Path $candidatePath -GitArguments @('remote', 'get-url', '--all', 'origin'))
    $expectedRemote = '^(https://github\.com/wzlwit/skillvault(?:\.git)?/?|git@github\.com:wzlwit/skillvault(?:\.git)?|ssh://git@github\.com/wzlwit/skillvault(?:\.git)?/?)$'
    if ($remoteUrls.Count -ne 1 -or ([string]$remoteUrls[0]).Trim() -notmatch $expectedRemote) {
        throw "Source origin must identify github.com/wzlwit/skillvault: $candidatePath"
    }
    return $gitRoot
}

$repositoryRoot = $null
$selection = $null
$skippedWorkspace = $null

if ($PSBoundParameters.ContainsKey('RepoPath')) {
    $repositoryRoot = Get-VerifiedSourceRoot -Path $RepoPath
    $selection = 'Explicit'
}
elseif ($Mode -eq 'Install') {
    if (-not [string]::IsNullOrWhiteSpace($KnownRepoPath)) {
        $candidatePath = Get-SourceCandidatePath -Path $KnownRepoPath
        if (Test-Path -LiteralPath $candidatePath) {
            $repositoryRoot = Get-VerifiedSourceRoot -Path $candidatePath
            $selection = 'KnownCheckout'
        }
    }
}
else {
    if ((Test-Path -LiteralPath (Join-Path $projectRoot 'catalog.json') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $projectRoot 'skills') -PathType Container)) {
        try {
            $repositoryRoot = Get-VerifiedSourceRoot -Path $projectRoot
            $selection = 'Workspace'
        }
        catch { $skippedWorkspace = $_.Exception.Message }
    }
    foreach ($candidate in @(
        @{ Path = $KnownRepoPath; Selection = 'KnownCheckout' },
        @{ Path = $CachePath; Selection = 'Cache' }
    )) {
        if ($repositoryRoot) { break }
        if ([string]::IsNullOrWhiteSpace($candidate.Path)) { continue }
        $candidatePath = Get-SourceCandidatePath -Path $candidate.Path
        if (-not (Test-Path -LiteralPath $candidatePath)) { continue }
        $repositoryRoot = Get-VerifiedSourceRoot -Path $candidatePath
        $selection = $candidate.Selection
    }
}

[pscustomobject]@{
    Status = if ($repositoryRoot) { 'Resolved' } else { 'NeedsSource' }
    Selection = $selection
    RepoRoot = $repositoryRoot
    CatalogPath = if ($repositoryRoot) { Join-Path $repositoryRoot 'catalog.json' } else { $null }
    SkillsPath = if ($repositoryRoot) { Join-Path $repositoryRoot 'skills' } else { $null }
    ProjectPath = $projectRoot
    SkippedWorkspace = $skippedWorkspace
}