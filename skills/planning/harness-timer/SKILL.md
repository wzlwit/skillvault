---
name: harness-timer
description: "Manage logical schedules under one user-wide heartbeat. Use /harness-timer or /hn-timer with list, set, disable, resume, clean, or migrate. Targets are project, pr, refresh, maintenance, or heartbeat settings. Bare invocation lists only. Overlaps with schedule-manager on task administration; owns SkillVault schedules. Maintenance delegates historical-data cleanup to harness."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|set|disable|resume|clean|migrate] [<arguments>...]"
---

# Harness Timers

`/harness-timer` owns SkillVault cadence under one user-wide heartbeat; the shared PowerShell
runtime owns execution.
`/hn-timer` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Outcome |
| --- | --- |
| `list [<target>]` | Show known schedules, cadence, results, and recovery state |
| `set <target> [<duration>]` | Preview or apply an approved schedule, maintenance window, or heartbeat baseline |
| `disable <id>` | Disable future ticks; do not kill the active worker |
| `resume <id>` | Reenable the saved cadence after prerequisite and recovery checks |
| `clean` | Preview stale schedules; apply only the approved schedule changes |
| `migrate <target>` | Preview and replace one exact legacy OS timer, preserving cadence and enabled state |

Bare invocation, `list`, `status`, and `help` are read-only: they show schedules and actions without
selecting work, prompting for setup, initializing a project, or registering a timer. Unknown actions
show choices. Follow the [scheduler contract](./references/scheduler.md) for the selected action.
Before setting or resuming a project target, read [project preflight](./references/project.md).
Before status, disable, resume, or migration of a legacy OS timer, read
[PR timer](./references/pr.md) or [refresh timer](./references/refresh.md) for that target.

## Before Scripts

Apply `/rules apply`, project instructions, Script Permissions and Agent Fallback, Runner
Inheritance, and Reuse or New. Confirm missing matching-instance choices and work-schedule cadence.
Keep PR and refresh as singleton targets and preserve named project instances. Legacy `project`,
`pr`, `refresh`, topic/duration inputs, and `/pr-review-timer` route to `set`; they are not
separate actions or OS schedulers.

## Boundaries

- The heartbeat dispatches only nonconflicting approved jobs; it never creates work from an
  untouched backlog, expands permissions, or clears safety pauses. Its `1d` baseline and preview/apply
  rules are in [Heartbeat Baseline](./references/scheduler.md#heartbeat-baseline).
- Maintenance is opt-in: Saturday 08:30-09:00 in the saved local timezone, with no remote scans or
  catch-up outside that window. Wake and AI use follow the
  [conditional capability policy](./references/scheduler.md#conditional-capabilities); permission
  alone changes no live wake setting and starts no AI run.
- History records and retention belong to `/harness clean`; timer `clean` owns only stale schedule
  definitions and their scheduler receipts.
- Existing OS timers and installed copies need separately previewed migration. PACS and unrelated
  schedules stay unchanged.