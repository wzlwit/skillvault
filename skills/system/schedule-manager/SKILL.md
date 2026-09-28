---
name: schedule-manager
description: List, enable, disable, or delete Windows scheduled tasks by index, list, range, or keyword. Triggers on "/schedule-manager", "schedule-manager", "list schedules", "list scheduled tasks", "enable scheduled task", "disable scheduled task", or "delete scheduled task". Overlaps with harness-timer on enabling/disabling tasks; covers general schedule administration.
metadata:
  author: wzlwit
  version: "1.1.0"
argument-hint: "[list|enable|disable|delete] [<selector>]"
---

# Schedule Manager

List all visible Windows scheduled tasks with indexes valid for the current listing run, then
enable, disable, or delete selected tasks by index, comma list, range, or keyword after
confirmation. `harness-timer` owns SkillVault's logical project, PR watchlist, refresh, and
maintenance schedules under one current-user heartbeat; this skill remains the general Windows
task inventory and administration workflow. Do not turn PR watch entries into separate tasks.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

## Parameters

- `action`: optional first argument, `list` (default), `enable`, `disable`, or `delete`;
  `remove` and `uninstall` remain aliases for `delete`.
- `selector`: required for `enable`, `disable`, and `delete`; omitted for listing. Use an index
  (`2`), comma list (`1,3,5`), range (`4-7`), mixed form (`1,3-5,9`), or keyword such as
  `SkillVault`, `sync`, or part of a task path or action.

## List

Start with this introduction:

```text
Windows scheduled tasks found on this machine. Indexes are stable only for this listing run.
Use them immediately with enable, disable, or delete, or use a keyword if the task name is clear.
```

Then show an indexed table with Index, TaskName, TaskPath, State, NextRunTime, LastRunTime,
Execute, Arguments, and Description.

## Enable, Disable, or Delete

1. Build the same indexed list first.
2. Resolve the selector. Indexes, lists, and ranges select exact positions, including every index
   inside a range. Keywords match task name, task path, action executable, action arguments, or
   description case-insensitively.
3. Show the action, matched indexes, task names, and task paths before making changes.
4. Ask for confirmation of that action on those tasks unless the user already explicitly
   confirmed it in the same request. If the selected set changes, show it and confirm again.
5. Run the bundled script with exactly one action switch, adding `-Force` only after that
   confirmation. The script addresses tasks by both task name and task path.
6. Report changed tasks, unmatched selectors, and failures. Do not claim a failed action
   succeeded or automatically retry with elevated privileges.

| Action | Cmdlet | Effect |
| --- | --- | --- |
| `enable` | `Enable-ScheduledTask` | Allows future runs under existing triggers; does not start the task. |
| `disable` | `Disable-ScheduledTask` | Prevents future scheduled runs and keeps the definition; does not stop a running instance. |
| `delete` | `Unregister-ScheduledTask -Confirm:$false` | Removes the task definition. |

## Script

Without `-Force`, the bundled Windows script lists tasks or previews the selected action:

```powershell
~/.copilot/skills/schedule-manager/scripts/schedule-manager.ps1
~/.copilot/skills/schedule-manager/scripts/schedule-manager.ps1 -Enable -Selector "2"
~/.copilot/skills/schedule-manager/scripts/schedule-manager.ps1 -Disable -Selector "SkillVault"
~/.copilot/skills/schedule-manager/scripts/schedule-manager.ps1 -Delete -Selector "1,3-5"
```

Never combine `-Enable`, `-Disable`, and `-Delete` in one invocation.

## Safety

- Listing is broad and includes all visible Windows scheduled tasks.
- Changes require an explicit selector and confirmation; never act on a keyword match before
  showing its matched indexes.
- Enabling or disabling a schedule never starts or stops task instances.
- Never commit or push after managing schedules unless the user explicitly asks.