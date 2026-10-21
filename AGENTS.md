# SkillVault Agent Notes

SkillVault is a catalog-driven repository for public, shareable Copilot skills.

## Layout

- `catalog.json` is the name-sorted lookup index for install and discovery; it lists every skill's path.
- `skills/<category>/<skill>/` holds each skill bundle. `skills/core/` contains SkillVault
  management skills, and `skills/system/` contains OS/system utility skills.
- `templates/` contains reusable scaffolds and draft skills that aren't in the catalog yet.
- `scripts/` contains repeatable automation. Use scripts or code when they make a repeated or
  error-prone task clearer, safer, or easier to rerun.
- The eight project copies in `.github/skills/` are committed on purpose; keep them unless the owner
  asks otherwise (owner decision, 2026-10-20).

## Project Documentation

- `docs/` is this repository's documentation root: plans go under `docs/plans/`, ADRs under
  `docs/plans/decisions/`, and past review records under `docs/reviews/`; add other subfolders only
  when needed.
- ADRs, evaluations, and review records are history: keep them, and keep the skill and command names
  they were written with; a rename fixes only their links (owner decision, 2026-10-14). Plans and
  guides are current: they describe the present state, not an appended history of discussions or
  runs, and name the current topics.
- Spell out each acronym at first use in docs, ADRs, and PR descriptions, except ones readers know
  better than the full term, such as URL or PDF, and product or service names that go by their short
  form (owner decisions, 2026-10-15).
- Handoff notes are working notes, not documentation. In this public repository, save them in the OS
  temporary folder or a path the user names, never under `docs/`.
- Keep root entrypoints such as `README.md` and `AGENTS.md` in place. Skill-owned guides,
  references, and examples stay in their skill bundles so installed copies remain self-contained.
- When a skill writes documentation in another project, honor an explicit destination first, then
  the project's established artifact location. Otherwise discover and reuse its documentation root
  (`doc/`, `docs/`, or a configured alternative), defaulting to `docs/` only when none is
  established. If both `doc/` and `docs/` exist, inspect configuration, README links, and content
  before choosing, and ask only when the convention remains ambiguous. Don't create parallel
  documentation roots or move existing records without a request.
