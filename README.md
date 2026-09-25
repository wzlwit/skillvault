# SkillVault

A single repository for public, shareable skills.

## Purpose

- `skills/` for open-source or shareable skills
- `templates/` for skill scaffolds

Public skills use one category level, for example `skills/core/skillvault-installation` or
`skills/system/schedule-manager`.
Reusable scaffolds stay in top-level `templates/`, outside the skill catalog. Source folder
moves do not update installed copies or live schedules; installed tools that use old source
paths need a separately approved update.

The registered management commands are `/skillvault-installation`, `/skillvault-discovery`,
`/skillvault-authoring`, and `/skillvault-refresh`. Type `/skillvault` to filter these full names
in the slash-command picker. `/sv-*` spellings are conversational shortcuts, not separate
registered skills.

The `writing` category groups technical documentation and prose-editing skills, including
`architecture-decision-records` and `humanizer`. Their names and workflows stay separate;
manifest tags distinguish their focus. Skill categories do not change the project's `docs/` root.

## Project Documentation

`docs/` is the parent for project documentation subfolders. Plans live in `docs/plans/`, with
decision history in `docs/plans/decisions/`. Add other documentation subfolders only when needed.

- [Harness working plan](docs/plans/2026-09-15-harness-command-and-record-contracts.md)
- [Topic structure, diagram, and migration map](docs/plans/2026-09-16-topic-skill-refactor.md)
- [Source layout decision](docs/plans/decisions/2026-09-23-source-layout-adr.md)
- [Shared checkout and runtime ownership](docs/plans/decisions/2026-09-23-shared-ownership-adr.md)
- [Bounded refresh-contention retries](docs/plans/decisions/2026-09-24-refresh-contention-retries-adr.md)
- [Recovery, runtime compatibility, and baseline acceptance](docs/plans/decisions/2026-09-24-recovery-compatibility-and-harness-baseline-adr.md)
- [Current-copy-only installation and temporary rollback](docs/plans/decisions/2026-09-25-current-copy-only-installation-adr.md)
- [Harness decision record](docs/plans/decisions/2026-09-15-harness-command-and-record-contracts-adr.md)
- [External harness reference draft](docs/plans/2026-09-15-project-agent-harness.md)
- [Kusto query optimization session notes](docs/notes/kusto-query-optimization.md)

