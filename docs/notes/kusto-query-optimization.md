# Kusto Query Optimization: Session Notes

Recorded: 2026-09-18. Status: evidence for a future skill, not an installable skill.

These lessons came from optimizing a federated telemetry report with per-entity
readiness, error counts, latest error context, and details/summary modes. Internal
endpoints, database names, identities, and log contents are intentionally omitted.
Examples below use synthetic data or clearly marked placeholders.

## Main Finding

The largest measured latency improvement came from **executing close to the data**.
Reducing unnecessary parsing helped reduce work, but shorter KQL and fewer operators
did not reliably predict faster execution. Preserve the report's meaning first,
measure the actual execution topology, then keep only worthwhile changes.

## Techniques That Helped

### 1. Check the Helper's Execution Location

A stored helper can hide cross-cluster unions, environment filters, metadata
lookups, and another coordinator hop. Inspect its definition and referenced schema
before optimizing only the visible query.

Changing the client connection alone did not remove a remote hop when the query
still qualified the helper on the old coordinator. The strongest measured variant
connected to the source cluster/database and called the equivalent local helper.
The two helper definitions were compared before assuming they were interchangeable.

- Source-local runs: 1.14, 1.79, and 1.86 seconds; median 1.79 seconds.
- An earlier remote-coordinator baseline was about 3.2 seconds.
- Measured cross-cluster transfer fell from about 330 MiB to 0.0024 MiB.
- Source-local CPU was about 199 CPU-seconds versus 179 for a contemporary baseline.
  Lower latency was not the same as lower resource cost.

Later remote runs varied from 3.70 to 20.77 seconds. These observations do not
establish a universal speedup percentage. The measured workload was a fixed 24-hour
non-production scope, not all environments, regions, or report options.

An unqualified helper depends on the selected database. It subsequently produced an
unknown-function error in a different client context. The final query therefore
restored literal-qualified helper targets with conditional source selection.
Connect to the matching source for locality, but do not confuse explicit name
resolution with a guarantee about execution location or speed. The final union
form was correctness-checked; the repeated 1.79-second result belongs to the earlier
source-local helper experiment, not a repeated benchmark of that final form.

### 2. Reduce Rows Before Expensive Parsing

The retained pipeline followed this shape:

1. Apply time, environment, application, region, and entity-scope filters.
2. Use a broad term-index filter to admit plausible readiness/error events.
3. Project only columns needed by classification and aggregation.
4. Classify exact phrases and drop irrelevant rows.
5. Parse the JSON pipeline dimension only for remaining rows.
6. Apply the real pipeline-type filter before aggregation.

`has_any` and `contains` are not interchangeable. Indexed terms make a useful broad
prefilter; exact phrases and substrings still need the appropriate predicate.
Prove that the prefilter admits every accepted phrase, including punctuation and
underscore variants. Keep the severity branch when the report includes other
Error/Critical events, even when their messages contain no known error term.

For example, this is an illustrative fragment, not a complete query:

```kusto
| where message has_any (dynamic(["ReadyCheck", "missing", "definition", "ancient"]))
    or (includeOtherErrors and traceLevel in~ ("Error", "Critical"))
| project env_time, entityId, message, traceLevel, customDimensions
```

The session reduced rows reaching JSON parsing by 16.1%, with the same selected
events. Median latency moved only from 3.526 to 3.440 seconds, so the latency benefit
was inconclusive. Do not present fewer parsing candidates as proof of a large speedup.

Case sensitivity is part of correctness: real pipeline names used mixed casing.
Changing a case-insensitive prefix match to a case-sensitive one would change scope.
Searching for a pipeline name in free-text messages was not a substitute for reading
the actual dimension and its schema.

### 3. Aggregate First, Extract Display Fields Later

If a field is needed only from the latest event per entity, select that event first
with `arg_max`, then run the regex on its retained message. The session moved URL
extraction from individual readiness events to the per-entity result.

Keep parsing needed for filtering or grouping before the aggregation. Moving such
parsing afterward would change which events contribute. Consider projecting unused
fields away, but do not remove public output fields just to improve a benchmark.

### 4. Use One Grouping Pass for Counts and Latest Context

Conditional `arg_max` expressions and `countif` calculated the latest readiness,
latest event, latest relevant error, and category counts in one per-entity summarize.
This avoided introducing separate latest-event queries and joins for each field.
This was the retained query shape, not an independently measured speedup claim.

Select a related message and pipeline in the **same** `arg_max` call. Independent
selection can produce mismatched context, especially when timestamps tie.

This self-contained synthetic example also demonstrates the no-error case:

