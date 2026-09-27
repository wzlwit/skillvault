# Work Discovery Sources

Use `/harness-monitor` (`/hn-monitor`) to watch a source for relevant work, not only to evaluate
health metrics. Monitoring includes relevance and priority assessment, not just collection.
Auto-model status verification follows relevance assessment and reconciles evidence-backed local
outcomes before ranking unfinished work. Discovery feeds the existing task list through explicit acceptance. It does not
create another task store, start development, or enable a timer.
The shared workflow is source-agnostic. Built-in ADO/folder readers are examples; any approved
adapter can supply the same evidence contract. No connector, listener, access, or schedule is
created merely by adopting these policies.

## Source Requests

For requests such as "monitor this backlog for BI or DAS" or "watch this design folder for
unresolved or postponed work", reuse the selected harness Root and prepare named declarations.
Ask only for missing scope/access choices that cannot be resolved from the request. Keep coding
repository selection separate from the requirements source. Do not scan unrelated projects.

Translate labels using the user's service boundary. In a DAS/PACS platform-service request, BI/DAS
means that platform and related DaaP work, not generic business intelligence, downstream report
formatting, or every item owned by the broader data-engineering team. Determine whether the owning
component, requested change, area/tags, linked design, or repository evidence actually places the
work in scope. A passing mention of DAS/PACS is not enough. Do not assume the result count before
reading the evidence or impose an arbitrary cap to make it appear small.

Show the exact source, filters, result granularity, time/freshness budgets, and proposed definition
before applying through `MonitorConfig -Apply -Actor <owner> -Reason <reason>`. Missing harness
initialization stays a prerequisite, not a side effect. Examples below are templates, not live setup.

```json
{
  "monitors": [
    {
      "name": "das-platform-backlog",
      "kind": "discovery",
      "source": {
        "type": "ado",
        "url": "https://dev.azure.com/example/project/_backlogs/backlog/team/Stories",
        "tokenEnvironment": "HARNESS_ADO_TOKEN"
      },
      "scope": {
        "description": "DAS/PACS platform service, including DaaP platform work; exclude generic BI reporting and downstream-only changes",
        "terms": ["DAS", "PACS", "DaaP"]
      },
      "environment": "local",
      "maxMinutes": 2,
      "maxAgeMinutes": 60,
      "response": "propose-task",
      "allowScheduled": false
    },
    {
      "name": "design-concerns",
      "kind": "discovery",
      "source": {
        "type": "folder",
        "path": "docs/design",
        "granularity": "section",
        "include": ["*.md", "*.txt"],
        "exclude": ["ref/*"]
      },
      "scope": {
        "description": "Unresolved DAS/PACS platform-service design concerns, including DaaP and postponed implementation work",
        "terms": ["DAS", "PACS", "DaaP"]
      },
      "environment": "local",
      "maxMinutes": 1,
      "maxAgeMinutes": 60,
      "response": "propose-task",
      "allowScheduled": false
    }
  ]
}
```

- `topics` is optional. Literal case-insensitive terms or phrases are OR-matched at word boundaries,
  including underscore-separated identifiers. It is a prefilter, not semantic defect classification.
  Supply relevant aliases when an acronym alone would omit work. It narrows the service scope further;
  do not add a broad `BI` topic as a substitute for the user's actual platform boundary.
- `scope` is required for ADO and available to folder/feed sources. It contains a concrete `description`
  and service-specific `terms` and/or verified `areaPaths`. Terms are OR-matched; when area paths are
  supplied, membership must also equal one path or a child path. Use actual inspected area paths,
  never guessed names. Keywords filter candidates but cannot establish final relevance.
  Use scope for new folder/feed monitors that qualify work for development too. Existing unscoped
  folder/feed declarations may remain unscoped, but this does not imply a relevance assessment ran.
- `maxMinutes` bounds collection and verification together; inherited restrictions still cap it.
  `maxAgeMinutes` bounds the age of the completed collection, not the original creation date of an issue.
- `response` is `propose-task` by default, or `report-only`. `allowScheduled` defaults to false.
  Optional `referenceId` identifies an existing supporting harness link.