The spelling is a common tooling convention, not a universal requirement:
[MkDocs defaults its documentation directory to `docs`](https://www.mkdocs.org/user-guide/configuration/#docs_dir),
and [GitHub Pages supports a `/docs` publishing source](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).
No documentation site or publishing workflow is configured by this folder choice.

Skills honor an explicit output path and existing artifact convention first, then the project's
documented/used documentation root (`doc/`, `docs/`, or another configured directory), and use
`docs/` only when none is established. Do not create both spellings or silently move another
project's documents. Root entrypoints such as `README.md` and `AGENTS.md` stay in place, and
skill-owned guides/references remain bundled with their skills. Harness runtime/board locations
are independent of the documentation root.

## Recommended schema

Each skill folder should include a manifest named `skill.json` and a `README.md`.

Example:

```json
{
  "name": "my-skill",
  "title": "My Skill",
  "version": "1.0.0",
  "kind": "agent",
  "description": "Short description of what the skill does.",
  "tags": ["devops", "cli"],
  "author": "Your Name",
  "license": "MIT",
  "source": {
    "repo": "skillvault",
    "path": "skills/workflows/my-skill"
  },
  "install": {
    "global": true,
    "project": true,
    "session": true,
    "defaultScope": "global",
    "globalPath": "~/.copilot/skills",
    "strategy": "copy"
  }
}
```

`catalog.json` is a compact, name-sorted lookup index. Keep only `name`,
`description`, `path`, and `version` there. Derive display titles and grouping from the
skill folder or the skill's own `skill.json`.

Reusable catalog skills default to global availability. Explicit project installation remains
available for supported, repository-pinned or customized copies; an absent manifest default
still falls back to project scope. Keep sibling runtime dependencies in the selected scope.
Global installation does not make project state, output paths, or execution permissions global,
does not install every catalog skill through bootstrap, and does not migrate existing copies.
See the [per-skill scope audit](review/install-scopes-2026-09-15.md) for the assessed defaults.

Keep `version` present in both the catalog and manifest: use the declared version string,
or JSON `null` when no version is declared. `latest` describes the requested installation
policy, not a release version. Preserve original authorship on imports and disclose any
adaptation; access to a source repository does not establish redistribution rights.

Catalog entry example:

```json
{
  "name": "skillvault-installation",
  "description": "Manage installed SkillVault skill copies by subcommand.",
  "path": "skills/core/skillvault-installation",
  "version": "1.1.0"
}
```

## Skill Overlap

When skills share meaningful work, mention the counterpart and shared workflow briefly in
the descriptions in `catalog.json`, `skill.json`, and `SKILL.md` frontmatter. Keep each skill's
distinct purpose clear, preserve trigger phrases and reference-only limitations, and leave
the catalog's four-field structure unchanged.
An optional follow-up step alone is not material overlap; describe it directly, for example,
"can install the result afterward."

| Skill | Overlap | Distinct purpose |
| --- | --- | --- |
| `brainstorming` | Questions and trade-offs with `grilling`. | Develop alternative designs collaboratively; preserve existing drafts and seek approval before implementation. |
| `grilling` | Trade-offs with `architecture-decision-records`; planning with `planning-with-files`. | Interview to test a plan and resolve choices. |
| `architecture-decision-records` | Trade-offs with `grilling`; decision notes with `planning-with-files`; decision history with `harness-decision`. | Preserve architectural rationale, status, and superseded history. |
| `harness-decision` | Decision history with `architecture-decision-records`. | Show open decisions by default, request closed/all views explicitly, and record human choices. |
| `handoff`, `harness` | Summarizing selected work and its context. | Handoff writes an explicitly requested continuation note; context provides a read-only project/task view. Neither controls execution. |
| `harness-task`, `harness-dev` | Both accept task input. | Task is add-only; dev adds bounded execution, validation, and independent review. |
| `harness-test`, `harness-dev` | Executable validation. | Test owns reusable flows/environments and test-only runs; dev invokes declared gates as part of task completion. |
| `harness-monitor` | Checks with `harness-test`; intake with `harness-task`; metric contracts with `kpi-dashboard`. | Evaluate exported measurements and incident proposals, separating collection success from service health. |
| `harness-report` | Implementation with `harness-dev`; design with `kpi-dashboard`; Jarvis authoring with `jarvis-metrics`. | Select one report-authoring route, reuse artifact identity, and coordinate validation without a new rendering engine. |
| `jarvis-metrics` | Design with `kpi-dashboard`; authoring with `harness-report`. | Guide Jarvis metric-source selection and widget configuration without bundling a client, query executor, or alerting API. |
| `kpi-dashboard` | Design with `harness-report` and `jarvis-metrics`; metric contracts with `harness-monitor`. | Define formulas, populations, units, freshness, and layouts independently of execution or incident intake. |
| `harness-policy` | Limits and failure handling within one topic. | `limits` defines boundaries; `fallback` handles bounded test retries, failed-run thresholds, and durable pause/stop/resume. |
| `harness-review`, `pr-review`, `differential-review` | Code review against a baseline. | Harness review stays project-first; PR review selects remote snapshots and the user-wide list. Both share bounded review passes and can load the differential security methodology. |
| `harness-timer`, `skillvault-refresh`, `schedule-manager` | Schedule setup and controls. | Timer dispatches to existing project, PR, and refresh owners; refresh performs one-way copying; schedule-manager administers Windows tasks broadly. |
| `skillvault-discovery` | Search, evaluation, and explanation within one topic. | `explain` describes use; `evaluate` judges adoption value; `search` finds candidates. |
| `planning-with-files` | Planning with `grilling`; decision notes with `architecture-decision-records`. | Reference to upstream task tracking and recovery; this entry bundles no upstream workflow, hooks, scripts, or templates. |

The [brainstorming guide](skills/planning/brainstorming/SKILL.md) adapts the Superpowers
workflow for the selected discussion or project, with global availability by default.
It does not install the full plugin, invoke follow-on skills,
or commit design documents automatically.

`/skillvault-authoring upsert` checks relevant counterpart instructions before recording overlap for either a
name or URL, preserves or corrects existing overlap notes on updates, and updates relevant
repository documentation. Partial overlap is not duplication or permission to remove a skill.
Existing design documents or task notes may already cover some of these roles.

## Project Decisions

The [harness-decision skill](skills/planning/harness-decision/references/workflow.md) defaults to global availability.
Use `/harness-decision` for a read-only bulletin of active open decisions plus a one-line
**Configuration When Needed** summary and link. Optional setup is not an immediate blocker;
raise a missing setting only when requested or enabled work needs a human choice that saved
settings, inheritance, or defaults cannot resolve. Recorded Open/Proposed decisions stay visible.
`list closed` shows up to five recent resolved decisions; `list all` includes open/recent decisions
and the detailed configuration checklist. `--recent <count>` changes only the resolved-result limit.
Use `/harness-decision list <decision-id>` for any status, or `record` with an explicit human choice.
Closed and exact-ID views omit the configuration checklist. See the
[project setup topics](docs/plans/2026-09-15-harness-command-and-record-contracts.md#configuration-when-needed).
It can read existing plans and ADRs without initializing a harness; its bundled PowerShell helper
handles structured CSV reads and writes. It does not start tasks, schedules, or interviews.

## Session Handoff

Use `/handoff [next-session focus] [--output path]` to write a concise continuation note with
artifact/evidence links, open decisions, blockers, process or side-effect uncertainty, and the
first next action. The [handoff guide](skills/planning/handoff/SKILL.md) is a global-default
MIT adaptation of Matt Pocock's lightweight workflow and retains explicit-only invocation.
It follows the project's established handoff/documentation location unless an output is supplied;
standalone work can use OS temporary storage. No harness initialization or Python helpers are needed.
Actual stop/recovery/resume stays with `/harness-policy fallback`; a note does not clear pauses, start another
writer, authorize its suggested actions, or mark unfinished work complete.

Development, report authoring, blocked skill searches, recovery, and unresolved decision workflows
can offer `/handoff` when work must transfer to another session or person. `/harness context` can read
a supplied note and reconcile it with current records. These are optional follow-ups, not automatic
notes or new skill dependencies: read-only commands still need a separate explicit request to write
a note, and routine phase transitions/timer ticks keep their existing behavior.

## PR Review

[PR review](skills/github/pr-review/SKILL.md), [watchlist management](skills/github/pr-watch/SKILL.md),
and `/harness-timer set pr` share one user-wide watchlist under `~/.copilot/pr-review`, independent of the current project.
They support GitHub and explicitly configured GitHub Enterprise hosts through authenticated `gh`.

| Command | Purpose |
| --- | --- |
| `/pr-review run [PR-or-repository-URL]` | Review an exact PR, a repository's latest open PRs, or the saved list; bare invocation reads saved status |
| `/pr-watch add <URL>` | Add a PR/repository; no immediate execution |
| `/pr-watch remove <URL-or-W-ID>` | Remove a watch entry while preserving reports and remote PRs |
| `/pr-watch list` | Show entries, filters, recorded revisions, outcomes, and blockers without remote calls |
| `/harness-timer set pr <duration>` | Configure one whole-watchlist logical schedule under the shared heartbeat |

The [shared setup reference](skills/github/pr-review/references/runtime.md) defines the
controller, configuration, and scheduler contract. `/harness-review` remains current-project review;
its PR-URL route delegates one-way to `/pr-review`. The PR worker reuses the shared read-only
review implementation with verified isolated checkouts, complete paginated comment/thread
evidence, and a fresh second pass only when the first finds nothing new. It never switches the
user's current branch or runs untrusted PR code, hooks, builds, or tests.

Setup requires a strongest-first approved model list, verified per-model effort/context choices,
and explicit time/credit/count bounds. The helper requests the maximum supported permitted
combination, including long context when approved; it does not invent model access or exact
token capacity. Unchanged completed snapshots skip; failed, stale, or incomplete ones remain
pending. Reports are local, not PR comments, approvals, fixes, or merges.

There is one logical PR schedule per user for all watched targets, sharing the heartbeat with other targets.
Set reuses its stable identity; an omitted duration reuses its saved cadence or requires an answer.
The timer uses current-user interactive logon, limited privilege, overlap exclusion, and the
saved review settings. Installation creates no list entries, runner settings, or live task.
An explicit setup request with approved targets, capabilities, budgets, and cadence is separate.

## Local Harness

The [runtime guide](skills/planning/harness/references/runtime.md) describes the shared
PowerShell 7 runtime and required configuration. Harness skills default to global availability;
explicit project copies remain supported. Both use the selected project's configuration and state.

Canonical names and folders use `harness` and `harness-*`. `/hn` and `/hn-*` are shorthand for quick typing,
not a separate registered skill. For example, `/hn-dev run` selects `/harness-dev run`.
Each topic routes by its first argument; descriptions and argument hints advertise choices,
not nested autocomplete. Bare multi-action topics use read-only `list`, including the timer.
For example, install `harness-dev` through
`/skillvault-installation install harness-dev`, then use `/harness-dev run <task-id>`.

| Command Synopsis | Responsibility |
| --- | --- |
| `/harness [list\|root\|init\|context\|clean] [<arguments>...]` | Project setup, context, and historical data |
| `/harness-policy [list\|set\|pause\|stop\|resume] [<arguments>...]` | Runtime limits and failure responses |
| `/harness-task [list\|add\|update] [<arguments>...]` | Task records and readiness, without execution |
| `/harness-dev [list\|run\|queue] [<arguments>...]` | Execution and queues, reusing task intake |
| `/harness-review [list\|run] [<arguments>...]` | Independent code review |
| `/harness-test [list\|declare\|run] [<arguments>...]` | Reusable test definitions and execution |
| `/harness-monitor [list\|declare\|check\|accept] [<arguments>...]` | Observations and incident proposals |
| `/harness-report [list\|upsert] [<arguments>...]` | Report and query authoring |
| `/harness-timer [list\|set\|disable\|resume\|clean\|migrate] [<arguments>...]` | Cadence and schedule lifecycle, not historical-data cleanup |
| `/harness-link [list\|add\|remove] [<arguments>...]` | Supporting URLs, files, and coding-repository links |
| `/harness-decision [list\|record] [<arguments>...]` | Human decisions and their register |

One folder registers one topic; actions are routed inside it. There are no separate
`harness-management`, `harness-init`, or `hn-*` skill registrations.

`help`/`status` remain read-only aliases rather than extra advertised actions. `/hn`, `/hn-*`, and legacy conversational commands select their matching
operation. Source folders use `harness`, `harness-*`, and `skillvault-*`, without duplicate shorthand bundles.
See the [actual folder layout](docs/plans/2026-09-16-topic-skill-refactor.md#folder-layout).
Callers of removed source paths must use the canonical folders. The shared heartbeat is implemented
in source; installed-copy replacement and migration of exact live tasks remain separately approved operations.

`/harness root` shows the selected root; `/harness root <path>` selects the parent containing
`.harness_sv/`. First or missing selection prompts with the absolute current folder (`./`); an
unanswered first-selection prompt uses that displayed fallback, while rejection/invalid paths
do not. A valid new path becomes the session Root before asking **Move the existing harness?**
when the previous harness was initialized. **Move is the displayed default, including no answer.**
Explicit answers or user instructions take precedence; No or cancel leaves the old data in place.
Yes or the unanswered default previews and applies relocation from the saved previous root.
`/hn-root <path>` follows the same workflow. The new Root stays selected regardless of the move
outcome. A failed move does not count as successful migration. No move
flag is needed, and no move prompt is shown for an uninitialized source or unchanged path.

A move selected explicitly or by the displayed default relocates owned files and registered worktrees, preserves identity
and uncommitted work, and updates stored schedule paths without changing cadence or enabled state.
External code and board locations stay put; `executionRoot` retains the original implicit coding
and test target. See [relocation boundaries and recovery](skills/planning/harness/references/loc.md#explicit-relocation).

All harness-owned records, reports, logs, documents, declarations, and local outputs default
to that `.harness_sv/` unless the user explicitly selects another destination. See the
[complete project hierarchy](docs/plans/2026-09-16-topic-skill-refactor.md#project-storage).
Existing configuration and previously selected artifacts move only through the root-change
workflow above, not through installation or a change to artifact defaults.
`loc` aliases `root`. A recognized legacy SkillVault `.harness` controller is reused in place
when `.harness_sv` does not exist; unrelated folders are not adopted or merged.

Other actions derive their project path from Root, including the `./` fallback, without another
location confirmation. This includes `/harness init` and reconnects. The session supplies `-ProjectPath`
automatically and adds `-ConfirmLocation` for Init; these are caller arguments, not extra user prompts.
If Root has not been selected and no explicit target was supplied, use `/harness root ./` once first.
Selecting Root alone does not request initialization or waive operation-specific approvals.
Timers cannot initialize projects. `/harness loc --board <board-path>` retains empty-board placement and does
not change the implementation repository or migrate existing records.

The harness project can be a plain, non-Git controller folder. Add each existing local coding
repository with `/harness-link <local-git-root>`, then select its returned ID through
`/harness-task <requirements> --repo-ref R-001` or `/harness-dev <task-id> --repo-ref R-001`.
Keep `ProjectPath` at the controller: code and validation use the selected repository/current
worktree, while state and reports stay in the controller. `/harness-review --repo-ref R-001` reviews
that repository's checkout. No reference implicitly clones a URL, grants permissions, or starts work.

Task matching normalizes known source/reference syntax and outer whitespace without fuzzy
matching or erasing meaningful path/code case. Explicitly revised completed requirements create
a linked follow-up, preserving the original record and same-repository workspace. It must pass
its own validation and required reviews; completion does not commit, merge, or push changes.

Installation creates no live schedule and runs no agents. `/harness init` leaves model, effort,
permissions, workspace, review policy, and budgets unset as inheritance markers. Runtime resolution
uses project overrides, current-session/parent context, then maximum verified or native settings;
missing allowances do not block execution or require duplicate approval. Use `-RunnerContext` or
`-RunnerContextPath` for the host handoff; explicit limits and denials remain enforced. Test-only
runs need applicable test flows/environments, not an AI model.
State and the default board live under the project's `.harness_sv` directory. Run evidence is in
`.harness_sv/history/`; authored guidance uses `.harness_sv/docs/`. Existing boards need a reviewed
migration, not an automatic file move. Application source and linked targets stay in their selected repositories.
Real workers use Copilot CLI; validation commands run as the current OS user, not in a security
sandbox. The test suite uses fake agents and scheduled tasks, plus an isolated subprocess check.
Git snapshot and worktree checks use a temporary repository, never the user's working branch.

`/harness-review run` uses an explicit `--base` or a merge-base with local `origin/develop`/configured
upstream, so committed-ahead work is included with working changes. Without either ref it reports
working-changes-only coverage. If a completed first pass finds nothing new compared with the last
compatible report, it makes one fresh independent pass over the whole selected repository and
keeps supported findings from both. Ordinary Review and development Critical stay change-scoped;
Fresh keeps the same permissions and budgets, with inadequate coverage reported as blocked.
The [review guide](skills/planning/harness-review/references/workflow.md) explains exact
newness matching, scope, and the optional `/harness-review --security` composition with
[differential-review](skills/security/differential-review/SKILL.md). General review and
security methodology stay separate; neither implies automatic fixes, publication, or a scanner.
Local changes during either pass restart Review on the updated snapshot, at most twice, while
keeping the original baseline and restrictions. Superseded findings remain in the report, not the
current verdict. Persistent edits return `Partial`; pinned PR snapshots and worker errors do not retry.

The review coordinator keeps the request open across findings checkpoints: hand findings to the
existing dev/proposal workflow, let dev fix and validate, then repeat Changes -> Full until no
supported unfixed issues remain. Each script round releases the run lock for dev. No new findings
only triggers Full; it does not mean clean. Recheck older issues, including Full findings outside
the diff. Do not launch another fixer or repeat unchanged snapshots while waiting. Existing budgets,
permissions, failures, and pause/stop requests still apply; unavailable fixes remain pending.

Use `/harness-test declare <file>` for [test-flow declarations](skills/planning/harness-test/references/test-flows.md),
then `/harness-test run smoke localPPE` for an ad-hoc run. `testing.afterDev` applies the same flows
after feature/fix/verify work, before review. `/harness-timer set project 12h test smoke localPPE` schedules only
that target every 12 hours when its environment explicitly allows scheduling; it does not replace
the development timer. Definitions do not provision localPPE or install frameworks. Test evidence
uses the existing history CSV and linked reports, with flow/environment identity and real exits.

Use `/harness-monitor` to inspect saved definitions, health, incidents, and proposals without collecting
data. `/harness-monitor declare <file>` previews [monitor declarations](skills/planning/harness-monitor/references/monitoring.md);
`/harness-monitor check <name>` reads a local numeric JSON snapshot from a reviewed query/export and
evaluates its identity, measurement window, freshness, and declared condition. Repeated breaches
reuse one incident; stale or failed collection stays Unknown. Unhealthy service data is successful
monitoring, so it does not pause a working monitor. `/harness-monitor accept <incident-id>` previews
explicit task acceptance; accepted investigations are manual-only, and recovery never completes
them automatically. The [monitor guide](skills/planning/harness-monitor/references/workflow.md) explains
approval and evidence handling. No direct online/PBI connector or automatic intake is bundled.

Use `/harness-report upsert <purpose> --type powerbi|grafana|jarvis|web|query` for the
[report-authoring dispatcher](skills/planning/harness-report/references/workflow.md). It loads
the reusable [KPI design companion](skills/data/kpi-dashboard/SKILL.md) and only
the relevant platform guidance, then uses available authorized tools and the existing `/harness-dev`
workflow for tracked local implementation. Bare `/harness-report` shows status/actions; `upsert`
updates an identified existing target or creates a confirmed missing one. `create` and `update`
remain aliases, not separate existence requirements;
`--design-only` requests a specification. Design-only, Created, Validated, and Published are
different outcomes, not interchangeable success claims. The dispatcher is a session workflow,
not a new PowerShell action or report renderer; the selected platform's writer must be available.
No platform skills/tools are installed automatically, and publishing/monitoring remain separate.
The KPI companion is a curated MIT adaptation with explicit unknown version and no bundled
untested upstream SQL or Streamlit generator. Both skills default to global availability;
artifact destinations and access approvals remain specific to the requested project/platform.

The `jarvis` route selects [jarvis-metrics](skills/monitoring/jarvis-metrics/SKILL.md)
for Geneva/MDM, Kusto-to-Metrics or Logs-to-Metrics source decisions and widget configuration.
For example, `/harness-report service-health --type jarvis --design-only` prepares a specification;
creating a saved Jarvis artifact requires an available authorized authoring surface. Query-only
work remains `--type query`, including queries intended for Jarvis, without compulsory conversion
or visuals. Jarvis-native monitors/alerts and `/harness-monitor` JSON checks are distinct optional targets.

Bare `/harness-timer` lists saved schedules and actions. `set project <duration>` schedules the
existing gated E2E pipeline; explicit review, test, and monitor targets reuse their own executors.
Durations use `m/h/d/n/y` for minutes, hours, fixed days, calendar months, and calendar years.
New work schedules require an explicit duration; updates can reuse the exact saved cadence/context.
For matching agents or schedules, confirm **Reuse (singleton) or New?**; `--new <name>` remains
create-only and does not authorize competing writers. Old `now`/`next` development requests map
to `run --now`/`queue`; a queue request never starts a worker.

One current-user heartbeat dispatches all registered logical schedules, with a routine `1d` baseline
shortened automatically by faster job intervals and earlier deadlines. Active workers keep a
30-minute check cap. `/harness-timer set heartbeat 12h` previews a baseline-only change;
`list heartbeat` reads it. Applying preserves job cadence, start-time anchors, and maintenance.
Overdue jobs found unavailable or conflicting wait for the adaptive recheck rather than causing
one-minute polling. The heartbeat is script-only, not an AI model configured as `auto`.
Project definitions, nextDue, enabled state, and active
claims are in `.harness_sv/schedules.json`; the central registry and latest job receipts are under
`~/.copilot/skillvault/scheduler`. Intersecting coding roots serialize; independent approved roots
can run together. Signed-out execution and machine wake are not currently enabled; conditional
maintenance permission does not activate them. Existing OS tasks need
an exact `migrate` preview; no install silently changes them or their cadence.

`/harness clean [--policy <file>] [--apply]` previews historical-data cleanup or configures
retention. Retention defaults to **90 days and 5,000
completed entries per harness**, with optional **1,000 per topic** instead of the total count.
Protect active/pinned/linked evidence, open tasks/incidents, policy evidence, and comparison context.
Records and corresponding files are pruned together; authored plans, decisions, and evaluations
are never run-history candidates. `/harness-timer clean` instead handles stale schedules:
confirmed stale jobs are disabled first; deletion requires
approval after a 30-day grace. Unavailable, failed, idle, and manually disabled do not mean stale.

`set maintenance` previews automatic cleanup on **Saturday 08:30-09:00 local time**. Once enabled,
it uses the same heartbeat, skips active work, and performs routine cleanup with local scripts.
Historical-data work delegates to the same operation as `/harness clean`; no separate cleanup
algorithm or management topic is introduced.
**Machine wake and AI assistance are allowed when necessary**, not on every run. Identify the
need first; this permission does not enable wake, start an AI process, or expand deletion authority.
No remote scans or catch-up outside the window. See the
[scheduler contract](skills/planning/harness-timer/references/scheduler.md) for configuration,
migration, duration edge cases, and retained legacy routes.

Use `/harness-policy list [limits|fallback]` to inspect policy without writing anything. `set limits|fallback <file>`
previews an explicit replacement; applying it requires a reviewed declaration, human owner, and reason.
The [restriction guide](skills/planning/harness-policy/references/limits.md) and
[fallback guide](skills/planning/harness-policy/references/fallback.md) include field contracts, usage,
and situation/response tables. Policy examples are not applied automatically. `/rules` still manages
human guidance rather than these runtime checks. Safety pauses survive timer ticks and recovery;
resume clears only the reviewed pause, without starting work or requeuing failed tasks. Automatic
retries require explicitly repeatable named test steps and approved transient exits. Eligible steps
default to one additional attempt after five seconds, within the original time budget; explicit
settings remain effective, including `maxRetries: 0`. No exit code is globally declared transient,
and failed AI sessions are not restarted. Per-session CLI credit limits are not aggregate billing
or sandbox guarantees.

`/skillvault-discovery explain <skill>` is a global-default, read-only explanation helper covering purpose,
principles, workflow, step-by-step usage, outputs, limits, and source links. It does not execute
or install the skill it explains.

`/skillvault-discovery evaluate <candidate>` saves a completed public-safe assessment in
`docs/evaluations/<candidate>.md` by default, including defer/skip. `--chat-only` opts out.
Reuse the record on reevaluation while verifying fresh evidence; private assessments need a private
destination. These lasting references are outside history cleanup and never enter the catalog unless
an actual skill is authored. See [the Oh My Pi assessment](docs/evaluations/oh-my-pi.md).

## Selected Category Skills

These six additions are starting recommendations based on the upstream workflows and
licenses reviewed on 2026-09-14, not an objective worldwide ranking. Existing skills remain
in place. Each guide defaults to `global` availability; explicit project copies can still be
pinned or customized independently.

| Category | Skill | Upstream | Why selected |
| --- | --- | --- | --- |
| `testing` | `webapp-testing` | [Anthropic](https://github.com/anthropics/skills/tree/main/skills/webapp-testing) | Focused Playwright workflow for browser behavior, distinct from UI design review. |
| `security` | `differential-review` | [Trail of Bits](https://github.com/trailofbits/skills/tree/main/plugins/differential-review/skills/differential-review) | Security review of changes against a baseline, with concrete evidence and coverage limits. |
| `api` | `openapi-spec` | [wshobson/agents](https://github.com/wshobson/agents/tree/main/plugins/documentation-generation/skills/openapi-spec-generation) | Code-first or design-first REST contracts and validation without a full scaffolding framework. |
| `data` | `supabase-postgres-best-practices` | [Supabase](https://github.com/supabase/agent-skills/tree/main/skills/supabase-postgres-best-practices) | Maintainer guidance for Postgres queries, schema, connections, and RLS; not generic SQL or Power BI. |
| `github` | `github-issues` | [GitHub Awesome Copilot](https://github.com/github/awesome-copilot/tree/main/skills/github-issues) | Issue drafting and updates with existing GitHub tools; complements PR review tools. |
| `writing` | `architecture-decision-records` | [wshobson/agents](https://github.com/wshobson/agents/tree/main/plugins/documentation-generation/skills/architecture-decision-records) | Preserves decision rationale and history beyond prose editing or task planning. |

These are curated, usable SkillVault guides, not full upstream plugin installations. No
upstream scripts, reference libraries, browsers, database clients, account setup, or hooks
are bundled or installed. Each guide states its runtime requirements and links to deeper
upstream material. Each guide keeps its own license: the security adaptation retains
CC-BY-SA-4.0 attribution and licensing, and the other five guides are MIT. Upstream licenses
differ and are recorded separately in each manifest's `upstream` block.

Authorship stays with the original upstream author in `author`, and `maintainer` records who
maintains the SkillVault adaptation. These adapted guides declare `version: null` in both the
catalog and the manifest so they do not impersonate an upstream release. In each manifest,
`source` identifies the guide's location inside SkillVault and `upstream` records its
provenance: upstream repository, path, and license. Install metadata points to SkillVault, not
an incompatible upstream folder. The existing `/skillvault-refresh` script targets managed global latest
installs only when explicitly run or scheduled. Project copies are not refreshed by it; changing
a default creates no refresh schedule and updates no upstream dependencies.

## Discover and Explain

`/skillvault-discovery [list|search|evaluate|explain] [<arguments>...]` finds and explains skills
without installing or running the target. Bare invocation remains a read-only list.

- `evaluate <url-or-name>` separates standalone usefulness, creating a SkillVault guide, and
  harness integration when relevant. `upsert/defer/skip` applies only to the guide decision;
  a tool may be worth trying standalone while integration is deferred. Recommendations do not
  authorize trials, installations, or integration.
- `explain <subject>` accepts a skill, tool, or product. For example, `explain playwright`
  explains Playwright first, then its relationship to the `webapp-testing` guide. It asks only
  when the intended subject is genuinely ambiguous and does not run the subject.

All multi-action topics accept exactly 3 or 4 leading letters when they identify one canonical
action within that topic, after checking exact action names and documented aliases first.
For example, `eva`/`eval` select `evaluate`, `exp`/`expl` select `explain`, and installation's
`ins`/`inst` select `install`. Multiple matches show choices and ask; no match shows help;
neither executes an action. Other arguments are not abbreviated, and permissions/confirmations
stay unchanged. This is conversational routing, not new PowerShell argument parsing.
Canonical menus, skill registrations, and read-only bare defaults stay unchanged. Source changes
do not refresh installed copies. Completed evaluations retain their public-safe record by default,
with `--chat-only` to skip it; explanation stays read-only.

## Install or Upsert

- `/skillvault-installation install <skill-or-folder-or-keyword> [scope] [version] [--repo path]` installs existing catalog
  skills or updates their installed copies. It does not author source skills. Omit the
  target to browse the catalog; `/skillvault-installation update` refreshes approved managed copies.
- `/skillvault-authoring upsert <name-or-url> [<scope>] [--repo <path>]` edits an existing repository skill or creates one from
  scratch or a URL, updating its source files and catalog entry. A name does not automatically
  import an installed copy. It can install the result afterward; use scope `none` for source-only
  work. Publishing is separate and requires explicit approval.

Install uses its [read-only source resolver](skills/core/skillvault-installation/scripts/resolve-source-repo.ps1):
an explicit `--repo` or the verified Windows checkout `C:\repos\skillvault`. It does not automatically
select a source cache, temporary worktree, or another session's clone, even with the same origin.
Without that intended checkout, ask for the actual source path; cloning or preparing another revision
needs separate approval. Read the selected checkout's catalog and bundles afresh. Local `latest`
means those current files, not a claim of remote-tip parity, and starts no implicit fetch/pull/checkout.
Harness initialization follows this same rule when installing missing dependencies.

Upsert uses a [read-only source resolver](skills/core/skillvault-authoring/scripts/resolve-source-repo.ps1):
explicit `--repo`, verified SkillVault working project, known Windows checkout `C:\repos\skillvault`,
then the existing source cache. The Git root, catalog/public layout, and official origin must match;
an invalid explicit or preferred source blocks edits. It displays the resolved source and any
separate installation destination before writing. No source found means ask for a checkout or
approval to clone/open a remote PR, never create source files in an unrelated working project.
Optional project installs still target the original working project's `.github/skills`.

Use **install** to update copies in your environment and **upsert** to change repository sources.
Installation after upsert is an optional follow-up. For example, `/skillvault-installation install planning-with-files project`
installs or updates that project copy; `/skillvault-authoring upsert my-custom-skill none` authors a source skill.
Its `create` and `update` aliases also upsert; the user need not check existence first.
The canonical authoring topic is `/skillvault-authoring [list|upsert|remove] [<arguments>...]`;
`/sv-authoring` is shorthand. Former `/skillvault-source` and `/sv-source` commands retain their
actions as compatibility routes, without separate source bundles. Existing installed copies move
only through an approved `skillvault-installation update --topics` migration.
The registered topic is `skillvault-installation`. Legacy `/sv-install`, `/sv-list`, and `/sv-uninstall`
requests route to its corresponding operations, not separate visible skills.

## Global install

Repository URL: <https://github.com/wzlwit/skillvault>

Windows bootstrap installer URL: <https://github.com/wzlwit/skillvault/blob/main/scripts/install-global.ps1>

Both installers read [scripts/bootstrap-skills.json](scripts/bootstrap-skills.json), the single
place to manage the initial global install set. Keep names only in this file; paths and versions
come from [catalog.json](catalog.json). The authoring topic `skillvault-authoring` requires explicit
installation through `/skillvault-installation install`; existing copies are not removed by bootstrap.
`/skillvault-refresh schedule` explicitly configures one-way refresh; `/skillvault-sync` and `/sv-sync`
are compatibility aliases. Use `/skillvault-installation install <skill-or-folder-or-keyword> <scope> <version>` for
specific skills or keyword-matched sets. Omitted scope uses `install.defaultScope`, then `project`.
`session` writes no installed copy. Omitted version is `latest`; pinned versions use `v#.#.#`.

PowerShell installation uses the bundled file helper. Bash installation requires Node.js for
JSON metadata; neither installer runs skill workflows or changes Windows schedules. Existing
identical installs are skipped. Review differing or pinned copies before using `-Force`
(PowerShell) or `--force` (Bash). Files are staged before replacement and a failed swap retains
or restores the previous copy.

After installing the new name, bootstrap removes a managed legacy `skillvault` installation
only with `-Force` (`--force` in Bash), after review. Without that flag, the old folder remains
for review; unmanaged old-name folders are always preserved. Repository URLs and install
ownership markers remain `skillvault`; only the installer skill and its source path were renamed.

One-line download (Windows PowerShell 5.1+):

```powershell
Invoke-Command -ScriptBlock { $ErrorActionPreference = 'Stop'; $revision = (Invoke-RestMethod -Uri 'https://api.github.com/repos/wzlwit/skillvault/commits/main' -Headers @{ 'User-Agent' = 'SkillVault-Setup' }).sha; $setupPath = Join-Path ([IO.Path]::GetTempPath()) ('skillvault-' + [guid]::NewGuid().ToString('N') + '.ps1'); try { Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/wzlwit/skillvault/$revision/scripts/setup.ps1" -OutFile $setupPath; & $setupPath -Revision $revision } finally { Remove-Item -LiteralPath $setupPath -Force -ErrorAction SilentlyContinue } }
```

The [online setup](scripts/setup.ps1) reads GitHub's file index and downloads only the selected
complete skill bundles, installer, shared selection, catalog, and helper. All files use one
resolved revision, not a full repository ZIP. Temporary files are removed after installation.
No Git checkout is required for this bootstrap step. Run it only when you trust the published
code on `main`; local changes are unavailable through this command until published. It does not
bypass PowerShell execution policy or force replacement of existing installs.

After successful installation, setup offers to clone the repository into a new folder, then
optionally open that clone in VS Code. Each prompt cancels after **30 seconds without a keypress**;
typing restarts the idle timer. Enter without an answer, Escape, or timeout skips the remaining
optional steps without undoing installation. Only an explicit yes and a destination permit
`git clone`; existing destinations are never replaced. Git is required only for the optional
clone. Noninteractive hosts skip prompts; pass `-NonInteractive` to setup to suppress them
explicitly. Local installers do not prompt. Subsequent source-based operations still require
a verified Git checkout.

Or clone the repository and run the installer yourself. Windows PowerShell:

```powershell
git clone https://github.com/wzlwit/skillvault.git
Set-Location skillvault
.\scripts\install-global.ps1
```

macOS or Linux:

```bash
git clone https://github.com/wzlwit/skillvault.git
cd skillvault
./scripts/install-global.sh
```

Or ask an AI coding agent (install `skillvault-authoring` explicitly before using the optional
source-authoring command mentioned below):

> Install the SkillVault bootstrap skills globally using https://github.com/wzlwit/skillvault/blob/main/scripts/install-global.ps1. Clone or update its repository first, then run the installer from the local checkout. Do not install every catalog skill; after bootstrap I will use `/skillvault-installation install <skill-or-folder-or-keyword> <scope> <version>` to install or update specific skills, with omitted scope resolved from each skill's `install.defaultScope` and omitted version defaulting to `latest`. Use `/skillvault-discovery evaluate <url-or-skillName> [location]` to assess purpose and value before deciding to upsert; without `location`, it checks installed skills, local catalogs, the official SkillVault repository, then external sources. Use `/skillvault-authoring upsert <name-or-url> <scope>` to create or update local SkillVault source skills, not just install an existing one; if no local SkillVault checkout exists, it asks whether to clone one locally or create a remote pull request. Use `/rules <add|modify|remove> <rule> [location]` to propose and, after confirmation, update an authoritative AI-rules document; `/rules apply` is the compact four-rule guidance set. Use `/skillvault-refresh <intervalDay>` or `/skillvault-refresh <intervalDay>` to schedule one-way latest refreshes from recorded source repositories. Use `/skillvault-installation list` to list installed skills and `/skillvault-installation uninstall <selector>` to uninstall by index, range, list, or keyword after confirmation. Use `/schedule-manager` to list Windows scheduled tasks and enable, disable, or delete selected tasks by index, range, list, or keyword after confirmation.

## Local Scripts

Install selected skills from a local checkout with
[install-skills.ps1](scripts/install-skills.ps1). It resolves the suggested scope per manifest,
copies complete skill bundles, and records the actual catalog source, not an upstream link.

```powershell
.\scripts\install-skills.ps1 -Name webapp-testing -Scope project -ProjectPath C:\repos\my-project
```

Use `-Force` only after reviewing an existing installation. For a pinned install, select a
clean checkout of the desired tag and pass `-RequestedVersion v1.0.0`; the installer checks
HEAD against that tag. Uncommitted local changes can be installed with `latest`, but are not
available remotely until explicitly published.

Use `/skillvault-authoring remove <skill-name[,skill-name...]> [repo-path]` to remove exact source skills and
their catalog entries after a preview and confirmation. The
[bundled removal script](skills/core/skillvault-authoring/scripts/skillvault-remove.ps1)
requires an explicit `-RepoRoot` and previews unless `-Force` is supplied. It checks remaining
manifest dependencies and the shared bootstrap selection, stages source folders before changing
the catalog, and preserves recoverable files on failure. Installed copies, other checkouts,
schedules, and remotes are unchanged. Use `/skillvault-installation uninstall` separately for installed copies.

`/skillvault-refresh` follows recorded Git sources for managed global `latest` installs only. It checks
versions and file contents, so unchanged copies keep their install timestamp and same-version
edits still refresh. Failed or dirty caches cannot overwrite installations. It does not
refresh project installs, choose between local and remote changes, download arbitrary URLs,
or update the external runtimes named by reference-only skills.

## Validation

Use Node.js 20+ for development validation. Install the pinned parser dependency once:

```powershell
npm ci
.\scripts\test-all.ps1
.\scripts\validate-catalog.ps1
```

[test-all.ps1](scripts/test-all.ps1) runs parser checks and isolated installation, source removal, refresh,
inventory, schedule, and bootstrap tests. No real tasks are mutated and no remote writes are
performed. When Git Bash is available, the bootstrap tests also exercise the Bash installer.

After an approved installation or refresh, verify the copies against the selected checkout:

```powershell
.\scripts\verify-installed-skills.ps1
.\scripts\verify-installed-skills.ps1 -SkillsPath "$HOME/.copilot/skills" -Name skillvault-installation,skillvault-refresh
```

Parity checking is explicit: a customized or pinned install may legitimately differ from the
current checkout. Runtime dependencies and automated trigger behavior of upstream plugins
are not established by catalog validation.
