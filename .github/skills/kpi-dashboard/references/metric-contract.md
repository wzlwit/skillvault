# Metric Contract and Checks

Reuse the project's existing data dictionary or report specification. Fill only fields relevant
to the requested KPI; identify unresolved definitions instead of inventing another registry or a
mandatory configuration schema. This is design guidance, not a runtime JSON contract.

| Field | Establish |
| --- | --- |
| Purpose and audience | Decision supported, owner, and expected action |
| Source and identity | Verified query/model/measure, resource/environment, schema/version when relevant |
| Population and grain | Eligible entities, grouping, filters, deduplication, and join keys |
| Calculation | Numerator, denominator, aggregation, exclusions, and units |
| Time | Measurement window, timezone, event versus ingestion time, and late/corrected data |
| Comparison | Prior period, baseline, or explicit target with matching populations |
| Direction | Higher/lower is better, acceptable range, or descriptive only |
| Data state | Distinct treatment of zero, missing, stale, partial, and failed data |
| Freshness | Last measured period, collection time, source refresh constraints, and accepted age |
| Display and interaction | Native format/precision, filters, drilldowns, and non-color status cues |
| Verification | Known expected cases, source reconciliation, and actual checks or outstanding gaps |

Thresholds, sampling rules, and refresh budgets must be supplied or explicitly approved by the
owner. Do not turn the following arithmetic examples into live defaults.

## Calculation Guidance

- Validate denominator populations, join multiplicity, duplicate events, zero/null values, and time
  boundaries. Verify visual and filter behavior when implementation is in scope.
- Cohort retention divides distinct returning cohort members in the period by the original eligible
  cohort population, not only members active in that period. Use a full elapsed-period index rather
  than a month-of-year component for multi-year cohorts.
- Aggregate costs and acquisition counts at their intended grain before combining them. Joining a
  monthly spend row to every customer must not multiply the cost or change the denominator.
- Define whether MRR is a point-in-time subscription measure or another agreed business metric. Do
  not treat invoice-month revenue as historical MRR without verifying the required semantics, and
  retain agreed billing, cancellation, currency, and proration rules rather than impose a sample.
- Ratios and period-over-period growth need explicit zero-denominator and missing-period handling.
  Reconcile units and percentage versus percentage-point differences before comparisons.
- Refresh frequency should match source availability and the decision, not a generic real-time
  default. Inspect actual query cost and existing aggregation/cache facilities before proposing
  infrastructure; never create schedules, summary tables, or dynamic thresholds from examples.
- No data is not success. A dashboard or collector can work while a service is unhealthy; show those
  separately when the report is used for monitoring. Account for metric direction, accessibility,
  and mobile constraints when relevant, and never call an old value live.

## Small Known Cases

These synthetic cases check the definition before an engine-specific query is implemented:

| Case | Expected result | Defect it can expose |
| --- | --- | --- |
| Cohort has 10 eligible members; 2 return in month 1; each emits several events | Retention is 20%, with 2 distinct returning members and denominator 10 | Activity rows or only active members used as the population |
| Monthly acquisition spend is 1,000; 10 qualifying customers are acquired | Cost per acquisition is 100, with spend counted once | A monthly spend row repeated for each customer |
| Earlier period value is 120; current value is 150 | Relative increase is 25% | Reversed denominator or percentage formatting applied twice |
| Error rate rises from 2% to 3% | Increase is 1 percentage point, or 50% relative | Percentage points confused with percentage change |
| Denominator is zero or the source query failed | Apply the agreed undefined/Unknown state, not an invented zero or Healthy value | Null/error data silently coerced to success |
| A report refreshes now but the latest measurement window ended yesterday | Freshness reflects yesterday's measurement | File/export/refresh time substituted for observation time |

For a real implementation, execute focused checks against the selected engine and actual schema
when authorized. Include duplicates and boundary periods as appropriate. These worked cases do
not validate a production formula, integration, or report by themselves.

## Layout and Validation Handoff

Keep the purpose and key exceptions visible, followed by useful comparisons/trends and
investigation detail. Use the actual product's layout and chart conventions instead of a
mandatory generic card dashboard. Verify filters apply consistently across panels and measures;
call out intentional differences rather than accidentally compare mismatched scopes.

For a monitoring handoff, use the existing `harness-monitor` declaration and observation contract.
Current snapshots contain one numeric metric, resource/environment identity, and explicit
measurement/collection times. The dashboard and exporter should share their verified definition;
the visual artifact alone does not supply those observations. A design specification does not
grant collection, scheduling, incident intake, or publishing permission.