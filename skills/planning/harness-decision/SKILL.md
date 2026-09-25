---
name: harness-decision
description: "List open harness decisions separately from optional configuration, filter closed/all decisions, or record a choice. Use /harness-decision or
  /hn-decision with list or record; also accepts legacy /harness-decide
  and /hn-decide. Overlaps with architecture-decision-records on history; owns
  the compact bulletin and decision register."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|record] [<arguments>...]"
---

# Harness Decisions

The registered command is `/harness-decision`. `/hn-decision` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

Bare invocation, `list`, or `list open` shows active open decisions plus a one-line
**Configuration When Needed** summary and source link when optional setup is documented.
Keep explicitly recorded Open/Proposed decisions visible; do not hide or reclassify them as
optional configuration. Missing configuration is an open decision only when a requested or enabled
workflow needs a human choice that saved settings, inheritance, or defaults cannot resolve.
`list closed` shows recent resolved outcomes; `list all` includes open and recent decisions plus
the detailed configuration checklist. Listing records or accepts nothing.
`list <decision-id>` shows that record regardless of status. Resolved results default to five;
`--recent <count>` changes that display limit. `record` follows the [decision procedure](./references/workflow.md).
Unknown actions or `help` shows choices. Legacy decide commands retain their explicit operation.
Apply `/rules apply` and project instructions. Grilling may resolve a human choice, but its
proposal is not an accepted decision. Consequential rationale can use ADRs as authorized.