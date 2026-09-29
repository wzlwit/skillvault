# Local Harness Runtime

The runtime uses PowerShell 7, Git, and the Copilot CLI; scheduled operation uses Windows Task
Scheduler. Read-only board commands, standalone test flows, and numeric health checks need no CLI or
model settings, and discovery status verification uses the CLI's model `auto` mode. Installing
skills does not initialize a project, start an agent, or register a schedule.

Harness bundles default to global availability; explicit project installations remain supported for
pinned or customized copies, with sibling runtime dependencies in the same scope. The installation
directory never selects the target: `-ProjectPath` controls configuration, state, boards, and
execution policy, and a task can select another coding repository through a reference. Changing a
default moves no installation or runtime data.

The top-level topic is `harness`; specialized topics use `harness-*`, and `/hn` and `/hn-*` are
conversational shorthand, not separate registrations. Old commands route to the matching operation.
Bare multi-action topics use read-only `list`; explicit dev/review work uses `run`. PowerShell action
names, stored state, and scheduler behavior are unchanged.

## Root Inheritance

`/harness root` shows the selected root; `/harness root <path>` selects the existing parent directory
for `.harness_sv/`. Prompts, the displayed `./` fallback, and moving an initialized harness to a new
root follow [Harness Root](./loc.md); `/hn-root <path>` uses the same workflow. The read-only `Root`
action reports the selected project, control/config, and board paths and initialized state. Only
`Root` may omit `-ProjectPath`, resolving the current directory without writes.

Every harness action reuses the selected Root without another location confirmation, including
`/harness init`, reconnects, and the displayed `./` fallback. The session supplies the absolute
`-ProjectPath`, so later terminal-directory changes cannot retarget it; child scripts neither read
editor context nor keep a second root registry. If no Root or explicit target exists, run
`/harness root ./` once first. Invalid targets and explicit rejection block the action; they never
fall back to an incidental terminal or installation directory. An explicit action path overrides that
invocation only, resolved against Root. Scheduled ticks reuse their saved explicit target.
`/harness loc --board <board-path>` keeps its separate empty-board placement meaning.

The public `Init` action takes `-ProjectPath <selected-root> -ConfirmLocation` and rejects
`-Scheduled`; the session supplies both from the selected Root without another prompt. Root
inheritance is location selection, not blanket permission: operation-specific approval, host
permissions, policy denials, and safety pauses still apply. Selecting Root alone requests no
initialization, execution, installation, destructive change, or schedule.

## Configuration and State

New `/harness init` controllers use layout version 2. `config/project.json` owns identity and runner
settings; `config/monitors.json`, `config/tests.json`, and `config/policy.json` own their domains, and
`config/schedules.json` holds project schedules when configured. These declarations are the single
editable source of truth: commands update the same files, direct edits need no import, and the runtime
combines a validated set only in memory. Missing, malformed, or conflicting declarations block the
next operation; no old copy is used. An in-flight operation keeps its validated configuration and can
record its outcome; the next operation loads the current declarations. Pause/stop stays live even with
an invalid declaration.

`runtime/state.json` owns tasks, references, queue order, active phase, run history, and the `safety`
object (counters, pauses, and audit events); `runtime/schedules.json` holds schedule progress. The
configured current-work CSV, `history.csv`, and `references.csv` are generated views in the board
root, `<project-root>/.harness_sv/board` by default; do not edit them as competing task queues.
`/harness-decision` owns the decision register, and an existing standalone register keeps its board
location on first initialization. Unrelated CSV files are never adopted or overwritten. A README links
to board, history, and configuration without copying task rows.

