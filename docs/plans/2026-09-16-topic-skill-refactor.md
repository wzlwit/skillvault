# Topic Skill Refactor

- Date: 2026-09-16
- Status: Source topic, transactional update, and compatibility contracts implemented; targeted management-copy rollout completed; subsequent installed-copy rollout remains separate
- Scope: Topic actions and synopsis hints, namespaced storage and explicit relocation, shared scheduling, retention, discovery, and evaluation records.

Use one registered skill per topic. A first word that is a menu word selects that action; anything
else is text, which does the topic's main job, and no input at all is the topic alone. Alone, a topic
acts at once only on a fixed target, such as `/harness-review` on the current changes and
`/pr-publish` on the current branch's PR; every other topic alone shows where things stand and offers
the next step, asking once, and a target guessed from the conversation is confirmed first. Menus list
only the other actions, with no aliases. Descriptions start with the menu words, then `Alone:` and
`Text:`; argument hints show the menu words, then the kind of text. They do not create nested VS Code
autocomplete. See the [bare, text, and menu convention ADR](./decisions/2026-10-09-bare-text-menu-convention-adr.md).

The [interface and baseline ADR](./decisions/2026-09-24-recovery-compatibility-and-harness-baseline-adr.md)
adds explicit executable-dependency interface checks. Its archive policy is superseded by the
[current-copy-only ADR](./decisions/2026-09-25-current-copy-only-installation-adr.md): temporary
originals protect in-progress updates, but success or verified rollback leaves no retained
installation archives. Removing existing obsolete copies remains explicitly scoped work.

The [accepted action-prefix ADR](./decisions/2026-09-23-topic-action-prefix-matching-adr.md)
adds conversational routing across these topics: an exact menu word wins first; otherwise exactly
3 or 4 leading letters select a unique menu word within the selected topic when the rest of the
request fits that action. Multiple matches require a choice and run nothing; anything else is text.
Other arguments, case handling, natural-language routing, full menus, and existing
permissions/confirmations are unchanged. PowerShell argument parsing and installed copies are not
changed by this source update.

The command synopsis is `/harness-<topic> [<menu words>] [<text>]`.
The project entrypoint is `/harness-setup [root|clean|policy] [<link, task, or question>]`;
there is no `management` topic and actions do not become separate registered skills. On 2026-10-07
the thirteen harness topics were consolidated into seven, and on 2026-10-09 four of them were
renamed; see the [topic consolidation ADR](./decisions/2026-10-07-harness-topic-consolidation-adr.md)
and the [convention ADR](./decisions/2026-10-09-bare-text-menu-convention-adr.md).

Harness topics register as `/harness-*` with matching folders and dependencies: `harness-setup`,
`harness-dev`, `harness-write`, `harness-review`, `harness-decide`, `harness-monitor`, and
`harness-schedule`. The shared `harness-runtime` bundle is hidden from the `/` menu.
`/hn-*` is only conversational shorthand for quick typing; for example, `/hn-setup root` selects
`/harness-setup root`. Retired topic and command names are not accepted; see the
[old-name retirement ADR](./decisions/2026-10-07-retire-old-names-adr.md). No separate alias bundles are
registered or installed. SkillVault management registers the full `skillvault-*` names:
`skillvault-discover`, `skillvault-install`, and `skillvault-author`. `/sv-<topic>` is
conversational shorthand only. The slash picker uses the full canonical names. Refresh is the
`/skillvault-install refresh` action; see the
[SkillVault topic consolidation ADR](./decisions/2026-10-07-skillvault-topic-consolidation-adr.md).

Skill authoring registers as `/skillvault-author [remove] [<what to create or change>]`, with
`/sv-author` shorthand. The name describes creating and maintaining skill bundles, not coding
context or data sources.

## Command Structure

