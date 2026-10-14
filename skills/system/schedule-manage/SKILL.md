---
name: schedule-manage
description: "[enable|disable|delete] Alone: Windows tasks. Text: filter them. Manage Windows scheduled tasks, selected by number, list, range, or keyword. Triggers on \"list schedules\", \"list scheduled tasks\", \"enable scheduled task\", \"disable scheduled task\", or \"delete scheduled task\". Overlaps with harness-schedule on enabling and disabling tasks; covers general schedule administration."
metadata:
  author: wzlwit
  version: "2.0.0"
argument-hint: "[enable|disable|delete] [<number or keyword>]"
---

# Schedule Manage

List all visible Windows scheduled tasks with indexes valid for the current listing run, then
enable, disable, or delete selected tasks by index, comma list, range, or keyword after
confirmation. `harness-schedule` owns SkillVault's logical project, PR watchlist, refresh, and
maintenance schedules under one current-user heartbeat; this skill remains the general Windows
task inventory and administration workflow. Do not turn PR watch entries into separate tasks.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | [List every visible Windows scheduled task, numbered](#task-list) |
| Text | [Filter the list](#task-list) by a keyword or number; changes nothing |
| `enable <number, list, range, or keyword>` | [Allow future runs of the selected tasks](#enable-disable-or-delete), after confirmation |
| `disable <number, list, range, or keyword>` | [Prevent future scheduled runs of the selected tasks](#enable-disable-or-delete), after confirmation |
| `delete <number, list, range, or keyword>` | [Remove the selected task definitions](#enable-disable-or-delete), after confirmation |

- Alone lists every visible Windows scheduled task, numbered, and changes nothing.
- The alone view ends with one line naming the text uses: a keyword or number filters the list,
  and `enable`, `disable`, or `delete` with numbers or a keyword changes the selected tasks.
- Text is a selector that filters the list: run the listing, then show only the rows the selector
  rule below matches, with their numbers from the full listing. It changes nothing.

## Parameters

- `action`: optional menu word: `enable`, `disable`, or `delete`. Without one, the skill lists
  tasks, filtered by any text.
- `selector`: required for `enable`, `disable`, and `delete`; optional text for filtering the list.
  Use an index (`2`), comma list (`1,3,5`), range (`4-7`), mixed form (`1,3-5,9`), or keyword such
  as `SkillVault`, `sync`, or part of a task path or action.

## Task List

Start with this introduction:

```text
Windows scheduled tasks found on this machine. Indexes are stable only for this listing run.
Use them immediately with enable, disable, or delete, or use a keyword if the task name is clear.
```

Then show an indexed table with Index, TaskName, TaskPath, State, NextRunTime, LastRunTime,
Execute, Arguments, and Description. With text, show only the matching rows. End with the one line
naming the text uses.

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
~/.copilot/skills/schedule-manage/scripts/schedule-manage.ps1
~/.copilot/skills/schedule-manage/scripts/schedule-manage.ps1 -Enable -Selector "2"
~/.copilot/skills/schedule-manage/scripts/schedule-manage.ps1 -Disable -Selector "SkillVault"
~/.copilot/skills/schedule-manage/scripts/schedule-manage.ps1 -Delete -Selector "1,3-5"
```

Never combine `-Enable`, `-Disable`, and `-Delete` in one invocation.

## Safety

- Listing is broad and includes all visible Windows scheduled tasks.
- Changes require an explicit selector and confirmation; never act on a keyword match before
  showing its matched indexes.
- Enabling or disabling a schedule never starts or stops task instances.
- Never commit or push after managing schedules unless the user explicitly asks.
