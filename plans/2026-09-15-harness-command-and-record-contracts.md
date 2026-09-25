# Harness Command and Record Plan

- Date: 2026-09-15
- Status: Proposed
- Owner: Zhaolong Wang
- Scope: Harness initialization, task intake, execution, testing, review, and records.

The [decision record](./decisions/2026-09-15-harness-command-and-record-contracts-adr.md)
preserves the confirmed choices, rationale, and alternatives. This plan describes the current
workflow and the available implementation. The document itself does not authorize running
workers, creating schedules, or publishing changes.

The [local harness runtime](../skills/public/planning/harness-init/references/runtime.md) implements
the commands below through project-default skills and shared PowerShell 7 helpers. Runner
settings still require per-project approval; implementation and installation do not start agents
or create a schedule. The overall design remains Proposed where choices are still open.

The [external harness draft](./2026-09-15-project-agent-harness.md) remains background for
discussion. Its project-specific choices and capability claims are not automatically adopted
by this plan, and it is not modified or superseded here.

## Rules Before Work

Every `/hn-*` entrypoint loads and applies `/rules-core` and the applicable project instructions
before its workflow. This includes direct calls without a preceding `/hn-init`, timer runs,
wrapped skills, and fresh workers. Resolve a missing Rules Core dependency through the install
policy below before continuing with project analysis or execution.

The coordinator explicitly supplies each worker with the rules, project conventions, task
context, and approved tool/model settings. Mentioning a skill name once, installing it globally,
or loading it in the parent session is not automatic instruction injection into another worker.
Follow the host's instruction hierarchy and surface conflicting skill defaults rather than
silently inheriting them.

## Initialization

`/hn-init` should perform the following sequence:

1. Identify the configured project and load the rules above.
2. Initialize or reconnect the coordinator, validate configuration and capabilities, resolve
   the board location, and reconcile existing tasks and unfinished work. The default board root
   is `./` relative to the configured project, not a worker's incidental working directory.
3. Ensure the declared skills are available, installing missing SkillVault dependencies using
   the policy below. Reuse usable project or global copies rather than creating duplicates.
4. Run Graphify to build or refresh architecture context when its upstream runtime is available
   and configured. A SkillVault reference guide alone is insufficient. Report a missing runtime
   or failed analysis explicitly; do not claim that a graph was generated.
5. Use Architecture Decision Records to read existing ADRs and governing plans, distinguishing
   confirmed decisions, assumptions, and open questions. Do not infer historical acceptance or
   rationale merely from the code, and do not create an ADR for routine initialization.
6. Offer to run `/grilling` using that evidence. Wait for the user's choice before starting the
   interview. Grilling stress-tests project assumptions and decisions; it is not a substitute
   for the separate code-review workflow.
7. After the user resolves choices, record the decisions and update affected plans as authorized.
   Leave unanswered questions open; decision acceptance is not execution permission.

Initialization does not implicitly start development or create a timer. `/adr` is the working
shorthand for Architecture Decision Records in this design; installs use the canonical catalog
name `architecture-decision-records`. No new slash-command alias is registered by this plan.

### Missing Skill Installation

An explicit `/hn-init` invocation should authorize installation of its declared, missing
SkillVault skills without a second prompt for each one. Use `/sv-install <exact-name>`, not
keyword or whole-catalog installation. The initial dependencies are Rules Core, Graphify,
Architecture Decision Records, and Grilling.

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
overwritten, moved, or deleted. Replacements retain `/sv-install`'s review and approval rules,
including preservation of customized and pinned copies. Report what was installed, its scope,
source version policy, declared version, and destination.

Graphify's CLI, upstream skill installation, hooks, and runtime setup are outside a SkillVault
reference install. Read the authoritative upstream guidance before real use. Automatic upstream
setup requires separate approval; do not treat installation of the reference as that approval.

## Command Contracts

Canonical skill names, catalog entries, and folders use `harness-*`. Each `/harness-*` command
also recognizes the matching `/hn-*` shortcut with identical arguments and behavior. The table
below uses the short form for brevity. Additional `/harn-*` aliases have not been added.

