
# Harness Monitoring

Contents: Start Here; Commands (Start or Update Monitoring); Results and Incidents; Task Intake;
Scheduling; Storage and Scope; Related Work.

Discover source-linked work candidates or evaluate structured health observations on the existing
harness. **Alone shows saved definitions, latest checks, candidates, incidents, and proposals, then
offers the all-source check.** Showing does not collect data, initialize state, or create tasks or
schedules; the check runs only on a yes.

Use `kind: discovery` and the [discovery contract](discovery.md) for ADO backlogs/saved queries,
local text folders, or normalized feeds from other approved adapters. URL/folder plus topic requests
belong here, not in a numeric metric schema. Discovery reads sources, filters candidates, and
retains source identity/revision and deferral status. A check then assesses relevance and priority
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
   `harness-runtime` guide and [declaration contract](monitoring.md).
2. Choose discovery or health monitoring. For discovery, identify the exact source, topics,
   access method, and authoritative current status using its contract. For health, identify the
   existing query/export and healthy state; read its metric/filter and refresh semantics. Do not invent a threshold, source, credentials, or
   scheduling permission. Add relevant dashboard or query links as sources with `/harness-setup <link>`;
   do not create a second reference register or copy raw telemetry into the board.
3. Require existing initialized harness state before saving a declaration or checking. A missing
   harness is a prerequisite that `/harness-setup` offers to create, not permission to initialize
   as a side effect. The alone view's display works before initialization. Health checks need no
   AI; discovery verification uses model auto.

## Commands

Use the shared `harness-runtime/scripts/harness.ps1` with the selected project root:

| Request | Helper action and behavior |
| --- | --- |
| `/harness-monitor` | `-Action Monitor`; show saved state only, including timestamps and pending proposals, then offer the all-source check once |
| A yes to that offer, or a plain request to check every source | `-Action Monitor -AllMonitors`; collect all configured sources, assess/verify, reconcile and audit one complete or Partial batch |
| `/harness-monitor <name>` | `-Action Monitor -MonitorName <name>`; collect, assess relevance, Auto-verify status, reconcile local outcomes, then rank proposals; a complete check also runs that source's standing intake |
| `/harness-monitor <link, folder, or file> [--hold]` | Find or draft the declaration file, ask to save (saving after 1 minute without an answer), then offer a timer; see Start or Update Monitoring below |
| `/harness-monitor <name> <change> [--hold]` | Update that monitor's declaration file the same way |
| `/harness-monitor accept <id>` | `-Action MonitorTask -Id <id> -Apply -Actor <owner> -Reason <request>`; accept the named `C-...` discovery candidate or `I-...` incident at once and show the resulting task |
| `/harness-monitor auto` | `-Action MonitorAuto`; show each monitor's standing intake, worker, limits, last check, and worker tasks |
| `/harness-monitor auto <name> --worker <flow> [--every <duration>]` | `-Action MonitorAuto -MonitorName <name> -Flow <flow>`, plus `-MaxPerCheck <n>`, `-MaxAttempts <n>`, or `-SetupExitCode <code>...` when the request names those limits (defaults: 2 items per check, 2 attempts); show and ask once, then on a yes apply with `-Apply -Actor -Reason` and `/harness-schedule project <duration> monitor <name>` (default `1h`); hold without an answer |
| `/harness-monitor auto <name> off` | `-Action MonitorAuto -MonitorName <name> -Off`; show and ask once, then on a yes apply with `-Apply -Actor -Reason` and `/harness-schedule <id> off` for that monitor's timer; hold without an answer |

### Start or Update Monitoring

Text that names a link, folder, or file starts monitoring it, and a monitor name with a change
updates its declaration:

1. **Find the file.** Use a given declaration file. Otherwise search `.harness_sv/definitions/` for
   JSON files whose `monitors` cover that source or name; if several match, ask which one. A name
   that no saved monitor has but a draft there declares selects that draft. If none exists, draft
   `.harness_sv/definitions/monitor-<name>.json` from the request under the
   [health](monitoring.md) or [discovery](discovery.md) contract, starting from the saved
   declaration when updating one, naming the monitor and asking only for the source, scope, or
   threshold choices the request leaves open. Apply a requested change to that monitor in the file.
   Never invent a source, credential, or threshold.
2. **Ask to save.** Run `-Action MonitorConfig -DefinitionPath <file>` and show what changes: new or
   changed monitors, standing intake, and scheduling approval (`allowScheduled`). Ask **Save now**
   or **Hold** with the host's question tool; a request that already says save needs no question.
   - Save: run it again with `-Apply -Actor <owner> -Reason <reason>`, with the requesting owner as
     Actor and the request as Reason. Save exactly the file shown; if it changes first, show it again.
   - No answer, including a question tool that reports the owner unavailable: say in the reply that it
     saves in 1 minute unless told to hold, wait 1 minute, and save if no other reply has arrived. The
     Reason notes that it was saved without an answer.
   - Hold, from `--hold`, the request, or the answer: save nothing and keep the file. Save it later
     by replying save or by giving its file again.
