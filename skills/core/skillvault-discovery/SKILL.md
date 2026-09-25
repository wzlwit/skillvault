---
name: skillvault-discovery
description: "Discover skills, evaluate candidates, and explain skills, tools, or products. Use /skillvault-discovery or /sv-discovery list, search, evaluate, or explain. Replaces skillvault-search, skillvault-evaluate, skillvault-key-points and /sv-search, /sv-evaluate, /sv-key-points. Evaluation saves a public-safe assessment unless chat-only; search and explanation are read-only. None installs, runs, or edits the target."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|search|evaluate|explain] [<arguments>...]"
---

# Skill Discovery

The registered command is `/skillvault-discovery`. `/sv-discovery` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

No arguments or `list` shows the actions and known catalog context without installing or
searching remote sources. Unknown actions show help. Route explicit requests as follows:
`help` and `status` are compatibility aliases for the same read-only list.
The exact action aliases `eval` -> `evaluate` and `expl` -> `explain` use the same procedures
and boundaries as their canonical actions. Keep aliases out of primary menus and registered
skill names.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

| Action | Procedure |
| --- | --- |
| `list` | Show known catalog context and available actions |
| `search` | [Find candidates](./references/search.md) |
| `evaluate` | [Assess value, fit, overlap, and risk](./references/evaluate.md) |
| `explain` | [Explain a skill, tool, or product](./references/explain.md) |

Old full names and `/sv-*` or `/skv-*` equivalents select their matching action. Search,
evaluation, and explanation do not run the target skill. Load only the selected procedure.
Installation belongs to `/skillvault-installation`; authoring belongs to `/skillvault-authoring`. Preserve source
verification, attribution, reference-only limitations, and explicit approval for either handoff.