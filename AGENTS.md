# SkillVault Agent Notes

SkillVault is a catalog-driven repository for public, shareable Copilot skills.

## Layout

- `catalog.json` is the compact lookup index for install/discovery.
- `skills/core/` contains SkillVault management skills.
- `skills/system/` contains OS/system utility skills.
- `templates/` contains reusable scaffolds.
- `scripts/` contains repeatable automation. Use scripts or code when they make a repeated or error-prone task clearer, safer, or easier to rerun.

## Project Documentation

- `docs/` is this repository's documentation root. Put project plans under `docs/plans/` and
  ADRs under `docs/plans/decisions/`; use other documentation subfolders only when needed.
- Keep root entrypoints such as `README.md` and `AGENTS.md` in place. Skill-owned guides,
  references, and examples stay in their skill bundles so installed copies remain self-contained.
- When a skill writes documentation in another project, honor an explicit destination first,
  then the project's established artifact location. Otherwise discover and reuse its documentation
  root (`doc/`, `docs/`, or a configured alternative); default to `docs/` only when none is established.
- If both `doc/` and `docs/` exist, inspect configuration, README links, and content before choosing;
  ask only when the convention remains ambiguous. Do not create parallel documentation roots or
  move existing records without a request.
- Documentation location is separate from harness board/runtime storage. Do not relocate
  `.harness_sv`, CSV state/views, or run reports merely because documentation moves.
- Harness-generated project artifacts default to `.harness_sv/` inside the root selected by
  `/harness root` (`/hn root`), unless the user explicitly selects another destination. Use
  `.harness_sv/docs/` for authored plans, decisions, and handoffs, `.harness_sv/definitions/` for
  declarations, and `.harness_sv/artifacts/` for local report/query outputs. Pass these defaults to
  delegated specialists. Existing project documents, installed skill bundles, application code,
  and requested host instruction entrypoints stay in place; do not migrate them implicitly.
- Completed public-safe skill evaluations are saved in `docs/evaluations/<candidate>.md` by
  default, including defer/skip, unless chat-only is requested. Reuse one record per canonical
  source and recheck stale conclusions. Private assessments require a private destination.
  Evaluation records are not installable catalog entries or timer-history cleanup candidates.

## Harness Context

- Start with the [current harness plan](docs/plans/2026-09-15-harness-command-and-record-contracts.md)
  for the active design, implementation status, and open decisions. Keep current-facing docs
  focused on the present state, not an appended history of earlier discussions or runs.
- Use the [harness ADR](docs/plans/decisions/2026-09-15-harness-command-and-record-contracts-adr.md)
  for decision rationale/history. Consult historical material when needed; do not delete it or
  treat an external reference draft as the current project plan.
- Live task status comes from the configured harness board's current-work CSV or the runtime's
  `Status` action; run history is in `history.csv` and linked reports. These are not duplicate
  status documents under `docs/`. Do not invent current status before the project is initialized.
- Decision bulletins keep explicitly recorded Open/Proposed decisions visible. Missing configuration
  becomes an open choice only when requested or enabled work needs a human decision that saved
  settings, inheritance, or defaults cannot resolve; check environmental facts with tools.
  Default/open views add one brief **Configuration When Needed** summary and source link for
  documented optional setup; `list all` expands that checklist. Closed/exact-ID views omit it.
  Do not count optional setup as open decisions, change statuses, or create records during display.
- `/harness init` maintains this navigation section without invoking another `/init` workflow or
  replacing unrelated project instructions.
- `/harness root` shows the selected parent root and `.harness_sv` paths; `/harness root <path>`
  selects that parent. First or missing selection prompts with the absolute current folder;
  no answer uses displayed `./` in session context only. Rejection/invalid paths never fall back.
  Use the read-only `Root` action; only this action permits omitted `-ProjectPath`. Reselection
  selects a valid new root first, saving the previous root as a possible move source. If that
  source was initialized, prompt with Move as the default, including no answer. Explicit answers
  or applicable user instructions override the default; No or cancel skips the move. The new
  Root stays selected either way. Uninitialized sources and unchanged paths need no move
  prompt. Legacy `--root` and `--board` routes preserve their
  meanings; only an explicit board override may place new board files outside `.harness_sv`.
  New controllers default their board to `.harness_sv`; recognized legacy `.harness` controllers
  are reused in place when the new directory is absent. `loc` remains a compatibility alias.
- All harness actions derive their project path from the selected Root, including the displayed
  `./` fallback, without another location confirmation. The session supplies `-ProjectPath`
  automatically. If no Root or explicit target exists, use `/harness root ./` once. A valid explicit
  action path overrides that call only; `/harness root <path>` changes the session selection
  independently of the optional data move. Invalid target paths never change Root or fall back silently.
