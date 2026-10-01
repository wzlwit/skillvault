---
name: harness-decision
description: "List open harness decisions separately from optional configuration, filter closed/all decisions, explain one decision or question, or record a choice. Use /harness-decision or
  /hn-decision with list, explain, or record; also accepts legacy /harness-decide
  and /hn-decide. Overlaps with architecture-decision-records on history; owns
  the compact bulletin, decision register, and read-only explanations."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|explain|record] [<arguments>...]"
---

# Harness Decisions

`/harness-decision` owns the compact decision bulletin and register; full rationale belongs in ADRs.
`/hn-decision` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

- Bare invocation, `list`, or `list open` shows active open decisions plus a one-line
  **Configuration When Needed** summary and source link when optional setup is documented.
  `list closed` shows recent resolved outcomes (five by default; `--recent <count>` changes it),
  `list all` adds the detailed configuration checklist, and `list <decision-id>` shows one record of
  any status. Listing records or accepts nothing.
- `explain <decision-id|path|question>` follows the [explanation procedure](./references/workflow.md#explain-a-decision-or-question):
  a plain-language answer with an options table, evidence-backed reasons, a worked example, the
  trade-off, and the status. It is read-only and records or accepts nothing.
- Keep explicitly recorded Open/Proposed decisions visible; never hide or reclassify them as optional
  configuration. Missing configuration is an open decision only when requested or enabled work needs
  a human choice that saved settings, inheritance, or defaults cannot resolve.
- `record` follows the [decision procedure](./references/workflow.md). Unknown actions and `help` show
  choices; legacy decide commands keep their explicit operation.
- Apply `/rules apply` and project instructions. A grilling proposal is not an accepted decision;
  consequential rationale may use ADRs as authorized.