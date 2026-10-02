# Metric-Source Runbooks

Contents: Prerequisites for every route; A. Existing Geneva / MDM metric; B. Kusto-to-Metrics
(K2M); C. Logs-to-Metrics (L2M); Preaggregates: selecting is not creating.

## Prerequisites for every route

Record the target cloud or environment, service owner, source location, destination Metrics
account and namespace, intended metric identity, and existing configuration. Keep real
identifiers in approved private project records. Inspect available data before proposing a new
pipeline.

Check four permissions separately: reading the source data, the connector's execution identity,
editing metric or connector configuration, and saving dashboards or monitors. A query that works
for its author may not work for the connector or for the dashboard's readers. Use current
onboarding guidance for required roles; do not copy application IDs, role commands, or
cross-cloud endpoints from another team's example.

For counts, decide whether a sample is one event or an already-aggregated count. For gauges,
decide whether a sample is a point-in-time value, a maximum, or an average. Record this in the
[metric contract](./validation.md#record-the-contract-before-configuration) and use its
numerical checks before configuring sampling.

## A. Existing Geneva / MDM metric

1. Find the service's existing metric in Metrics and, when relevant, the emitting code in the
   authorized project. Record account, namespace, metric, unit, sample meaning, dimensions,
   freshness, and owner. A metric with a similar name may measure a different population.
2. Open a query or chart for one completed UTC window that has data. Start with an existing
   aggregate, then inspect the preaggregate that holds the dimensions the report needs.
3. Choose the sampling type. Sum adds emitted event counts; Count generally counts samples, not
   their values. Do not use Sum for a capacity gauge just because it was right for request
   counts. Check the target's sampling rules.
4. For each dimension, choose a fixed filter, separate series, aggregation across values, or a
   dashboard parameter. Confirm that the metric emits it and that the selected preaggregate keeps
   it. A dashboard cannot recover a dimension that was dropped upstream.
5. Compare the selected series with source observations for the same window. Then add the
   checked query to a widget using the [dashboard runbook](./dashboards.md).

**If the signal is missing:** check source freshness, environment, permissions, configuration
deployment, and known dimensions before concluding that new telemetry is required.

### New or changed native emission

Only in the owning project and with permission to implement: reuse its existing telemetry SDK
and emitter pattern; define name, units, timestamp, sampling, and bounded dimensions; add focused
emitter tests with synthetic events; and deploy through the service's normal rollout. Confirm
receipt in the intended test account before configuring preaggregates and dashboards. Do not
invent SDK calls, install a generic library, or send test traffic into production. Adding a
widget or creating a namespace does not make an application emit a metric.

## B. Kusto-to-Metrics (K2M)

Use K2M when a scheduled database query must produce a durable MDM metric. For an exploratory
query-only report, use a [direct Kusto dashboard](./dashboards.md#direct-kusto-dashboards-no-conversion-required)
instead.

1. Check that the author can see the source database and that the connector's documented
   execution identity can read it. Check destination account and rule-edit permissions.
2. Inspect an existing rule and the current connector editor. Older guides show **Manage ->
   Kusto to Metrics**, sometimes under **Connectors** (not checked against current Jarvis).
   Choose the source cluster and database, the destination account and namespace, and a new rule
   identity or the exact approved existing rule.
3. Start from the approved KQL and pick a fixed, completed test interval. Define sample
   timestamps, result grain, dimensions, and numeric measures. Older guides use one datetime
   column, string `d_` dimension columns, and numeric `m_` measure columns, and allow several
   measures per rule (not checked against current Jarvis). Confirm how measures map to metric
   names in the actual editor. Remove unintended output columns instead of assuming they are
   ignored.
4. Adapt [the synthetic count query](../examples/kusto-counts.kql) only after inspecting the
   real schema. For scheduling, replace the fixed dates with the connector's window bindings.
   Older guides use `{startTime}` and `{endTime}` (not checked against current Jarvis); take the
   exact syntax from the target template. Do not paste dashboard parameter syntax into a
   connector rule.
5. Set the execution interval, source-ingestion delay, and time-bucket policy from the required
   freshness and the observed source latency. Prefer disjoint `[start, end)` windows for counts.
   Align buckets and sample timestamps with the intended windows; do not stamp historical
   aggregates with the current execution time. Do not assume that replays are deduplicated, or
   that a longer lookback safely backfills data. Check late arrivals, retries, and overlap.
6. Preview the exact result types, row counts, values, timestamps, and dimension combinations.
   For precomputed count samples, use an aggregation that keeps their values, such as Sum, not a
   sample Count. Configure the needed preaggregates and sampling options.
7. Review query cost, schedule, owner, and destination before enabling or publishing. For
   source-controlled accounts, follow their PR and deployment flow; do not bypass it.
8. After approved deployment, inspect rule execution status and check actual MDM samples for one
   completed execution window against the source query. No runs, no data, and failed runs are
   different outcomes. Build the dashboard only after this check.

**Stop when:** identity permissions are missing, the output schema is incompatible, the window
syntax is unverified, the requested backfill depends on unknown replay behavior, or the preview
fails. Do not silently change data sources or treat a saved rule as evidence that it emitted
anything.

## C. Logs-to-Metrics (L2M)

Use L2M for eligible events already in a supported Geneva Logs pipeline. It does not read
arbitrary local log files, and it is not the Kusto-to-Metrics scheduler.

1. Identify the Logs account and namespace and the actual event stream and schema. Confirm which
   field is the event timestamp and how the source expresses measure values and categories.
   Never copy an example event name such as `Log` without checking the source configuration.
2. Open the target's Logs-to-Metrics page. Older guides show **Manage -> Connectors -> Logs to
   Metrics** and **New Conversion** (not checked against current Jarvis). Choose the correct
   account and namespace, then a new conversion or the approved existing one.
3. Select the event and write a transformation in the supported L2M subset of KQL. Older guides
   project `dt` as datetime, string `d_` dimensions, and one numeric `m_` value per conversion
   (not checked against current Jarvis). Confirm the current rules in the editor; do not assume
   that K2M's multiple measures or aggregation apply here.
4. Use [the synthetic event query](../examples/log-events.kql) to reason about the projection.
   When adapting it, replace the datatable with the transformation's documented input, which
   older guides call `source` (not checked against current Jarvis), and map real fields
   explicitly. Keep numeric measurements for latency or size; emit 1 only when counting eligible
   events.
5. Preview a time interval that contains known test events. The preview's time filter does not
   prove the scheduled ingestion window. Check included and excluded event types, parsing
   failures, timestamp conversion, null dimensions, sample count, and measure values. Treat
   malformed measurements as explicit quality failures, not zero.
6. Set the destination metric mapping and the required preaggregates, give the conversion a
   meaningful name and description, and check whether it is enabled. Enable it only with
   permission, through the applicable source-control or portal workflow.
7. Check real converted samples in MDM against eligible source events. Account for source
   sampling, duplicate events, schema drift, and delay before attaching a monitor.

Use bounded categories for unknown dimensions when the agreed contract allows it. Keep missing
or invalid numeric values distinct. Do not assume that joins, multi-event windows, or every Kusto
operator work in L2M; check first, or choose another approved route.

## Preaggregates: selecting is not creating

Selecting an existing preaggregate in a widget reads an existing metric view. Creating or editing
one in Metrics management changes the metric configuration and can affect cost and retention.

1. List the existing preaggregates, dimension combinations, and available sampling types.
2. Choose only the combinations that actual panels or monitors need. Keep environment boundaries
   unless a cross-environment rollup is intended.
3. Estimate cardinality from real bounded dimension values. Avoid customer IDs, request IDs,
   arbitrary URLs, and free-form errors. This guide sets no universal safe numeric limit.
4. With approval, add missing combinations through the target's configuration workflow. Older
   guides say Min and Max sampling need a Min/Max option on the preaggregate, and percentiles
   need the supported distribution or percentile setting (not checked against current Jarvis).
5. Check deployment and fresh samples with the required dimension values, then select the new
   view. Do not assume retroactive backfill or instant visibility, or that turning on percentile
   display can rebuild a distribution from averages.
