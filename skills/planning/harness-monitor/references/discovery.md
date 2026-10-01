# Work Discovery Sources

Contents: Source Requests; Built-In Readers; Other Sources; Source Ownership; Relevance and
Priority Assessment; Auto Status Verification; Related Sources and Conflicts; Checks and Task Intake.

`/harness-monitor` (`/hn-monitor`) can watch a source for relevant work, not only health metrics. A
check collects candidates, assesses relevance and priority, verifies current status with the Auto
model, reconciles evidence-backed local outcomes, and then ranks unfinished work. Discovery feeds the
existing task list only through explicit acceptance; it creates no task store, starts no development,
and enables no timer. The workflow is source-agnostic: the built-in ADO and folder readers are examples, and any
approved adapter can supply the same evidence contract. Adopting these policies creates no
connector, listener, access, or schedule.

## Source Requests

For requests such as "monitor this backlog for BI or DAS" or "watch this design folder for
unresolved or postponed work", reuse the selected harness Root and prepare named declarations. Ask
only for scope or access choices the request leaves open, keep coding-repository selection separate
from the requirements source, and never scan unrelated projects.

Interpret labels by the user's service boundary. In a DAS/PACS platform-service request, BI/DAS means
that platform and related DaaP work, not generic business intelligence, downstream report
formatting, or everything the broader data-engineering team owns. The owning component, requested
change, area/tags, linked design, or repository evidence must place the work in scope; a passing
mention of DAS/PACS is not enough. Never assume the result count before reading the evidence or cap
it to make it look small.

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

- `topics` (optional): literal case-insensitive terms or phrases, OR-matched at word boundaries,
  including underscore-separated identifiers. It is a prefilter that narrows the service scope, not
  semantic defect classification. Add aliases when an acronym alone would miss work, and never use a broad
  `BI` topic in place of the user's actual platform boundary.
- `scope` (required for ADO, available to folder and feed sources): a concrete `description` plus
  service-specific `terms` and/or verified `areaPaths`. Terms are OR-matched; with area paths, an item
  must also be in one of those paths or a child path. Use actually inspected area paths, never guessed
  names. Keywords filter candidates but never establish final relevance. Scope new folder and feed
  monitors too when their work can qualify for development; existing unscoped ones may stay unscoped,
  but that does not mean a relevance assessment ran.
- `maxMinutes` bounds collection and verification together, still capped by inherited restrictions.
  `maxAgeMinutes` bounds the age of the completed collection, not the creation date of an issue.
- `response` is `propose-task` (default) or `report-only`. `allowScheduled` defaults to false.
  Optional `referenceId` names an existing supporting harness link.
- Folder `granularity` is `document` (compatibility) or explicit `section`. Section mode uses parsed
  Markdown headings, includes introductory content and owning ancestry, ignores headings inside code
  fences, and identifies each item by file plus section. No TODO or status keyword is required.
  Changing the observed granularity needs a new monitor name.
- Status verification is on by default and uses AI model `auto`. Optional `verification.repositoryRef`
  selects an already registered coding repository; linked tasks keep their own repository and
  workspace. There is no automatic clone, first-reference selection, or Git initialization. Explicit
  `verification.enabled: false` means collection and assessment only: no AI verification and no local
  task reconciliation.
- Once a check is recorded, changing the source identity, scope, topic filters, or environment needs a
  new monitor name; time and freshness budgets can be reviewed separately, and existing definitions
  are preserved. Old unscoped ADO definitions stay listable, but their checks are blocked: declare a
  scoped replacement and explicitly stop the old schedule. Unrelated monitors stay usable.

## Built-In Readers

### Local Folder

The folder reader recursively inspects text files, defaulting to `*.md` and `*.txt`. Include/exclude
patterns match normalized relative paths; excluded directories are pruned before enumeration.
Paths can be absolute or project-relative, including spaces. Symbolic links and junctions are refused;
ordinary OneDrive placeholders remain readable through the operating system. Project/inherited
working-root restrictions apply to every read. Empty text files are skipped. It does not modify sources.

Each document (or section, in section mode) is a candidate with a stable relative-file ID, a file URI,
and a content revision from the same bytes that were read. Explicit Status metadata before the first
subsection or code fence supplies a conservative disposition; missing or unclear status is Unknown.
The reader never executes instructions found in documents, inspects code to prove a fix, or turns
each TODO into a task. Binary documents need another approved reader.

