param(
    [ValidateSet('Review', 'Add', 'Remove', 'List', 'Configure', 'Timer')][string]$Action = 'Review',
    [string]$Url,
    [string]$Selector,
    [ValidateRange(1, 100)][int]$Limit = 5,
    [switch]$IncludeDrafts,
    [switch]$Again,
    [switch]$Scheduled,
    [switch]$SecurityReview,
    [string]$DefinitionPath,
    [switch]$Apply,
    [ValidateSet('Status', 'Set', 'Disable', 'Resume')][string]$TimerAction = 'Set',
    [Nullable[double]]$IntervalDays,
    [string]$DataRoot = (Join-Path $HOME '.copilot/pr-review')
)

. (Join-Path $PSScriptRoot 'pr-review-core.ps1')
. (Join-Path $PSScriptRoot 'pr-review-runner.ps1')
$paths = Get-PrReviewPaths $DataRoot
if ($Scheduled -and $Action -cne 'Review') { throw 'A recurring tick can only review the saved list.' }
switch ($Action) {
    'List' { Get-PrReviewList $paths | ConvertTo-Json -Depth 20 }
    'Add' {
        $options = @{}
        foreach ($name in @('Limit', 'IncludeDrafts')) { if ($PSBoundParameters.ContainsKey($name)) { $options[$name] = $PSBoundParameters[$name] } }
        Add-PrReviewWatch $paths $Url @options | ConvertTo-Json -Depth 10
    }
    'Remove' { Remove-PrReviewWatch $paths $Selector -Apply:$Apply | ConvertTo-Json -Depth 10 }
    'Configure' {
        if (-not $DefinitionPath) { throw 'Supply the approved configuration JSON file.' }
        $definition = Get-Content -LiteralPath $DefinitionPath -Raw | ConvertFrom-Json -NoEnumerate
        Set-PrReviewConfiguration $paths $definition -Apply:$Apply | ConvertTo-Json -Depth 20
    }
    'Review' { Invoke-PrReviewRun $paths -Url $Url -Limit $Limit -IncludeDrafts:$IncludeDrafts -Again:$Again -Scheduled:$Scheduled -SecurityReview:$SecurityReview | ConvertTo-Json -Depth 20 }
    'Timer' { Invoke-PrReviewTimer $paths -Action $TimerAction -IntervalDays $IntervalDays -Apply:$Apply -RunnerPath (Join-Path $PSScriptRoot 'pr-review.ps1') | ConvertTo-Json -Depth 15 }
}