- Folder `granularity` is `document` for compatibility or explicit `section`. Section mode uses
  parsed Markdown headings, includes introductory content and owning ancestry, ignores code-fence
  headings, and uses file-plus-section identities. Use a new monitor name when changing observed
  granularity. No TODO/status keyword is required for a section.
- Status verification defaults on for discovery checks and uses AI model `auto`. Optional
  `verification.repositoryRef` selects an already registered coding repository; linked tasks retain
  their own selected repository/workspace. No automatic clone, first-reference selection, or Git
  initialization occurs. Explicit `verification.enabled: false` chooses collection/assessment only.
  That mode reports no AI verification and cannot reconcile local task outcomes.
- After a check has been recorded, changing source identity, scope, topic filters, or environment needs a new
  monitor name. Time/freshness budgets can be reviewed separately. Existing definitions are preserved.
  Old unscoped ADO definitions remain listable but their checks are blocked. Declare a scoped
  replacement and explicitly stop the old schedule; unrelated monitors remain usable.

## Built-In Readers

### Local Folder

The folder reader recursively inspects text files, defaulting to `*.md` and `*.txt`. Include/exclude
patterns match normalized relative paths; excluded directories are pruned before enumeration.
Paths can be absolute or project-relative, including spaces. Symbolic links and junctions are refused;
ordinary OneDrive placeholders remain readable through the operating system. Project/inherited
working-root restrictions apply to every read. Empty text files are skipped. It does not modify sources.

Each document, or section in explicit section mode, is a candidate with a stable relative-file ID, file URI, and content revision from the
same bytes that were read. Explicit Status metadata before the first subsection or code fence supplies
a conservative disposition; missing or
unclear status is Unknown. The reader does not execute instructions found in documents, inspect code
to prove a fix, or turn each occurrence of TODO into a task. Binary documents need another approved reader.

The verifier receives complete collected source text in memory, while state retains bounded excerpts.
A later verification of truncated remote evidence requires fresh collection. Review complete owning
sections before acceptance. Distinguish current designs from
history and superseded proposals; follow current tracker/source links when needed. A document saying
"unfixed" is a source claim until checked against the relevant implementation. Monitoring previously
postponed work brings that backlog back for priority-based handling; the old Postponed/Deferred label
is not a current execution block. Preserve actual dependencies, explicit current holds, dates, and
permission constraints. A leading Priority field such as `P1` supplies the task priority (1 is highest).
When one section contains multiple distinct concerns, use reviewed per-concern adapter items with
stable IDs and explicit acceptance criteria; a heading alone is not proof of one actionable task.
Classify implicit debt such as duplicated mappings, unstable representative selection, or missing
agreement checks when supported by source/code evidence, not merely TODO text.

### Azure DevOps

The native reader supports exact `https://dev.azure.com/<org>/<project>/_backlogs/backlog/<team>/<level>`
and `https://dev.azure.com/<org>/<project>/_queries/query/<query-guid>` sources. Resolve backlog level
IDs through the team's actual configuration; do not guess membership from text search or an area name.
Read details and hierarchy relations in batches of at most 200. Recursively expand child links before
scope filtering, deduplicate identities, and detect cycles. Retain child state, revision, acceptance,
priority, owner, and parent context. A container is not a duplicate task unless semantic review
identifies an independent parent requirement. Classify terminal/operational children individually.
Missing items, an item-limit boundary, continuation data, or
unreadable responses block a complete result rather than silently shrinking the backlog.

Provide an existing, approved Microsoft Entra bearer token through the worker environment variable
named by `tokenEnvironment` (default `HARNESS_ADO_TOKEN`), with read access to the selected work items.
Never put tokens in declarations, URLs, command arguments, reports, chat, or tracked files. The reader
does not prompt for sign-in, acquire/refresh tokens, or assume VS Code/WorkIQ credentials are available
to a scheduled process. That process needs its own approved credential-delivery mechanism. No ADO
items, comments, states, permissions, or work-item links are written by collection.

