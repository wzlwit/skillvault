# Smart Charts Evaluation

- Evaluated: 2026-09-27
- Source: https://github.com/hherosoul/dsh-smart-charts/tree/main/skills/smart-charts
- Reviewed revision: `fdb5dcba78ae650b572a347160176d1f9491870e` (2026-09-24)
- Declared skill and DSH package version: `8.4.0`
- Publisher: `hherosoul/dsh-smart-charts`; skill metadata and license identify `smart-charts`
- License: MIT; root notice is `Copyright (c) 2026 smart-charts`
- Candidate review scope: This published bundle, not other Smart Charts mirrors or Deriv charting products

## Recommendation

Purpose: Turn supplied tabular files into standalone interactive ECharts HTML, with profiling,
transformations, chart statistics, and explanatory annotations. It targets analysts and agent users
who need local charts, not a backend dashboard, live connector, or narrative-report system.

Value: High for repeated file-to-chart work. Fit: A script-backed charting specialist with a DSH
adapter. It has a distinct rendering role; it is not simply another KPI design guide.

Installed recommendation: Keep `kpi-dashboard` for metric and visual-design contracts and
`harness-report` for artifact identity, authoring, and validation. Skill recommendation: Defer a
managed Smart Charts bundle until the execution and output-contract issues below are addressed
and a focused trial verifies the intended host. Do not replace either existing workflow.

Standalone use: Worth a separately approved trial on trusted synthetic or non-sensitive data,
starting with a single, already-shaped input and no generated transform code. Use an isolated
Python environment and an explicit output directory. This assessment does not authorize that trial.

Harness integration: A potential optional local-HTML specialist under an explicitly selected web
route, not a new runtime action or automatic default. DSH means DeepSeek Harness here, not
SkillVault's harness runtime; the DSH plugin is not a drop-in SkillVault integration.

## Source and Requirements

The shared inventory found no match among 55 current-user global/current-project skill folders.
The current and official SkillVault catalogs had no entry, and the optional cache was absent.
The public directory identified this publisher; its actual source, metadata, and license were
inspected at the pinned revision. Popularity and registry audit badges were not treated as proof.

The skill declares Python 3.11+ with pandas `>=3.0.1,<4`, NumPy `>=2.4.3,<3`, openpyxl
`>=3.1.5,<4`, and xlrd `>=2.0.1,<3`. The separate DSH adapter declares Node `>=20.19.0` and a
`@deepseek-ai/dsh-skill-filesystem` peer dependency. Its package has a build-time `prepare` script;
approving that installation would approve code execution. No dependencies or adapter were installed.

The root MIT notice was verified. Bundled ECharts extensions and map assets need their own
license/attribution review before redistribution; this review did not establish every asset's terms.

## Useful Capabilities

- CSV/TSV/TXT, XLSX/XLS, and limited nested JSON input handling; the code declares 32 chart types.
  Multi-file combining is implemented in the parser layer; the main chart CLI takes one input file.
- A non-rendering profile reports types, cardinality, missingness, samples, candidate keys, signals,
  and suspicious rows. The agent chooses the chart; the profile does not establish business meaning.
  An already-clear user question takes the direct route without a mandatory profiling round trip.
- Separate source/plotted row counts, entity counts, previews, statistics, and advisories help
  reconcile row-level versus entity-level aggregation. A preview is only a sample, not a full audit.
- Chart-type-aware aggregation warnings avoid treating scatter/distribution rows as if they always
  require category aggregation. A gauge scale is not silently treated as a business target.
- Annotations are expected to cite computed facts and disclose assumptions and limitations,
  distinguishing supported observations from speculation.
- The template reads bundled JavaScript and embeds chart data locally, with title/annotation HTML
  escaping and script-termination escaping for chart-option JSON. Offline rendering is a useful
  design property, not proof that an agent's model inference or every optional path is local.

## Risks and Limits

These findings come from source review, not reproduced failures or a complete security audit.

- **Transform execution is not an OS sandbox.** `DataTransformer` validates keywords/AST nodes,
  restricts builtins, and then calls `exec` in the same process with pandas and NumPy objects.
  Its alarm-based timeout is skipped on Windows; loops remain allowed and there is no memory quota
  in that helper. Do not infer safe execution of arbitrary generated or untrusted code, or waive
  permissions because the instructions say confirmation is unnecessary.