- `/harness init` and reconnects reuse Root. The session supplies `-ConfirmLocation` automatically
  with the resolved path when initialization is requested; no second location prompt is needed.
  Scheduled initialization remains prohibited. Root selection alone requests no initialization,
  installation, workers, or schedules and does not bypass operation-specific approvals or denials.
- `/harness root <new-parent>` and `/hn-root <new-parent>` require no move flag. For an initialized
  previous harness, Yes or no answer after the displayed Move-default prompt previews and applies
  relocation unless an explicit instruction overrides it. The saved previous root is the source, not
  its new selection. A blocked or failed move leaves the valid new Root selected, reports that
  data was not moved, and preserves recovery evidence; never silently initialize a replacement.
  An unanswered move prompt uses Move, never the `./` path fallback. The session supplies
  `-Move`/`-Apply` for the explicit choice or this default without another Yes-only confirmation.
  Existing-root aliases add no second location prompt. Scheduled ticks cannot initiate a move.
  Preserve project identity,
  records, queues, pauses, dirty registered worktrees, external boards/repositories, and schedule
  cadence. `executionRoot` retains the former implicit coding/test target and instructions.
  Existing path restrictions and inherited denials still apply. Refuse active/unrecovered work,
  collisions, linked filesystem entries, and ambiguous scheduled contexts; never merge controllers.
  Pending-move markers block incomplete recovery. No live move is implied by installing this feature.

## Catalog Rules

Keep `catalog.json` simple and sorted by `name`. Each entry has only:

```json
{
  "name": "skill-name",
  "description": "Short purpose.",
  "path": "skills/<category>/<skill-name>",
  "version": "1.0.0"
}
```

Every public skill must appear in `catalog.json`. The catalog `name` and `version` must match the skill's `skill.json`.

The `version` field must be present in both files: use a non-empty string for a declared
version, or explicit JSON `null` when unversioned. `latest` is an installation policy,
not a substitute for an unknown version.

## Skill Rules

- Each skill folder has `skill.json` and usually `SKILL.md`; add `README.md` when useful for humans.
- `skill.json` owns richer metadata such as `title`, `tags`, `source`, and `install.defaultScope`.
- Preserve verified original authorship for imports and disclose adaptations. Do not infer a redistribution license from repository access.
- Skill sources (owner decisions, 2026-09-30 and 2026-10-01):
  - Native: write your own skill from a description, session, approach, knowledge, or task.
  - External, not adapted: keep only a reference: `skill.json` with the upstream repository, path,
    and version, `install.strategy: upstream`, and no `SKILL.md`. Installing fetches the original.
    Use version `latest`, so refresh keeps copies current; pin a tag or commit only when the author
    sets one on purpose.
  - External, adapted: keep the adaptation under the original's name, with no `-sv` or other
    renamed copy of the same workflow. An adaptation may take a new name when it turns the original
    into a different workflow. A renamed adaptation has no `origin` variant and must not be
    installed alongside the original. It uses `install.strategy: adapted`, names the original in `skill.json`
    (`upstream`, including the merged `commit`) and in `SKILL.md`. Like a wrapper, its `SKILL.md`
    keeps SkillVault's changes outside one `<!-- upstream:begin -->` ... `<!-- upstream:end -->`
    section that holds the original text unchanged. Refresh replaces that section and merges the
    original's other files automatically, then pushes when it has permission.
  - Guide: when the original cannot be installed as one skill (a collection, a tool that installs
    its own skill, or a license that forbids copies or grants none), keep a SkillVault-written
    guide that links to it and copies none of its files. It installs like a native skill.
  - Install picks the adaptation by default; `install <skill> origin` installs the original, except
    for a renamed adaptation.
  `architecture-decision-records`, `brainstorming`, `differential-review`, `github-issues`,
  `grilling`, `handoff`, `kpi-dashboard` (renamed from `kpi-dashboard-design`), `openapi-spec`
  (renamed from `openapi-spec-generation`), `powerbi-modeling`, `rag-implementation`,
  `supabase-postgres-best-practices`, and `webapp-testing` are adapted; `archify`, `humanizer`,
  `planning-with-files`, and `ppt-master` are references; `awesome-gamedev-agent-skills`,
  `graphify`, `humanizer-ch`, and `office-documents` are guides.
- Do not modify an external-source skill: one whose metadata or source notes name an upstream author
  or source, or that the owner has called external, such as `grilling`. This covers its files and
  catalog entry. Change it only when the owner explicitly asks, for example by adapting it.
  Otherwise report the needed change, and
  put overlap notes in the native counterpart and repository docs. Unchanged copies keep upstream
  updates easy to apply.
