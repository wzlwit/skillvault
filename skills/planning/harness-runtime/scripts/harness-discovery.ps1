function Get-HarnessDiscoveryDisposition {
    param([string]$Status)
    switch -Regex ($Status.Trim()) {
        '^(blocked\b|on[ -]hold\b.*\b(dependency|blocked|awaiting)\b)' { return 'Blocked' }
        '^(postponed|deferred|on[ -]hold)\b' { return 'Deferred' }
        '^(superseded|obsolete|cancelled|canceled|removed)\b' { return 'Superseded' }
        '^(done|closed|completed|fixed|resolved)\b' { return 'Resolved' }
        '^(open|active|new|unfixed|not fixed|in progress|pending)\b' { return 'Open' }
        default { return 'Unknown' }
    }
}

function Get-HarnessDiscoveryPriority {
    param($Value)
    if (($Value -is [int] -or $Value -is [long]) -and $Value -ge 1 -and $Value -le 5) { return [int]$Value }
    if ($Value -is [string] -and $Value.Trim() -match '^P?([1-5])\b') { return [int]$Matches[1] }
    $null
}

function Get-HarnessSourceOwner {
    param($Value)
    if ($Value -is [pscustomobject] -or $Value -is [Collections.IDictionary]) { $Value = $Value.displayName }
    if ($Value -isnot [string]) { return '' }
    $owner = $Value.Trim()
    if ($owner -match '^(?:unassigned|unknown|none|n/?a|tbd|not assigned|-)?$') { return '' }
    $owner
}

function Test-HarnessDiscoveryTopic {
    param([string]$Text, [string[]]$Topics)
    if (-not $Topics.Count) { return $true }
    foreach ($topic in $Topics) {
        if ([regex]::IsMatch($Text, '(?i)(?<![\p{L}\p{N}])' + [regex]::Escape($topic) + '(?![\p{L}\p{N}])')) { return $true }
    }
    $false
}

function Test-HarnessDiscoveryScope {
    param($Definition, [string]$Text, [string]$AreaPath)
    if (-not $Definition.scope) { return $true }
    if ($Definition.scope.terms.Count -and -not (Test-HarnessDiscoveryTopic $Text $Definition.scope.terms)) { return $false }
    if ($Definition.scope.areaPaths.Count) {
        foreach ($area in $Definition.scope.areaPaths) {
            if ($AreaPath -ceq $area -or $AreaPath.StartsWith($area.TrimEnd('\') + '\', [StringComparison]::Ordinal)) { return $true }
        }
        return $false
    }
    $true
}

function Assert-HarnessDiscoveryPath {
    param([string]$Path, $Config, [string]$ProjectPath)
    $fullPath = [IO.Path]::GetFullPath($Path)
    $parent = $fullPath
    while ($parent) {
        if (Test-Path -LiteralPath $parent) {
            $item = Get-Item -LiteralPath $parent -Force
            if ($item.LinkTarget -or $item.LinkType -in @('SymbolicLink', 'Junction')) { throw 'Discovery does not follow linked filesystem entries.' }
        }
        $parent = Split-Path -Parent $parent
    }
    if ($Config) { Assert-HarnessRestrictions -Config $Config -ProjectRoot $ProjectPath -Workspace $fullPath }
    $fullPath
}

function Read-HarnessFolderDiscovery {
    param($Definition, [string]$ProjectPath, $Config)
    $path = [string]$Definition.source.path
    if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $ProjectPath $path }
    $root = Assert-HarnessDiscoveryPath $path $Config $ProjectPath
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'The declared discovery folder is unavailable.' }
    $include = if ($null -ne $Definition.source.include) { @($Definition.source.include) } else { @('*.md', '*.txt') }
    $exclude = @($Definition.source.exclude | Where-Object { $_ })
    $pending = [Collections.Generic.Queue[string]]::new()
    $pending.Enqueue($root)
    $items = [Collections.Generic.List[object]]::new()
    $diagnostics = [ordered]@{ filesScanned = 0; sectionsReviewed = 0; matched = 0; excluded = 0; rejected = @() }
    while ($pending.Count) {
        $directory = $pending.Dequeue()
        foreach ($child in Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) {
            $relative = [IO.Path]::GetRelativePath($root, $child.FullName).Replace('\', '/')
            if (@($exclude | Where-Object { $relative -like $_ -or ($child.PSIsContainer -and ($relative + '/') -like $_) }).Count) { continue }
            $null = Assert-HarnessDiscoveryPath $child.FullName $Config $ProjectPath
            if ($child.PSIsContainer) { $pending.Enqueue($child.FullName); continue }
            if (-not @($include | Where-Object { $relative -like $_ }).Count) { continue }
            $diagnostics.filesScanned++
            $bytes = [IO.File]::ReadAllBytes($child.FullName)
            $stream = [IO.MemoryStream]::new($bytes, $false)
            $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $true)
            try { $text = $reader.ReadToEnd() }
            finally { $reader.Dispose() }
            if ([string]::IsNullOrWhiteSpace($text)) { continue }
            $hasher = [Security.Cryptography.SHA256]::Create()
            try { $revision = ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '') }
            finally { $hasher.Dispose() }
            if (-not (Test-HarnessDiscoveryTopic ($relative + "`n" + $text) $Definition.topics) -or -not (Test-HarnessDiscoveryScope $Definition ($relative + "`n" + $text) '')) {
                $diagnostics.excluded++; $diagnostics.rejected += [pscustomobject]@{ id = $relative; reason = 'Outside declared source prefilters; not semantically classified.' }; continue
            }
            $heading = [regex]::Match($text, '(?m)^#{1,6}\s+(.+?)\s*#*\s*$')
            $bodyStart = [regex]::Match($text, '(?m)^(?:#{2,6}\s|`{3,}|~{3,})')
            $header = if ($bodyStart.Success) { $text.Substring(0, $bodyStart.Index) } else { $text }
            $status = [regex]::Match($header, '(?im)^\s*(?:\*\*)?Status\s*:(?:\*\*)?\s*(.+)$')
            $priority = [regex]::Match($header, '(?im)^\s*(?:\*\*)?Priority\s*:(?:\*\*)?\s*(.+)$')
            $owners = @([regex]::Matches($header, '(?im)^\s*(?:[-+*]\s+)?(?:\*\*)?Owner(?:\*\*)?\s*:[ \t]*(?:\*\*)?[ \t]*([^\r\n]*)$') |
                ForEach-Object { Get-HarnessSourceOwner $_.Groups[1].Value } | Select-Object -Unique)
            $source = ([uri]$child.FullName).AbsoluteUri
            $sections = @([pscustomobject]@{ id = ''; title = $(if ($heading.Success) { $heading.Groups[1].Value.Trim() } else { $child.BaseName }); text = $text; context = ''; line = 1 })
            if ($Definition.source.granularity -ceq 'section') { $sections = @(Get-HarnessDocumentSections $text $sections[0].title) }
            foreach ($section in $sections) {
                $diagnostics.sectionsReviewed++
                $items.Add([pscustomobject]@{
                    id = $relative + $section.id; source = $source + $section.id; revision = $revision
                    title = $section.title; text = $section.context + "`n" + $section.text; disposition = Get-HarnessDiscoveryDisposition $status.Groups[1].Value
                    priority = Get-HarnessDiscoveryPriority $priority.Groups[1].Value; acceptance = ''; parentContext = $section.context; sourceLine = $section.line
                    sourceOwner = $(if ($owners.Count -eq 1) { $owners[0] } else { '' })
                })
            }
        }
    }
    $diagnostics.matched = $items.Count
    [pscustomobject]@{ schemaVersion = 1; observedAt = [datetimeoffset]::UtcNow.ToString('o'); complete = $true; items = @($items); diagnostics = [pscustomobject]$diagnostics }
}