- Harness storage is separate: harness-generated artifacts default to `.harness_sv/` under the Root
  selected by `/harness-setup root`, and moving documentation never relocates `.harness_sv`, its CSV
  views, or run reports. See
  [Plans and Records](docs/plans/2026-09-15-harness-command-and-record-contracts.md#plans-and-records).
- Completed public-safe skill evaluations go in `docs/evaluations/<candidate>.md` by default,
  including defer/skip, unless chat-only is requested. Reuse one record per canonical source,
  recheck stale conclusions, and compare each candidate with earlier records of related candidates.
  Private assessments need a private destination. Evaluation records are not installable catalog
  entries or timer-history cleanup candidates.

## Harness Context

- The [current harness plan](docs/plans/2026-09-15-harness-command-and-record-contracts.md) holds
  the active design, implementation status, and open decisions. Rationale and history are in the
  [ADRs](docs/plans/decisions/), starting with the
  [harness ADR](docs/plans/decisions/2026-09-15-harness-command-and-record-contracts-adr.md); the
  external harness draft is background, not the current plan.
- Live task status comes from the configured harness board's current-work CSV or the runtime's
  `Status` action, and run history from `history.csv` and linked reports. Keep no status documents
  under `docs/`, and don't invent status before a harness is initialized.
- Creating or reconnecting a harness (`/harness-setup` alone) maintains this section without running
  `/init` or replacing unrelated instructions.

## Catalog Rules

Keep `catalog.json` simple and sorted by `name`. Each entry has only:

```json
{
  "name": "skill-name",
  "description": "The skill's one description, identical in skill.json and SKILL.md.",
  "path": "skills/<category>/<skill-name>",
  "version": "1.0.0"
}
```

Every public skill must appear in `catalog.json`, with `name` and `version` matching its
`skill.json`. Each skill has one `description`, identical in `catalog.json`, `skill.json`, and the
`SKILL.md` frontmatter (a reference without `SKILL.md` matches its manifest); change all three
together. `validate-skill-files.mjs` enforces the match.

The `version` field must be present in both files: a non-empty string for a declared version, or
explicit JSON `null` when unversioned. `latest` is an installation policy, not a substitute for an
unknown version.

Versions (owner decision, 2026-10-01): a native skill's version changes with the change itself, in
`skill.json`, `catalog.json`, and the `SKILL.md` metadata together.

| Change | Version |
| --- | --- |
| Wording, typos, docs, tests, or an internal change; nothing works differently | No change |
| Bug fix; it works the same way | Patch |
| Adds something; old use still works | Minor |
| Removes or renames an action or option, changes a default, or changes a saved file format | Major |

- Changes between two tags take one step, the largest.
- A new native skill starts at `1.0.0`; an unversioned one starts at `1.0.0` at its next change.
- Adapted, reference, and guide skills stay `null`; an original's version is pinned only in
  `upstream.version`.
- Tag each version `<skill>/vX.Y.Z` on the commit that contains it, only when the owner asks for a
  commit or push, and push the tags with it.
- Installs default to `latest`. `install <skill> <scope> vX.Y.Z` pins a copy to that skill's tag;
  refresh leaves pinned copies alone.

## Skill Rules

- Each skill folder has `skill.json` and usually `SKILL.md`; add `README.md` when useful for humans.
  `skill.json` owns richer metadata such as `title`, `tags`, `source`, and `install.defaultScope`.
- Preserve verified original authorship for imports and disclose adaptations. Don't infer a
  redistribution license from repository access.
- The repository has no license: all rights are reserved, except five SkillVault skills that are
  MIT on purpose: `rules`, `schedule-manage`, `skillvault-author`, `skillvault-discover`, and
  `skillvault-install`. Every other native skill and SkillVault guide declares `license: null`, and
  adapted skills keep their originals' licenses (owner decisions, 2026-10-20).
- Skill sources (owner decisions, 2026-09-30 and 2026-10-01):
  - Native: write your own skill from a description, session, approach, knowledge, or task.
  - Native, written from other skills, such as a team's internal ones (owner decision, 2026-10-16):
    use your own words, copying no text, code, tables, or examples, and list each original under
    `origins` in `skill.json` (HTTPS `repo`, `branch`, `path`, and the full `commit` it was written
    from). `/skillvault-author <skill> check origins` lists their later commits. An origin URL may
    name a private repository; nothing else private goes into the skill.
  - External, not adapted: keep only a reference: a `skill.json` with the upstream repository, path,
    and version, `install.strategy: upstream`, and no `SKILL.md`; installing fetches the original.
    Use version `latest` so refresh keeps copies current; pin a tag or commit only when the author
    sets one on purpose.
  - External, adapted: keep the adaptation under the original's name, with no `-sv` or other renamed
    copy of the same workflow. It may take a new name when it turns the original into a different
    workflow; a renamed adaptation has no `origin` variant and must not be installed alongside the
    original. It uses `install.strategy: adapted` and names the original in `skill.json`
    (`upstream`, including the merged `commit`) and in `SKILL.md`, which keeps SkillVault's changes
    outside one `<!-- upstream:begin -->` ... `<!-- upstream:end -->` section holding the original
    text unchanged. Refresh replaces that section, merges the original's other files automatically,
    and pushes when it has permission.
  - Guide: when the original can't be installed as one skill (a collection, a tool that installs its
    own skill, or a license that forbids copies or grants none), keep a SkillVault-written guide
    that links to it and copies none of its files. It installs like a native skill.
  - Install picks the adaptation by default; `install <skill> origin` installs the original, except
    for a renamed adaptation.

  `architecture-decision-records`, `brainstorming`, `differential-review`, `github-issues`,
  `grilling`, `handoff`, `kpi-dashboard` and `openapi-spec` (both renamed adaptations),
  `powerbi-modeling`, `rag-implementation`, `supabase-postgres-best-practices`, and `webapp-testing`
  are adapted; `archify`, `humanizer`, `planning-with-files`, and `ppt-master` are references;
  `awesome-gamedev-agent-skills`, `graphify`, `humanizer-ch`, and `office-documents` are guides.
