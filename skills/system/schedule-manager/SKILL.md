---
name: schedule-manager
description: List, enable, disable, or delete Windows scheduled tasks by index, list, range, or keyword. Triggers on "/schedule-manager", "schedule-manager", "list schedules", "list scheduled tasks", "enable scheduled task", "disable scheduled task", or "delete scheduled task". Overlaps with harness-timer and harness-timer on enabling/disabling tasks; covers general schedule administration.
metadata:
  author: wzlwit
  version: "1.1.0"
argument-hint: "[list|enable|disable|delete] [<selector>]"
---

# Schedule Manager

This skill lists Windows scheduled tasks broadly, assigns indexes for the current command
run, and enables, disables, or deletes selected tasks by index, range, comma list, or keyword
after confirmation.
`harness-timer` creates and manages one selected harness project's timer; this skill remains the
general inventory and administration workflow.
`harness-timer` owns one current-user timer for the entire cross-repository PR watchlist.
Do not turn watch entries into separate scheduled tasks when administering that timer.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

## Parameters

- `action` — optional first positional argument: `list`, `enable`, `disable`, or `delete`.
  Default: `list`. `remove` and `uninstall` remain aliases for `delete`.
- `selector` — required for `enable`, `disable`, and `delete`; omitted for listing. Supports:
  - Single index: `2`
  - Comma list: `1,3,5`
  - Range: `4-7`
  - Mixed list and range: `1,3-5,9`
  - Keyword: `SkillVault`, `sync`, or part of a task path/action

## Listing Behavior

When listing schedules, start with a short introduction explaining what is being shown:

```text
Windows scheduled tasks found on this machine. Indexes are stable only for this listing run.
Use them immediately with enable, disable, or delete, or use a keyword if the task name is clear.
```

Then show an indexed table with:

- Index
- TaskName
- TaskPath
- State
- NextRunTime
- LastRunTime
- Execute
- Arguments
- Description

## Action Behavior

For `enable`, `disable`, or `delete`:

1. Build the same indexed list first.
2. Resolve the selector:
   - Numeric selectors target exact indexes.
   - Ranges target all indexes inside the range.
   - Keywords match task name, task path, action executable, action arguments, or description
     case-insensitively.
3. Show the action, matched indexes, task names, and task paths before making changes.
4. Ask for confirmation of that action on those tasks unless the user has already explicitly
  confirmed in the same request. If the selected set changes, show it and confirm again.
5. Use the bundled script with exactly one action switch and `-Force` only after confirmation.
  It addresses tasks by both task name and task path.
6. Report changed tasks, unmatched selectors, and any failure. Do not claim a failed action
  succeeded or automatically retry with elevated privileges.

- `enable` uses `Enable-ScheduledTask`: allows future runs under the existing triggers; it
  does not immediately start the task.
- `disable` uses `Disable-ScheduledTask`: prevents future scheduled runs while retaining the
  task definition; it does not stop an already-running instance.
- `delete` uses `Unregister-ScheduledTask -Confirm:$false`: removes the task definition.

## Script

The bundled Windows script lists tasks or previews selected actions:

```powershell
~/.copilot/skills/schedule-manager/scripts/schedule-manager.ps1
~/.copilot/skills/schedule-manager/scripts/schedule-manager.ps1 -Enable -Selector "2"
~/.copilot/skills/schedule-manager/scripts/schedule-manager.ps1 -Disable -Selector "SkillVault"
~/.copilot/skills/schedule-manager/scripts/schedule-manager.ps1 -Delete -Selector "2"
~/.copilot/skills/schedule-manager/scripts/schedule-manager.ps1 -Delete -Selector "1,3-5"
~/.copilot/skills/schedule-manager/scripts/schedule-manager.ps1 -Delete -Selector "SkillVault"
```

Append `-Force` only after the user explicitly confirms the action and matched tasks.
Never combine `-Enable`, `-Disable`, and `-Delete` in one invocation.

## Safety

- Listing is broad: include all visible Windows scheduled tasks.
- Enabling, disabling, and deletion require an explicit selector and confirmation.
- Never change tasks by keyword without showing the matched indexes first.
- Do not start or stop task instances as a side effect of enabling or disabling schedules.
- Never commit or push after managing schedules unless the user explicitly asks.