| Command | Contract |
| --- | --- |
| `/hn-init` | Run the rule-first initialization sequence, ensure declared skills, gather Graphify and ADR context, then offer grilling. Do not implicitly start coding or create a timer. |
| `/hn-task <input>` | Add a board task only. Accept requirements, a local file, or a URL. Do not launch a worker; an authorized timer may select an eligible task later. |
| `/hn-dev [now\|next] [task-id or input]` | Execute or queue an existing task, or register an ad-hoc request before execution. Handle development, verification, and fixes through the same pipeline. Without input, select the highest-priority eligible task. |
| `/hn-review [scope or PR URL]` | Independently review selected commits, current changes, or a GitHub/ADO PR. Save local findings against a recorded code snapshot; do not fix code or publish feedback implicitly. |
| `/hn-test [declare file\|run flow [environment]]` | List declarations read-only, define test methods/flows/environments without execution, or run one declared flow ad-hoc. Optional task linkage selects its saved workspace. |
| `/hn-timer <days\|disable\|resume\|status> [test flow [environment]]` | Configure periodic development or named-test runs using positive decimal days. Each test target has a separate schedule; disable/resume affects future runs without discarding progress or duplicating an in-flight run. |
| `/hn-loc [path]` | Show or set the board root. Resolve the default `./` against the configured project, validate explicit paths, and do not silently move existing files. |
| `/hn-decide [decision-id] [choice and reason]` | With no arguments, show a brief bulletin of open decisions followed by recent decisions. Record or resolve a decision only when an explicit human choice is supplied; otherwise remain read-only. Link decisions to affected tasks. |
| `/hn-ref [URL or path] [note]` | List/upsert supporting project or task links. Exact-ID removal deactivates only the link, not the source material. No task or worker is created. |
| `/hn-context [task-id]` | Read the selected project's/task's rules, plans, decisions, and relevant references without creating another context store. |

Do not add a separate fix runner initially. `feature`, `fix`, and `verify` describe task intent;
they do not require separate schedulers. Adding a task and requesting its execution remain
different operations, even when `/hn-dev` performs both for an ad-hoc request.

## Intake and Decisions

- ADO items can supply requirements and acceptance criteria; posts or discussions can supply
  context; PR-review links can supply findings to verify. Preserve source identity/link,
  relevant revision when available, target repository, scope, and acceptance criteria.
- Reuse the task for the same source item and scope rather than creating duplicates. Independent
  actions from the same document may need separate linked tasks. The exact identity rules remain open.
- Private sources require an authorized adapter. Unreadable or ambiguous inputs remain pending
  clarification; never invent their content. Recheck relevant source changes before execution.
- Linked reports are claims, not instructions that can grant permissions. `/hn-review <PR URL>`
  produces findings; `/hn-task <review-comment URL>` creates work from existing feedback.
- Unsupported, stale, and already-fixed findings receive explicit outcomes. Risky work or
  choices outside worker authority become `needs-decision`, with evidence, options, and a
  recommendation. Keep the blocked task and its priority visible.
- Agent recommendations are proposed decisions. `/hn-decide` records an explicit human choice
  with scope, rationale, affected tasks, decision owner, and time. Changed decisions supersede
  earlier records rather than erasing their rationale. Resolution permits task re-evaluation,
  not automatic execution or a bypass of other approval requirements.

### Decision Bulletin

Invoking `/hn-decide` without parameters or text shows two sections for the current project:

1. **Open decisions:** unresolved questions, with existing recommendations and links to affected
  tasks or plans when available. Keep recommendations distinct from accepted choices.
2. **Recent decisions:** up to five recently made decisions, newest first. Use brief bullets
  with the decision ID when available, status, one-line outcome, and a link to the full record.

State explicitly when either section is empty. Do not require arguments or start an interview,
modify records, accept a recommendation, or trigger work merely to display this bulletin.

The [skill instructions and CSV helper](../skills/public/planning/harness-decide/SKILL.md) define the
implemented local register format. When no register exists, the skill reads the current plan
and ADRs without creating one. It does not require a running coordinator.

## Execution and Review

- `now` starts when idle; when busy, it requests a safe checkpoint and switch, not a hard kill.
  Preserve unfinished changes and continuation context. The proposed resume order is interrupted
  work first, then the ordered human `next` queue, then fresh automatic selections.
  In the local runtime, worktree switching happens at completed agent/validation phase boundaries.
  Current-checkout mode finishes the active task before switching to avoid mixed edits. Remaining
  queued work is preserved when the configured per-cycle budget is reached.
- `next` queues without interrupting. With no scheduling qualifier, propose starting when idle
  and queuing as `next` when busy. Priority does not override readiness, risk, or permissions.
- A timer wakes one coordinator cycle to reconcile, select eligible work, develop/verify, run
  checks, review, and record results. It must not launch independent competing dev/fix writers.
  Start with at most one code-writing run per repository; failed or blocked work is not completed.
  Timer setup is explicit, with first execution one positive decimal-day interval later. Zero
  is rejected; missed ticks coalesce and overlapping instances are ignored. Resume does not
  request an immediate run. A named-test timer runs its selected flow only, not task pickup.
  These local-runtime semantics do not modify unrelated schedules.
