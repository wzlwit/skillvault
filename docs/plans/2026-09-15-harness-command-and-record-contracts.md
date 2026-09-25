# Harness Command and Record Plan

- Date: 2026-09-15
- Status: Reusable baseline, transactional updates, and compatibility contracts accepted and implemented in source; live rollout and project-specific settings remain separate
- Owner: Zhaolong Wang
- Scope: Harness initialization, task intake, execution, testing, review, runtime policy, and records.

The [decision record](./decisions/2026-09-15-harness-command-and-record-contracts-adr.md)
preserves the confirmed choices, rationale, and alternatives. This plan describes the current
workflow and the available implementation. The document itself does not authorize running
workers, creating schedules, or publishing changes.

The [accepted September 18 ADR](./decisions/2026-09-18-upsert-and-harness-work-contracts-adr.md)
records the authoring, Fresh-review, completion, task-matching, and follow-up decisions.

The [accepted September 24 ADR](./decisions/2026-09-24-recovery-compatibility-and-harness-baseline-adr.md)
formally accepts the current coordinator, executor, review, and `now`/`next` baseline. It also
records explicit runtime-interface checks. Its retained-backup policy is superseded by the
[September 25 ADR](./decisions/2026-09-25-current-copy-only-installation-adr.md): successful skill
updates retain only current copies, using temporary originals solely for in-progress rollback.
Existing archive/obsolete-file removal and installed-copy rollout retain explicit target scope;
there is no backup-retention policy or automatic archive-maintenance job.

