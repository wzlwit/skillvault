
# One PR Review Timer

For new schedules use [the shared scheduler](scheduler.md), `set pr <duration>`. It calls the
PR runtime's read-only Prepare path, then registers one logical whole-watchlist job. The details
below describe the retained legacy OS timer for compatibility/migration only, not another default
scheduler. Bare `/harness-timer` lists; it never invokes the old Set default. PR execution and
budgets remain owned by `pr-review`.

All watched PRs and repositories share one Windows task. Do not create per-target, per-project,
or timestamp-suffixed tasks, and do not change `/harness-timer` or unrelated schedules.
Discussing, creating, or installing this skill does not authorize a live timer.

## Workflow

1. Locate `pr-review` and read its runtime reference. Inspect the user-wide list and explicit
   runner configuration. A nonempty list, verified account/model capabilities, positive budgets,
   and `allowScheduled: true` are prerequisites. Missing choices need attended setup.
2. Bare invocation requests Set. Map a supplied positive decimal `intervalDays` to `-IntervalDays`;
   otherwise reuse this one task's single saved cadence. If none exists, ask. Never invent a
   default interval, copy another task's cadence, or interpret zero as an immediate run.
3. Preview with the dependency's `scripts/pr-review.ps1 -Action Timer -IntervalDays <days>`.
   Show task name/path, whole-list scope, cadence, approved model/effort/context and budgets,
   and current-user limited-privilege execution. No worker is started during setup.
4. After approval of the exact operation, repeat with `-Apply`. A direct, fully resolved timer
   request authorizes that operation; skill-authoring approval does not. The helper creates or
   updates the same `SkillVault PR Review <current-user-SID>` task at root task path `\`, and
   verifies the saved action/interval. Conflicting ownership blocks; do not choose another name.
5. Each tick runs only the installed dispatcher with `-Action Review -Scheduled`. It reads the
   entire current watchlist, deduplicates, applies shared safety/budget gates, and saves local
   evidence. No tick performs setup, changes policy, creates timers, or publishes feedback.

## Status and Control

Map `status`, `disable`, and `resume` to `-Action Timer -TimerAction Status|Disable|Resume`.
Status is read-only. Disable/Resume preview until the exact operation is approved with `-Apply`.
Disable affects future ticks, not an active worker. Resume enables the existing trigger without
resetting cadence or running immediately. Neither clears a safety pause or removes history.

The task uses interactive logon for the current user, not elevation or saved passwords. Do not
claim it runs while that user is logged out. Overlapping ticks are ignored; a shared cycle lock
also prevents concurrent manual runs. Empty future lists are no-ops. Existing CLI authentication
must work in that scheduled environment; editor MCP access is not inherited. Use the existing
harness fallback/recovery controls against the explicit user-wide controller for paused work.