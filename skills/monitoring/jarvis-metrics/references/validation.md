# Metric Contracts, Checks, and Monitors

Contents: Record the contract before configuration; Worked checks; Acceptance checks; Diagnose
before changing configuration; Optional metric-based monitor.

## Record the contract before configuration

Use the project's existing specification rather than creating a second registry:

| Field | Required decision |
|---|---|
| Signal and owner | Question answered; who owns correctness and operations |
| Population and grain | Eligible events/entities, exclusions, duplicate key/policy, one row/sample's meaning |
| Time | Event versus ingestion time, UTC/timezone, completed `[start, end)` window, bucket width, late-arrival policy |
| Value | Count, gauge, duration, distribution, ratio; units; numeric type |
| Dimensions | Bounded categories, retained combinations, null/unknown mapping, cardinality |
| Aggregation | Sum/Count/Min/Max/average/percentile semantics, time versus dimension reduction |
| Ratios, if any | Numerator/denominator population, alignment, zero denominator, unknown outcomes |
| Freshness and state | Expected delay, refresh cadence, measured zero versus absent/stale/error |
| Resource and permission | Source/destination identity, reader/editor/execution roles, intended save location |

## Worked checks

These are synthetic reasoning fixtures, not observations from Jarvis.

| Case | Expected result |
|---|---|
| 90 successes and 10 failures | Total 100; success 90%; failure 10% |
| 0 successes and 0 failures | No traffic/undefined rate, not healthy by arithmetic |
| 90 successes but failure series unavailable | Unknown/incomplete; do not replace the missing series with zero |
| Group A: 9/10 failures; group B: 1/90 | Combined 10/100 = 10%, not the unweighted mean of 90% and 1.111...% |
| K2M emits numeric count samples 7 and 13 | Sum = 20 events; sample Count = 2, not 20 |
| 120 interval events in 60 seconds | 2 events/second; not a derivative of 120 |
| Latest capacity observations 50 and 60 over time | Latest 60, not temporal Sum 110 |
| Input timestamp equals the end of `[start, end)` | Excluded from that interval; eligible for the next one |
| Only per-region p95 values available | Global request-level p95 cannot be reconstructed by averaging them |

The bundled [Kusto count example](../examples/kusto-counts.kql) should return:

| dt (UTC) | d_Region | d_Status | m_Requests |
|---|---|---|---|
| 2026-01-01 00:00:00 | East | Failure | 1 |
| 2026-01-01 00:00:00 | East | Success | 2 |
| 2026-01-01 00:00:00 | West | Success | 1 |

The four included events give 25% overall failure; the two boundary and outside events do not
count. This fixture assumes one row per unique event and only success and failure outcomes. Real
queries must also handle duplicate events and unknown outcomes. A missing West/Failure group is
zero only if a complete, successful query over the eligible events proves it; its absence from a
downstream series is not that proof.

The [log-event example](../examples/log-events.kql) keeps two `Completed` events and emits a
numeric 1 for each, with East/Success and Unknown/Failure dimensions. It excludes `Started`; the
malformed latency on that excluded row is not silently counted or turned into a duration. This is
a count transformation, not a latency or percentile metric.

## Acceptance checks

1. Run the source query, or inspect emitter output, in an authorized test context with known
   completed windows. Check result types, row counts, units, dimensions, duplicates, missing
   values, and time boundaries. A query that parses is weaker evidence than one that matches
   known values.
2. For K2M and L2M, use the preview, then check actual emitted MDM samples after approved
   deployment. Compare counts and values for the same window, dimension slice, and grain.
   Account for conversion delay and sampling; do not compare a fresh log window with delayed
   metrics.
3. In each widget, test one normal case, no traffic, a missing or stale source, and an error
   where safe. Inspect total and per-dimension values, rate alignment, percentile support,
   legend, units, time reduction, and truncated results.
4. Exercise time and dimension parameters with known values, multi-select and All where
   supported, and an empty selection. Check every affected layer, including direct Kusto and
   mixed sources.
5. Save and reopen the exact artifact, and confirm expected permissions with an authorized reader
   or a documented ACL inspection. Do not impersonate a user or claim access from a link alone.
6. Report evidence levels separately: draft prepared, synthetic arithmetic checked, query
   executed, preview passed, configuration deployed, live samples reconciled, dashboard saved.
   Mark unavailable steps as blocked or not run. Local catalog validation proves bundle
   structure only.

## Diagnose before changing configuration

| Symptom | Inspect first |
|---|---|
| No metric | Wrong environment/account/namespace, emitter or rule status, permissions, deployment, source freshness |
| Query works manually but connector fails | Execution identity access, supported operators, window substitution, result contract |
| Dimension or sampling type unavailable | Selected preaggregate, dimension emitted in actual samples, Min/Max or percentile configuration |
| Counts too high | Count versus Sum, duplicate events, joins, overlapping windows, multiple emitters/rules, preaggregate double counting |
| Counts too low | Late ingestion, exclusion filters, null parsing, source sampling, missing buckets, wrong interval |
| Rate looks implausible | Population/time/key alignment, zero/missing denominator, ratio-versus-percent units, averaging ratios |
| Latency percentile misleading | Raw/distribution support, unit conversion, precomputed percentile or mean used as a sample |
| Blank after parameter change | Unbound layer, value type/escaping, All semantics, dimension not retained, no data versus query error |
| Saved view differs from preview | Wrong artifact identity, unsaved layer, parameters/defaults, source-control deployment pending |
| Owner sees data, reader cannot | Dashboard ACL versus backing-source permission; do not broaden permissions as a shortcut |

## Optional metric-based monitor

A color threshold on a chart, or a direct Kusto widget, does not create a metric monitor.

1. Validate the metric and preaggregate, and rebuild any dashboard formula in the monitor's
   supported expression or query interface; do not assume widget expressions transfer as is.
2. Agree with the owner on the sampling type, population and dimension scopes, evaluation window,
   delay, minimum traffic if required, threshold source, no-data behavior, and recovery policy.
   Zero traffic, ingestion failure, and a healthy measured value are different conditions.
3. In the monitor editor, select the metric's Time Series and expression
   (not checked against current Jarvis). Preview normal, failing, and missing-data periods
   without generating incidents, and record the actual preview values.
4. Confirm severity, owner, routing and deduplication policy, suppression, and that the
   enrichment query matches the signal. Do not guess SLOs, production thresholds, or IcM
   destinations.
5. Publish or enable only with approval, through the required workflow. Check deployment
   separately from saving. Use a sanctioned test route only if an alert-delivery test is
   explicitly approved. Record how to disable or revert the changed monitor; do not change
   unrelated monitoring.
