# SkillVault

A single repository for public, shareable skills.

## Purpose

- `skills/public/` for open-source or shareable skills
- `skills/templates/` for skill scaffolds

Public skills use one category level, for example `skills/public/core/skillvault-install` or
`skills/public/system/schedule-manager`.

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
    "path": "skills/public/workflows/my-skill"
  },
  "install": {
    "global": true,
    "project": true,
    "session": true,
    "defaultScope": "project",
    "globalPath": "~/.copilot/skills",
    "strategy": "copy"
  }
}
```

`catalog.json` is a compact, name-sorted lookup index. Keep only `name`,
`description`, `path`, and `version` there. Derive display titles and grouping from the
skill folder or the skill's own `skill.json`.

Keep `version` present in both the catalog and manifest: use the declared version string,
or JSON `null` when no version is declared. `latest` describes the requested installation
policy, not a release version. Preserve original authorship on imports and disclose any
adaptation; access to a source repository does not establish redistribution rights.

Catalog entry example:

```json
{
  "name": "skillvault-list",
  "description": "List and uninstall global or project SkillVault skills by selector.",
  "path": "skills/public/core/skillvault-list",
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
| `grilling` | Trade-offs with `architecture-decision-records`; planning with `planning-with-files`. | Interview to test a plan and resolve choices. |
| `architecture-decision-records` | Trade-offs with `grilling`; decision notes with `planning-with-files`. | Preserve decision rationale, status, and superseded history. |
| `planning-with-files` | Planning with `grilling`; decision notes with `architecture-decision-records`. | Reference to upstream task tracking and recovery; this entry bundles no upstream workflow, hooks, scripts, or templates. |

`/sv-upsert` checks relevant counterpart instructions before recording overlap for either a
name or URL, preserves or corrects existing overlap notes on updates, and updates relevant
repository documentation. Partial overlap is not duplication or permission to remove a skill.
Existing design documents or task notes may already cover some of these roles.

## Selected Category Skills

These six additions are starting recommendations based on the upstream workflows and
licenses reviewed on 2026-09-14, not an objective worldwide ranking. Existing skills remain
in place. Each addition defaults to `project` scope so it can be tried independently.

| Category | Skill | Upstream | Why selected |
| --- | --- | --- | --- |
| `testing` | `webapp-testing` | [Anthropic](https://github.com/anthropics/skills/tree/main/skills/webapp-testing) | Focused Playwright workflow for browser behavior, distinct from UI design review. |
| `security` | `differential-review` | [Trail of Bits](https://github.com/trailofbits/skills/tree/main/plugins/differential-review/skills/differential-review) | Security review of changes against a baseline, with concrete evidence and coverage limits. |
| `api` | `openapi-spec-generation` | [wshobson/agents](https://github.com/wshobson/agents/tree/main/plugins/documentation-generation/skills/openapi-spec-generation) | Code-first or design-first REST contracts and validation without a full scaffolding framework. |
| `data` | `supabase-postgres-best-practices` | [Supabase](https://github.com/supabase/agent-skills/tree/main/skills/supabase-postgres-best-practices) | Maintainer guidance for Postgres queries, schema, connections, and RLS; not generic SQL or Power BI. |
| `github` | `github-issues` | [GitHub Awesome Copilot](https://github.com/github/awesome-copilot/tree/main/skills/github-issues) | Issue drafting and updates with existing GitHub tools; complements PR review tools. |
| `documentation` | `architecture-decision-records` | [wshobson/agents](https://github.com/wshobson/agents/tree/main/plugins/documentation-generation/skills/architecture-decision-records) | Preserves decision rationale and history beyond prose editing or task planning. |

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
an incompatible upstream folder. The existing `/sv-fresh` script targets global installs only;
these project copies are not scheduled for refresh, and no upstream dependency updates are
implied.

## Install or Upsert

- `/sv-install <skill-or-folder-or-keyword> [scope] [version]` installs existing catalog
  skills or updates their installed copies. It does not author source skills. Omit the
  target to browse the catalog; `/sv-install update` refreshes approved managed copies.
- `/sv-upsert <name-or-url> [scope]` edits an existing repository skill or creates one from
  scratch or a URL, updating its source files and catalog entry. A name does not automatically
  import an installed copy. It can install the result afterward; use scope `none` for source-only
  work. Publishing is separate and requires explicit approval.

Use **install** to update copies in your environment and **upsert** to change repository sources.
Installation after upsert is an optional follow-up. For example, `/sv-install planning-with-files project`
installs or updates that project copy; `/sv-upsert my-custom-skill none` authors a source skill.
The install skill's full name is `skillvault-install`; `/sv-install` and `/skv-install` are its
short triggers. Its name replaces the former generic `skillvault` installer.

## Global install

Repository URL: <https://github.com/wzlwit/skillvault>

Windows bootstrap installer URL: <https://github.com/wzlwit/skillvault/blob/main/scripts/install-global.ps1>

Clone the repository, then run the installer for your operating system. The installer only installs the bootstrap skills `/skillvault-install`, `/skillvault-evaluate`, `/skillvault-fresh`, `/skillvault-list`, `/skillvault-remove`, `/skillvault-search`, `/skillvault-uninstall`, `/skillvault-upsert`, `/rules`, `/rules-core`, and `/schedule-manager` globally. `/sv-fresh` is the short trigger for scheduled one-way refresh; `/skillvault-sync` and `/sv-sync` are compatibility aliases. Use `/sv-install <skill-or-folder-or-keyword> <scope> <version>` after that to install or update specific skills or keyword-matched sets. If you omit `<scope>`, `/sv-install` uses the skill's `install.defaultScope`; if that field is missing, it falls back to `project`. Use `session` to use a skill only in the current AI session without writing it globally or into the project. If you omit `<version>`, it defaults to `latest`; pinned versions use `v#.#.#`.

PowerShell installation uses the bundled file helper. Bash installation requires Node.js for
JSON metadata; neither installer runs skill workflows or changes Windows schedules. Existing
identical installs are skipped. Review differing or pinned copies before using `-Force`
(PowerShell) or `--force` (Bash). Files are staged before replacement and a failed swap retains
or restores the previous copy.

After installing the new name, bootstrap removes a managed legacy `skillvault` installation
only with `-Force` (`--force` in Bash), after review. Without that flag, the old folder remains
for review; unmanaged old-name folders are always preserved. Repository URLs and install
ownership markers remain `skillvault`; only the installer skill and its source path were renamed.

Windows PowerShell:

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

Or ask an AI coding agent:

> Install the SkillVault bootstrap skills globally using https://github.com/wzlwit/skillvault/blob/main/scripts/install-global.ps1. Clone or update its repository first, then run the installer from the local checkout. Do not install every catalog skill; after bootstrap I will use `/sv-install <skill-or-folder-or-keyword> <scope> <version>` to install or update specific skills, with omitted scope resolved from each skill's `install.defaultScope` and omitted version defaulting to `latest`. Use `/skillvault-evaluate <url-or-skillName> [location]` to assess purpose and value before deciding to upsert; without `location`, it checks installed skills, local catalogs, the official SkillVault repository, then external sources. Use `/sv-upsert <name-or-url> <scope>` to create or update local SkillVault source skills, not just install an existing one; if no local SkillVault checkout exists, it asks whether to clone one locally or create a remote pull request. Use `/rules <add|modify|remove> <rule> [location]` to propose and, after confirmation, update an authoritative AI-rules document; `/rules-core` is the compact four-rule guidance set. Use `/skillvault-fresh <intervalDay>` or `/sv-fresh <intervalDay>` to schedule one-way latest refreshes from recorded source repositories. Use `/skillvault-list` to list installed skills and `/skillvault-uninstall <selector>` to uninstall by index, range, list, keyword, or skill name after confirmation. Use `/schedule-manager` to list Windows scheduled tasks and enable, disable, or delete selected tasks by index, range, list, or keyword after confirmation.

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

Use `/sv-remove <skill-name[,skill-name...]> [repo-path]` to remove exact source skills and
their catalog entries after a preview and confirmation. The
[bundled removal script](skills/public/core/skillvault-remove/scripts/skillvault-remove.ps1)
requires an explicit `-RepoRoot` and previews unless `-Force` is supplied. It checks remaining
manifest dependencies and both bootstrap registrations, stages source folders before changing
the catalog, and preserves recoverable files on failure. Installed copies, other checkouts,
schedules, and remotes are unchanged. Use `/sv-uninstall` separately for installed copies.

`/sv-fresh` follows recorded Git sources for managed global `latest` installs only. It checks
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
.\scripts\verify-installed-skills.ps1 -SkillsPath "$HOME/.copilot/skills" -Name skillvault-install,skillvault-fresh
```

Parity checking is explicit: a customized or pinned install may legitimately differ from the
current checkout. Runtime dependencies and automated trigger behavior of upstream plugins
are not established by catalog validation.
