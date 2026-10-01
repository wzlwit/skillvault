# Awesome Gamedev Agent Skills Evaluation

- Evaluated: 2026-09-30
- Canonical source: https://github.com/gamedev-skills/awesome-gamedev-agent-skills
- Reviewed revision: `d4b0e35550c55ae70bdfcab4ef5a0e94610438a9` (latest `main` commit when inspected)
- Version: none declared per skill; frontmatter has only `name` and `description`. The latest
  GitHub release, `v1.1.0`, is older than the reviewed commit.
- License: Apache-2.0. NOTICE: copyright 2026 Abhishek Barali and the project contributors; the
  skills are stated to be original works written from primary documentation; engine names are
  trademarks of their owners.
- Recommendation: Skip a SkillVault bundle; install from upstream only for a real game project.
  The owner then chose a reference-only entry; see [Applied Locally](#applied-locally).
- Scope: Source review only; nothing was installed or run

## Purpose and Capabilities

A collection of 74 game-development skills plus a router skill for coding agents. Categories:
Godot (16), Unity (8), Unreal (6), web engines (6: Phaser, PixiJS, three.js), other engines
(10: Bevy, pygame, LÖVE, Roblox), disciplines (15), genres (9), and workflows (4). The guidance
targets specific engine versions, such as Godot 4.7, Unity 6.3 LTS, Unreal 5.8, Phaser 4.2,
PixiJS 8.21, and three.js r186.

The router detects the engine from project files such as `project.godot` or `*.uproject`, sorts
the task by discipline, genre, and workflow, and loads a small set of skills. If it cannot detect
the engine, it asks once and then defaults to Godot.

Two sampled skills are specific and practical:

- `save-systems` is engine-neutral. It covers a versioned save schema, writing to a temporary file
  and then renaming it (with a Windows `.bak` note), migrations, throttled autosave, and pitfalls.
- `create-game-assets` covers an art-direction brief, an asset manifest, approving one visual
  target before a full set, normalization, in-engine checks, and provenance and license gates.
  It hands actual image generation to an `imagegen` skill when one is present. Its two bundled
  Python helpers need Python 3.10+ and Pillow.

The upstream authoring standard is strict: `name`/`description`-only frontmatter, `SKILL.md` under
500 lines, every reference linked directly from `SKILL.md`, and a validator plus tests. Upstream
installs through `npx skills add gamedev-skills/awesome-gamedev-agent-skills` or a Claude Code
plugin marketplace with per-category bundles.

## Value, Fit, and Overlap

Value is high for game projects and low for current SkillVault work. No installed or catalog skill
covers game development. `webapp-testing` is adjacent only for browser games.

Fit: use the upstream collection directly, not a SkillVault bundle. It is large, updated often, and
has its own installer and validator. Importing 75 bundles would add a large maintenance load, and
under the external-source rule in `AGENTS.md`, imported copies could not be edited locally. A
reference-only entry, like `archify`, would only point to upstream and adds little now.

Installed recommendation: Skip for now. If it is installed later for a game project, it would
coexist with current skills and replace nothing.

Standalone use: Worth trying in a real game project. Install it into that project, or install only
the needed category or skills, rather than globally. This keeps 75 extra skill descriptions out of
unrelated work.

Skill recommendation: Skip. Reconsider if a game project starts and SkillVault-managed discovery of
these skills is wanted; a reference-only entry that points to upstream is then the smallest option.

## Risks and Limits

- The `npx skills` installer runs separately distributed code and uses different paths from
  SkillVault's managed copies. See the [Find Skills evaluation](find-skills.md) for its telemetry,
  path, and approval notes.
- Some skills bundle Python scripts with third-party dependencies, such as Pillow. Install them in
  the game project's own environment. The script code was not reviewed or run.
- The guidance is tied to specific engine versions and will age. Take updates from upstream rather
  than keeping a local snapshot. The upstream standard tells agents to check the project's own
  engine version first and keep it unless a migration is requested.
- Any copied material must keep the Apache-2.0 license and NOTICE and mark changed files.

## Existing-Skill Improvement

### Check Every Link in a Bundle

| Detail | Proposal |
| --- | --- |
| Target | `skillvault-authoring` validation, through `checkBundle` in `scripts/validate-skill-files.mjs`, which `scripts/validate-catalog.ps1` runs |
| Evidence and gap | Upstream `scripts/validate-skills.py` at the reviewed revision checks local links in every Markdown file, outside code. SkillVault checks only `SKILL.md` links that start with `./` or `../`. This skips 7 `SKILL.md` links written without `./` (in `kpi-dashboard`, `pr-review`, and `harness-doc`) and 61 relative links in 60 other Markdown files under `skills/`. A read-only scan on 2026-09-30 found that all of them resolve inside their bundles. |
| Proposed change | Apply the existing check (the target exists and stays inside the bundle) to every relative link in every Markdown file of a bundle, with or without `./`. Keep skipping external URLs, in-page anchors, and code blocks. Do not add anchor checks. |
| Expected benefit | Preventive. A renamed or moved reference would fail validation instead of leaving a link that an agent cannot follow. |
| Validation | A fixture reference that links to a missing file fails, and so does a `SKILL.md` link without `./` to a missing file. A valid link between references, an `https://` link, and a link inside a code block pass. The current tree passes unchanged. |

Suggested upsert, only after approval: `/skillvault-authoring upsert skillvault-authoring` to
implement this link check. This is a proposal only; no skill, script, or catalog entry was changed.

Considered, not proposed:

- Upstream script rules (help output, non-zero exit on failure, no destructive defaults or network
  calls). SkillVault's install and removal scripts already preview first and need `-Force` to
  replace or remove, and its source resolver makes no network calls. No failure was found that a
  new general rule would fix.
- A 500-line `SKILL.md` limit. The longest current `SKILL.md` has 136 lines.
- Linking every reference directly from `SKILL.md` and saying when to read it. This is already a
  SkillVault rule.

## Verification Limits

This is a source review, not a runtime test. Read at the reviewed revision: the README, router
`SKILL.md`, `docs/SKILL-FORMAT.md`, `docs/VERSION-SUPPORT.md`, `scripts/validate-skills.py`, NOTICE,
and the two sampled skills. Not read: the other 72 skills, the router's reference files, the bundled script
code, and the tests. Popularity (about 1,300 stars when inspected) is context, not a sign of
quality or safety.

## Applied Locally

On 2026-09-30 the owner chose to add a reference-only entry instead of skipping:
[`awesome-gamedev-agent-skills`](../../skills/gamedev/awesome-gamedev-agent-skills/SKILL.md) in a new
`gamedev` category. It links to the upstream router, routing table, version support page, and skills
at the reviewed revision, and bundles no upstream files. The catalog, README, and topic map list it,
and a focused contract test protects its provenance and boundaries. The 51 skill contract tests,
catalog and resource validation, and `git diff --check` passed. The upsert's old default also
installed a global copy, which was removed the same day; upsert now writes only to the repository.
The upstream collection was not installed or run, and the link-check proposal above was not
implemented.

## Sources

- [Repository](https://github.com/gamedev-skills/awesome-gamedev-agent-skills)
- [Router](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/d4b0e35550c55ae70bdfcab4ef5a0e94610438a9/router/SKILL.md)
- [Authoring standard](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/d4b0e35550c55ae70bdfcab4ef5a0e94610438a9/docs/SKILL-FORMAT.md)
- [Validator](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/d4b0e35550c55ae70bdfcab4ef5a0e94610438a9/scripts/validate-skills.py)
- [NOTICE](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/d4b0e35550c55ae70bdfcab4ef5a0e94610438a9/NOTICE)
- [save-systems](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/d4b0e35550c55ae70bdfcab4ef5a0e94610438a9/skills/disciplines/save-systems/SKILL.md)
- [create-game-assets](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/d4b0e35550c55ae70bdfcab4ef5a0e94610438a9/skills/disciplines/create-game-assets/SKILL.md)
