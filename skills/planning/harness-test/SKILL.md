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

`/harness-test` declares and runs reusable tests; it does not evaluate incident episodes.
`/hn-test` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

- Bare invocation, `list`, `status`, and `help` show declarations, latest results, and actions
  without running tests. Unknown actions show help.
- `declare`, `run`, and legacy `/harness-test` arguments follow the
  [test procedure](./references/workflow.md). Before declaring or changing a flow or environment,
  read [test declarations](./references/test-flows.md).
- Apply `/rules apply`, project instructions, and the runtime's Script Permissions and Agent Fallback
  procedure. Keep environments, approvals, and post-development gates unchanged.
- Test-only runs need no AI worker; failures are never relabeled as passing.