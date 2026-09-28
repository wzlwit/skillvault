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

`/harness-task` owns task records and readiness; it never executes work.
`/hn-task` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

- Bare invocation, `list`, `status`, and `help` inspect tracked tasks and show actions. Unknown
  actions show help without creating work.
- `add`, `update`, requirements, or legacy `/harness-task` input follow the
  [task procedure](./references/workflow.md). No intake route starts execution or grants automatic
  eligibility.
- Keep requirement Source separate from the coding repository. `/harness-dev` reuses this intake for
  ad-hoc work; there is no second task registry.
- Apply `/rules apply` and project instructions. Unresolved consequential scope or acceptance
  choices go to the attended owner through grilling, not invented task fields.