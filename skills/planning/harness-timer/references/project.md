
# Harness Timer

This is the retained project preflight and legacy OS-timer reference. The current public
[scheduler contract](scheduler.md) owns command defaults and new schedules. Bare invocation is
read-only `list`. The shared scheduler calls the helper with `-Prepare -Action Set -IntervalDay 1`
to validate a runner definition only; that placeholder is never the saved schedule's cadence.
The remaining legacy Set/Status/Disable/Resume details support compatibility fixtures and exact
migration, not registration of new competing OS timers. Do not use bare setup examples below
as the current topic's default. Installed skill edits authorize no live schedule.

## Resolve and Schedule

1. Resolve the project, apply `/rules apply` and project instructions, and read the installed
   `harness` runtime guide. Keep that canonical dependency beside `harness-timer` in the same
   scope. Do not use an obsolete `hn-init` runtime merely because an old shortcut folder exists.
   During attended setup, follow its Script Permissions and Agent Fallback procedure before
   scripts: reuse approvals and request only missing command-scoped access. Resolve required
   authentication before enabling unattended execution. Agent-assisted investigation is not a
   registered schedule; do not substitute an ad-hoc agent run for the requested recurring target.
2. Resolve the requested topic from the table below. Bare `/harness-timer` selects `e2e`; an interval
   alone also selects `e2e`. Free-form topic requests must resolve to the existing runner or a
   concrete, reviewed flow. Clarify an ambiguous request; never substitute development silently.
3. Follow the runtime's Reuse or New procedure. Inspect matching instances with `-Action Status`
   and ask **Reuse (singleton) or New?** unless the request already states the choice. Show each
   instance's identity, ownership, status, purpose, cadence, and context before changing it.
   Recommend reuse for the same purpose; an unanswered choice creates/updates nothing. Do not
   ask again on recurring ticks or for an already explicit reuse/new request.
4. Inspect state and prerequisites. Offer `/harness init` for missing initialization. Follow Runner
   Inheritance for allowances instead of blocking on missing settings. The session can supply
   `-RunnerContextPath` with known compatible model/tool/resource values; the timer stores that
   non-secret path for its child command and reuses it on later Set/Resume. With no file, use
   project/native settings, not a fictional editor parent. Reuse references, tasks, and decisions;
   inheritance does not invent work, auto-eligibility, new grants, or approval to schedule.
5. Use an explicit positive interval in days, or reuse the single saved cadence of this exact
   target. If neither exists, ask the user for the interval. Do not invent a daily default, reuse
   an unrelated timer's cadence, or reinterpret multiple/custom triggers as an approved interval.
6. Preview the exact topic, instance name, task identity, cadence, runner action, phases/flow, and any existing
   schedule to replace. Show the helper's `operation` (Create or Update), `taskPath`, and `taskName`.
   The script defaults to `Set` and previews until `-Apply` is supplied.
   A direct scheduling request, including bare `/harness-timer`, authorizes applying that resolved
   operation after missing choices are answered, without another routine confirmation. Changes
   outside that request retain their own approval requirements.
7. Report the actual outcome, selected instance, target, interval, first-run timing, and blockers. Do not report a
   preview, unresolved setup choice, unsupported flow, or failed registration as a created schedule.

## Upsert Identity

