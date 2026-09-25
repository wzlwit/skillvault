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

The registered command is `/harness-policy`. `/hn-policy` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

No arguments or `list` inspects existing restrictions, fallback settings, and pauses.
It adds no configuration and starts no work. Route unknown actions to help.

| Subcommand | Procedure |
| --- | --- |
| `list [limits|fallback]` | Read the selected policy and durable pauses |
| `set limits <file>` | [Restrictions](./references/limits.md), using its Declare preview/apply procedure |
| `set fallback <file>` | [Failure policy](./references/fallback.md), using its Declare preview/apply procedure |
| `pause`, `stop`, `resume` | [Target controls](./references/fallback.md#pause-stop-and-resume) |

Old `harness-restrict` or `/hn-restrict` requests select `limits`; old `harness-fallback` or
`/hn-fallback` requests select `fallback` or their explicit target-control action. Preserve all
remaining arguments. Limits do not clear pauses; resume does not restart or requeue work.
`limits` and `fallback` without a declaration select `list`; their old `declare <file>` form
selects `set`. `status` and `help` remain read-only aliases. Runtime PolicyAction names are unchanged.

Apply `/rules apply` and project instructions. Use the `harness` runtime and its Script
Permissions and Agent Fallback and Runner Inheritance procedures. The detailed guides own the
field contracts and approvals; examples are not accepted settings. Preview persistent changes
and obtain the required owner, reason, and confirmation. Explicit emergency stop authority is
not delayed by an extra interview. Unattended workers surface unresolved decisions and defer
dependent actions rather than invoking grilling or changing their own rules.