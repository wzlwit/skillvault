---
name: harness-dev
description: "Run or queue tracked development, verification, and fixes. Use
  /harness-dev or /hn-dev with list, run, or queue. Overlaps with
  harness-task on intake, harness-test on validation, and harness-report on
  implementation; owns execution and independent review."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|run|queue] [<arguments>...]"
---

# Harness Development

`/harness-dev` runs and queues tracked development, verification, and fixes with independent review.
`/hn-dev` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Outcome |
| --- | --- |
| `list` | Show tasks, queue, and current execution |
| `run [<task>]` | Start when idle or queue when busy; `--now` requests a cooperative checkpoint |
| `queue <task>` | Queue only; map to `-Mode next`, never start a worker |

- Bare invocation, `list`, `status`, and `help` show tracked state and actions without selecting or
  running work. Queue selection without an ID applies only to an explicit `run`. Unknown subcommands
  show help.
- `run`, `queue`, or explicit task input follows the [development procedure](./references/workflow.md).
  Legacy `now` selects `run --now` (`-Mode now`) and `next` selects `queue`; queue-only input never
  becomes permission to execute.
- `/harness-task` owns task identity and intake; ad-hoc runs register through it first, and intake
  never becomes automatic pickup.
- Apply `/rules apply` and project instructions, then the runtime's Script Permissions and Agent
  Fallback, Runner Inheritance, and Reuse or New procedures. Preserve task identity, workspace,
  checks, budgets, and reviewer independence. Do not commit, publish, or change schedules.
- Keep required tests and independent review after development. Offer `/grilling` only when a
  consequential human choice remains; it is not another review pass or an automatic rule editor.
  An unattended worker reports questions and defers the dependent action; it does not interview
  itself or claim the choice was accepted.