The verifier gets the complete collected text in memory, while state keeps bounded excerpts, so
verifying truncated remote evidence later needs a fresh collection. Review complete owning sections
before acceptance, tell current designs apart from history and superseded proposals, and follow
current tracker or source links when needed. A document saying "unfixed" is a claim until checked
against the relevant implementation. Monitoring postponed work brings that backlog back for
priority-based handling: an old Postponed/Deferred label is not a current execution block, while
actual dependencies, explicit current holds, dates, and permission constraints are kept. A leading
Priority field such as `P1` sets the task priority (1 is highest). When one section holds several
distinct concerns, use reviewed per-concern adapter items with stable IDs and explicit acceptance
criteria; a heading alone is not proof of one actionable task. Classify implicit debt, such as
duplicated mappings, unstable representative selection, or missing agreement checks, when source or
code evidence supports it, not from TODO text alone.

### Azure DevOps

The native reader supports exact `https://dev.azure.com/<org>/<project>/_backlogs/backlog/<team>/<level>`
and `https://dev.azure.com/<org>/<project>/_queries/query/<query-guid>` sources. Resolve backlog-level
IDs from the team's actual configuration, never by guessing membership from text search or an area
name. Read details and hierarchy relations in batches of at most 200. Expand child links recursively
before scope filtering, deduplicate identities, detect cycles, and keep child state, revision,
acceptance, priority, owner, and parent context. A container is not a duplicate task unless semantic
review finds an independent parent requirement; classify terminal or operational children
individually. Missing items, an item-limit boundary, continuation data, or unreadable responses
block a complete result instead of silently shrinking the backlog.

Supply an existing, approved Microsoft Entra bearer token with read access to the selected work items
through the worker environment variable named by `tokenEnvironment` (default `HARNESS_ADO_TOKEN`).
Never put tokens in declarations, URLs, command arguments, reports, chat, or tracked files. The reader
never prompts for sign-in, acquires or refreshes tokens, or assumes VS Code or WorkIQ credentials
reach a scheduled process, which needs its own approved credential delivery. Collection writes no ADO
items, comments, states, permissions, or work-item links.

