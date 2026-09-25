---
name: harness-report
description: "Coordinate dashboard, report, and query authoring. Use
  /harness-report or /hn-report with list or upsert. The create/update actions and
  legacy /harness-report-create and /hn-report-create commands use upsert. Overlaps with
  harness-dev on implementation, kpi-dashboard on design, and jarvis-metrics on
  Jarvis authoring; owns artifact identity and validation, not publishing."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|upsert] [<arguments>...]"
---

# Harness Reports

The registered command is `/harness-report`. `/hn-report` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

No arguments or `list` shows known artifacts and available actions without creating
one. Explicit `upsert`, an authoring request, or the old report-create command uses
the [authoring procedure](./references/workflow.md). Unknown actions show help.
`status` and `help` remain aliases for the read-only view; listing does not query remote platforms.

```text
list
upsert <artifact-or-purpose> [--type <platform>] [--output <path>] [--design-only]
```

`create` and `update` are compatibility aliases for `upsert`, not existence requirements.
Resolve the stable artifact identity, update it when present, and create it when confirmed
absent. An ambiguous or inaccessible target is not absent; do not create a duplicate.

Platforms: `powerbi`, `grafana`, `jarvis`, `web`, or `query`. Infer a type only from an
unambiguous request or existing artifact; otherwise ask before selecting a platform.
Apply `/rules apply` and project instructions. Load only the selected platform specialist;
preserve artifact IDs, source contracts, output destinations, validation, and publication approvals.
Design, created, validated, and published are distinct outcomes. Monitoring remains optional.