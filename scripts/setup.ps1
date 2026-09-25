[CmdletBinding()]
param(
    [string]$Revision = 'main',
    [string]$GlobalSkillsPath = (Join-Path $HOME '.copilot/skills'),
    [switch]$Force,
    [switch]$NonInteractive
)

function Read-SetupResponse {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        $RawUI = $Host.UI.RawUI,
        $Clock = [System.Diagnostics.Stopwatch]::StartNew()
    )

    Write-Host "$Prompt (30 seconds idle to skip): " -NoNewline
    $response = New-Object System.Text.StringBuilder
    while ($Clock.Elapsed.TotalSeconds -lt 30) {
        try {
            if (-not $RawUI.KeyAvailable) {
                [System.Threading.Thread]::Sleep(50)
                continue
            }
            $key = $RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
        catch {
            Write-Host "`nOptional setup skipped: interactive input is unavailable."
            return $null
        }
        $Clock.Restart()
        if ($key.VirtualKeyCode -eq 13) {
            Write-Host ''
            return $response.ToString()
        }
        if ($key.VirtualKeyCode -eq 27) {
            Write-Host "`nOptional setup cancelled."
            return $null
        }
        if ($key.VirtualKeyCode -eq 8) {
            if ($response.Length -gt 0) {
                [void]$response.Remove($response.Length - 1, 1)
                Write-Host "`b `b" -NoNewline
            }
        }
        elseif (-not [char]::IsControl($key.Character)) {
            [void]$response.Append($key.Character)
            Write-Host $key.Character -NoNewline
        }
    }
    Write-Host "`nOptional setup skipped after 30 seconds without input."
    return $null
}

function Save-SetupFile {
    param(
        [string]$Root,
        [string]$Revision,
        [string]$RelativePath,
        [object[]]$Tree,
        [System.Collections.Generic.HashSet[string]]$Downloaded
    )

    if ($Downloaded.Contains($RelativePath)) { return }
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        $RelativePath -match '^/|/$|//|[\\:*?"<>|\x00-\x1f]|(^|/)\.{1,2}(/|$)') {
        throw "Unsafe download path: $RelativePath"
    }
    $matches = @($Tree | Where-Object { $_.path -ceq $RelativePath })
    if ($matches.Count -ne 1 -or $matches[0].type -cne 'blob' -or $matches[0].mode -cnotin @('100644', '100755')) {
        throw "Required resource must be exactly one regular file: $RelativePath"
    }
    $target = Join-Path $Root $RelativePath
    if (Test-Path -LiteralPath $target) { throw "Download paths collide: $RelativePath" }
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    $encodedPath = ($RelativePath.Split('/') | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/wzlwit/skillvault/$Revision/$encodedPath" -OutFile $target -ErrorAction Stop
    [void]$Downloaded.Add($RelativePath)
}

function Request-SetupClone {
    $answer = Read-SetupResponse -Prompt 'Clone SkillVault locally? [y/N]'
    if ([string]::IsNullOrWhiteSpace($answer) -or $answer.Trim() -notmatch '^y(es)?$') { return }

    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $gitCommand) {
        Write-Warning 'Skills are installed. Install Git before cloning the repository.'
        return
    }
    $destination = Read-SetupResponse -Prompt 'Clone destination (new folder; Enter skips)'
    if ([string]::IsNullOrWhiteSpace($destination)) { return }

    try {
        $destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($destination.Trim())
        if (Test-Path -LiteralPath $destination) {
            throw "Destination already exists; it was not changed: $destination"
        }
        & $gitCommand clone -- 'https://github.com/wzlwit/skillvault.git' $destination
        if ($LASTEXITCODE -ne 0) { throw "git clone failed with exit code $LASTEXITCODE." }
        Write-Output "Cloned SkillVault: $destination"

        $answer = Read-SetupResponse -Prompt 'Open the clone in VS Code? [y/N]'
        if ([string]::IsNullOrWhiteSpace($answer) -or $answer.Trim() -notmatch '^y(es)?$') { return }
        $codeCommand = Get-Command code -ErrorAction SilentlyContinue
        if ($null -eq $codeCommand) {
            Write-Warning "VS Code's code command is unavailable. The clone remains at $destination."
            return
        }
        & $codeCommand --new-window $destination
        if ($LASTEXITCODE -ne 0) { throw "VS Code failed to open with exit code $LASTEXITCODE." }
    }
    catch { Write-Warning "Skills are installed; optional repository setup did not finish: $($_.Exception.Message)" }
}