function Get-HarnessDocumentSections {
    param([string]$Text, [string]$DocumentTitle)
    $null = ConvertFrom-Markdown -InputObject $Text
    $document = [Markdig.Markdown]::Parse($Text)
    $headings = @($document | Where-Object { $_.GetType().Name -ceq 'HeadingBlock' -and $_.Level -ge 2 })
    if (-not $headings.Count) { return [pscustomobject]@{ id = ''; title = $DocumentTitle; text = $Text; context = ''; line = 1 } }
    $identities = @{}
    $introduction = $Text.Substring(0, $headings[0].Span.Start)
    if (-not [string]::IsNullOrWhiteSpace($introduction)) {
        $identities['overview'] = 1
        [pscustomobject]@{ id = '#overview'; title = "$DocumentTitle / Overview"; text = $introduction; context = 'Owning context: ' + $DocumentTitle; line = 1 }
    }
    for ($index = 0; $index -lt $headings.Count; $index++) {
        $heading = $headings[$index]
        $headingText = [string]$heading.Inline
        $slug = ($headingText.ToLowerInvariant() -replace '[^\p{L}\p{N}]+', '-').Trim('-')
        if (-not $slug) { $slug = 'section' }
        $identities[$slug]++
        $identity = if ($identities[$slug] -eq 1) { $slug } else { $slug + '-' + $identities[$slug] }
        $end = $Text.Length
        for ($next = $index + 1; $next -lt $headings.Count; $next++) { if ($headings[$next].Level -le $heading.Level) { $end = $headings[$next].Span.Start; break } }
        if ($index + 1 -lt $headings.Count -and $headings[$index + 1].Level -gt $heading.Level) { $end = $headings[$index + 1].Span.Start }
        $sectionText = $Text.Substring($heading.Span.Start, $end - $heading.Span.Start)
        if ([string]::IsNullOrWhiteSpace($Text.Substring($heading.Span.End + 1, $end - $heading.Span.End - 1))) { continue }
        $parents = [Collections.Generic.List[string]]::new()
        $ancestorLevel = $heading.Level
        for ($previous = $index - 1; $previous -ge 0; $previous--) {
            if ($headings[$previous].Level -lt $ancestorLevel) { $parents.Insert(0, [string]$headings[$previous].Inline); $ancestorLevel = $headings[$previous].Level }
        }
        $parents.Insert(0, $DocumentTitle)
        [pscustomobject]@{ id = '#' + $identity; title = "$DocumentTitle / $headingText"; text = $sectionText; context = 'Owning context: ' + ($parents -join ' / '); line = $heading.Line + 1 }
    }
}

function Get-HarnessAdoSource {
    param([string]$Url)
    $uri = [uri]$Url
    if ($uri.Scheme -cne 'https' -or $uri.Host -ine 'dev.azure.com' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or -not $uri.IsDefaultPort) { throw 'Use an unambiguous dev.azure.com HTTPS source URL.' }
    $parts = @($uri.AbsolutePath.Trim('/').Split('/') | ForEach-Object { [uri]::UnescapeDataString($_) })
    if ($parts.Count -lt 5) { throw 'Use an ADO team backlog or saved-query URL.' }
    $base = 'https://dev.azure.com/' + [uri]::EscapeDataString($parts[0]) + '/' + [uri]::EscapeDataString($parts[1])
    if ($parts.Count -eq 6 -and $parts[2] -ceq '_backlogs' -and $parts[3] -ceq 'backlog') {
        return [pscustomobject]@{ kind = 'backlog'; base = $base; team = [uri]::EscapeDataString($parts[4]); backlog = $parts[5] }
    }
    $queryId = [guid]::Empty
    if ($parts.Count -eq 5 -and $parts[2] -ceq '_queries' -and $parts[3] -ceq 'query' -and [guid]::TryParse($parts[4], [ref]$queryId)) {
        return [pscustomobject]@{ kind = 'query'; base = $base; query = $queryId.ToString() }
    }
    throw 'Use an ADO team backlog or saved-query URL; arbitrary pages are not work-item sources.'
}

function Invoke-HarnessAdoRead {
    param($Source, [string]$Uri, $Body)
    $tokenVariable = if ($Source.tokenEnvironment) { $Source.tokenEnvironment } else { 'HARNESS_ADO_TOKEN' }
    $token = [Environment]::GetEnvironmentVariable($tokenVariable)
    if ([string]::IsNullOrWhiteSpace($token)) {
        $failure = [InvalidOperationException]::new("ADO read access requires an existing Entra bearer token in environment variable $tokenVariable. No sign-in or credentials are created by monitoring.")
        $failure.Data['HarnessFailureKind'] = 'Blocked'
        throw $failure
    }
    $options = @{
        Uri = $Uri; Method = 'Get'; Headers = @{ Authorization = 'Bearer ' + $token; Accept = 'application/json' }
        MaximumRedirection = 0; TimeoutSec = 60; ErrorAction = 'Stop'; ResponseHeadersVariable = 'responseHeaders'
    }
    if ($null -ne $Body) { $options.Method = 'Post'; $options.ContentType = 'application/json'; $options.Body = $Body | ConvertTo-Json -Depth 8 }
    try {
        $result = Invoke-RestMethod @options
        if ($responseHeaders['x-ms-continuationtoken']) { throw 'ADO returned continuation data; use an adapter that collects every page.' }
        $result
    }
    catch {
        $failure = [InvalidOperationException]::new('ADO collection did not return a complete readable result. Check access and source availability; credentials and server payloads are not logged.')
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -in @(401, 403)) { $failure.Data['HarnessFailureKind'] = 'Blocked' }
        throw $failure
    }
}