New controllers save `currentFileName: "current-<project-slug>.csv"`, stable across Root relocation;
configurations without it keep `current.csv`. `Get-HarnessCurrentPath` and the `current` result
property expose the resolved path. Renames and opt-in topic snapshots follow the
[current-view procedure](loc.md#current-view-names), never an implicit reconnect migration.

`/harness-policy` declarations add `restrictions` and `fallback` to `config/policy.json`; there is no
second policy database. Bare policy commands are read-only, even before initialization, and
installing a guide applies no example policy.

Resolve reference, configuration, and policy paths against the controller, never the installed skill
directory. Task scopes and relative test directories apply to the selected coding workspace.
Read-only status/context calls do not initialize missing state. Follow the project's plan/ADR
convention; ordinary actions move no documentation. Explicit Root relocation moves authored files
inside the control directory, not external documents, and saves `executionRoot` for the former
implicit coding/test target and instruction lookup (absent means the current `projectRoot`).

Legacy flat controllers remain readable and runnable in place until explicit migration; `init` only
reconnects. Transaction originals exist only in OS temporary storage until success or verified
rollback; interrupted updates keep a pending marker.

## Layout Migration

`/hn migrate` (or `/harness migrate`) previews in-place conversion; approved `--apply` maps to:

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action Migrate -Apply
```

Preview exact source/destination paths before approval. This is not Root relocation to another parent
or timer migration of OS tasks, and it never runs on a schedule or implicitly during Init. Refuse
active/unrecovered work, conflicting destinations, actual filesystem links, ambiguous schedule
ownership, or conflicting old declarations. Preserve identities, task statuses, queues, pauses, report
bytes, explicit external boards, and schedule anchors and cadence; owned reports move to monthly names
with their stored links. Custom adapters, snapshots, unrelated files, and external documents stay in
place and are never rewritten or deleted automatically; inspect adapter path assumptions before
applying. A failed update restores originals; if restoration fails, keep `migrate.pending.json` and
its temporary originals for attended recovery.

## Artifact Storage

All harness-owned information and files default to `<root>/.harness_sv/`, where Root is selected
through `/harness root` (`/hn root`). An explicit user destination overrides the relevant output,
not the whole controller. Keep one authoritative copy; do not mirror records into the project root.

| Artifact | Default destination relative to Root |
| --- | --- |
| Authoritative project, monitor, test, policy, and schedule declarations | `.harness_sv/config/` |
| Task/link/run state, safety state, and scheduler progress | `.harness_sv/runtime/state.json`, `.harness_sv/runtime/schedules.json` |
| Board views, decision register, and board ownership marker | `.harness_sv/board/` |
| Canonical current-work view for new controllers | `.harness_sv/board/current-<project>.csv` |
| Explicitly requested filtered board snapshots | `.harness_sv/artifacts/board-views/current-<project>-<topic>.csv` |
| Run evidence, validation results, and captured command output | `.harness_sv/history/YYYY-MM/<UTC-timestamp>-<topic>-<run-id>.md` |
| Requested plans and specifications | `.harness_sv/docs/plans/` |
| Requested ADRs | `.harness_sv/docs/plans/decisions/` |
| Requested handoff/context notes | `.harness_sv/docs/handoffs/` |
| Other workflow definitions and approved adapter scripts | `.harness_sv/definitions/`, `.harness_sv/adapters/` |
| New local reports, dashboards, queries, diagrams, and approved exports | `.harness_sv/artifacts/` |
| Store, runner, schedule, and decision lock files | `.harness_sv/runtime/locks/`, `<board>/decisions.lock` |
| Detached task worktrees when worktree mode is selected | `.harness_sv/worktrees/<task-id>/` |

Create only the files an authorized action needs, not this whole hierarchy. Run reports already hold
the execution evidence; do not add a logs database or duplicate them, and keep separately requested
logs under `.harness_sv/history/` unless the user chose another path. Workers return their JSON
result and never edit controller state or generated views directly.

Pass the resolved output path to any delegated ADR, handoff, diagram, report, or other specialist so
its own documentation default cannot send harness output elsewhere. Its permissions and validation
still apply; this installs no specialist and authorizes no new artifact. If a tool cannot honor the
path, report that before writing.

Existing configured board paths and user-selected artifacts, including legacy layouts, are shown as
overrides; populated data and timers are never moved or retargeted automatically. Moving existing
material is a separate reviewed operation, and selecting another Root changes session context, not
saved records. Without a `.harness_sv` directory, a valid existing SkillVault `.harness` controller
(identity, schema, root, and runner configuration) is reused in place, and its Control holds
generated artifacts.

Application source stays in the task's selected coding workspace, and linked documents, repositories,
and evidence stay where they are. Skill bundles and the host's project instruction files are not
harness artifacts; an authorized navigation update adds pointers there, not record copies. The
user-wide PR and skill-refresh controllers keep their own storage; selecting a Root does not move them.

The session-level `/harness init` workflow maintains a small Harness Context section in the project's
agent instruction file, linking current plans, decisions, and implementation status under
`.harness_sv/docs`, with ADRs and run history separate. Current-facing docs are not chronological logs;
live status stays a link to the board view or Status action. The script's `Init` action neither writes
that section nor runs the host's `/init` or `copilot init`, and unrelated instructions and status
storage are never regenerated or duplicated.

## Runner Inheritance

Missing or null allowances inherit; they are not a reason to stop or ask for configuration. Explicit
project values take precedence over the current session, then its parent. The coordinator supplies
known compatible values through `-RunnerContext` (an object or JSON) or `-RunnerContextPath` (a
non-secret JSON file), and inherited grants need no new approval. Resolution happens in memory: it
does not rewrite project settings or apply a restriction declaration.

The context has optional `runner`, `parent.runner`, and strongest-first `profiles`. Each verified
profile lists `model`, `efforts`, and `contexts` using actual runtime identifiers and approved
choices, not editor display labels. Optional `restrictions` on either layer stay enforced alongside
project restrictions, with relative policy paths resolved against that layer's `projectRoot`. Supply
absolute inherited paths such as `rulesPath`. Never build the context from task or reference text,
extract editor tokens, or include credentials.

Use the maximum verified available profile/effort/context where nothing was inherited. Without
capability data, use CLI `--model auto --auto-tier intelligence` with native effort/context, tools,
and credential lookup. Auto routing uses native effort even when an effort preference is saved; a
fixed effort needs a concrete compatible model. This requests intelligence-oriented routing, not a
particular model or a universal ranking. A child CLI cannot inspect the editor session, so the
coordinator owns the handoff; when the CLI cannot represent a required host boundary, use the
authorized session-agent path instead of inventing grants or treating unknown capability as verified.

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
`None`, and `Max` use inheritance, then maximum verified/native availability; lists holding only
those placeholders count the same. Prefer omission or `null` when writing configuration; `Max` is
accepted for resource allowances and never sent as a numeric cap. Fresh initialization and effective
views use `null`, not empty tool filters. These markers do not clear concrete parent restrictions,
and reasoning-effort `none` and `max` remain ordinary CLI levels. Explicit positive numeric caps use
the stricter parent/project value; zero, invalid values, denials, and unavailable prerequisites are
not missing allowances. Omitted caps never become zero or small arbitrary limits, native account and
host limits still apply, and the harness does not claim to know remaining quota. Reviews stay
read-only. No model allowlist comes from a screenshot or editor menu, and empty configuration is not
a deny-all control; use the safety pause/stop workflow to stop work.

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action Context -RunnerContext $sessionContext
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action Dev -Id <task-id> -RunnerContext $sessionContext
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action Review -RunnerContextPath <session-context-file>
```

`Context` and `Restrict` inspection show effective allowances without saving them, and the same
handoff applies to dev, review, tests, and monitoring. With no configured checks, validation looks for
`scripts/test-all.ps1`, then a declared `package.json` test script (`npm test`); inherited restrictions
still apply. With no executable check, continue through an authorized agent/tool path and report
validation unverified until it runs; missing configuration never yields a false pass.

## Folder Controllers and Coding Repositories

The controller may be an ordinary folder without Git; initialize it through `/harness init` and keep
its `.harness_sv` configuration, state, board, queues, pauses, and reports there. Register an existing
local Git root with `Ref -Source <repository-path>`, then select its stable `R-*` ID through `Task`,
`UpdateTask`, or `Dev -RepositoryRef <id>` (alias `-RepoRef`). Requirement `-Source` and coding
`-RepositoryRef` are distinct; task matching follows `harness-task` (exact after meaning-preserving
normalization, never fuzzy).

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <controller-folder> -Action Ref -Source <local-git-root>
& <harness-folder>/scripts/harness.ps1 -ProjectPath <controller-folder> -Action Task -Title <title> -Text <requirements> -Scope <scope> -Acceptance <checks> -RepoRef <returned-reference-id>
& <harness-folder>/scripts/harness.ps1 -ProjectPath <controller-folder> -Action Dev -Id <task-id>
```

These examples approve no risk, tools, budgets, or worker start; the usual gates still apply. A
missing, inactive, URL-only, non-directory, non-Git-root, or another task's reference blocks
repository selection; there is no cloning, Git initialization, or first-reference fallback. A
task-scoped reference can be assigned to its task through UpdateTask. Without an explicit reference,
development and untargeted tests use `executionRoot` after a move, otherwise the controller (a Git root
for development), and relocation never silently retargets queued tasks. Use separate tasks for
different repositories. Standalone `Review -RepoRef <id>` reviews that reference's checkout, not a
task's worktree, and task-linked `Test -Id` uses the task's saved workspace or selected repository.

Current mode works in the selected checkout; worktree mode creates
`<controller>/.harness_sv/worktrees/<task-id>` from that repository's HEAD. Saved tasks keep
`repositoryRef`, `repositoryRoot`, and a workspace that cannot be retargeted, and resume checks that
the worktree belongs to the recorded repository. Timed development uses each task's saved selection,
and registering a reference creates no settings or schedules.

Workers receive controller and coding-repository instructions; validation and reviews use the same
workspace, and snapshots exclude only this controller's records, not code paths with similar names.
CSV views and reports carry repository identity. Controller-relative `workingRoots` apply to source
and workspace, and a reference never extends permissions. Controller locks stay local, while shared
checkout ownership also excludes competing harness-managed writers across controllers, manual or
scheduled. Separate worktrees are separate checkout resources, so one repository's worktrees are not
serialized together.

### Shared Ownership

The bundled ownership adapter uses the same-scope `skillvault-installation` helper, and participating
runtime manifests declare `ownershipProtocol: 1`. The user-wide registry defaults to
`~/.copilot/skillvault/ownership`; `SKILLVAULT_OWNERSHIP_ROOT` selects a common root for isolated
environments and fixtures, and all cooperating entrypoints must share it. This coordinates
participating processes only; it is not an OS sandbox or protection from arbitrary editors, other
users, or older runtimes that do not report ownership.

Development holds exclusive checkout ownership through validation and both review phases until the
active cycle returns, including a cooperative checkpoint. Standalone tests reserve their checkout and
execution directory, resolving nested directories to the checkout root. Independent reviews share
only an identical snapshot fingerprint and exclude writers; snapshot validation and restart limits
still apply. Read-only status and context need no reservation.

Execution also holds read claims on its runtime bundle and declared colocated dependencies, while
install, migration, uninstall, and refresh take conflicting write claims first. A conflict returns
`Busy` with owner details or a deferred update; it never stops workers, changes schedules, or clears a
pause. There are no versioned runtime snapshots or second scheduler, and running refresh/heartbeat
helpers cannot replace themselves; update them with the approved local-source installer afterward.

Claims are released on confirmed completion. Interrupted or abandoned claims stay `NeedsRecovery`,
never expired or stolen automatically. `Recover -ConfirmStopped` clears that controller's inactive
claims only after inspecting the work and confirming prior workers stopped, and existing safety pauses
remain; scheduler recovery clears its matching inactive wrapper claims. Unreadable evidence must be
repaired, not treated as idle. Updating older runtime copies needs separate attended stopped-worker
confirmation and temporary rollback protection.

Executable manifests also declare `runtimeInterfaces` and `requiredInterfaces`. Admission checks exact
interface versions under the dependency read claims, before agents or test commands launch; equal
package versions or `ownershipProtocol: 1` alone do not satisfy them. Missing or incompatible
same-scope dependencies report the required companion updates, and old helper entrypoints without
compatibility support block execution while read-only status stays available. There is no implicit
update, source-checkout fallback for installed dependencies, or relaxed ownership, and unrelated
skills need not share a package version. PR reviews keep their separate verified-snapshot adapter and
never treat remote repository instruction files as trusted worker instructions.

## Commands

The shared script is `scripts/harness.ps1` under the selected `harness` installation. Other
harness skills locate this same dependency instead of duplicating storage and execution code.

| Action | Inputs and behavior |
| --- | --- |
| `Root` | Read-only inspection by default; only this form permits omitted `-ProjectPath`. Explicit `-Move -DestinationPath <existing-parent>` previews relocation from the selected source; approved `-Apply` moves it. Never scheduled. |
| `Init` | Reuse Root; the session supplies `-ProjectPath` and `-ConfirmLocation` without another location prompt; no scheduled initialization |
| `Migrate` | Preview in-place layout/configuration migration; explicit approved `-Apply` only, never scheduled |
| `Status` | Read active state, tasks, and human queues |
| `Context` | Optional `-Id`; list selected task, coding repository, reference links, and instruction sources |
| `Clean` | Preview historical records/reports; approved `-Apply` prunes eligible entries. `-DefinitionPath <file>` previews or saves retention settings without running cleanup. |
| `Board` | Inspect resolved paths; `-CurrentFileName` previews an explicit rename, `-ViewTopic` and `-ViewMonitors` preview a filtered snapshot; each applies only with approval and `-Apply`. Legacy `-BoardPath` still changes only an empty board. |
| `Task` | List tasks, add with requirement fields, or use `-FollowUpOf <completed-id>` for a linked follow-up; optional source/revision/kind/priority/risk and `-RepositoryRef` |
| `UpdateTask` | Exact `-Id` and supplied fields; revised completed requirements create a linked task; never update an active task contract or retarget an allocated task |
| `Ref` | List references, upsert `-Source`/`-Note` with optional task `-Id`, or remove exact `-RemoveId` |
| `Dev` | Existing `-Id`, ad-hoc fields, or `-FollowUpOf`; shares task update/intake, then optional `-Mode now` or queue-only `next` |
| `Review` | Review ahead/working changes with optional `-RepositoryRef`, `-Scope`, `-BaseRef`, and `-SecurityReview`; one whole-repository Fresh pass when no new findings appear |
| `TestConfig` | Import explicit `-DefinitionPath` JSON declarations without executing commands |
| `Test` | List declarations, or run `-Flow` with optional `-TestEnvironment`, task `-Id`, and timer `-Scheduled` |
| `MonitorConfig` | Preview a `-DefinitionPath` declaration; apply with explicit `-Apply`, human `-Actor`, and `-Reason` |
| `Monitor` | Show saved monitors/proposals, or check one `-MonitorName`, optionally timer `-Scheduled` |
| `Monitor -AllMonitors` | Check every configured source, report per-source coverage, and fail closed on an incomplete aggregate |
| `MonitorTask` | Preview an exact incident `-Id` proposal; explicit Apply/Actor/Reason accepts it as a manual-only investigation task |
| `Restrict` | Show policy; `-PolicyAction Declare -DefinitionPath <file>` previews a restriction replacement |
| `Fallback` | Show policy/pauses; explicitly Declare, Pause, Stop, or Resume through `-PolicyAction` |
| `Cycle` | Run the next eligible task and bounded pending human/resume work |
| `Recover` | Requires `-ConfirmStopped` after reviewing interrupted work and stopping prior workers |

Task intake never starts execution; missing description, scope, or acceptance yields `NeedsEvidence`.
Priority 1 is highest and separate from risk. Timer pickup requires explicit `-AutoEligible`, Low risk,
and Queued status; human queues keep their order without bypassing readiness, and unknown or high-risk
work needs a reviewed narrower scope, not an automatic downgrade. Explicitly revised completed
requirements create a linked `followUpOf` task as defined by `harness-task`, visible in task state and
the current-work CSV; the original completion, snapshot, and report stay unchanged.

An ad-hoc `Dev` request is registered before execution. Without a mode it starts when idle or queues
as `next` when busy; explicit `next` only queues. `now` requests a checkpoint at the end of the current
agent or validation phase and never kills it; worktree mode can then pause and switch, while
current-checkout mode waits for the task to finish so edits do not mix. Selection order is human now,
interrupted work, human next, then eligible automatic work. When a cycle budget runs out, remaining
work stays queued for another explicit or scheduled run.

## History Cleanup

`/harness clean` owns history retention. Reuse the selected Root and preview before applying:

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <selected-root> -Action Clean
& <harness-folder>/scripts/harness.ps1 -ProjectPath <selected-root> -Action Clean -Apply
```

`/harness clean --policy <file>` previews a retention declaration (mapped to `-DefinitionPath`; relative
paths resolve against Root); add `--apply` only for approved settings. Declaring policy runs no
cleanup and enables no maintenance, and cleanup selects one controller, not every registered project.
Weekly maintenance calls the same `harness-maintenance.ps1` implementation; the timer chooses only
when. `/harness-timer clean` handles stale schedules only.

Defaults are **90d and 5,000 completed entries per harness**, across topics. Completion time, not file
mtime, determines age, and the oldest eligible entries beyond either bound are pruned. For count-only,
set `maxAge` to null; for age-only, set both count fields to null. Optional per-topic mode uses 1,000
per topic:

```json
{
	"maxAge": "90d",
	"maxEntries": null,
	"maxEntriesPerTopic": 1000,
	"pinnedRunIds": []
}
```

Topics group development with its validation and review phases, standalone review, tests, monitors,
and PR review; named flows get no extra allowance. Preserve active or incomplete runs, open-task
evidence including completed ancestors of open follow-ups, pinned or linked reports, current monitor
readings, unresolved incidents, policy and recovery evidence, and the latest comparable review. Report
protected overages instead of deleting required context. Project `maintenance.enabled: false` opts out
of automatic cleanup; attended Clean stays available.

Clean run/PR state and its owned report files as one operation, then regenerate CSV views. Locks and
path checks protect active work and outside files. Pending removals survive interruption, are rechecked
before retry, and report `Partial` until done; expired pointers are cleared, not left broken. Authored
plans, ADRs, decisions, evaluations, declarations, application code, linked sources, skill bundles, and
worktrees are never cleaned, and a preview or policy declaration never deletes history. Installation
backups are not history: installers keep temporary originals only until success or verified rollback,
and there is no backup retention policy or weekly backup cleanup.

## Restrictions and Fallback

`harness-policy` owns the limits and fallback schemas, defaults, situation/response tables, and
examples. Policy changes preview until `-Apply` with a human `-Actor` and `-Reason`, replace only the
selected policy object, require an idle runner with no unresolved active marker, and never clear an
existing pause. During execution, actual timeouts pause the affected target, restriction mismatches
persist a project stop/pause, and an interrupted run needs reconciliation and recovery with a durable
pause on its known target, or on the project when the target cannot be identified. These responses
come from execution, not from installing or displaying a policy. Safety pauses are distinct from
cooperative task checkpoints, and read-only context, status, and decision views stay available.

## Reuse or New

One logical development/review task may involve several agents or schedules. Before launching an
additional instance or updating a matching one, inspect existing instances for the same controller,
task, repository/workspace, role, and purpose. Show their identity and status, then ask
**Reuse (singleton) or New?** unless the user already chose for this request. Recommend reuse for the
same purpose; never silently duplicate or merge distinct roles. If the choice is unanswered, leave
existing instances unchanged and create no additional one. This instance choice is separate from
allowance inheritance and is not another permission prompt.

- **Reuse (singleton):** select the exact compatible owned instance. An active development task stays
  `AlreadyRunning`; never launch a second writer or attach to an unknown process. Reuse an agent
  definition or profile where supported, not its old conclusions: required Review, Critical, and
  Fresh passes still use a fresh reviewer context. A reused schedule keeps its identity; changing
  cadence or context updates that schedule.
- **New:** confirm its role, target/workspace, and distinct identity through the host's supported
  agent-instance mechanism. Keep the same logical task with separate agent, run, and report
  identifiers. Several read-only reviewers can share a fixed snapshot; simultaneous development
  writers need separate workspaces and an explicit integration plan. Keep inherited limits, pauses,
  ownership, and required validation.

The choice does not remove the project run lock or the singleton active-task record: the shared
script remains serialized, so New never makes a second direct invocation concurrent. Use an approved
agent host for additional instances, or report the unsupported action instead of bypassing the lock.
Required pipeline review passes are part of the requested workflow and need no instance prompt.

Schedules compare purpose as well as identity before registration, and repeated ticks reuse the saved
choice without prompting or creating another timer. The user-wide PR-review timer remains a singleton
for its whole watchlist, and this choice never duplicates it. The project timer implements the choice
through `-InstanceMode`, as described in `harness-timer`; editing these skills creates no schedule.

## Script Permissions and Agent Fallback

Before running scripts, the session/coordinator checks the exact executable, arguments, target
directory, side effects, applicable policy, and required tool approvals. Reuse existing approvals
without asking again. If a necessary approval is missing, use the host's supported permission
request before execution, limited to that command and scope. A task request is not permission to
grant administrator access, change execution policy, clear a safety pause, or enable all tools.
Do not run a command known to need approval merely to rediscover the denial.

Separate missing authentication from denied tool/path access and incompatible launch settings.
Inspect non-secret status and supported credential lookup, and fix invocation mistakes within
existing approvals. Never copy tokens from editor storage or request secrets in chat. Start a
supported login flow when the authorized task needs it, asking the user only for browser sign-in,
MFA, consent, or secret entry directly in the terminal. Never silently persist new permissions,
budgets, models, or credentials. Only actual worker execution, not Idle or a successful login alone,
verifies the worker path.

If scripts are unavailable or unsuitable, an attended session may use an agent fallback with already
authorized editor/agent tools for the same work, doing it directly or delegating only when delegation
is authorized. This is an alternative execution method, not permission to repeat an explicit denial
through another tool or agent. Preserve the selected repository/workspace, task readiness and risk,
model/effort and budget limits, read-only review boundaries, validation, restrictions, and safety
pauses.

Before fallback writes, confirm exclusive workspace ownership and that no active, scheduled, or
uncertain worker can compete. Preserve runtime lock and recovery rules; if ownership or a required
execution boundary cannot be established, limit fallback to permitted read-only investigation. Never
restart a failed or timed-out worker this way, reset its budget, or silently retarget its task;
reconcile partial effects before any separately authorized continuation.

Report the fallback explicitly: what it changed, actual checks, and remaining blockers. Run required
checks through another approved test tool when available; code inspection is not execution. If
validation or independent review cannot run, leave them unverified and do not mark the task Completed.
Use existing state/report helpers when available; otherwise leave runtime state and CSV views
unchanged and report recording as pending. Never invent a run, approval, or report to make fallback
look script-run.

This is session-level guidance, not a runtime action or automatic CLI authentication recovery.
Unattended timer ticks never request interactive permissions or login, relax restrictions, or launch
an unconfigured fallback agent; they keep the existing failure/pause behavior until attended setup
resolves the prerequisite.

## Worker Output

CLI transport and the agent's final result are separate contracts. The runner launches the CLI with
`--silent --output-format text --stream off` (response-only text, no streaming), and the prompt
requires exactly one JSON object with no prose or Markdown fences. Text transport neither forbids JSON
nor guarantees the model complies. The CLI's `--output-format json` means JSONL events, one object per
line, not the harness schema; supporting it would need a separate tested event parser.

Development returns `outcome` (`ready`, `unsupported`, `already-fixed`, `stale`, `needs-decision`, or
`blocked`) and a non-empty string `summary`. Review, Critical, and Fresh return `verdict` (`clean`,
`findings`, or `blocked`), a non-empty string `summary`, and a `findings` array: empty for clean, and
supported findings with file, positive line number, and message for findings. `ready` permits
validation, not completion.

Check nonzero exits before parsing; exit zero alone is not success. Empty output, arrays, scalars,
null, malformed JSON, wrapped transport events, and invalid envelopes fail. Keep the outer JSON shape
instead of unwrapping a one-item array, never extract apparent JSON from prose, and never treat CLI
statistics as the result. Investigate missing stdout with launcher exit propagation and stderr, not by
changing the output format alone.

`Idle` returns before workspace selection and agent invocation because no eligible task was selected;
it proves nothing about CLI startup, authentication, model access, parsing, validation, or review. A
transport or parser fix needs a direct fixture or an explicitly approved worker run that reaches that
path. Report mocked and live evidence, actual exits, and parsed results separately, and never launch
work or weaken readiness to turn Idle into a success claim.

## Evidence and Recovery

Each task has development, validation, independent review, and optionally one critical-review phase;
the agent cannot mark it Completed directly. Validation runs the configured commands and declared
`testing.afterDev` flows and checks their real exit codes. Reviews are fresh read-only sessions:
writing, shell execution, and URL access are denied, and only `view`, `glob`, and `grep` are exposed.
Their structured findings are bound to the captured code snapshot, so source changes invalidate a
clean verdict.

The Git snapshot holds base/head, the tracked diff, and blob identities for untracked inputs, and
excludes harness-owned state and views. Each phase writes a local Markdown report. Malformed worker
JSON, missing evidence, CLI errors, and timeouts never count as success, and findings become
`NeedsDecision`, not an unlimited automatic repair loop.

Completed means validation and required independent reviews passed in the assigned workspace, with a
report; it does not mean committed, integrated, merged, pushed, deployed, or operationally verified.
A linked follow-up receives the parent's last report as evidence, never a reusable clean verdict, and
must pass its own validation and required reviews.

`harness-review` owns the standalone review contract: baseline selection (explicit BaseRef, then the
merge-base with local `origin/develop` or the configured upstream, otherwise a reported
WorkingChangesOnly fallback, never an implicit fetch), the whole-repository Fresh pass when no new
findings appear, the attended Changes -> Full continuation after fixes, bounded snapshot restarts,
result fields, and optional `-SecurityReview` guidance from the installed `differential-review` skill.
The runtime pins the resolved commit for the run, never extends outer budgets or retries failed
workers, and leaves development's separate `runner.criticalReview` gate unchanged.

`pr-review` owns remote PR selection and its one user-wide watchlist and timer, and
`/harness-review <PR-URL>` delegates there. Its dispatcher calls `Invoke-HarnessReview` from its own
controller with an explicit workspace, comparison commit, expected head, collected evidence, and
approved runner profile; target repositories are not initialized. Isolated PR reviews stay pinned and
fail on snapshot changes, and complete PR snapshots do not exclude source paths named like harness
records. No PR scripts, hooks, builds, tests, or remote publication are authorized.

Worktree mode uses a detached workspace at `<controller>/.harness_sv/worktrees/<task-id>` and leaves
changes there for review and handoff; it never commits, merges, or deletes the workspace. New worktrees
use committed input, while same-repository linked follow-ups reuse the saved workspace. Current mode
includes unrelated uncommitted input only with explicit `-UseWorkingChanges`. Preserve user edits and
report the resulting workspace and evidence.

Exclusive process locks serialize state updates and all development, review, test, and monitor runs.
A process exit without a recorded phase outcome blocks execution until explicit recovery; never assume
its child worker stopped. Inspect the report and workspace and confirm prior processes stopped before
`Recover -ConfirmStopped`, then explicitly resume the safety pause and separately requeue a failed task
when appropriate. Recovery preserves pauses and reports, and no hidden retry erases failure history.

After blocked development, review, testing, or monitoring, the session may offer `/handoff` to record
the outcome, evidence, blocker, observed process and pause state, and first next action. Only an
explicit request authorizes writing the note; required safety actions come first, and the note clears
no markers or pauses and starts no worker. This is optional session guidance, not a runtime action,
worker-context injection, or timer behavior.

These are coordination controls, not a security sandbox. Workers and validation commands run as the
configured OS user, and a Git worktree is not process or credential isolation. Use a restricted account
and environment for unattended work, scope tool and shell permissions deliberately, and keep production
credentials out of the worker environment.

## Timers

`harness-timer` owns schedule commands, cadence, instances, maintenance, and schedule migration; keep
it beside `harness` in the same install scope. Bare `/harness-timer` lists only, and changes preview
until `-Apply`. One current-user heartbeat owns OS timer changes. Layout-2 project declarations live in
`config/schedules.json`; progress and active claims live in `runtime/schedules.json` under
`runtime/locks/schedules.lock`; the central registry and latest job receipts live in
`~/.copilot/skillvault/scheduler`. Legacy flat files stay in place until migration, and installing or
editing skills creates no live timer.

Each tick reuses the saved `-RunnerContextPath`, or project and native settings when there is none,
never an assumed editor session; update verified capabilities through the owning session, never
through task text. Allowance inheritance, worker gates, and known caps still apply. The heartbeat only
dispatches and returns; signed-in execution uses no elevation, saved password, or machine wake. `e2e`
and `dev` select `Cycle` with the original development task identity. Setup, intake, policy changes,
and human decisions stay attended, and no eligible task means Idle. Review, named-monitor, and
test-flow timers are separate targets, and legacy `-TestFlow` without a topic still means `test`.
Status shows any safety pause; set and resume reject a paused target, and enabling the Windows task
externally never clears it. Opt-in maintenance runs in the Saturday 08:30-09:00 window and delegates
history work to [History Cleanup](#history-cleanup).

## Test Flows

`harness-test` owns `testing.environments`, `testing.flows`, and `testing.afterDev`. The shared
`harness-tests.ps1` executor stays in this bundle so manual tests, timers, and post-development
validation behave the same. Configurations without `testing` keep their legacy validation commands,
and initialization starts with empty test definitions. Declaring runs nothing. Runs preflight
directories, variable names, commands, and positive budgets, and environment overrides reach only the
child process. All post-dev flows must pass before review. Test timers run `Test -Scheduled` with no
AI worker or task creation and share the development run lock, so a busy run is reported, not
interrupted or silently queued. Task-linked tests reuse the saved workspace, allocate no worktree, and
never complete development.

## Monitoring

`harness-monitor` owns declarations, observation and discovery contracts, classifications, and
acceptance rules. The shared `harness-monitor.ps1` and `harness-source-reader.ps1` scripts stay in this
bundle. Layout-2 definitions live in `config/monitors.json`; latest checks, incident episodes, and
discovery candidates live in the `monitoring` object of `runtime/state.json`. Configurations without
monitoring read as an empty set, installation or read-only display creates no monitor or threshold,
and `MonitorConfig` previews before an approved upsert by name. Collection uses the common run lock,
restrictions, and pause/stop controls. Health checks read numeric JSON without AI; discovery
verification uses the read-only model `auto` worker, not development's Max settings.

Only current Relevant, verified-open candidates become proposals; uncertain work stays Unverified, and
checks never create tasks. Explicit `MonitorTask` acceptance reuses normal task and reference intake
and creates verify tasks with Unknown risk and manual pickup only. Failed, partial, stale, or older
results preserve prior candidates and owner data; disappearance, source closure, or age alone never
means completion. A valid breach is Succeeded/Unhealthy and reuses one incident rather than counting
as a monitor failure; actual collection failures use fallback counters, and timeouts pause
`monitor:<name>`. Required candidate reports survive retention and relocation. External ADO or
document writes need separate per-source approval. Report authoring belongs to `harness-report`, and
automatic intake or live source, cadence, and condition choices still need separate approval.

## Report Authoring

`harness-report` coordinates report, dashboard, and query authoring with `kpi-dashboard` and one
selected platform workflow. It adds no ReportCreate action, renderer, connector installation, task
store, or timer, and design-only work does not initialize the runtime. Tracked local implementation
reuses Dev intake, runner settings, workspace and permission boundaries, validation, and review.
Specialist guidance must be supplied to the worker explicitly, because the CLI does not inherit the
editor's platform tools. Publishing and optional JSON-export handoff to Monitor keep separate approvals.