```kusto
let Events = datatable(
    EventTime:datetime, Entity:string, IsRelevantError:bool, Message:string, Pipeline:string)
[
    datetime(2026-01-01T00:00:00Z), "alpha", true,  "first error", "PipelineA",
    datetime(2026-01-01T00:01:00Z), "alpha", true,  "last error",  "PipelineB",
    datetime(2026-01-01T00:02:00Z), "alpha", false, "later event", "PipelineC",
    datetime(2026-01-01T00:00:00Z), "beta",  false, "normal",      "PipelineD"
];
Events
| summarize
    ErrorCount = countif(IsRelevantError),
    (LastErrorTime, LastErrorMessage, LastErrorPipeline) = arg_max(
        iff(IsRelevantError, EventTime, datetime(null)), Message, Pipeline)
    by Entity
| extend
    LastErrorMessage = iff(ErrorCount > 0, LastErrorMessage, ""),
    LastErrorPipeline = iff(ErrorCount > 0, LastErrorPipeline, "")
| order by Entity asc
```

Expected: `alpha` has two errors and the pair `last error` / `PipelineB`; `beta` has
zero errors and empty message/pipeline. When every ordering expression is null,
`arg_max` can still return another row's payload. Clear those fields explicitly.
Timestamp ties do not promise which tied row wins; paired fields must come from
one winning row. Add a tie-break contract only when the report requires one.

### 5. Count a Defined Population Exactly

Once the intermediate result has exactly one row per entity, `count()` is the exact
entity count; approximate `dcount()` is unnecessary for that grouping. Do not use
`count()` as a distinct count before uniqueness has been established.

The report retained only entities with a readiness result in the selected scope.
Removing that gate would enlarge the population, not optimize the same report.

Use an explicit `case` priority for overlapping categories, both for individual
events and for the per-entity summary. Each event contributes once to the combined
error total, and each entity enters one summary bucket. Keep separate component
counts when needed. Log-row counts are not counts of unique failed runs, and a
readiness signal is not proof of feature usage or causality.

### 6. Separate Source Selection from Output Selection

Two Kusto behaviors mattered:

- A `union` keeps the combined schema even if a branch returns no rows. It did not
  provide clean details versus summary columns.
- A name calculated with `iff(...)` was rejected by `cluster()` with `SEM0049` and
  by `table()` with `SEM0052`, even when the selector inputs were constants.

For output mode, zero-argument query functions selected by a literal-bound name
worked without combining their schemas. This self-contained example returns only
the details columns; change the literal to `"summary"` for the other schema:

```kusto
let mode = "details";
let details = () { print Entity = "alpha", ErrorCount = long(2) };
let summary = () { print EntityCount = long(1) };
table(mode)
```

For automatic source routing, literal-qualified branches with mutually exclusive
scalar predicates compiled and preserved the existing environment selector. This
is a placeholder pattern, not a runnable connection configuration:

```kusto
let environment = "test";
union
    (cluster('test-source.example').database('Telemetry').Events
        | where environment == "test"),
    (cluster('prod-source.example').database('Telemetry').Events
        | where environment == "prod")
```

Runtime statistics for a tested Test selection recorded only non-production source
execution. This is evidence for pruning that inactive branch, not a universal claim
that unions are free. Both branches may still require schema resolution; permissions
and planning overhead remain relevant.

A literal `environment` plus zero-argument `test`/`prod` functions and
`table(environment)` also compiled in a schema probe. It was not adopted: deriving
that selector from the existing station setting with `iff` failed, while adding a
second literal setting introduced a synchronization burden without a measured win.

## Experiments Not Promoted

These are workload-specific observations, not rules against the operators.
Different experiments had different repetition counts; do not rank single runs
against medians as if they were one controlled comparison.

| Candidate | Observation | Decision |
| --- | --- | --- |
| Earlier pipeline parsing, boolean categories, deferred readiness regex | Median 3.194 to 3.183 seconds; transfer essentially unchanged | No demonstrated latency win; not retained |
| Two-pass readiness-entity lookup, then entity-filtered error scan | Transfer fell to about 20.6 MiB, but latency rose to 10.93 seconds | Less transfer did not compensate for extra work |
| Raw-source union instead of the helper | About 6.11 seconds initially and 7.78 warmed | Did not beat the selected helper approach |
| Per-source aggregation with `macro-expand` | About 15.17 seconds initially and 6.98 warmed | Not promoted |
| Extra raw region/island predicates around the helper | About 9.07 seconds | Not promoted |
| Raw source-local query | About 2.23-3.09 seconds, with 324-370 CPU-seconds | No overall advantage over the selected local helper |
| Additional source-local transformation variant | About 3.62 seconds, with 232-245 CPU-seconds | Not promoted |

Do not introduce `materialize()` merely because a tabular `let` exists. In a
validation query, materializing the reduced per-entity result let several assertions
reuse it. That did not establish that materializing raw logs would improve the final
single-mode report. No general shuffle, partitioning, or ingestion-policy tuning
claim was established by this session.

## Repeatable Optimization Procedure

Prerequisites: authorized read access, a known query and selected connection, its
helper/schema definitions, and a narrow reproducible workload. No schema writes,
policy changes, permission changes, or new services are needed. Queries consume
cluster resources; there is no universal time or cost estimate for a federated scan.

1. **Freeze the contract.** Record the output columns, entity key, population,
   category precedence, time boundaries, pipeline filters, and no-error behavior.
   Keep the accepted query as the reference; preserve unrelated user edits.
