---
name: harness
description: "Inspect harness state, select or relocate its root, initialize, migrate layout, read context, or clean history. Use /harness or /hn with list, root, init, migrate, context, or clean. Accepts legacy root/init/loc/context and management commands. Context summaries overlap with handoff; harness-link owns links. Owns retention; harness-timer schedules maintenance. Bare invocation only lists."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|root|init|migrate|context|clean] [<arguments>...]"
---

# Harness

`/harness` owns project setup: Root selection and relocation, initialization, layout migration,
context, and history cleanup. Specialized work stays with the other `harness-*` topics.
`/hn` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Subcommand | Load only this procedure |
| --- | --- |
| `list` | Show the selected root, saved status, and actions |
| `root [<path>]` | [Show or change the root; prompted moves default to Yes after initialization](./references/loc.md) |
| `init` | [Initialize or reconnect](./references/init.md) |
| `migrate [--apply]` | [Preview or apply an in-place layout migration](./references/runtime.md#layout-migration) |
| `context` | [Read rules, plans, decisions, and references](./references/context.md) |
| `clean [--policy <file>] [--apply]` | [Preview historical-data cleanup or configure retention](./references/runtime.md#history-cleanup) |

- Bare invocation, `list`, `status`, and `help` show the selected Root, saved state, and actions
  without prompting for a new root, initializing, installing, or starting work. Bare `/harness`
  never implies `init`. Unknown actions show help.
- `root` alone displays the selected root; `root <path>` selects it, and `loc` is an alias. Changing
  an initialized root prompts to move its data, with **Yes: Move** as the default; the new Root stays
  selected either way. Invalid paths leave Root unchanged and never fall back. The
  [location guide](./references/loc.md) owns the prompt, legacy `--root`/`--board` routes, and
  [current-view names](./references/loc.md#current-view-names), including `root --current-file`
  renames and `root --view` exports.
- `migrate` converts a layout in place after preview and approval; `init` never migrates. It is not
  Root relocation or cleanup.
- `clean` owns retained run records and reports, not schedules, skill folders, application files, or
  worktrees. `/harness-timer` owns cadence and stale schedules.
- Harness-owned files default to `<root>/.harness_sv/` under
  [Artifact Storage](./references/runtime.md#artifact-storage). Selecting a location creates nothing,
  never silently moves data, and grants no permission to initialize, install, clone, or schedule.
  Keep controller, coding repository, board, and SkillVault source locations distinct.
- Use `/harness-link list|add|remove` for URLs, files, folders, and repository paths, and
  `/harness-doc list|upsert` for reader-facing guides; it works without initialization.
- Legacy root/init/loc/context/management commands are text routes, not separate skills;
  `/hn-root <path>` and `/harness-root <path>` share the same move prompt.

## Before Scripts

The shared runtime is bundled at [scripts/harness.ps1](./scripts/harness.ps1). Every action applies
`/rules apply` and project instructions, then
[Script Permissions and Agent Fallback](./references/runtime.md#script-permissions-and-agent-fallback),
[Root Inheritance](./references/runtime.md#root-inheritance), and
[Runner Inheritance](./references/runtime.md#runner-inheritance). Do not invent settings or repeat
location confirmations.

Grilling is offered for unresolved consequential choices found during initialization or later. It
interviews the human owner, never replaces review, and records decisions through `/harness-decision`
only as authorized.