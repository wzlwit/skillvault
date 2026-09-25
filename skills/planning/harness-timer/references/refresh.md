# Shared Scheduler Route

Use [the shared scheduler](scheduler.md) for `set refresh <duration>`. The approved worker calls
the installed refresh script with `-RunOnce`; it never enters that script's legacy OS-task setup
branch. Existing refresh tasks require `migrate refresh` before replacement. Bare topic invocation
is read-only `list`. The following compatibility guidance does not authorize a second scheduler.

# SkillVault Refresh Schedule

Delegate explicit refresh scheduling to the `skillvault-refresh` bundle's operation guide and existing
`scripts/skillvault-fresh.ps1` helper. `schedule` uses its reviewed positive interval; the legacy
one-day default applies only to an explicit request that omits it. `run` is a separate immediate
refresh, never a zero-frequency schedule. Keep scope, pins, source ownership, and cache rules.

`status` reads the existing `SkillVault Source Refresh` Windows task without invoking the
refresh script, which would otherwise configure a schedule. `disable` or `resume` uses the
existing schedule-manager procedure for that exact task after the required confirmation;
it neither changes cadence nor performs an immediate refresh. Show absence without creating it.

There is no central-heartbeat migration here. This guide calls the refresh owner directly;
`skillvault-refresh schedule` does not route back through harness-timer. Never change unrelated timers,
install missing dependencies, or invoke setup or grilling during a scheduled tick.