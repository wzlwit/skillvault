---
name: jarvis-metrics
description: Design Jarvis metrics and dashboards from existing Geneva/MDM metrics, Kusto queries, or logs. Use for /jarvis-metrics, legacy /jarvis-metrics-create, Jarvis dashboard creation, metric-source selection, pre-aggregation, dimensions, monitors, and CDS-style success/failure reporting. Overlaps with kpi-dashboard on dashboard/metric design and harness-report on Jarvis authoring; owns Jarvis metric-source plumbing and widget configuration rather than general dispatch or layout guidance.
argument-hint: '<signal-or-monitoring-goal>'
metadata:
  author: wzlwit
  version: null
---

# Jarvis Metrics and Dashboards

Turn an operational signal into a Jarvis metric, dashboard, and optional monitor. This is a
planning and configuration guide, not a Jarvis client, telemetry emitter, Kusto executor, or
alerting API.

## Choose the Metric Source

Define the signal and useful dimensions before opening Jarvis, then use the first source that
represents them cleanly:

1. **Geneva / MDM metric**: an existing application metric already emits the signal and dimensions.
2. **Kusto-to-Metrics**: an existing KQL query can calculate the signal, but no suitable direct
   metric exists.
3. **Logs-to-Metrics**: the signal exists primarily in application logs.
4. **New telemetry**: add or refactor application telemetry only when the preceding sources
   cannot represent the signal.

Check the existing Geneva account, namespace, metric names, emitting code, and dimensions before
rebuilding a direct metric from Kusto or logs.

## Define the Signal

Write down the numerator, denominator, success state, failure state, time window, and units. For
reliability reporting, keep success and failure as explicit measures so rates reconcile:

```text
total = success + failure
success_rate = success / total
failure_rate = failure / total
```

Use stable, bounded dimensions such as environment, geography, feature, version, status, and
categorized failure reason. Never put arbitrary request text, customer data, or full error
messages into dimensions; normalize them into categories such as `InvalidPayload`,
`InsufficientData`, `SystemFailure`, or `Other`.

## Convert Kusto or Logs

For Kusto-to-Metrics:

1. Start from the existing KQL and verify that it produces the defined signal.
2. Normalize or derive dimensions in KQL before conversion.
3. Map the query output to metric values and dimensions.
4. Configure the execution period and Jarvis pre-aggregation.
5. Validate the converted metric against the source query before building the dashboard.

Preserve the query's time semantics, filters, units, and null or missing-data behavior. Do not
invent a threshold or silently substitute a different query.

For Logs-to-Metrics, identify the structured fields and event categories that define the signal,
convert them to bounded dimensions, and document sampling, parsing, missing or duplicate events,
and aggregation. Prefer a direct Geneva metric or Kusto conversion when either gives a more
stable contract.

## Build the Dashboard

The usual UI flow is:

```text
Dashboard → … → + Dashboard
  → + Widget → chart type → Sources → Layer
  → Display / Parameters → Save
```

For each layer, configure the time range, data source, account, namespace, metric, sampling type,
dimensions, missing-data behavior, and resolution reduction. Use Display for legends, tooltips,
colors, and thresholds, and dashboard Parameters for reusable filters. Use multiple layers for
multiple counters in one chart and Advanced → Subquery for calculated values, documenting the
expression. Save or copy reusable widgets rather than recreating them. Chart types vary by product
and deployment; inspect the `+ Widget` menu instead of assuming a fixed list.

## Add Monitoring

Add monitoring only when Jarvis-native monitoring or alerting is explicitly requested. Creating a
report, query, or dashboard does not authorize monitor activation or IcM routing. Harness
monitoring uses `/harness-monitor`'s local JSON observation contract; a Jarvis-native monitor or
dashboard link is not an interchangeable input.

After validating dashboard values, add a monitor only when the service's operational requirements
define the condition. Connect it to the appropriate alert or IcM flow and record the owner,
evaluation window, threshold source, and missing-data behavior. Never derive production thresholds
from an illustrative example.

## Validation Checklist

Apply checks to the requested deliverables. Mark unrun live checks as unverified and monitor items
as not applicable when monitoring was not requested. A design-only specification or metric query
is not evidence that a dashboard has been saved or is readable in Jarvis.

- [ ] The measured signal, numerator, denominator, units, and time window are explicit.
- [ ] Existing Geneva/MDM metrics were checked before using a fallback source.
- [ ] Dimensions are bounded, useful for aggregation, and free of sensitive or high-cardinality text.
- [ ] KQL or log parsing preserves source semantics and missing-data behavior.
- [ ] Pre-aggregation matches the dashboard slices and requested resolution.
- [ ] Success/failure calculations reconcile with the underlying metric.
- [ ] The dashboard is saved and readable by its intended audience.
- [ ] Monitor thresholds and IcM behavior come from service requirements.

## Boundaries and Reuse

- This guide does not provide access to Microsoft-internal Jarvis documentation, credentials,
  telemetry libraries, Kusto clusters, or dashboard APIs. Confirm UI labels and supported source
  types in the target deployment. Keep internal identifiers, query results, and sensitive
  operational data out of public skill files and reports.
- `kpi-dashboard` owns platform-agnostic KPI selection, metric contracts, and layout for business
  dashboards. This skill owns Jarvis's metric-source choice (Geneva/MDM, Kusto-to-Metrics, or
  Logs-to-Metrics) and its pre-aggregation, widgets, layers, and monitors.
- `harness-report` coordinates artifact identity, capability checks, and delivery validation
  across platforms. Its `--type jarvis` route selects this guide; a Jarvis-bound query-only request
  can use `--type query` with the relevant source guidance, without creating a dashboard or
  converted metric. Pass back the agreed signal, stable artifact destination/ID, source bindings,
  checks, and any missing access or authoring capability.
- Only available authorized tools can create live artifacts; naming this skill does not install a
  client, execute KQL, or publish a report.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.
