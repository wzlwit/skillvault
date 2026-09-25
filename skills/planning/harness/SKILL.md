---
name: harness
description: "Inspect harness state, select its root with a move confirmation after initialization, initialize, read context, or clean historical data. Use /harness or /hn with list, root, init, context, or clean. Accepts legacy root/init/loc/context and management commands. Context summaries overlap with handoff; harness-link owns links. Owns retention; harness-timer schedules maintenance. Bare invocation only lists."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|root|init|context|clean] [<arguments>...]"
---

# Harness

The registered command is `/harness`. `/hn` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

Route on the first subcommand or an unambiguous natural-language request. No arguments or
`list` shows the selected Root, available state, and these actions without prompting
for a new root, initializing, installing, or starting work. Unknown actions show help.
`status` and `help` are compatibility spellings for this read-only view.

| Subcommand | Load only this procedure |
| --- | --- |
| `list` | Show the selected root, saved status, and actions |
| `root [<path>]` | [Show or change the root; prompted moves default to Yes after initialization](./references/loc.md) |
| `init` | [Initialize or reconnect](./references/init.md) |
| `context` | [Read rules, plans, decisions, and references](./references/context.md) |
| `clean [--policy <file>] [--apply]` | [Preview historical-data cleanup or configure retention](./references/runtime.md#history-cleanup) |

`clean` owns retained run records and reports, not schedules, skill folders, application files,
or worktrees. `/harness-timer` owns cadence and stale schedules; weekly maintenance invokes the
same history-cleanup operation. No separate management or maintenance topic is registered.

`root` alone displays the selected root; `root <path>` selects it. `loc` is a compatibility alias.
Validate and select the requested new root first. If the previously selected harness was initialized
and the path differs, prompt with **Yes: Move** as the default, including when no answer is given.
No move flag is needed. An explicit answer or applicable user instruction overrides the default;
No, cancel, or an instruction not to move leaves existing data in place. Otherwise use the previewed
relocation helper with the saved previous root as its source. The new Root stays selected either way.
A failed move is reported without
undoing that selection or claiming migration succeeded. Invalid paths leave Root unchanged;
relocation never merges with another controller. An uninitialized source or unchanged path needs
no move prompt.
Harness-owned information and
files default to `<root>/.harness_sv/` unless the user explicitly specifies another destination.
Follow [Artifact Storage](./references/runtime.md#artifact-storage) for records, documents,
logs, declarations, and report/query outputs. Selecting a location creates nothing and never
silently moves existing data. Installed skill folders and linked coding repositories are separate.
Use `/harness-link list|add|remove` for all supporting URLs, files, folders, and coding-repository
paths. There are no separate `repo` or `url` actions here. Specialized work stays with
`/harness-dev`, `/harness-review`, `/harness-monitor`, and the other harness topics.

Legacy management commands route to these actions. `/hn-root <path>` and `/harness-root <path>` use
the same move prompt and default as `/hn root <path>`, without a second location prompt for an
existing Root. An old management/loc command with a positional board path keeps its board-placement
meaning, never the new `/harness loc <path>` meaning. Explicit `--root` and `--board` remain
compatibility routes described in the location guide, not two advertised location actions.
The old root/init/loc/context full commands and shortcuts remain text routes, not separate skills.
Bare `/harness` never implies `init`. Root selection is session context, not permission
to initialize, install, clone, or create schedules. Keep controller, coding repository, board,
and SkillVault source locations distinct. Invalid paths or rejection never silently fall back.

The shared PowerShell runtime is bundled here under [scripts/harness.ps1](./scripts/harness.ps1).
Every action applies `/rules apply` and project instructions. Before scripts, follow
[Script Permissions and Agent Fallback](./references/runtime.md#script-permissions-and-agent-fallback).
Reuse [Root Inheritance](./references/runtime.md#root-inheritance) and
[Runner Inheritance](./references/runtime.md#runner-inheritance); do not invent settings or
repeat location confirmations. Existing CLI actions and saved explicit paths are unchanged.

Grilling is offered when initialization or later evidence reveals unresolved consequential
choices. It interviews the human owner, not a worker; it neither replaces review nor changes
standing rules. Record an accepted decision through `/harness-decision` only as authorized.