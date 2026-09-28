---
name: skillvault-installation
description: "Manage installed SkillVault copies. Use /skillvault-installation or /sv-installation list, install, update, or uninstall. Replaces skillvault-install, skillvault-list, skillvault-uninstall and /sv-install, /sv-list, /sv-uninstall. List defaults to installed copies; list catalog inspects sources. Does not edit SkillVault source or application code; skillvault-authoring owns skill authoring."
metadata:
  author: wzlwit
  version: "1.1.0"
argument-hint: "[list|install|update|uninstall] [<arguments>...]"
---

# Skill Installation

`/skillvault-installation` manages installed copies, not SkillVault sources or application code;
`/skillvault-authoring` owns authoring. `/sv-installation` is conversational shorthand for the same
topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Procedure |
| --- | --- |
| `list` | [Installed inventory](./references/list.md) |
| `list catalog` | [Verified source catalog](./references/install.md#no-skillname-given-catalog-exploration) |
| `install`, `update` | [Install or update copies](./references/install.md) |
| `uninstall` | [Confirmed removal of installed copies](./references/uninstall.md) |

Bare invocation, `list`, `status`, and `help` show the installed inventory and actions; `catalog`
aliases `list catalog`. Unknown actions show choices without copying or deleting files. If a token is
a catalog selector rather than an action, show the matches and the corrected `install <selector>`
command, not only an invalid-action error. Read-only help never implies install permission.

## Selection

Selectors match case-insensitive name fragments first, then descriptions and catalog paths only when
no names match. An exact name does not narrow a larger match set: `install harness` selects `harness`
and every `harness-*` topic. Use `install --exact harness` for the base skill, or `install harness-`
for suffixed topics; patterns such as `harness*` are optional. Preview all matches and required
companions before copying, preserving replacement, pin, and scope approvals.

## Source and Safety

- Resolve the checkout with the bundled [source resolver](./scripts/resolve-source-repo.ps1) in
  Install mode; never use Upsert mode to bypass its known-or-explicit source rule.
- Before an approved install, show exact catalog matches, sibling dependencies, source paths,
  scopes, and target paths. Keep source and installation destinations separate.
- Compatibility-only bundles are excluded from default discovery and bulk installs; an ordinary
  refresh never replaces old installed copies with forwarders.
- Keep installed copies at approved canonical names and current source contents. Explicit updates
  may replace stale managed copies, or retire verified old names after their replacements validate.
- Preserve unrelated, customized, and pinned copies. Deletion and forced replacement need explicit
  approval; obsolete-file deletion stays explicitly scoped.
- The [transactional update procedure](./references/install.md#transactional-updates) keeps
  temporary originals only during work; successful updates retain no backup archive or recovery directory.

## Legacy Routes and Topic Migration

Legacy `/sv-install`, `/sv-list`, `/sv-uninstall`, their full names, and `/skv-*` equivalents keep
their operations: a bare old install request explores the catalog, and `update` stays an explicit
installed-copy refresh.

For an explicitly requested topic-layout migration, `update --topics` uses the bundled
[migration helper](./scripts/migrate-topics.ps1). Preview exact current-project/global targets,
canonical mappings, same-scope dependencies, and retired names; apply with `-Apply -Force` only after
approval. `-Name <canonical-names>` limits it to selected topics and required siblings, leaving
identical copies unchanged. Former `sv-*` names map to full `skillvault-*` registrations, while their
short spellings stay conversational. Former `skillvault-source` and `sv-source` bundles map to
`skillvault-authoring` without refreshing unrelated topics. Successful migration discards temporary
originals and changes no schedules or other projects.