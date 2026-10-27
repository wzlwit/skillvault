---
name: rules
description: "[apply|remove] Alone: rules in effect. Text: add or change a rule. Put the core and extra rules, or only the core rules with apply core, into effect globally (default), in a project, or for this chat; add, change, or remove your own global or project rules. The SkillVault rule library changes only when you name extra or core, and persistent rule changes require confirmation."
metadata:
  author: wzlwit
  version: "4.3.0"
argument-hint: "[apply|remove] [<rule>]"
---

# Rules

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | Show the core and extra rules and where they are in effect, from the read-only [always-on helper](./scripts/always-on.ps1) check, and offer to apply them when the global copy is missing or out of date |
| Text | [Add or change a rule](./references/manage.md): your own, `global` (default) or `project`; the SkillVault library only when you say `extra` or `core`; shown and confirmed first |
| `apply [core] [global\|project\|session]` | Put the [core rules](./references/core.md) and [extra rules](./references/extra.md), or only the core rules with `core`, into effect: `global` (default), `project`, or `session` |
| `remove <rule>` | [Remove a rule](./references/manage.md) after showing it and confirming |

- Alone shows the core and extra rules and runs the [always-on helper](./scripts/always-on.ps1)
  without `-Apply` for `global` and the current project, which reports Missing, Unmanaged, InSync,
  or Drifted for each. It changes no files. When the global copy is Missing, Unmanaged, or Drifted,
  it offers to apply it, asking once; no answer changes nothing.
- The alone view ends with one line naming the text uses: type a rule in plain words to add or
  change your own rule, and say `project` for this repository's instructions, or `extra` or `core`
  for the SkillVault library.
- Text is a rule in plain words, such as "always run the focused test first". It adds or changes
  your own rule: the private global Personal rules by default, or this repository's instructions
  when it says `project`. Naming `extra` or `core` changes the SkillVault library. Every change
  follows the [confirmed edit procedure](./references/manage.md#confirmed-edit-procedure): shown
  first and applied only after confirmation. Text that is not clearly a rule asks what to do and
  never approves a rule.
- **The library** is the core rules in [core.md](./references/core.md) and the extra rules in
  [extra.md](./references/extra.md), one bullet each, in the public SkillVault repository; load the
  [detailed reference](./references/ai-principles.md) only for clarification. Text, `apply`, and
  `remove` never change the library unless the user names `extra` or `core`.
- **Scopes.** `global` is a generated block at the top of `~/.copilot/copilot-instructions.md`, which
  Copilot Agent Host and CLI sessions load in every chat on this machine; the private Personal rules
  section follows it. `project` is the same block at the top of the current project's
  `.github/copilot-instructions.md`, followed by its Project rules; that file is usually committed and
  shared with the team. `session` applies the rules to the current chat without editing files.
- **Applying.** For `global` or `project`, run the [always-on helper](./scripts/always-on.ps1) with
  `-Scope`, `-Set all` or `-Set core`, and `-Apply`, then report the target, set, and status. An
  explicit `/rules apply` approves rewriting that generated block, which records its set so later
  repairs keep it; nothing outside the block changes. Without `-Apply` the helper only reports
  Missing, Unmanaged, InSync, or Drifted. Never hand-edit the block; installing the skill writes
  nothing by itself.
- **Other skills.** When another skill says to apply `/rules apply`, it means `session`: follow the
  core and extra rules in that work. It never writes files. Harness coordinators still pass core
  guidance and project instructions to workers, not the rule-editing workflow.
- **Enforceable limits belong to policy.** A rule the harness can enforce, such as allowed models,
  time or credit caps, reviewer concurrency, test retries, failure thresholds, or pauses, goes to
  `/hn-setup policy set limits` or `set fallback` with its matching field. Add a written rule only
  if the user still wants one; a written rule never enforces anything.
- Applying rules grants no tools, permissions, or new work.
- Grilling may propose a reusable rule, but never edits the authoritative rule document, overrides a
  security requirement, or substitutes for tests and independent review. Persistent changes use the
  confirmed management route.
- Lessons from completed work use the same
  [proposal checks](./references/manage.md#lessons-proposed-as-rules): verify cause and scope, test
  for overgeneralization, and keep the approval boundary. This adds no reflection hook and does not
  change the core rules applied to ordinary work.
