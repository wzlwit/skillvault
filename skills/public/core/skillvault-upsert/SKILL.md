---
name: skillvault-upsert
description: Edit existing SkillVault repository skill sources or create them from scratch or a URL, updating their catalog entries. Can install the result afterward; publishing requires explicit approval. Use /sv-install to update installed copies only. Triggers on "/skillvault-upsert", "skillvault-upsert", "/sv-upsert", "sv-upsert", "/skv-upsert", "skv-upsert", "create skillvault skill", or "upsert skillvault skill".
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "<name-or-url> [scope]"
---

# SkillVault Upsert

This skill creates or edits skill source files and their catalog entries in the selected
SkillVault repository. It can edit an existing repository skill, create a new one from scratch,
or derive one from a URL. It can install the result afterward using the requested or
manifest-defined scope. Publishing by push or PR requires an explicit request.

Use `/sv-install` when you only want to install or update an existing catalog skill in your
environment. Use `/sv-upsert` when you want to create or edit its repository source. Installation
after upsert is an optional follow-up step, not its primary purpose.

## Parameters

- `nameOrUrl` — required first positional argument.
  - If it looks like a URL, derive a SkillVault skill from that source and link back to it.
   - Otherwise, edit the named repository skill if present, or create a new skill from scratch.
      A name alone does not import an installed copy; installed-skill discovery below is for
      comparison, not automatic copying back into the repository.
- `scope` — optional second positional argument: `default`, `global`, `project`, `session`,
  or `none`. Default: `default`.
  - `default`: use the created skill's `install.defaultScope`; if missing, use `project`.
  - `global`: install into `~/.copilot/skills/<skill-name>` after local upsert.
  - `project`: install into `.github/skills/<skill-name>` in the current repo after local upsert.
  - `session`: read and use the skill in the current AI session only.
  - `none`: create or update source files only.
- `publish` — optional later keyword. If present, validate first, then push directly or open
   a PR to `wzlwit/skillvault` using the current repo state and branch policy. If absent, do
   not commit, push, or open a PR.

## Source Repository Resolution

1. Prefer the current workspace if it contains `catalog.json` and `skills/public/`.
2. Otherwise, use `~/.copilot/skillvault-src` if it exists.
3. If no local SkillVault repository exists, present two choices and wait for confirmation:
   - `clone`: clone `https://github.com/wzlwit/skillvault.git` into
     `~/.copilot/skillvault-src`, then upsert locally.
   - `pr`: create the SkillVault entry directly on a new remote branch and open a pull request.
4. For `clone`, perform the upsert in the confirmed local checkout. Do not create or update
   SkillVault source files in an unrelated workspace.
5. For `pr`, use authenticated GitHub tools to read the current remote catalog and target
   branch, then prepare the skill files and catalog update without writing remotely. Present
   the proposed files and wait for confirmation before creating the remote branch or PR.
   After confirmation, commit the approved changes on the new remote branch and open the PR.
6. Do not commit, push, or open a PR unless the user explicitly selects `pr` or otherwise
   explicitly asks for publishing in the request.

## Check Overlap

For both name-based and URL-based upserts, before writing skill files:

1. Use the selected catalog and `/skillvault-list` inventory to locate likely counterparts,
   then read their skill instructions. For a URL, read the source guidance before comparing.
   Compare actual workflows, not just names or tags; keep this check limited to relevant skills.
2. When overlap is meaningful, briefly name the counterpart and shared work in the description
   in `catalog.json`, `skill.json`, and `SKILL.md` frontmatter. State the skill's distinct role
   so users can choose between them. Keep the catalog's existing four fields; do not add an
   overlap field. Preserve trigger phrases and reference-only or runtime limitations.
   An optional follow-up alone is not material overlap; describe it directly, such as
   "can install the result afterward."
