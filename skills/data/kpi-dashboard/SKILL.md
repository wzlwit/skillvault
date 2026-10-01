---
name: kpi-dashboard
description: Define actionable KPIs and design dashboard layouts, comparisons, filters, and freshness states. Use for /kpi-dashboard, legacy /kpi-dashboard-design, executive SaaS dashboards, MRR/churn/LTV-CAC metrics, operations-center views, cohort retention, or conflicting metric calculations. Overlaps with harness-report on authoring, harness-monitor on metric contracts, jarvis-metrics on dashboard design, powerbi-modeling on grain and measure semantics, and the ppt-master reference on presentation design; supplies reusable, platform-agnostic design guidance, not a platform writer, incident engine, or Jarvis-specific metric-source workflow.
license: MIT
metadata:
  author: Seth Hobson
  maintainer: wzlwit
  version: null
argument-hint: "[<dashboard-purpose-or-existing-report>] [<audience>] [<platform>]"
---

# KPI Dashboard Design

Adapted from Seth Hobson's KPI dashboard design skill (`https://github.com/wshobson/agents`,
`plugins/business-analytics/skills/kpi-dashboard-design`, named `kpi-dashboard-design` there), MIT;
see `UPSTREAM-LICENSE`. The original is in the Original section below. Where it differs, the
SkillVault rules above it win.

Turn a business or operational question into a small set of well-defined metrics and a usable
dashboard specification. Reuse the actual project's schema, formulas, reporting tools, and design
system. Installing or reading this skill runs nothing.

No input means clarify the intended dashboard or reuse an unambiguous current discussion. A design
request does not authorize data access, implementation, production queries, publishing, alerts, or
schedules. For implementation, hand the agreed specification to the appropriate existing workflow.

## Workflow

1. Identify the audience, the decision the dashboard supports, and its reading cadence. Executive
   trends, analyst exploration, and operational investigation need different layouts; never choose
   metric targets for the owner.
