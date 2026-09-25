---
name: skillvault-installation
description: "Manage installed SkillVault copies. Use /skillvault-installation or /sv-installation list, install, update, or uninstall. Replaces skillvault-install, skillvault-list, skillvault-uninstall and /sv-install, /sv-list, /sv-uninstall. List defaults to installed copies; list catalog inspects sources. Does not edit SkillVault source or application code; skillvault-authoring owns skill authoring."
metadata:
  author: wzlwit
  version: "1.1.0"
argument-hint: "[list|install|update|uninstall] [<arguments>...]"
---

# Skill Installation

The registered command is `/skillvault-installation`. `/sv-installation` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

Bare invocation or `list` shows the installed inventory. `help` or an unknown action shows
choices without copying or deleting files. Keep source and installation destinations separate.

| Action | Procedure |
| --- | --- |
| `list` | [Installed inventory](./references/list.md) |
| `list catalog` | [Verified source catalog](./references/install.md#no-skillname-given-catalog-exploration) |
| `install`, `update` | [Install or update copies](./references/install.md) |
| `uninstall` | [Confirmed removal of installed copies](./references/uninstall.md) |

Legacy `/sv-install`, `/sv-list`, `/sv-uninstall`, their full names, and `/skv-*` equivalents
retain their operation. A bare old install request explores the catalog; `update` remains an
explicit installed-copy refresh. No operation edits application code or authors skill sources.
`catalog` aliases `list catalog`; `status` and `help` retain the read-only inventory/actions view.

Resolve a SkillVault checkout using the bundled [source resolver](./scripts/resolve-source-repo.ps1)
in Install mode. Do not use Upsert mode to bypass its known-or-explicit source rule. Show exact
catalog matches, required sibling skill dependencies, source paths, scopes, and target paths
before an approved install. Compatibility-only bundles are not default discovery or bulk-install
candidates; do not replace old installed copies with forwarders during an ordinary refresh.
Preserve pins and customized copies; deletion and forced replacement require explicit approval.

For an explicitly requested topic-layout migration, `update --topics` uses the bundled
[migration helper](./scripts/migrate-topics.ps1). Preview the exact current-project/global targets,
canonical mappings, same-scope dependencies, and retired names. Apply with `-Apply -Force` only
after approval; verified successful migration discards temporary originals. It never changes schedules or other projects.
Use `-Name <canonical-names>` to limit a migration to selected installed topics and their required
siblings; already identical copies are left unchanged. Former `sv-*` installed names map to the
full `skillvault-*` registrations, while their short spellings remain conversational routes.
The former `skillvault-source` and `sv-source` bundles map to `skillvault-authoring`; selecting
that canonical name previews their replacement without refreshing unrelated topics.

Keep installed copies at their approved canonical names and current source contents. Explicit
updates can replace stale managed copies or retire verified old names after their replacements
validate; preserve unrelated, customized, and pinned copies. The [transactional update procedure](./references/install.md#transactional-updates)
uses temporary originals only while work is in progress. Successful updates retain no backup
archive or recovery directory. Existing obsolete-file deletion remains explicitly scoped.