---
name: harness-task
description: "Record or inspect harness tasks without executing them. Use
  /harness-task or /hn-task with list, add, or update. Overlaps
  with harness-dev and harness-monitor on intake; owns task records and
  readiness."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|add|update] [<arguments>...]"
---

# Harness Tasks

The registered command is `/harness-task`. `/hn-task` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

Bare invocation or `list` inspects tracked tasks and shows actions; `status` and `help` are aliases. Explicit
`add`, `update`, requirements, or legacy `/harness-task` input follows the
[task procedure](./references/workflow.md). Unknown actions show help without creating work.
Apply `/rules apply` and the project's instructions. No intake route starts execution or
grants automatic eligibility. Keep requirement Source separate from the coding repository.
This topic owns task records and readiness. When `/harness-dev` accepts ad-hoc work, it reuses
this intake and update path; it does not maintain a second task registry.
Unresolved consequential scope or acceptance choices go to the attended owner through grilling,
not invented task fields; existing readiness and authorization checks remain in force.