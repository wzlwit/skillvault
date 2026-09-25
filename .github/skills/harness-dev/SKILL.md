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

The registered command is `/harness-dev`. `/hn-dev` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

Bare `/harness-dev` or `list` shows tracked state and actions without selecting or running
work. `run`, `queue`, or explicit task input selects the
[development procedure](./references/workflow.md). Its no-ID queue selection applies only to
an explicit run, never a bare topic, including the `/hn-dev` shorthand. Unknown subcommands show help.

| Action | Outcome |
| --- | --- |
| `list` | Show tasks, queue, and current execution |
| `run [<task>]` | Start when idle or queue when busy; `--now` requests a cooperative checkpoint |
| `queue <task>` | Queue only; map to `-Mode next`, never start a worker |

Execution and queueing belong here; task identity, intake, and field updates belong to
`/harness-task`. An ad-hoc run registers its input through the shared task intake before
execution. Neither topic duplicates the other's records or turns intake into automatic pickup.

Compatibility: `status`/`help` select `list`; `now` selects `run --now` (`-Mode now`);
`next` selects `queue`. Do not reinterpret old queue-only input as permission to execute.

Apply `/rules apply` and project instructions, then the runtime's Script Permissions and Agent
Fallback, Runner Inheritance, and Reuse or New procedures. Preserve task identity, workspace,
checks, budgets, and reviewer independence. Do not commit, publish, or change schedules.

After development, retain required tests and independent review. Offer `/grilling` only if
the evidence leaves a consequential human choice unresolved. It is not another review pass
or an automatic rule editor. An unattended worker reports questions and defers the dependent
action; it does not interview itself or claim the choice was accepted.