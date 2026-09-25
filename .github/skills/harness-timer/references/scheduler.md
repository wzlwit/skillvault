# Scheduler

Use the bundled [timer dispatcher](../scripts/harness-timer.ps1) for attended commands and
[heartbeat](../scripts/harness-heartbeat.ps1) for the single user-wide Windows task. PowerShell 7
is required. No install, bare command, preview, or source edit enables a live schedule.

## Commands

| Command | Mapping |
| --- | --- |
| `list` | `-Action List -ProjectPath <selected-root>`; `--all` explicitly lists all registered projects |
| `list heartbeat` | `-Action List -Target heartbeat`; read the user-wide baseline without inspecting OS tasks |
| `set heartbeat [<duration>]` | `-Action Set -Target heartbeat -Interval <duration>`; settings only, preview unless approved with `-Apply` |
| `set project <duration>` | `-Action Set -Target project -ProjectPath <root> -Interval <duration>` |
| `set pr <duration>` | `-Action Set -Target pr -Interval <duration>`; one whole-watchlist target |
| `set refresh <duration>` | `-Action Set -Target refresh -Interval <duration>`; one global latest-copy target |
| `set maintenance` | `-Action Set -Target maintenance`; enable the Saturday window only on apply |
| `disable <id>` / `resume <id>` | `-Action Disable|Resume -Id <id>` within the selected project, or explicit `-All` |
| `clean` | `-Action Clean -ProjectPath <root>`; preview stale schedules, never run-history deletion |
| `clean --retire <id>` | `-Action Clean -RetireId <id>`; explicitly retire and disable one selected schedule |
| `clean --delete-stale` | `-DeleteStale`; removal remains previewed until approved with `-Apply` |
| `migrate <target>` | `-Action Migrate -Target project|pr|refresh`; inspect one exact legacy OS task |

`--apply` maps to `-Apply` after the user has approved the displayed targets or the saved automatic
maintenance policy. `status` and `help` alias read-only `list`. An explicit old topic/duration
setup request routes to `set`; bare `/hn-timer` no longer requests setup. Do not invent a duration
when a new work schedule has none. Legacy `-IntervalDay` values still mean fixed days.

Use `/harness clean [--policy <file>] [--apply]` for historical data or retention settings; the
installed harness runtime guide's History Cleanup section owns that contract. The former timer
`clean --policy <file>` route delegates there for compatibility, without running cleanup.

Project target arguments retain `-Topic e2e|dev|review|test|<declared-topic>`, `-TestFlow`,
`-TestEnvironment`, and `-MonitorName`. `--new <name>` maps to `-InstanceMode New -InstanceName`,
and `--reuse` to `-InstanceMode Reuse`. Confirm **Reuse (singleton) or New?** for matching
schedules; unanswered choices create nothing. New requires a distinct stable name. PR and refresh
remain singleton logical targets, not per-watch or per-repository schedules.

## Scope and Execution

Reuse Root selected through `/harness root` and pass `-ProjectPath` explicitly. Project schedule
definitions, interval, nextDue, enabled state, and active claims live in the resolved control's
`schedules.json`; `schedules.lock` protects that file. New control is `<root>/.harness_sv`;
recognized legacy SkillVault controllers remain at `.harness` without migration.

The default user-wide scheduler root is `~/.copilot/skillvault/scheduler`. Its `schedules.json`
holds project registrations, the PR/refresh logical schedules, shared maintenance settings,
and the routine `heartbeatInterval` baseline;
`scheduler.lock` serializes dispatch. `receipts/<job-id>.json` holds only that job's latest process
result, overwritten on its next completion, not another growing run-history store. Project run
evidence stays in its board history. Unavailable registrations are reported, never treated as empty.

All changes to the one OS task go through `Sync-HarnessHeartbeat`. Its stable name includes the
current user's SID. The routine baseline is `1d`, shortened automatically by enabled fixed-duration
jobs and capped at 30 minutes while a worker result is outstanding. The next trigger honors any
earlier pending job deadline or enabled maintenance start; the repeating fallback uses that same
adaptive interval. With only maintenance enabled, it waits for Saturday 08:30 with a weekly fallback;
with no enabled/active work or maintenance, the heartbeat is disabled. Machine wake remains off.
Conditional permission below does not change that setting automatically.
The scheduler starts below-normal-priority workers and returns;
the OS task does not remain busy for the whole development run. It uses current-user Interactive
logon and Limited privilege: signed-out execution is not enabled and requires a separate approved
credential/service design. No password, token extraction, auto-login, or elevation is attempted.

The baseline is a scheduling setting, not an agent profile. Routine ticks do not invoke a model.
Scheduled harness AI workers retain their existing explicit/inherited runner configuration and
verified-profile selection; their native fallback is `auto` with intelligence-oriented routing.
PR review retains its own approved profiles. Changing the baseline changes none of these settings.

