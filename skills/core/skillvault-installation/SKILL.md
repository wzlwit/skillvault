---
name: skillvault-installation
description: "[install|update|uninstall|clean|refresh] Manage installed SkillVault copies and keep them current. Shorthand: /sv-installation. List defaults to installed copies; list catalog inspects sources; clean finds skills that load twice or conflict and shows overlaps, which skillvault-discovery evaluate can judge. Refresh merges upstream changes into adapted skills when push is permitted, then brings new commits to the local checkout and managed global latest copies; scheduling delegates to harness-timer set refresh. Edits no SkillVault source or application code except refresh's adaptation merges; skillvault-authoring owns skill authoring."
metadata:
  author: wzlwit
  version: "3.0.0"
argument-hint: "[list|install|update|uninstall|clean|refresh] [<arguments>...]"
---

# Skill Installation

`/skillvault-installation` manages installed copies and keeps them current, not SkillVault sources or
application code; `/skillvault-authoring` owns authoring. `refresh` is the one exception: it merges
upstream changes into adapted skills in its own clone. `/sv-installation` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

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
| `clean` | [Find and fix skills that load twice or conflict, and show overlaps](./references/clean.md) |
| `refresh` | [Merge upstream changes into adaptations, then update the checkout and managed global latest copies](./references/refresh.md) |

Bare invocation, `list`, `status`, and `help` show the installed inventory and actions; `catalog`
aliases `list catalog`. Unknown actions show choices without copying or deleting files. If a token is
a catalog selector rather than an action, show the matches and the corrected `install <selector>`
command, not only an invalid-action error. Read-only help never implies install permission.

Selectors match name fragments before descriptions, so `install harness` selects every `harness-*`
skill, including the `harness-runtime` bundle; use `install --exact harness-project` for one skill. See [selector rules](./references/install.md#parameters).

## Boundaries

- Resolve the checkout with the bundled [source resolver](./scripts/resolve-source-repo.ps1) in
  Install mode; never use Upsert mode to bypass its known-or-explicit source rule.
- Preview matches, sibling dependencies, source paths, scopes, and targets before copying. Keep
  source and installation destinations separate.
- An adapted skill installs SkillVault's adaptation by default; `install <skill> origin` fetches
  the original instead. A renamed adaptation has no `origin` variant and must not be installed
  alongside its original. A reference fetches its original. See
  [upstream references](./references/install.md#upstream-references).
- Preserve unrelated, customized, and pinned copies. Deletion and forced replacement need explicit approval.
- Keep one installed copy per skill: before installing, check global and the current project, and
  ask whether to move a copy found in the other scope (see [target scope](./references/install.md#skillname-foldername-or-keyword-given-installupdate-mode)).
- `clean` changes nothing until the user picks findings. It fixes only copies SkillVault installed,
  through the existing steps, and never removes a skill only because it overlaps another.
- Compatibility-only bundles are excluded from default discovery and bulk installs; an ordinary
  refresh never replaces old installed copies with forwarders.
- Keep one current copy per canonical name through [transactional updates](./references/install.md#transactional-updates).
- `refresh` runs once with `-RunOnce`; the shared heartbeat runs the same
  [refresh script](./scripts/skill-refresh.ps1) for `/harness-timer set refresh`, which owns
  scheduling. Refresh commits merged adaptation updates only in its own clone and pushes them when
  permitted; it never pushes your own commits, commits in your checkout, or updates project copies.
  It preserves pins, unrelated installs, recorded sources, and failure isolation; dependency checks
  and rollback follow [runtime compatibility](./references/refresh.md#runtime-compatibility).

An explicitly requested topic-layout migration follows [topic-layout migration](./references/install.md#topic-layout-migration),
which also retires installed copies under former names.