function Read-HarnessAdoDiscovery {
    param($Definition)
    Assert-HarnessDiscoveryMonitor $Definition
    $source = Get-HarnessAdoSource $Definition.source.url
    if ($source.kind -ceq 'backlog') {
        $levelsUri = "$($source.base)/$($source.team)/_apis/work/backlogs?api-version=7.1"
        $levels = Invoke-HarnessAdoRead $Definition.source $levelsUri
        $backlog = @($levels.value | Where-Object { $_.name -ceq $source.backlog -or $_.id -ceq $source.backlog })
        if ($backlog.Count -ne 1) { throw 'The requested ADO backlog level was not resolved exactly once.' }
        $backlogUri = "$($source.base)/$($source.team)/_apis/work/backlogs/$([uri]::EscapeDataString($backlog[0].id))/workItems?api-version=7.1"
        $listing = Invoke-HarnessAdoRead $Definition.source $backlogUri
        if ($listing.workItems -isnot [array]) { throw 'ADO backlog membership was not returned.' }
        $ids = @($listing.workItems | ForEach-Object { $_.target.id } | Sort-Object -Unique)
        if ($backlog[0].workItemCountLimit -and $ids.Count -ge $backlog[0].workItemCountLimit) { throw 'The ADO backlog reached its item limit; use a complete saved query or adapter instead of treating truncation as a full scan.' }
    }
    else {
        $listing = Invoke-HarnessAdoRead $Definition.source "$($source.base)/_apis/wit/wiql/$($source.query)?api-version=7.1"
        if ($listing.workItems -is [array]) { $ids = @($listing.workItems.id | Sort-Object -Unique) }
        elseif ($listing.workItemRelations -is [array]) { $ids = @(@($listing.workItemRelations.source.id) + @($listing.workItemRelations.target.id) | Where-Object { $null -ne $_ } | Sort-Object -Unique) }
        else { throw 'The ADO saved query did not return work-item membership.' }
    }
    if (@($ids | Where-Object { ($_ -isnot [int] -and $_ -isnot [long]) -or $_ -le 0 -or $_ -gt [int]::MaxValue }).Count) { throw 'ADO returned an invalid work-item identity.' }
    $items = [Collections.Generic.List[object]]::new()
    $pendingIds = [Collections.Generic.Queue[int]]::new()
    $seenIds = [Collections.Generic.HashSet[int]]::new()
    $records = @{}
    $parents = @{}
    $diagnostics = [ordered]@{ matched = 0; reviewed = 0; excluded = 0; terminal = 0; containers = 0; descendants = 0; rejected = @() }
    foreach ($identity in $ids) { if ($seenIds.Add([int]$identity)) { $pendingIds.Enqueue([int]$identity) } }
    while ($pendingIds.Count) {
        $batchList = [Collections.Generic.List[int]]::new()
        while ($pendingIds.Count -and $batchList.Count -lt 200) { $batchList.Add($pendingIds.Dequeue()) }
        $batch = @($batchList)
        $response = Invoke-HarnessAdoRead $Definition.source "$($source.base)/_apis/wit/workitemsbatch?api-version=7.1" @{ ids = $batch; errorPolicy = 'Fail'; '$expand' = 'Relations' }
        if ($response.value -isnot [array] -or $response.value.Count -ne $batch.Count -or
            @($batch | Where-Object { $_ -notin $response.value.id }).Count) { throw 'ADO did not return every selected work item.' }
        foreach ($workItem in $response.value) {
            $records[[string]$workItem.id] = $workItem
            $diagnostics.reviewed++
            $children = @($workItem.relations | Where-Object rel -CEQ 'System.LinkTypes.Hierarchy-Forward')
            if ($children.Count) { $diagnostics.containers++ }
            foreach ($relation in $children) {
                $childUri = $null
                $baseUri = [uri]$source.base
                if (-not [uri]::TryCreate([string]$relation.url, [UriKind]::Absolute, [ref]$childUri) -or $childUri.Scheme -cne 'https' -or
                    $childUri.Host -ine $baseUri.Host -or $childUri.UserInfo -or $childUri.Query -or $childUri.Fragment -or
                    $childUri.AbsolutePath -notmatch ('^' + [regex]::Escape($baseUri.AbsolutePath.Split('/')[0..1] -join '/') + '/(?:' + [regex]::Escape($baseUri.AbsolutePath.Split('/')[2]) + '/)?_apis/wit/workItems/(\d+)$')) { throw 'A hierarchy link leaves the declared ADO project or has an ambiguous identity.' }
                $childId = [int]$Matches[1]
                if (-not $parents.ContainsKey([string]$childId)) { $parents[[string]$childId] = @() }
                $parents[[string]$childId] = @($parents[[string]$childId] + @([string]$workItem.id) | Sort-Object -Unique)
                if ($seenIds.Add($childId)) { $pendingIds.Enqueue($childId); $diagnostics.descendants++ }
            }
        }
    }
    foreach ($workItem in @($records.Values | Sort-Object { [int]$_.id })) {
            $fields = $workItem.fields
            $parentContext = @($parents[[string]$workItem.id] | ForEach-Object { $parent = $records[[string]$_]; "Parent #$($parent.id): $($parent.fields.'System.Title')" }) -join "`n"
            $text = @($fields.'System.Title', $fields.'System.Description', $fields.'Microsoft.VSTS.Common.AcceptanceCriteria', $fields.'System.Tags', $fields.'System.AreaPath', $parentContext) -join "`n"
            if (-not (Test-HarnessDiscoveryTopic $text $Definition.topics) -or -not (Test-HarnessDiscoveryScope $Definition $text ([string]$fields.'System.AreaPath'))) {
                $diagnostics.excluded++; $diagnostics.rejected += [pscustomobject]@{ id = [string]$workItem.id; reason = 'Outside declared service prefilters.' }; continue
            }
            $disposition = Get-HarnessDiscoveryDisposition ([string]$fields.'System.State')
            $tags = @(([string]$fields.'System.Tags').Split(';') | ForEach-Object { $_.Trim() })
            if ($disposition -notin @('Resolved', 'Superseded', 'Blocked')) {
                if (@($tags | Where-Object { $_ -match '^blocked$' }).Count) { $disposition = 'Blocked' }
                elseif (@($tags | Where-Object { $_ -match '^(postponed|deferred|on[ -]hold)$' }).Count) { $disposition = 'Deferred' }
            }
            if ($disposition -in @('Resolved', 'Superseded')) { $diagnostics.terminal++ }
            $items.Add([pscustomobject]@{
                id = [string]$workItem.id; source = "$($source.base)/_workitems/edit/$($workItem.id)"; revision = [string]$workItem.rev
                title = [string]$fields.'System.Title'; text = $text
                areaPath = [string]$fields.'System.AreaPath'
                disposition = $disposition; priority = Get-HarnessDiscoveryPriority $fields.'Microsoft.VSTS.Common.Priority'
                sourceOwner = Get-HarnessSourceOwner $fields.'System.AssignedTo'
                acceptance = [string]$fields.'Microsoft.VSTS.Common.AcceptanceCriteria'; sourceState = [string]$fields.'System.State'; parentContext = $parentContext
                parentIds = @($parents[[string]$workItem.id]); isContainer = @($workItem.relations | Where-Object rel -CEQ 'System.LinkTypes.Hierarchy-Forward').Count -gt 0
            })
    }
    $diagnostics.matched = $items.Count
    [pscustomobject]@{ schemaVersion = 1; observedAt = [datetimeoffset]::UtcNow.ToString('o'); complete = $true; items = @($items); diagnostics = [pscustomobject]$diagnostics }
}