- Don't modify an external-source skill: one whose metadata or source notes name an upstream author
  or source, or that the owner has called external, such as `grilling`. This covers its files and
  catalog entry. Change it only when the owner explicitly asks, for example by adapting it;
  otherwise report the needed change and put overlap notes in the native counterpart and repository
  docs. Unchanged copies keep upstream updates easy to apply.
- Edit an adapted skill only on its wrapper side: `SKILL.md` outside the marked section, and files
  SkillVault added, such as `skill.json`. Never put SkillVault changes in the section, which refresh
  replaces, or in a file from the original, which can stop the automatic merge. If refresh defers
  the skill for a conflict, undo SkillVault's change to that file and move what it needs to the
  wrapper side; the next refresh merges.
- `install.defaultScope` must be `global`, `project`, or `session`; `/skillvault-install` treats a
  missing default as `project`.
- Prefer global installation for reusable catalog skills and an explicit project installation for a
  repository-pinned or customized copy. Keep one installed copy per skill: before installing, check
  global and the current project, and ask whether to move a copy found in the other scope instead of
  adding a second. Installation scope is availability, not execution scope or approval; keep sibling
  runtime dependencies in the same scope. Changing a default never migrates existing copies, project
  state, or schedules, and never expands bootstrap.
- Keep skills concise and direct, and bundle scripts for repeated or tedious operations when they
  make the work clearer, safer, or easier to rerun. `SKILL.md` holds everything needed on every use:
  purpose, trigger phrases, actions, defaults, approvals, prohibitions, and rules that change the
  result; only detail for one action or case goes in `references/`.