The project adapter reuses [project preflight](project.md) for model/tool limits, approved test
environments, runner availability, and durable pauses. PR reuses its installed readiness checks;
refresh uses its existing `-RunOnce` path. Definitions select only those adapters, not an arbitrary
command runner. Each tick reuses the saved target and context; it never asks questions or invents
work, eligibility, permissions, thresholds, or missing credentials.

One job never overlaps itself. Controllers or linked coding roots that intersect are serialized;
independent approved project roots can proceed together. Refresh is exclusive because it replaces
shared installed helpers. Existing per-controller/PR run locks and worker budgets remain mandatory.
Shared ownership also coordinates manual harness runs and runtime replacements outside the
heartbeat. The heartbeat wrapper holds runtime/dependency read claims while it dispatches or
waits for a child; a self/dependency update may therefore defer until that wrapper is idle.
An uncertain child termination retains its claim. Explicit stopped-worker schedule recovery
clears only the matching inactive wrapper claim, not controller safety pauses.
An uncertain claim, lost worker, or invalid receipt disables that schedule until attended recovery.
Resume with `-ConfirmStopped` verifies the recorded process is no longer live; it does not clear
the underlying harness safety pause or recover interrupted task state on the user's behalf.

The heartbeat checks declared executable dependency interfaces during runtime admission. Refresh
setup/resume also checks the selected adapter, and execution claims and checks the actual saved
adapter before invoking it. `structured-refresh: 1` is required for receipt and retry transport;
matching package versions or ownership markers do not imply that support. A mismatch blocks work
and identifies the companion update set without installing it or retrying it as temporary Busy.

## Heartbeat Baseline

Use `set heartbeat 12h` to change the routine baseline, or `set heartbeat 1d` to restore the
default. Omitting the duration reuses the saved value. This target is user-wide, not a new logical
job; it does not need a project runner or choose a Reuse/New job identity. Preview shows the old
and requested baseline. Applying persists it and synchronizes the owned OS heartbeat without
changing job intervals, anchors, nextDue, enabled states, or maintenance. Inspection and preview
write nothing. Older state without `heartbeatInterval` reads as `1d` without being rewritten.

The baseline accepts fixed `m/h/d` durations of at least one minute. Job intervals still support
calendar `n/y` and shorter best-effort durations; calendar jobs contribute their actual nextDue,
not an approximate month/year length. Windows heartbeat repetition is clamped to at least one minute.

When ordinary work is enabled or active, synchronization uses the shortest of the saved baseline,
enabled non-recovery fixed job intervals, and 30 minutes when any active claim needs reconciliation.
An outstanding refresh result temporarily caps reconciliation at one minute so its first retry
deadline is not delayed by the ordinary active-worker cap.
It then selects an earlier pending due time or maintenance start if present. Applied job setup,
disable/resume, cleanup, baseline changes, and each completed tick resynchronize automatically.
Disabling the fastest job restores the slower interval unless active work still needs checking.
An earlier deadline never causes other jobs to run before their own due times.

During a tick, overdue jobs found unavailable or blocked by conflicting roots are reported in
`deferred`. Their nextDue and anchor remain unchanged. For that tick's re-arm only, those overdue
deadlines do not request another one-minute wake; the adaptive fallback provides the next recheck,
or another job's earlier deadline can trigger it. They are reconsidered normally on the next tick,
without invented runs, automatic recovery, or a second retry queue. Already due work that has not
been checked still receives the existing near-term trigger after a configuration change.

Successful synchronization returns `nextWake` and the effective `fallbackSeconds`; list shows the
configured baseline, not a claim that the live OS task has already adopted this source version.
Source edits and installation alone never perform a live rollout. A longer idle fallback reduces
routine checks but can delay detection of conditions with no earlier scheduled deadline; it does
not promise model-cost savings or real-time dispatch.

## Refresh Contention Retries

Scheduled refresh permits three additional attempts for targets blocked by temporary `Busy`
ownership: wait one minute, then ten minutes, then thirty minutes after the preceding attempt
finishes. Nominal retry times are 1, 11, and 41 minutes after the initial result; process time,
conflicting work, machine availability, and Windows trigger precision can make them later.

The worker records a structured receipt and exits. Completion releases its active job slot,
saves `refreshRetry` on that existing logical job, and re-arms the shared heartbeat. No worker
sleeps through the delay and no second task or scheduler is created. If completion races the
scheduler lock, the next tick collects the receipt. Ordinary conflict checks still apply to
each attempt; other jobs may run between retries.

Retry only the deferred target names, original Git source identity/tree revision, and unchanged
installation metadata. A source revision, target metadata, pin, or selected-root change ends
that target's retry chain rather than silently adopting new work. Successful or unchanged targets
drop out, while unrelated failures and terminal deferrals remain visible. Missing source revision,
`NeedsRecovery`, `NeedsTransition`, self-owned or heartbeat-parent-owned dependencies, and actual
copy/Git failures are not retryable. Never stop workers, clear pauses, or infer legacy idleness.