- **Structural matching is not a join contract.** `DataParser._merge` concatenates matching schemas
  or outer-joins on all shared columns once a column-overlap threshold is met. That merge call does
  not validate key cardinality; duplicate keys can multiply rows. The existing business grain,
  units, and join keys must control any accepted merge, not column similarity alone.
- **Some evidence fields do not match the advertised universal contract.** The spreadsheet branch
  renders selected columns but builds `data_preview` from the full transformed frame. Its
  `source_rows` is computed after the transform, unlike the ordinary per-chart path. Batch-global
  transforms also occur before per-chart source counts are captured. Do not equate every returned
  count with original file rows or every preview with only the displayed columns.
- **Success needs per-chart review.** The batch CLI exits unsuccessfully only when no charts succeed;
  a mixed batch can exit normally while its summary reports failures. Advisories also accompany
  successful charts. A nonempty HTML file or dependency check does not prove correct rendering,
  complete scope, or a sound interpretation.
- **Local output still has effects.** HTML contains the plotted values and labels. Repeated identical
  title/options can target the same generated filename and overwrite it. Preserve chosen artifact
  identity and user edits, and obtain the required approval before sharing data-bearing HTML.
- **Interpretation needs judgment.** Candidate-key uniqueness is not proof of the intended business
  entity; trend/concentration heuristics use specific aggregations and thresholds. Inspect the
  underlying metric semantics, distinguish facts from hypotheses, and do not adopt blanket
  no-confirmation rules for material choices. Claimed generation speed was not measured here.

## Existing-Skill Improvements

The user approved both proposals and requirement-first fallback on 2026-09-27. They are now
implemented in the existing KPI/report guidance, independently of candidate adoption. The gap
descriptions below refer to the pre-change workflows.

### 1. Profile Before Uncertain Chart Selection

- Target: `kpi-dashboard`, Workflow steps 2 and 5.
- Evidence and gap: The candidate's `build_profile` provides compact input evidence before chart
  choice. The current guide checks schema/grain and maps charts to questions, but does not explicitly
  inspect cardinality, representative values, or suspicious header/total rows when the question is
  open-ended and a table is already available.
- Proposed change: Reuse available data profiles or approved readers to inspect those properties,
  missingness, units, and entity/detail grain before choosing a few useful views. Explain the
  selection. Treat types and unique-key candidates as evidence, not automatic semantic roles;
  clarify unresolved business definitions while making low-risk visual choices independently.
- Scope: Only when authorized tabular data is available and chart choice is uncertain. Reuse a clear
  question and established metric contract; no mandatory extra scan, parser installation, fixed chart
  count, or live query for design-only work.
- Expected benefit: Avoid plots of numeric IDs, inappropriate category counts, or totals mixed with
  detail rows before spending effort on visual polish.
- Validation: Review a table with numeric IDs, repeated entities, measures, and a trailing total row;
  justify the plotted unit and exclusions. An explicitly requested valid monthly trend should keep
  its direct path, and a design-only request without data must not invent profiling results.

### 2. Reconcile Chart Explanations With Plotted Data

- Target: `harness-report`, Validate and Deliver, reusing `kpi-dashboard`'s metric contract.
- Evidence and gap: The candidate exposes plot statistics and advisories alongside its artifact.
  Current report validation covers formulas, filters, grain, and rendering, but does not explicitly
  bind a chart's explanatory numbers to its final displayed data after transformations.
- Proposed change: When a deliverable includes chart captions or conclusions, check their numbers
  against the plotted scope, series, units, filters, and aggregation. Retain compact source-to-plot
  counts and material assumptions where useful; a sample preview alone cannot prove full totals.
  Surface missing series, partial batches, and unresolved advisories. Keep inferred explanations
  distinct from measured facts, and exclude non-displayed sensitive columns from shared evidence.
- Scope: Reuse the artifact and existing validation notes, not a new ledger or mandatory statistics
  schema. No requirement to add a narrative when the user asked only for a chart, and no replacement
  of actual rendering checks with a JSON success flag.
- Expected benefit: Prevent a correct-looking chart from being delivered with numbers describing a
  different data slice or with a partial batch reported as fully validated.
- Validation: Filter and aggregate a small known dataset, then verify its caption and totals against
  that exact result. Include a hidden column and a failed chart in a batch. A bare-chart request
  should retain its scope without forced commentary or disclosure of unused data.

## Applied Locally