function Read-HarnessDiscoverySource {
    param($Definition, [string]$ProjectPath, $Config)
    switch ($Definition.source.type) {
        'folder' { Read-HarnessFolderDiscovery $Definition $ProjectPath $Config }
        'ado' { Read-HarnessAdoDiscovery $Definition }
        'json-feed' {
            $path = [string]$Definition.source.path
            if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $ProjectPath $path }
            $path = Assert-HarnessDiscoveryPath $path $Config $ProjectPath
            [IO.File]::ReadAllText($path) | ConvertFrom-Json -NoEnumerate -ErrorAction Stop
        }
        default { throw 'Unsupported discovery source.' }
    }
}

function ConvertTo-HarnessDiscoveryAssessment {
    param($Assessment, $Definition, [string]$Revision)
    if ($null -eq $Assessment) { return $null }
    $fields = @('candidateId', 'scope', 'sourceRevision', 'relevance', 'reason', 'priority', 'priorityReason', 'classification', 'category', 'blockers', 'independentConcern')
    if (-not $Definition.scope -or $Assessment -isnot [pscustomobject] -or
        @($Assessment.PSObject.Properties.Name | Where-Object { $_ -cnotin $fields }).Count) { throw 'Assessment requires a declared service scope and only assessment fields.' }
    if ($Assessment.scope -isnot [string] -or $Assessment.sourceRevision -isnot [string] -or
        $Assessment.scope -cne $Definition.scope.description -or $Assessment.sourceRevision -cne $Revision) { throw 'Assessment does not match the current scope and source revision.' }
    if ($Assessment.relevance -isnot [string] -or $Assessment.relevance -cnotin @('Relevant', 'NotRelevant', 'Uncertain') -or $Assessment.reason -isnot [string] -or
        [string]::IsNullOrWhiteSpace($Assessment.reason)) { throw 'Assessment requires a relevance decision and an evidence-based reason.' }
    if ($Assessment.relevance -ceq 'Relevant' -and
        (($Assessment.priority -isnot [int] -and $Assessment.priority -isnot [long]) -or $Assessment.priority -lt 1 -or $Assessment.priority -gt 5 -or
        $Assessment.priorityReason -isnot [string] -or [string]::IsNullOrWhiteSpace($Assessment.priorityReason))) { throw 'Relevant work requires assessed priority 1 through 5 and a priority reason.' }
    if ($Assessment.classification -and $Assessment.classification -cnotin @('Actionable', 'Deferred', 'Resolved', 'Informational', 'OutOfScope', 'Uncertain')) { throw 'Unsupported concern classification.' }
    if ($null -ne $Assessment.category -and $Assessment.category -isnot [string]) { throw 'Assessment category must be a string.' }
    if ($null -ne $Assessment.blockers -and ($Assessment.blockers -isnot [array] -or @($Assessment.blockers | Where-Object { $_ -isnot [string] }).Count)) { throw 'Assessment blockers must be an array of evidence-backed descriptions.' }
    $normalized = [pscustomobject]@{
        scope = $Assessment.scope; sourceRevision = $Revision; relevance = $Assessment.relevance
        reason = $Assessment.reason.Substring(0, [Math]::Min(4000, $Assessment.reason.Length))
        priority = $(if ($Assessment.relevance -ceq 'Relevant') { [int]$Assessment.priority } else { $null })
        priorityReason = $(if ($Assessment.relevance -ceq 'Relevant') { $Assessment.priorityReason.Substring(0, [Math]::Min(4000, $Assessment.priorityReason.Length)) } else { '' })
        classification = $(if ($Assessment.classification) { $Assessment.classification } elseif ($Assessment.relevance -ceq 'Relevant') { 'Actionable' } elseif ($Assessment.relevance -ceq 'NotRelevant') { 'OutOfScope' } else { 'Uncertain' })
        category = [string]$Assessment.category; blockers = @($Assessment.blockers | Where-Object { $_ }); independentConcern = ($Assessment.independentConcern -eq $true)
    }
    if ($normalized.category -and $normalized.category -cin @($Definition.scope.excludedCategories)) {
        $normalized.relevance = 'NotRelevant'; $normalized.classification = 'OutOfScope'
        $normalized.reason += ' Excluded by the declared category policy.'; $normalized.priority = $null
    }
    elseif ($normalized.relevance -ceq 'Relevant' -and $normalized.category -and $Definition.scope.priorityFloors.PSObject.Properties[$normalized.category]) {
        $floor = [int]$Definition.scope.priorityFloors.($normalized.category)
        if ($normalized.priority -lt $floor) { $normalized.priority = $floor; $normalized.priorityReason += " Declared category policy limits pickup to P$floor or below." }
    }
    $normalized
}

function Get-HarnessRequirementFingerprint {
    param([string]$Title, [string]$Text, [string]$Acceptance)
    $content = [ordered]@{ title = $Title.Trim(); text = $Text.Trim(); acceptance = $Acceptance.Trim() } | ConvertTo-Json -Compress
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($content)))).Replace('-', '') }
    finally { $hasher.Dispose() }
}

