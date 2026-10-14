---
name: harness-schedule
description: "[clean] Alone: all schedules. Text: set one, like pr 1d or pr off. Manage logical schedules under one user-wide heartbeat for projects, PR review, refresh, and maintenance: set, turn off or on, convert old SkillVault Windows tasks, and clean up stale schedules. Shorthand: /hn-schedule. Overlaps with schedule-manage on Windows task administration; owns SkillVault schedules. Maintenance delegates history cleanup to harness-setup clean."
metadata:
  author: wzlwit
  version: "5.0.0"
argument-hint: "[clean] [<target> <duration|off|on>]"
---

# Harness Schedule

`/harness-schedule` owns SkillVault cadence under one user-wide heartbeat; the shared PowerShell
runtime owns execution.
`/hn-schedule` is chat shorthand for the same topic, not a separate skill or folder.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | Show every schedule with its cadence, last result, next run, and anything paused or stuck; offer to convert an old SkillVault Windows task ([commands](./references/scheduler.md#commands), [migration](./references/scheduler.md#migration)) |
| Text | Set, turn off or on, or show one target: `pr 1d`, `refresh 1d`, `project 4h`, `project 1h monitor <name>`, `heartbeat 1d`, `maintenance`, `pr off`, `pr on`, or a target alone ([commands](./references/scheduler.md#commands)) |
| `clean` | Show stale schedules and change only the ones approved after one question ([stale schedules](./references/scheduler.md#stale-schedules)) |

- Alone (`-Action List -All`) shows every project, PR, and refresh schedule with the heartbeat
  baseline and maintenance setting; showing selects no work, prompts for no setup, initializes no
  project, and registers no timer. It also checks, read-only, for an old SkillVault Windows task
  from before the heartbeat that has no logical replacement yet: the PR review timer,
  `SkillVault Source Refresh`, or a project's `SkillVault Harness <project-id>` task, never the
  heartbeat itself. When it finds one, it offers once to convert it, keeping its cadence and enabled
  state; no answer changes nothing. The view ends with one line naming the text uses: give a target
  and a duration, such as `pr 1d`, to set it, `pr off` or `pr on` to stop or resume it, or a target
  alone to show it.
- Text names a target (`project`, `pr`, `refresh`, `maintenance`, or `heartbeat`) or a schedule id
  from the alone view. A target and a duration sets it
  (`-Action Set -Target <target> -Interval <duration>`); `maintenance` sets the fixed Saturday window
  and takes no duration; `heartbeat <duration>` changes only the user-wide routine baseline.
  `<target or id> off` stops future runs, and a run in progress finishes (`-Action Disable -Id <id>`).
  `<target or id> on` resumes the saved cadence after the prerequisite and recovery checks
  (`-Action Resume -Id <id>`). A target alone shows it (`-Action List -Target <target>`), and a
  target that matches several schedules asks which one. Project targets keep their topics and
  instance names, such as `project 1d review as new second-review`.
- Every change follows Ask Once in the `harness-runtime` guide. A request that names exactly what to
  change acts at once and reports the result: a target with its duration (`maintenance` needs none)
  when no matching schedule needs a Reuse or New choice, and `off` or `on` for one exact schedule.
  Anything else, such as a missing duration, a Reuse or New choice, every schedule at once,
  recovering an uncertain worker, `clean`, or converting an old Windows task, shows the resolved
  schedule and asks once; without an answer nothing changes.
- Follow the [scheduler contract](./references/scheduler.md) for every request. Before setting or
  turning on a project target, or converting an old project task, read
  [project preflight](./references/project.md). Before showing, turning off or on, or converting an
  old PR or refresh Windows task, read [PR timer](./references/pr.md) or
  [refresh timer](./references/refresh.md) for that target.

## Before Scripts

Apply `/rules apply`, project instructions, Script Permissions and Agent Fallback, Runner
Inheritance, and Reuse or New. Confirm missing matching-instance choices and work-schedule cadence.
Keep PR and refresh as singleton targets and preserve named project instances. Targets are text,
not separate actions or OS schedulers.

## Boundaries

- The heartbeat dispatches only nonconflicting approved jobs; it never creates work from an
  untouched backlog, expands permissions, or clears safety pauses. Its `1d` baseline and preview/apply
  rules are in [Heartbeat Baseline](./references/scheduler.md#heartbeat-baseline).
- Maintenance is opt-in: Saturday 08:30-09:00 in the saved local timezone, with no remote scans or
  catch-up outside that window. Wake and AI use follow the
  [conditional capability policy](./references/scheduler.md#conditional-capabilities); permission
  alone changes no live wake setting and starts no AI run.
- Old run history belongs to `/harness-setup clean` and retention settings to
  `/harness-setup policy set retention <file>`; schedule `clean` owns only stale schedule
  definitions and their scheduler receipts.
- Converting existing OS timers and migrating installed copies each need their own preview. PACS
  and unrelated schedules stay unchanged.