Within a selected instance, `Set -InstanceMode Reuse` is an upsert. The unique scheduler identity
is the root task path `\` plus the deterministic task name below. These names retain the existing
unnamed singleton. `<project-id>` is the ID saved by `/harness init`, never a new ID per invocation.

| Purpose | Task name |
| --- | --- |
| Omitted topic, `e2e`, or `dev` | `SkillVault Harness <project-id>` |
| `review` | `SkillVault Harness <project-id> Review` |
| `test <flow> [environment]` | `SkillVault Harness <project-id> Test <flow> <environment>` |
| Named `monitor <name>` | `SkillVault Harness <project-id> Monitor <name>` |
| Custom topic or legacy monitor flow | `SkillVault Harness <project-id> Topic <topic> <flow> <environment>` |

`--new <name>` maps to `-InstanceMode New -InstanceName <name>` and appends ` Instance <name>`
to that topic's task name. New is create-only: an existing case-insensitive name is a conflict,
not permission to replace it. Use a stable name containing letters, digits, dots, underscores,
or hyphens, starting with a letter/digit. Confirm its purpose; never generate random duplicate names.

`--reuse` maps to `-InstanceMode Reuse`. Omit `--instance` for the singleton, or supply
`--instance <name>` (`-InstanceName`) to reuse a named instance. Reuse selects exactly that owned
schedule and preserves its saved cadence/context when omitted. A missing named instance cannot
be reused. When no matching schedules exist, the initial call can create the unnamed singleton.
Matching Set requests without InstanceMode return `NeedsInstanceChoice` in preview and reject
Apply before mutation. Status includes an `instances` list so the session can present the choice.

The interval, current time, and display prose are not part of this identity. For example,
`/harness-timer 1` followed by `/harness-timer 0.5 dev --reuse` updates the same E2E schedule to every 12 hours.
Explicit and default environments resolve to the same declared name; topic/name casing does not
create another target. Existing task names are matched without case sensitivity and retained.
An ownership-description mismatch blocks replacement rather than overwriting an unrelated task.

For repeated prose requests with the same purpose, offer the exact existing instance for reuse
or a distinctly named New instance. Do not rename the topic/flow/monitor to simulate another
instance. Different declared targets and named instances have separate identities; clarify
ambiguous purpose matches. Renaming is not an interval update or permission to migrate a schedule.

Reapplying Set updates the existing trigger and schedules the first run one interval from the
update time. It does not delete run history, task progress, or safety pauses. This is separate from
Resume, which enables the saved trigger without changing its cadence or starting an immediate run.

## Topics

| Request | Scheduled workflow |
| --- | --- |
| No topic, or `e2e` | Shared `Cycle`: select approved work, develop/fix/verify, validate and run declared tests, independently review, record outcomes |
| `dev` | Same tracked development cycle and timer identity as `e2e`; required test/review gates are not skipped |
| `review` | Shared independent `Review` of ahead commits and working changes against the resolved comparison base, with one fresh pass when no new findings appear; no development or publishing |
| `test <flow> [environment]` | Run that declared flow only, without an AI worker or task pickup |
| `monitor <name>` | Run one `/harness-monitor` declaration through the shared Monitor evaluator; separate collection status, health, episodes, and task proposals |
| `monitor <flow> [environment]` | Retained command-flow mode: run a reviewed health-check flow through the Test executor; do not silently convert existing schedules into named monitors |
| `<topic> <flow> [environment]` | Run that explicitly declared executable flow under a separate topic-labeled timer; unsupported adapters/workflows remain unresolved |

`test`, legacy monitor flows, and custom flow topics require a `/harness-test` declaration, verified executables,
directories and variables, a time budget, and explicit environment `allowScheduled: true`.
Omitted environment uses the flow's declared default. A topic label grants no additional access
or side effects; review the actual flow. These runs use the existing Test report/history format
and `test:<flow>:<environment>` safety target.

For a named monitor, read its `/harness-monitor` definition and use `-MonitorName <name>`, with no flow
or environment override. Require its own `allowScheduled: true`, source file, declared collector
budget, and approved directory/launcher/environment access. The current source is a local JSON
snapshot; no online collector or AI worker is implied. Each check can update incident evidence and
proposals, but never accepts proposals or creates tasks automatically. Its task name is
`SkillVault Harness <project-id> Monitor <name>` and its pause target is `monitor:<name>`.

Resolve monitor-versus-flow meaning from existing definitions and an explicit request. If both
match the same name, ask rather than guess; preserve the old `Topic monitor <flow> <environment>`
identity when managing a legacy flow. `-MonitorName` and `-TestFlow` are mutually exclusive.
Review uses inherited or verified/native model settings and read-only tool access, not development
write permissions. E2E/dev resolves missing allowances before checking scheduled validation.
Known caps bound execution; absent caps add no arbitrary timer limit. Independent review timers
retain the legacy OS time limit sized for two review sessions and do not use the development
`criticalReview` switch. Local snapshot restarts remain subject to that existing limit; setup does
not enlarge it implicitly. Their default does not request the optional security sub-skill.

## Default End-to-End Flow

Compose the relevant harness responsibilities through the shared runtime, not by blindly calling
every `/harness-*` skill on every tick:

1. Load rules, current task/reference context, and restriction/fallback gates.
2. Select an eligible existing task from the human/resume queues or approved automatic backlog.
3. Run bounded development, fix, or verification work for that task.
4. Execute configured validation and `testing.afterDev` flows against its workspace.
5. Run a fresh independent review and the configured critical pass when applicable.
6. Preserve reports, task status, queues, and failures/pauses on the existing board.

The runtime performs these phases directly; do not launch duplicate slash-command workers for
the same phase. With no eligible task it records no invented work and returns Idle. Each tick is
bounded; it does not exhaust the backlog or repair failures indefinitely.

`/harness init`, Graphify setup, `/harness-link`, task intake, `/harness-policy limits`, `/harness-policy fallback`, and `/harness-decision`
support setup/context or explicit configuration and decisions. Invoke their applicable workflows
when needed during attended setup, not as recurring mutations. Missing decisions remain open;
do not schedule automatic grilling, decision acceptance, policy changes, `/init`, publishing, or
recursive timer creation. Related reference-only skills do not supply executable integrations.
Unattended ticks never prompt for permissions/login or spawn an unconfigured agent fallback.
Retain the existing failure/pause outcome for attended recovery; do not widen access on a tick.

## Helper and Examples

Use the [legacy preflight helper](../scripts/harness-project-timer.ps1) from the canonical installation:

```powershell
& <hn-timer-folder>/scripts/harness-timer.ps1 -ProjectPath <root> -Action Set -Topic e2e -IntervalDay <approved-days>
& <hn-timer-folder>/scripts/harness-timer.ps1 -ProjectPath <root> -Action Set -Topic review -IntervalDay <approved-days>
& <hn-timer-folder>/scripts/harness-timer.ps1 -ProjectPath <root> -Action Set -MonitorName <name> -IntervalDay <approved-days>
& <hn-timer-folder>/scripts/harness-timer.ps1 -ProjectPath <root> -Action Set -Topic monitor -TestFlow <flow> -TestEnvironment <environment> -IntervalDay <approved-days>
& <hn-timer-folder>/scripts/harness-timer.ps1 -ProjectPath <root> -Action Status
& <hn-timer-folder>/scripts/harness-timer.ps1 -ProjectPath <root> -Topic review -InstanceMode Reuse -Apply
& <hn-timer-folder>/scripts/harness-timer.ps1 -ProjectPath <root> -Topic review -InstanceMode New -InstanceName second-review -IntervalDay <approved-days> -Apply
```

Append `-Apply` to execute an authorized Set/Disable/Resume after preview. With a single saved
cadence, Set can omit `-IntervalDay`. `-Flow` and `-Environment` alias the two Test parameters.
Existing `-TestFlow` calls without `-Topic` still select `test` for compatibility.

```text
/harness-timer
/harness-timer 0.5
/harness-timer dev
/harness-timer 1 review
/harness-timer 1 review --new second-review
/harness-timer 0.5 review --reuse --instance second-review
/harness-timer 0.5 test smoke localPPE
/harness-timer 0.5 monitor service-health
/harness-timer 0.25 monitor health local
/harness-timer status
/harness-timer status review
/harness-timer status monitor service-health
/harness-timer disable monitor health local
/harness-timer resume test smoke localPPE
/harness-timer status review --instance second-review
```

`status`, `disable`, and `resume` address the same topic/flow/environment and optional instance name as setup; omission
selects the E2E timer. Status is read-only. Disable affects future ticks without killing workers;
resume enables the saved trigger without an immediate run or a new interval. Set creates or
updates that target and schedules its first run one interval later. Zero is rejected; use
`/harness-dev`, `/harness-review`, `/harness-test run`, or `/harness-monitor check` for immediate execution. Missed ticks coalesce and
overlapping instances are ignored.

## Boundaries

E2E/dev reuses the original project development task. Review, each named monitor, and each flow topic have separate
identities, with optional named instances; creating one must not replace another. Multiple
schedules can target the same purpose, but all script execution still shares the project run lock
and each schedule retains IgnoreNew. A new schedule is not an independently writable task clone
or automatic parallel-agent orchestration. Additional agents use the host's supported instance
mechanism after the same reuse/new choice; concurrent writers need isolated workspaces.
Set/resume honor `/harness-policy limits` and reject paused targets, including mandatory post-dev flows.
Use `/harness-policy fallback` to investigate and explicitly resume a safety pause; timer actions and external
Windows task enabling never clear it. No worker/test command runs during timer preflight.

Do not touch unrelated schedules, elevate, request secrets through chat, or configure credentials.
If Windows requires privileges, report the blocker for the user to handle directly. Installing
skills or requesting `/harness init` or `/harness-decision` alone never creates a schedule. `schedule-manager`
remains the general task administration tool.