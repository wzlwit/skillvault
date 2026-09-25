---
name: rules
description: "Apply or manage AI working rules. Use /rules list, apply, add, update, or remove. The apply action replaces /rules-core and supplies compact coding guidance without editing files; persistent rule changes require confirmation."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|apply|add|update|remove] [<arguments>...]"
---

# Rules

Route by the first subcommand or an unambiguous natural-language request. No arguments,
or `list` displays the compact rules and available actions without changing files.
Unknown keywords show help; never interpret one as approval to add a rule.
`show`, `status`, and `help` are read-only aliases; `modify` aliases `update`.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

| Action | Load only this guidance |
| --- | --- |
| `apply` | [Core working rules](./references/core.md), applied to the current task without editing files |
| `list` | Read current rules and available actions |
| `add`, `update`, `remove` | [Rule management](./references/manage.md), with an authoritative target and confirmed edit |

The old `/rules-core` command selects `apply`. Keep the four core rules maintained once in
the bundled reference; load the [detailed reference](./references/ai-principles.md) only for
clarification. Installation makes this skill available, not always-on instruction injection.
Harness coordinators explicitly supply the core guidance and project instructions to workers,
not the rule-editing workflow. Applying rules does not grant tools, permissions, or new work.

Grilling resolves human decisions and may propose a reusable rule. It never automatically
edits the authoritative rule document, overrides a security requirement, or substitutes for
tests and independent review. Persistent changes still use the confirmed management route.