3. **Offer a timer.** Unless the monitor already has a timer, end the reply by offering to check it
   on a timer: every `1h` (recommended), another duration, or no. Show the exact
   `/harness-schedule project <duration> monitor <name>` command and do not wait for an answer. A
   yes, in this reply or later, sets `allowScheduled: true` in the file and saves it again when it is
   not already set, because scheduled checks need it, then runs that command and applies it. Without
   a yes, start no timer.

Starting or updating a monitor runs no check: give its name to check it now, and use `auto <name>`
to work its items automatically. Saving a declaration, `accept`, and `auto` follow Ask Once in the
runtime guide.

Task intake through `accept <id>` acts at once, because the id names exactly what to accept: it
accepts with `-Apply -Actor <human-owner> -Reason <reason>` and shows the resulting task. Accept
exactly the proposal or incident named; when it no longer matches the board, such as a candidate
that changed or was already accepted, report that and accept nothing. Declarations add or replace
monitors by name; unmentioned monitors are preserved. Changing a previously observed
metric/resource/environment/window/condition needs a new monitor name so old incidents retain
their meaning. Declarations do not run or schedule checks.

The alone view lists `pendingDefinitions`: JSON files under `.harness_sv/definitions/` whose
monitors differ from the saved declarations, with each new or changed monitor. They include held
drafts, but also older files that later declarations passed; saving one of those would undo the later
change, so check it before saving it from its file.

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

Default response is `propose-task`; `report-only` suppresses proposals. Checks create tasks
automatically only for a discovery source with a declared [standing intake](discovery.md#standing-intake). One explicit `accept <incident-id>` reuses `/harness-dev` task storage and the `/harness-setup`
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
/harness-schedule project 1h monitor service-health
/harness-schedule
/harness-schedule <id> off
/harness-schedule <id> on
```

`project <duration> monitor <name>` selects the named monitor through the timer's
`-MonitorName service-health`, not `-TestFlow`; `/harness-schedule` alone shows each schedule's id
for `off` and `on`. The timer calls `Monitor -Scheduled` using the same collector/evaluator and pause
target. Health checks run no AI worker; discovery verification runs the read-only Auto worker.
Neither creates tasks, chooses thresholds, fixes code, or publishes dashboards.
The cadence is the duration given, such as `30m`, `1h`, or `1d`, or the one already saved for that
exact target, never an invented default. Monitoring declarations and checks do not create schedules,
and the default E2E timer does not add monitoring automatically.

Existing monitor command-flow timers using `-TestFlow` retain their Test executor and identity.
Do not silently migrate them or reinterpret a name shared by a monitor and a flow. Use the timer
guide to resolve that ambiguity. Turning a timer off does not clear a safety pause or stop a worker.

## Storage and Scope

Layout-2 definitions use `.harness_sv/config/monitors.json`; direct edits and declaration saves
share that authoritative file. Latest observations, candidates, verification, and incident episodes
use `runtime/state.json`'s `monitoring` object. Monthly Markdown evidence uses the runtime history
directory and `board/history.csv` includes separate `monitor` and `health` columns. Legacy controllers
retain their flat configuration/state paths until the layout conversion that `/hn-setup` alone
offers. Keep raw
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

Reuse the directory, launcher, and environment limits from `/harness-setup policy set limits <file>`
and the durable pause and recovery actions of `/harness-setup policy`. The current implementation
shares the existing `testEnvironments` allowlist for
monitor environment labels and uses the approved `pwsh` launcher. Those controls are not an OS
sandbox, credentials boundary, or proof of the producer's data accuracy. Source paths and reference
notes must not contain secrets. The health snapshot reader retries no commands and provisions nothing.
The ADO discovery reader uses separately supplied read authentication; it does not sign in,
provision credentials, or modify ADO.

## Related Work

- `/harness-dev test` invokes project test flows; this skill consumes measurements and manages breach episodes.
- `/harness-dev` owns task intake, and `/harness-setup` owns sources and evidence links; this skill proposes their inputs.
- `/harness-schedule` owns schedules; `/harness-dev` owns separately authorized investigation/implementation.
- `/harness-write` dispatches query/dashboard/report authoring to the selected platform workflow.
   It can prepare a verified JSON exporter only when requested; a report URL or completed design
   does not replace this skill's observation input or authorize saving or scheduling a monitor.
- `kpi-dashboard` shares metric-definition work, focusing on formulas, units, time windows,
   and presentation. This skill evaluates declared observations and owns incident proposals instead.

Installing this skill selects no live sources, conditions, schedules, or automatic task policy.