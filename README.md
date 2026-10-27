# SkillVault

A single repository for public, shareable skills.

## Purpose

- `skills/` for open-source or shareable skills
- `templates/` for skill scaffolds

Public skills use one category level, for example `skills/core/skillvault-install` or
`skills/system/schedule-manage`.
Reusable scaffolds and draft skills that aren't in the catalog yet stay in top-level `templates/`. Source folder
moves do not update installed copies or live schedules; installed tools that use old source
paths need a separately approved update.

The registered management commands are `/skillvault-install`, `/skillvault-discover`, and
`/skillvault-author`. Type `/skillvault` to filter these full names in the slash-command picker.
`/sv-<topic>` spellings such as `/sv-install` are conversational shortcuts, not separate
registered skills. Alone, each shows where things stand and asks before acting: `/skillvault-install`
shows the catalog with each skill's state here and offers to update copies that are behind,
`/skillvault-discover` shows past evaluations and asks what to look for, and `/skillvault-author`
confirms a skill clear from the conversation or shows the catalog and asks. Text does the main job:
`/skillvault-install <name>` installs, `/skillvault-discover <purpose, URL, or skill>` searches or
evaluates, and `/skillvault-author <what to create or change>` authors. Refresh is the
`/skillvault-install refresh` action, and retired command spellings are not accepted. On 2026-10-09
these three names replaced `skillvault-installation`, `skillvault-discovery`, and
`skillvault-authoring`. See the
[SkillVault topic consolidation ADR](docs/plans/decisions/2026-10-07-skillvault-topic-consolidation-adr.md)
and the [bare, text, and menu convention ADR](docs/plans/decisions/2026-10-09-bare-text-menu-convention-adr.md).

The `writing` category groups documentation, prose-editing, and presentation skills, including
`architecture-decision-records`, `humanizer`, `humanizer-ch`, and the `ppt-master` and
`office-documents` references. Their workflows stay separate;
manifest tags distinguish their focus. Skill categories do not change the project's `docs/` root.

The `data` category also includes the [RAG implementation skill](skills/data/rag-implementation/SKILL.md)
for document Q&A, chunking, retrieval, reranking, and grounded answers. It is adapted from
wshobson/agents and includes the original's examples with explicit limits; it bundles no runtime
and authorizes no ingestion or installation.

The `gamedev` category contains the [Awesome Gamedev Agent Skills reference](skills/gamedev/awesome-gamedev-agent-skills/SKILL.md)
for game development with Godot, Unity, Unreal, web, and other engines. It points to the upstream
router and skills; it bundles none of them and authorizes no installation.

The `monitoring` category holds [jarvis-metrics](skills/monitoring/jarvis-metrics/SKILL.md) and the
[DRI copilot](skills/monitoring/dri/SKILL.md). `/dri <incident ID or link>` builds a read-only,
evidence-linked brief on one incident for the on-call DRI, and `/dri` alone shows the DRI profile's
status and asks which incident; the rest of the DRI-agent design is a
[proposal](skills/monitoring/dri/references/proposal.md) distilled from the owner's private notes.
Service details stay in each project's private DRI profile, never in this public repository.

## Project Documentation

`docs/` is the parent for project documentation subfolders. Plans live in `docs/plans/`, with
decision history in `docs/plans/decisions/` and past review records in `docs/reviews/`. Add other
documentation subfolders only when needed.

- [Harness working plan](docs/plans/2026-09-15-harness-command-and-record-contracts.md)
- [Topic structure, diagram, and migration map](docs/plans/2026-09-16-topic-skill-refactor.md)
- [Source layout decision](docs/plans/decisions/2026-09-23-source-layout-adr.md)
- [Shared checkout and runtime ownership](docs/plans/decisions/2026-09-23-shared-ownership-adr.md)
- [Bounded refresh-contention retries](docs/plans/decisions/2026-09-24-refresh-contention-retries-adr.md)
- [Recovery, runtime compatibility, and baseline acceptance](docs/plans/decisions/2026-09-24-recovery-compatibility-and-harness-baseline-adr.md)
- [Current-copy-only installation and temporary rollback](docs/plans/decisions/2026-09-25-current-copy-only-installation-adr.md)
- [Source-agnostic monitoring and evidence reconciliation](docs/plans/decisions/2026-09-25-source-agnostic-monitoring-adr.md)
- [Feature documentation authoring](docs/plans/decisions/2026-09-26-harness-documentation-adr.md)
- [Stakeholder communications drafting](docs/plans/decisions/2026-09-29-harness-communications-adr.md)
- [Quiet script execution](docs/plans/decisions/2026-09-27-quiet-script-execution-adr.md)
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

Each skill folder includes a `skill.json` manifest and usually a `SKILL.md`; add a `README.md`
when it helps people.

Example:

