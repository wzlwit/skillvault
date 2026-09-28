---
name: skillvault-discovery
description: "Discover skills, evaluate candidates, and explain skills, tools, or products. Use /skillvault-discovery or /sv-discovery list, search, evaluate, or explain. Replaces skillvault-search, skillvault-evaluate, skillvault-key-points and /sv-search, /sv-evaluate, /sv-key-points. Evaluation saves a public-safe assessment unless chat-only; search and explanation are read-only. None installs, runs, or edits the target."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|search|evaluate|explain] [<arguments>...]"
---

# Skill Discovery

`/skillvault-discovery` finds, evaluates, and explains skills, tools, and products without installing,
running, or editing them. Search and explanation are read-only; evaluation writes only its
public-safe record.
`/sv-discovery` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Procedure |
| --- | --- |
| `list` | Show known catalog context and available actions |
| `search` | [Find candidates](./references/search.md) |
| `evaluate` | [Assess value, fit, overlap, and risk](./references/evaluate.md) |
| `explain` | [Explain a skill, tool, or product](./references/explain.md) |

- Bare invocation, `list`, `help`, and `status` show actions and known catalog context without
  searching remote sources. Unknown actions show help.
- The exact aliases `eval` -> `evaluate` and `expl` -> `explain` use the canonical procedures and
  stay out of menus and registered names. Old full names and `/sv-*` or `/skv-*` spellings select
  their matching action.
- Load only the selected procedure. `evaluate` reuses verified search evidence and also
  [proposes improvements to existing skills](./references/evaluate.md#improve-existing-skills);
  implementing them needs the user's approval.
- Installation belongs to `/skillvault-installation` and authoring to `/skillvault-authoring`.
  Preserve source verification, attribution, reference-only limits, and explicit approval for either handoff.