2. Inspect current metric definitions, source grain, filters, schema, and relevant reports; find the
   governing definition when reports disagree. Keep unavailable data or unknown formulas unverified;
   never infer a metric from a screenshot or trust a copied query blindly.
  For open-ended tabular visualization, use the [profiling guidance](#profile-before-chart-selection)
  before choosing a chart; reuse sufficient evidence already available.
3. Define each KPI with the [metric contract and checks](references/metric-contract.md) and reuse one
   definition across dashboard and monitor exports.
4. Select the few measures the decision needs, with comparisons, trends, and drilldowns rather than
   vanity metrics. A suggested KPI count is not a fixed requirement: an operational table may need
   more information than a summary. Explain what each measure prompts; thresholds and alert
   responses remain explicit project decisions.
5. Arrange from current exceptions and key outcomes to trends and investigation detail. Match charts
   to the question: time series for change, bars for category comparisons, tables for exact
   values/actions, and distributions for variability. Avoid decorative 3D charts and misleading axes.
   Reuse platform conventions, predictable filters, units, and readable labels.
  For branded or template-based output, resolve [brand and template authority](#brand-and-template-authority).
6. Treat empty, zero, stale, loading, partial, and failed data as distinct states. Show the measured
   period and refresh context, and use text or symbols as well as color for status.
7. Validate calculations with small known cases before choosing colors, using the
   [calculation guidance](references/metric-contract.md#calculation-guidance). Use query/model tooling
   only when available and authorized, and distinguish reasoning checks from executed tests.
8. Deliver metric definitions, the page/panel plan, interactions, data-state behavior, validation
   evidence, and open choices. Save only requested artifacts at the explicit or established location,
   without creating another KPI registry or dashboard inventory when the project already has one.
   Carry agreed brand/template requirements and any unverified constraints into the
   existing presentation handoff when applicable.

## Brand and Template Authority

For branded or template-based output, reuse the supplied authority and record its source/revision,
exact palette, title/body and language-specific fonts, fixed layout elements, and permitted variation
in the existing artifact specification. Distinguish visual appearance from required template structure,
such as inherited masters, layouts, and placeholders; do not silently replace one with the other.

Label sampled colors and inferred fonts as estimates, not official values. A supplied official
palette takes precedence over a screenshot estimate. Clarify material conflicts between authoritative
sources or an explicit user variation rather than guessing which requirement to discard. Missing
evidence remains unverified; do not invent brand rules or require a new brand registry.

When implementation is in scope, check representative output against the agreed palette, font faces,
fixed elements, and structure in the intended viewer, including relevant language and overflow cases.
An unavailable required font is a reported limitation until an alternative is approved; do not silently
substitute fonts, install them, or alter the source template to make validation pass. Preserve font
and template usage rights. Design-only work records constraints without claiming a rendering test.
Unbranded work keeps the existing simple design path, without mandatory brand paperwork.

## Profile Before Chart Selection

Explicit requirements for tools, platform, output format, chart type, and data scope take precedence
over defaults. If the data or available tools cannot satisfy them, explain the limitation and ask
before substituting a different result. A valid requested view and established metric contract need
no mandatory profiling round trip.

When chart choice is uncertain and tabular data is available and authorized for inspection, reuse
an existing profile or approved reader. Inspect data types, cardinality, representative values,
missingness, units, and entity-versus-detail grain. Check for repeated entities, numeric identifiers,
and suspected header or total rows before aggregating. Keep candidate keys and suspected exclusions
as evidence to review: uniqueness does not establish the business entity, and a numeric type does
not make a column a measure. Do not silently discard unusual rows.

Choose useful views from that evidence and explain why they fit. Make low-risk visual choices
without a compulsory menu, but clarify unresolved business definitions rather than guessing them.
There is no fixed chart count or new profiling dependency. Design-only work stays design-only;
without authorized data, use the known schema and label unverified assumptions, not invented profiles.

If profiling fails or times out, follow existing retry and time budgets. An already-available,
approved reader or supplied schema can be a fallback when it preserves the requirements. A timeout
does not prove the prior process stopped: reconcile its status and possible side effects before
retrying or starting conflicting work. Preserve pauses and ownership; unresolved execution stays blocked.

Reuse existing scoped approval. Ask before changing a requested tool, platform, format, chart type,
data coverage, or sampling requirement, installing dependencies, or substituting a design-only result.
Refusal or no answer leaves that change pending. Limited evidence may support a qualified design,
but a sample cannot establish whole-dataset totals. Keep missing evidence Unverified and incomplete
scope Partial; fallback never invents data, substitutes zero for missing values, or waives validation.

## Reuse and Boundaries

- `harness-report` chooses the authoring platform and coordinates artifact creation and validation;
  this skill supplies platform-independent metric and layout guidance.
- `harness-monitor` evaluates exported observations; this skill helps define that metric contract
  but never declares or activates monitors.
- `ppt-master` installs PPT Master's own presentation workflow; this skill provides no PPTX writer,
  and suggesting PPT Master is not permission to install or run it.
- `powerbi-modeling` owns Power BI relationships, DAX, RLS, and model validation. Neither skill grants
  live model access or permission to implement the other's recommendations.
- Do not invent business targets, production endpoints, permission grants, query results, or
  performance claims; synthetic examples are not live data. Design never publishes artifacts, mutates
  semantic models, accepts tasks, creates schedules or thresholds, or relaxes privacy/access controls.
  Keep raw sensitive records and credentials out of specifications and examples.

## Using the Original

The SkillVault rules above add explicit metric contracts and verification limits to the original's
metric selection, hierarchy, comparisons, drilldowns, and refresh guidance. Treat the original's
SQL and Streamlit examples in `references/details.md` as untested examples, not a report generator;
check queries such as retention and spend before use. The small worked checks in
[metric contracts](references/metric-contract.md) are reasoning cases, not executed SQL or a
promise of portable platform syntax. No runtime, connectors, or test framework are bundled.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.

## Original

<!-- upstream:begin -->
<!-- Original: https://github.com/wshobson/agents plugins/business-analytics/skills/kpi-dashboard-design at 156b7a5e7a8b93642628a339ee4039c925b34c7f. Refresh replaces this section; put SkillVault changes outside it. -->

# KPI Dashboard Design

Comprehensive patterns for designing effective Key Performance Indicator (KPI) dashboards that drive business decisions.

## When to Use This Skill

- Designing executive dashboards
- Selecting meaningful KPIs
- Building real-time monitoring displays
- Creating department-specific metrics views
- Improving existing dashboard layouts
- Establishing metric governance

## Core Concepts

### 1. KPI Framework

| Level           | Focus            | Update Frequency  | Audience   |
| --------------- | ---------------- | ----------------- | ---------- |
| **Strategic**   | Long-term goals  | Monthly/Quarterly | Executives |
| **Tactical**    | Department goals | Weekly/Monthly    | Managers   |
| **Operational** | Day-to-day       | Real-time/Daily   | Teams      |

### 2. SMART KPIs

```
Specific: Clear definition
Measurable: Quantifiable
Achievable: Realistic targets
Relevant: Aligned to goals
Time-bound: Defined period
```

### 3. Dashboard Hierarchy

```
├── Executive Summary (1 page)
│   ├── 4-6 headline KPIs
│   ├── Trend indicators
│   └── Key alerts
├── Department Views
│   ├── Sales Dashboard
│   ├── Marketing Dashboard
│   ├── Operations Dashboard
│   └── Finance Dashboard
└── Detailed Drilldowns
    ├── Individual metrics
    └── Root cause analysis
```

## Detailed worked examples and patterns

Detailed sections (starting with `## Common KPIs by Department`) live in `references/details.md`. Read that file when the navigation summary above is insufficient.

## Best Practices

### Do's

- **Limit to 5-7 KPIs** - Focus on what matters
- **Show context** - Comparisons, trends, targets
- **Use consistent colors** - Red=bad, green=good
- **Enable drilldown** - From summary to detail
- **Update appropriately** - Match metric frequency

### Don'ts

- **Don't show vanity metrics** - Focus on actionable data
- **Don't overcrowd** - White space aids comprehension
- **Don't use 3D charts** - They distort perception
- **Don't hide methodology** - Document calculations
- **Don't ignore mobile** - Ensure responsive design

## Troubleshooting

### MRR shown on dashboard contradicts finance's number

The most common cause is inconsistent treatment of annual plans. Finance may prorate to a daily rate while the dashboard normalizes to monthly. Align on a single formula and document it directly on the dashboard card:

```sql
-- Explicit formula shown in tooltip / data dictionary
-- Annual plans: divide total contract value by 12
-- Quarterly plans: divide by 3
-- Monthly plans: use as-is
CASE subscription_interval
    WHEN 'monthly'   THEN amount
    WHEN 'quarterly' THEN amount / 3.0
    WHEN 'yearly'    THEN amount / 12.0
END AS normalized_mrr
```

### Dashboard shows green but product team reports users complaining

The dashboard likely tracks system uptime (a lagging indicator) but not user-facing quality metrics. Add customer-perceived metrics alongside infrastructure metrics:

| Infrastructure (green) | User-perceived (add these) |
|---|---|
| API uptime 99.9% | P95 page load time |
| Error rate 0.1% | Task completion rate |
| Queue depth normal | Support ticket volume |

### Retention cohort looks flat — no variation between cohorts

Check whether the cohort query is partitioning by signup month correctly. A common bug is using `created_at::date` instead of `DATE_TRUNC('month', created_at)`, which groups by day and produces cohorts too small to show trends:

```sql
-- Wrong: too granular, cohorts are too small
DATE_TRUNC('day', created_at) AS cohort_date

-- Correct: monthly cohorts
DATE_TRUNC('month', created_at) AS cohort_month
```

### Real-time dashboard hammers the database

A live dashboard refreshing every 10 seconds with complex cohort SQL will degrade production query performance. Separate OLAP workloads from OLTP by writing pre-aggregated metrics to a summary table via a scheduled job, and have the dashboard read from that:

```python
# Scheduled every 5 minutes via cron/Celery
def refresh_mrr_summary():
    conn.execute("""
        INSERT INTO kpi_snapshot (metric, value, snapshot_at)
        SELECT 'mrr', SUM(...), NOW()
        FROM subscriptions WHERE status = 'active'
        ON CONFLICT (metric) DO UPDATE SET value = EXCLUDED.value
    """)
```

### Alert thresholds fire constantly, team ignores them

Static thresholds set once and never reviewed cause alert fatigue. Use dynamic thresholds based on rolling averages so alerts fire only when the metric deviates significantly from its own baseline:

```python
# Alert if current value is > 2 standard deviations from 30-day rolling mean
def is_anomalous(current: float, history: list[float]) -> bool:
    mean = statistics.mean(history)
    stdev = statistics.stdev(history)
    return abs(current - mean) > 2 * stdev
```

## Related Skills

- `data-storytelling` - Turn dashboard findings into narratives that drive executive decisions
<!-- upstream:end -->
