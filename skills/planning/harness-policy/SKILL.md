---
name: harness-policy
description: "Inspect or change harness limits and failure responses. Use
  /harness-policy or /hn-policy with list, set, pause, stop, or resume.
  Legacy harness-restrict, harness-fallback, /hn-restrict, and
  /hn-fallback select the matching action. Limits and failure handling share
  execution policy but remain separate configuration objects."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|set|pause|stop|resume] [<arguments>...]"
---

# Harness Policy

`/harness-policy` owns runtime limits, failure responses, and durable pauses; limits and failure
handling remain separate configuration objects.
`/hn-policy` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Subcommand | Procedure |
| --- | --- |
| `list [limits|fallback]` | Read the selected policy and durable pauses |
| `set limits <file>` | [Restrictions](./references/limits.md), using its Declare preview/apply procedure |
| `set fallback <file>` | [Failure policy](./references/fallback.md), using its Declare preview/apply procedure |
| `pause`, `stop`, `resume` | [Target controls](./references/fallback.md#pause-stop-and-resume) |

- Bare invocation, `list`, `status`, and `help` inspect restrictions, fallback settings, and pauses;
  they add no configuration and start no work. Unknown actions show help.
- Legacy `harness-restrict` and `/hn-restrict` select `limits`; `harness-fallback` and `/hn-fallback`
  select `fallback` or their explicit target control. `limits` or `fallback` without a declaration
  selects `list`, and the old `declare <file>` form selects `set`. Remaining arguments and runtime
  PolicyAction names are unchanged.
- Limits do not clear pauses; resume does not restart or requeue work.
- Apply `/rules apply` and project instructions, then the `harness` runtime's Script Permissions and
  Agent Fallback and Runner Inheritance procedures. The detailed guides own field contracts;
  examples are not accepted settings. Preview persistent changes and obtain the required owner,
  reason, and confirmation. Explicit emergency stop authority is not delayed by an interview.
- Unattended workers surface unresolved decisions and defer dependent actions instead of invoking
  grilling or changing their own rules.