[KPI profiling guidance](../../skills/data/kpi-dashboard/SKILL.md#profile-before-chart-selection)
now uses authorized data evidence before uncertain chart choices, including cardinality, samples,
missingness, entity/detail grain, and suspicious header/total rows. It preserves valid explicit
requests and design-only scope, without a mandatory profile call or new dependency.

[Report validation](../../skills/planning/harness-report/references/workflow.md#validate-and-deliver)
now reconciles explanatory numbers with the final plotted scope, units, filters, aggregation, and
series. It exposes partial batches and material assumptions, avoids sharing unused sensitive
columns, and does not force a narrative for a bare-chart request.

Both guides honor explicit tools, platforms, formats, chart types, and data requirements before
defaults. [Report fallback](../../skills/planning/harness-report/references/workflow.md#requirement-preserving-fallback)
reuses an available approved method only when it preserves that contract. It retains retry/time
budgets, reconciles prior execution and possible writes before conflicting work, and preserves
ownership and pauses. Changes to requested coverage, sampling, tools, or deliverable need approval;
refusal or no answer leaves the change pending. Missing evidence remains Unverified and incomplete
scope remains Partial or Blocked, never a reason to invent data or waive validation.

Verification: five focused Node instruction contracts passed, including the two new charting checks.
Catalog/resource validation passed for 37 public skills and 30 project-installed copies. A read-only
walkthrough covered explicit requests, ambiguous data, approved fallback, unresolved timeouts,
partial batches, hidden columns, and bare-chart delivery. This validates instruction contracts and
scope, not rendered chart behavior or the upstream transform sandbox.

## Verification and Reconsideration

Inspected the pinned skill instructions, README, license, package/dependency metadata, CLI,
profile/parser/transformer, generator, and HTML template. Compared the installed KPI guide and
metric reference plus report-authoring workflow. The regression script and all type-specific
renderers/assets were not exhaustively reviewed. No upstream doctor command, transform, chart,
regression suite, plugin install, model trial, or browser rendering was run.

Before adoption, verify Windows-safe execution limits or an explicitly approved alternative, the
source/preview contract, partial-batch handling, join semantics, and representative chart rendering.
The native improvements above do not install Smart Charts, add a renderer or runtime action, change
live retry policies, or authorize data access and publication.

## Sources

- [Pinned skill instructions](https://github.com/hherosoul/dsh-smart-charts/blob/fdb5dcba78ae650b572a347160176d1f9491870e/skills/smart-charts/SKILL.md)
- [README](https://github.com/hherosoul/dsh-smart-charts/blob/fdb5dcba78ae650b572a347160176d1f9491870e/README.md)
- [MIT license](https://github.com/hherosoul/dsh-smart-charts/blob/fdb5dcba78ae650b572a347160176d1f9491870e/LICENSE)
- [Package metadata](https://github.com/hherosoul/dsh-smart-charts/blob/fdb5dcba78ae650b572a347160176d1f9491870e/package.json)
- [Python requirements](https://github.com/hherosoul/dsh-smart-charts/blob/fdb5dcba78ae650b572a347160176d1f9491870e/skills/smart-charts/requirements.txt)
- [Transform execution](https://github.com/hherosoul/dsh-smart-charts/blob/fdb5dcba78ae650b572a347160176d1f9491870e/skills/smart-charts/scripts/data_transformer.py)
- [Parser and merge](https://github.com/hherosoul/dsh-smart-charts/blob/fdb5dcba78ae650b572a347160176d1f9491870e/skills/smart-charts/scripts/data_parser.py)
- [Data profile](https://github.com/hherosoul/dsh-smart-charts/blob/fdb5dcba78ae650b572a347160176d1f9491870e/skills/smart-charts/scripts/profile.py)
- [Chart generator](https://github.com/hherosoul/dsh-smart-charts/blob/fdb5dcba78ae650b572a347160176d1f9491870e/skills/smart-charts/scripts/chart_generator.py)
- [HTML template](https://github.com/hherosoul/dsh-smart-charts/blob/fdb5dcba78ae650b572a347160176d1f9491870e/skills/smart-charts/scripts/template.py)
- [CLI](https://github.com/hherosoul/dsh-smart-charts/blob/fdb5dcba78ae650b572a347160176d1f9491870e/skills/smart-charts/scripts/cli.py)
- [Current KPI workflow](../../skills/data/kpi-dashboard/SKILL.md)
- [Metric contract](../../skills/data/kpi-dashboard/references/metric-contract.md)
- [Current report workflow](../../skills/planning/harness-report/references/workflow.md)