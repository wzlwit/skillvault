
# SkillVault Upsert

This skill creates or edits skill source files and their catalog entries in the selected
SkillVault repository. It can edit an existing repository skill, create a new one from scratch,
or derive one from a URL. It can install the result afterward using the requested or
manifest-defined scope. Publishing by push or PR requires an explicit request.

Use `/skillvault-installation install` when you only want to install or update an existing catalog skill in your
environment. Use `/skillvault-authoring upsert` when you want to create or edit its repository source. Installation
after upsert is an optional follow-up step, not its primary purpose.

The `create` and `update` action aliases use this same procedure. Determine existence from the
verified source, not from the chosen spelling. An inaccessible or ambiguous target does not
authorize creating a replacement; resolve the target before editing or creating files.

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
- `--repo <path>` - optional explicit SkillVault source checkout. Resolve relative paths against
  the original working project. Invalid paths or repository identities block the upsert; do not
  silently choose another source. This does not change the installation scope or working project.
- `publish` — optional later keyword. If present, validate first, then push directly or open
   a PR to `wzlwit/skillvault` using the current repo state and branch policy. If absent, do
   not commit, push, or open a PR.

## Source Repository Resolution

Keep the original working project separate from the source checkout throughout this workflow.
Before any source edits, run the bundled [read-only resolver](../scripts/resolve-source-repo.ps1)
with PowerShell 5.1+ or PowerShell 7 and Git:

```powershell
& <upsert-skill-folder>/scripts/resolve-source-repo.ps1 -ProjectPath <working-project-root>
```

Keep the declared `skillvault-installation` dependency beside this bundle. The local resolver delegates
verification to that sibling's shared helper in Upsert mode, preserving the selection order below;
the installer itself uses a stricter known-or-explicit checkout rule with no automatic cache fallback.

Map conversational `--repo <path>` to the helper's `-RepoPath <path>`. Selection order is:

1. An explicitly supplied source checkout, which must pass verification.
2. The current working project, only if it is a verified SkillVault checkout root.
3. The known Windows checkout `C:\repos\skillvault`, when present. A different known checkout
   can be explicitly supplied through `--repo`; do not scan unrelated repositories for one.
4. The existing source cache `~/.copilot/skillvault-src` when the known checkout is absent.

Verification requires `catalog.json`, `skills/`, an exact Git checkout root, and one
`origin` fetch URL identifying `github.com/wzlwit/skillvault` (standard HTTPS or SSH form).
A folder name or matching layout alone is insufficient. A lookalike working project is skipped;
an invalid explicit, known, or cache checkout is a blocker, not permission to use another path.
Do not retarget remotes or weaken verification to make a candidate pass. Dirty source work is
allowed and preserved; the resolver never fetches, clones, resets, writes, or publishes.

Accept only `Status: Resolved`. Use its `RepoRoot`, `CatalogPath`, and `SkillsPath` for source
authoring, never the original working project's similarly named paths or an installed skill copy.
For an existing skill, use its catalog path within that source tree; for a new skill, choose a
contained `skills/<category>/<name>` destination. Before writing, show the resolved source
root, catalog, exact skill folder, and any separate installation destination. Re-resolve if the
selected source changes. A verified existing destination needs no extra approval beyond the upsert
request; an explicit mismatch must be resolved by the user.

`Status: NeedsSource` means no source was selected and no source files may be written. Ask for an
explicit local checkout, or present these separately confirmed choices:

- `clone`: clone `https://github.com/wzlwit/skillvault.git` into the source cache, then rerun
  the resolver with that explicit path before authoring. Do not create SkillVault source files
  in the unrelated working project or overwrite a conflicting cache.
- `pr`: prepare the SkillVault entry directly for a new remote branch and pull request.

For `pr`, use authenticated GitHub tools to read the current remote catalog and target
branch, then prepare the skill files and catalog update without writing remotely. Present
the proposed files and wait for confirmation before creating the remote branch or PR.
After confirmation, commit the approved changes on the new remote branch and open the PR.
Do not commit, push, or open a PR unless the user explicitly selects `pr` or otherwise explicitly
asks for publishing. Resolver failure or unavailable Git/PowerShell is a blocker; report it
rather than falling back to unverified source authoring.

## Check Overlap

For both name-based and URL-based upserts, before writing skill files:

1. Use the selected catalog and `/skillvault-installation list` inventory to locate likely counterparts,
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
2. Create or update `skills/<category>/<skill-name>/`. Use an existing category when
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
   catalog name, resolved scope, and `-RepoRoot <resolved-source-root>`. Keep `-ProjectPath` bound
   to the original working project, not the source checkout. Preview existing target differences
   and use `-Force` only for approved replacements. The script stages files and writes install metadata using the
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
   remote after checking its actual push destination identifies the approved SkillVault repository;
   a verified fetch origin alone is not a publishing check. Push directly only when the current
   branch is intended for direct publish; otherwise create a PR.
- If no local SkillVault checkout exists, offer confirmed `clone` or `pr` choices. Never use an
   unrelated repository as the SkillVault source or publish to its configured remote.

## Safety

- Public SkillVault skills live under `skills/`.
- Keep generated catalog entries compact: name, description, path, version.
- Keep descriptions short.
- Do not write secrets into generated skill files.
- Do not commit or push unless the user explicitly asks.