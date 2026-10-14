# Shared Scheduler Route

Use [the shared scheduler](scheduler.md) for `/harness-schedule refresh <duration>`. The approved
worker calls the installed refresh script with `-RunOnce`; it never enters that script's legacy
OS-task setup branch. An existing refresh Windows task must be converted before replacement;
`/harness-schedule` alone offers that conversion and otherwise only shows schedules. The following
compatibility guidance does not authorize a second scheduler.

# SkillVault Refresh Schedule

The refresh itself is `/skillvault-install refresh`; its operation guide
(`skillvault-install/references/refresh.md`) and the bundled
`scripts/skill-refresh.ps1` helper live in the installed `skillvault-install` skill.
`/harness-schedule refresh <duration>` uses a reviewed duration; an immediate refresh is
`/skillvault-install refresh`, never a zero-frequency schedule. Keep scope, pins, source
ownership, and cache rules. A refresh schedule saved before the helper moved keeps its cadence;
run `/harness-schedule refresh <duration>` once to point it at the moved helper.

Showing an old `SkillVault Source Refresh` Windows task reads it without invoking the refresh
script, which would otherwise configure a schedule. `refresh off` or `refresh on` for that old task
uses the existing `schedule-manage` procedure for that exact task after the required confirmation;
it neither changes cadence nor performs an immediate refresh. Show absence without creating it.

Never change unrelated timers, install missing dependencies, or invoke setup or grilling during a
scheduled tick.