The third unsuccessful retry records `Deferred` with exhaustion and returns to the configured
regular refresh cadence. It does not disable that independently approved periodic schedule or
create an endless retry chain. The regular anchor is preserved; elapsed regular ticks coalesce.
Disabling an idle job or explicitly changing its definition cancels its pending retry. Uncertain
worker termination still disables the schedule for explicit recovery.

This applies only to the existing scheduled global-refresh route. Manual one-shot installation
or refresh does not create a background retry job. Source edits do not install these helpers or
enable a refresh schedule. Agent and named-test retry policies are unchanged.

## Durations

Use positive `m`, `h`, `d`, `n`, or `y`: minutes, hours, fixed 24-hour days, calendar months, and
calendar years. Minutes/hours/days support decimals, at least one second; calendar units require
whole numbers. The Windows wakeup has minute precision, so very short cadences are best-effort,
not a real-time guarantee. Omission reuses the exact saved cadence; unitless new values are rejected.

Intervals are anchored start-to-start. Missed ticks coalesce into at most one due run, then nextDue
advances past now. Calendar arithmetic uses the original anchor, avoiding Jan-31 -> Feb-28 ->
Mar-28 drift. Save the system timezone at creation. Clamp month-end/leap-day to the valid day;
for a DST gap use the first valid minute and for a repeated wall time choose the earlier occurrence.
These are deterministic scheduling rules, not implicit permission to change existing triggers.

## Maintenance

Default automatic window: **Saturday 08:30 inclusive to 09:00 exclusive**, saved local timezone.
Enable with `set maintenance --apply`; installing never enables it. The existing heartbeat handles
the window, so there is no second OS task. Run at most once per window, before launching newly due
work, and skip active/interrupted controllers. Without a necessary, configured wake request, a
sleeping/offline machine misses that window; it does not run cleanup later at an inconvenient
time. Routine cleanup remains local script work without an AI call, network scans, builds,
tests, commits, or automatic worktree deletion. A partial run stays visible; it is not retried
in a tight loop that morning.

The heartbeat checks stale schedules, then delegates historical data to the same
`Invoke-HarnessHistoryCleanup` implementation used by `/harness clean`. It selects registered
project/PR controllers only, respects a project's `maintenance.enabled: false`, and retains
the owner's evidence protections and runtime locks. No competing retention implementation or
new maintenance topic is introduced.

Installation updates use short-lived transactions and keep no completed version archives.
Maintenance does not enumerate, retain, or prune installation backups. The Saturday window and
harness-history protections remain unchanged; manual timer `clean` stays schedule-only. Existing
obsolete skill/archive removal is attended, explicitly scoped work, not a new maintenance job.

### Conditional Capabilities

Default permission: machine wake and AI assistance are both allowed when necessary. This is
permission, not automatic activation or an obligation to use either capability on every run.

| Capability | Necessary Use |
| --- | --- |
| Machine wake | Identified maintenance work must run in the approved window and cannot reasonably wait for the machine to be awake. No known work means no wake request. |
| AI assistance | A specific maintenance question or failure needs interpretation that deterministic checks cannot provide. Use existing authorized evidence, runner context, permissions, and budgets. |

Routine retention and stale-schedule checks need neither capability. Reuse this conditional
approval once a concrete need is established; stricter project/parent denials still apply.
Keep the Saturday window, signed-in execution, and existing scope. Any required wake configuration
is a targeted change to the owned task through its scheduler; do not enable wake for every
routine heartbeat merely to cover maintenance, alter system-wide power settings, or touch
unrelated tasks. Verify actual OS settings before claiming wake is enabled.

AI may explain evidence or recommend next steps; it cannot expand cleanup candidates, authorize
deletion, clear safety pauses, or mark failed work successful. If a required runner or scoped
configuration is unavailable, report the need as pending rather than inventing it. The current
deterministic heartbeat remains no-wake and script-only until a concrete execution change is
configured; these permissions alone reconfigure no live task and launch no AI process.

## Stale Schedules

Stale means a verified removed declaration or explicitly retired job, not idle, disabled,
overdue, failed authentication, an unavailable drive, or an empty backlog. Confirm ownership;
disable first and retain a 30-day grace. `--delete-stale --apply` explicitly approves deletion.
Automatic maintenance may disable verified stale jobs and prune eligible history but never deletes
OS task definitions. Reappearing declarations reset stale age without silently re-enabling work.

## Migration

Preview exact legacy task name/path, description, executable, literal arguments, repetition,
enabled state, and next run. Preserve selected Root and instance identity. Unsupported/custom
triggers, dynamic arguments, changed ownership, or a running task block migration rather than
being guessed. Disable and verify the old task before enabling its replacement. If registration
fails, restore the old enabled state only when no active replacement was created. Keep the old
disabled definition for recovery; confirmed cleanup can remove it after 30 days only if unchanged.

Skill installation migration is separate: display source/copy differences and approve exact forced
replacements. Do not replace scripts still used by active workers. Existing records are not moved
when the storage namespace changes. PACS and all unrelated timers remain unchanged. A successful
fixture proves local logic, not live authentication or a completed live rollout.