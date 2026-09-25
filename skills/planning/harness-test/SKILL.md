---
name: harness-test
description: "Declare or run reusable harness tests. Use /harness-test or
  /hn-test with list, declare, or run. Overlaps with harness-dev on
  validation and harness-monitor on checks; executes declared tests rather than
  evaluating incident episodes."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|declare|run] [<arguments>...]"
---

# Harness Tests

The registered command is `/harness-test`. `/hn-test` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

No arguments or `list` shows declarations, latest results, and actions without
running tests. Explicit `declare` or `run` follows the [test procedure](./references/workflow.md).
`status` and `help` remain read-only aliases.
Legacy `/harness-test` arguments retain their operation. Unknown actions show help.
Apply `/rules apply`, project instructions, and the runtime's Script Permissions and Agent
Fallback procedure. Keep environments, approvals, and post-development gates unchanged.
No AI worker is required for test-only execution; failures cannot be relabeled as passing.