3. Record only verified overlap. Do not credit a reference guide with its upstream package's
   unbundled capabilities. If evidence is insufficient, report the uncertainty instead of
   inventing a comparison.
4. On updates, recheck existing overlap notes and preserve or correct them rather than
   replacing them with a purpose-only description. Update relevant repository documentation
   when the comparison changes.
5. Overlap alone does not authorize merging, replacing, or removing other skills. Report any
   consolidation recommendation separately and leave those skills unchanged unless approved.

## Upsert By Name

When `nameOrUrl` is not a URL:

1. Normalize it to a skill folder name: lowercase words separated by hyphens.
2. Create or update `skills/public/<category>/<skill-name>/`. Use an existing category when
   it is obvious, such as `core`, `system`, `planning`, or `codeview`; otherwise choose a
   conservative category and mention the assumption.
3. If files are missing, create them from the repository template:
   - `SKILL.md`
   - `README.md`
   - `skill.json`
   - `tests/` when useful
4. Do not overwrite user-authored files unless the user explicitly asks for regeneration.
5. Update `catalog.json` with the compact fields: name, description, path, version.
6. Keep `catalog.json` sorted by name.

## Upsert From URL

When `nameOrUrl` is a URL:

1. Identify the source project name from the URL.
2. Derive a SkillVault skill name, such as `<project>-patterns`, unless the user gives a
   better name.
3. Read the source README or project homepage when available.
4. Create a curated SkillVault skill that summarizes reusable workflows and links back to
   the upstream source. Do not vendor large upstream docs.
5. Preserve the verified original `author` and record the SkillVault curator as `maintainer`.
   Use the verified version only for an actual matching upstream release; use explicit `null`
   for unversioned or rewritten guides. Keep catalog and manifest versions aligned. Unknown
   authorship or licensing is null, not an inferred attribution or permission grant.
   Record upstream repository, path, and license under `upstream`; `source` describes the
   actual SkillVault folder being installed. Disclose adaptations in the instructions.
   A reference-only entry must not claim upstream scripts, hooks, or packages are installed.
6. Update `catalog.json` with the compact fields and keep it sorted by name.

## Install After Upsert

After creating or updating the source skill:

1. Resolve the install scope from the `scope` argument.
2. If the scope is `default`, read `install.defaultScope` from the new skill's `skill.json`;
   if missing, use `project`.
3. For `global` or `project`, use the checkout's `scripts/install-skills.ps1` with the exact
   catalog name and resolved scope. Keep `-ProjectPath` bound to the user's working project,
   not the source cache. Preview existing target differences and use `-Force` only for
   approved replacements. The script stages files and writes install metadata using the
   SkillVault repository and catalog path, not an upstream reference URL.
4. For `session`, read the skill instructions and apply them only to the current request.
5. For `none`, skip installation.

## Validation

Use scripts or code when they make a repeated or error-prone task clearer, safer, or easier
to rerun. After every upsert, run:

```powershell
npm ci
.\scripts\validate-catalog.ps1
```

Run `npm ci` once per checkout to install development-only validation dependencies. For a
remote-only PR, validate proposed JSON/frontmatter with available tools and report that the
local repository checks were not run; rely on actual CI results, never claim unrun checks.
Report validation results before offering publish steps.

## Publishing

Publishing is separate from local upsert.

- If the user asks only to upsert, do not commit, push, or open a PR.
- If the user explicitly asks to publish, validate first, then use the repo's configured
   remote. For `wzlwit/skillvault`, push directly only when the current branch is intended for
   direct publish; otherwise create a PR.
- If no local SkillVault checkout exists, offer confirmed `clone` or `pr` choices. Never use an
   unrelated repository as the SkillVault source or publish to its configured remote.

## Safety

- Public SkillVault skills live under `skills/public/`.
- Keep generated catalog entries compact: name, description, path, version.
- Keep descriptions short.
- Do not write secrets into generated skill files.
- Do not commit or push unless the user explicitly asks.