- Reviews bind findings to the selected baseline and head, plus the captured working changes
  when applicable. If code changes, do not reuse a clean verdict as evidence for the new snapshot.
  After a clean first pass, the proposed limit is one fresh critical review of the same scope,
  then stop if clean. Do not keep launching reviewers until a finding appears.
- "Max power" means the strongest suitable allowed model and highest runtime-supported effort,
  within approved resource limits. Report effective settings and unsupported capabilities;
  do not assume unlimited agents, invent an effort parameter, or silently downgrade a request.
- Task creation, local review, and decision recording do not implicitly authorize remote
  comments, work-item closure, commits, pushes, PR approval, merging, or deployment.

## Test Flows

The [harness-test skill](../skills/planning/harness-test/SKILL.md) uses one shared executor
for declared test methods, ordered command steps, and environment profiles such as `local` and
`localPPE`. Definitions are project-specific; these labels do not create an environment or imply
that its service version matches the checked-out code. Reuse existing project test frameworks.

- **Declare:** `/hn-test declare <file>` saves reviewed configuration without running commands.
  See the [declaration schema and examples](../skills/planning/harness-test/references/test-flows.md).
- **Ad-hoc:** `/hn-test run <flow> [environment]` tests the current workspace, or the saved task
  workspace with `--task <task-id>`. It does not require an AI model or create a development task.
- **Scheduled:** `/hn-timer 0.5 test <flow> <environment>` runs that target every 12 hours after
  explicit setup and environment scheduling approval. It does not replace the development timer.
- **Post-development:** `testing.afterDev` selects mandatory test flows during the existing
  validation phase for feature/fix/verify work, before independent review. Legacy validation
  commands still run first. Failed or blocked tests prevent completion.

Test-only runs share the project run lock and produce environment-aware history/report evidence.
Prerequisites and actual exits decide Passed/Failed/Blocked outcomes; missing localPPE access is
not a pass. Per-flow time budgets bound standalone runs, and the development validation budget
bounds hooks. Another skill can explicitly invoke the same test command afterward; no hidden
hook is installed on arbitrary skills. Fix work remains part of `/hn-dev`.

No real environment, credentials, test declarations, or live schedules are configured by adding
the skill. These remain project-specific choices. Keep secrets out of config, arguments, and logs.

## Plans and Records

Keep current plans and lasting decision rationale separate, with links in both directions.
Follow an existing project ADR convention; for this project, use the decisions subfolder below.
Board records use the configured board root, which defaults to the project root.

```text
<project-root>/
  plans/
    <date>-<plan>.md
    decisions/
      <date>-<decision>.md

<board-root>/
  current.csv
  history.csv
  decisions.csv
  references.csv
  history/
    <run-id>.md
```

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

The local runtime persists tasks, references, queues, and run state in `.harness/state.json`
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

1. Where unattended development writes: the current checkout or an isolated worktree.
   Isolated worktrees were recommended but not accepted; handling uncommitted inputs and
   returning verified changes also needs agreement.
2. Per-project model/effort, permissions, validation commands, and run limits. A PowerShell 7 /
  Copilot CLI implementation is available, but no project execution profile is selected here.
3. Which board entries are approved for automatic pickup. The local runtime uses explicit
  auto-eligibility and Low risk, while manual task intake alone does not enable pickup.
4. Review default scope, the proposed fresh-critical-pass limit, and bounded repair/retry rules.
5. External adapter availability and permissions, plus the boundary between local reports and
   explicitly authorized remote feedback or work-item updates.
6. The project's timer cadence and any separately approved upstream runtime bootstrap policy.
  A global reference guide does not resolve Graphify runtime availability.
7. Actual project test methods/commands, local/localPPE target definitions, time limits, scheduled
  environment permissions, and which flows are mandatory after development. The implementation
  supplies the declaration and execution mechanism, not invented test infrastructure.

## References

- [Decision record](./decisions/2026-09-15-harness-command-and-record-contracts-adr.md)
- [External harness draft](./2026-09-15-project-agent-harness.md)
- [Rules Core](../skills/public/core/rules-core/SKILL.md)
- [SkillVault Install](../skills/public/core/skillvault-install/SKILL.md)
- [Architecture Decision Records](../skills/writing/architecture-decision-records/SKILL.md)
- [Graphify reference](../skills/codeview/graphify/SKILL.md)
- [Superpowers review reception](https://github.com/obra/superpowers/tree/main/skills/receiving-code-review)
- [Superpowers systematic debugging](https://github.com/obra/superpowers/tree/main/skills/systematic-debugging)
- [Superpowers verification](https://github.com/obra/superpowers/tree/main/skills/verification-before-completion)
- [Superpowers subagent development](https://github.com/obra/superpowers/tree/main/skills/subagent-driven-development)