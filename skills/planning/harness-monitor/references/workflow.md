
# Harness Monitoring

Consume structured observations, evaluate declared conditions, and keep evidence-linked incident
proposals on the existing harness. **No arguments only shows saved definitions, latest checks,
incidents, and proposals.** It does not collect data, initialize state, or create tasks or schedules.

This first version reads one numeric observation per monitor from a local JSON file. Queries,
Power BI measures, APIs, and online dashboards can supply reviewed exports in this format; this
skill does not connect to them directly or scrape their visual presentation. Use the same metric,
filters, environment, and time window as the underlying report. Screenshots are not numeric input.

## Start Here

1. Resolve the project and apply `/rules apply` and applicable instructions. Read the canonical
   `harness` runtime guide and [declaration contract](monitoring.md).
2. Identify the existing query/export and expected healthy state. Read its actual metric/filter
   definitions and data-refresh semantics. Do not invent a threshold, source, credentials, or
   scheduling permission. Use `/harness-link` for relevant dashboard/query links; do not create a second
   reference register or copy raw telemetry into the board.
3. Require existing initialized harness state before declaration or checking. Missing state is
   an `/harness init` prerequisite, not permission to initialize as a side effect. Read-only inspection
   works before initialization. No AI model is needed for checks.

## Commands

Use the shared `harness/scripts/harness.ps1` with the selected project root:

| Request | Helper action and behavior |
| --- | --- |
| `/harness-monitor` | `-Action Monitor`; show saved state only, including timestamps and pending proposals |
| `/harness-monitor declare <file>` | `-Action MonitorConfig -DefinitionPath <file>`; validate and preview named definitions |
| `/harness-monitor check <name>` | `-Action Monitor -MonitorName <name>`; collect once, evaluate, and save a report/incident proposal |
| `/harness-monitor task <incident-id>` | `-Action MonitorTask -Id <incident-id>`; preview the existing proposal for explicit intake |

Declaration and task intake preview unless `-Apply` is supplied. Show the exact definitions or
proposal and require approval before applying with `-Actor <human-owner> -Reason <reason>`.
A reviewed `--apply` request authorizes that exact operation; obtain missing owner/reason details.
Do not accept unseen file changes after approval. Declarations upsert by name; unmentioned monitors
are preserved. Changing a previously observed metric/resource/environment/window/condition needs
a new monitor name so old incidents retain their meaning. Declarations do not run or schedule checks.

## Results and Incidents

| Situation | Result |
| --- | --- |
| Fresh valid observation, condition false | Collection Succeeded; health Healthy |
| Fresh valid observation, condition true | Collection Succeeded; health Unhealthy; open/reuse its incident and proposal |
| Stale, missing, future, wrong-identity, or invalid metric/window | Health Unknown, never a healthy default; leave open incidents open |
| Malformed JSON, collection error, or timeout | Health Unknown with failure evidence; honor fallback failure/pause policy |
| Same breach on later checks | Keep one incident/proposal and update latest evidence, not one task per tick |
| Fresh recovery, then a later breach | Record recovery without completing a task; open a new episode for the next breach |
| Run lock busy or target paused | Launch no collector; report Busy or PolicyPaused |

The comparison operator describes the **breach**, not the healthy condition. Observations must
match resource, environment, metric, and declared window length. Fresh export time does not make
an old measurement fresh; use the measurement window end. Previously accepted newer windows
cannot be replaced by older ones. An already saved status is not proof of current health: show
its measurement/check timestamps and run a fresh check when current health is needed.

Collection success and service health are separate. Repeated unhealthy signals do not increment
fallback failed-run counts or pause a working monitor. Stale/unavailable inputs are Blocked/Unknown;
actual collection failures count toward the configured threshold. Timeouts pause `monitor:<name>`;
detected restriction mismatches pause the project. Check reports for the exact outcome, not just
the collector's exit code.

## Task Intake

Default response is `propose-task`; `report-only` suppresses proposals. Checks never create tasks
automatically. One explicit `task <incident-id>` acceptance reuses `/harness-task` storage and `/harness-link`
evidence links, with an episode-specific source identity, so repeat acceptance returns the same task.
Accept only an open proposal backed by a fresh latest Unhealthy observation. Stale or Unknown
evidence requires another check. Existing linked task IDs remain available after recovery.

New tasks are `verify`, risk Unknown, and `autoEligible: false`. Their purpose is to investigate
and establish a cause, not to assume that a metric breach is a code defect. Do not invent a code
scope, downgrade risk, enable automatic fixes, or launch `/harness-dev`. An accepted proposal does not
authorize execution. Later checks update incident evidence and its task reference, never the task's
status or contract. Signal recovery alone does not complete an investigation or prove a fix worked.

## Scheduling

After approving `allowScheduled: true` in that monitor definition, use:

```text
/harness-timer 0.5 monitor service-health
/harness-timer status monitor service-health
/harness-timer disable monitor service-health
```

These examples select the named monitor through the timer helper's `-MonitorName service-health`,
not `-TestFlow`. The timer calls `Monitor -Scheduled` using the same collector/evaluator and pause
target. It does not run an AI worker, create tasks, choose thresholds, or publish dashboards.
Cadence remains positive days, explicitly supplied or reused for that exact target, not an invented
default. Monitoring declarations and checks do not create schedules, and the default E2E timer
does not add monitoring automatically.

Existing monitor command-flow timers using `-TestFlow` retain their Test executor and identity.
Do not silently migrate them or reinterpret a name shared by a monitor and a flow. Use the timer
guide to resolve that ambiguity. Disabling a timer does not clear a safety pause or stop a worker.

## Storage and Scope

Definitions use `.harness_sv/config.json`'s `monitoring.monitors`. Latest observations and incident
episodes use `state.json`'s `monitoring` object; normal run history and Markdown evidence stay on
the configured board. `history.csv` includes separate `monitor` and `health` columns. Keep raw
telemetry in its owning source system and exported snapshots small; the collector saves only the
selected metric/window/identity and configured links, not arbitrary extra JSON or raw parser errors.

Reuse `/harness-policy limits` directory/launcher/environment controls and `/harness-policy fallback` durable pause and
recovery actions. The current implementation shares the existing `testEnvironments` allowlist for
monitor environment labels and uses the approved `pwsh` launcher. Those controls are not an OS
sandbox, credentials boundary, or proof of the producer's data accuracy. Source paths and reference
notes must not contain secrets. The snapshot reader retries no commands, provisions nothing, and
does not authenticate to any online service.

## Related Work

- `/harness-test` invokes project test flows; this skill consumes measurements and manages breach episodes.
- `/harness-task` owns task intake, and `/harness-link` owns evidence links; this skill proposes their inputs.
- `/harness-timer` owns schedules; `/harness-dev` owns separately authorized investigation/implementation.
- `/harness-report` dispatches query/dashboard/report authoring to the selected platform workflow.
   It can prepare a verified JSON exporter only when requested; a report URL or completed design
   does not replace this skill's observation input or authorize monitor declaration/scheduling.
- `kpi-dashboard` shares metric-definition work, focusing on formulas, units, time windows,
   and presentation. This skill evaluates declared observations and owns incident proposals instead.

Installing this skill selects no live sources, conditions, schedules, or automatic task policy.