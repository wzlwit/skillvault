---
name: skillvault-authoring
description: "Author and maintain skill bundles and catalog entries in the SkillVault repository, not application source or installed copies. Use /skillvault-authoring or /sv-authoring list, upsert, or remove; create/update are upsert aliases. Accepts legacy /skillvault-source, /sv-source, skillvault-upsert, skillvault-remove and their shortcuts. Can install afterward through skillvault-installation with separate target and approval."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|upsert|remove] [<arguments>...]"
---

# SkillVault Authoring

The registered command is `/skillvault-authoring`. `/sv-authoring` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

This topic owns the **SkillVault repository's skill sources and catalog**, not an application's
source tree. Bare invocation or `list` shows the selected SkillVault source and actions
without writing. Unknown actions show help rather than treating them as new skill names.
`status` and `help` remain read-only aliases.

| Action | Procedure |
| --- | --- |
| `list` | Read the selected repository's catalog and show authoring actions |
| `upsert` | [Create or edit the resolved source skill](./references/upsert.md) |
| `remove` | [Confirmed source removal](./references/remove.md) |

`create` and `update` are compatibility aliases for `upsert`, not existence requirements.
Resolve the target in the verified catalog: edit it when present and create it when confirmed
absent. An ambiguous or inaccessible target is not absent; resolve that uncertainty first.
`/skillvault-source` and `/sv-source` route to this topic with the same action and arguments.
Legacy upsert requests use `upsert`; old remove requests retain exact-source removal, including
their `/sv-*` and `/skv-*` spellings. These are text routes, not duplicate registered bundles.
Installed-copy removal belongs to `/skillvault-installation uninstall`.
Use the [read-only resolver](./scripts/resolve-source-repo.ps1) before writing. Preserve its
verified source-selection order; a working project is eligible only if it is the intended
verified SkillVault checkout. Do not silently choose another checkout or change a Git remote.

Show **SkillVault repository**, **working project**, and any **installation target** separately.
`--repo` selects the first, never the other two. Preserve public authorship, versions, dependencies,
and overlap descriptions. Removal is previewed and confirmed. Authoring does not authorize
commits, publishing, installation, or changes to any unrelated source repository.