The [local harness runtime](../../skills/planning/harness/references/runtime.md) implements
the commands below through globally available skills and shared PowerShell 7 helpers. Explicit
project installation remains supported; command targets and runtime records stay project-local.
Missing runner allowances inherit the current session or parent, then maximum verified/native
capability; explicit restrictions still apply. Implementation and installation do not start agents
or create a schedule. The project-specific setup topics are
[Configuration When Needed](#configuration-when-needed), not unanswered choices in these reusable
contracts or automatic blockers for unused features.

The [external harness draft](./2026-09-15-project-agent-harness.md) remains background for
discussion. Its project-specific choices and capability claims are not automatically adopted
by this plan, and it is not modified or superseded here.

The [topic refactor and structure diagram](./2026-09-16-topic-skill-refactor.md) describes the
current command surface and shared heartbeat implementation. It preserves the execution gates below;
installed-copy replacement, activation, and exact live timer migration are separately approved operations.

## Rules Before Work

Every `/harness` or `/harness-*` entrypoint, including its `/hn` or `/hn-*` shorthand, applies `/rules apply`
and the applicable project instructions before its workflow. This includes direct calls without
a preceding `/harness init`, timer runs,
wrapped skills, and fresh workers. Resolve a missing Rules Core dependency through the install
policy below before continuing with project analysis or execution.

The coordinator explicitly supplies each worker with the rules, project conventions, task
context, and approved tool/model settings. Mentioning a skill name once, installing it globally,
or loading it in the parent session is not automatic instruction injection into another worker.
Follow the host's instruction hierarchy and surface conflicting skill defaults rather than
silently inheriting them.

## Initialization

`/harness init` should perform the following sequence:

1. Reuse the session's selected Root, including its displayed `./` fallback, without another
  location confirmation. If no Root or explicit action target exists, run `/harness root ./` once;
  its unanswered prompt selects the displayed current folder. Validate the existing directory
  and load the rules above. An explicit action path overrides that call only. Invalid paths or
  explicit rejection block the action; incidental terminal directories never override Root.
2. Initialize or reconnect the coordinator, validate configuration and capabilities, resolve
   the board location, and reconcile existing tasks and unfinished work. The default board root
  is `.harness_sv/` inside the selected project Root, not a worker's incidental working directory.
  The session automatically supplies `-ProjectPath <selected-root> -ConfirmLocation`, including
  on reconnect, without a second user prompt. Scheduled initialization is refused. Resolve Root
  before dependency installation or instruction edits; selection alone does not request Init.
3. Ensure the declared skills are available, installing missing SkillVault dependencies using
   the policy below. Reuse usable project or global copies rather than creating duplicates.
4. Run Graphify to build or refresh architecture context when its upstream runtime is available
   and configured. A SkillVault reference guide alone is insufficient. Report a missing runtime
   or failed analysis explicitly; do not claim that a graph was generated.
5. Use Architecture Decision Records to read existing ADRs and governing plans, distinguishing
   confirmed decisions, assumptions, and open questions. Do not infer historical acceptance or
   rationale merely from the code, and do not create an ADR for routine initialization.
6. Maintain one compact Harness Context section in the project's existing agent instructions,
  normally `AGENTS.md`. Link current plans, active decisions, and implementation status under
  `.harness_sv/docs/` by default, or user-selected paths; keep them current-focused. Link ADRs
  and run history separately. Point live task status to its actual configured board source,
  not a duplicate status document. Preserve unrelated instructions and reuse the same section
  on subsequent init calls; do not create a competing `Agent.md` or invoke another initializer.
7. Offer to run `/grilling` using that evidence. Wait for the user's choice before starting the
   interview. Grilling stress-tests project assumptions and decisions; it is not a substitute
   for the separate code-review workflow.
8. After the user resolves choices, record the decisions and update affected plans as authorized.
   Leave unanswered questions open; decision acceptance is not execution permission.

The session performs the navigation update; the PowerShell `Init` action only creates/reconnects
harness state. Neither implicitly calls the host's `/init` or `copilot init`. Initialization does
not implicitly start development or create a timer. `/adr` is the working
shorthand for Architecture Decision Records in this design; installs use the canonical catalog
name `architecture-decision-records`. No new slash-command alias is registered by this plan.

The selected project may be a non-Git controller folder. Initialization and instruction maintenance
stay there; coding repositories are existing local Git roots registered through `/harness-link`, not
new Git repositories created in the controller. All actions inherit the selected Root.

### Missing Skill Installation

With Root resolved, an `/harness init` request authorizes installation of its
declared, missing SkillVault skills without a second prompt for each one. Use `/skillvault-installation install <exact-name>`, not
keyword or whole-catalog installation. The initial dependencies are Rules Core, Graphify,
Architecture Decision Records, and Grilling.

Use the installer's verified source checkout: `C:\repos\skillvault` on Windows or an explicitly
selected `--repo` path. Read its current catalog and bundles, not a cached summary or another
session's clone. If the intended checkout is missing or invalid, resolve that choice before
installing; init approval does not authorize implicit cloning, pulling, or branch changes.
Source selection stays separate from the original project's installation destination.

Resolve scope from an explicit supported override, then the skill's `install.defaultScope`,
then `project` if the manifest omits a default. An explicit session choice remains session-only;
it must not silently become a persistent install.

| Skill | Default scope | Installed capability |
| --- | --- | --- |
| `architecture-decision-records` | Global | ADR authoring and review guide |
| `graphify` | Global | Upstream reference guide only, not its CLI |
| `grilling` | Global | Decision-tree interview guide |

Global scope makes these guides available across projects; their output and decision records
still belong to the selected project. Existing usable installs are not automatically upgraded,
overwritten, moved, or deleted. Replacements retain `/skillvault-installation install`'s review and approval rules,
including preservation of customized and pinned copies. Report what was installed, its scope,
source version policy, declared version, and destination.

Graphify's CLI, upstream skill installation, hooks, and runtime setup are outside a SkillVault
reference install. Read the authoritative upstream guidance before real use. Automatic upstream
setup requires separate approval; do not treat installation of the reference as that approval.

## Command Contracts

Canonical skill names, catalog entries, and folders use topic names such as `harness`
and `harness-dev`. First-argument subcommands select operations; old full commands and shortcuts
remain conversational compatibility routes. Bare multi-action topics use read-only `list`, including
`/harness-timer`. Use command synopsis notation: `/harness-<topic> [action1|action2|...] [<arguments>...]`.
The top-level `/harness` remains the agreed root/setup/context/history entry; there is no management topic.

| Command | Contract |
| --- | --- |
| `/harness root [<root-path>]` or `/hn-root [<root-path>]` | Show Root, or select a valid new path and prompt to move data from an initialized previous harness. Move is the default even without an answer; explicit answers/instructions override it. The new Root stays selected either way. Invalid paths do not change Root. No move flag; first/missing selection retains its separate displayed `./` fallback. |
| `/harness init` | Reuse selected Root, including its fallback, without another location prompt; run the rule-first initialization sequence. Do not start coding/timers. |
| `/harness clean [--policy <file>] [--apply]` | Preview historical records/reports or configure retention; applying one operation does not imply the other. No schedule or source-skill cleanup. |
| `/harness-task [list\|add\|update] [<arguments>...]` | Own task records and readiness without starting work. Accept requirements, a local file, or a URL. |
| `/harness-dev [list\|run\|queue] [<arguments>...]` | Own execution and queues. Ad-hoc work reuses task intake. Old `now` maps to `run --now`; `next` maps to `queue`. |
| `/harness-review [list\|run] [<arguments>...]` | Review ahead/working changes or a verified PR snapshot; optional scope, base, and security arguments retain their meanings. |
| `/harness-test [list\|declare\|run] [<arguments>...]` | Inspect or declare flows/environments, or run a selected flow. Optional task linkage reuses its workspace. |
| `/harness-monitor [list\|declare\|check\|accept] [<arguments>...]` | Inspect observations/proposals, declare monitors, check one observation, or accept an incident-linked manual task. |
| `/harness-report [list\|upsert] [<arguments>...]` | Resolve an existing or missing artifact and author it; create/update remain aliases. Platform, output, validation, and publication boundaries stay separate. |
| `/harness-policy [list\|set\|pause\|stop\|resume] [<arguments>...]` | Own runtime limits and failure handling. `limits` and `fallback` qualify list/set; policy changes start nothing. |
| `/harness-timer [list\|set\|disable\|resume\|clean\|migrate] [<arguments>...]` | Own cadence and schedule lifecycle. `clean` handles stale schedules only; weekly maintenance delegates history to harness. |
| `/harness-decision [list\|record] [<arguments>...]` | Read-only [decision bulletin](#decision-bulletin): open decisions plus a brief configuration summary by default; `list all` adds recent decisions and the detailed setup checklist. Closed/exact-ID views omit setup. Record only an explicit human choice, linked to affected tasks. |
| `/harness-link [list\|add\|remove] [<arguments>...]` | One registry for supporting URLs, files, folders, and coding Git roots. Removal unregisters the link, never its target. |
| `/harness context [<task-id>]` | Read the selected project's/task's rules, plans, decisions, and relevant references without creating another context store. |

Root selection uses the read-only `Root` action; it does not initialize or migrate a controller.
Keep the selected absolute path in session context. All other actions derive `-ProjectPath` from
it without another location confirmation, including after the unanswered `./` fallback. Init and
reconnect receive `-ConfirmLocation` automatically from the caller, not another user prompt.
`/harness root <path>` selects the valid new target and saves the previous root separately. If
that previous harness was initialized and the target differs, ask whether to move its data.
Display Move as the default; Yes or no answer previews and applies the move unless an explicit
answer or applicable user instruction overrides it. No or cancel leaves existing data and
schedules in place. The new Root remains selected either way. `/hn-root <path>` follows the
same routing without an extra location prompt for an existing Root. A failed move does not undo selection
or imply successful migration. Invalid targets do not change Root. An uninitialized source or
unchanged path needs no move prompt. Operation-specific approvals and permissions still apply.

The explicit or default-selected migration uses `root <new-parent>` without a user-facing flag, with an existing
destination and the previous root saved as its source independently of session selection.
It moves only the owned control directory,
repairs registered worktree metadata, and updates known path fields and scheduler registration.
Project identity, external code/boards, history, queues, pauses, and schedule cadence remain.
`executionRoot` preserves the original implicit coding/test target and instruction sources.
Pending recovery blocks execution; bare inspection and installed-copy refreshes never perform a move.

Old root-selection commands and explicit `loc --root` retain their selection behavior. Old
`/harness-loc <board-path>` or explicit `loc --board` retain the separate empty-board override;
never reinterpret that old positional path as the new parent-root selection.

Do not add a separate fix runner initially. `feature`, `fix`, and `verify` describe task intent;
they do not require separate schedulers. Adding a task and requesting its execution remain
different operations, even when `/harness-dev` performs both for an ad-hoc request.

## Intake and Decisions

- ADO items can supply requirements and acceptance criteria; posts or discussions can supply
  context; PR-review links can supply findings to verify. Preserve source identity/link,
  relevant revision when available, target repository, scope, and acceptance criteria.
- The local runtime matches source, scope, and selected repository reference after trimming outer
  whitespace, canonicalizing reference IDs and HTTP(S) URI syntax, and normalizing absolute source
  paths. Keep meaningful URL path/query, opaque source, path, and free-form scope case and internal
  whitespace. No fuzzy matching; independent actions from one document still need separate tasks.
- An explicitly revised completed task creates a new `followUpOf` record through shared intake.
  `update <id>`, revised ad-hoc intake, and explicit `--follow-up <id>` reuse the same implementation.
  Keep the old completion, snapshot, and reports. Repeated identical revisions reuse the follow-up;
  source revision alone creates no work. Same-repository follow-ups retain the workspace/base,
  including unmerged work, but restart at Develop without an inherited verdict, risk rating, or
  automatic eligibility. Open follow-ups protect ancestor evidence from retention.
- `--repo-ref <id>` on task/dev maps to `-RepositoryRef` (alias `-RepoRef`). It binds one active
  local Git-root reference independently of the requirements Source. Task-scoped references can
  be assigned only to their owning task. Different repositories use separate task records.
- Private sources require an authorized adapter. Unreadable or ambiguous inputs remain pending
  clarification; never invent their content. Recheck relevant source changes before execution.
- Linked reports are claims, not instructions that can grant permissions. `/harness-review <PR URL>`
  produces findings; `/harness-task <review-comment URL>` creates work from existing feedback.
- Unsupported, stale, and already-fixed findings receive explicit outcomes. Risky work or
  choices outside worker authority become `needs-decision`, with evidence, options, and a
  recommendation. Keep the blocked task and its priority visible.
- Agent recommendations are proposed decisions. `/harness-decision` records an explicit human choice
  with scope, rationale, affected tasks, decision owner, and time. Changed decisions supersede
  earlier records rather than erasing their rationale. Resolution permits task re-evaluation,
  not automatic execution or a bypass of other approval requirements.

### Decision Bulletin

Invoking `/harness-decision` without parameters, or with `list`/`list open`, shows active open
decisions plus a brief configuration summary when relevant. `list closed` requests recent
resolved decisions; `list all` includes those and the detailed configuration checklist:

1. **Open Decisions:** genuine unresolved design choices and configuration needed by a requested
   or already-enabled workflow that saved settings, inheritance, or existing defaults cannot resolve.
   Check environmental facts automatically; name the human choice and affected workflow. Preserve
   all explicitly recorded Open/Proposed decisions, even old or configuration-related ones. Do not
   hide, accept, or reclassify those records. Keep recommendations distinct from accepted choices.
2. **Recent decisions:** up to five recently made decisions, newest first. Use brief bullets
   with the decision ID when available, status, one-line outcome, and a link to the full record.
3. **Configuration When Needed:** one-line summary with a source link in the default/open view;
   the detailed documented checklist in `list all`. Do not include optional setup in the open
   count. Omit configuration in closed/exact-ID views or when none is documented.

State explicitly when a requested decision section is empty. Do not require arguments or start an interview,
modify records, accept a recommendation, or trigger work merely to display this bulletin.

The [skill instructions and CSV helper](../../skills/planning/harness-decision/references/workflow.md) define the
implemented local register format. When no register exists, the skill reads the current plan
and ADRs without creating one. This is a presentation and classification rule, not a new action,
CSV status, execution permission, or requirement for a running coordinator. Source guidance
updates do not refresh installed copies or configure live workflows.

## Execution and Review

- `ProjectPath` identifies the controller, not necessarily a Git checkout. A selected repository
  supplies the current checkout or the source for a detached worktree under the controller's
  `.harness_sv/worktrees`. State, reports, locks, and relative restriction roots remain controller-local.
  Persist repository ID/root and workspace with the task; do not retarget allocated work or use
  another reference on failure. Workers receive controller and coding-repository instructions.
  All development phases use the same workspace. Missing/inactive/remote-only/non-Git targets
  block selection without cloning, Git initialization, or widening permissions. Existing same-root
  projects remain supported. Controller locks remain, while shared checkout ownership also excludes
  competing harness-managed writers from other controllers across manual and scheduled entrypoints.
- `now` starts when idle; when busy, it requests a safe checkpoint and switch, not a hard kill.
  Preserve unfinished changes and continuation context. The resume order is interrupted
  work first, then the ordered human `next` queue, then fresh automatic selections.
  In the local runtime, worktree switching happens at completed agent/validation phase boundaries.
  Current-checkout mode finishes the active task before switching to avoid mixed edits. Remaining
  queued work is preserved when the configured per-cycle budget is reached.
- `next` queues without interrupting. With no scheduling qualifier, propose starting when idle
  and queuing as `next` when busy. Priority does not override readiness, risk, or permissions.
- A logical task can involve multiple agents or schedules. Before adding an instance or changing
  a matching one, inspect identities/status and confirm Reuse (singleton) or New unless already
  selected by the request. Reuse means compatible ownership/profile, not shared developer/reviewer
  conclusions. Additional agents require host support; simultaneous writers need isolated
  workspaces and an integration plan. The shared script runner remains serialized.
- A timer wakes one coordinator cycle to reconcile, select eligible work, develop/verify, run
  checks, review, and record results. It must not launch independent competing dev/fix writers.
  The local runtime serializes development, independent review, and tests under one project run
  lock; failed, blocked, or safety-paused work is not completed.
  Completed means validation and required independent reviews passed in the assigned workspace,
  with a report, not integration, commits, merging, pushing, or deployment.
  Timer setup is explicit, with first execution one positive decimal-day interval later. Zero
  is rejected; missed ticks coalesce and overlapping instances are ignored. Resume does not
  request an immediate run. A review timer runs independent review only; test/monitor/custom
  flow timers run their selected declared commands only, not task pickup.
  These local-runtime semantics do not modify unrelated schedules.
- Reviews bind findings to the selected baseline and head, plus the captured working changes
  when applicable. If code changes, do not reuse a clean verdict as evidence for the new snapshot.
  Development cycles retain the explicitly configured critical-review choice. Standalone Review
  instead makes one fresh whole-repository pass after a completed pass has no new findings,
  including when it repeats existing findings. Findings are handed to the existing dev/proposal
  workflow; after fixes, the review coordinator repeats from Changes until no supported unfixed
  issues remain and Full is clean. Review itself neither fixes code nor starts another fixer.
- "Max power" means the strongest suitable allowed model and highest runtime-supported effort,
  within approved resource limits. Report effective settings and unsupported capabilities;
  do not assume unlimited agents, invent an effort parameter, or silently downgrade a request.
- Task creation, local review, and decision recording do not implicitly authorize remote
  comments, work-item closure, commits, pushes, PR approval, merging, or deployment.

### Standalone Review

The [shared-ownership ADR](./decisions/2026-09-23-shared-ownership-adr.md) covers checkout ownership
through active development, validation, and review, shared stable-snapshot readers, and runtime
update deferral. Tests reserve their actual execution checkouts as potential writers. Runtime and
declared colocated dependency claims conflict with install/refresh/uninstall writes. Busy outcomes
identify owners; uncertain claims require explicit stopped-worker recovery without clearing pauses.
Older nonparticipating runtimes need an attended, backed-up transition. Current/worktree defaults,
read-only status access, and existing scheduling policy are unchanged. Source implementation does
not install this protocol into live copies or grant execution permission.

The [review skill](../../skills/planning/harness-review/references/workflow.md) owns general code-review
guidance, independent passes, and reports. Explicit comparison refs win; otherwise the local
runtime chooses the merge-base with `origin/develop` when present, then the configured upstream.
It pins that commit while reviewing ahead commits and staged/unstaged/untracked inputs. Without
either ref it reports HEAD-based WorkingChangesOnly coverage; no remote fetch is implied.
For a folder-based controller, `/harness-review --repo-ref <id>` selects one active project-wide local
repository reference and resolves its baseline there. It reviews that checkout, not a task's
detached worktree, and keeps reports in the controller. No first-reference fallback is selected.
PR URLs delegate to the [PR-review workflow](../../skills/github/pr-review/SKILL.md),
which owns verified remote base/head evidence and isolated matching workspaces. `/harness-review`
remains project-first; the reverse path reuses the shared implementation, not a recursive skill
invocation. PR review, watchlist actions, and the timer route share one user-wide list and one current-user timer
for all its targets, separate from project harness schedules. Its dedicated controller reuses
harness state, policy, read-only agents, and reports without initializing target repositories.
The [PR runtime contract](../../skills/github/pr-review/references/runtime.md) defines
approved strongest-first model/effort/context selection, bounded collection/review, unchanged
snapshot skipping, and pending failed/stale outcomes. No live list/settings/timer is implied.

Newness is an exact normalized file/line/message comparison against the last completed report
with the same repository reference/root, scope, base reference/commit, and security mode. Both passes use current evidence,
not cached conclusions, and all supported findings on the same stable snapshot survive aggregation. A clean second pass
cannot clear first-pass findings. Prior reports remain intact, and omission is not automatic
issue resolution. Local changes during either pass restart from Review on the latest snapshot,
up to twice, keeping the original baseline, scope, repository, and permissions. Superseded
attempts remain evidence in the report, not current findings. Persistent edits return `Partial`
without counting a worker failure. Actual failures/pauses do not retry; isolated PR snapshots stay pinned.

At workflow level, repeat Changes -> Full around the existing dev/proposal handoff. A findings
result is a checkpoint, not completion: publish the report, release the shared run lock, let dev
fix and validate, then resume Changes on the updated snapshot without another user run request.
Earlier unresolved findings must be rechecked even outside the latest diff. Keep one review
request and the same repository, base, security mode, and reports; do not add a fixer, task store,
notifier, or schedule. Do not repeatedly review unchanged code while waiting for a correction.
Missing fixes/validation stay pending, and failures, access limits, pauses, and budgets stay enforced.

Fresh covers the whole selected repository, including unchanged code, configuration, and tests.
Ordinary Review and development Critical keep their change scope. Respect explicit user/parent
restrictions and existing budgets; insufficient coverage is blocked, not clean. Do not inspect
another repository, fetch remote material, or add workers to compensate. Reports identify each
pass's requested scope; isolated PR review retains its pinned workspace and no-execution rules.
Each script round uses at most two passes per snapshot, up to six sessions across two local
restarts, with unchanged explicit/inherited/native per-session limits and outer budgets. These
churn limits do not cap rounds resumed after completed fixes. Only a stable clean Changes/Full
round with no supported unresolved issues sets `complete: true`; findings set `nextPhase: Review`.
Development's critical pass is independent. Reports and run metadata include attempted passes and restarts.

`--security` composes the installed [differential-review guide](../../skills/security/differential-review/SKILL.md)
into the same reviewer contexts. Keep common evidence-based code-review principles in harness-review,
but reuse the specialized security methodology at its owning guide rather than copying it. No
scanner, extra worker, implicit installation, or wider tool permission is introduced. Requested
missing guidance blocks before execution. The optional mode is available, not silently selected
as the default for every project or timer.

## Timer Workflows

The [timer skill](../../skills/planning/harness-timer/references/scheduler.md) treats bare
`/harness-timer` as read-only `list`. `set` selects project, PR, refresh, or maintenance targets.
Unit durations support fixed minutes/hours/days and whole calendar months/years. Missing cadence
reuses the exact saved target or requires a choice, never an invented work schedule.

The separate `set heartbeat [<duration>]` settings target manages a routine `1d` baseline; it
does not assign a daily interval to jobs. Saved baseline reuse, faster-job adaptation, active-worker
checks, and deferred overdue work follow the [adaptive-heartbeat ADR](./decisions/2026-09-23-adaptive-heartbeat-adr.md).
Baseline edits preserve job cadence, start-time anchors, enabled states, and Saturday maintenance.
The heartbeat is a script dispatcher with no agent model setting; worker model selection is unchanged.

Scheduled global refresh has three bounded retries for temporary ownership contention, delayed
one, ten, and thirty minutes after preceding attempts. Each worker exits while waiting; the
existing job retains only its retry deadline and exact deferred source/target bindings. Other
jobs can run meanwhile. Self-owned dependencies, legacy transitions, recovery, and actual failures
remain excluded. See the [refresh-retry ADR](./decisions/2026-09-24-refresh-contention-retries-adr.md).
Regular cadence and approvals remain; manual updates create no retry job, and source changes
enable no schedule or installed-copy rollout.

Matching schedules require a Reuse/New choice before mutation. `-InstanceMode Reuse` selects
the existing singleton, or a named schedule via `-InstanceName`. `-InstanceMode New` requires
a distinct stable name and creates only that schedule; it never overwrites a collision. Named
instances append ` Instance <name>` to the existing purpose-specific task name. Unselected matching
requests return `NeedsInstanceChoice` in preview and reject Apply. Status exposes the matching
instances. Cadence/context reuse and disable/resume apply only to the selected identity. All
instances share the controller's run lock and inherited policy; recurring ticks use the saved
choice without prompting. The user-wide PR-review list keeps one logical schedule, sharing the
single heartbeat with other targets instead of registering another OS task.

Project definitions and nextDue/enabled/active state live in the resolved harness control's
`schedules.json`, with a central user-wide registration list. Dispatch coalesces missed ticks,
never overlaps the same job or intersecting coding roots, and retains uncertain workers for
explicit recovery. The Windows heartbeat runs only for the signed-in current user without
elevation and is currently configured with no machine wake. Exact legacy migrations preserve
cadence and enabled state.

Opt-in maintenance runs once on Saturday 08:30-09:00 local, before new work and only with idle
controllers. Machine wake and AI assistance are permitted when necessary; routine cleanup remains
scripted. Establish a concrete need and honor scope, budgets, denials, and cleanup approvals.
This permission does not itself change the live task or create an AI run. No remote scan or
catch-up outside that window. Retention defaults
to 90d and 5,000 entries across a harness; optional per-topic mode uses 1,000. Protect active,
pinned, referenced, unresolved, policy, and review-comparison evidence. Prune authoritative records
and owned report files together, preserving failed deletions for retry. Stale means removed or
explicitly retired, not disabled/idle/failed/unavailable; disable first, then allow confirmed
deletion after 30 days. Authored plans, decisions, evaluations, and worktrees are not cleanup targets.

| Topic | Shared runtime and scope |
| --- | --- |
| `e2e`, omitted, or `dev` | Existing Cycle and development timer identity: rules/context/policy gates, eligible task selection, development/fix/verification, validation/tests, independent review, board/report updates |
| `review` | Read-only ahead/working-change review and a conditional fresh pass; up to two local snapshot restarts without relaxing limits |
| `test <flow> [environment]` | Separate declared test-flow schedule, without AI/task pickup |
| `monitor <name>` | Separate Monitor schedule for a declared health observation, with monitor-specific scheduling permission, budget, and pause target |
| Legacy `monitor <flow> [environment]` or another topic label | Separate named schedule over an explicitly declared executable flow, retaining the Test executor and its approval/evidence/pause contracts |

E2E composes applicable harness roles through the existing runtime, not a new worker that invokes
every slash command. It does not invent tasks when the queue is empty, skip required gates for
dev, or run unlimited cycles. Initialization, supporting-reference/task intake, Graphify setup,
policy declarations, interviews, and human decision acceptance remain attended or separately
authorized actions. No recurring `/init`, policy mutation, publishing, or timer recursion is implied.

Named monitor schedules select `-MonitorName` and use the Monitor action described below. Existing
monitor/custom command flows retain reviewed commands, environment scheduling permission, budgets,
Test history, and their flow/environment safety target. No automatic migration or name-based
substitution is allowed; ambiguous monitor-versus-flow names require an explicit choice.
A label does not implement a monitoring service or external adapter. Unresolved topics remain
blocked on a concrete definition instead of silently becoming development work. All workers share
the project run lock, restrictions, and durable pause gates. Installing/editing the timer skill
does not create live schedules. Missing allowances resolve through session/parent context or
verified/native settings; actual policy conflicts and unavailable prerequisites remain distinct.

## Test Flows

The [harness-test skill](../../skills/planning/harness-test/references/workflow.md) uses one shared executor
for declared test methods, ordered command steps, and environment profiles such as `local` and
`localPPE`. Definitions are project-specific; these labels do not create an environment or imply
that its service version matches the checked-out code. Reuse existing project test frameworks.

- **Declare:** `/harness-test declare <file>` saves reviewed configuration without running commands.
  See the [declaration schema and examples](../../skills/planning/harness-test/references/test-flows.md).
- **Ad-hoc:** `/harness-test run <flow> [environment]` tests the current workspace, or the saved task
  workspace with `--task <task-id>`. It does not require an AI model or create a development task.
- **Scheduled:** `/harness-timer 0.5 test <flow> <environment>` runs that target every 12 hours after
  explicit setup and environment scheduling approval. It does not replace the development timer.
- **Post-development:** `testing.afterDev` selects mandatory test flows during the existing
  validation phase for feature/fix/verify work, before independent review. Legacy validation
  commands still run first. Failed or blocked tests prevent completion.

Test-only runs share the project run lock and produce environment-aware history/report evidence.
Prerequisites and actual exits decide Passed/Failed/Blocked outcomes; missing localPPE access is
not a pass. Per-flow time budgets bound standalone runs, and the development validation budget
bounds hooks. Another skill can explicitly invoke the same test command afterward; no hidden
hook is installed on arbitrary skills. Fix work remains part of `/harness-dev`.

No real environment, credentials, test declarations, or live schedules are configured by adding
the skill. These remain project-specific choices. Keep secrets out of config, arguments, and logs.

## Monitoring

The [monitor skill](../../skills/planning/harness-monitor/references/workflow.md) owns observation
evaluation and incident proposals, not dashboard authoring, task execution, or another scheduler.
Its first source is one local JSON metric snapshot per monitor, produced by an existing reviewed
query/export. Reuse underlying data and metric definitions rather than interpret screenshots of
Power BI or online dashboards. The [declaration contract](../../skills/planning/harness-monitor/references/monitoring.md)
specifies resource/environment/metric, numeric breach condition, measurement window, freshness,
collector timeout, response, and separate scheduling permission. No live values are selected here.

- Bare `/harness-monitor` shows saved definitions, timestamped checks, incidents, and proposals only.
  Declarations preview and require explicit approval/owner/reason to save, without execution.
- `/harness-monitor check <name>` uses the common run lock, bounded process, restriction, and pause
  controls. Valid Healthy and Unhealthy observations are both successful monitoring. Stale,
  wrong-identity, unavailable, or invalid readings remain Unknown and cannot record recovery.
  Actual collection failures/timeouts use fallback policy; repeated service breaches do not
  disable a functioning monitor. Its safety target is `monitor:<name>`.
- One breach episode has one incident and pending proposal. Repeated readings update evidence;
  valid recovery ends that episode, and a subsequent breach opens another. An already observed
  metric/resource/window/condition change uses a new monitor name to preserve historical meaning.
- Explicit `/harness-monitor task <incident-id>` acceptance requires fresh Unhealthy evidence and uses
  existing task/reference helpers with an episode-specific source identity. It creates only a
  verify task with risk Unknown and no auto-eligibility; repeated acceptance reuses that task.
  Recovery changes neither task status nor the user's scope. A breach is evidence to investigate,
  not proof of a code defect or automatic permission to fix it.
- `/harness-timer <days> monitor <name>` schedules the same Monitor action after that declaration
  explicitly permits scheduling. It does not accept proposals or become part of E2E by default.
  Existing monitor command-flow timers keep their behavior and identity.

Definitions live in `config.monitoring.monitors`; compact latest observations/incidents live in
`state.monitoring`. Board reports and history.csv retain evidence, with separate monitor/health
columns. Dashboard/query links reuse `/harness-link`, not a competing register. Keep telemetry at its
source, credentials out of snapshots/config, and source collectors separately reviewed. Direct
online/PBI adapters, provider authentication, and automatic task intake are not implemented.

The report-authoring dispatcher below handles query/dashboard creation separately. Monitoring
evidence reports do not imply a BI authoring engine or permission to publish artifacts.

## Report Authoring

The [report skill](../../skills/planning/harness-report/references/workflow.md) is a
session-level dispatcher, with `/hn-report` as conversational shorthand. It establishes
purpose/audience, source and metric definitions, stable artifact identity, and platform before
loading the relevant specialist. Supported route guidance covers Power BI, Grafana, Jarvis, web dashboards,
and saved queries; available authorized tools determine what can actually be created and validated.
The [report-authoring ADR](./decisions/2026-09-15-harness-report-authoring-adr.md) supersedes only
the earlier authoring-skill deferral, not the monitoring or execution boundaries.

- No arguments shows status/actions; an explicit create/update request clarifies missing requirements.
  `--design-only` requests a specification.
  Neither implicitly initializes harness state or connects to a data source.
- Reuse the [KPI design companion](../../skills/data/kpi-dashboard/SKILL.md) for
  metric contracts, population/grain/unit/time/freshness checks, and layout principles. It is
  a curated MIT guide, not a copied or tested upstream SQL/Streamlit generator.
- The Jarvis route selects [jarvis-metrics](../../skills/monitoring/jarvis-metrics/SKILL.md)
  for metric-source and widget configuration, not a bundled client. A query-only deliverable
  remains on the query route without forcing conversion or visuals. Distinguish requested
  Jarvis-native monitors/alerts from harness JSON observation checks; both need separate approval.
- Use existing `/harness-dev` task handling for approved local implementation. Explicitly supply
  selected guidance and acceptance checks to workers. Do not build another runner or presume
  the CLI inherits the current editor's platform MCP tools. Attended connector work needs its
  own authorization and must not bypass execution/pause controls or create competing writers.
- Reuse the existing report path/UID/platform item ID for the same purpose; preview scoped
  updates and clarify collisions instead of inventing timestamped duplicates. No separate
  artifact registry or automatic semantic deduplication is added.
- Delivery names the real artifact and design-only, created, validated, published, or partial/
  blocked outcome. Design recommendations or model exports are not finished Power BI reports.
  Validation checks formulas and filters as well as native format and actual visual behavior.
- Publication, sharing, platform tool installation, model mutation, live data access, and
  monitoring activation remain separate permissions. Only an explicitly requested, verified
  JSON exporter can feed the current Monitor contract; a dashboard URL alone cannot.

This adds reusable authoring guidance and dispatch, not a report generator for every platform.
Concrete report targets, data authorization, available writers, and delivery checks are resolved
per request. No reports, live sources, schedules, or automatic intake are configured by installation.

## Restrictions and Fallback

The [restriction skill](../../skills/planning/harness-policy/references/limits.md) and
[fallback skill](../../skills/planning/harness-policy/references/fallback.md) use the shared config,
runner, and state rather than adding a competing controller. Their guides own the supported
field contracts and situation/response examples. `/rules` remains human-readable guidance,
not an execution gate. Both bare commands inspect without initializing or changing anything.

- Restrict defines model/tool/directory/environment/launcher allowlists and stricter time,
  per-agent credit, and cycle caps. It checks actual saved development workspaces too. These
  controls do not provide OS isolation or aggregate task/daily billing enforcement.
- Fallback defaults to one additional attempt after five seconds only for safely repeatable named
  test steps on explicitly classified transient exits, within the same flow/validation budget.
  Explicit retry count/delay overrides remain effective; `maxRetries: 0` disables retries. Once
  eligibility is approved, the failed step may retry without per-attempt confirmation. It never automatically
  retries agents, changes models, repairs code, rolls back edits, or widens permissions.
- Optional failed-run thresholds pause the affected development, review, monitor collection, or flow/environment
  target across invocations. Count failed attempts, not log lines; successful execution clears
  that target's consecutive-failure count. Post-dev and standalone flows share test counters.
- Actual timeouts pause their target; detected restriction violations stop/pause the project.
  Crashes and unconfirmed termination require reconciliation, confirmation that workers stopped,
  and explicit recovery. Old unidentified interrupted targets conservatively pause the project.
- Ordinary safety pause waits for the current process to finish. Stop requests termination of
  the runner-owned process tree, not arbitrary/escaped processes. Explicit resume clears only
  the selected pause and starts nothing. It does not requeue failed tasks or enable schedules.
  Existing queued/checkpointed work may be picked up by a later already-enabled timer tick.
- Policy declarations preview first and require explicit owner/reason/approval to apply. They
  replace only the selected config section and never clear pauses. Recovery and timer enable
  also preserve pauses. Manual, scheduled, post-dev, and review entrypoints honor the same gate.

Installing these skills selects no live thresholds or retry codes and changes no schedules.
The [bounded-retry ADR](./decisions/2026-09-23-bounded-test-retry-defaults-adr.md) records the
one-retry/five-second defaults and retained opt-out. No exit code is transient globally, and no
numeric failed-run threshold is selected. Timeout, detected violation, and interruption keep their
documented stop/pause behavior; failed tasks are not automatically requeued by the heartbeat.
The current text adapter cannot reliably identify credit exhaustion or all denied CLI tool events,
and does not implement automatic model failover. Host/tool/OS controls remain necessary for hard
containment; same-user workers are not tamper-proof. Project-specific setup is listed under
[Configuration When Needed](#configuration-when-needed).

The session follows [permission preflight and agent fallback](../../skills/planning/harness/references/runtime.md#script-permissions-and-agent-fallback)
before scripts: reuse existing approvals, obtain missing command-scoped host permission first,
and distinguish authentication from policy denial. When scripts are unsuitable, an attended
agent can use authorized tools for the same task only while preserving workspace ownership,
restrictions, pauses, budgets, validation, and independent review. Do not bypass explicit denial
through a different executor. Unavailable tests or record updates stay pending, not Completed.
This is session guidance, not automatic CLI-auth repair, a new runner action, or timer failover;
unattended ticks cannot grant permissions, interactively log in, or launch an unconfigured agent.

## Plans and Records

Keep current plans and lasting decision rationale separate, with links in both directions.
All harness-owned information and files default inside `.harness_sv/` under the Root selected by
`/harness root`, unless the user explicitly specifies another destination. Board views and run
evidence default there as well. Pass that artifact destination to delegated skills instead of
inheriting their standalone `docs/` default. Existing project documents and configured board
locations are not migrated or duplicated. This repository's existing design records stay at
their established paths; new harness-run artifacts follow the following hierarchy.

```text
<project-root>/
  .harness_sv/
    config.json
    state.json
    schedules.json
    schedules.lock
    current.csv
    history.csv
    decisions.csv
    references.csv
    history/
      <run-id>.md
    docs/
      plans/
        <date>-<plan>.md
        decisions/
          <date>-<decision>.md
      handoffs/
    definitions/
    artifacts/
    worktrees/
```

See the [complete hierarchy and ownership](./2026-09-16-topic-skill-refactor.md#project-storage).
Folders are created only for requested operations. Logs use run evidence under `history/`;
do not create parallel status dashboards. Explicit output overrides affect their own artifact
only, never a saved task's coding repository or live schedule. Application source and linked
documents remain in place.

Prefer CSV for structured status, logs, decision registers, and report indexes. Use linked
Markdown for detailed explanations and evidence when needed. Do not create a duplicate
Markdown dashboard by default. Supply filtered rows to workers, not whole growing files.

`current.csv` is a compact view of pending, running, and blocked work with IDs, priority, state,
next action, and report links. Completed outcomes remain reachable through `history.csv`,
which indexes significant runs/events. Use one Markdown summary per run when findings,
decisions, or test evidence need explanation; link large logs rather than embedding them in CSV.

`decisions.csv` indexes decisions, statuses, affected tasks/plans, and ADR links. Routine choices
can remain in the register or task history; consequential architectural choices warrant a full
ADR. Do not duplicate the full rationale in the CSV, plan, and ADR.

Draft ADRs with `Proposed` status unless the user has accepted the decision. A proposal must not
silently change an agreed plan. When an accepted decision affects the current plan, update the
relevant section and link its ADR as part of the authorized documentation change. When an
accepted decision changes, create a superseding ADR and preserve the previous reasoning.

The local runtime persists tasks, references, queues, run state, monitor observations/incidents, and safety counters/pauses in `.harness_sv/state.json`
with exclusive writer locks and atomic replacement, projecting CSV views for inspection. The
separate decision helper retains its CSV register. This is a single-machine implementation,
not a distributed transactional controller. Input reports remain distinct from generated output.
No board CSV files or live runtime state are created merely by installing the skills.

## Reuse Candidates

Potential wrappers can reuse Superpowers' report-validation, debugging, verification, and
subagent-development procedures. Reuse is not wholesale adoption: reviewed upstream defaults
include automatic commits and cost-based model selection that differ from this plan.
Companion skills, executable helpers, and runtime capabilities must be checked before use.

## Open Decisions

Use the [decision bulletin](#decision-bulletin) to identify explicitly recorded unresolved decisions,
genuine open design choices, and human choices needed for requested or enabled workflows. A heading
or an unset optional feature alone does not make configuration a pending decision. Keep recorded
Open/Proposed items visible; missing evidence remains a reported limitation, not proof of no decisions.

## Configuration When Needed

These setup topics apply when a workflow needs them, not as ten immediate decisions. Reuse saved
settings, inheritance, and existing defaults first. Raise only a remaining human choice needed
for requested or already-enabled work; discover checkable facts rather than asking the user.
The checklist creates no decision records and grants no execution or configuration approval.

1. Project-specific workspace overrides and integration of verified worktree changes. Missing
  mode now inherits the session/parent, otherwise current unless explicit policy requires
  worktree. This default does not approve using uncommitted input or integrating changes.
2. Actual per-project overrides, verified capability snapshots, and applicable validation commands.
  Missing model/effort, mode, tool, and resource allowances now inherit through Runner Inheritance;
  they are not unresolved approvals or a reason to add arbitrary caps. Native routing is not proof
  of a particular model. No live project override/profile is selected by this plan.
3. Which board entries are approved for automatic pickup. The local runtime uses explicit
  auto-eligibility and Low risk, while manual task intake alone does not enable pickup.
4. Per-project review scope/budgets, the development critical-review choice, and bounded repair/retry
  rules. Fresh covers the whole selected repository under those limits. Optional security composition is not
  a blanket project approval to add security passes or external tooling.
5. External adapter availability and permissions, plus the boundary between local reports and
   explicitly authorized remote feedback or work-item updates.
6. The project's timer cadence and any separately approved upstream runtime bootstrap policy.
  A global reference guide does not resolve Graphify runtime availability.
7. Actual project test methods/commands, local/localPPE target definitions, time limits, scheduled
  environment permissions, and which flows are mandatory after development. The implementation
  supplies the declaration and execution mechanism, not invented test infrastructure.
8. Actual restriction allowlists/caps, failed-run thresholds, transient exit classifications,
  and repeatable steps. No numeric examples in the two policy skills are accepted project values.
9. Actual monitor sources/exports, metric units and conditions, measurement windows, freshness,
  scheduling approval/cadence, and any future automatic intake policy. The first implementation
  supports manual proposal acceptance only; direct online monitoring adapters remain deferred.
10. Concrete report platforms/targets, authorized data sources, available platform writers, native
  validation, and publishing destinations. The authoring dispatcher supplies the workflow, not
  preapproved live access or a universal report-generation engine.

## References

- [Decision record](./decisions/2026-09-15-harness-command-and-record-contracts-adr.md)
- [External harness draft](./2026-09-15-project-agent-harness.md)
- [Rules Core](../../skills/core/rules/references/core.md)
- [SkillVault Install](../../skills/core/skillvault-installation/references/install.md)
- [Architecture Decision Records](../../skills/writing/architecture-decision-records/SKILL.md)
- [Graphify reference](../../skills/codeview/graphify/SKILL.md)
- [Superpowers review reception](https://github.com/obra/superpowers/tree/main/skills/receiving-code-review)
- [Superpowers systematic debugging](https://github.com/obra/superpowers/tree/main/skills/systematic-debugging)
- [Superpowers verification](https://github.com/obra/superpowers/tree/main/skills/verification-before-completion)
- [Superpowers subagent development](https://github.com/obra/superpowers/tree/main/skills/subagent-driven-development)