---
name: rules
description: "[apply|remove] Alone: every rule. Text: add or change a rule. Apply the core and extra rules, one rule, or your own words to this chat; apply core writes the core rules into the global instructions and apply extra the extra rules into the project's; add, change, or remove your own global or project rules. The SkillVault rule library changes only when you name extra or core, and persistent rule changes require confirmation."
metadata:
  author: wzlwit
  version: "6.0.0"
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
| Alone | List every rule, numbered: the core and extra rules, then your Personal rules and this project's rules, with where the rules are in effect from the read-only [always-on helper](./scripts/always-on.ps1) check; offer to repair the global copy when it is missing or out of date |
| Text | [Add or change a rule](./references/manage.md): your own, `global` (default) or `project`; the SkillVault library only when you say `extra` or `core`; shown and confirmed first |
| `apply [core\|extra\|<number or name>\|<your words>] [global\|project\|session]` | Follow the core and extra rules, one rule from the list, or your own words in this chat (`session`, the default); `core` writes the [core rules](./references/core.md) into the global instructions and `extra` the [extra rules](./references/extra.md) into this project's, and a named scope overrides either default |
| `remove <rule>` | [Remove a rule](./references/manage.md) after showing it and confirming |

- Alone lists every rule with one running number: the core rules, the extra rules, your Personal
  rules from the global file, and this project's rules from the Project rules section of its
  `.github/copilot-instructions.md` when it has one, each set under its own heading. It runs the
  [always-on helper](./scripts/always-on.ps1) without `-Apply` for `global` and the current project,
  which reports Missing, Unmanaged, InSync, or Drifted and the set each block holds, and changes no
  files. When the global copy is Drifted, it offers to rewrite it with the set it holds; when it is
  Missing or Unmanaged, it offers `apply core`. It asks once; no answer changes nothing.
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
  [detailed reference](./references/ai-principles.md) only for clarification. Text and `remove`
  never change the library unless the user names `extra` or `core`; after `apply`, those words only
  select the rules to apply.
- **Scopes.** `global` is a generated block at the top of `~/.copilot/copilot-instructions.md`, which
  Copilot Agent Host and CLI sessions load in every chat on this machine; the private Personal rules
  section follows it. `project` is a generated block at the top of the current project's
  `.github/copilot-instructions.md`, followed by its Project rules; that file is usually committed and
  shared with the team. `session` applies rules to the current chat without editing files; it is the
  default for `apply`, except that `apply core` defaults to `global` and `apply extra` to `project`.
- **Applying in this chat.** `apply` alone follows the core and extra rules for the rest of this
  chat. `apply` with one rule follows it, by its number from the alone list or by words that clearly
  name it, and `apply` with your own words follows them. Words that could name several rules show
  them and apply nothing. Your own words are followed in this chat only and saved nowhere; type them
  after `/rules` to keep them. `apply core session` or `apply extra session` follows only that set
  here. Report what now applies: the set, or the rule's text.
- **Writing files.** `apply core` writes the core rules into the global instructions, and
  `apply extra` writes the extra rules into this project's, so a chat in that project gets each rule
  once; `apply global` or `apply project` writes both sets there, and a named scope overrides either
  default. Run the [always-on helper](./scripts/always-on.ps1) with `-Scope`, `-Set core`,
  `-Set extra`, or `-Set all`, and `-Apply`, then report the target, set, and status. A file's block
  holds exactly what was last applied there: check its set first, and when the new set leaves rules
  out, such as `apply core` on a global block that held all the rules, say which rules leave it. One
  rule or your own words with `global` or `project` go through the text route instead: shown,
  confirmed, then saved in your Personal rules or the project's rules. An explicit `apply` to a file
  approves rewriting its generated block, which records its set so later repairs keep it; nothing
  outside the block changes. Without `-Apply` the helper only reports Missing, Unmanaged, InSync, or
  Drifted. Never hand-edit the block; installing the skill writes nothing by itself.
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