- Link every reference directly from `SKILL.md` and say when to read it ("Before `broad`, read
  ..."), not just "see ...". Start any reference file over 100 lines with a short contents list.
- Write `argument-hint` in command synopsis notation: literal action/option names, `<value>`
  placeholders, `[optional]` groups, `a|b` alternatives, and `...` for repeated arguments. A menu
  skill keeps two separate brackets, menu words first, then the kind of text it takes, such as
  `[broad|list] [<scope>]`, never mixing them in one. Put exact action-specific forms in the body;
  the hint is display guidance, not a parser.
- Start a menu skill's `description` with its menu in brackets, then `Alone:` for what it does by
  itself and `Text:` for what it does with the user's own words, such as
  `[broad|list] Alone: review your changes. Text: review that scope.`, alike in `SKILL.md`,
  `skill.json`, and `catalog.json`. A noun after `Alone:` means the skill shows something; a verb
  means it acts. The `/` picker shows only a description's first ~80 characters, and `argument-hint`
  only after a skill is picked, so this lead fits in 80 characters, before the purpose and overlap
  notes; `validate-skill-files.mjs` enforces it.
- Bare, text, and menu (owner decisions, 2026-10-09; see the
  [convention ADR](docs/plans/decisions/2026-10-09-bare-text-menu-convention-adr.md)): a skill alone
  acts at once only on a fixed target, such as `/harness-review` on the current changes; otherwise
  it shows where things stand and offers the next step, asking once, and confirms a target guessed
  from the conversation first. Text after the skill does its main job. The menu lists only the other
  actions, one distinct outcome each, with a brief description; a skill left with nothing else keeps
  one or two quick-navigation words for its most important view or action. There are no aliases.
  Multi-word skill names end in their main verb; single-word names such as `rules` stay. Keep
  `remove` for leaving a list, such as the PR watchlist, and preserve meaningful differences such as
  queue-only versus start-work behavior. Each workflow has one owning topic; others delegate instead
  of exposing a competing implementation. Naming cleanup alone doesn't change approvals.
- Keep commands concise (owner decision, 2026-10-08; see the
  [concise commands ADR](docs/plans/decisions/2026-10-08-concise-commands-adr.md)): defaults cover
  the common case, and an option exists only when neither a default nor a plain-language request can
  do its job, such as a required input, a safety hold, or a choice that scheduled runs need. Don't
  add options that name the default, repeat another action or option, or toggle something rare; the
  agent maps a plain request to the script parameter. Script parameters, check codes, and helper
  steps are internal: keep them out of menus, examples, and user summaries, and tell users only what
  they type and what changes for them.
- When skills materially overlap, briefly name the counterpart and shared work in the
  `catalog.json`, `skill.json`, and `SKILL.md` frontmatter descriptions, keeping each skill's
  distinct role clear. Verify against the relevant skill instructions, and preserve trigger phrases
  and reference-only limits. Recheck these notes during upserts and update relevant docs, without
  adding catalog fields or treating overlap as removal approval. An optional follow-up alone isn't
  material overlap; describe it directly, such as "can install afterward."
- For supporting research, honor an explicit target first; otherwise search local, configured
  accessible internal, then external sources only as needed. Prefer authoritative external sources,
  never leak private terms or content in public queries, and report unavailable sources. This order
  never expands execution scope or overrides stricter source resolvers.

## Management Skills

SkillVault management registers [`skillvault-install`](skills/core/skillvault-install/SKILL.md),
[`skillvault-discover`](skills/core/skillvault-discover/SKILL.md), and
[`skillvault-author`](skills/core/skillvault-author/SKILL.md); [`rules`](skills/core/rules/SKILL.md)
and [`schedule-manage`](skills/system/schedule-manage/SKILL.md) are related utilities. `/sv-<topic>`
is chat shorthand only: the slash picker shows the full names, and there are no abbreviated or alias
bundles. Retired names stay retired; the installer's former-name map only retires copies installed
under them. Installing edits no source except refresh's adaptation merges, and authoring never
installs. See the
[SkillVault topic consolidation ADR](docs/plans/decisions/2026-10-07-skillvault-topic-consolidation-adr.md)
and the [verb-named topics ADR](docs/plans/decisions/2026-10-09-verb-named-topics-adr.md).

## Topic Action Matching

A first word that is a menu word, or exactly 3 or 4 leading letters of one, selects that action when
the rest of the request fits it; otherwise the agent asks. Several matches show choices and run
nothing. Anything else is text, and no input at all is the skill alone. Don't prefix-match skill
names, targets, paths, options, or other arguments. There are no action aliases, and shortening an
action neither bypasses approval nor adds a confirmation. See the
[action-prefix ADR](docs/plans/decisions/2026-09-23-topic-action-prefix-matching-adr.md).

## Harness Skills

The harness topics are [`harness-setup`](skills/planning/harness-setup/SKILL.md),
[`harness-dev`](skills/planning/harness-dev/SKILL.md),
[`harness-write`](skills/planning/harness-write/SKILL.md),
[`harness-review`](skills/planning/harness-review/SKILL.md),
[`harness-decide`](skills/planning/harness-decide/SKILL.md),
[`harness-monitor`](skills/planning/harness-monitor/SKILL.md), and
[`harness-schedule`](skills/planning/harness-schedule/SKILL.md); each `SKILL.md` links its
`references/`. The shared runtime bundle `harness-runtime` is hidden from the `/` menu and isn't a
topic; install it beside the topics in the same scope. `/hn-<x>` is chat shorthand for
`/harness-<x>` only, with no `hn-*` folders or registrations. Retired topic, command, and action
names stay retired: don't accept, advertise, or reintroduce them (owner decisions, 2026-10-07 and
2026-10-09; see the
[old-name retirement ADR](docs/plans/decisions/2026-10-07-retire-old-names-adr.md)).