```mermaid
flowchart LR
    ENTRY["Topic skills and subcommand dispatch"]
    ENTRY --> SV["SkillVault management"]
    ENTRY --> HN["Project harness"]
    ENTRY --> PR["Remote PR review"]
    ENTRY --> RULES["rules<br/>apply, remove<br/>text: add or change a rule"]
    ENTRY --> DOMAIN["Independent domain skills"]
    SV --> DISCOVER["skillvault-discover<br/>explain<br/>text: search or evaluate"]
    SV --> INSTALL["skillvault-install<br/>list, update, uninstall, clean, refresh<br/>text: install"]
    SV --> AUTHORING["skillvault-author<br/>remove<br/>text: create or change<br/>SkillVault repository only"]
    HN --> PROJECT["harness-setup<br/>root, clean, policy<br/>text: sources and briefings"]
    HN --> WORK["harness-dev<br/>upsert, queue, sprint, test, broad<br/>text: develop"]
    HN --> CHECK["harness-review, harness-monitor"]
    HN --> OUTPUT["harness-write<br/>slots<br/>text: docs, communications, reports"]
    HN --> DECIDE["harness-decide<br/>closed, all<br/>text: explain, then decide"]
    HN --> TIMER["harness-schedule<br/>clean<br/>text: set, off, on"]
    HN -.-> RUNTIME["harness-runtime<br/>hidden shared runtime"]
    PR --> REVIEW["pr-review<br/>broad, list, configure<br/>text: review a URL"]
    PR --> WATCH["pr-watch<br/>remove<br/>text: watch a URL"]
    TIMER --> HEARTBEAT["One user-wide heartbeat<br/>project, PR, refresh, maintenance"]
    INSTALL -->|Refresh schedule ownership| TIMER
```

The diagram shows logical command relationships, not nested directories. The heartbeat is
implemented but source changes do not register or migrate live tasks. The standalone
`schedule-manage` continues to administer explicitly selected Windows tasks outside the harness.

Task records, identity, and updates belong to `harness-dev upsert`; `harness-dev` text (a task ID or a
request) and `queue` run and queue work, reusing task intake for ad-hoc requests, `harness-dev broad`
runs one task's reviews and unit tests at broad, and `harness-dev sprint` runs goal-based
sprints over existing tasks without a second task store. `harness-schedule` owns schedules and stale definitions.
Historical records/reports belong to `/harness-setup clean` and retention settings to
`/harness-setup policy set retention <file>`; the Saturday
maintenance tick invokes that same cleanup implementation. Existing policies and retention
protections are unchanged, and no additional maintenance topic is introduced.

Source, report, and documentation authoring take what to create or change as text and resolve
whether it exists, with no separate create or update action. The
[accepted work-contract ADR](./decisions/2026-09-18-upsert-and-harness-work-contracts-adr.md)
records that upsert behavior, whole-repository Fresh review, workspace-based completion, normalized exact task
identity, and linked follow-ups for explicitly revised completed work. These source changes do
not refresh installed copies or change live schedules.

`harness-write` text that asks for docs provides session-level feature guides, onboarding, and troubleshooting. It uses
existing approved task context when applicable and does not require initialization or add a
`harness.ps1` action. Humanizer edits prose before final validation; decision history remains
with `architecture-decision-records`. See the
[accepted documentation ADR](./decisions/2026-09-26-harness-documentation-adr.md).

`harness-write` text that asks for a tracker, meeting, or email drafts stakeholder trackers, meeting
invites, and email updates or thread replies in the session, and `harness-write slots` ranks meeting times from saved
free/busy data. It likewise needs no initialization or `harness.ps1` action, and it saves drafts
only; sending, inviting, and sharing need explicit requests. See the
[accepted communications ADR](./decisions/2026-09-29-harness-communications-adr.md).

## Folder Layout