2. **Freeze the input.** Replace rolling `ago()`/`now()` with fixed timestamps in
   benchmark copies. Use the same scope and connection unless connection locality
   is the variable under test. Late ingestion can still change a fixed time window.
3. **Inspect the actual path.** Read helper bodies, actual column types, and the
   application code/report definition that supplies important dimensions. Use
   `take 0 | getschema` for inexpensive schema checks; it proves no data coverage.
4. **State one hypothesis.** For example: fewer rows should reach JSON parsing, or
   source-local execution should reduce cross-cluster transfer. Name the smallest
   check that could disprove it before changing the query.
5. **Check semantics cheaply.** Use synthetic rows for overlaps, no errors, missing
   dimensions, tied timestamps, and a later unrelated event. Then compare real
   output schemas and keyed rows field by field, not merely total counts. Compare
   tied results according to the established tie contract rather than row order.
6. **Benchmark sequentially.** Disable result caching with
   `set query_results_cache_max_age = time(0s);`, exclude warm-ups, and alternate
   baseline/candidate runs. Prefer at least three measured runs per candidate.
   Do not run competing benchmarks concurrently or flush shared data caches.
7. **Read complete resource evidence.** Capture latency, CPU across participating
   clusters, transfer, memory, and scan statistics. Require all samples before
   reporting medians. Record query IDs and options so measurements are attributable.
8. **Decide and stop.** Keep a candidate only when outputs remain correct and the
   objective improves enough to justify its complexity and resource trade-offs.
   Rerun the final saved form. State any untested environments or options, retain
   the rollback/reference query, and leave only essential comments in the script.

## Measurement and Tool Traps

- The query tool returned `duration: 0` even for substantial queries. This field
  was not a usable latency measurement; server query history supplied timings.
- Coordinator `TotalCpu` alone missed remote work. Inspect
  `OverallQueryStats.resource_usage` and `cross_cluster_resource_usage`, including
  each remote `cpu["total cpu"]`. Keep CPU-seconds distinct from wall-clock seconds.
- Transfer came from `resource_usage.network.cross_cluster_total_bytes`, not result
  row count or the size of the displayed response. Record the metric's scope.
- Query-history records sometimes appeared after results. Missing statistics were
  not zero; do not compute a median from an incomplete set. Avoid tight polling.
- Result-cache disabling does not disable warm data/extent caches. Record warm/cold
  conditions and cluster load; noisy runs do not prove a small optimization worked.
- A tool wrapped permanent HTTP 400 semantic errors in a 503 response. Read the
  nested Kusto error code before diagnosing networking or retrying unchanged input.
- Editor schema warnings persisted while live server queries succeeded. Server
  execution was authoritative for compilation, but did not itself repair the
  editor's metadata or prove another user's permissions.
- A helper using `isfuzzy=true` can return partial source coverage. Successful rows
  and matching totals do not alone prove every intended source was available.

## Future Skill Shape

Potential trigger: optimize or explain a slow KQL query while preserving results.

Required inputs: query text, environment/connection, time and entity scope, output
contract, and the objective (latency, CPU, transfer, memory, or cost).

Deliverables: a minimally changed query, correctness evidence, a short measurement
table with repeat counts, rejected candidates, and explicit verification limits.

Stop conditions: unavailable schema/access, unknown intended semantics, partial
source coverage, resource pressure, or an unstable benchmark. Report the limit
instead of widening production scans, changing permissions, or claiming a win.

Keep reusable mechanics in the future skill and private cluster dictionaries in
the user's own project. Creating that skill, registering it, installing it, and
publishing it remain separate work; none is performed by this note.

## Sources and Evidence Limits

- Session evidence: live Kusto schema probes, synthetic checks, fixed-window result
  comparisons, and server query-history statistics collected on 2026-09-18. Raw
  operational artifacts remain outside this public repository. The measurements
  here are anonymized observations, not an independently reproducible benchmark.
- [Kusto cluster function](https://learn.microsoft.com/en-us/kusto/query/cluster-function?view=azure-data-explorer),
  Microsoft Learn, public documentation accessed 2026-09-18. Describes cluster-name
  restrictions and literal function-argument examples.
- [Kusto table function](https://learn.microsoft.com/en-us/kusto/query/table-function?view=azure-data-explorer),
  Microsoft Learn, public documentation accessed 2026-09-18. Describes constant
  selectors, zero-argument function resolution, and conditional-union workarounds.

Additional references for a future skill: [query best practices](https://learn.microsoft.com/en-us/kusto/query/best-practices?view=azure-data-explorer),
[arg_max](https://learn.microsoft.com/en-us/kusto/query/arg-max-aggregation-function?view=azure-data-explorer),
[materialize](https://learn.microsoft.com/en-us/kusto/query/materialize-function?view=azure-data-explorer),
and [query results cache](https://learn.microsoft.com/en-us/kusto/query/query-results-cache?view=azure-data-explorer).
These are reference links, not additional performance experiments.