- Commands: the plan's
  [Command Contracts](docs/plans/2026-09-15-harness-command-and-record-contracts.md#command-contracts)
  and the [topic structure](docs/plans/2026-09-16-topic-skill-refactor.md).
- Shared behavior, such as Root selection, artifact storage, the review panel and levels, Ask Once,
  Reuse or New, and script permissions: the
  [runtime guide](skills/planning/harness-runtime/references/runtime.md). Schedules: the
  [scheduler contract](skills/planning/harness-schedule/references/scheduler.md).

## PR Review Skills

[`pr-review`](skills/github/pr-review/SKILL.md) reviews pull requests,
[`pr-watch`](skills/github/pr-watch/SKILL.md) manages the one user-wide watchlist, and
[`pr-publish`](skills/github/pr-publish/SKILL.md) commits, pushes, and creates or updates the user's
own PR when asked. `pr-review` and `pr-watch` share the user-wide controller at
`~/.copilot/pr-review`, work from any folder without a harness, and have one logical schedule for
the whole watchlist (`/harness-schedule pr <duration>`). `/harness-review` delegates PR URLs to
`pr-review`. The [PR runtime contract](skills/github/pr-review/references/runtime.md) owns settings
and defaults.

## Validation

There is no CI: every check runs locally (owner decision, 2026-10-20).

Choose checks by the behavior changed, not the number of edited files. Start with the cheapest
focused check that can catch the intended regression:

| Change | Validation |
| --- | --- |
| Prose-only documentation or instruction wording, without a contract change | Review the affected guidance and links; run `git diff --check`. No runtime suite is needed. |
| Catalog, manifests, frontmatter, or skill resource paths | Run `scripts/validate-catalog.ps1`. Add the relevant Node contract tests when commands, defaults, or safety instructions change. |
| One script or runtime behavior | Run the matching `scripts/test-*.ps1` fixture and affected consumer checks. After a local fix, rerun that slice first. |
| `powerbi-test` or `powerbi-localize` | `test-all.ps1` doesn't run the Python tests of `powerbi-test` and `powerbi-localize`. When changing those skills, run `python -m unittest discover -s tests` from the skill folder; `powerbi-test`'s tests need `pbir-utils` and `pyyaml` and skip without them (owner decision, 2026-10-20). |
| Cross-topic moves, shared runtime/installer changes with broad consumers, or an explicit full regression request | Run `scripts/test-all.ps1` once after the related edits are complete. |

Use `node --test --test-name-pattern '<relevant test>' scripts/test-skill-files.mjs` for focused
instruction/metadata contracts. A wording-only edit after a successful full run doesn't require
another full run. Broaden validation only when the changed behavior or a failure warrants it.

`npm ci` is needed once per checkout for Node 20+ YAML validation tooling, not for installed skills;
rerun it when the dependency lock changes or dependencies are missing. `test-all.ps1` already runs
the Node contracts, PowerShell fixtures, catalog/resource validation, and `git diff --check`; don't
duplicate those checks around an unchanged successful full run.

Keep tests that protect data preservation, path/scope isolation, approvals, public contracts, and
known regressions. Prefer observable behavior or parsed structure over exact prose matches. Don't
add tests solely to freeze incidental wording or duplicate the same failure case. Fixtures use
temporary directories and Git repositories with fake agents, tasks, providers, and models, never
live schedules, installed copies, or ownership claims.

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
`scripts/install-global.ps1` for approved targets and verify installed metadata against the catalog.
Changed or pinned installs require review and explicit `-Force` (`--force` in Bash).

## Git Safety

Do not commit, push, force-push, or open a PR unless the user explicitly asks. This repo may
intentionally keep all work uncommitted while the design is still moving. The one standing exception
(owner decision, 2026-09-30) is `/skillvault-install refresh`: it commits merged adaptation updates
in its own clone and pushes them when it has permission. It never force-pushes, and it never commits
or pushes anything from the owner's checkout.
