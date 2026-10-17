param(
    [ValidateSet('Status', 'Check', 'Commit', 'Rebase', 'Push', 'Publish')][string]$Action = 'Status',
    [string]$RepositoryPath = (Get-Location).Path,
    [string]$Base,
    [string]$Title,
    [string]$BodyFile,
    [string]$TableFile,
    [string]$PreviousBodyFile,
    [string]$PlanFile,
    [string]$ExpectedRemoteHead,
    [switch]$Fetch,
    [switch]$Apply
)

. (Join-Path $PSScriptRoot 'pr-publish-core.ps1')
switch ($Action) {
    'Status' { Get-PrPublishStatus $RepositoryPath -Base $Base -Fetch:$Fetch | ConvertTo-Json -Depth 6 }
    'Check' { Invoke-PrPublishCheck $RepositoryPath -BodyFile $BodyFile -PreviousBodyFile $PreviousBodyFile -Base $Base | ConvertTo-Json -Depth 6 }
    'Commit' { Invoke-PrPublishCommit $RepositoryPath -PlanFile $PlanFile -Base $Base -Apply:$Apply | ConvertTo-Json -Depth 6 }
    'Rebase' { Invoke-PrPublishRebase $RepositoryPath -Base $Base -Apply:$Apply | ConvertTo-Json -Depth 6 }
    'Push' { Push-PrPublishBranch $RepositoryPath -Base $Base -ExpectedRemoteHead $ExpectedRemoteHead -Apply:$Apply | ConvertTo-Json -Depth 6 }
    'Publish' { Publish-PrPublishPullRequest $RepositoryPath -Title $Title -BodyFile $BodyFile -TableFile $TableFile -Base $Base -Apply:$Apply | ConvertTo-Json -Depth 6 }
}
