# Shared Scheduler Route

Use [the shared scheduler](scheduler.md) for `set refresh <duration>`. The approved worker calls
the installed refresh script with `-RunOnce`; it never enters that script's legacy OS-task setup
branch. Existing refresh tasks require `migrate refresh` before replacement. Bare topic invocation
is read-only `list`. The following compatibility guidance does not authorize a second scheduler.

# SkillVault Refresh Schedule

The refresh itself is `/skillvault-installation refresh`; its operation guide
(`skillvault-installation/references/refresh.md`) and the bundled
`scripts/skill-refresh.ps1` helper live in the installed `skillvault-installation` skill.
`set refresh` uses a reviewed duration; an immediate refresh is
`/skillvault-installation refresh`, never a zero-frequency schedule. Keep scope, pins, source
ownership, and cache rules. A refresh schedule saved before the helper moved keeps its cadence;
run `set refresh <duration>` once to point it at the moved helper.

`status` reads the existing `SkillVault Source Refresh` Windows task without invoking the
refresh script, which would otherwise configure a schedule. `disable` or `resume` uses the
existing schedule-manager procedure for that exact task after the required confirmation;
it neither changes cadence nor performs an immediate refresh. Show absence without creating it.

Never change unrelated timers, install missing dependencies, or invoke setup or grilling during a
scheduled tick.