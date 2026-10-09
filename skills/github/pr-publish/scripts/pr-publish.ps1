param(
    [ValidateSet('Status', 'Check', 'Publish')][string]$Action = 'Status',
    [string]$RepositoryPath = (Get-Location).Path,
    [string]$Base,
    [string]$Title,
    [string]$BodyFile,
    [string]$TableFile,
    [string]$PreviousBodyFile,
    [switch]$Apply
)

. (Join-Path $PSScriptRoot 'pr-publish-core.ps1')
switch ($Action) {
    'Status' { Get-PrPublishStatus $RepositoryPath -Base $Base | ConvertTo-Json -Depth 6 }
    'Check' { Invoke-PrPublishCheck $RepositoryPath -BodyFile $BodyFile -PreviousBodyFile $PreviousBodyFile -Base $Base | ConvertTo-Json -Depth 6 }
    'Publish' { Publish-PrPublishPullRequest $RepositoryPath -Title $Title -BodyFile $BodyFile -TableFile $TableFile -Base $Base -Apply:$Apply | ConvertTo-Json -Depth 6 }
}
