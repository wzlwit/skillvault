---
name: rules
description: "Apply or manage AI working rules. Use /rules list, apply, add, update, or remove. The apply action replaces /rules-core and supplies compact coding guidance without editing files; persistent rule changes require confirmation."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|apply|add|update|remove] [<arguments>...]"
---

# Rules

Route by the first subcommand or an unambiguous natural-language request. No arguments or `list`
shows the compact rules and actions without changing files; `show`, `status`, and `help` are
read-only aliases, and `modify` aliases `update`. Unknown keywords show help and never approve a rule.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Load only this guidance |
| --- | --- |
| `apply` | [Core working rules](./references/core.md), applied to the current task without editing files |
| `list` | Read current rules and available actions |
| `add`, `update`, `remove` | [Rule management](./references/manage.md), with an authoritative target and confirmed edit |

- The old `/rules-core` command selects `apply`. The four core rules are maintained once in the
  bundled reference; load the [detailed reference](./references/ai-principles.md) only for clarification.
- Installation makes this skill available, not always-on instruction injection; for always-on rules,
  use the host's global or project instructions without duplicating conflicting rule documents.
  Harness coordinators pass core guidance and project instructions to workers, not the rule-editing
  workflow.
- Applying rules grants no tools, permissions, or new work.
- Grilling may propose a reusable rule, but never edits the authoritative rule document, overrides a
  security requirement, or substitutes for tests and independent review. Persistent changes use the
  confirmed management route.
- Lessons from completed work use the same
  [proposal checks](./references/manage.md#lessons-proposed-as-rules): verify cause and scope, test
  for overgeneralization, and keep the approval boundary. This adds no reflection hook and does not
  change the four rules applied to ordinary work.