These are the refactored families on disk; other category folders retain their existing layout.
Each skill folder matches its registered name. Subcommands use bundled operation guides, not
another layer of skill folders. Duplicate shorthand and old action-per-skill source folders
are not retained.
The `public` directory level is removed; reusable scaffolds live separately in top-level
`templates/`. This source-only layout change does not move installed copies or live state.
See the [accepted source-layout ADR](./decisions/2026-09-23-source-layout-adr.md) for rationale,
compatibility costs, and the boundary around installed-copy updates.
The separately approved [management-copy rollout](./decisions/2026-09-23-source-layout-adr.md#approved-installed-copy-rollout)
updated four global and two current-workspace copies, including the global authoring rename.
It did not refresh other installed skills or change live schedules.
The accepted [shared-ownership contract](./decisions/2026-09-23-shared-ownership-adr.md) is a later
source change: it coordinates manual/scheduled checkout use and affected runtime updates.
Its installed-copy transition remains separately approved; earlier rollout evidence does not
prove that live copies participate in the new protocol.

```text
skills/
|-- core/
|   |-- rules/
|   |-- skillvault-author/
|   |-- skillvault-discover/
|   `-- skillvault-install/
|-- github/
|   |-- github-issues/
|   |-- pr-publish/
|   |-- pr-review/
|   `-- pr-watch/
`-- planning/
  |-- brainstorming/
  |-- grilling/
  |-- handoff/
  |-- harness-decide/
  |-- harness-monitor/
  |-- harness-setup/
  |-- harness-review/
  |-- harness-runtime/
  |-- harness-schedule/
  |-- harness-dev/
  |-- harness-write/
  `-- planning-with-files/
```

The approved `.github/skills/` and global installed copies remain separate from this source tree
and now use the canonical topic layout. `/hn-*` and `/sv-*` remain chat shorthand; legacy command
spellings are not accepted.
Removed source script paths are not provided; callers must use the corresponding canonical folder while
keeping the executable filename. This cleanup does not retarget live schedules.

## Project Storage

`/harness-setup root` (`/hn-setup root`) shows the selected root; `/harness-setup root <path>` selects it. The
harness workspace is **`<root>/.harness_sv/`**, not a visible `harness/` folder and not the installed
skill bundle. All harness-owned information and files default here unless the user explicitly
specifies another destination. The following is the complete default artifact hierarchy:

```mermaid
flowchart LR
  ROOT["Root selected by /hn-setup root"] --> STORE[".harness_sv/"]
  STORE --> CONFIG["config/<br/>authoritative domain declarations"]
  STORE --> STATE["runtime/<br/>state and schedule progress"]
  STORE --> BOARD["board/<br/>current, history, references, decisions"]
  STORE --> LOCKS["runtime/locks/<br/>store, runner, schedule locks"]
  STORE --> HISTORY["history/YYYY-MM/<br/>timestamp-topic-run-id.md"]
  STORE --> DOCS["docs/"]
  DOCS --> PLANS["plans/<br/>plan.md"]
  PLANS --> DECISIONS["decisions/<br/>decision.md"]
  DOCS --> HANDOFFS["handoffs/<br/>handoff.md"]
  STORE --> DEFINITIONS["definitions/<br/>other workflow inputs"]
  STORE --> ARTIFACTS["artifacts/<br/>reports, queries, diagrams, exports"]
  STORE --> WORKTREES["worktrees/<br/>task-id/"]
```

```text
<root>/
`-- .harness_sv/
  |-- README.md
  |-- config/
  |   |-- project.json
  |   |-- monitors.json
  |   |-- tests.json
  |   |-- policy.json
  |   `-- schedules.json
  |-- board/
  |   |-- current-<project>.csv
  |   |-- history.csv
  |   |-- references.csv
  |   |-- decisions.csv
  |   |-- decisions.lock
  |   `-- .harness-board.json
  |-- runtime/
  |   |-- state.json
  |   |-- schedules.json
  |   `-- locks/
  |-- history/
  |   `-- YYYY-MM/
  |       `-- <UTC-timestamp>-<topic>-<run-id>.md
  |-- docs/
  |   |-- plans/
  |   |   |-- <plan>.md
  |   |   `-- decisions/
  |   |       `-- <decision>.md
  |   `-- handoffs/
  |       `-- <handoff>.md
  |-- definitions/
  |-- adapters/
  |-- observations/
  |-- artifacts/
  |   `-- <report-query-diagram-or-export>/
  `-- worktrees/
    `-- <task-id>/
```

Configuration domains are the single editable authority; effective settings are combined only
in memory. Runtime state is separate. CSVs are generated views except the decision register,
which its helper owns. Monthly history files store run summaries, test/review
evidence, errors, and available captured output. Separate logs, when requested, use `history/`
unless the user specifies another path; do not duplicate reports to fill a logs folder.
Documents, definitions, artifacts, and worktrees are created only by the corresponding
authorized operation. The diagram is not a request to create all folders during initialization.

Pass `.harness_sv` output destinations to delegated authoring skills explicitly. A user-selected
destination or existing saved configuration takes precedence; preserve existing data and
report any legacy paths instead of moving records or retargeting schedules automatically.
Reader-facing `harness-write` doc output follows the selected coding repository's documentation
convention, or explicit output path, rather than this runtime hierarchy. Pass that destination
explicitly when delegating documentation; any existing harness tracking remains controller-local.
Application source, linked documents/repositories, installed skills, and existing host instruction
entrypoints remain separate. The user-wide PR/refresh controllers are not relocated by project `root`.
A verified legacy SkillVault controller at `.harness` is reused in place
when `.harness_sv` is absent; unrelated `.harness` folders are not adopted.

New controllers use this layout. `/hn-setup` alone previews the in-place conversion of an existing
controller with an old layout and, after approval, converts it, preserving IDs, report contents,
queues, and cadence while updating owned links. Creating or reconnecting a harness never silently
converts one. See the [accepted decision](./decisions/2026-09-25-declarative-harness-and-auto-verification-adr.md).
Existing standalone decision registers retain their board location during first initialization.
The [accepted naming ADR](./decisions/2026-09-25-project-qualified-board-names-adr.md) records the
project-qualified default, central `currentFileName` setting, legacy fallback, and guarded explicit
renames. Topic-filtered CSVs are requested artifact snapshots, never extra canonical boards.

`root <new-parent>` selects the valid new target, then asks whether to move an initialized
previous harness; no move flag is required. Move is the displayed default, including no answer.
Explicit answers or applicable user instructions take precedence; No or cancel leaves old data
in place. `/hn-setup root <path>` follows the same workflow. The new Root stays selected either way.
A failed move is reported without undoing selection.
Invalid targets do not change Root. Uninitialized sources and unchanged paths need no move prompt.
Yes or the unanswered Move default previews and applies relocation from the saved previous root to a parent with no destination controller,
retaining identity, queue/pause state, registered dirty worktrees, external board/code targets,
and logical schedule cadence. `executionRoot` retains the original implicit coding/test target.
Known structured paths are updated; authored text and snapshot evidence are preserved. Active
work, collisions, linked filesystem entries, and ambiguous scheduled contexts block the move.

Topic `argument-hint` fields use compact command synopsis notation: the menu words in one bracket,
then the kind of text in another, as in `[broad|list] [<scope>]`, with `<value>`, `[optional]`, `a|b`,
and `...`. Exact operation forms belong in the body, not a simulated
parser or a long list of positional choices. `/harness-decide` alone shows active open decisions
plus a one-line **Configuration When Needed** summary and source link, then offers to go through
them. `all` adds recent
decisions and the detailed configuration checklist; closed and exact-ID views omit configuration.
Explicit Open/Proposed records stay visible. Unselected setup becomes an open choice only when
requested or enabled work needs a human decision that saved settings, inheritance, and defaults
cannot resolve. The [bulletin contract](./2026-09-15-harness-command-and-record-contracts.md#decision-bulletin)
preserves CSV statuses and read-only display. Recent-result limits remain,
and exact-ID inspection covers any status. Installed-copy updates are separate.

## Scheduling and Retention

The [scheduler contract](../../skills/planning/harness-schedule/references/scheduler.md)
owns one current-user heartbeat and project-local logical schedules. The central registry,
shared maintenance settings, and latest process receipt per job use `~/.copilot/skillvault/scheduler`.
No work schedule has an invented cadence; fixed and calendar duration units are `m/h/d/n/y`.
The [adaptive-heartbeat ADR](./decisions/2026-09-23-adaptive-heartbeat-adr.md) sets a `1d` routine
baseline, configurable through `heartbeat <duration>` without changing job schedules. Faster
fixed job intervals shorten it, active workers retain a 30-minute cap, and earlier job/maintenance
deadlines still win. Already blocked overdue work uses the adaptive recheck instead of one-minute
polling. The heartbeat has no AI model; scheduled workers keep their own approved configuration.
Nonconflicting approved roots can run together; active/uncertain jobs and intersecting roots are
not overlapped. Source changes do not synchronize live tasks or refresh installed copies.

Maintenance defaults to Saturday 08:30-09:00 local only after explicitly enabled, skips active
work, and does not catch up outside that window. Machine wake and AI assistance are allowed when
necessary, not required for routine scripted cleanup. Permission alone changes no live task or
AI execution; any concrete use retains existing scope, budgets, denials, and cleanup approvals. Retain
90 days and 5,000 completed entries per harness by default; optional per-topic count is 1,000.
Count-only, age-only, and combined policies are supported. Required/pinned/linked evidence is
protected even if it exceeds limits. Prune authoritative records and owned files together.
Disable confirmed stale jobs before a 30-day grace; deleting legacy OS definitions requires
explicit approval and unchanged ownership. Existing OS timers need an exact conversion preview, which
`/harness-schedule` alone offers.

## Discovery and Evaluations

Supporting research honors an explicit source first; otherwise use local, configured accessible
internal, then authoritative external sources as needed. Working permissions and stricter source
resolvers are separate. Never leak private search terms or silently substitute for a failed target.

Discovery's only menu word is `explain`. Alone, it shows past evaluations and asks what to look for;
text with a purpose searches, and a URL or one skill name is evaluated. There are no aliases; the
topic-local action-prefix rule above still applies.
`explain` accepts skills, tools, and products: explain the requested subject first, then distinguish
any related skill. Ask only when the intended subject is genuinely ambiguous; an unavailable
explicit source remains a limitation, not permission to substitute another subject.

Evaluation separates standalone usefulness, the SkillVault guide decision, and harness integration
when relevant. Only the guide decision uses `upsert/defer/skip`; a candidate may be worth trying
standalone while integration is deferred. Recommendations authorize no execution or installation.
These source changes do not refresh installed copies; preview and approve those updates separately.

Completed public-safe evaluations use one `docs/evaluations/<candidate>.md` record per canonical
source, including defer/skip, with a chat-only opt-out. Reevaluate outdated evidence, not the
record's wording. Private assessments require a private destination. Records are outside history
cleanup and do not become catalog entries. The [Oh My Pi assessment](../evaluations/oh-my-pi.md)
records the completed research; installing OMP or integrating its runtime has not been validated.

## Catalog Mapping

Every catalog skill registers under its own canonical name, and each topic folder registers one
topic. The [harness topic consolidation ADR](./decisions/2026-10-07-harness-topic-consolidation-adr.md)
and the [SkillVault topic consolidation ADR](./decisions/2026-10-07-skillvault-topic-consolidation-adr.md)
record which retired topics the current topics and actions replaced. The installer's former-name
map retires installed copies under those names; nothing else accepts them. Each row lists the
skill's menu words; what it does alone and with text starts its description.

| Skill | Command and menu words |
| --- | --- |
| archify | archify |
| architecture-decision-records | architecture-decision-records |
| awesome-gamedev-agent-skills | awesome-gamedev-agent-skills |
| brainstorming | brainstorming |
| differential-review | differential-review |
| dri | dri investigate |
| github-issues | github-issues |
| graphify | graphify |
| grilling | grilling |
| handoff | handoff |
| harness-decide | harness-decide closed, all |
| harness-monitor | harness-monitor accept, auto |
| harness-setup | harness-setup root, clean, policy |
| harness-review | harness-review broad, list |
| harness-schedule | harness-schedule clean |
| harness-dev | harness-dev upsert, queue, sprint, test, broad |
| harness-write | harness-write slots |
| humanizer | humanizer |
| humanizer-ch | humanizer-ch |
| jarvis-metrics | jarvis-metrics |
| kpi-dashboard | kpi-dashboard |
| office-documents | office-documents |
| openapi-spec | openapi-spec |
| planning-with-files | planning-with-files |
| powerbi-build | powerbi-build convert |
| powerbi-localize | powerbi-localize review |
| powerbi-modeling | powerbi-modeling |
| powerbi-test | powerbi-test compare |
| ppt-master | ppt-master |
| pr-publish | pr-publish list |
| pr-review | pr-review broad, list, configure |
| pr-watch | pr-watch remove |
| rag-implementation | rag-implementation |
| rules | rules apply, remove |
| schedule-manage | schedule-manage enable, disable, delete |
| skillvault-author | skillvault-author remove |
| skillvault-discover | skillvault-discover explain |
| skillvault-install | skillvault-install list, update, uninstall, clean, refresh |
| supabase-postgres-best-practices | supabase-postgres-best-practices |
| trading-signal-analysis | trading-signal-analysis |
| webapp-testing | webapp-testing |

## Boundaries

- `/skillvault-author` authors skill bundles and catalog entries in a verified SkillVault repository,
  never the working project's application source. Show source and working project separately;
  authoring never installs. Preserve the source resolver's existing selection rules.
- `/rules apply [core] [global|project|session]` puts the core and extra rules, or only the core rules,
  into the global always-on file (default), a project's `.github/copilot-instructions.md`, or the
  current chat; other skills' "apply `/rules apply`" means the current chat. Text with a rule and
  `remove` change private Personal rules by default, or project rules, and the public library only
  when the owner names `extra` or `core`, always after explicit approval. Workers receive core guidance
  explicitly; installing or mentioning a skill is not automatic context injection.
- Grilling remains a human decision interview. Offer it for unresolved consequential choices,
  including choices found after development, not every review or monitor tick. Unattended
  workers report questions and defer dependent actions. Tests and independent reviews remain.
- Keep complete runtime bundles colocated in the selected installation scope. Source contains
  only the canonical topic folders, not duplicate shorthand wrappers. Retired topic and command
  names are not routes; installed-copy migration retires copies under former names.
- Preserve controller roots, repository references, board/state/report paths, permissions,
  snapshot checks, review independence, time and credit limits, and existing timer cadences.
- Default new harness-owned artifacts to `.harness_sv` inside the selected root; preserve explicit
  output paths and existing records. Never turn location selection into a storage migration.
- Source changes do not refresh installed copies, initialize controllers, migrate live timers,
  change PACS schedules, clone repositories, commit, push, or publish. Exact rollout is separate.

## Verification

Validate topic metadata, exact catalog coverage, resource links, explicit subcommand routes,
bootstrap selection, canonical folders and conversational shortcuts, and affected runtime fixtures.
Use focused checks while editing, then one complete suite for this shared-runtime change. Installed-copy
replacement and live scheduler activation require separate parity/OS checks; do not infer them from fixtures.

## Rollout Status

Managed global and current-project copies are updated through `/skillvault-install`, and
[verify-installed-skills.ps1](../../scripts/verify-installed-skills.ps1) checks them against the checkout.
Live schedules, heartbeat settings, and registered projects change over time, so this plan doesn't
record them: `/harness-schedule` alone shows the schedules, and `/harness-setup` alone shows a
project's state. This plan sets no project-specific models, permissions, work schedules, or
monitoring targets.
