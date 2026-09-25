---
name: jarvis-metrics
description: Design Jarvis metrics and dashboards from existing Geneva/MDM metrics, Kusto queries, or logs. Use for /jarvis-metrics, legacy /jarvis-metrics-create, Jarvis dashboard creation, metric-source selection, pre-aggregation, dimensions, monitors, and CDS-style success/failure reporting. Overlaps with kpi-dashboard on dashboard/metric design and harness-report on Jarvis authoring; owns Jarvis metric-source plumbing and widget configuration rather than general dispatch or layout guidance.
argument-hint: '<signal-or-monitoring-goal>'
metadata:
  author: wzlwit
  version: null
---

# Jarvis Metrics and Dashboards

Use this guide to turn an operational signal into a Jarvis metric, dashboard, and optional
monitor. It is a planning and configuration guide, not a Jarvis client, telemetry emitter,
Kusto executor, or alerting API.

## Choose the metric source

Define the signal and useful dimensions before opening Jarvis. Then choose the first available
source in this order:

1. **Geneva / MDM metric**: reuse an existing application metric when the signal and dimensions
   are already emitted.
2. **Kusto-to-Metrics**: use this when the required information exists in Kusto and an existing
   KQL query can calculate it, but no suitable direct metric exists.
3. **Logs-to-Metrics**: use this when the signal exists primarily in application logs.
4. **New telemetry**: add or refactor application telemetry only when the preceding sources
   cannot represent the signal cleanly.

Do not rebuild a direct metric with Kusto or logs without checking the existing Geneva account,
namespace, metric names, emitting code, and dimensions first.

## Define the signal

Write down the numerator, denominator, success state, failure state, time window, and expected
units. For reliability reporting, keep success and failure as explicit measures so a rate can be
checked as:

```text
total = success + failure
success_rate = success / total
failure_rate = failure / total
```

Use stable, bounded dimensions such as environment, geography, feature, version, status, and
categorized failure reason. Do not put arbitrary request text, customer data, or full error
messages into dimensions; normalize them into categories such as `InvalidPayload`,
`InsufficientData`, `SystemFailure`, or `Other`.

## Configure Kusto-to-Metrics

When Kusto is the source:

1. Start from the existing KQL and verify that it produces the defined signal.
2. Normalize or derive dimensions in KQL before conversion.
3. Map the query output to metric values and dimensions.
4. Configure the execution period and Jarvis pre-aggregation.
5. Validate the converted metric against the source query before building the dashboard.

Preserve the query's time semantics, filters, units, and null or missing-data behavior. Do not
invent a threshold or silently substitute a different query.

## Configure Logs-to-Metrics

When logs are the source, first identify the structured fields and event categories that define
the signal. Convert them to bounded metric dimensions and document sampling, parsing, missing
events, duplicate events, and aggregation behavior. Prefer a direct Geneva metric or a Kusto
conversion when either provides a more stable contract.

## Build the Jarvis dashboard

The usual UI flow is:

```text
Dashboard → … → + Dashboard
  → + Widget → chart type → Sources → Layer
  → Display / Parameters → Save
```

For each layer, configure the time range, data source, account, namespace, metric, sampling
type, dimensions, missing-data behavior, and resolution reduction. Use Display for legends,
tooltips, colors, and thresholds. Use dashboard Parameters for reusable filters.

Use multiple layers for multiple counters in one chart. Use Advanced → Subquery for calculated
values and document the expression. Save or copy reusable widgets rather than recreating them.
The available chart types are product- and deployment-specific; inspect the `+ Widget` menu
instead of assuming a complete fixed list.

## Add monitoring

Use this section only when Jarvis-native monitoring or alert configuration is explicitly requested.
Creating a report, query, or dashboard does not authorize monitor activation or IcM routing. If the
request means harness monitoring instead, use `/harness-monitor`'s local JSON observation contract;
a Jarvis-native monitor or dashboard link is not an interchangeable input.

After validating the dashboard values, add a monitor only when the service's operational
requirements define the condition. Connect the condition to the appropriate alert or IcM flow,
and record the owner, evaluation window, threshold source, and missing-data behavior. Do not
derive production thresholds from an illustrative example.

## Validation checklist

Apply checks to the requested deliverables. Mark unrun live checks as unverified and monitor
items as not applicable when monitoring was not requested. A design-only specification or metric
query is not evidence that a dashboard has been saved or is readable in Jarvis.

- [ ] The measured signal, numerator, denominator, units, and time window are explicit.
- [ ] Existing Geneva/MDM metrics were checked before using a fallback source.
- [ ] Dimensions are bounded, useful for aggregation, and free of sensitive or high-cardinality text.
- [ ] KQL or log parsing preserves source semantics and missing-data behavior.
- [ ] Pre-aggregation matches the dashboard slices and requested resolution.
- [ ] Success/failure calculations reconcile with the underlying metric.
- [ ] The dashboard is saved and readable by its intended audience.
- [ ] Monitor thresholds and IcM behavior come from service requirements.

## Boundaries

This guide does not provide access to Microsoft-internal Jarvis documentation, credentials,
telemetry libraries, Kusto clusters, or dashboard APIs. Confirm UI labels and supported source
types in the target Jarvis deployment. Keep internal identifiers, query results, and sensitive
operational data out of public skill files and reports.

## Reuse and Overlap

`kpi-dashboard` supplies platform-agnostic KPI selection, metric-contract, and layout
guidance for business dashboards. This skill is narrower and Jarvis-specific: it decides which
Jarvis metric source to use (Geneva/MDM, Kusto-to-Metrics, or Logs-to-Metrics) and how to wire
pre-aggregation, widgets, layers, and monitors in the Jarvis UI. Use `kpi-dashboard` for
general metric/layout design and this skill for Jarvis's own metric-plumbing decisions.

`harness-report` coordinates artifact identity, capability checks, and delivery validation
across platforms. Its `--type jarvis` route selects this guide; a Jarvis-bound query-only request
can use `--type query` with the relevant source guidance, without creating a dashboard or converted
metric. Pass the agreed signal, stable artifact destination/ID, source bindings, checks, and any
missing access or authoring capability back to that workflow. Only available authorized tools can
create live artifacts; naming this skill does not install a client, execute KQL, or publish a report.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.
