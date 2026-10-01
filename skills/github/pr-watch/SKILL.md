---
name: pr-watch
description: "Manage the single user-wide PR review watchlist. Use /pr-watch list, add, or remove; replaces /pr-review-add, /pr-review-list, and /pr-review-remove. Watchlist changes do not run reviews or change schedules; pr-review owns execution and review results, and harness-timer owns its logical schedule."
metadata:
  author: wzlwit
  version: "1.1.0"
argument-hint: "[list|add|remove] [<arguments>...]"
---

# PR Watchlist

`/pr-watch` manages the single user-wide PR review watchlist. Watch changes never run reviews or
change schedules.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Procedure |
| --- | --- |
| `list` | [List watched targets](./references/list.md) |
| `add` | [Add an exact PR or repository](./references/add.md) |
| `remove` | [Confirm removal of an exact watch entry](./references/remove.md) |

- Bare invocation or `list` reads watched targets and their filters; review results, including
  ad-hoc and in-progress reviews, belong to `/pr-review list`. `help` or an unknown action shows
  choices without writing. Old pr-review-add/list/remove commands select the matching operation.
- Use the `pr-review` runtime and its existing user-wide controller, never the working project's
  source or a new project-local list. Preserve IDs, explicit filters, reports, and removal confirmations.
- Applying `/rules apply` and project instructions authorizes no provider call, review, timer, or
  publication. Review execution belongs to `/pr-review run`; schedules to `/harness-timer pr`.