function Get-HarnessDiscoveryResult {
    param($Definition, $Observation, [datetimeoffset]$Now = [datetimeoffset]::UtcNow)
    $result = [pscustomobject]@{
        status = 'Blocked'; health = 'NotApplicable'; reason = ''; observedAt = ''; windowStart = ''; windowEnd = ''
        checkedAt = $Now.ToString('o'); items = @(); diagnostics = $null
    }
    try {
        if ($Observation -isnot [pscustomobject] -or ($Observation.schemaVersion -isnot [int] -and $Observation.schemaVersion -isnot [long]) -or $Observation.schemaVersion -ne 1 -or
            $Observation.complete -isnot [bool] -or -not $Observation.complete -or $Observation.items -isnot [array]) { throw 'Discovery requires a complete schemaVersion 1 item collection; partial results cannot reconcile candidates.' }
        $observedAt = ConvertTo-HarnessMonitorTime $Observation.observedAt
        if ($observedAt -gt $Now -or ($Now - $observedAt).TotalMinutes -gt $Definition.maxAgeMinutes) { throw 'Discovery evidence is stale or dated in the future.' }
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $items = [Collections.Generic.List[object]]::new()
        foreach ($item in $Observation.items) {
            if ($item -isnot [pscustomobject]) { throw 'Each discovered item must be an object.' }
            foreach ($field in @('id', 'source', 'revision', 'title', 'text', 'disposition')) {
                if ($item.$field -isnot [string] -or [string]::IsNullOrWhiteSpace($item.$field)) { throw "Discovery item $field must be a non-empty string." }
            }
            $uri = $null
            if (-not [uri]::TryCreate($item.source, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -notin @('https', 'file') -or $uri.UserInfo) { throw 'Discovery evidence requires an absolute HTTPS or file URI without credentials.' }
            if ($uri.Host -ieq 'dev.azure.com' -and -not $Definition.scope) { throw 'ADO evidence requires an explicit service scope, including adapter feeds.' }
            if (-not $seen.Add($item.id)) { throw 'Discovery item IDs must be unique within one source.' }
            if ($item.disposition -cnotin @('Open', 'Deferred', 'Blocked', 'Resolved', 'Superseded', 'Unknown')) { throw 'Unsupported discovery disposition.' }
            if ($null -ne $item.priority -and (($item.priority -isnot [int] -and $item.priority -isnot [long]) -or $item.priority -lt 1 -or $item.priority -gt 5)) { throw 'Discovery priority must be an integer from 1 through 5, or omitted.' }
            if ($null -ne $item.sourceOwner -and $item.sourceOwner -isnot [string]) { throw 'Discovery sourceOwner must be a display-name string, null, or omitted.' }
            foreach ($field in @('acceptance', 'sourceState', 'parentContext')) { if ($null -ne $item.$field -and $item.$field -isnot [string]) { throw "Discovery $field must be a string." } }
            if ($null -ne $item.isContainer -and $item.isContainer -isnot [bool]) { throw 'Discovery isContainer must be boolean.' }
            $sameRequirementAs = @(ConvertTo-HarnessRelatedSources $item.sameRequirementAs)
            $claims = @(ConvertTo-HarnessSourceClaims $item.claims $item.text)
            if (-not (Test-HarnessDiscoveryTopic ($item.id + "`n" + $item.title + "`n" + $item.text) $Definition.topics)) { continue }
            if (-not (Test-HarnessDiscoveryScope $Definition ($item.title + "`n" + $item.text) ([string]$item.areaPath))) { continue }
            $assessment = ConvertTo-HarnessDiscoveryAssessment $item.assessment $Definition $item.revision
            $items.Add([pscustomobject]@{
                id = $item.id; source = $uri.AbsoluteUri; revision = $item.revision; title = $item.title
                disposition = $item.disposition; priority = $item.priority; sourceOwner = Get-HarnessSourceOwner $item.sourceOwner
                assessment = $assessment; evidence = $item.text.Substring(0, [Math]::Min(4000, $item.text.Length))
                evidenceTruncated = $item.text.Length -gt 4000
                sameRequirementAs = $sameRequirementAs; claims = $claims
                acceptance = [string]$item.acceptance; sourceState = [string]$item.sourceState; parentContext = [string]$item.parentContext; parentIds = @($item.parentIds | Where-Object { $_ }); isContainer = [bool]$item.isContainer
                requirementFingerprint = Get-HarnessRequirementFingerprint $item.title $item.text ([string]$item.acceptance)
            })
        }
        $result.status = 'Succeeded'; $result.reason = 'Source collection completed; candidates require source review before task acceptance.'
        $result.observedAt = $observedAt.ToString('o'); $result.windowEnd = $result.observedAt; $result.items = @($items)
        if ($Observation.diagnostics) {
            $diagnostics = [ordered]@{}
            foreach ($field in @('filesScanned', 'sectionsReviewed', 'matched', 'reviewed', 'excluded', 'terminal', 'containers', 'descendants')) {
                $value = $Observation.diagnostics.$field
                if ($null -ne $value) {
                    if (($value -isnot [int] -and $value -isnot [long]) -or $value -lt 0) { throw 'Source diagnostics counts must be non-negative integers.' }
                    $diagnostics[$field] = $value
                }
            }
            $diagnostics.rejected = @($Observation.diagnostics.rejected | Where-Object { $_.id -is [string] -and $_.reason -is [string] } | Select-Object id, reason)
            $result.diagnostics = [pscustomobject]$diagnostics
        }
    }
    catch { $result.status = 'Blocked'; $result.reason = $_.Exception.Message }
    $result
}

function Register-HarnessDiscoveryObservation {
    param($State, $Definition, $Result, [string]$RunId, [string]$ReportPath)
    $monitoring = Get-HarnessMonitoringState $State
    if (-not $monitoring.PSObject.Properties['candidates']) { $monitoring | Add-Member -NotePropertyName candidates -NotePropertyValue @() }
    $previous = @($monitoring.latest | Where-Object monitor -CEQ $Definition.name) | Select-Object -First 1
    if ($Result.status -eq 'Succeeded' -and $previous.lastWindowEnd -and
        (ConvertTo-HarnessMonitorTime $Result.observedAt) -lt (ConvertTo-HarnessMonitorTime $previous.lastWindowEnd)) {
        $Result.status = 'Blocked'; $Result.reason = 'Discovery evidence predates the latest accepted collection.'
    }
    if ($Result.status -eq 'Succeeded') {
        foreach ($item in $Result.items) {
            $existing = @($monitoring.candidates | Where-Object { $_.monitor -ceq $Definition.name -and $_.sourceId -ceq $item.id }) | Select-Object -First 1
            if ($existing -and $existing.source -cne $item.source) {
                $Result.status = 'Blocked'; $Result.reason = 'A discovery adapter changed an existing item identity; use a new source item ID.'
                break
            }
        }
    }
    if ($Result.status -eq 'Succeeded') {
        foreach ($item in $Result.items) {
            $candidate = @($monitoring.candidates | Where-Object { $_.monitor -ceq $Definition.name -and $_.sourceId -ceq $item.id }) | Select-Object -First 1
            if (-not $candidate) {
                $candidate = [pscustomobject]@{
                    id = Get-HarnessNextId @($monitoring.candidates) 'C'; monitor = $Definition.name; sourceId = $item.id
                    source = $item.source; revision = ''; title = ''; disposition = 'Unknown'; evidence = ''
                    firstSeenAt = $Result.observedAt; lastSeenAt = ''; firstReport = $ReportPath; latestReport = ''; lastRunId = ''; taskId = ''; referenceId = ''
                }
                $monitoring.candidates = @($monitoring.candidates) + @($candidate)
            }
            if ($candidate.revision -cne $item.revision -or $null -ne $item.assessment) {
                $candidate | Add-Member -NotePropertyName assessment -NotePropertyValue $item.assessment -Force
            }
            if ($candidate.revision -cne $item.revision) { $candidate.PSObject.Properties.Remove('verification') }
            $candidate.revision = $item.revision; $candidate.title = $item.title; $candidate.disposition = $item.disposition
            $candidate | Add-Member -NotePropertyName priority -NotePropertyValue $item.priority -Force
            $candidate | Add-Member -NotePropertyName sourceOwner -NotePropertyValue (Get-HarnessSourceOwner $item.sourceOwner) -Force
            foreach ($field in @('acceptance', 'sourceState', 'parentContext', 'parentIds', 'isContainer', 'requirementFingerprint', 'evidenceTruncated', 'sameRequirementAs', 'claims')) { $candidate | Add-Member -NotePropertyName $field -NotePropertyValue $item.$field -Force }
            foreach ($linkedTask in @($State.tasks | Where-Object { $_.id -ceq $candidate.taskId -and $_.source -ceq $candidate.source })) {
                $linkedTask | Add-Member -NotePropertyName sourceOwner -NotePropertyValue $candidate.sourceOwner -Force
                $linkedTask | Add-Member -NotePropertyName sourceType -NotePropertyValue (Get-HarnessSourceType $Definition $candidate.source) -Force
            }
            $candidate.evidence = $item.evidence; $candidate.lastSeenAt = $Result.observedAt
            $candidate.latestReport = $ReportPath; $candidate.lastRunId = $RunId
        }
        foreach ($candidate in @($monitoring.candidates | Where-Object { $_.monitor -ceq $Definition.name -and $_.sourceId -cnotin @($Result.items.id) })) {
            $candidate.disposition = 'Missing'; $candidate.latestReport = $ReportPath; $candidate.lastRunId = $RunId
        }
    }
    $monitoring.latest = @($monitoring.latest | Where-Object monitor -CNE $Definition.name) + @([pscustomobject]@{
        monitor = $Definition.name; runId = $RunId; report = $ReportPath; result = $Result
        lastWindowEnd = $(if ($Result.status -eq 'Succeeded') { $Result.observedAt } else { $previous.lastWindowEnd })
    })
    foreach ($candidate in @($monitoring.candidates | Where-Object monitor -CEQ $Definition.name)) {
        $candidate | Add-Member -NotePropertyName evidenceStatus -NotePropertyValue $(if ($Result.status -ceq 'Succeeded' -and $candidate.disposition -cne 'Missing') { 'Current' } else { 'Uncertain' }) -Force
    }
    $State | Add-Member -NotePropertyName monitoring -NotePropertyValue $monitoring -Force
    @($monitoring.candidates | Where-Object monitor -CEQ $Definition.name)
}

function ConvertTo-HarnessRelatedSources {
    param($Sources)
    if ($null -eq $Sources) { return }
    if ($Sources -isnot [array]) { throw 'Same-requirement sources must be an array of explicit source URIs.' }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($source in $Sources) {
        $uri = $null
        if ($source -isnot [string] -or -not [uri]::TryCreate($source, [UriKind]::Absolute, [ref]$uri) -or
            $uri.Scheme -cnotin @('https', 'file') -or $uri.UserInfo) { throw 'A related source must be an absolute HTTPS or file URI without credentials.' }
        if ($seen.Add($uri.AbsoluteUri)) { $uri.AbsoluteUri }
    }
}

function ConvertTo-HarnessSourceClaims {
    param($Claims, [string]$Text)
    if ($null -eq $Claims) { return }
    if ($Claims -isnot [array]) { throw 'Source claims must be an array of named facts with exact evidence quotes.' }
    foreach ($claim in $Claims) {
        if ($claim -isnot [pscustomobject] -or @($claim.PSObject.Properties.Name | Where-Object { $_ -cnotin @('fact', 'value', 'quote') }).Count -or
            $claim.fact -cnotmatch '^(acceptance|requirements|completion)(\.[a-z0-9-]+)*$' -or
            $claim.value -isnot [string] -or [string]::IsNullOrWhiteSpace($claim.value) -or $claim.value.Length -gt 4000 -or
            $claim.quote -isnot [string] -or [string]::IsNullOrWhiteSpace($claim.quote) -or $claim.quote.Length -gt 4000 -or -not $Text.Contains($claim.quote) -or
            $claim.quote -match '^\s*(?:\*\*)?(?:Status|Owner)\b\s*:|^\s*(?:Open|Active|Closed|Done|Fixed|Resolved)\s*$') { throw 'Claims require a named acceptance, requirements, or completion fact and an exact substantive quote, not an owner or status label.' }
        [pscustomobject]@{ fact = $claim.fact; value = $claim.value.Trim(); quote = $claim.quote }
    }
}

function Get-HarnessDiscoveryCorrelation {
    param($Config, $State, $Candidate)
    $sources = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $null = $sources.Add([string]$Candidate.source)
    $edges = @(
        foreach ($item in $State.monitoring.candidates) { foreach ($related in $item.sameRequirementAs) { Write-Output -NoEnumerate @($item.source, $related) } }
        foreach ($declaration in $Config.monitoring.correlations) { Write-Output -NoEnumerate @($declaration.sources) }
    )
    do {
        $changed = $false
        foreach ($edge in $edges) {
            if (@($edge | Where-Object { $sources.Contains($_) }).Count) {
                foreach ($source in $edge) { if ($sources.Add($source)) { $changed = $true } }
            }
        }
    } while ($changed)
    $members = @($State.monitoring.candidates | Where-Object { $sources.Contains($_.source) } | Sort-Object id)
    $representative = @($members | Where-Object followUpOf | Select-Object -First 1)
    if (-not $representative.Count) { $representative = @($members | Where-Object taskId | Select-Object -First 1) }
    if (-not $representative.Count) { $representative = @($members | Select-Object -First 1) }
    $pending = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $conflicts = [Collections.Generic.List[object]]::new()
    $claims = [Collections.Generic.List[object]]::new()
    $authorities = [ordered]@{}
    foreach ($declaration in $Config.monitoring.correlations) {
        if (-not @($declaration.sources | Where-Object { $sources.Contains($_) }).Count) { continue }
        foreach ($authority in $declaration.authorities.PSObject.Properties) {
            if ($authorities.Contains($authority.Name) -and $authorities[$authority.Name] -cne $authority.Value) {
                $conflicts.Add([pscustomobject]@{ fact = $authority.Name; reason = 'Conflicting declared authorities.'; resolved = $false; claims = @() })
            }
            else { $authorities[$authority.Name] = $authority.Value }
        }
    }
    foreach ($source in $sources) { if (-not @($members | Where-Object source -CEQ $source).Count) { $null = $pending.Add($source) } }
    foreach ($member in $members) {
        $definition = @($Config.monitoring.monitors | Where-Object name -CEQ $member.monitor) | Select-Object -First 1
        $latest = @($State.monitoring.latest | Where-Object monitor -CEQ $member.monitor) | Select-Object -First 1
        $fresh = $definition -and $latest.result.status -ceq 'Succeeded' -and $member.evidenceStatus -cne 'Uncertain' -and $member.disposition -cne 'Missing' -and
            $member.lastSeenAt -and ([datetimeoffset]::UtcNow - [datetimeoffset]$member.lastSeenAt).TotalMinutes -le $definition.maxAgeMinutes
        $verified = $member.verification.sourceRevision -ceq $member.revision -and $member.verification.collectionRunId -ceq $member.lastRunId -and
            $member.verification.outcome -in @('open', 'already-fixed', 'stale')
        if (-not $fresh -or ($definition.verification.enabled -ne $false -and -not $verified)) { $null = $pending.Add($member.source) }
        foreach ($claim in $member.claims) { $claims.Add([pscustomobject]@{ source = $member.source; fact = $claim.fact; value = $claim.value; quote = $claim.quote; current = [bool]$fresh }) }
        if ($verified -and $fresh) { $claims.Add([pscustomobject]@{ source = $member.source; fact = 'completion'; value = $member.verification.outcome; quote = $member.verification.summary; current = $true }) }
    }
    $repositories = @(@(foreach ($member in $members) {
        $definition = $Config.monitoring.monitors | Where-Object name -CEQ $member.monitor | Select-Object -First 1
        $task = $State.tasks | Where-Object id -CEQ $member.taskId | Select-Object -First 1
        if ($task.repositoryRef) { $task.repositoryRef } elseif ($definition.verification.repositoryRef) { $definition.verification.repositoryRef }
    }) | Sort-Object -Unique)
    if ($repositories.Count -gt 1) { $conflicts.Add([pscustomobject]@{ fact = 'repository'; reason = 'Related sources select different coding repositories; correlation cannot retarget tasks.'; resolved = $false; claims = @() }) }
    $snapshots = @($members.verification.snapshot | Where-Object { $_ } | Sort-Object -CaseSensitive -Unique)
    if ($snapshots.Count -gt 1) { foreach ($member in $members) { $null = $pending.Add($member.source) } }
    $effectiveOutcome = ''
    foreach ($fact in @($claims.fact | Sort-Object -CaseSensitive -Unique)) {
        $facts = @($claims | Where-Object fact -CEQ $fact)
        $values = @($facts.value | Sort-Object -CaseSensitive -Unique)
        $authority = if ($authorities.Contains($fact)) { [string]$authorities[$fact] } else { '' }
        $authoritative = @($facts | Where-Object { $_.source -ceq $authority -and $_.current })
        $resolved = $authority -and @($authoritative.value | Sort-Object -CaseSensitive -Unique).Count -eq 1
        if ($values.Count -gt 1) { $conflicts.Add([pscustomobject]@{ fact = $fact; reason = 'Substantive source claims disagree.'; resolved = [bool]$resolved; authority = $authority; claims = $facts }) }
        if ($fact -ceq 'completion') {
            if ($resolved) { $effectiveOutcome = $authoritative[0].value }
            elseif ($values.Count -eq 1) { $effectiveOutcome = $values[0] }
        }
    }
    $taskIds = @($members.taskId | Where-Object { $_ } | Sort-Object -CaseSensitive -Unique)
    if ($taskIds.Count -gt 1) { $conflicts.Add([pscustomobject]@{ fact = 'task-link'; reason = 'Existing separate tasks require explicit reconciliation; their records were preserved.'; resolved = $false; claims = @() }) }
    $unresolved = @($conflicts | Where-Object { -not $_.resolved })
    [pscustomobject]@{
        representativeId = [string]$representative[0].id; members = $members; sources = @($sources | Sort-Object -CaseSensitive); taskIds = $taskIds
        correlated = ($sources.Count -gt 1 -or $members.Count -gt 1); ready = (-not $pending.Count -and -not $unresolved.Count)
        outcome = $(if ($pending.Count -or $unresolved.Count) { 'unverified' } else { $effectiveOutcome })
        pending = @($pending); conflicts = @($conflicts); authorities = [pscustomobject]$authorities
        provenance = @($members | Select-Object id, monitor, sourceId, source, revision, sourceOwner, lastSeenAt, latestReport, acceptance, verification)
    }
}

function Get-HarnessDiscoveryProposal {
    param($Config, $Candidate, $DiscoveryState)
    $definition = @((Get-HarnessMonitorSettings $Config).monitors | Where-Object name -CEQ $Candidate.monitor) | Select-Object -First 1
    $correlation = if ($DiscoveryState) { Get-HarnessDiscoveryCorrelation $Config $DiscoveryState $Candidate } else { $null }
    if ($correlation.correlated -and (-not $correlation.ready -or $correlation.representativeId -cne $Candidate.id -or
        ($correlation.outcome -and $correlation.outcome -cne 'open'))) { return }
    if (-not $definition -or $definition.response -eq 'report-only' -or ($Candidate.taskId -and -not $Candidate.followUpOf) -or $Candidate.disposition -eq 'Missing' -or $Candidate.evidenceStatus -ceq 'Uncertain') { return }
    if ($Candidate.lastSeenAt -and ([datetimeoffset]::UtcNow - [datetimeoffset]$Candidate.lastSeenAt).TotalMinutes -gt $definition.maxAgeMinutes) { return }
    if ($definition.verification.enabled -ne $false) {
        if (-not $correlation.correlated -and ($Candidate.verification.outcome -cne 'open' -or $Candidate.verification.sourceRevision -cne $Candidate.revision -or $Candidate.verification.collectionRunId -cne $Candidate.lastRunId)) { return }
    }
    elseif ($Candidate.disposition -in @('Resolved', 'Superseded')) { return }
    if (-not $definition.scope -and ($definition.source.type -ceq 'ado' -or ([uri]$Candidate.source).Host -ieq 'dev.azure.com')) { return }
    $assessment = $Candidate.assessment
    if ($assessment.classification -in @('Informational', 'OutOfScope') -or ($Candidate.isContainer -and -not $assessment.independentConcern)) { return }
    if ($definition.scope -and (-not $assessment -or $assessment.relevance -cne 'Relevant' -or
        $assessment.scope -cne $definition.scope.description -or $assessment.sourceRevision -cne $Candidate.revision)) { return }
    $priority = if ($assessment -and $assessment.relevance -ceq 'Relevant') { $assessment.priority } elseif ($null -ne $Candidate.priority) { $Candidate.priority } else { 3 }
    [pscustomobject]@{
        candidateId = $Candidate.id; title = $Candidate.title; disposition = $Candidate.disposition
        description = "Source disposition: $($Candidate.disposition). Review the authoritative source and current implementation, then handle unfinished work by priority. Previously postponed work is backlog, not an automatic block; current blockers still apply.`nRelevance: $($assessment.reason)`nPriority: $($assessment.priorityReason)`n$($Candidate.evidence)"
        scope = "Source discovery: $($Candidate.source)"
        acceptance = $(if ($Candidate.acceptance) { $Candidate.acceptance } else { 'Verify the source concern, current status, scope, and acceptance criteria. Handle prioritized backlog while preserving actual blockers and historical evidence; discovery alone does not establish an unfixed defect.' })
        priority = [int]$priority; relevanceReason = $assessment.reason; priorityReason = $assessment.priorityReason
        blocked = ($Candidate.disposition -ceq 'Blocked' -or @($assessment.blockers | Where-Object { $_ }).Count -gt 0); blockers = @($assessment.blockers | Where-Object { $_ })
        source = $Candidate.source; sourceRevision = $Candidate.revision; sourceOwner = [string]$Candidate.sourceOwner
        followUpOf = [string]$Candidate.followUpOf
        sourceEvidence = @($correlation.provenance); conflicts = @($correlation.conflicts); factAuthorities = $correlation.authorities
        kind = 'verify'; risk = 'Unknown'; autoEligible = $false
    }
}

function Get-HarnessDiscoveryAssessmentSummary {
    param($Definition, [object[]]$Candidates, [string]$CollectionStatus = 'Succeeded')
    if (-not $Definition.scope) { return [pscustomobject]@{ status = 'NotRequired'; pending = @() } }
    if ($CollectionStatus -cne 'Succeeded') { return [pscustomobject]@{ status = 'AwaitingCollection'; pending = @() } }
    $pending = @(); $relevant = 0; $excluded = 0; $uncertain = 0
    foreach ($candidate in $Candidates) {
        if ($candidate.disposition -ceq 'Missing') { continue }
        $assessment = $candidate.assessment
        if (-not $assessment -or $assessment.scope -cne $Definition.scope.description -or $assessment.sourceRevision -cne $candidate.revision) { $pending += $candidate.id; continue }
        switch ($assessment.relevance) {
            'Relevant' { $relevant++ }
            'NotRelevant' { $excluded++ }
            'Uncertain' { $uncertain++ }
        }
    }
    [pscustomobject]@{ status = $(if ($pending.Count) { 'NeedsAssessment' } else { 'Assessed' }); pending = $pending; relevant = $relevant; excluded = $excluded; uncertain = $uncertain }
}

function Set-HarnessDiscoveryAssessment {
    param($Paths, [string]$Name, [string]$DefinitionPath, [switch]$Apply, $RunnerContext)
    if (-not [IO.Path]::IsPathRooted($DefinitionPath)) { $DefinitionPath = Join-Path $Paths.Project $DefinitionPath }
    $incoming = [IO.File]::ReadAllText($DefinitionPath) | ConvertFrom-Json -NoEnumerate
    if ($incoming -isnot [pscustomobject] -or $incoming.monitor -isnot [string] -or $incoming.monitor -cne $Name -or
        $incoming.runId -isnot [string] -or [string]::IsNullOrWhiteSpace($incoming.runId) -or $incoming.assessments -isnot [array] -or
        @($incoming.PSObject.Properties.Name | Where-Object { $_ -cnotin @('monitor', 'runId', 'assessments') }).Count) { throw 'Supply the selected monitor, collection runId, and assessments array.' }
    $runLock = Enter-HarnessLock $Paths.RunLock
    try {
        $config = Read-HarnessConfig $Paths
        $definition = Get-HarnessMonitorDefinition $config $Name
        if ($definition.kind -cne 'discovery' -or -not $definition.scope) { throw 'Assessment requires a scoped discovery monitor.' }
        Assert-HarnessTargetRunning $Paths @('monitor:' + $Name)
        $state = Read-HarnessState $Paths
        if ($state.active) { throw 'Recover interrupted work before assessing discovered candidates.' }
        $latest = @((Get-HarnessMonitoringState $state).latest | Where-Object monitor -CEQ $Name) | Select-Object -First 1
        if ($latest.runId -cne $incoming.runId -or $latest.result.status -cne 'Succeeded' -or
            ([datetimeoffset]::UtcNow - (ConvertTo-HarnessMonitorTime $latest.result.observedAt)).TotalMinutes -gt $definition.maxAgeMinutes) { throw 'Assessment requires the latest fresh successful collection.' }
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $assessments = @(foreach ($entry in $incoming.assessments) {
            if ($entry.candidateId -isnot [string] -or -not $seen.Add($entry.candidateId)) { throw 'Assessment candidate IDs must be unique.' }
            $candidate = @($state.monitoring.candidates | Where-Object { $_.id -ceq $entry.candidateId -and $_.monitor -ceq $Name }) | Select-Object -First 1
            if (-not $candidate -or $candidate.disposition -ceq 'Missing') { throw 'Assess only present candidates in the selected monitor.' }
            [pscustomobject]@{ candidateId = $candidate.id; assessment = ConvertTo-HarnessDiscoveryAssessment $entry $definition $candidate.revision }
        })
        if (-not $Apply) { return [pscustomobject]@{ preview = $true; monitor = $Name; assessments = $assessments } }
        $result = Update-HarnessState $Paths -Config $config -Operation {
            param($saved)
            foreach ($entry in $assessments) {
                $candidate = $saved.monitoring.candidates | Where-Object id -CEQ $entry.candidateId
                $candidate | Add-Member -NotePropertyName assessment -NotePropertyValue $entry.assessment -Force
            }
            $summary = Get-HarnessDiscoveryAssessmentSummary $definition @($saved.monitoring.candidates | Where-Object monitor -CEQ $Name)
            [pscustomobject]@{
                status = $summary.status; monitor = $Name; assessments = $assessments
                assessment = $summary
                proposals = @(@(foreach ($candidate in $saved.monitoring.candidates | Where-Object monitor -CEQ $Name) { Get-HarnessDiscoveryProposal $config $candidate $saved }) | Sort-Object priority, candidateId)
            }
        }
        if ($definition.verification.enabled -ne $false) {
            $effective = Resolve-HarnessRunnerConfig $config $RunnerContext
            $verification = Invoke-HarnessDiscoveryVerification $Paths $effective $definition $latest.runId (Get-HarnessExecutionLimit $effective maxProcessMinutes $definition.maxMinutes)
            $result | Add-Member -NotePropertyName verification -NotePropertyValue $verification
            $verifiedState = Read-HarnessState $Paths
            $result.proposals = @(@(foreach ($candidate in $verifiedState.monitoring.candidates | Where-Object monitor -CEQ $Name) { Get-HarnessDiscoveryProposal $config $candidate $verifiedState }) | Sort-Object priority, candidateId)
        }
        $result
    }
    finally { $runLock.Dispose() }
}