function Test-SetupInteractive {
    return ($Host.Name -eq 'ConsoleHost' -and [Environment]::UserInteractive -and
        -not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected -and
        @([Environment]::GetCommandLineArgs() | Where-Object { $_ -like '-NonI*' }).Count -eq 0)
}

function Invoke-SkillVaultSetup {
    param(
        [string]$Revision,
        [string]$GlobalSkillsPath,
        [switch]$Force,
        [switch]$NonInteractive
    )

    $ErrorActionPreference = 'Stop'
    $api = 'https://api.github.com/repos/wzlwit/skillvault'
    $headers = @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'SkillVault-Setup' }
    $commit = Invoke-RestMethod -Uri "$api/commits/$([uri]::EscapeDataString($Revision))" -Headers $headers
    $resolvedRevision = [string]$commit.sha
    $treeRevision = [string]$commit.commit.tree.sha
    if ($resolvedRevision -cnotmatch '^[a-f0-9]{40}$' -or $treeRevision -cnotmatch '^[a-f0-9]{40}$' -or
        ($Revision -cmatch '^[a-f0-9]{40}$' -and $Revision -cne $resolvedRevision)) {
        throw 'GitHub did not return the requested repository revision.'
    }
    $tree = Invoke-RestMethod -Uri "$api/git/trees/${treeRevision}?recursive=1" -Headers $headers
    if ($tree.sha -cne $treeRevision -or $tree.truncated -ne $false -or $tree.tree -isnot [System.Array]) {
        throw 'GitHub did not return a complete file list; no installation was attempted.'
    }

    $downloadRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-setup-' + [guid]::NewGuid().ToString('N'))
    $downloaded = New-Object 'System.Collections.Generic.HashSet[string]'
    $downloadParameters = @{ Root = $downloadRoot; Revision = $resolvedRevision; Tree = $tree.tree; Downloaded = $downloaded }
    try {
        $helperPath = 'skills/core/skillvault-installation/scripts/skill-files.ps1'
        foreach ($path in @('scripts/bootstrap-skills.json', 'catalog.json', $helperPath, 'skills/core/skillvault-installation/scripts/skill-ownership.ps1', 'skills/core/skillvault-installation/scripts/skill-transactions.ps1')) {
            Save-SetupFile @downloadParameters -RelativePath $path
        }
        . (Join-Path $downloadRoot $helperPath)
        $names = @(Read-BootstrapSkillNames -RepositoryRoot $downloadRoot)
        $catalog = Get-Content -LiteralPath (Join-Path $downloadRoot 'catalog.json') -Raw | ConvertFrom-Json
        foreach ($name in $names) {
            $entries = @($catalog | Where-Object { $_.name -ceq $name })
            if ($entries.Count -ne 1) { throw "Bootstrap skill must occur exactly once in the catalog: $name" }
            $sourcePath = [string]$entries[0].path
            if ($sourcePath -cnotmatch ('^skills/[a-z0-9]+(-[a-z0-9]+)*/' + [regex]::Escape($name) + '$')) {
                throw "Unsafe catalog path for ${name}: $sourcePath"
            }
            $resources = @($tree.tree | Where-Object { $_.path.StartsWith($sourcePath + '/', [System.StringComparison]::Ordinal) })
            if ($resources.Count -eq 0) { throw "No resources found for bootstrap skill: $name" }
            foreach ($resource in $resources) {
                if ($resource.type -ceq 'tree' -and $resource.mode -ceq '040000') { continue }
                Save-SetupFile @downloadParameters -RelativePath $resource.path
            }
        }
        Save-SetupFile @downloadParameters -RelativePath 'scripts/install-global.ps1'
        Write-Output "Downloaded $($downloaded.Count) required files at revision $resolvedRevision."
        & (Join-Path $downloadRoot 'scripts/install-global.ps1') -RepoRoot $downloadRoot -GlobalSkillsPath $GlobalSkillsPath -Force:$Force
    }
    finally {
        if (Test-Path -LiteralPath $downloadRoot) { Remove-Item -LiteralPath $downloadRoot -Recurse -Force }
    }

    if (-not $NonInteractive -and (Test-SetupInteractive)) { Request-SetupClone }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-SkillVaultSetup -Revision $Revision -GlobalSkillsPath $GlobalSkillsPath -Force:$Force -NonInteractive:$NonInteractive
}