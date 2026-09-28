---
name: harness-report
description: "Coordinate dashboard, report, and query authoring. Use
  /harness-report or /hn-report with list or upsert. The create/update actions and
  legacy /harness-report-create and /hn-report-create commands use upsert. Overlaps with
  harness-dev on implementation, kpi-dashboard on design, jarvis-metrics on Jarvis authoring,
  and the ppt-master and office-documents references on artifact validation; owns artifact identity and validation,
  not publishing."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|upsert] [<arguments>...]"
---

# Harness Reports

`/harness-report` coordinates dashboard, report, and query authoring. It owns artifact identity and
validation, not publishing.
`/hn-report` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

```text
list
upsert <artifact-or-purpose> [--type <platform>] [--output <path>] [--design-only]
```

- Bare invocation, `list`, `status`, and `help` show known artifacts and actions without creating one
  or querying remote platforms. Unknown actions show help.
- `upsert`, an authoring request, or the old report-create command follows the
  [authoring procedure](./references/workflow.md). `create` and `update` alias `upsert`: update the
  resolved artifact when present and create it only when confirmed absent. An ambiguous or
  inaccessible target is not absent; never create a duplicate.
- Platforms: `powerbi`, `grafana`, `jarvis`, `web`, or `query`. Infer a type only from an unambiguous
  request or existing artifact; otherwise ask.
- Apply `/rules apply` and project instructions. Load only the selected platform specialist and
  preserve artifact IDs, source contracts, output destinations, validation, and publication approvals.
  Design, created, validated, and published are distinct outcomes; monitoring is optional.
- `ppt-master` and `office-documents` reference separate presentation and PDF/Word/Excel guidance.
  They add no PPTX or XLSX route or renderer; editability and workbook checks belong to the
  artifact's acceptance contract, not its file extension.