```json
{
  "name": "my-skill",
  "title": "My Skill",
  "version": "1.0.0",
  "kind": "agent",
  "description": "What the skill does and when to use it; the same text as SKILL.md and catalog.json.",
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

`catalog.json` is a name-sorted lookup index. Keep only `name`, `description`, `path`, and
`version` there. Each skill has one description, identical in `catalog.json`, `skill.json`, and
the `SKILL.md` frontmatter; `scripts/validate-skill-files.mjs` checks that they match. Derive
display titles and grouping from the skill folder or the skill's own `skill.json`.

Reusable catalog skills default to global availability. Explicit project installation remains
available for supported, repository-pinned or customized copies; an absent manifest default
still falls back to project scope. Keep sibling runtime dependencies in the selected scope.
Global installation does not make project state, output paths, or execution permissions global,
does not install every catalog skill through bootstrap, and does not migrate existing copies.
See the [per-skill scope audit](docs/reviews/install-scopes-2026-09-15.md) for the assessed defaults.

Keep `version` present in both the catalog and manifest: use the declared version string,
or JSON `null` when no version is declared. `latest` describes the requested installation
policy, not a release version. Native skill versions follow the version rules in
[AGENTS.md](AGENTS.md#catalog-rules), and each version is tagged `<skill>/vX.Y.Z`. Preserve
original authorship on imports and disclose any adaptation; access to a source repository does
not establish redistribution rights.

Catalog entry example:

```json
{
  "name": "my-skill",
  "description": "What the skill does and when to use it; the same text as skill.json and SKILL.md.",
  "path": "skills/workflows/my-skill",
  "version": "1.0.0"
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
| `grilling` | Trade-offs with `architecture-decision-records`; planning with `planning-with-files`. | Interview to test a plan and resolve choices. Adapted from Matt Pocock's grilling; `/skillvault-install grilling origin` installs the original. |
| `architecture-decision-records` | Trade-offs with `grilling`; decision notes with `planning-with-files`; decision history with `harness-decide`; reader-facing rationale with `harness-write`. | Preserve architectural rationale, status, and superseded history. |
| `harness-decide` | Decision history with `architecture-decision-records`. | Show open decisions alone, with `closed` and `all` views; explain a decision or question, then save the human choice or leave a new question open. |
| `handoff`, `harness-setup` | Summarizing selected work and its context. | Handoff writes an explicitly requested continuation note; a harness-setup briefing, from a task ID or a question, provides a read-only project/task view. Neither controls execution. |
| `harness-dev` | Intake and checks with `harness-monitor`; code review with `harness-review`; report implementation with `harness-write`. | Record tasks with `upsert`, which never starts work; develop a task ID or request given as text; run sprints and reusable tests. Test-only runs need no AI worker. |
| `harness-monitor` | Checks and intake with `harness-dev`; metric contracts with `kpi-dashboard`; status and owner evidence with `harness-write`; incidents with `dri`. | Discover work across approved source adapters or evaluate health measurements, preserving source evidence and approval boundaries; a declared standing intake can take in and work a source's items through a local-only flow. |
| `dri` | Incidents with `harness-monitor`. | Investigate one production incident read-only for the on-call DRI and draft the next step and update; harness-monitor detects health breaches and proposes work. Service details come from the project's private DRI profile. |
| `harness-write` | Design rationale with `architecture-decision-records`; status and owner evidence with `harness-monitor`; implementation with `harness-dev`; report design with `kpi-dashboard` and `jarvis-metrics`; document output and artifact validation with the `ppt-master` and `office-documents` references. | Author feature guides, onboarding, and troubleshooting from evidence, with Humanizer followed by validation; draft trackers, meeting invites, and email updates or replies and rank meeting slots offline; coordinate report, dashboard, and query authoring. Never send, invite, share, or publish without explicit approval. |
| `humanizer`, `humanizer-ch` | Prose editing. | Humanizer installs blader's original for general prose; Humanizer CH is a guide to Chinese critical-essay rules and bundles none of them. Neither automatically replaces the documentation workflow. |
| `office-documents` | Document output with `harness-write`; workbook/report validation with `harness-write`. | Reference Anthropic's PDF/DOCX/XLSX skills without copying their proprietary prompts, scripts, or assets; no runtime or new report route. |
| `jarvis-metrics` | Design with `kpi-dashboard`; authoring with `harness-write`. | Guide Jarvis metric-source selection and widget configuration without bundling a client, query executor, or alerting API. |
| `kpi-dashboard` | Design with `harness-write`, `jarvis-metrics`, and the `ppt-master` reference; metric contracts with `harness-monitor`. | Define formulas, populations, units, freshness, and layouts independently of execution or incident intake. |
| `powerbi-build`, `powerbi-test`, `powerbi-localize` | Model changes with `powerbi-modeling`; report authoring with `harness-write` and Microsoft's `powerbi-report-cli`. | Build changes a Power BI project's model and report files as code, test checks the report files, and localize translates captions and report text. Each was written in its own words from other skills, listed as its `origins`. |
| `ppt-master` | Artifact validation with `harness-write`; presentation design with `kpi-dashboard`. | Installs Hugo He's original for editable PowerPoint decks and brand/template workflows; it adds no PPTX route to `harness-write`. |
| `harness-setup` | Setup, sources and briefings, limits, and failure handling within one topic. | Text keeps one registry of sources and coding repositories and shows a task's briefing or answers a question from it; `policy set limits` defines boundaries; `policy set fallback` handles bounded test retries and failed-run thresholds, and `policy pause`, `stop`, and `resume` control durable pauses. |
| `harness-review`, `pr-review`, `differential-review` | Code review against a baseline. | Harness review stays project-first; PR review selects remote snapshots and the user-wide list. Both share bounded review passes and can load the differential security methodology. |
| `harness-schedule`, `skillvault-install`, `schedule-manage` | Schedule setup and controls. | harness-schedule dispatches to existing project, PR, and refresh owners; `skillvault-install refresh` performs the refresh; schedule-manage administers Windows tasks broadly. |
| `skillvault-discover` | Search, evaluation, and explanation within one topic. | Text with a purpose finds candidates, and a URL or skill name is evaluated for adoption value; `explain` describes use. |
| `planning-with-files` | Planning with `grilling`; decision notes with `architecture-decision-records`. | Installs OthmanAdi's original for task tracking and recovery; its hooks run local scripts in hosts that support skill hooks. |
| `pr-publish` | Opening PRs with the GitHub Pull Requests extension's `create-pull-request` skill. | Commits working changes in grouped commits after one question and pushes the branch, then writes a new PR's description that skill's way and adds a current vs. to-be scenario table. On an existing PR it keeps the description and adds or refreshes only that table. It opens PRs through that extension's tool when available. |
| `skillvault-author` | Writing `SKILL.md` files with VS Code's `agent-customization` skill. | Use only for skills in the SkillVault repository and its catalog; it never installs. |

The [brainstorming skill](skills/planning/brainstorming/SKILL.md) adapts the Superpowers
workflow, including its visual companion, for the selected discussion or project, with global
availability by default. It does not install the full plugin, invoke follow-on skills, commit
design documents, or start the companion without your agreement.

`/skillvault-author` checks relevant counterpart instructions before recording overlap for either a
name or URL, preserves or corrects existing overlap notes on updates, and updates relevant
repository documentation. Partial overlap is not duplication or permission to remove a skill.
Existing design documents or task notes may already cover some of these roles.
A native skill written from other skills lists them under `origins` in its `skill.json`;
`/skillvault-author <skill> check origins` lists their new commits so useful changes can be carried
over in the skill's own words.

## Feature Documentation

Ask `/hn-write` in plain words for a full doc set, naming its readers (internal, partner, or public),
as in `/hn-write public docs for the monitor feature`, or for focused pages such as troubleshooting. The
[documentation skill](skills/planning/harness-write/SKILL.md) reuses existing docs and adapts its
seven-page outline to the feature. Alone, `/hn-write` confirms a target clear from the conversation
before writing, or shows known drafts and asks what to write.
It requires no initialized harness. Explicit output paths take precedence; otherwise reader guides
stay in the coding repository's documentation tree while harness tracking stays with the controller.

Claims come from the relevant code, configuration, designs, and verified history. Each acronym is
spelled out where it first appears, except ones readers know better than the full term, such as URL,
PDF, or a service that goes by its short name. Humanizer is the final prose-editing pass and keeps those expansions; factual, link,
terminology, and diagram validation follow. Essential
evidence gaps or missing checks leave a clearly labeled Draft. Publication and restructuring are
separately approved. The [accepted decision](docs/plans/decisions/2026-09-26-harness-documentation-adr.md)
describes the scope and boundaries.

## Stakeholder Communications

Tell `/hn-write` what to draft, such as `/hn-write email the platform team about the outage`, for a
status tracker, a sync-up invite, or an email update or thread reply, and use `/hn-write slots` with
the people to meet to compare meeting times across attendees' time zones, lunch hours, and holidays.
The [communications skill](skills/planning/harness-write/SKILL.md) needs no
initialized harness. It saves drafts only: sending, inviting, and sharing stay with the user or need
an explicit request. Drafts spell out acronyms at first use, as docs do. Its bundled `rank-slots.ps1` ranks saved getSchedule data without calling a
service. The [accepted decision](docs/plans/decisions/2026-09-29-harness-communications-adr.md)
describes the scope and boundaries.

## Project Decisions

The [harness-decide skill](skills/planning/harness-decide/references/workflow.md) defaults to global availability.
`/harness-decide` alone shows active open decisions plus a one-line **Configuration When Needed**
summary and link, then offers to go through them one at a time; without an answer it saves nothing.
Optional setup is not an immediate blocker;
raise a missing setting only when requested or enabled work needs a human choice that saved
settings, inheritance, or defaults cannot resolve. Recorded Open/Proposed decisions stay visible.
`/harness-decide closed` shows the five most recently decided items; `/harness-decide all` includes
open and recent decisions and the detailed configuration checklist. A number, as in
`/harness-decide closed 20`, changes only the resolved-result limit.
Give `/harness-decide` a decision ID of any status, a question, or a statement, as in
`/harness-decide D-004`, for a plain-language explanation with options, reasons, and an example; it
then asks for your choice, with **Leave it open** among the choices. Your answer is saved with you as
its owner, leaving it open saves a new question as Open, and no answer saves nothing. An ID with a
choice, as in `/harness-decide D-004 B`, is saved at once.
Closed and exact-ID views omit the configuration checklist. See the
[project setup topics](docs/plans/2026-09-15-harness-command-and-record-contracts.md#configuration-when-needed).
It can read existing plans and ADRs without initializing a harness; its bundled PowerShell helper
handles structured CSV reads and writes. It does not start tasks, schedules, or grilling interviews.

## Session Handoff

Use `/handoff [next-session focus] [--output path]` to write a concise continuation note with
artifact/evidence links, open decisions, blockers, process or side-effect uncertainty, and the
first next action. It ends with a ready-to-paste prompt that continues the work from the note in a
new session, such as a VS Code **New Session**, `/clear` in the GitHub Copilot app, or `/reset` in
the Copilot CLI. The [handoff guide](skills/planning/handoff/SKILL.md) is a global-default
MIT adaptation of Matt Pocock's lightweight workflow. It runs on `/handoff` or a plain request such
as "hand this off" or "restart the session", never unprompted.
It follows the project's established handoff/documentation location unless an output is supplied;
standalone work can use OS temporary storage. No harness initialization or Python helpers are needed.
Actual stop, recovery, and resume stay with the `/harness-setup policy` controls; a note does not
clear pauses, start another writer, authorize its suggested actions, or mark unfinished work complete.

Development, report authoring, blocked skill searches, recovery, and unresolved decision workflows
can offer `/handoff` when work must transfer to another session or person. A `/harness-setup`
briefing, from a task ID or a question, can read a supplied note and reconcile it with current
records. These are optional follow-ups, not automatic
notes or new skill dependencies: read-only commands still need a separate explicit request to write
a note, and routine phase transitions/timer ticks keep their existing behavior.

## PR Review

[PR review](skills/github/pr-review/SKILL.md), [watchlist management](skills/github/pr-watch/SKILL.md),
and `/harness-schedule pr <duration>` share one user-wide watchlist under `~/.copilot/pr-review`, independent of the current project.
They support GitHub and explicitly configured GitHub Enterprise hosts through authenticated `gh`.

| Command | Purpose |
| --- | --- |
| `/pr-review` | Review the watched PRs that changed since their last review; an empty watchlist points to `/pr-watch` |
| `/pr-review <PR-or-repository-URL>` | Review an exact PR or a repository's latest open PRs at `blocking`, without adding a watch entry |
| `/pr-review broad [<URL>]` | Review the URL, or the watched PRs, at `broad`, which also reports minor and existing issues |
| `/pr-review list` | Show the latest result for every reviewed PR, watched or ad hoc, including `Running` and `Interrupted` reviews, without remote calls |
| `/pr-review configure` | Show optional saved settings, such as models, limits, scheduling permission, and the default review level, and ask once before saving |
| `/pr-watch <URL>` | Watch a PR or repository at once; it starts no review |
| `/pr-watch remove <URL-or-W-ID>` | Remove a watch entry after confirmation, preserving reports and remote PRs |
| `/pr-watch` | Show watched PRs and repositories with their filters, without remote calls |
| `/harness-schedule pr <duration>` | Configure one whole-watchlist logical schedule under the shared heartbeat |

The [shared setup reference](skills/github/pr-review/references/runtime.md) defines the
controller, configuration, and scheduler contract. `/harness-review` remains current-project review;
its PR-URL route delegates one-way to `/pr-review`. The PR worker reuses the shared read-only
review implementation with verified isolated checkouts, complete paginated comment/thread
evidence, and a fresh second pass only when the first finds nothing new. It never switches the
user's current branch or runs untrusted PR code, hooks, builds, or tests.

[PR publish](skills/github/pr-publish/SKILL.md) takes your work on the current branch to a PR, with
no options, and `/pr-publish` alone publishes. Working changes, staged or not, are committed first in
commits grouped by concern, after one question that shows each commit and any file left out; then
the branch is pushed, never by force. It writes and checks the title, description, and
table locally and shows them; asking to see the draft first stops there. It then creates the PR,
ready for review, with a short description written the way the `create-pull-request` skill writes
one, plus the table. On an existing PR it adds or refreshes only
the table and keeps the rest, including a GitHub Copilot summary. `/pr-publish list` shows the
branch, its PR, and whether its description has the table. Ask in plain words for anything
else, such as a draft or a rewritten description. It reads the PR back and ends with the PR link,
opens PRs through the VS Code create-pull-request tool when available, otherwise through `gh`, and
never comments, requests reviewers, or merges.

Setup requires a strongest-first approved model list, verified per-model effort/context choices,
and explicit time/credit/count bounds. The helper requests the maximum supported permitted
combination, including long context when approved; it does not invent model access or exact
token capacity. Unchanged completed snapshots skip; failed, stale, or incomplete ones remain
pending. Reports are local, not PR comments, approvals, fixes, or merges.

There is one logical PR schedule per user for all watched targets, sharing the heartbeat with other targets.
Setting it reuses its stable identity; an omitted duration reuses its saved cadence or requires an answer.
The timer uses current-user interactive logon, limited privilege, overlap exclusion, and the
saved review settings. Installation creates no list entries, runner settings, or live task.
An explicit setup request with approved targets, capabilities, budgets, and cadence is separate.

## Local Harness

The [runtime guide](skills/planning/harness-runtime/references/runtime.md) describes the shared
PowerShell 7 runtime and required configuration. Harness skills default to global availability;
explicit project copies remain supported. Both use the selected project's configuration and state.

Canonical names and folders use `harness-*`; the hidden `harness-runtime` bundle is the shared
runtime, not a topic, and no folder keeps the old base name `harness`. `/hn-*` is shorthand for quick
typing, not a separate registered skill. For example, `/hn-dev T-012` selects `/harness-dev T-012`.
Retired topic and command names are not accepted, and topics keep no action aliases; see the
[old-name retirement ADR](docs/plans/decisions/2026-10-07-retire-old-names-adr.md).
A first word that is a menu word selects that action; anything else is text, which does the topic's
main job, and no input at all is the topic alone. Descriptions and argument hints show the menu words
first, then the kind of text, not nested autocomplete. Alone, `/harness-review` reviews the current
changes at once; every other harness topic alone shows where things stand and offers the next step,
asking once, and `/harness-write` first confirms a target clear from the conversation. Groups keep
their sub-actions, and `policy list` and `test list` are read-only. The thirteen earlier topics were
merged into seven on 2026-10-07, and four were renamed on 2026-10-09; see the
[topic consolidation ADR](docs/plans/decisions/2026-10-07-harness-topic-consolidation-adr.md) and the
[bare, text, and menu convention ADR](docs/plans/decisions/2026-10-09-bare-text-menu-convention-adr.md).
For example, install `harness-dev` through
`/skillvault-install harness-dev`, then use `/harness-dev <task-id>`.

| Command Synopsis | Responsibility |
| --- | --- |
| `/harness-setup [root\|clean\|policy] [<link, task, or question>]` | Project setup and status, sources and briefings, the Root, historical data, and runtime limits, failure responses, and retention |
| `/harness-dev [upsert\|queue\|sprint\|test\|broad] [<task or request>]` | Task records and readiness, development, queues, the review loop, goal-based sprints, reusable tests, and broad reviews for one task |
| `/harness-write [slots] [<what to write>]` | Feature doc sets, stakeholder trackers, meeting slots and invites, email drafts, and report and query authoring |
| `/harness-review [broad\|list] [<scope>]` | Independent code review: GPT and Claude Opus review the changes, then Claude Opus reviews the whole repository |
| `/harness-decide [closed\|all] [<question or ID>]` | Human decisions, explanations, and their register |
| `/harness-monitor [accept\|auto] [<monitor, link, or folder>]` | Observations, incident proposals, and scheduled automatic follow-up |
| `/harness-schedule [clean] [<target> <duration\|off\|on>]` | Cadence and schedule lifecycle, not historical-data cleanup |

One folder registers one topic; actions are routed inside it. There are no per-action or `hn-*`
skill registrations.

A command that changes saved state asks once instead of needing a separate preview or `--apply`
step. A command that names exactly what to change acts at once: monitor `accept <id>` and a fully
specified schedule, such as `/hn-schedule pr 1d`, `<target> off`, or `<target> on`. With no answer, a
monitor declaration and test `declare` save after 1 minute; every other change, such as policy, `auto`,
layout conversion, or cleanup, holds; a timer offered after a declaration is shown as a command and
starts only on a yes. See Ask Once in the
[runtime guide](skills/planning/harness-runtime/references/runtime.md#ask-once).

Help and status are plain requests, not menu words or aliases; they show where the topic stands and
act on nothing. `/hn-*` shorthand selects the matching topic. Source folders use `harness-*` and
`skillvault-*`, without duplicate shorthand bundles.
See the [actual folder layout](docs/plans/2026-09-16-topic-skill-refactor.md#folder-layout).
Callers of removed source paths must use the canonical folders. The shared heartbeat is implemented
in source; installed-copy replacement and migration of exact live tasks remain separately approved operations.

`/harness-setup root` shows the selected root; `/harness-setup root <path>` selects the parent containing
`.harness_sv/`. First or missing selection prompts with the absolute current folder (`./`); an
unanswered first-selection prompt uses that displayed fallback, while rejection/invalid paths
do not. A valid new path becomes the session Root before asking **Move the existing harness?**
when the previous harness was initialized. **Move is the displayed default, including no answer.**
Explicit answers or user instructions take precedence; No or cancel leaves the old data in place.
Yes or the unanswered default previews and applies relocation from the saved previous root.
`/hn-setup root <path>` follows the same workflow. The new Root stays selected regardless of the move
outcome. A failed move does not count as successful migration. No move
flag is needed, and no move prompt is shown for an uninitialized source or unchanged path.

A move selected explicitly or by the displayed default relocates owned files and registered worktrees, preserves identity
and uncommitted work, and updates stored schedule paths without changing cadence or enabled state.
External code and board locations stay put; `executionRoot` retains the original implicit coding
and test target. See [relocation boundaries and recovery](skills/planning/harness-setup/references/root.md#explicit-relocation).

All harness-owned records, reports, logs, documents, declarations, and local outputs default
to that `.harness_sv/` unless the user explicitly selects another destination. See the
[complete project hierarchy](docs/plans/2026-09-16-topic-skill-refactor.md#project-storage).
Reader-facing `harness-write` guides use the coding repository's documentation tree instead;
they are project documentation, not controller runtime records.
Existing configuration and previously selected artifacts move only through the root-change
workflow above, not through installation or a change to artifact defaults.
A recognized legacy SkillVault `.harness` controller is reused in place
when `.harness_sv` does not exist; unrelated folders are not adopted or merged.

Other shared-runtime actions derive their project path from Root, including the `./` fallback, without
another location confirmation. This includes creating a harness from `/harness-setup` alone, and
reconnects. The session supplies `-ProjectPath` automatically and adds `-ConfirmLocation` when creating
one; these are caller arguments, not extra user prompts.
If Root has not been selected and no explicit target was supplied, use `/harness-setup root ./` once first.
Selecting Root alone does not request initialization or waive operation-specific approvals.
Timers cannot initialize projects. `/harness-setup root board <board-path>` retains empty-board
placement and does not change the implementation repository or migrate existing records.

The harness project can be a plain, non-Git controller folder. Add each existing local coding
repository by giving its path to `/harness-setup`, as in `/harness-setup <local-git-root>`, then
select its returned ID through `/harness-dev upsert <requirements> R-001` or
`/harness-dev <task-id> R-001`.
Keep `ProjectPath` at the controller: code and validation use the selected repository/current
worktree, while state and reports stay in the controller. `/harness-review R-001` reviews
that repository's checkout. No reference implicitly clones a URL, grants permissions, or starts work.

Task matching normalizes known source/reference syntax and outer whitespace without fuzzy
matching or erasing meaningful path/code case. Explicitly revised completed requirements create
a linked follow-up, preserving the original record and same-repository workspace. It must pass
its own validation and required reviews; completion does not commit, merge, or push changes.

Installation creates no live schedule and runs no agents. Creating a harness leaves model, effort,
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

`/harness-review` uses an explicit base, given in plain words such as "since main", or a merge-base
with local `origin/develop`, the remote's default branch (`origin/HEAD`), or the configured upstream,
so committed-ahead work is included with working changes, and a feature branch is reviewed whole,
as its PR would be. Without any of these refs it reports
working-changes-only coverage. If a completed first pass finds nothing new compared with the last
compatible report, it makes one fresh independent pass over the whole selected repository and
keeps supported findings from both. Ordinary Review stays change-scoped;
Fresh keeps the same permissions and budgets, with inadequate coverage reported as blocked.
The [review guide](skills/planning/harness-review/references/workflow.md) explains exact
newness matching, scope, and the optional security review, which composes
[differential-review](skills/security/differential-review/SKILL.md) on request. General review and
security methodology stay separate; neither implies automatic fixes, publication, or a scanner.
Local changes during either pass restart Review on the updated snapshot, at most twice, while
keeping the original baseline and restrictions. Superseded findings remain in the report, not the
current verdict. Persistent edits return `Partial`; pinned PR snapshots and worker errors do not retry.

Reviewers report at the `blocking` level by default: only what blocks merging the change or completing
its task, with the Full pass looking only for what the change breaks elsewhere. `/harness-review broad`
(or `/pr-review broad`, or a saved PR `reviewLevel`) reports every issue with evidence,
including minor and pre-existing ones, and audits the whole repository. Development reviews use
`blocking` unless the task was started with `/harness-dev broad <task>`, which also raises that
task's unit tests to broad. Saved settings and run records that use the level's former name read as
`blocking`. Review Levels in the
[runtime guide](skills/planning/harness-runtime/references/runtime.md#review-levels) defines both.

The review coordinator keeps the request open across findings checkpoints: hand findings to the
existing dev/proposal workflow, let dev fix and validate, then repeat Changes -> Full until no
supported unfixed issues remain. Each script round releases the run lock for dev. No new findings
only triggers Full; it does not mean clean. Recheck older issues, including Full findings outside
the diff. Do not launch another fixer or repeat unchanged snapshots while waiting. Existing budgets,
permissions, failures, and pause/stop requests still apply; unavailable fixes remain pending.

Use `/harness-dev test declare <file>` for [test-flow declarations](skills/planning/harness-dev/references/test-flows.md),
then `/harness-dev test run smoke localPPE` for an ad-hoc run. `testing.afterDev` runs the same flows
with the first review of feature/fix/verify work, and `testing.afterReview` runs flows such as a bounded
local PPE smoke check once on the reviewed code; a failed test goes back to the developer as a fix
round. Checks that need a deployment, such as PPE online, run on demand or on a timer, and
`testing.unitTests` (`blocking` by default, or `broad`) sets how much unit testing the developer adds;
`/harness-setup policy set unit-tests blocking|broad` changes it, and `/harness-dev broad <task>`
raises it for one task. See the
[real-tests ADR](docs/plans/decisions/2026-10-08-real-tests-in-development-loop-adr.md).
`/harness-schedule project 12h test smoke localPPE` schedules only
that target every 12 hours when its environment explicitly allows scheduling; it does not replace
the development timer. Definitions do not provision localPPE or install frameworks. Test evidence
uses the existing history CSV and linked reports, with flow/environment identity and real exits.

`/harness-monitor` alone shows saved definitions, last results, candidates, incidents, and proposals
without collecting data, including declaration files that differ from what's saved, such as held
drafts, then offers to check all monitors now, asking once.
`/harness-monitor <link, folder, or file>` starts monitoring it: it reuses or drafts a
[work discovery](skills/planning/harness-monitor/references/discovery.md)
or [numeric health](skills/planning/harness-monitor/references/monitoring.md) declaration under
`.harness_sv/definitions/` and asks to save it, saving after 1 minute without an answer unless told to
`hold`; the reply then offers a timer with its command, which starts only on a yes. A monitor
name with a change, such as a new threshold, updates that declaration after one question.
`/harness-monitor <name>` checks that monitor now, reading the declared ADO backlog/query, text
folder, adapter feed, or numeric snapshot. Discovery preserves source IDs/revisions and deferred status; failed or incomplete
reads never mean the source is empty or fixed. ADO discovery requires a service scope; the check
workflow assesses relevance, verifies status with AI model `auto`, reconciles evidence-backed local
AlreadyFixed/Stale outcomes, then ranks unfinished work. Unverified results remain visible separately
from pickup proposals. External ADO/document writeback needs separate source-specific approval;
the built-in verifier provides none. Development retains its strongest permitted double-check. Health checks
retain metric/window validation and incident episodes. `/harness-monitor accept <id>` accepts the named proposal at once and shows the task; discovery `C-...`
candidates and health `I-...` incidents share the existing task store. Previously postponed work
enters the priority queue when accepted; actual blockers remain blocked. Readiness,
automatic development, source authentication, and scheduling remain separately authorized. No PBI
visual scraping, source writes, or automatic intake is enabled by installing the skill.
When the owner's policy is to work every item a source lists, the source can declare a standing
`intake` instead, through `/harness-monitor auto <name> worker <flow>`: a complete named check then
accepts what manual acceptance would and runs a declared worker flow, marked `effects: "local"`, for
up to `maxPerCheck` items, with an optional feed
`producer` flow refreshing the source first. Its timer covers Monitor and Work in one job; worker tasks
never enter development. See the [standing intake ADR](docs/plans/decisions/2026-10-08-monitor-standing-intake-adr.md).
Source ownership is exposed as `sourceOwner` on candidates, tasks, and the current-work CSV: ADO assignment,
explicit document Owner metadata, or a normalized adapter field. Unknown/unassigned remains blank;
failed refreshes preserve the last captured evidence, not a claim of current assignment.

Checking all monitors, which `/hn-monitor` alone offers, covers all configured sources;
`/hn-monitor <name>` explicitly scopes the run.
Partial source/verification failures remain visibly incomplete. ADO hierarchies and optional
Markdown-section discovery retain per-item evidence and diagnostics. The canonical board includes
task/candidate and source types, ordered by priority then ID. Explicit repository authority can
inspect a fetched branch without touching dirty coding trees. Pending rollout/PPE/sign-off prevents
completion; unchanged evidenced completion stays closed, and material new requirements become
follow-up proposals, not automatic development. Domain exclusions/priority floors are local policy.

New boards use `current-<project>.csv`, with the filename persisted centrally as `currentFileName`.
Existing boards keep `current.csv` unless explicitly renamed. Asking `/hn-setup root` to rename the
board file previews the guarded rename; a requested snapshot of named monitors under a topic label
stays under artifacts. Neither creates another authoritative queue. See the
[accepted naming decision](docs/plans/decisions/2026-09-25-project-qualified-board-names-adr.md).

Ask `/harness-write` in plain words for a report, dashboard, or query, naming its purpose and platform
(Power BI, Grafana, Jarvis, web, or a saved query), as in
`/harness-write service-health dashboard in Grafana`, for the
[report-authoring dispatcher](skills/planning/harness-write/references/report.md). It loads
the reusable [KPI design companion](skills/data/kpi-dashboard/SKILL.md) and only
the relevant platform guidance, then uses available authorized tools and the existing `/harness-dev`
workflow for tracked local implementation. Alone, `/harness-write` confirms a target clear from the
conversation, or shows known drafts and artifacts and asks what to write. Text updates an identified
existing target or creates a confirmed missing one, never a duplicate of an ambiguous or
inaccessible one; asking for a design only gets a specification. Design-only, Created, Validated, and Published are
different outcomes, not interchangeable success claims. The dispatcher is a session workflow,
not a new PowerShell action or report renderer; the selected platform's writer must be available.
No platform skills/tools are installed automatically, and publishing/monitoring remain separate.
The KPI companion is an MIT adaptation; it includes the original's SQL and Streamlit examples as
untested examples, not a report generator. Both skills default to global availability;
artifact destinations and access approvals remain specific to the requested project/platform.

The `ppt-master` reference installs [Hugo He's PPT Master](https://github.com/hugohe3/ppt-master)
for deck, template, and native-editing workflows. It adds no report route. Editable
artifact requests must identify required object types/actions and verify representative edits;
branded outputs retain the supplied palette, fonts, and template authority in their existing specs.

The [office-documents reference](skills/writing/office-documents/SKILL.md) links to Anthropic's
PDF, Word, and Excel skills under their proprietary terms; it contains none of their implementation.
Workbook-backed reports check formulas and cached results. Requested PDF/DOCX documents receive
final-page visual checks; values-only CSV and Markdown-only work keep their existing scope.

The Jarvis route selects [jarvis-metrics](skills/monitoring/jarvis-metrics/SKILL.md)
for Geneva/MDM, Kusto-to-Metrics or Logs-to-Metrics source decisions and widget configuration.
For example, `/harness-write service-health report in Jarvis, design only` prepares a specification;
creating a saved Jarvis artifact requires an available authorized authoring surface. Query-only
work stays on the query route, including queries intended for Jarvis, without compulsory conversion
or visuals. Jarvis-native monitors/alerts and `/harness-monitor` JSON checks are distinct optional targets.

`/harness-schedule` alone shows every schedule with its cadence, last result, and next run, and
offers to convert an old SkillVault Windows task, asking once. `/harness-schedule project <duration>`
schedules the existing gated E2E pipeline; explicit review, test, and monitor targets reuse their own executors.
`<target> off` and `<target> on` stop or resume a schedule at once, and a target alone shows it.
Durations use `m/h/d/n/y` for minutes, hours, fixed days, calendar months, and calendar years.
New work schedules require an explicit duration; updates can reuse the exact saved cadence/context.
For matching agents or schedules, confirm **Reuse (singleton) or New?**; `as new <name>` remains
create-only and does not authorize competing writers. In development, `/harness-dev <id> now` asks
the running task to yield at its next checkpoint, and `/harness-dev queue <task>` never starts a worker.

One current-user heartbeat dispatches all registered logical schedules, with a routine `1d` baseline
shortened automatically by faster job intervals and earlier deadlines. Active workers keep a
30-minute check cap. `/harness-schedule heartbeat 12h` changes only the baseline, at once;
`/harness-schedule heartbeat` shows it. Applying preserves job cadence, start-time anchors, and
maintenance.
Overdue jobs found unavailable or conflicting wait for the adaptive recheck rather than causing
one-minute polling; a job that waits only behind a running job is rechecked every 2 minutes until
that run ends. The heartbeat is script-only, not an AI model configured as `auto`.
Layout-2 project definitions and enabled settings are authoritative in `config/schedules.json`;
nextDue and active invocation state use `runtime/schedules.json` inside `.harness_sv`. The central registry and latest job receipts are under
`~/.copilot/skillvault/scheduler`. Intersecting coding roots serialize; independent approved roots
can run together. Signed-out execution and machine wake are not currently enabled; conditional
maintenance permission does not activate them. Existing OS tasks need an exact conversion preview,
which `/harness-schedule` alone offers; no install silently changes them or their cadence.

New controllers use authoritative `config/` domain files, generated `board/` CSV views, `runtime/`
state and locks, monthly readable `history/` reports, and a short README for navigation.
Commands and direct edits share the same declarations; there is no second active configuration.
`/hn-setup` alone shows the in-place conversion of an existing controller's old layout and asks
once, with preserved records/evidence/cadence and rollback. Creating or reconnecting a harness never
converts legacy state. This is separate from Root relocation and old Windows task conversion. See the
[layout and verification decision](docs/plans/decisions/2026-09-25-declarative-harness-and-auto-verification-adr.md).

`/harness-setup clean` shows the old run history that retention would prune and asks once, and
`/harness-setup policy set retention <file>` shows a retention change and asks once; neither
changes anything without an answer. Retention defaults to **90 days and 5,000
completed entries per harness**, with optional **1,000 per topic** instead of the total count.
Protect active/pinned/linked evidence, open tasks/incidents, policy evidence, and comparison context.
Records and corresponding files are pruned together; authored plans, decisions, and evaluations
are never run-history candidates. `/harness-schedule clean` instead handles stale schedules:
confirmed stale jobs are disabled first; deletion requires
approval after a 30-day grace. Unavailable, failed, idle, and manually disabled do not mean stale.

`/harness-schedule maintenance` enables automatic cleanup on **Saturday 08:30-09:00 local time**.
Once enabled, it uses the same heartbeat, skips active work, and performs routine cleanup with local scripts.
Historical-data work delegates to the same operation as `/harness-setup clean`; no separate cleanup
algorithm or management topic is introduced.
**Machine wake and AI assistance are allowed when necessary**, not on every run. Identify the
need first; this permission does not enable wake, start an AI process, or expand deletion authority.
No remote scans or catch-up outside the window. See the
[scheduler contract](skills/planning/harness-schedule/references/scheduler.md) for configuration,
migration, duration edge cases, and retained legacy routes.

Use `/harness-setup policy list [limits|fallback|retention]` to inspect policy without writing
anything. `policy set limits|fallback <file>` shows an explicit replacement and asks once; it saves
only on a yes, with the human owner and reason. `policy set retention <file>` likewise shows
retention settings and saves them only on a yes.
The [restriction guide](skills/planning/harness-setup/references/limits.md) and
[fallback guide](skills/planning/harness-setup/references/fallback.md) include field contracts, usage,
and situation/response tables. Policy examples are not applied automatically. `/rules` still manages
human guidance rather than these runtime checks. Safety pauses survive timer ticks and recovery;
resume clears only the reviewed pause, without starting work or requeuing failed tasks. Automatic
retries require explicitly repeatable named test steps and approved transient exits. Eligible steps
default to one additional attempt after five seconds, within the original time budget; explicit
settings remain effective, including `maxRetries: 0`. No exit code is globally declared transient,
and failed AI sessions are not restarted. Per-session CLI credit limits are not aggregate billing
or sandbox guarantees.

`/skillvault-discover explain <skill>` is a global-default, read-only explanation helper covering purpose,
principles, workflow, step-by-step usage, outputs, limits, and source links. It does not execute
or install the skill it explains.

`/skillvault-discover <URL or skill name>` evaluates that candidate and saves a completed public-safe
assessment in `docs/evaluations/<candidate>.md` by default, including defer/skip; asking for chat only opts out.
Reuse the record on reevaluation while verifying fresh evidence, and compare the candidate with
earlier records of related candidates. Private assessments need a private destination. These lasting
references are outside history cleanup and never enter the catalog unless
an actual skill is authored. See [the Oh My Pi assessment](docs/evaluations/oh-my-pi.md).

## Selected Category Skills

These six additions are starting recommendations based on the upstream workflows and
licenses reviewed on 2026-09-14, not an objective worldwide ranking. Existing skills remain
in place. Each defaults to `global` availability; explicit project copies can still be
pinned or customized independently.

| Category | Skill | Upstream | Why selected |
| --- | --- | --- | --- |
| `testing` | `webapp-testing` | [Anthropic](https://github.com/anthropics/skills/tree/main/skills/webapp-testing) | Focused Playwright workflow for browser behavior, distinct from UI design review. |
| `security` | `differential-review` | [Trail of Bits](https://github.com/trailofbits/skills/tree/main/plugins/differential-review/skills/differential-review) | Security review of changes against a baseline, with concrete evidence and coverage limits. |
| `api` | `openapi-spec` | [wshobson/agents](https://github.com/wshobson/agents/tree/main/plugins/documentation-generation/skills/openapi-spec-generation) | Code-first or design-first REST contracts and validation without a full scaffolding framework. |
| `data` | `supabase-postgres-best-practices` | [Supabase](https://github.com/supabase/agent-skills/tree/main/skills/supabase-postgres-best-practices) | Maintainer guidance for Postgres queries, schema, connections, and RLS; not generic SQL or Power BI. |
| `github` | `github-issues` | [GitHub Awesome Copilot](https://github.com/github/awesome-copilot/tree/main/skills/github-issues) | Issue drafting and updates with existing GitHub tools; complements PR review tools. |
| `writing` | `architecture-decision-records` | [wshobson/agents](https://github.com/wshobson/agents/tree/main/plugins/documentation-generation/skills/architecture-decision-records) | Preserves decision rationale and history beyond prose editing or task planning. |

These six are adapted skills: each keeps its original's instructions unchanged in a marked
section, with SkillVault's notes outside it, and carries the original's other files, such as
`webapp-testing`'s `scripts/with_server.py` and Python examples and the
`supabase-postgres-best-practices` reference rules. Nothing else is installed for them: no
browsers, database clients, account setup, or hooks. Each states its runtime requirements and
links to deeper upstream material. Each keeps its original's license, recorded in `license` and
the manifest's `upstream` block: `differential-review` is CC-BY-SA-4.0, `webapp-testing` is
Apache-2.0, and the other four are MIT.

Authorship stays with the original upstream author in `author`, and `maintainer` records who
maintains the SkillVault adaptation. These adaptations declare `version: null` in both the
catalog and the manifest so they do not impersonate an upstream release. In each manifest,
`source` identifies the skill's location inside SkillVault and `upstream` records its
provenance: repository, path, license, and the merged commit. Install metadata points to
SkillVault, not an incompatible upstream folder. `/skillvault-install refresh` merges
upstream changes into these adaptations and updates managed global latest copies only when
explicitly run or scheduled. Project copies are not refreshed by it; changing a default creates
no refresh schedule and updates no upstream dependencies.

## Discover and Explain

`/skillvault-discover [explain] [<purpose, URL, or skill>]` finds, evaluates, and explains skills
without installing or running the target. Alone, it shows past evaluations and asks what to look for.

- A purpose searches the catalog, then external sources as needed, and offers to evaluate the best
  match. Input that could be either a purpose or a candidate searches first, since search saves
  nothing.
- A URL or one skill name is evaluated. Evaluation separates standalone usefulness, creating a
  SkillVault guide, and harness integration when relevant. `upsert/defer/skip` applies only to the
  guide decision; a tool may be worth trying standalone while integration is deferred.
  Recommendations do not authorize trials, installations, or integration.
- `explain <subject>` accepts a skill, tool, or product. For example,
  `/skillvault-discover explain playwright` explains Playwright first, then its relationship to the
  `webapp-testing` guide. It asks only when the intended subject is genuinely ambiguous and does not
  run the subject.

In every skill with a menu, a first word that is a menu word, or exactly 3 or 4 leading letters of
one, selects that action when the rest of the request fits it; otherwise the agent asks. For example,
`exp`/`expl` select `explain`, and installation's `refr` selects `refresh`. Several matches show
choices and run nothing. Anything else is text, and no input at all is the skill alone. Skills keep
no action aliases, other arguments are not abbreviated, and permissions/confirmations stay
unchanged. This is conversational routing, not new PowerShell argument parsing.
Source changes do not refresh installed copies. Completed evaluations retain their public-safe record
by default, unless you ask for chat only; search and explanation stay read-only.

## Install or Author

- `/skillvault-install <name or pattern*> [global|project|session] [origin] [vX.Y.Z]` installs
  existing catalog skills or updates their installed copies. A name without `*` matches one skill
  exactly, ignoring case, and installs it with what it needs; `name*`, `*name`, `*name*`, or `*`
  shows its matches and asks once; no exact match installs nothing and suggests skills that mention
  the name. It does not author source skills. Alone, it shows the catalog with each skill's state
  here and offers to update managed copies that are behind; `/skillvault-install update` brings
  managed copies up to the local checkout.
- `/skillvault-install clean` finds skills that load twice or conflict (for example, global and
  project copies of one skill, or an adaptation next to its original) and shows overlaps. It changes
  nothing until you pick findings to fix.
- `/skillvault-author <what to create or change>` edits an existing repository skill or creates one from
  scratch or a URL, updating its source files and catalog entry. A name does not automatically
  import an installed copy. It never installs; install the result separately with
  `/skillvault-install <name>`. Publishing is separate and requires explicit approval.

Install uses its [read-only source resolver](skills/core/skillvault-install/scripts/resolve-source-repo.ps1):
a checkout named after "from", as in `/skillvault-install rules from <path>`, or the verified
Windows checkout `C:\repos\skillvault`. It does not automatically
select a source cache, temporary worktree, or another session's clone, even with the same origin.
Without that intended checkout, ask for the actual source path; cloning or preparing another revision
needs separate approval. Read the selected checkout's catalog and bundles afresh. Local `latest`
means those current files, not a claim of remote-tip parity, and starts no implicit fetch/pull/checkout.
Creating a harness follows this same rule when installing missing dependencies.

Authoring uses a [read-only source resolver](skills/core/skillvault-author/scripts/resolve-source-repo.ps1):
a checkout named after "in", verified SkillVault working project, known Windows checkout
`C:\repos\skillvault`, then the existing source cache. The Git root, catalog/public layout, and official origin must match;
an invalid explicit or preferred source blocks edits. It displays the resolved source before
writing. No source found means ask for a checkout or approval to clone/open a remote PR, never
create source files in an unrelated working project.

Use `/skillvault-install` to update copies in your environment and `/skillvault-author` to change
repository sources. Installing after authoring is a separate install request. For example,
`/skillvault-install planning-with-files project` installs or updates that project copy;
`/skillvault-author my-custom-skill` authors a source skill: an existing name is edited, and a new
name is created once it is confirmed absent, so the user need not check existence first.
The canonical authoring topic is `/skillvault-author [remove] [<what to create or change>]`;
`/sv-author` is shorthand. Alone, it confirms a skill clear from the conversation, or shows the
checkout's catalog and asks what to create or change. Existing installed copies under former names
move only through an approved topic-layout migration through `skillvault-install update`.
The registered topic for installed copies is `skillvault-install`, including `refresh`.

## Global install

Repository URL: <https://github.com/wzlwit/skillvault>

Windows bootstrap installer URL: <https://github.com/wzlwit/skillvault/blob/main/scripts/install-global.ps1>

Both installers read [scripts/bootstrap-skills.json](scripts/bootstrap-skills.json), the single
place to manage the initial global install set. Keep names only in this file; paths and versions
come from [catalog.json](catalog.json). The authoring topic `skillvault-author` requires explicit
installation through `/skillvault-install skillvault-author`; existing copies are not removed by bootstrap.
`/skillvault-install refresh` runs one refresh now; `/harness-schedule refresh <duration>`
schedules it. Use `/skillvault-install <name or pattern*> [<scope>] [<version>]` for
specific skills or pattern-matched sets. Omitted scope uses `install.defaultScope`, then `project`.
`session` writes no installed copy. Omitted version is `latest`; a pinned version `v#.#.#` installs
that skill's `<skill>/v#.#.#` tag.

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

Or ask an AI coding agent (install `skillvault-author` explicitly before using the optional
source-authoring command mentioned below):

> Install the SkillVault bootstrap skills globally using https://github.com/wzlwit/skillvault/blob/main/scripts/install-global.ps1. Clone or update its repository first, then run the installer from the local checkout. Do not install every catalog skill; after bootstrap I will use `/skillvault-install <name or pattern*> [<scope>] [<version>]` to install or update specific skills, with omitted scope resolved from each skill's `install.defaultScope` and omitted version defaulting to `latest`. Use `/skillvault-discover <URL or skill name> [<location>]` to assess purpose and value before deciding to author it; without a location, it checks installed skills, local catalogs, the official SkillVault repository, then external sources. Use `/skillvault-author <name or URL>` to create or update local SkillVault source skills, not just install an existing one; if no local SkillVault checkout exists, it asks whether to clone one locally or create a remote pull request. Use `/rules <rule> [<location>]` to propose a new or changed rule, or `/rules remove <rule>`, and after confirmation update an authoritative AI-rules document; `/rules apply` puts the core and extra rules into effect, and `/rules apply core` only the core rules. Use `/skillvault-install refresh` to refresh now, or `/harness-schedule refresh <duration>` to schedule latest refreshes: upstream changes are merged into adapted skills when push is permitted, then new commits reach the local checkout and installed copies. Use `/skillvault-install list` to list installed skills and `/skillvault-install uninstall <number, name, or pattern>` to uninstall by list number, range, exact name, or `*` pattern after confirmation. Use `/schedule-manage` to list Windows scheduled tasks, and its `enable`, `disable`, or `delete` to change tasks selected by number, range, list, or keyword after confirmation.

## Local Scripts

Install selected skills from a local checkout with
[install-skills.ps1](scripts/install-skills.ps1). It resolves the suggested scope per manifest,
copies complete skill bundles, and records the actual catalog source, not an upstream link.
A skill from another repository is either a reference, which keeps only its source, or an
adapted skill, which keeps SkillVault's adaptation under the original's name. An adaptation may
take a new name when it turns the original into a different workflow. A reference installs
by fetching the original. An adapted skill installs the adaptation unless `-Variant origin`
requests the original; a renamed adaptation has no `origin` variant and must not be installed
alongside the original. When the source is a Git checkout root, the installer also records the
checkout and the committed version of the skill folder, which refresh uses to merge updates.

```powershell
.\scripts\install-skills.ps1 -Name webapp-testing -Scope project -ProjectPath C:\repos\my-project
```

Use `-Force` only after reviewing an existing installation. For a pinned install, pass
`-RequestedVersion v1.0.0`; the installer reads the skill from its own `<skill>/v1.0.0` tag without
changing your checkout. Uncommitted local changes can be installed with `latest`, but are not
available remotely until explicitly published.

Use `/skillvault-author remove <skill-name[,skill-name...]>`, adding "in <checkout path>" for another
checkout, to remove exact source skills and
their catalog entries after a preview and confirmation. The
[bundled removal script](skills/core/skillvault-author/scripts/skill-remove.ps1)
requires an explicit `-RepoRoot` and previews unless `-Force` is supplied. It checks remaining
manifest dependencies and the shared bootstrap selection, stages source folders before changing
the catalog, and preserves recoverable files on failure. Installed copies, other checkouts,
schedules, and remotes are unchanged. Use `/skillvault-install uninstall` separately for installed copies.

`/skillvault-install refresh` has two steps for managed global `latest` installs:

1. It merges upstream changes into each adapted skill, at the declared `latest`, tag, or commit,
   commits the merge in its own clone, and pushes it to this repository. It does this only when
   the current credentials may push; otherwise it skips this step. Conflicts are not committed.
2. It brings new commits to the recorded local checkout, then to the installed copies. Changes
   made in an installed copy, such as installed uncommitted work, are merged. Installed originals
   follow their upstream repository.

It never pushes your own commits, never commits in your checkout, and leaves conflicts for your
decision. Unchanged copies keep their install timestamp, and failed or dirty caches cannot
overwrite installations. It does not refresh project installs, download arbitrary URLs, or update
the external runtimes named by reference-only skills.

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
.\scripts\verify-installed-skills.ps1 -SkillsPath "$HOME/.copilot/skills" -Name skillvault-install,harness-schedule
```

Parity checking is explicit: a customized or pinned install may legitimately differ from the
current checkout. Runtime dependencies and automated trigger behavior of upstream plugins are
not established by catalog validation.
