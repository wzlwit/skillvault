# Local Harness Runtime

The runtime uses PowerShell 7, Git, and the Copilot CLI. Read-only board commands, standalone
test flows, and named monitor checks do not need the CLI or model settings. Scheduled operation uses Windows Task Scheduler.
Installing skills does not initialize a project, start an agent, or register a schedule.

Harness bundles default to global availability. Explicit project installations remain supported
for pinned or customized copies. Keep sibling runtime dependencies in the selected scope. The
installation directory does not determine the target project: `-ProjectPath` still controls
configuration, state, boards, and execution policy. A task can explicitly select a different
coding repository through a reference. No existing installation or runtime data is moved
when a default changes.

The top-level topic is `harness`; specialized names, folders, and dependencies use `harness-*`.
`/hn` and `/hn-*` are conversational shorthand for the same topics, not separate registrations.
Old commands route to the corresponding operation. Bare multi-action topics use read-only `list`,
including harness-timer. Explicit dev/review work uses `run`. PowerShell
action names, stored state, and existing scheduler behavior are unchanged.

## Root Inheritance

`/harness root` shows the selected root without changing it. `/harness root <path>` selects the
existing parent directory for `.harness_sv/`. First selection or a required missing selection
prompts after displaying the absolute current project folder. `/hn-root <path>` uses the same
workflow without adding a second location prompt when Root is already selected.
No answer or an unavailable question tool/user selects that displayed `./` in session context
only; an explicit rejection or invalid path does not trigger fallback. The read-only
`Root` action reports the selected project, control/config, and board paths and initialized state.
Pass the selected absolute `-ProjectPath` so later terminal-directory changes cannot retarget it.
Only `Root` allows an omitted path, resolving the command's current directory without writes.

Every harness action reuses the selected Root without another location confirmation, including
`/harness init` and reconnects. The displayed `./` fallback is a selected Root too. The session derives
the absolute path and supplies `-ProjectPath` automatically; the user need not repeat it. Child
scripts do not discover editor context or store a second root registry. If no Root or explicit
target is available, run `/harness root ./` once before the action. Invalid targets and explicit rejection
block the action, not permission to fall back to an incidental terminal or installation directory.

An explicit action path overrides that invocation only; resolve relative paths against Root.
`/harness root <path>` validates and selects the requested new root, saving the previous root
separately. If that previous harness was initialized and the path changes, ask whether to move
its data with Yes: Move as the displayed default. Yes or no answer previews and applies relocation
from the saved previous root. An explicit answer or applicable user instruction overrides the
default; No, cancel, or an instruction not to move leaves the old controller and schedules in
place. The new Root remains selected in either case. A blocked
or failed move is reported separately and does not undo selection or imply a successful migration.
An invalid target leaves Root unchanged. The first-selection fallback never answers the move question.
An unchanged path or uninitialized source needs no move prompt. Selection never initializes a
controller. Scheduled ticks reuse their saved explicit target, not another session's Root.
`/harness loc --board <board-path>` retains its separate empty-board placement meaning.

