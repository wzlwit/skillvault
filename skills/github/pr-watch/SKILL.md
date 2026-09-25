---
name: pr-watch
description: "Manage the single user-wide PR review watchlist. Use /pr-watch list, add, or remove; replaces /pr-review-add, /pr-review-list, and /pr-review-remove. Watchlist changes do not run reviews or change schedules; pr-review owns execution and harness-timer owns its logical schedule."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|add|remove] [<arguments>...]"
---

# PR Watchlist

Bare invocation or `list` reads the user-wide watchlist. `help` or an unknown action shows
choices without writing. Resolve explicit actions through only the selected procedure:

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

| Action | Procedure |
| --- | --- |
| `list` | [List watched targets](./references/list.md) |
| `add` | [Add an exact PR or repository](./references/add.md) |
| `remove` | [Confirm removal of an exact watch entry](./references/remove.md) |

Old pr-review-add/list/remove commands select the corresponding operation. Use the `pr-review`
runtime and its existing user-wide controller, never the working project's source or a new
project-local list. Applying `/rules apply` and project instructions does not authorize a
provider call, review, timer, or publication. Preserve IDs, explicit filters, reports, and
removal confirmations. Review execution belongs to `/pr-review run`; schedules to `/harness-timer pr`.