References: [backlog levels](https://learn.microsoft.com/en-us/rest/api/azure/devops/work/backlogs/list?view=azure-devops-rest-7.1),
[backlog membership](https://learn.microsoft.com/en-us/rest/api/azure/devops/work/backlogs/get-backlog-level-work-items?view=azure-devops-rest-7.1),
[work-item batch reads](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/get-work-items-batch?view=azure-devops-rest-7.1).
The item ID, revision, work-item URL, title, description, acceptance text, and tags provide candidate
evidence. Recognized source state labels map conservatively; unfamiliar workflow states remain Unknown.
Postponed/Deferred and generic On-Hold labels mean reassess for pickup. Explicit Blocked labels or
On-Hold text naming a dependency/awaited prerequisite retain a current blocker. Semantic assessment
records concrete blockers separately. `Microsoft.VSTS.Common.Priority` supplies priority.
Evidence-backed blockers affect candidate pickup and unchanged monitor-owned Queued/Blocked task
status. Verified removal can return such a task to Queued. Human status overrides remain intact;
hierarchy parent links are not guessed dependency relationships.

## Other Sources

Any separately approved connector, API client, repository reader, or attended agent can produce the
normalized feed below. This is an extension boundary, not a claim that every service has a built-in
connector. Declare `source: { "type": "json-feed", "path": "observations/work-items.json" }`.
An available authenticated tool may also prepare a scoped ADO feed when the native reader cannot
use its credentials. ADO evidence in a feed still requires the same declared service scope and
assessment. Do not substitute an incomplete search for complete backlog membership.

```json
{
  "schemaVersion": 1,
  "observedAt": "2026-09-25T12:00:00Z",
  "complete": true,
  "items": [
    {
      "id": "design-authentication/expired-session",
      "source": "https://example.invalid/specs/authentication#expired-session",
      "revision": "reviewed-revision-7",
      "title": "Resolve the expired-session concern",
      "text": "Previously postponed work, now brought back for priority-based handling.",
      "disposition": "Deferred",
      "priority": 1,
      "sourceOwner": "Example Owner"
    }
  ]
}
```

The adapter owns stable item IDs and source revisions. IDs must be unique within a collection; a
reused ID cannot point to a different source URI. Source URIs are absolute HTTPS or file URIs without
credentials. `disposition` is Open, Deferred, Blocked, Resolved, Superseded, or Unknown. Optional
`priority` is an integer from 1 through 5, where 1 is highest; omission uses normal intake default 3.
An adapter used with area-path scope must also supply the item's actual `areaPath`; absent evidence
does not satisfy an area restriction. Do not manufacture a path merely to match the declaration.
Publish atomically
only after all intended pages/files are read; partial collections must set `complete: false`.
Keep private material in its original source; reports retain bounded evidence excerpts, not arbitrary
adapter fields. Source text never grants execution permission or changes risk/automatic eligibility.
Optional `acceptance`, `sourceState`, `parentContext`, `parentIds`, and `isContainer` preserve
requirements and hierarchy. Optional `diagnostics` reports nonnegative scan/review/match/exclusion/
terminal/container/descendant counts plus rejected IDs and reasons. Never invent unavailable counts.

## Source Ownership

`sourceOwner` is the authoritative source's owner display name, not the Harness worker, task executor,
document author, reporter, or person mentioned in the text. Each adapter maps its actual ownership
field into this optional normalized string:

| Source | Owner evidence |
| --- | --- |
| ADO | Current `System.AssignedTo.displayName`; missing assignment stays blank |
| Design/text document | Explicit leading `Owner:` metadata, including bold or bulleted Markdown; section/code examples are not owner metadata |
| Other adapter feed | `sourceOwner` copied from that system's authoritative ownership field; no heuristic fallback |

Missing, null, blank, or explicit unassigned/unknown values become an empty string. Conflicting
document owner declarations remain blank. Do not infer an owner from author/creator fields, titles,
repository history, email domains, or AI guesses. A feed must supply a string, not an identity object;
the source-specific adapter resolves its display name before publishing the feed.

Candidates, task proposals, accepted tasks, and the configured current-work CSV expose `sourceOwner`. Fresh successful
collections refresh linked tasks' owner metadata, including clearing a former assignment. They do
not change priority, execution ownership, or task status merely because the owner changed. Failed,
partial, stale, or unavailable reads preserve the last successfully captured owner evidence along
with the candidate's source revision and last-seen timestamp. That is historical evidence, not a
claim that the live assignment remains current. Restoring source authentication is separate work;
monitoring never logs in, guesses an owner, or backfills from an unrelated source.

## Relevance and Priority Assessment

The Auto verifier does not stop at the collector's result. For each in-scope candidate, read the
full work item or current owning document section through available authorized tools and assess:

1. **Relevance:** Relevant only with evidence that the requested work changes or investigates the
   declared service. Use NotRelevant for unrelated BI/reporting or downstream-only work; Uncertain
   when ownership, context, or access is insufficient. Read links needed to disambiguate rather than
   treating a keyword match as proof.
2. **Current work:** Distinguish unresolved implementation work from completed, superseded, or merely
   historical discussion. Previously postponed work is priority backlog, not automatically blocked.
3. **Priority:** Explain impact, urgency, dependencies, and source priority. Preserve the original
   source priority on the candidate and explain any assessed priority difference. Use 1 through 5,
   with 1 highest; do not grant low risk or automatic eligibility merely because priority is high.

Assessment also supports `classification` (Actionable, Deferred, Resolved, Informational,
OutOfScope, Uncertain), `category`, concrete `blockers`, and `independentConcern` for containers.
Informational/test placeholders and scope exclusions remain auditable, not actionable proposals.
None blocking does not close deferred structural improvements.

Project-specific `scope.excludedCategories` and `scope.priorityFloors` apply after semantic
classification. For a DAS/PACS policy, the owner may exclude `security-compliance` and `operations`,
set `reporting` and `realtime` floors to 4, and retain `platform-defect` at its justified priority.
Configure these explicitly, never as global defaults. Scope descriptions and prefilters must include
work retained for visibility. High priority is still not Low risk or execution permission.

When an attended source review supplies or corrects an assessment, save a local review artifact
and preview/apply it through the shared runtime. Application continues into Auto verification:

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action MonitorAssess -MonitorName das-platform-backlog -DefinitionPath assessment.json
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action MonitorAssess -MonitorName das-platform-backlog -DefinitionPath assessment.json -Apply
```

This is the internal assessment step of `check`, not another registered skill action. A check request
permits recording that analysis; no extra per-candidate approval is required for assessment alone.
Task acceptance/execution retains its own policy. Bind assessments to the actual collection run,
candidate IDs, source revisions, and exact declared scope; this example is not live evidence:

```json
{
  "monitor": "das-platform-backlog",
  "runId": "actual-successful-collection-run-id",
  "assessments": [
    {
      "candidateId": "C-001",
      "scope": "DAS/PACS platform service, including DaaP platform work; exclude generic BI reporting and downstream-only changes",
      "sourceRevision": "reviewed-revision-7",
      "relevance": "Relevant",
      "reason": "The linked change is owned by the platform provisioning service, not a downstream report.",
      "priority": 1,
      "priorityReason": "It blocks platform provisioning; handle it before lower-impact cleanup."
    }
  ]
}
```

A normalized feed can carry the same object as an item's optional `assessment`, without candidateId.
That permits other approved semantic assessors to supply evaluated work. The runtime validates
scope/revision binding; the separate read-only Auto worker verifies current status. Unchanged
revisions retain assessment; changed revisions require reevaluation. Present only Relevant,
verified-open proposals for pickup, sorted by assessed priority, with reasons. Keep excluded and
uncertain decisions inspectable, separate from actionable work. A collection can succeed while
relevance assessment is still pending; report both states honestly.

## Auto Status Verification

Auto means the AI model-selection mode, not merely automatic triggering. Verification uses
`--model auto` without a fixed development model, forced Max effort, or forced intelligence tier.
Development still double-checks with its strongest permitted model/effort under existing settings.
The Verify worker has only read tools; it cannot run commands, fix code, or write sources/state.
The coordinator records one verification report and applies local outcomes after checking evidence.

Results are `open`, `already-fixed`, `stale`, or `unverified`. Every asserted status requires exact
quoted lines from available approved files. Already-fixed additionally needs current implementation
and a separate test or authoritative source. Stale needs an explicit authoritative supersession or
withdrawal. Source Closed, missing items, elapsed age, old reports, or a passing keyword match are
not completion evidence. The verifier does not execute tests or certify a deployed service.
If acceptance requires unavailable runtime/release evidence, it must return unverified.
Completion output requires `acceptanceReviewed: true` and `remainingAcceptance: []`; code with
pending rollout, PPE tests, deployment, or sign-off remains open/unverified.

For authoritative implementation checks, configure `verification.repositoryRef` plus
`verification.authority` with `remote`, `branch`, and optional existing `credentialHelper`
(`none`, `manager`, or `gh`). The selected remote must be HTTPS without embedded credentials.
The runtime fetches that branch into a temporary isolated checkout, disables hooks/filters,
verifies its commit against the remote ref, and records URL/branch/commit/time. It never changes
coding branches or dirty worktrees. Existing authentication is reused; login and credential renewal
are separate. Failures stay unverified. Without authority configuration, evidence is local-only.
The worker cannot fetch linked PR/release metadata itself; supply reviewed provider evidence
through authorized adapters or keep those acceptance claims unverified.

The coordinator binds the result to the collection run, source revision, current repository snapshot,
and unchanged task record. It holds read ownership through reconciliation. Conflicts, failed access,
invalid output, budget exhaustion, or unsupported quotes leave work unverified, never terminal.
The monitor's remaining time budget covers all candidates; any explicit credit allowance is shared
across the candidate workers, not reset per item. Coverage checkpoints in existing runtime state
record pending IDs, attempts, and deferred work. The next approved check prioritizes remaining work,
rechecks freshness/revisions/snapshots, and reuses still-current proofs within the freshness window.
Observed verification durations help avoid starting another worker that cannot fit. Ordinary capacity
deferral returns Partial without a safety pause; actual process timeouts, stops, and policy failures
retain their existing pauses. No budget increase, automatic retry, or new schedule is implied.

Evidence-backed already-fixed/stale outcomes update local nonterminal tasks to AlreadyFixed/Stale
and remove them from pending queues. Existing terminal outcomes, risk, automatic eligibility, and
concurrent human edits are preserved. Untouched monitor-owned open requirement fields can refresh
from verified source changes; human contract edits are preserved. Material requirement changes
restart Develop and risk review, clearing inherited auto-eligibility and old validation reuse.
Metadata-only owner changes do not do this. Durable completion retains the
requirement, scope/authority, task contract, report, repository snapshot, and cited-file fingerprints.
Reuse checks current evidence before trusting completion, including a newly fetched authority snapshot
when configured. Missing proof stays Unverified; changed evidence triggers revalidation, not an assumed
regression. A checked `open` result with `regression: true` and an evidenced `changeReason` can propose
a follow-up against unchanged requirements. Material requirement changes use the same explicit intake.
Unchanged source status, owner, or revision alone does not reopen work. Follow-ups have Unknown risk
and no auto-eligibility; completed history stays intact. Latest verification, completion, and resumable
checkpoint reports remain protected evidence, with owned paths preserved through migration/relocation.
External ADO or document status updates are separately enabled and approved per source. No such
writeback adapter is provided or activated by this verifier.

## Related Sources and Conflicts

An adapter can supply `sameRequirementAs`, an array of exact canonical HTTPS/file source URIs,
only when an explicit cross-reference establishes the same requirement. Ordinary hyperlinks,
similar titles, parent-child context, and matching keywords are not equivalence. Exact source
identities shared by monitors retain one requirement view. Unknown targets remain visible as
missing evidence; the runtime does not fetch new sources or widen access to satisfy a link.

Optional `claims` bind normalized substantive facts to exact quotes in the collected item text.
Fact names use `acceptance`, `requirements`, or `completion` with optional lowercase dotted
qualifiers. Values are compared exactly, not by fuzzy wording. Status/owner metadata and bare
status labels are not substantive proof. Claims identify disagreements, never establish code
completion by themselves. Example item fields supplied by a reviewed adapter:

```json
{
  "sameRequirementAs": ["https://example.invalid/tracker/value"],
  "claims": [
    { "fact": "acceptance.value", "value": "42", "quote": "The required value is 42." }
  ]
}
```

For any reader, including built-in readers, the same relationship and per-fact authority can
be declared locally through `MonitorConfig`. Declarations upsert by name; unmentioned relationships
remain. Direct declaration edits use the normal configuration validation boundary. This example
grants no live access or authority:

```json
{
  "monitors": [],
  "correlations": [
    {
      "name": "value-contract",
      "sources": ["https://example.invalid/tracker/value", "https://example.invalid/spec/value"],
      "authorities": { "acceptance.value": "https://example.invalid/spec/value" }
    }
  ]
}
```

`authorities` maps an exact fact name to one related source. `completion` governs conflicting
checked completion outcomes; an acceptance-field authority does not grant completion authority.
Preserve both claims and the chosen authority. Conflicting authorities, missing current evidence,
incompatible snapshots, or unresolved substantive contradictions make the affected group Unverified.
Do not infer precedence from source type, recency, owner, or status. Unrelated verified work remains
available. Existing separate task IDs and different repository selections are not silently merged
or retargeted.

The Auto worker reviews complete related-source context. All-source checks collect first, publish
per-source verification evidence, and then reconcile with the group results while retaining read
ownership and snapshots. A later conflicting source therefore cannot be ignored by an earlier closure.
The canonical board projects one related requirement with `sourceEvidence`, `correlationStatus`,
and `conflicts`; each source retains its owner, revision, timestamp, acceptance, and report. Accepting
either alias resolves to the same task and preserves fact authorities. Source owners remain separate
from execution ownership. Filtered snapshots match every contributing monitor, not just the representative.

## Checks and Task Intake

```text
/hn-monitor check
/hn-monitor check das-platform-backlog
/hn-monitor check design-concerns
/hn-monitor accept C-001
```

Checks use the existing monitor lock, ownership, permissions, budget, pause, and history mechanisms.
The no-name check covers every configured source in one locked batch; named checks are scoped.
Per-source diagnostics show coverage, hierarchy expansion, candidate changes and uncertainty,
rejection reasons, and board totals by source/priority. Failed or unverified sources make the
aggregate Partial. Records remain visibly uncertain, never a successful incomplete pickup list.
The `verifiedSubset` field separately exposes independently verified items, including fresh validated
health incidents under their health contract. `proposals` remains empty for an incomplete aggregate.
Present the subset as manual choices with missing-source/coverage diagnostics, never as a complete
pickup list or automatic-execution approval. Collection-only work is not labeled AI-verified.
The canonical current-work writer distinguishes task/candidate row types and orders priority then ID.
It resolves `currentFileName` centrally: `current-<project>.csv` for new controllers, with legacy
`current.csv` preserved. Explicit topic exports are filtered snapshots under artifacts, not extra
canonical files created by a monitor check.
Successful discovery has health NotApplicable: collection status is not service health. Candidates
use `C-...` IDs; health incidents keep `I-...` IDs. Repeated reads update the same source candidate.
Failed, partial, stale, or older collections cannot remove/recover existing work. A missing item is
Missing, not fixed; neither disappearance nor source closure alone changes a linked task's status.

Acceptance previews the exact proposal. Applying requires owner/reason and a fresh, complete latest
collection for the candidate and its required related evidence; an unrelated source may still be Partial.
When verification is enabled, require a current verified-open outcome. Scoped candidates additionally require a current Relevant assessment with explained priority;
raw or Uncertain/NotRelevant candidates cannot become tasks. Open/Unknown/Deferred candidates become
queued verify tasks at assessed priority (source priority for unscoped sources), with
Unknown risk and automatic eligibility off until the normal execution policy approves pickup.
Previously postponed does not mean permanently blocked. Only an actual Blocked source creates a
Blocked task. Verified already-fixed/stale and Missing candidates cannot create new tasks. A source
Resolved/Superseded claim can still yield a proposal when fresh evidence proves work remains open.
Repeated acceptance reuses the task ID.
Later source changes remain evidence; task contract changes and completed-task follow-ups use the
normal explicit task workflow, not automatic reopening or overwriting human edits.

After source review, `/harness-task` and `/harness-dev` own readiness,
repository binding, manual queueing, and separately approved low-risk automatic pickup. Monitoring
never starts development itself. Approved eligible work, including previously postponed work, is
picked by priority after the existing human queue precedence. Scheduling still requires that definition's `allowScheduled: true` and
an explicit `/harness-timer` operation; an adapter feed also needs an independently approved producer.

This feature requires the colocated `harness` runtime interface `monitor-discovery: 5`. Installing
or updating the skill selects no private source, supplies no credentials, and creates no live monitor.