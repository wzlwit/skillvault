---
name: harness-monitor
description: "Declare monitors, check structured observations, and propose
  incident investigations. Use /harness-monitor or /hn-monitor with list, declare,
  check, or accept. Overlaps with harness-test on checks,
  harness-task on intake, and kpi-dashboard on metric contracts; never launches
  automatic fixes."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|declare|check|accept] [<arguments>...]"
---

# Harness Monitoring

The registered command is `/harness-monitor`. `/hn-monitor` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

Bare invocation or `list` only shows saved definitions, observations, incidents, and
actions. `declare`, `check`, and `accept` use the [monitoring procedure](./references/workflow.md)
and [declaration contract](./references/monitoring.md). Unknown actions show help.
`accept <incident-id>` previews task intake through `-Action MonitorTask`; applying it still needs
the owner and reason. Legacy `task` maps to `accept`; `status` and `help` map to `list`.
Apply `/rules apply` and project instructions. Preserve collection-versus-health distinctions,
episode deduplication, explicit task intake, and existing approval and pause gates.

Offer grilling when an attended owner must resolve a consequential metric, threshold, or
response-policy choice. Do not run interviews during scheduled checks or on every incident.
Unknown observations and unresolved choices are not permission to invent thresholds or fixes.