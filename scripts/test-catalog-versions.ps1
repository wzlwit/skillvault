$ErrorActionPreference = 'Stop'

$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skillvault-version-test-' + [guid]::NewGuid().ToString('N'))
$validatorDirectory = Join-Path $fixtureRoot 'scripts'
$skillDirectory = Join-Path $fixtureRoot 'skills\public\testing\fixture'

try {
    New-Item -ItemType Directory -Path $validatorDirectory, $skillDirectory -Force | Out-Null
    $validatorPath = Join-Path $PSScriptRoot 'validate-catalog.ps1'
    "---`nname: fixture`ndescription: Catalog version fixture`n---`n# Fixture" |
        Set-Content -LiteralPath (Join-Path $skillDirectory 'SKILL.md') -Encoding utf8

    $cases = @(
        @{ Name = 'explicit null'; CatalogVersion = $null; ManifestVersion = $null; Valid = $true },
        @{ Name = 'matching release'; CatalogVersion = '1.0.0'; ManifestVersion = '1.0.0'; Valid = $true },
        @{ Name = 'missing catalog version'; OmitCatalogVersion = $true; Valid = $false },
        @{ Name = 'missing manifest version'; OmitManifestVersion = $true; Valid = $false },
        @{ Name = 'null versus release'; CatalogVersion = $null; ManifestVersion = '1.0.0'; Valid = $false },
        @{ Name = 'release mismatch'; CatalogVersion = '1.0.0'; ManifestVersion = '2.0.0'; Valid = $false },
        @{ Name = 'empty string'; CatalogVersion = ''; ManifestVersion = ''; Valid = $false },
        @{ Name = 'numeric version'; CatalogVersion = 1; ManifestVersion = 1; Valid = $false }
    )

    foreach ($case in $cases) {
        $entry = [ordered]@{
            name = 'fixture'
            description = 'Catalog version fixture'
            path = 'skills/public/testing/fixture'
            version = $case.CatalogVersion
        }
        $manifest = [ordered]@{
            name = 'fixture'
            description = 'Catalog version fixture'
            version = $case.ManifestVersion
            install = @{ defaultScope = 'project' }
        }
        if ($case.OmitCatalogVersion) { $entry.Remove('version') }
        if ($case.OmitManifestVersion) { $manifest.Remove('version') }
        ConvertTo-Json -InputObject @($entry) -Depth 5 | Set-Content -LiteralPath (Join-Path $fixtureRoot 'catalog.json') -Encoding utf8
        $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $skillDirectory 'skill.json') -Encoding utf8

        $succeeded = $true
        try { & $validatorPath -RepoRoot $fixtureRoot | Out-Null }
        catch { $succeeded = $false }
        if ($succeeded -ne $case.Valid) { throw "Unexpected validation result for $($case.Name)" }
    }

    Write-Output 'Catalog version checks passed: explicit null and matching releases accepted; missing, empty, numeric, and mismatched versions rejected.'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}