# Monitor Declarations

Import only a `monitors` array with `/harness-monitor declare <file>`. This is a preview; save the
reviewed declaration with explicit approval, owner, and reason. The example's names, values, and
paths are illustrative, not installed configuration or recommendations for a real service.

```json
{
  "monitors": [
    {
      "name": "service-health",
      "source": { "type": "json-file", "path": "observations/service-health.json" },
      "resource": "example-api",
      "environment": "local",
      "metric": "error-percent",
      "windowMinutes": 5,
      "maxAgeMinutes": 10,
      "maxMinutes": 1,
      "condition": { "operator": "gt", "threshold": 2 },
      "response": "propose-task",
      "allowScheduled": false
    }
  ]
}
```

| Field | Meaning |
| --- | --- |
| `name` | Stable monitor identity using letters, digits, dots, underscores, or hyphens |
| `source` | Only `json-file` is supported; path resolves against the project unless absolute |
| `resource`, `environment`, `metric` | Exact expected observation identity; environment uses the safe name format |
| `windowMinutes` | Positive finite expected measurement-window duration |
| `maxAgeMinutes` | Positive finite maximum age of the measurement window end |
| `maxMinutes` | Positive finite collector timeout, also capped by `maxProcessMinutes` restrictions |
| `condition` | Numeric breach condition: `gt`, `ge`, `lt`, `le`, `eq`, or `ne`, plus finite threshold |
| `response` | Optional `propose-task` default or `report-only`; no automatic intake option |
| `allowScheduled` | Optional boolean, false when omitted; independent of timer registration |
| `referenceId` | Optional active `/harness-link` ID pointing to a dashboard, query, or source guide |

All nonoptional fields must be supplied. Unknown declaration/source/condition fields are rejected.
No numeric defaults are guessed. `monitors` upserts by name and preserves unmentioned definitions;
an empty array removes nothing. Stop future checks with the exact timer's Disable action and/or
explicit monitor pause, not by deleting incident state. Omitted optional fields on a replacement
return to their defaults, so review permission/response changes before applying.

Once any observation is saved, use a new name for changed resource/environment/metric/window or
threshold/operator. Old incidents stay under the old meaning. A source-path or freshness-budget
update can reuse the name if the measured contract is unchanged; scheduling changes still require
approval and never resume a paused target. Policy updates are rejected while a runner owns the
project lock or an interrupted active marker remains.

## Observation Format

The query/export producer writes one JSON object, not a table, arbitrary log, or screenshot:

```json
{
  "resource": "example-api",
  "environment": "local",
  "metric": "error-percent",
  "value": 3.5,
  "windowStart": "2026-09-15T10:00:00Z",
  "windowEnd": "2026-09-15T10:05:00Z",
  "observedAt": "2026-09-15T10:05:30Z"
}
```

`value` must be a JSON number. Null, strings, booleans, nonfinite values, and absent data do not
mean zero. Units are part of the metric contract; do not compare a fraction with a percentage
threshold. Perform aggregation/filtering in the verified producer, not by guessing from a chart.

Times require explicit timezones, with `windowStart < windowEnd <= observedAt <= check time`.
The window duration must equal `windowMinutes`. Its end, not the export's file timestamp or
`observedAt`, determines freshness. Preserve the measurement time when re-exporting or refreshing
a cached dashboard. A window older than the last accepted one is Unknown; a same-window corrected
value may be accepted after the normal validation. Extra input fields are not retained in reports.

Publish snapshots atomically using the producer's existing tools when possible. A partial write
or malformed JSON produces Unknown with collection failure, not recovery. Missing files and
invalid/stale metrics/windows produce Blocked/Unknown. The reader does not infer provider
credentials or verify a deployed service version from local code; include correct resource and
environment identity in the producer's tested contract.

## Episode and Task Contract

A healthy-to-unhealthy transition (including the first valid breach) opens one incident. Further
breaches reuse it; a valid healthy reading records recovery. Unknown readings leave that episode
open. A later breach after recovery opens a new incident even for the same report URL.

Each proposal contains the incident ID, investigation title/scope/acceptance, latest evidence,
and an episode-specific `harness-monitor://<project-id>/<incident-id>` source identity. Explicit
task acceptance uses the existing task/reference helpers and stores their IDs on the incident.
Repeated acceptance returns the existing task rather than adding another. The first report link
is stable; subsequent checks update its reference note with latest evidence. Recovered episodes
and completed/cancelled tasks are not automatically reopened or closed by a metric reading.

## Helper Examples

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action Monitor
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action MonitorConfig -DefinitionPath monitors.json
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action Monitor -MonitorName service-health
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action MonitorTask -Id I-001
```

Apply reviewed declarations or task acceptance with `-Apply -Actor <owner> -Reason <reason>`.
`check` explicitly saves run/incident evidence, so it has no preview flag. No-argument inspection
reads saved values only. Accepting a task still requires fresh Unhealthy evidence at that time;
inspection may show an older pending proposal without authorizing intake.

For scheduling, the timer helper uses `-MonitorName service-health -IntervalDay <days>`; preview
before Apply. Its task identity is `SkillVault Harness <project-id> Monitor <name>`, separate from
existing `Topic monitor <flow> <environment>` command-flow timers. Fallback uses `monitor:<name>`.