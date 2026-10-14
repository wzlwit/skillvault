---
name: skillvault-install
description: "[list|update|uninstall|clean|refresh] Alone: the catalog. Text: install it. Manage installed SkillVault copies and keep them current: install by exact name or a * pattern, list installed copies, update them from the local checkout, uninstall, clean up copies that load twice or conflict, and refresh from upstream. Shorthand: /sv-install. Clean shows overlaps, which skillvault-discover can evaluate; refresh scheduling delegates to harness-schedule. Edits no SkillVault source or application code except refresh's adaptation merges; skillvault-author owns skill authoring."
metadata:
  author: wzlwit
  version: "4.0.0"
argument-hint: "[list|update|uninstall|clean|refresh] [<skill or pattern*>]"
---

# SkillVault Install

`/skillvault-install` manages installed copies and keeps them current, not SkillVault sources or
application code; `/skillvault-author` owns authoring. `refresh` is the one exception: it merges
upstream changes into adapted skills in its own clone.
`/sv-install` is chat shorthand for the same topic, not a separate skill or folder.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | [Show the verified catalog with each skill's state here](./references/install.md#no-skillname-given-catalog-exploration), and offer to update managed copies that are behind |
| Text | [Install what a skill name or `*` pattern selects](./references/install.md#skillname-or-pattern-given-installupdate-mode) |
| `list` | [Show installed copies everywhere, numbered for uninstall](./references/list.md) |
| `update` | [Bring every managed copy, global and in this project, up to the local checkout](./references/install.md#skillvault-install-update-explicit-installed-copy-refresh) |
| `uninstall <number, name, or pattern>` | [Remove the selected installed copies after confirmation](./references/uninstall.md) |
| `clean` | [Find and fix skills that load twice or conflict, and show overlaps](./references/clean.md) |
| `refresh` | [Merge upstream changes into adaptations, then update the checkout and managed global latest copies](./references/refresh.md) |

- Alone shows the verified catalog: each skill's name, version, and description, and its state here:
  not installed, global, or this project, with the installed version, whether it is pinned, and
  whether it is behind the checkout. It copies nothing. When managed `latest` copies are behind, it
  offers to update them, asking once; no answer changes nothing. Showing the catalog never implies
  install permission.
- The alone view ends with one line naming the text uses: a skill name installs it, and a pattern
  such as `harness*` shows its matches first.
- Text is a selector, then optional plain words. A name without `*` matches one skill exactly,
  ignoring case, and installs that skill and its required companions at once after the usual
  preview; replacing an existing or customized copy keeps its own approval. `name*`, `*name`,
  `*name*`, or `*` shows the matches and asks once. No exact match installs nothing and suggests
  skills that mention it, so `harness` selects nothing while `harness*` selects every `harness-*`
  skill, including the `harness-runtime` bundle. See [selector rules](./references/install.md#parameters).
- Plain words after the selector: `global`, `project`, or `session` for the scope; `origin` for the
  original of an adapted skill; a version `vX.Y.Z` to pin it; and "from <path>" for an explicit
  source checkout. The selector maps to the checkout installer's `-Select <selector> -Preview`, the
  checkout to the resolver's `-RepoPath`, `origin` to `-Variant origin`, and a version to
  `-RequestedVersion`.

## Boundaries

- Resolve the checkout with the bundled [source resolver](./scripts/resolve-source-repo.ps1) in
  Install mode; never use Upsert mode to bypass its known-or-explicit source rule.
- Preview matches, sibling dependencies, source paths, scopes, and targets before copying. Keep
  source and installation destinations separate.
- An adapted skill installs SkillVault's adaptation by default; `origin` after its name fetches
  the original instead. A renamed adaptation has no `origin` variant and must not be installed
  alongside its original. A reference fetches its original. See
  [upstream references](./references/install.md#upstream-references).
- Preserve unrelated, customized, and pinned copies. Deletion and forced replacement need explicit approval.
- Keep one installed copy per skill: before installing, check global and the current project, and
  ask whether to move a copy found in the other scope (see [target scope](./references/install.md#skillname-or-pattern-given-installupdate-mode)).
- `clean` changes nothing until the user picks findings. It fixes only copies SkillVault installed,
  through the existing steps, and never removes a skill only because it overlaps another.
- Compatibility-only bundles are excluded from default discovery and bulk installs; an ordinary
  refresh never replaces old installed copies with forwarders.
- Keep one current copy per canonical name through [transactional updates](./references/install.md#transactional-updates).
- `refresh` runs once with `-RunOnce`; the shared heartbeat runs the same
  [refresh script](./scripts/skill-refresh.ps1) for `/harness-schedule refresh <duration>`, which owns
  scheduling. Refresh commits merged adaptation updates only in its own clone and pushes them when
  permitted; it never pushes your own commits, commits in your checkout, or updates project copies.
  It preserves pins, unrelated installs, recorded sources, and failure isolation; dependency checks
  and rollback follow [runtime compatibility](./references/refresh.md#runtime-compatibility).

An explicitly requested topic-layout migration follows [topic-layout migration](./references/install.md#topic-layout-migration),
which also retires installed copies under former names.