No user-facing move flag is required. The session follows [Harness Root](./loc.md#explicit-relocation)
and uses the dispatcher with the saved previous root as `-ProjectPath`, `-Move`, and `-DestinationPath`
for a Yes answer, explicit move instruction, or the displayed unanswered-prompt Move default;
application adds `-Apply` after preview. Do not require a second Yes-only confirmation.
The destination must exist and be free of a controller. Identity, queues, pauses, external code,
board overrides, dirty registered worktrees, and schedule cadence are preserved. Existing policy
and host restrictions still apply. The PowerShell Root inspection action remains read-only;
the session owns the prompt and maps its answer to the existing helper controls.

The public `Init` action keeps `-ProjectPath <selected-root> -ConfirmLocation` and rejects
`-Scheduled`. The session supplies both automatically from the selected Root when Init is
requested, including after fallback; the flag acknowledges resolved location, not another user
prompt. Root inheritance is location selection, not blanket permission: operation-specific
approval, host permissions, policy denials, and safety pauses still apply. Selecting Root alone
does not request initialization, execution, installation, destructive changes, or a schedule.

## Configuration and State

`/harness init` creates `<project-root>/.harness_sv/config.json` and `state.json`. The state file owns
tasks, references, queue order, active phase, and run history. `current.csv`, `history.csv`, and
`references.csv` are generated views in the board root, which defaults to `<project-root>/.harness_sv`.
The existing decision register remains owned by `/harness-decision`. Do not edit generated views as
competing task queues. Existing unrelated CSV files are never adopted or overwritten.

Explicit `/harness-policy limits` and `/harness-policy fallback` declarations add `restrictions` and `fallback` sections
to that same configuration. Safety counters, pauses, and audit events use the state file's
`safety` object; there is no second controller or policy database. Bare policy commands are
read-only, including before initialization. Installing either guide applies no example policy.

Every action except read-only `Root` requires an explicit controller `-ProjectPath`. Resolve reference, configuration, and
policy paths against that project, never the installed skill directory. Task scopes and relative
test working directories apply to the selected coding workspace. Read-only status/context calls do not initialize missing state.
Use the existing project plan/ADR convention; ordinary actions move no documentation files.
Explicit Root relocation includes authored files already inside the control directory, not
external project documents. A moved controller saves `executionRoot` for its former implicit
coding/test target and original instruction lookup; absent means the current `projectRoot`.

## Artifact Storage

All harness-owned information and files default to `<root>/.harness_sv/`, where Root is selected
through `/harness root` (`/hn root`). An explicit user destination overrides the relevant output,
not the whole controller. Keep one authoritative copy; do not mirror records into the project root.

| Artifact | Default destination relative to Root |
| --- | --- |
| Configuration, task/link/run state, policy and safety state | `.harness_sv/config.json`, `.harness_sv/state.json` |
| Board views, decision register, and board ownership marker | `.harness_sv/current.csv`, `.harness_sv/history.csv`, `.harness_sv/references.csv`, `.harness_sv/decisions.csv`, `.harness_sv/.harness-board.json` |
| Run evidence, validation results, and captured command output | `.harness_sv/history/<run-id>.md` |
| Requested plans and specifications | `.harness_sv/docs/plans/` |
| Requested ADRs | `.harness_sv/docs/plans/decisions/` |
| Requested handoff/context notes | `.harness_sv/docs/handoffs/` |
| Authored policy, test, monitor, and runner declarations | `.harness_sv/definitions/` |
| New local reports, dashboards, queries, diagrams, and approved exports | `.harness_sv/artifacts/` |
| Store, runner, and decision lock files | `.harness_sv/store.lock`, `.harness_sv/runner.lock`, `<board>/decisions.lock` |
| Detached task worktrees when worktree mode is selected | `.harness_sv/worktrees/<task-id>/` |

Create only the files required by an authorized action, not this entire hierarchy on inspection
or installation. Runtime run reports already contain the available execution evidence; do not
invent a separate logs database or duplicate them. Any separately requested logs stay under
`.harness_sv/history/` unless the user specified another path. Worker output must still meet its
JSON contract; a worker must not edit controller state or generated views directly.

Pass the resolved output path to any delegated ADR, handoff, diagram, report, or other specialist
so its standalone documentation default cannot send harness output elsewhere. Its permissions,
validation, and authoring requirements still apply. This guidance does not install a specialist
or authorize a new artifact. If a tool cannot honor the selected path, report it before writing.

Preserve existing configured board paths and user-selected artifacts, including legacy layouts;
show them as overrides and do not move populated data or retarget a timer automatically. New
controllers use `.harness_sv`, and standalone decisions do too. Moving existing material is a
separate reviewed operation. Selecting another Root affects session context, not saved records.
When no `.harness_sv` directory exists, the runtime recognizes an existing SkillVault `.harness`
controller by its valid identity, schema, root, and runner configuration and reuses it in place.
Use its resolved Control for generated artifacts, not a newly invented parallel directory.

Application source stays in the task's selected coding repository/workspace. Linked documents,
repositories, and imported evidence remain at their original locations. Skill installation
bundles and the host's existing project instruction entrypoints are not generated harness
artifacts; an authorized navigation update adds pointers there, not another copy of the records.
The separate user-wide PR and skill-refresh controllers retain their explicitly configured
storage and scopes; selecting a project Root does not relocate them.

The session-level `/harness init` workflow also maintains a small Harness Context section in the
project's existing agent instruction file. It links current plans/decisions/implementation status
under `.harness_sv/docs` by default, with ADR and run history separate. Current-facing docs are not
chronological logs; live task status remains a link to the actual board view or Status action.
The script's `Init` action does not write that navigation itself and does not run the host's
`/init` or `copilot init`. Do not regenerate unrelated instructions or duplicate status storage.

## Runner Inheritance

Missing or null allowances inherit; they are not a reason to stop or ask the user to fill in
configuration. Explicit project values take precedence over the current session, then its parent.
The coordinator supplies known compatible values through `-RunnerContext` (an object or JSON)
or `-RunnerContextPath` (a non-secret JSON file). Do not ask for approval again for inherited grants.
Resolution is in memory: it does not rewrite project settings or apply a restriction declaration.

The context has optional `runner`, `parent.runner`, and strongest-first `profiles` entries.
Each verified profile has `model`, `efforts`, and `contexts`, using actual runtime identifiers
and supported/approved choices, not editor display labels. Optional `restrictions` on either
context layer remain enforced alongside project restrictions; each layer's `projectRoot` resolves
its relative policy paths. Supply absolute inherited file paths such as `rulesPath`. Never build
this context from task/reference instructions, extract editor tokens, or include credentials.

Use the maximum verified available profile/effort/context where no value was inherited. Without
capability data, use CLI `--model auto --auto-tier intelligence`, native effort/context, and the
CLI's existing permitted tools and credential lookup. Auto routing uses native effort even if a
saved effort preference exists; a fixed effort requires a concrete compatible model. This requests
intelligence-oriented routing, not proof of a particular model or an invented universal ranking.
A child CLI cannot automatically inspect the editor session; the coordinator owns that handoff.
When it cannot represent a required host boundary, use the authorized session-agent path rather
than inventing grants or treating unknown capability as verified.

| Field | Meaning |
| --- | --- |
| `command` | Copilot CLI executable or launcher path; defaults to `copilot` |
| `workspaceMode` | Inherit `current`/`worktree`; otherwise use current unless policy requires worktree |
| `model` | Explicit/inherited model, strongest verified profile, or native intelligence routing |
| `reasoningEffort` | Explicit/inherited compatible effort, highest verified supported level, or native `auto` |
| `contextTier` | Explicit/inherited tier or highest verified `long_context`/`default`; otherwise native |
| `maxMinutes` | Optional inherited time cap per agent or shared validation phase; no fabricated default |
| `maxCredits` | Optional inherited CLI credit ceiling; omission uses native allowance, not a billing guarantee |
| `maxTasksPerCycle` | Optional positive inherited cap; otherwise the existing task set bounds one invocation |
| `criticalReview` | Inherit the choice; otherwise enable the critical pass for maximum review coverage; explicit false is retained |
| `allowedTools` | Inherit approved CLI permission patterns; otherwise keep native grants without adding allow-all |
| `availableTools` | Inherit available CLI tool names; otherwise native availability, constrained by explicit policy |
| `validationCommands` | Inherit applicable executable/argument checks or discover supported repository test scripts |
| `rulesPath` | Optional explicit Rules Core file; otherwise project then global installation |

Blank strings and empty allowance lists add no local restriction. Missing values, JSON `null`,
`None`, and `Max` use inheritance, then maximum verified/native availability; lists containing
only those placeholders are treated the same way. Prefer omission or JSON `null` (`None`) when
writing configuration; `Max` is also accepted for resource allowances, not sent as a numeric cap.
Fresh initialization and effective views use `null`, not empty tool filters. These markers do not
clear concrete parent restrictions. Reasoning-effort `none` and `max` remain valid CLI levels,
not no-restriction markers for that field. Explicit positive numeric caps use the stricter parent/project value;
zero, invalid values, genuine denials, and unavailable prerequisites are not missing allowances.
Omitted time/credit caps do not become zero or arbitrary small limits. Native account/host limits
remain in effect; the harness does not claim to know the remaining quota. Reviews stay read-only.
No fixed model allowlist is installed from a screenshot or editor menu. For an intentional stop,
use the existing safety pause/stop workflow; empty configuration is not a deny-all control.

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action Context -RunnerContext $sessionContext
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action Dev -Id <task-id> -RunnerContext $sessionContext
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action Review -RunnerContextPath <session-context-file>
```

`Context` and `Restrict` inspection show effective allowances without saving them. The same
handoff applies to dev, review, tests, and monitoring. If checks are unset, validation first
looks for `scripts/test-all.ps1`, then a declared `package.json` test script (`npm test`). These
are actual executable checks, not a passing default; inherited restrictions still apply. With
no executable check available, continue validation through an authorized agent/tool path and
report it unverified until it runs. Missing allowance configuration must not create a false pass.

## Folder Controllers and Coding Repositories

The controller may be an ordinary folder without Git. Confirm it through `/harness init` as usual;
keep its `.harness_sv` configuration/state, board, queues, pauses, and reports there. Register an
existing local Git root using `Ref -Source <repository-path>`, then select its stable `R-*` ID
with `Task`, `UpdateTask`, or `Dev -RepositoryRef <id>` (alias `-RepoRef`). Requirements `-Source`
and coding `-RepositoryRef` are distinct. Task intake matches source/scope/reference tuples after
trimming outer whitespace, canonicalizing reference IDs and HTTP(S) URI syntax, and normalizing
absolute source-path dot segments. Preserve URL path/query, opaque source, path, and free-form
scope case and internal whitespace; a scope can contain code identifiers. No fuzzy matching.

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <controller-folder> -Action Ref -Source <local-git-root>
& <harness-folder>/scripts/harness.ps1 -ProjectPath <controller-folder> -Action Task -Title <title> -Text <requirements> -Scope <scope> -Acceptance <checks> -RepoRef <returned-reference-id>
& <harness-folder>/scripts/harness.ps1 -ProjectPath <controller-folder> -Action Dev -Id <task-id>
```

These examples do not approve risk, tools, budgets, or worker startup. Execute only after the
usual gates. A missing/inactive, URL-only, non-directory, non-Git-root, or another task's reference
blocks repository selection; there is no cloning, Git initialization, or first-reference fallback.
A task-scoped reference can be assigned to that task through UpdateTask after registration.
Without an explicit reference, development uses `executionRoot` after an explicit move, or the
controller-at-Git-root workflow otherwise. Relocation does not silently retarget queued tasks.
Use separate task records for different repositories, not an implicit multi-repository write.

Current mode operates in the selected checkout. Worktree mode uses that repository's HEAD to
create `<controller>/.harness_sv/worktrees/<task-id>`. Saved tasks retain `repositoryRef`, resolved
`repositoryRoot`, and workspace; a selected workspace cannot be retargeted. Resume checks that
a referenced worktree belongs to the recorded repository. Timed development uses each task's
saved selection. No live settings or schedules are created by reference registration.

Workers receive controller and coding-repository/workspace instructions. Validation and reviews
follow the same workspace; snapshots exclude only this controller's records, not unrelated code
paths with matching names. CSV views and reports carry repository identity. Controller-relative
`workingRoots` still apply to both source and workspace; a reference never extends permissions.
Controller locks remain local. Shared checkout ownership also excludes competing harness-managed
writers across controllers, for manual and scheduled execution. Separate worktrees remain separate
checkout resources; this does not serialize every worktree of one Git repository.

### Shared Ownership

The bundled ownership adapter uses the same-scope `skillvault-installation` helper. Participating
runtime manifests declare `ownershipProtocol: 1`. The user-wide registry defaults to
`~/.copilot/skillvault/ownership`; `SKILLVAULT_OWNERSHIP_ROOT` selects an explicit common root for
isolated environments and fixtures. All cooperating entrypoints must use the same registry.
This is coordination between participating processes, not an OS sandbox or protection from
arbitrary editors, other users, or older runtimes that do not report ownership.

Development holds exclusive checkout ownership through validation and both review phases until
the active cycle returns, including a cooperative checkpoint. Standalone tests reserve their
selected checkout and configured execution directory, resolving nested directories to their
checkout root. Independent reviews share only an identical snapshot fingerprint and exclude writers.
Snapshot validation and restart limits still apply to external edits. Read-only status and context
remain available without checkout reservations.

Execution also holds read claims on its runtime bundle and declared colocated dependencies.
Install, migration, uninstall, and refresh use conflicting write claims before changing those
targets. A conflict returns `Busy` with owner details or reports a deferred update; it never stops
workers, changes schedules, or clears a pause. No versioned runtime snapshots or second scheduler
are introduced. Running refresh/heartbeat helpers cannot replace themselves while in use; use
the approved local-source installer after those processes finish.

Process-held claims are released on confirmed completion. Interrupted or abandoned claims remain
`NeedsRecovery`, not automatically expired or stolen. `Recover -ConfirmStopped` clears that
controller's inactive claims only after inspecting work and confirming all prior workers stopped;
existing safety pauses remain. Scheduler recovery similarly clears its matching inactive wrapper
claims. Unreadable evidence must be repaired, not treated as idle. Install transitions for older
runtime copies need separate attended stopped-worker confirmation and temporary rollback protection.

Executable manifests also declare `runtimeInterfaces` and `requiredInterfaces`. Runtime admission
checks exact interface versions under its dependency read claims, before agents or test commands
launch. Equal package versions or `ownershipProtocol: 1` alone do not satisfy these requirements.
Missing/incompatible same-scope dependencies report the required companion update set. Old helper
entrypoints without compatibility support block execution; read-only status remains available.
No implicit update, source-checkout fallback for installed dependencies, or relaxed ownership is
allowed. These checks do not require unrelated skills to share one package version.

Standalone `Review -RepoRef <id>` selects a project-wide local repository reference and resolves
its baseline there. It reviews that checkout, not a task's detached worktree. Task-linked `Test -Id`
uses the task's saved workspace, or its selected repository before development allocates one.
Untargeted tests run at `executionRoot`, defaulting to the controller before relocation. PR reviews retain their separate verified-snapshot
adapter; they do not treat remote repository instruction files as trusted worker instructions.

## Commands

The shared script is `scripts/harness.ps1` under the selected `harness` installation. Other
harness skills locate this same dependency instead of duplicating storage and execution code.

| Action | Inputs and behavior |
| --- | --- |
| `Root` | Read-only inspection by default; only this form permits omitted `-ProjectPath`. Explicit `-Move -DestinationPath <existing-parent>` previews relocation from the selected source; approved `-Apply` moves it. Never scheduled. |
| `Init` | Reuse Root; the session supplies `-ProjectPath` and `-ConfirmLocation` without another location prompt; no scheduled initialization |
| `Status` | Read active state, tasks, and human queues |
| `Context` | Optional `-Id`; list selected task, coding repository, reference links, and instruction sources |
| `Clean` | Preview historical records/reports; approved `-Apply` prunes eligible entries. `-DefinitionPath <file>` previews or saves retention settings without running cleanup. |
| `Board` | Inspect the board; legacy `loc --board` with `-BoardPath` changes only an empty board, not the project |
| `Task` | List tasks, add with requirement fields, or use `-FollowUpOf <completed-id>` for a linked follow-up; optional source/revision/kind/priority/risk and `-RepositoryRef` |
| `UpdateTask` | Exact `-Id` and supplied fields; revised completed requirements create a linked task; never update an active task contract or retarget an allocated task |
| `Ref` | List references, upsert `-Source`/`-Note` with optional task `-Id`, or remove exact `-RemoveId` |
| `Dev` | Existing `-Id`, ad-hoc fields, or `-FollowUpOf`; shares task update/intake, then optional `-Mode now` or queue-only `next` |
| `Review` | Review ahead/working changes with optional `-RepositoryRef`, `-Scope`, `-BaseRef`, and `-SecurityReview`; one whole-repository Fresh pass when no new findings appear |
| `TestConfig` | Import explicit `-DefinitionPath` JSON declarations without executing commands |
| `Test` | List declarations, or run `-Flow` with optional `-TestEnvironment`, task `-Id`, and timer `-Scheduled` |
| `MonitorConfig` | Preview a `-DefinitionPath` declaration; apply with explicit `-Apply`, human `-Actor`, and `-Reason` |
| `Monitor` | Show saved monitors/proposals, or check one `-MonitorName`, optionally timer `-Scheduled` |
| `MonitorTask` | Preview an exact incident `-Id` proposal; explicit Apply/Actor/Reason accepts it as a manual-only investigation task |
| `Restrict` | Show policy; `-PolicyAction Declare -DefinitionPath <file>` previews a restriction replacement |
| `Fallback` | Show policy/pauses; explicitly Declare, Pause, Stop, or Resume through `-PolicyAction` |
| `Cycle` | Run the next eligible task and bounded pending human/resume work |
| `Recover` | Requires `-ConfirmStopped` after reviewing interrupted work and stopping prior workers |

Task intake never starts execution. Missing description/scope/acceptance yields `NeedsEvidence`.
Priority 1 is highest; risk and priority are separate. Timer pickup requires explicit
`-AutoEligible`, Low risk, and Queued status. Human queues remain ordered and do not bypass
readiness. Unknown/high-risk work needs a reviewed narrower scope, not an automatic risk downgrade.

Explicitly revised completed requirements create a new task linked through `followUpOf`, visible
in task state and `current.csv`. `UpdateTask -Id` and `Dev -Id` with changed requirement fields
reuse the same intake; `Task`/`Dev -FollowUpOf` can link a new request explicitly. Omitted requirement
fields inherit from the parent. An identical repeat reuses its task; a source revision alone does
not create work. Keep the original completion, snapshot, and report unchanged. The new task starts
at Develop with no inherited verdict, risk classification, or automatic eligibility. For the same
repository it retains the saved workspace/base, including unmerged work; another explicit repository
gets a separate allocation. No task-scoped reference is transferred to a different owner.

An ad-hoc `Dev` request is registered before execution. Without a mode, it starts when idle or
queues as `next` when busy. Explicit `next` only queues. `now` requests a checkpoint at the end of
the current agent or validation phase; it never kills that phase. Worktree mode can then pause
and switch. Current-checkout mode defers switching until the task finishes to avoid mixing edits.
Selection order is human now, interrupted work, human next, then eligible automatic work.
When a cycle budget is exhausted, remaining work stays queued for another explicit or scheduled run.

## History Cleanup

`/harness clean` owns history retention. Reuse the selected Root and preview before applying:

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <selected-root> -Action Clean
& <harness-folder>/scripts/harness.ps1 -ProjectPath <selected-root> -Action Clean -Apply
```

Use `/harness clean --policy <file>` to preview a retention declaration; add `--apply` only for
the approved settings. Map the file to `-DefinitionPath`; relative paths resolve against Root.
Declaring policy does not run cleanup or enable maintenance. History cleanup selects one
controller, not every project in the scheduler's registry.

The shared `harness-maintenance.ps1` implementation is also used by weekly maintenance. The timer
selects when to invoke it, not a different deletion algorithm. `/harness-timer clean` handles
stale schedules only. Historical skill/source-folder cleanup is never a retention target.

Default limits are **90d and 5,000 completed entries per harness**, across topics. Completion time
determines age, not file mtime. Prune oldest eligible entries beyond either bound. For count-only
set `maxAge` to null; for age-only set both count fields to null. Optional per-topic mode uses
1,000 per topic, for example:

```json
{
	"maxAge": "90d",
	"maxEntries": null,
	"maxEntriesPerTopic": 1000,
	"pinnedRunIds": []
}
```

Topics group development with its validation/review phases, standalone review, tests, monitors,
and PR review; each named flow does not gain another allowance. Preserve active/incomplete runs,
open-task evidence including completed ancestors of open follow-ups, pinned or linked reports,
current monitor readings, unresolved incidents,
policy/recovery evidence, and the latest comparable review. Report protected overages rather
than deleting required context to meet a count. Project `maintenance.enabled: false` opts out
of automatic history cleanup; explicit attended Clean remains separately available.

Clean authoritative run/PR state and corresponding owned report files as one logical operation,
then regenerate CSV views. Runtime locks and path checks protect active work and outside files.
Pending file removals survive interruption and are rechecked before retry; report `Partial`
until they finish. Clear expired pointers rather than leaving broken live references. Authored
plans, ADRs, decisions, evaluations, declarations, application code, linked sources, skill bundles,
and worktrees are excluded. A preview or policy declaration never deletes history.

Installation updates keep only the current copy after success. Their temporary originals protect
an in-progress transaction and are removed after success or verified rollback; unresolved failed
restoration must be reported, not discarded. There is no installation-archive retention policy or
weekly backup cleanup. This does not change harness run-history retention or interrupted-worker
recovery; `harness clean` continues to own only its recorded history and reports.

## Restrictions and Fallback

The `harness-policy` and `harness-policy` SKILL.md files own the field schemas, situation/response
tables, and usage examples. Policy changes preview unless given `-Apply`, a human `-Actor`, and
`-Reason`. They replace only the selected policy object, not runner/test configuration. Changes
require an idle runner and no unresolved active marker. They never clear an existing pause.

Restrictions validate the selected model, exact tool approvals/availability, development workspace
mode including saved workspaces, normalized working roots, test environments, and direct launchers.
Explicit CLI deny patterns are appended without removing review denials. Numeric caps take the
stricter limit for processes/shared flow budgets, per-agent CLI credits, and tasks per invocation.
Working roots and launcher allowlists are not filesystem, network, or subcommand sandboxes.
The CLI credit limit remains per session, not aggregate task spend or reliable billing accounting.

Fallback defaults to one additional attempt after five seconds for explicitly repeatable named test
steps with approved transient exit codes. There are no default transient codes and no numeric failure
threshold, so unclassified failures do not retry. A retry declaration may supply just `exitCodes`;
omitted count/delay use these defaults. Explicit values, including `maxRetries: 0`, are preserved.
Defaults resolve in memory without changing saved declarations. An optional declared
threshold counts consecutive failed attempts per `development`, `review`, `monitor:<name>`, or `test:<flow>:<environment>`
target, never log lines. Named flows share their target count across manual, scheduled, and post-dev
execution. Eligible retries use the existing step loop without repeated confirmation; attempts and
delays consume the original flow/validation budget. Earlier successful steps are not rerun. Agents
and legacy commands do not retry, and failed development tasks are not automatically requeued.

Actual timeouts pause the affected target. Detected restriction mismatches persist a project
stop/pause. An interrupted run requires reconciliation and recovery, with a durable pause on its
known target or the project when it cannot be identified. These are execution responses, not side
effects of installing or displaying a policy. The text adapter cannot reliably distinguish CLI
credit exhaustion from other CLI failures or detect every individual denied-tool event.

`Fallback -PolicyAction Pause -Target <target>` blocks subsequent execution boundaries while the
current process finishes. `Stop` also requests termination of the current runner's owned process
tree; it does not discover escaped/orphaned workers or roll back writes. `Resume` requires
`-ConfirmStopped` plus owner/reason/approval and clears only the selected pause. It starts no work,
enables no timer, and does not requeue failed tasks; already queued work may run on a later timer tick.
Project pauses cover every target, and clearing one does not clear narrower pauses. Safety pauses
are distinct from cooperative task checkpoints. Read-only context/status/decision views stay available.

## Reuse or New

One logical development/review task may involve multiple agents or schedules. Before launching
an additional instance or updating a matching one, inspect existing instances for the same
controller, task, repository/workspace, role, and purpose. Show their identity and status, then
ask **Reuse (singleton) or New?** unless the user already selected that choice for this request.
Recommend reuse for the same purpose; do not silently create duplicates or merge distinct roles.
If the choice is unanswered, leave existing instances unchanged and create no additional one.
This instance choice is separate from allowance inheritance and is not another permission prompt.

- **Reuse (singleton):** select the exact compatible owned instance. An active development task
	remains `AlreadyRunning`; do not launch a second writer or attach to an unknown process. Reuse
	an agent definition/profile where supported, not its old conclusions. Required independent
	Review/Critical/Fresh passes still use fresh reviewer context. A reused schedule keeps its
	stable identity; changing cadence or context is an update to that selected schedule.
- **New:** confirm its role, target/workspace, and distinct identity. Keep the same logical task
	association and separate agent/run/report identifiers rather than duplicating requirements.
	Use the selected host's supported agent-instance mechanism. Multiple read-only reviewers can
	share a fixed snapshot; simultaneous development writers require separate workspaces and an
	explicit integration plan. Preserve inherited limits, pauses, ownership, and required validation.

The choice does not remove the shared runtime's project run lock or singleton active-task record.
That script remains serialized; New does not make a second direct invocation concurrent. Use an
approved capable agent host for additional instances, or report the unsupported instance action
instead of bypassing the lock. Required pipeline review passes do not need this question again;
they are already part of the requested workflow, not accidental duplicate workers.

For schedules, compare purpose as well as identity and confirm reuse versus a distinct instance
before registration. Repeated ticks use their saved choice without prompting or creating another
timer. The dedicated user-wide PR-review timer remains a singleton for its entire watchlist;
this project-harness choice does not authorize duplicating that separate controller's timer.

The project timer helper implements `-InstanceMode Reuse` for the selected singleton or named
schedule, and `-InstanceMode New -InstanceName <name>` for create-only named schedules. The
unnamed singleton keeps its existing task identity; named copies append ` Instance <name>`.
Matching Set requests without a mode return `NeedsInstanceChoice` in preview and reject Apply.
Status lists matching instances and ownership. Select `-InstanceName` for named status/disable/
resume; cadence and context reuse come only from that exact instance. The initial unnamed
singleton can still be created when none exists. No schedule is created by editing these skills.

## Script Permissions and Agent Fallback

Before running scripts, the session/coordinator checks the exact executable, arguments, target
directory, side effects, applicable policy, and required tool approvals. Reuse existing approvals
without asking again. If a necessary approval is missing, use the host's supported permission
request before execution and limit it to that command and scope. A task request is not permission
to grant administrator access, change execution policy, clear a safety pause, or enable all tools.
Do not run a command known to need approval merely to rediscover the denial.

Separate missing authentication from denied tool/path access and incompatible launch settings.
Inspect available non-secret status and supported credential lookup, and correct invocation
mistakes within existing approvals. Do not copy tokens from editor storage or request secrets in
chat. Initiate a supported login flow when needed for the authorized task; ask the user only for
required browser sign-in, MFA, consent, or secret entry directly in the terminal. Do not silently
persist new permissions, budgets, models, or credentials. Actual worker execution, not Idle or a
successful login command alone, is needed to verify the worker path.

If scripts are unavailable or unsuitable, an attended session may use an agent fallback with
already authorized editor/agent tools for the same requested work. The current session may do
the work directly; delegate only when delegation is authorized. This is an alternative execution
method, not permission to repeat an explicit denial through another tool or agent. Preserve the
selected repository/workspace, task readiness and risk, model/effort and budget limits, read-only
review boundaries, validation requirements, and applicable restrictions and safety pauses.

Before fallback writes, confirm exclusive workspace ownership and that no active, scheduled, or
uncertain worker can compete. Preserve runtime lock/recovery rules; if ownership or a required
execution boundary cannot be established, limit fallback to permitted read-only investigation.
Do not restart a failed or timed-out worker through this route, reset its budget, or silently
retarget its task. Reconcile partial effects before any separately authorized continuation.

Report the agent fallback explicitly, what it changed, actual checks, and remaining blockers.
Run required checks through another approved test tool when available; code inspection is not
a substitute for execution. If validation or independent review cannot run, leave them unverified
and do not mark the task Completed. Use existing state/report helpers when available; otherwise
leave runtime state and generated CSV views unchanged and report that recording is pending.
Never invent a successful run, approval status, or report to make the fallback look script-run.

This recovery procedure is session-level guidance, not a new runtime action. Unattended timer
ticks never request interactive permissions/login, relax restrictions, or launch an unconfigured
fallback agent. They retain the existing failure/pause behavior until attended setup resolves
the prerequisite. This workflow does not itself implement automatic CLI authentication recovery.

## Worker Output

CLI transport and the agent's final result are separate contracts. The runner launches the CLI
with `--silent --output-format text --stream off`: response-only text with streaming disabled.
The prompt requires that final response to contain exactly one JSON object, with no prose or
Markdown fences. Text transport does not forbid JSON content or guarantee the model follows it.
The CLI's help defines `--output-format json` as JSONL, one JSON object per line; it is not an
instruction to produce the harness schema. Supporting that mode would require a separate,
tested transport/event parser rather than passing its stdout directly to the envelope parser.

Development returns an `outcome` (`ready`, `unsupported`, `already-fixed`, `stale`,
`needs-decision`, or `blocked`) and a non-empty string `summary`. Review, Critical, and Fresh
return a `verdict` (`clean`, `findings`, or `blocked`), a non-empty string `summary`, and a
`findings` array. A clean verdict requires an empty array; a findings verdict requires supported
findings with file, positive line number, and message. `ready` permits validation, not completion.

Nonzero exits are checked before parsing. Zero exit alone is insufficient: empty output,
arrays/scalars/null, malformed JSON, wrapped transport events, and invalid phase envelopes fail.
Preserve the outer JSON shape instead of unwrapping a single-item array. Do not extract apparent
JSON from arbitrary prose or treat CLI statistics as the worker result. Investigate missing
stdout together with launcher exit propagation and stderr, not by changing output format alone.

`Idle` returns before workspace selection and agent invocation because no eligible task was
selected. It is not evidence of successful CLI startup, authentication, model access, output
parsing, code validation, or review. A transport/parser fix needs a direct process/parser fixture
or an explicitly approved worker run that reaches that path. Report mocked versus live evidence,
actual exits, and parsed results separately. Never launch work or weaken readiness to replace an
Idle result with a success claim.

## Evidence and Recovery

Each task has development, validation, independent review, and optionally one critical-review
phase. The agent cannot mark the task Completed directly. Validation executes the configured
commands plus declared `testing.afterDev` flows, checking their real exit codes. Reviews are fresh
read-only sessions with writing, shell execution, and URL access denied and only `view`, `glob`,
and `grep` exposed. They return
structured findings bound to the captured code snapshot. Source changes invalidate clean verdicts.

The Git snapshot includes base/head, tracked diff, and Git blob identities for untracked inputs.
Harness-owned state/views are excluded. Each phase writes a local Markdown report. Worker result
JSON must match its contract; malformed output, missing evidence, CLI errors, or timeouts do not
count as success. Findings become `NeedsDecision`, not an unlimited automatic repair loop.

Completed means validation and required independent reviews passed in the assigned workspace,
with a report. It does not mean committed, integrated, merged, pushed, deployed, or operationally
verified. Linked follow-up development receives the parent's last report as evidence, never a
reusable clean verdict; the new task must complete its own validation and required reviews.

Standalone Review defaults to current ahead commits plus working changes. An explicit BaseRef
wins; otherwise use the merge-base with local `origin/develop` or the configured upstream.
Without either ref, the reported WorkingChangesOnly fallback uses HEAD; it does not claim ahead
coverage. No refs are fetched implicitly. Pin the resolved commit for the entire run and keep
PR reviews tied to verified PR base/head and explicitly scoped working changes.

The separate `pr-review` workflow owns remote PR selection and one user-wide watchlist/timer.
`/harness-review <PR-URL>` delegates there; its dispatcher calls `Invoke-HarnessReview` with an explicit
workspace, comparison commit, expected head, collected evidence, and approved runner profile.
Local defaults are unchanged. The dedicated user-wide controller owns state and safety gates;
target repositories are not initialized. Untrusted PR workers launch from that controller with
custom instructions disabled, stream their task/evidence through stdin, and read only the
isolated PR checkout. Complete PR snapshots do not exclude source paths named like harness
records. No source scripts, hooks, builds, tests, or remote publication are authorized.

A completed standalone pass with no new findings triggers one fresh independent whole-repository
pass, even when earlier findings are repeated. Newness compares exact file/line/message keys with
the last completed review of the same repository reference/root, scope, baseline, and security mode. Wording/line changes
count as new. Prior reports are comparison evidence, not accepted current findings or an issue
resolution register. Keep the union of findings from both passes on the same stable snapshot;
never erase them merely because the second pass is clean. Fresh covers the whole selected
repository, including unchanged source, configuration, and tests. Ordinary Review and development
Critical remain change-scoped. Preserve explicit restrictions and existing budgets; insufficient
repository coverage is blocked, not clean. No other repository or implicit fetch is authorized.
Pass outputs identify each requested scope without claiming unperformed coverage.

The attended coordinator repeats Changes -> Full around the existing dev/proposal workflow.
Findings from either pass are published as a checkpoint; the script returns and releases its run
lock so dev can fix and validate. Resume the same review request from Changes after fixes, without
requiring another user invocation or introducing a second fixer, notifier, or scheduler. Recheck
earlier unresolved findings against current code, including those outside the diff. A clean Full
pass cannot erase a supported issue from Changes. No new findings triggers Full, not completion.
The result and run's review metadata set `complete` only for a stable clean two-pass round with
zero supported findings; unresolved findings return `complete: false` and `nextPhase: Review`.
Do not spin reviewers on unchanged code while waiting. Missing fixes or validation remain pending;
unavailable coverage, failures, explicit budgets, and stop/pause requests still block continuation.

Local snapshot changes during Review or Fresh automatically restart at Review with the updated
snapshot and a new context, retaining the original pinned base, repository, scope, and restrictions.
Superseded attempts are archived in the same report and excluded from current findings. Allow two
restarts within a script round, at most six attempted sessions; further changes return `Partial` with no current verdict,
not a failure-counter increment or automatic safety pause. Actual worker errors, timeouts, stable
blocked results, and pauses do not restart. Isolated PR/ExpectedHead reviews remain pinned and fail
on snapshot changes. The `passes` and `restarts` result fields report attempted sessions and actual
restarts. Each session retains its configured limits; outer budgets are not extended. Development's
separate `runner.criticalReview` gate is unchanged.
These per-round churn limits do not cap rounds resumed after completed fixes. A scheduled or
one-shot script returns a checkpoint to its existing coordinator; it does not start a waiting daemon.

Optional `Review -SecurityReview` loads project/global installed `differential-review` guidance
and explicitly supplies it to both reviewers without copying it into the harness bundle. Missing
requested guidance blocks; installation is separate. The specialized guide adds security reasoning,
not tools, scanner integration, remote access, or a third worker. Reports identify the guidance
source and include findings, baseline, pass outputs, and comparison details. Compact comparison
data stays in existing run rows; reports and earlier findings are not overwritten.

Worktree mode uses a detached workspace at `<controller>/.harness_sv/worktrees/<task-id>` and leaves changes there
for review and handoff; it does not commit, merge, or delete the workspace. Fresh worktree allocations
use committed input; same-repository linked follow-ups reuse the saved workspace instead. Current
mode can include unrelated uncommitted input only through explicit
`-UseWorkingChanges`. Preserve user edits and report the resulting workspace and evidence.

Exclusive process locks serialize state updates and all development, independent review, test, and monitor runs. A process exit without a
recorded phase outcome blocks further execution until explicit recovery; do not assume its child
worker stopped. Inspect the report/workspace and confirm prior processes have stopped before
`Recover -ConfirmStopped`, then explicitly resume the safety pause and separately requeue a failed
task when appropriate. Recovery preserves pauses and reports. No hidden retry erases failure history.

For a session transfer after blocked development, review, testing, or monitoring, the session agent
may offer `/handoff` to preserve the existing outcome, evidence, blocker, observed process/pause
state, and first next action. Only an explicit request authorizes writing the note. Required safety
actions come first; the note does not clear markers/pauses or start another worker. This is optional
session guidance, not a runtime action, worker-context injection, or new behavior on timer ticks.

These are coordination controls, not a security sandbox. Workers and validation commands run as
the configured OS user. A Git worktree is not process or credential isolation. Use an appropriately
restricted account/environment for unattended work, review tool permissions, and do not place
production credentials in the worker environment. Shell permissions must be scoped deliberately.

## Timers

The `harness-timer` bundle calls the shared runner. Keep it alongside `harness` in the same install
scope. Bare `/harness-timer` uses read-only `list`. Its Set/Disable/Resume/Clean/Migrate operations
preview unless given `-Apply` for the approved selection/policy. One current-user heartbeat owns OS
timer changes; logical project schedules live in the resolved Control's `schedules.json` under
`schedules.lock`. The central registry and latest job receipts use `~/.copilot/skillvault/scheduler`.
Allowance inheritance and all worker gates remain unchanged. Installation/editing creates no live timer.

Timer setup accepts `-RunnerContextPath`, records the absolute non-secret path in its scheduled
command, and reuses it on later Set/Resume when omitted. Use Set to change the path. Each tick
loads that context; it does not assume an editor session exists. With no context file, use project
values and native CLI settings. Keep the file available and update verified capabilities through
the owning session, never through task text. Setup/resume still honor explicit policy and pauses.
Known inherited/native worker caps still apply. The heartbeat only dispatches and returns; its
short OS execution limit does not cut off a separately running approved worker. The user must be
signed in; no elevation, saved password, or machine wake is enabled.

`e2e` and `dev` select `Cycle` and share the original development task identity. This composes rules,
context/policy checks, eligible task selection, development/fix/verification, declared validation
and tests, independent review, and report/board updates. It does not invoke every slash command
on each tick: setup, task intake, policy changes, Graphify installation, interviews, and human
decisions remain attended/explicit workflows. No eligible task means Idle, not invented work.

`-Topic review` creates an independent review timer for ahead commits and working changes using
the default comparison selection and one fresh pass when nothing new is found. Local snapshot
restarts follow the bounded rule above, independently of the development critical-review setting.
Existing legacy OS time limits are retained and can bound restart time; they are not increased implicitly.
`-MonitorName <name>` selects a declared monitor with its own scheduled approval, budget, pause
target, and `Monitor -Scheduled` action. It is separate from legacy monitor command-flow schedules,
which are not migrated or replaced automatically. No AI settings or automatic task intake is needed.
`-Topic test`, legacy `monitor` flow mode, or another safe topic name uses `-TestFlow` and optional
`-TestEnvironment` (aliases `-Flow`/`-Environment`).
These use the existing declared Test executor, scheduled-environment approval, evidence, and
flow/environment safety target; a topic label does not install a monitoring service or grant
access. Topic timers have distinct names. Legacy `-TestFlow` without a topic still means `test`.

New durations require `m/h/d/n/y`: decimal fixed units or whole calendar units, anchored start-to-start.
Legacy IntervalDay still means fixed days. An explicit interval wins; otherwise Set reuses the exact
saved cadence. Missing cadence requires a user choice. First execution is one interval later;
migration preserves the old next run. Missed ticks coalesce and same/conflicting workspace jobs do
not overlap. Disable stops future ticks, not workers; resume retains cadence and required recovery.
Only owned selected jobs and approved legacy definitions are managed; unrelated tasks are unchanged.
Status includes any safety pause. Set/resume preflight rejects a paused target; externally enabling
a Windows task does not clear the runtime pause, and subsequent ticks still skip execution.

Maintenance is opt-in and runs once during Saturday 08:30-09:00 in its saved local timezone.
It checks stale schedules and delegates history work to [History Cleanup](#history-cleanup),
honoring each project's automatic-cleanup opt-out and active-work locks. Routine cleanup is
scripted; wake and AI are conditionally permitted for concrete needs, without activating either
by permission alone. No remote scan or catch-up occurs outside the window. The installed
harness-timer scheduler guide owns cadence, duration, and schedule-migration details.

## Test Flows

`harness-test` owns user guidance for `testing.environments`, `testing.flows`, and `testing.afterDev`.
The shared `harness-tests.ps1` implementation stays in this bundle so standalone tests, timers,
and post-development validation use the same executor. Existing config without `testing` keeps
working with legacy validation commands; initialization starts with empty test definitions.

Declarations upsert environment/flow names and replace `afterDev` only when supplied. No tests
execute during declaration. Runs preflight directories, required variable names, commands, and
positive flow budgets. Child-process variables do not mutate the runner's environment. Unrecovered
failures stop the flow; optional `repeatable: true` permits only the explicitly declared fallback
retry policy. Unavailable prerequisites are Blocked and paused targets report PolicyPaused. A declared environment is not automatically
provisioned or a guarantee that a separately running service matches the current source snapshot.

Task-linked tests resolve their repository reference and reuse the saved workspace when present;
they do not allocate worktrees or complete development. Declarations/reports stay in the controller.
All post-dev flows must pass before review, for development, fix, and verify tasks. The existing
validation-phase budget, when supplied or inherited, bounds legacy commands and named flows together. Scheduled development
passes `-Scheduled` and requires the target environments' explicit `allowScheduled` permission.

A test timer selects `-TestFlow <flow> -TestEnvironment <environment>`. This creates a separate
project/flow/environment task that calls `Test -Scheduled`, with the flow's own timeout and no AI
worker. Resume revalidates current configuration; disable can target removed definitions by both
saved names. Test timers and ad-hoc tests share the development run lock. A busy run is reported,
not forcibly interrupted or silently queued. Reports and history rows carry flow/environment data;
no second test-state store or automatic task creation is involved.

## Monitoring

The `harness-monitor` guide owns declarations and observation format. The shared `harness-monitor.ps1`
uses `config.monitoring.monitors` for definitions and `state.monitoring` for latest checks and
incident episodes. Older configs without monitoring read as an empty set; no live monitors or
thresholds are initialized by installation or read-only display. MonitorConfig previews then
upserts by name on explicit approval. Existing test/runner configuration is unchanged.

The first collector reads a local JSON file through a bounded `pwsh` process using the common
run lock, restrictions, and pause/stop controls. One object supplies resource/environment/metric,
finite numeric value, explicit-zone timestamps, and the declared window. Compare the metric to
the explicit breach condition only after checking identity, window duration, data age, and
previously accepted window order. Structured exports from online queries/dashboard measures need
separately reviewed producers; this runtime does not install or authenticate provider connectors.

Collection status and health are separate: a valid breach is Succeeded/Unhealthy. It opens or
reuses one episode without counting as a monitor failure. Fresh healthy data records recovery;
Unknown from stale/missing/invalid inputs or failed collection cannot close an episode. Actual
collection failures use fallback counters and timeouts pause `monitor:<name>`. No automatic
monitor retry is added. Monitoring should not pause because its observed service stays unhealthy.

Default response proposes an investigation; report-only suppresses the proposal. Explicit
MonitorTask acceptance requires fresh latest Unhealthy evidence, reuses task/reference helpers,
and deduplicates by the incident source identity. New tasks are verify/Unknown/manual-only. An
accepted task is neither executed nor completed by monitoring, and recovery does not prove a fix.
Checks update incident evidence and its reference note rather than changing a task's contract.
Reports use the existing board history directory, with monitor/health columns in history.csv.
Full telemetry stays at its source; saved report data excludes arbitrary extra JSON fields.

Report/query/dashboard authoring belongs to the session-level `harness-report` workflow
below, not this observation evaluator. Automatic task intake and live source/cadence/condition
choices still require separate approval.

## Report Authoring

`harness-report` coordinates report, dashboard, and query creation with the reusable
`kpi-dashboard` companion and one selected platform workflow. It adds no ReportCreate
PowerShell action, renderer, connector installation, task store, or timer. Missing requirements
are clarified before authoring; design-only work does not initialize the runtime.

Tracked local implementation reuses Dev intake, approved runner settings, workspace/permission
boundaries, validation, and review. Relevant specialist guidance must be supplied to the worker
explicitly. The CLI does not inherit the editor's live platform tools; unsupported routes remain
blocked or need separately authorized attended work, not an implicit second writer or wider access.
Report artifacts retain their stable destination/ID, and delivery distinguishes design-only,
created, validated, published, and partial/blocked outcomes with real evidence. Publishing and
optional JSON-export handoff to Monitor retain separate approvals; no existing timer changes.