- Edit an adapted skill only on its wrapper side: `SKILL.md` outside the marked section, and files
  SkillVault added, such as `skill.json`. Never put SkillVault changes in the section or in a file
  from the original: refresh replaces the section, so a change there is lost, and a changed
  original file can stop the automatic merge. If refresh defers the skill for a conflict, undo
  SkillVault's change to that file, moving what it needs to the wrapper side; the next refresh
  merges.
- `install.defaultScope` must be `global`, `project`, or `session`; missing defaults are treated as `project` by `/skillvault-installation install`.
- Prefer global installation for reusable catalog skills; use an explicit project installation
  for a repository-pinned or customized copy. Keep one installed copy per skill: before installing,
  check both global and the current project, and if the skill exists in the other scope, ask
  whether to move it instead of adding a second copy. Installation scope is availability,
  not execution scope or approval. Keep sibling runtime dependencies in the same selected scope.
  Changing a default never migrates existing copies, project state, or schedules, and never
  expands bootstrap.
- Keep skills concise and direct. `SKILL.md` holds everything needed on every use: purpose, trigger
  phrases, actions, defaults, approvals, prohibitions, and rules that change the result. Put only
  detail for one action or case in `references/`.
- Link every reference directly from `SKILL.md` and say when to read it ("Before `record`, read
  ..."), not just "see ...". Start any reference file over 100 lines with a short contents list.
- Use command synopsis notation in `argument-hint`: literal action/option names, `<value>`
  placeholders, `[optional]` groups, `a|b` alternatives, and `...` for repeated arguments.
  For multi-action topics, keep the hint compact, such as `[list|run] [<arguments>...]`, and
  put exact action-specific forms in the body. The hint is display guidance, not a parser.
- For supporting research, honor an explicit target first; otherwise search local, configured
  accessible internal, then external sources only as needed. Prefer authoritative external
  sources, never leak private terms/content in public queries, and report unavailable sources.
  This discovery order never expands execution scope or overrides stricter source resolvers.
- Keep topic action lists short and meaningful: one distinct outcome per canonical action,
  with a brief description that lets the user choose without reading the full procedure.
  Prefer familiar verbs; do not advertise synonyms for the same operation as separate actions.
  Keep aliases in compatibility guidance and modes/targets in arguments when they only qualify
  an operation. Preserve meaningful differences such as queue-only versus start-work behavior.
  Distinguish listing records, inspecting runtime status, and showing available actions/help;
  do not add all three when they would return the same view. Each workflow has one owning topic;
  other topics delegate instead of exposing a competing implementation. Naming cleanup alone
  does not change defaults, approvals, or existing command behavior.
- When skills materially overlap, briefly name the counterpart and shared work in `catalog.json`,
  `skill.json`, and `SKILL.md` frontmatter descriptions, while making each skill's distinct role clear.
  Verify against the relevant skill instructions; preserve trigger phrases and reference-only limits.
  Recheck these notes during upserts and update relevant docs without adding catalog fields or treating overlap as removal approval.
  An optional follow-up alone is not material overlap; describe it directly, such as "can install afterward."
- Prefer bundled scripts for repeated or tedious operations when they make the work clearer, safer, or easier to rerun.

## Management Skills

Registered names, folders, and dependencies use `skillvault-discovery`, `skillvault-installation`,
`skillvault-refresh`, and `skillvault-authoring`. `/sv-*` remains conversational shorthand only,
not a separate skill registration. Keep the full names visible in the slash-command picker;
do not rename canonical topics to abbreviations or create duplicate alias bundles.
`/skillvault-source` and `/sv-source` remain text routes to authoring, not registered bundles.

- `/skillvault-installation` lists installed skills. Its `install`, `update`, `uninstall`, and `list catalog`
  actions manage copies or inspect the catalog, never application code or SkillVault sources.
  Run its resolver in Install mode and use the verified `C:\repos\skillvault` checkout or an explicit
  `--repo` choice. Never auto-select a cache/session clone or implicitly clone, pull, or switch branches.
  Read the actual source catalog/bundles and show source and installation paths separately; missing
  or invalid intended sources block installation. `/harness init` follows this for missing dependencies.
- `/skillvault-discovery search`, `evaluate`, and `explain` find candidates, assess adoption, or explain
  usage without executing or installing the target skill. Evaluation alone has a narrow record-only
  write exception in the verified SkillVault checkout; search/explain remain read-only.
- `/skillvault-authoring upsert` authors skill bundles and catalog entries in the verified
  SkillVault repository, not the working project's application source. Publishing requires a request.
  `create` and `update` are aliases with the same upsert behavior; ambiguous or inaccessible is
  not absent. The session resolves existence without making the user choose an operation first.
  Use its read-only source resolver before authoring: explicit `--repo`, verified working project,
  known Windows checkout `C:\repos\skillvault`, then cache. Verify Git root and origin, block invalid
  preferred sources, and show source paths separately from the original working project. Upsert never
  installs; installing is a separate `/skillvault-installation install` request.
- `/skillvault-authoring remove` removes exact SkillVault source bundles and catalog entries after confirmation.
  Installed copies stay unchanged; use `/skillvault-installation uninstall` for those.
- `/rules` shows guidance/actions. `/rules apply` supplies the compact four rules without edits;
  `add`, `update`, and `remove` retain confirmed changes to the authoritative document; `modify` is an alias.
- `/skillvault-refresh` inspects only. `run` has two steps: merge upstream changes into adapted
  skills and push them to the SkillVault repository when permitted, then bring new commits to
  the recorded checkout and managed global latest copies, merging local changes; conflicts wait
  for the owner. Installed originals follow their upstream. Scheduling delegates to `/harness-timer set refresh`. Legacy `schedule` keeps its
  explicit day semantics, including a one-day default for that compatibility request and `0` for
  one run. Refresh never pushes the owner's own commits or commits in the owner's checkout.
- `/skillvault-installation uninstall` removes exact displayed installed copies by index, range, keyword,
  or name after confirmation. Compatibility-only bundles are not bulk-install/refresh candidates.
- `/schedule-manager` lists Windows scheduled tasks and enables, disables, or deletes selected tasks by index, range, list, or keyword after confirmation.
- `/skillvault-discovery explain <skill>` explains principles, workflow, and usage without running or installing the target skill.

## Topic Action Matching

For explicit action tokens in multi-action topics, exact canonical actions and documented aliases
take priority. Otherwise, exactly 3 or 4 leading letters may select one matching canonical action
in that topic. Multiple matches show choices and ask; no match shows help. Neither executes work.
Do not prefix-match aliases, skill names, targets, paths, options, or other arguments. Preserve
case handling, natural-language routing, full canonical menus, and read-only bare defaults.
Use the existing procedure with its arguments, permissions, and confirmations unchanged; shortening
an action neither bypasses approval nor adds another confirmation. This is conversational routing,
not script argument parsing. See the [accepted ADR](docs/plans/decisions/2026-09-23-topic-action-prefix-matching-adr.md).
Source edits alone do not refresh installed copies; complete the guarded synchronization under
Validation below. They do not authorize publication.

## Harness Skills

Canonical names are `harness`, `harness-policy`, `harness-task`, `harness-dev`,
`harness-review`, `harness-test`, `harness-monitor`, `harness-timer`, `harness-link`,
`harness-report`, `harness-doc`, `harness-comms`, and `harness-decision`. Names, folders, and dependencies use `harness` or `harness-*`.
`/hn` and `/hn-*` are conversational shorthand only; the first parameter selects a subcommand. See the
[topic structure and diagram](docs/plans/2026-09-16-topic-skill-refactor.md).
Use `/harness-<topic> [action1|action2|...] [<arguments>...]` command synopsis notation, not
one registered skill per action. The top-level `/harness [list|root|init|migrate|context|clean]` owns
project setup, explicit in-place layout migration, context, and history cleanup; no management topic is added.
Bare multi-action topics default to read-only `list`, including `/harness-timer`. Use `/harness-dev run`
and `/harness-review run` for explicit execution. Old full commands and shortcuts route to the
matching action, not another registered picker entry. The shared runtime exposes `Clean` for
history; existing execution action names stay unchanged.
Keep canonical `harness`, `harness-*`, and `skillvault-*` topic folders. Do not create separate
`hn-*` alias folders or restore the old action-per-skill bundles such as `harness-init`.
Legacy commands remain text routes to topic subcommands. Installed-copy migration is separate.

`harness-doc` owns full feature doc sets and focused onboarding/troubleshooting updates through
read-only `list` and explicit `upsert`. It authors directly in the session without requiring a
controller or adding a runtime action. Reuse an existing approved task and its ownership/pause
controls when applicable. Reader docs follow the explicit output or coding repository's documentation
convention, with `docs/guides/<feature>/` as the fallback; task/run records remain controller-local.
Distinguish implemented, planned, and unverified behavior and internal, partner, and public readers.
Use Humanizer for the final prose pass, then validate facts, terminology, links, anchors, and diagrams.
Preserve technical content and stable headings; missing evidence or required checks leaves a Draft.
Document moves, tool installations, and publication retain separate approval. The
[documentation ADR](docs/plans/decisions/2026-09-26-harness-documentation-adr.md) records these choices.

`harness-comms` drafts stakeholder trackers, meeting invites, and email updates or thread replies
through read-only `list`, read-only `slots`, and explicit `upsert <tracker|meeting|email>`. Like
`harness-doc`, it works in the session without a controller or runtime action. It saves drafts only:
sending, inviting, sharing, link-permission changes, and deletion each need an explicit request.
It re-reads before overwriting a draft the user may be editing and verifies every write by reading
it back. Owners come from authoritative records or the user, never authorship alone. The bundled
`rank-slots.ps1` ranks saved getSchedule data offline and is covered by `test-harness-comms.ps1`.
Keep its public examples generic. The
[communications ADR](docs/plans/decisions/2026-09-29-harness-communications-adr.md) records these choices.

New controllers use layout 2: authoritative `config/project.json`, `monitors.json`, `tests.json`,
`policy.json`, and schedules when configured; generated `board/` views; `runtime/` state/locks;
monthly readable history and a navigation-only README. Commands update the same declarations;
direct edits activate after validation at the next operation, with stable in-flight configuration
and live pause/stop controls. `/hn migrate` previews before approved apply; `init` never migrates.
Preserve task/queue identities, evidence bytes, external boards, pauses, and schedule cadence.
Custom adapters and snapshots stay in place for explicit path review, not implicit rewriting or
deletion. Temporary originals are removed after success/rollback; incomplete recovery stays blocked.
No live DAS migration is implied. See the [accepted layout and verification ADR](docs/plans/decisions/2026-09-25-declarative-harness-and-auto-verification-adr.md).

New controllers persist `currentFileName` as `current-<project-slug>.csv`; configs without that field
retain `current.csv`. Resolve it through `Get-HarnessCurrentPath` or the returned `current` path,
never a monitor-only hard-coded basename. Init, layout migration, and Root relocation preserve
existing names. `root --current-file` delegates to Board rename preview/approved Apply, preserving
records and registered/decision links under locks and temporary rollback. Explicit filtered views
use a topic label plus exact monitor names and become point-in-time artifacts, not canonical boards
or task stores. No automatic per-topic copies or live renames are enabled by source/copy updates.
See the [accepted naming ADR](docs/plans/decisions/2026-09-25-project-qualified-board-names-adr.md).

Participating runtimes use shared checkout and installed-bundle ownership in addition to existing
controller locks. Hold checkout ownership through active development, validation, and review;
tests are possible writers, and independent readers share only a stable snapshot while excluding
writers. Busy results identify owners. Defer affected bundle/dependency updates; never stop work
or steal uncertain claims. Older runtimes require an attended stopped-worker transition with temporary rollback protection.
Force replacement is not an ownership override. Preserve pauses, explicit recovery, current/worktree
defaults, and read-only status. Use temporary `SKILLVAULT_OWNERSHIP_ROOT` values in fixtures, not live
claims. See the [accepted ownership ADR](docs/plans/decisions/2026-09-23-shared-ownership-adr.md).

Executable dependency contracts use `runtimeInterfaces` and `requiredInterfaces`, checked before
launch under ownership. Equal package versions are not compatibility evidence. Report required
companion updates; do not install them implicitly or satisfy missing installed siblings from a
source checkout. Keep one canonical current source and installed copy, not parallel legacy names
or completed installation archives. The `installation-transactions` interface provides short-lived
originals in OS temporary storage during replacement, migration, or uninstall; success or verified
rollback removes them. A failed restoration leaves its originals only until that interrupted update
is resolved. No persistent recovery directory, backup-retention policy, or backup maintenance job
is retained. Delete existing archives and obsolete files only within an explicit approved scope;
preserve unrelated/customized/pinned skills and harness run evidence. Use isolated
`SKILLVAULT_TRANSACTION_ROOT` values in fixtures. See the [current-copy-only ADR](docs/plans/decisions/2026-09-25-current-copy-only-installation-adr.md);
the earlier [interface and baseline decisions](docs/plans/decisions/2026-09-24-recovery-compatibility-and-harness-baseline-adr.md) remain accepted.

`harness-task` owns task intake, identity, readiness, and updates. `harness-dev` owns running and
queuing work, reusing the same intake helper for ad-hoc requests. Do not add competing task stores.
Match source/scope/repository after meaning-preserving normalization, not fuzzy similarity or
blanket case-folding. Explicitly revised completed work creates a linked `followUpOf` task;
preserve the original evidence and same-repository workspace, restart validation, and do not
inherit risk or auto-eligibility. Completed means verified in the assigned workspace, not integrated.
`harness-timer clean` handles stale schedules only; `/harness clean [--policy <file>] [--apply]`
owns retention settings and historical records/reports. Weekly maintenance invokes the same
harness cleanup implementation, without changing the Saturday window or deletion protections.

All harness skills default to global availability; explicit project installs remain supported.
Project selection, configuration, boards, tests, and safety policies stay project-local. The
shared PowerShell 7 runtime is bundled under `harness`; install it beside `harness-timer`
in the same selected scope. Installing the skills does not initialize
project state or create a schedule. Missing runner allowances inherit the current session/parent,
then maximum verified or native settings; do not require duplicate configuration or add arbitrary
restrictions. Pass compatible non-secret context through `-RunnerContext`/`-RunnerContextPath`;
explicit project/parent limits, denials, and read-only reviews remain enforced. Tests use
temporary fixtures and fake agents/tasks, never the user's live schedules.
The controller project may be a non-Git folder. Register existing local coding Git roots through
`/harness-link`, then bind each task with `-RepositoryRef` (`-RepoRef`); keep requirements Source separate.
Configuration, board, reports, locks, and relative policy roots stay controller-local. Current and
worktree execution, validation, and reviews follow that task's selected repository. No implicit
cloning, Git initialization, first-reference choice, permission expansion, or saved-task retargeting.
Standalone review accepts a project-wide repository reference; task-linked tests reuse its workspace.
`harness-test` declares shared test flows/environments for ad-hoc, timer, and post-dev validation.
Test-only runs do not require AI settings; scheduled targets require explicit environment approval.
`harness-monitor` supports work discovery from ADO backlogs/saved queries, local text folders,
and normalized feeds from other approved adapters, alongside numeric JSON health observations.
The `monitor-discovery: 5` and `harness-runtime: 4` interfaces are required for discovery. ADO requires an explicit
service scope, not broad BI keyword matching. `check` includes relevance assessment, AI model `auto`
verification, evidence-backed local status reconciliation, and priority ranking. Auto is model
selection mode, not Max or merely scheduling. Development retains its strongest permitted double-check.
Only Relevant verified-open candidates become ranked proposals; insufficient evidence stays Unverified.
Exact evidence, current snapshots/revisions, and unchanged task records guard local AlreadyFixed/Stale
outcomes. Source Closed, disappearance, and age alone are insufficient. External ADO/document status
writes are separately enabled/approved per source, not provided by the built-in verifier. Source candidates preserve
identity, revision, deferrals, and bounded evidence; partial/stale/failed reads cannot imply closure.
Accepted postponed candidates enter the normal queue at source priority; postponement alone is not
a block. Generic On-Hold labels mean reassess; explicit dependency blocks remain. Readiness/automatic-pickup gates remain. Checks never fix code or create tasks;
explicit acceptance uses existing task/reference helpers with Unknown risk and no auto-eligibility
or task completion. Health collection stays separate from service health; repeated breaches reuse
an incident and Unknown cannot record recovery. ADO read credentials remain outside definitions and
reports. Named monitor timers use `-MonitorName` and preserve legacy Test-flow timers.
Expose `sourceOwner` from authoritative ADO assignment, leading document Owner metadata, or the
adapter field, separately from execution ownership. Unknown/unassigned remains blank; fresh complete
collection updates linked owner metadata, while failed/partial/stale reads preserve captured evidence.
Never infer owners from authors, creators, mentions, or AI guesses, or change priority/status for an owner change alone.
`check` without a name means all configured sources via `-AllMonitors`; bare monitor still lists.
Named checks are scoped. Batch completeness and per-source diagnostics must be visible; partial
or unverified work cannot yield a successful aggregate pickup list. Expand ADO descendants and
support explicit parsed Markdown sections, including introductory context. Review implicit design
debt, not only TODO/status headings. Source terminal state alone never completes acceptance work.
Use configured category exclusions/priority floors, not global DAS-specific defaults. Canonical
The configured current-work CSV includes task/candidate row types, sourceType, owner/freshness and checkStatus, ordered
by priority then stable ID; candidate rows grant no execution approval. Optional explicit repository
authority fetches an isolated HTTPS branch snapshot with existing credentials, leaving dirty coding
trees untouched. Durable completion binds requirements, task contract, scope, authority and evidence;
material changes propose explicit follow-ups. PR/release claims need accessible provider evidence;
missing access stays unverified. Remote writes remain separately approved, never implicit.
No live source, threshold, cadence, automatic intake, or report publication is enabled by install.
Monitoring policies apply across approved sources; ADO and folders are examples, not limits.
Partial checks expose an explicitly labeled verified subset for manual acceptance. Explicit
same-requirement links preserve every source's provenance while sharing one work item; no fuzzy
merges, repository retargeting, or implicit merging of existing task IDs. Declared authority governs
only its exact disputed fact. Otherwise substantive contradictions stay Unverified; owner/status
differences alone are not conflicts. Collect all sources before batch reconciliation and retain read
ownership through the decision. Revalidate completion against current proof; verified regressions
propose follow-ups without reopening history. Runtime coverage checkpoints resume on the next
approved check without new budgets or schedules; ordinary deferral never clears safety pauses.
See the [accepted source-agnostic monitoring ADR](docs/plans/decisions/2026-09-25-source-agnostic-monitoring-adr.md).
`harness-report upsert` is a session-level authoring dispatcher, not another runner action or
renderer. Reuse `harness-dev` for tracked local implementation and `kpi-dashboard` for
metric/layout guidance; load only the selected platform specialist. Preserve artifact IDs/paths,
distinguish design/created/validated/published outcomes, and keep monitoring/export handoff optional.
`create` and `update` remain aliases for upsert; do not duplicate an ambiguous or inaccessible target.
`harness-policy set limits` declares runtime boundaries; `harness-policy set fallback` declares bounded test retries
and failure thresholds and manages durable pauses. Bare policy commands inspect only; examples are not
live declarations. Eligible named test steps default to one additional attempt after five seconds,
but still require `repeatable: true` and explicitly classified transient exit codes. There are no
universal transient codes. Omitted retry count/delay use defaults; explicit values, including
`maxRetries: 0`, are preserved. Retries repeat only the failed step within the original budget and
need no per-attempt confirmation after eligibility is approved. Agent sessions and legacy validation
commands are not retried, and failed tasks are not automatically requeued. Policy, recovery, and
timer changes never silently clear safety pauses. All worker
entrypoints share the same execution gate. These controls are not an OS security sandbox.
Before scripts, the session follows the shared runtime's permission preflight: reuse approvals
and request missing command-scoped host access before execution. An attended agent fallback may
use permitted tools for the same work, never bypassing denials, ownership, pauses, budgets, or
required tests/review. Unverified checks and unavailable state recording stay pending. This is
not automatic runtime authentication recovery or an unattended permission/failover mechanism.
For additional or matching dev/review agents and schedules, confirm Reuse (singleton) or New
unless already chosen in the request. Keep reviewer context independent. Named project timers
use `-InstanceMode New -InstanceName <name>` or explicit Reuse; unanswered matching choices
create/update nothing. Multiple identities do not bypass the shared run lock or permit competing
writers. Recurring ticks never ask again. The user-wide PR logical schedule remains singleton.
`/harness-timer set` configures project, PR, refresh, or maintenance targets under one current-user
heartbeat; `set heartbeat <duration>` changes only its user-wide routine baseline, default `1d`.
Baseline settings accept fixed `m/h/d` durations of at least one minute, with saved-value reuse.
New work durations require units (`m/h/d/n/y`); fixed units support decimals and calendar
units whole numbers. Layout-2 project declarations use `config/schedules.json`; runtime progress and
active invocation snapshots use `runtime/schedules.json`. Ticks do not overwrite declarations. A central
registry dispatches due nonconflicting work. Faster enabled job intervals shorten the heartbeat,
active workers retain a 30-minute check cap, and earlier deadlines still win. A tick defers already
blocked overdue deadlines to the adaptive recheck without changing their due times. Baseline edits
preserve job anchors, cadence, enablement, and maintenance, and start no AI worker. Source/copy
updates require separately approved live synchronization; no duplicate writers are allowed.
Use `migrate` for exact existing OS timers; preserve cadence, enabled state, ownership, and evidence.
Maintenance is opt-in, Saturday 08:30-09:00 local. Machine wake and AI assistance are allowed
when necessary, not required for routine scripted cleanup. Establish a concrete need and retain
existing scope, budgets, denials, and cleanup approvals; permission alone enables no wake setting
or AI process. No remote scan or catch-up outside the window. History defaults to 90 days and
5,000 total completed entries per harness;
optional per-topic mode uses 1,000. Protect required evidence, honor explicit limits/paths, and
prune records and owned files together. Verified stale schedules are disabled before a 30-day
grace; deleting definitions requires explicit approval. Failed/idle/unavailable is not stale.
Read the [scheduler contract](skills/planning/harness-timer/references/scheduler.md).
Scheduled refresh may retry temporary Busy targets three times after 1, 10, and 30 minutes,
without holding an active worker slot between attempts. Preserve the regular anchor and exact
deferred source/metadata bindings; changed inputs end that retry target. Recovery, legacy
transitions, self/parent runtime ownership, and actual failures are not retryable. Disable or
definition changes cancel idle retries. Manual updates do not create jobs; no live schedule or
installed-copy update is implied. Agent/test retry policies remain separate.
Standalone `/harness-review run` includes ahead commits and working changes, with one fresh whole-repository
pass when no new findings appear. Findings are continuation checkpoints: publish through the existing
dev/proposal workflow, release the script run lock, and resume Changes -> Full after dev fixes and
validates, until no supported unfixed issues remain. Recheck earlier issues outside the diff too.
No new findings is not completion. Do not add a fixer/notifier/scheduler or spin on unchanged code;
keep missing fixes pending and preserve budgets, pauses, failures, and permissions.
Local edits during either pass restart Review on the latest snapshot
up to twice, keeping the pinned base and permissions; archive superseded findings and return Partial
if edits persist. Worker failures and isolated PR snapshot changes do not retry. Fresh covers the
whole selected repository; ordinary Review and development Critical stay change-scoped. Keep
snapshot checks, restrictions, and budgets; insufficient coverage is blocked, not clean. Never
widen to another repository or evade per-round limits. Fix-driven continuation has no fixed round
count within existing approved limits. `--security` loads the installed differential-review methodology
without copying it, adding tools, or launching a third pass. Development critical review is separate.

## PR Review Skills

`pr-review`, `pr-watch`, and the `/harness-timer set pr` route share the user-wide controller at
`~/.copilot/pr-review`. Bare review/watch topics inspect; `/pr-review run` starts review.
Keep one logical schedule for the whole watchlist under the shared heartbeat, never per-target/project timers.
`/harness-review` stays project-first and delegates PR URLs one-way; PR review calls the shared
harness implementation, not the harness-review skill recursively. GitHub/approved Enterprise
access uses authenticated `gh`; other providers require a separately requested adapter.
Use explicit ranked model profiles, verified effort/context support, and bounded budgets.
Isolated snapshots and PR text are untrusted evidence; no PR code execution or remote writes.
Install creates no watch entries, live configuration, workers, or schedule. Tests use temporary
Git repositories and fake provider, model, and task operations. Preserve unrelated live timers.

Apply `/rules apply` and project instructions to every harness entrypoint and worker. Core
guidance is maintained in `rules/references/core.md`; do not inject the rule-editing workflow
into workers. Offer `/grilling` for consequential unresolved human choices, including new
choices after development, not every review or monitor tick. Unattended workers report questions
and defer dependent actions. Grilling never replaces tests/review or automatically rewrites rules.

## Validation

Choose checks by the behavior changed, not the number of edited files. Start with the cheapest
focused check that can catch the intended regression:

| Change | Validation |
| --- | --- |
| Prose-only documentation or instruction wording, without a contract change | Review the affected guidance and links; run `git diff --check`. No runtime suite is needed. |
| Catalog, manifests, frontmatter, or skill resource paths | Run `scripts/validate-catalog.ps1`. Add the relevant Node contract tests when commands, defaults, or safety instructions change. |
| One script or runtime behavior | Run the matching `scripts/test-*.ps1` fixture and affected consumer checks. After a local fix, rerun that slice first. |
| Cross-topic moves, shared runtime/installer changes with broad consumers, or an explicit full regression request | Run `scripts/test-all.ps1` once after the related edits are complete. |

Use `node --test --test-name-pattern '<relevant test>' scripts/test-skill-files.mjs` for focused
instruction/metadata contracts. A wording-only edit after a successful full run does not require
another full run. Broaden validation only when the changed behavior or a failure warrants it.

`npm ci` is needed once per checkout for Node 20+ YAML validation tooling, not for installed
skills; rerun it when the dependency lock changes or dependencies are missing. `test-all.ps1`
already runs the Node contracts, PowerShell fixtures, catalog/resource validation, and
`git diff --check`; do not duplicate those checks around an unchanged successful full run.
Its fixtures and fake task/Git commands do not alter live schedules.

Keep tests that protect data preservation, path/scope isolation, approvals, public contracts,
and known regressions. Prefer observable behavior or parsed structure over exact prose matches.
Do not add tests solely to freeze incidental wording or duplicate the same failure case.

Use `scripts/install-skills.ps1` for selected local installs and
`scripts/verify-installed-skills.ps1` for an explicit source/copy parity check. Local customized
copies need not match a newer checkout unless a refresh is requested.

Standing owner instruction: after validated skill-source development, update affected existing
managed `latest` copies in the current user's global and current-project scopes, plus explicitly
selected targets. This request supplies routine replacement approval; preview exact targets, reuse
the verified source checkout and guarded installer, update compatible existing companions together,
and verify source/copy parity before reporting completion. Leave already matching copies unchanged.
Honor explicit source-only or `none` requests. Preserve pinned/customized copies, missing installs,
unselected projects, live state, and schedules unless separately authorized. Ownership conflicts or
unresolved replacements remain pending; source validation alone is not installed-copy completion.

For bootstrap installer changes, run `scripts/test-bootstrap.ps1`, then run
`scripts/install-global.ps1` for approved targets and verify installed metadata against the
catalog. Changed or pinned installs require review and explicit `-Force` (`--force` in Bash).

## Git Safety

Do not commit, push, force-push, or open a PR unless the user explicitly asks. This repo may intentionally keep all work uncommitted while the design is still moving.
The one standing exception (owner decision, 2026-09-30) is `/skillvault-refresh`: it commits
merged adaptation updates in its own clone and pushes them when it has permission.
It never force-pushes, and it never commits or pushes anything from the owner's checkout.