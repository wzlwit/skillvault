
# Harness Monitoring

Discover source-linked work candidates or evaluate structured health observations on the existing
harness. **No arguments only shows saved definitions, latest checks, candidates, incidents, and
proposals.** It does not collect data, initialize state, or create tasks or schedules.

Use `kind: discovery` and the [discovery contract](discovery.md) for ADO backlogs/saved queries,
local text folders, or normalized feeds from other approved adapters. URL/folder plus topic requests
belong here, not in a numeric metric schema. Discovery reads sources, filters candidates, and
retains source identity/revision and deferral status. `check` then assesses relevance and priority
against the declared service boundary; it does not finish by reporting raw keyword matches.
The read-only Auto verifier then checks current status and reconciles local evidence-backed
outcomes. Only current Relevant, verified-open candidates produce pickup proposals. Collection success alone is
not assessed readiness, proof of a defect, or execution permission.
The remaining metric-specific sections below apply to health monitors without `kind`.

Health monitoring reads one numeric observation from a local JSON file. Queries, Power BI measures,
and online dashboards can supply reviewed exports in that format; a visual dashboard is not a
numeric input or a work-discovery connector. Keep metric/filter/environment/window semantics intact.

## Start Here

1. Resolve the project and apply `/rules apply` and applicable instructions. Read the canonical
   `harness` runtime guide and [declaration contract](monitoring.md).
2. Choose discovery or health monitoring. For discovery, identify the exact source, topics,
   access method, and authoritative current status using its contract. For health, identify the
   existing query/export and healthy state; read its metric/filter and refresh semantics. Do not invent a threshold, source, credentials, or
   scheduling permission. Use `/harness-link` for relevant dashboard/query links; do not create a second
   reference register or copy raw telemetry into the board.
3. Require existing initialized harness state before declaration or checking. Missing state is
   an `/harness init` prerequisite, not permission to initialize as a side effect. Read-only inspection
   works before initialization. Health checks need no AI; discovery verification uses model auto.

## Commands

Use the shared `harness/scripts/harness.ps1` with the selected project root:

| Request | Helper action and behavior |
| --- | --- |
| `/harness-monitor` | `-Action Monitor`; show saved state only, including timestamps and pending proposals |
| `/harness-monitor declare <file>` | `-Action MonitorConfig -DefinitionPath <file>`; validate and preview named definitions |
| `/harness-monitor check` or `check all` | `-Action Monitor -AllMonitors`; collect all configured sources, assess/verify, reconcile and audit one complete or Partial batch |
| `/harness-monitor check <name>` | `-Action Monitor -MonitorName <name>`; collect, assess relevance, Auto-verify status, reconcile local outcomes, then rank proposals |
| `/harness-monitor accept <id>` | `-Action MonitorTask -Id <id>`; preview a `C-...` discovery candidate or `I-...` incident for explicit intake |

Declaration and task intake preview unless `-Apply` is supplied. Show the exact definitions or
proposal and require approval before applying with `-Actor <human-owner> -Reason <reason>`.
A reviewed `--apply` request authorizes that exact operation; obtain missing owner/reason details.
Do not accept unseen file changes after approval. Declarations upsert by name; unmentioned monitors
are preserved. Changing a previously observed metric/resource/environment/window/condition needs
a new monitor name so old incidents retain their meaning. Declarations do not run or schedule checks.

An explicit named check covers only that source. The all-source check continues collecting other
configured sources after one failure, preserves existing records, and returns `Partial` with
`complete: false` and no successful aggregate proposal list. Inspect per-source results and the
batch report; zero accepted candidates is not proof of complete review. Unverified semantics or
missing source access is visible, not success. Scheduled calls still require each source's approval.
Show `verifiedSubset` as a separate, explicitly incomplete manual selection, including fresh
health incidents validated under their own contract. Unavailable/unverified items remain excluded
from acceptance. Discovery relationships, fact authority, regression checks, and resumable coverage
use the shared [source-agnostic contract](discovery.md#related-sources-and-conflicts), not provider-specific rules.

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

Discovery candidates use the same acceptance command and task store. See the discovery contract
for source review, freshness, source priority, and actual blockers. Previously postponed items enter
the normal queue when accepted; postponement alone does not block them. The incident rules below remain specific
to numeric health breaches; do not require an ADO item or document to be Unhealthy.

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
target. Health checks run no AI worker; discovery verification runs the read-only Auto worker.
Neither creates tasks, chooses thresholds, fixes code, or publishes dashboards.
Cadence remains positive days, explicitly supplied or reused for that exact target, not an invented
default. Monitoring declarations and checks do not create schedules, and the default E2E timer
does not add monitoring automatically.

Existing monitor command-flow timers using `-TestFlow` retain their Test executor and identity.
Do not silently migrate them or reinterpret a name shared by a monitor and a flow. Use the timer
guide to resolve that ambiguity. Disabling a timer does not clear a safety pause or stop a worker.

## Storage and Scope

Layout-2 definitions use `.harness_sv/config/monitors.json`; direct edits and declaration commands
share that authoritative file. Latest observations, candidates, verification, and incident episodes
use `runtime/state.json`'s `monitoring` object. Monthly Markdown evidence uses the runtime history
directory and `board/history.csv` includes separate `monitor` and `health` columns. Legacy controllers
retain their flat configuration/state paths until explicit `/hn migrate`. Keep raw
telemetry in its owning source system and exported snapshots small; the collector saves only the
selected metric/window/identity and configured links, not arbitrary extra JSON or raw parser errors.

The configured current-work CSV is the single atomic materialized view of open tasks and pending discovery candidates.
New controllers use `current-<project>.csv`; existing controllers without `currentFileName` keep
`current.csv`. Use the shared resolver or the returned `current` path, not a monitor-specific filename.
It excludes terminal tasks and verified terminal/excluded candidates, avoids duplicate accepted
candidate rows, and sorts priority ascending then ID. `recordType` distinguishes task from candidate;
`sourceType` distinguishes ado, design, feed, health, and manual input. `sourceOwner`, `sourceState`,
`sourceObservedAt`, `evidenceStatus`, and `checkStatus` distinguish current facts from uncertainty or
a partial batch. Candidate rows do not create tasks or grant execution approval. The shared writer
validates row/source counts, required columns, identity uniqueness, and priority monotonicity before
atomic replacement. No collector or custom adapter writes a competing CSV schema.
Explicit topic-filtered exports use `current-<project>-<topic>.csv` under artifacts, through the
Harness current-view procedure. They are requested snapshots, not automatically split per-source
boards and not alternative authoritative queues.

Reuse `/harness-policy limits` directory/launcher/environment controls and `/harness-policy fallback` durable pause and
recovery actions. The current implementation shares the existing `testEnvironments` allowlist for
monitor environment labels and uses the approved `pwsh` launcher. Those controls are not an OS
sandbox, credentials boundary, or proof of the producer's data accuracy. Source paths and reference
notes must not contain secrets. The health snapshot reader retries no commands and provisions nothing.
The ADO discovery reader uses separately supplied read authentication; it does not sign in,
provision credentials, or modify ADO.

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