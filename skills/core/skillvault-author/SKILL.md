---
name: skillvault-author
description: "[remove] Alone: the catalog. Text: create or change it. Author and maintain skill bundles and catalog entries in the SkillVault repository, not application source or installed copies. Shorthand: /sv-author. Overlaps with VS Code's agent-customization skill on writing SKILL.md files; use this one only for skills in the SkillVault repository and its catalog. Never installs; use skillvault-install to install the result."
metadata:
  author: wzlwit
  version: "4.0.0"
argument-hint: "[remove] [<what to create or change>]"
---

# SkillVault Author

This topic owns the **SkillVault repository's skill sources and catalog**, not an application's
source tree or installed copies.
`/sv-author` is chat shorthand for the same topic, not a separate skill or folder.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | Say what it would author when the conversation makes that clear, and ask first; otherwise show the source checkout's catalog and ask what to create or change |
| Text | [Create or change the named skill in the resolved source](./references/upsert.md) |
| `remove <skill>` | [Delete the source bundle and catalog entry after confirmation](./references/remove.md) |

- Alone never writes. When the conversation makes clear what to author, it says what it would
  author and asks to confirm first. Otherwise it shows the verified source checkout and its
  catalog: each skill's name, version, and kind (native, adapted, reference, or guide, from its
  manifest's `install.strategy` and `upstream` block), and asks what to create or change. No answer
  changes nothing.
- The alone view ends with one line naming the text uses: a skill name or URL with the change,
  "from this session" or "from <document>", and "in <checkout path>".
- Text says what to create or change and runs the [upsert procedure](./references/upsert.md). An
  existing name is edited; a new name is created only when confirmed absent from the verified
  catalog. An ambiguous or inaccessible target is not absent. A URL adds an external skill as a
  reference by default. When the text does not clearly say what to create or change, ask first.
- "from this session" builds from the current work through the
  [experience review](./references/upsert.md#improve-from-task-experience); "from <document>" uses
  [document-derived authoring](./references/upsert.md#author-from-documents). "in <checkout path>"
  selects another checkout, the resolver's explicit `-RepoPath`.
- `remove` deletes only source bundles and catalog entries; installed copies stay. Installed-copy
  removal belongs to `/skillvault-install uninstall`.
- Run the [read-only resolver](./scripts/resolve-source-repo.ps1) before writing and keep its verified
  selection order; never silently choose another checkout or change a Git remote.
- Show the **SkillVault repository** and **working project** separately; "in <checkout path>"
  selects only the first. Upsert has no installation target.
- Preserve public authorship, dependencies, and overlap descriptions; change a version only by the
  [version rules](./references/upsert.md#versions). Removal is previewed
  and confirmed. Authoring does not authorize commits, publishing, installation, or changes to
  unrelated repositories. Upsert never installs; afterward, give the
  `/skillvault-install <name>` command for the user to run if wanted.

The upsert procedure includes the [experience review](./references/upsert.md#improve-from-task-experience),
[document-derived authoring](./references/upsert.md#author-from-documents), and
[validation checks](./references/upsert.md#validation), chosen before editing. Task completion alone
never authorizes rewriting skills or rules.
