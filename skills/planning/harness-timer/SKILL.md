---
name: harness-timer
description: "Manage logical schedules under one user-wide heartbeat. Use /harness-timer or /hn-timer with list, set, disable, resume, clean, or migrate. Targets are project, pr, refresh, maintenance, or heartbeat settings. Bare invocation lists only. Overlaps with schedule-manager on task administration; owns SkillVault schedules. Maintenance delegates historical-data cleanup to harness."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|set|disable|resume|clean|migrate] [<arguments>...]"
---

# Harness Timers

The registered command is `/harness-timer`. `/hn-timer` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

No arguments or `list` shows saved schedules and available actions without selecting work,
prompting for setup, initializing a project, or registering a timer. `status` and `help` are
read-only aliases. Unknown actions show choices. Read the [scheduler contract](./references/scheduler.md)
for the selected action. The shared PowerShell runtime owns execution; this topic owns cadence.

| Action | Outcome |
| --- | --- |
| `list [<target>]` | Show known schedules, cadence, results, and recovery state |
| `set <target> [<duration>]` | Preview or apply an approved schedule, maintenance window, or heartbeat baseline |
| `disable <id>` | Disable future ticks; do not kill the active worker |
| `resume <id>` | Reenable the saved cadence after prerequisite and recovery checks |
| `clean` | Preview stale schedules; apply only the approved schedule changes |
| `migrate <target>` | Preview and replace one exact legacy OS timer, preserving cadence and enabled state |

The routine heartbeat baseline defaults to `1d`. `set heartbeat 12h` previews a user-wide
baseline change; apply only after approval. `list heartbeat` inspects it, and omitting its duration
reuses the saved value. This settings target creates no work and leaves job intervals, anchors,
enabled states, and maintenance unchanged. Faster job intervals and earlier due times shorten the
heartbeat automatically; outstanding workers retain a 30-minute check cap. The heartbeat itself
has no AI model configuration. Existing scheduled AI workers keep their own runner settings.

Historical records and their reports belong to `/harness clean`, including retention settings.
Weekly maintenance delegates to that same history-cleanup operation. Explicit timer `clean`
never prunes history; it owns stale schedule definitions and their scheduler receipts only.

Apply `/rules apply`, project instructions, Script Permissions and Agent Fallback, Runner
Inheritance, and Reuse or New before scripts. Confirm missing matching-instance choices and
cadence for work schedules. Preserve singleton PR/refresh targets and named project instances. Old `project`, `pr`,
`refresh`, topic/duration inputs, and `/pr-review-timer` remain explicit setup routes to `set`,
not separate actions or OS schedulers. An entirely bare invocation now only lists.

One stable current-user heartbeat dispatches nonconflicting approved jobs; it never creates work
from an untouched backlog, expands permissions, or clears safety pauses. Maintenance defaults
to Saturday 08:30-09:00 in the saved local timezone, only after explicitly enabled. Machine wake
and AI assistance are allowed when necessary, not required for routine cleanup. Follow the
[conditional capability policy](./references/scheduler.md#conditional-capabilities); permission
alone changes no live wake setting and starts no AI run. No remote scans or catch-up outside
the maintenance window. Existing timers and installed copies need separately previewed migration.
Keep PACS and unrelated schedules unchanged.