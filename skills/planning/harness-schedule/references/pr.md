
# One PR Review Timer

For new schedules use [the shared scheduler](scheduler.md): `/harness-schedule pr <duration>`. It
calls the PR runtime's read-only Prepare path, then registers one logical whole-watchlist job. The
details below describe the retained legacy OS timer for compatibility and conversion only, not
another default scheduler. `/harness-schedule` alone shows schedules and offers to convert this
timer; it never sets it. PR execution and budgets remain owned by `pr-review`.

All watched PRs and repositories share one Windows task. Do not create per-target, per-project,
or timestamp-suffixed tasks, and do not change `/harness-schedule` or unrelated schedules.
Discussing, creating, or installing this skill does not authorize a live timer.

## Workflow

1. Locate `pr-review` and read its runtime reference. Inspect the user-wide watchlist and its saved
   settings. A nonempty watchlist, working `gh` and Copilot CLI access, and saved `allowScheduled: true`
   are prerequisites; other settings keep their defaults. Missing approval needs attended setup.
2. Setting this legacy timer maps a supplied positive decimal `intervalDays` to `-IntervalDays`;
   otherwise it reuses this one task's single saved cadence. If none exists, ask. Never invent a
   default interval, copy another task's cadence, or interpret zero as an immediate run.
3. Preview with the dependency's `scripts/pr-review.ps1 -Action Timer -IntervalDays <days>`.
   Show task name/path, whole-watchlist scope, cadence, the requested model/effort/context and any saved
   limits, and current-user limited-privilege execution. No worker is started during setup.
4. After approval of the exact operation, repeat with `-Apply`. A direct, fully resolved timer
   request authorizes that operation; skill-authoring approval does not. The helper creates or
   updates the same `SkillVault PR Review <current-user-SID>` task at root task path `\`, and
   verifies the saved action/interval. Conflicting ownership blocks; do not choose another name.
5. Each tick runs only the installed dispatcher with `-Action Review -Scheduled`. It reads the
   entire current watchlist, deduplicates, applies shared safety/budget gates, and saves local
   evidence. No tick performs setup, changes policy, creates timers, or publishes feedback.

## Status and Control

Before conversion, showing this timer, `pr off`, and `pr on` map to
`-Action Timer -TimerAction Status|Disable|Resume`. Showing is read-only. Disable/Resume preview
until the exact operation is approved with `-Apply`. Turning it off affects future ticks, not an
active worker. Turning it on enables the existing trigger without resetting cadence or running
immediately. Neither clears a safety pause or removes history.

The task uses interactive logon for the current user, not elevation or saved passwords. Do not
claim it runs while that user is logged out. Overlapping ticks are ignored; a shared cycle lock
also prevents concurrent manual runs. Empty future watchlists are no-ops. Existing CLI authentication
must work in that scheduled environment; editor MCP access is not inherited. Use the existing
harness fallback/recovery controls against the explicit user-wide controller for paused work.