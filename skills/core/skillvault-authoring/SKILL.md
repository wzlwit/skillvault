---
name: skillvault-authoring
description: "Author and maintain skill bundles and catalog entries in the SkillVault repository, not application source or installed copies. Use /skillvault-authoring or /sv-authoring list, upsert, or remove; create/update are upsert aliases. Accepts legacy /skillvault-source, /sv-source, skillvault-upsert, skillvault-remove and their shortcuts. Overlaps with VS Code's agent-customization skill on writing SKILL.md files; use this one only for skills in the SkillVault repository and its catalog. Never installs; use skillvault-installation to install the result."
metadata:
  author: wzlwit
  version: "2.0.0"
argument-hint: "[list|upsert|remove] [<arguments>...]"
---

# SkillVault Authoring

This topic owns the **SkillVault repository's skill sources and catalog**, not an application's
source tree or installed copies.
`/sv-authoring` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Procedure |
| --- | --- |
| `list` | Read the selected repository's catalog and show authoring actions |
| `upsert` | [Create or edit the resolved source skill](./references/upsert.md) |
| `remove` | [Confirmed source removal](./references/remove.md) |

- Bare invocation, `list`, `status`, and `help` show the selected source and actions without writing.
  Unknown actions show help and are never treated as new skill names.
- `create` and `update` alias `upsert`: edit a target present in the verified catalog and create it
  only when confirmed absent. An ambiguous or inaccessible target is not absent.
- `/skillvault-source`, `/sv-source`, and legacy upsert/remove spellings, including `/sv-*` and
  `/skv-*`, route here as text, not duplicate bundles. Installed-copy removal belongs to
  `/skillvault-installation uninstall`.
- Run the [read-only resolver](./scripts/resolve-source-repo.ps1) before writing and keep its verified
  selection order; never silently choose another checkout or change a Git remote.
- Show the **SkillVault repository** and **working project** separately; `--repo` selects only the
  first. Upsert has no installation target.
- Preserve public authorship, dependencies, and overlap descriptions; change a version only by the
  [version rules](./references/upsert.md#versions). Removal is previewed
  and confirmed. Authoring does not authorize commits, publishing, installation, or changes to
  unrelated repositories. Upsert never installs; afterward, give the
  `/skillvault-installation install <name>` command for the user to run if wanted.

`upsert` includes the [experience review](./references/upsert.md#improve-from-task-experience),
[document-derived authoring](./references/upsert.md#author-from-documents), and
[validation checks](./references/upsert.md#validation), chosen before editing. Task completion alone
never authorizes rewriting skills or rules.