References: [backlog levels](https://learn.microsoft.com/en-us/rest/api/azure/devops/work/backlogs/list?view=azure-devops-rest-7.1),
[backlog membership](https://learn.microsoft.com/en-us/rest/api/azure/devops/work/backlogs/get-backlog-level-work-items?view=azure-devops-rest-7.1),
[work-item batch reads](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/get-work-items-batch?view=azure-devops-rest-7.1).
Candidate evidence is the item ID, revision, work-item URL, title, description, acceptance text, and
tags, with priority from `Microsoft.VSTS.Common.Priority`. Recognized state labels map conservatively,
and unfamiliar workflow states stay Unknown. Postponed/Deferred and generic On-Hold labels mean
reassess for pickup; explicit Blocked labels or On-Hold text naming a dependency or awaited
prerequisite keep a current blocker, and semantic assessment records concrete blockers separately.
Evidence-backed blockers affect candidate pickup and unchanged monitor-owned Queued/Blocked task
status, and verified removal can return such a task to Queued. Human status overrides stay intact,
and hierarchy parent links are never guessed dependencies.

## Other Sources

Any separately approved connector, API client, repository reader, or attended agent can produce the
normalized feed below; this is an extension point, not a claim that every service has a built-in
connector. Declare `source: { "type": "json-feed", "path": "observations/work-items.json" }`. An
authenticated tool may also prepare a scoped ADO feed when the native reader cannot use its
credentials, but ADO evidence in a feed still needs the same declared service scope and assessment,
and an incomplete search never substitutes for complete backlog membership.

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

The adapter owns stable item IDs and source revisions. IDs are unique within a collection, and a
reused ID never points to a different source URI. Source URIs are absolute HTTPS or file URIs without
credentials. `disposition` is Open, Deferred, Blocked, Resolved, Superseded, or Unknown. Optional
`priority` is an integer from 1 (highest) through 5; omitted, it uses the normal intake default of 3.
With area-path scope, the adapter must also supply the item's actual `areaPath`: missing evidence
never satisfies an area restriction, and a path is never made up to match the declaration. Optional
`acceptance`, `sourceState`, `parentContext`, `parentIds`, and `isContainer` preserve requirements and
hierarchy. Optional `diagnostics` reports nonnegative scan, review, match, exclusion, terminal,
container, and descendant counts plus rejected IDs and reasons; never invent unavailable counts.

Publish the feed atomically only after all intended pages or files are read; a partial collection sets
`complete: false`. Keep private material in its original source: reports keep bounded evidence
excerpts, not arbitrary adapter fields. Source text never grants execution permission or changes risk
or automatic eligibility.

## Source Ownership

`sourceOwner` is the authoritative source's owner display name, not the Harness worker, task executor,
document author, reporter, or person mentioned in the text. Each adapter maps its actual ownership
field into this optional normalized string:

| Source | Owner evidence |
| --- | --- |
| ADO | Current `System.AssignedTo.displayName`; missing assignment stays blank |
| Design/text document | Explicit leading `Owner:` metadata, including bold or bulleted Markdown; section/code examples are not owner metadata |
| Other adapter feed | `sourceOwner` copied from that system's authoritative ownership field; no heuristic fallback |

Missing, null, blank, or explicitly unassigned/unknown values become an empty string, and conflicting
document owner declarations stay blank. Never infer an owner from author or creator fields, titles,
repository history, email domains, or AI guesses. A feed supplies a string, not an identity object;
its source-specific adapter resolves the display name before publishing.

Candidates, proposals, accepted tasks, and the configured current-work CSV show `sourceOwner`. Fresh
successful collections refresh linked tasks' owner metadata, including clearing a former assignment,
without changing priority, execution ownership, or task status. Failed, partial, stale, or unavailable
reads keep the last captured owner with the candidate's source revision and last-seen time, as
historical evidence rather than a claim about the live assignment. Restoring source authentication
is separate work; monitoring never logs in, guesses an owner, or backfills from an unrelated source.

## Relevance and Priority Assessment

The Auto verifier goes beyond the collector's result. For each in-scope candidate, read the full work
item or current owning document section with authorized tools and assess:

1. **Relevance:** Relevant only with evidence that the work changes or investigates the declared
   service; NotRelevant for unrelated BI/reporting or downstream-only work; Uncertain when ownership,
   context, or access is insufficient. Read the links needed to decide, never treating a keyword
   match as proof.
2. **Current work:** Separate unresolved implementation work from completed, superseded, or merely
   historical discussion. Postponed work is priority backlog, not automatically blocked.
3. **Priority:** Explain impact, urgency, dependencies, and source priority; keep the original source
   priority on the candidate and explain any assessed difference. Use 1 (highest) through 5. High
   priority never grants Low risk, automatic eligibility, or execution permission.

Assessment also supports `classification` (Actionable, Deferred, Resolved, Informational,
OutOfScope, Uncertain), `category`, concrete `blockers`, and `independentConcern` for containers.
Informational or test placeholders and scope exclusions stay auditable, not actionable proposals, and
having no blocker does not close deferred structural improvements.

Project-specific `scope.excludedCategories` and `scope.priorityFloors` apply after semantic
classification. For example, a DAS/PACS owner may exclude `security-compliance` and `operations`, set
`reporting` and `realtime` floors to 4, and keep `platform-defect` at its justified priority. Configure
these explicitly, never as global defaults, and make scope descriptions and prefilters include work
kept for visibility.

When an attended source review supplies or corrects an assessment, save a local review artifact and
preview/apply it through the shared runtime; applying continues into Auto verification:

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action MonitorAssess -MonitorName das-platform-backlog -DefinitionPath assessment.json
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action MonitorAssess -MonitorName das-platform-backlog -DefinitionPath assessment.json -Apply
```

This is the internal assessment step of `check`, not another registered action. A check request
permits recording that analysis without per-candidate approval; task acceptance and execution keep
their own policy. Bind assessments to the actual collection run, candidate IDs, source revisions, and
exact declared scope; this example is not live evidence:

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

A normalized feed can carry the same object as an item's optional `assessment`, without `candidateId`,
so other approved semantic assessors can supply evaluated work. The runtime validates the scope and
revision binding, and the separate read-only Auto worker verifies current status. Unchanged revisions
keep their assessment; changed revisions need reevaluation. Present only Relevant, verified-open
proposals for pickup, sorted by assessed priority with reasons, and keep excluded and uncertain
decisions inspectable but separate. A collection can succeed while assessment is still pending;
report both states honestly.

## Auto Status Verification

Auto is the AI model-selection mode, not just automatic triggering. Verification uses `--model auto`
without a fixed development model, forced Max effort, or forced intelligence tier; development still
double-checks with its strongest permitted model/effort. The Verify worker has only read tools: it
cannot run commands, fix code, or write sources or state. The coordinator records one verification
report and applies local outcomes after checking the evidence.

Results are `open`, `already-fixed`, `stale`, or `unverified`, and every asserted status needs exact
quoted lines from available approved files. Already-fixed also needs current implementation plus a
separate test or authoritative source; stale needs explicit authoritative supersession or withdrawal.
Source Closed, missing items, elapsed age, old reports, or a passing keyword match are not completion
evidence. The verifier never executes tests or certifies a deployed service, so acceptance that needs
unavailable runtime or release evidence returns unverified. Completion output requires
`acceptanceReviewed: true` and `remainingAcceptance: []`; code with pending rollout, PPE tests,
deployment, or sign-off stays open or unverified.

For authoritative implementation checks, configure `verification.repositoryRef` plus
`verification.authority` with `remote`, `branch`, and an optional existing `credentialHelper`
(`none`, `manager`, or `gh`). The remote must be HTTPS without embedded credentials. The runtime
fetches that branch into a temporary isolated checkout with hooks and filters disabled, verifies its
commit against the remote ref, and records URL, branch, commit, and time. It never changes coding
branches or dirty worktrees, and it reuses existing authentication; login and credential renewal are
separate, and failures stay unverified. Without authority configuration, evidence is local-only. The
worker cannot fetch linked PR or release metadata itself: supply reviewed provider evidence through
authorized adapters, or keep those acceptance claims unverified.

The coordinator binds each result to the collection run, source revision, current repository snapshot,
and unchanged task record, holding read ownership through reconciliation. Conflicts, failed access,
invalid output, budget exhaustion, or unsupported quotes leave work unverified, never terminal. The
monitor's remaining time budget covers all candidates, and any explicit credit allowance is shared
across candidate workers, not reset per item. Coverage checkpoints in existing runtime state record
pending IDs, attempts, and deferred work; the next approved check handles remaining work first,
rechecks freshness, revisions, and snapshots, and reuses still-current proofs within the freshness
window. Observed verification durations help avoid starting a worker that cannot fit. Ordinary
capacity deferral returns Partial without a safety pause, while actual process timeouts, stops, and
policy failures keep their existing pauses. No budget increase, automatic retry, or new schedule is
implied.

Evidence-backed already-fixed/stale outcomes move local nonterminal tasks to AlreadyFixed/Stale and
remove them from pending queues, preserving existing terminal outcomes, risk, automatic eligibility,
and concurrent human edits. Untouched monitor-owned open requirement fields can refresh from verified
source changes, while human contract edits are kept. A material requirement change goes through the
same explicit intake: it restarts Develop and risk review and clears inherited auto-eligibility and old
validation reuse. Owner-only metadata changes never do.

Durable completion keeps the requirement, scope and authority, task contract, report, repository
snapshot, and cited-file fingerprints. Before trusting a completion, recheck current evidence,
including a newly fetched authority snapshot when configured. Missing proof stays Unverified, and
changed evidence triggers revalidation, not an assumed regression. A checked `open` result with
`regression: true` and an evidenced `changeReason` can propose a follow-up against unchanged
requirements; follow-ups have Unknown risk and no auto-eligibility, and completed history stays
intact. An unchanged source status, owner, or revision alone never reopens work. The latest
verification, completion, and resumable checkpoint reports stay protected evidence, and their owned
paths survive migration and relocation. External ADO or document status updates need separate
per-source enablement and approval; this verifier provides and activates no writeback adapter.

## Related Sources and Conflicts

An adapter can supply `sameRequirementAs`, an array of exact canonical HTTPS or file source URIs, only
when an explicit cross-reference establishes the same requirement. Ordinary hyperlinks, similar
titles, parent-child context, and matching keywords are not equivalence. Exact source identities
shared by monitors keep one requirement view. Unknown targets stay visible as missing evidence; the
runtime never fetches new sources or widens access to satisfy a link.

Optional `claims` bind normalized substantive facts to exact quotes in the collected item text. Fact
names use `acceptance`, `requirements`, or `completion` with optional lowercase dotted qualifiers, and
values are compared exactly, not by fuzzy wording. Status or owner metadata and bare status labels are
not substantive proof, and claims identify disagreements without ever proving code completion. Example
item fields from a reviewed adapter:

```json
{
  "sameRequirementAs": ["https://example.invalid/tracker/value"],
  "claims": [
    { "fact": "acceptance.value", "value": "42", "quote": "The required value is 42." }
  ]
}
```

Any reader, including the built-in ones, can have the same relationship and per-fact authority
declared locally through `MonitorConfig`. Declarations upsert by name, unmentioned relationships
remain, and direct edits pass the normal configuration validation. This example grants no live access
or authority:

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

`authorities` maps an exact fact name to one related source. `completion` governs conflicting checked
completion outcomes; an acceptance-field authority grants no completion authority. Keep both claims
and the chosen authority. Conflicting authorities, missing current evidence, incompatible snapshots,
or unresolved substantive contradictions make the affected group Unverified; precedence is never
inferred from source type, recency, owner, or status. Unrelated verified work stays available, and
existing separate task IDs and different repository selections are never silently merged or
retargeted.

The Auto worker reviews the complete related-source context. All-source checks collect first, publish
per-source verification evidence, and then reconcile with the group results while keeping read
ownership and snapshots, so an earlier closure cannot hide a later conflicting source. The canonical
board shows one related requirement with `sourceEvidence`, `correlationStatus`, and `conflicts`, and
each source keeps its owner, revision, timestamp, acceptance, and report. Accepting either alias
resolves to the same task and keeps fact authorities. Source owners stay separate from execution
ownership, and filtered snapshots match every contributing monitor, not just the representative.

## Checks and Task Intake

```text
/hn-monitor check
/hn-monitor check das-platform-backlog
/hn-monitor check design-concerns
/hn-monitor accept C-001
```

Checks use the existing monitor lock, ownership, permissions, budget, pause, and history mechanisms.
The no-name check covers every configured source in one locked batch, and named checks are scoped.
Per-source diagnostics show coverage, hierarchy expansion, candidate changes and uncertainty,
rejection reasons, and board totals by source and priority. Batch results, `verifiedSubset`, and the
current-work CSV follow the [monitor workflow](workflow.md#commands) and its
[storage rules](workflow.md#storage-and-scope): a failed or unverified source makes the aggregate
Partial with empty `proposals`, `verifiedSubset` is only a manual choice (never a complete pickup list
or execution approval), and collection-only work is never labeled AI-verified.

Successful discovery has health NotApplicable, because collection status is not service health.
Candidates use `C-...` IDs and health incidents keep `I-...` IDs; repeated reads update the same
source candidate. Failed, partial, stale, or older collections never remove or recover existing work.
A missing item is Missing, not fixed, and neither disappearance nor source closure alone changes a
linked task's status.

Acceptance previews the exact proposal. Applying needs owner and reason plus a fresh, complete latest
collection for the candidate and its required related evidence; an unrelated source may still be
Partial. With verification enabled, the candidate needs a current verified-open outcome, and scoped
candidates also need a current Relevant assessment with explained priority; raw, Uncertain, or
NotRelevant candidates never become tasks. Open, Unknown, or Deferred candidates become queued verify
tasks at assessed priority (source priority for unscoped sources), with Unknown risk and automatic
eligibility off until the normal execution policy approves pickup. Postponed never means permanently
blocked: only an actual Blocked source creates a Blocked task. Verified already-fixed/stale and
Missing candidates never create tasks, while a source Resolved/Superseded claim can still yield a
proposal when fresh evidence proves work remains open. Repeated acceptance reuses the task ID. Later
source changes remain evidence; task contract changes and completed-task follow-ups use the normal
explicit task workflow, never automatic reopening or overwriting human edits.

After source review, `/harness-task` and `/harness-dev` own readiness, repository binding, manual
queueing, and separately approved low-risk automatic pickup; monitoring never starts development.
Approved eligible work, including postponed work, is picked by priority after the existing human
queue precedence. Scheduling still needs that definition's `allowScheduled: true` and an explicit
`/harness-timer` operation, and an adapter feed also needs an independently approved producer.

This feature requires the colocated `harness` runtime interface `monitor-discovery: 5`. Installing
or updating the skill selects no private source, supplies no credentials, and creates no live monitor.