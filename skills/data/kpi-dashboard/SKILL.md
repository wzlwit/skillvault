---
name: kpi-dashboard
description: Define actionable KPIs and design dashboard layouts, comparisons, filters, and freshness states. Use for /kpi-dashboard, legacy /kpi-dashboard-design, executive SaaS dashboards, MRR/churn/LTV-CAC metrics, operations-center views, cohort retention, or conflicting metric calculations. Overlaps with harness-report on authoring, harness-monitor on metric contracts, jarvis-metrics on dashboard design, and powerbi-modeling on grain and measure semantics; supplies reusable, platform-agnostic design guidance, not a platform writer, incident engine, or Jarvis-specific metric-source workflow.
license: MIT
metadata:
  author: Seth Hobson
  maintainer: wzlwit
  version: null
argument-hint: "[<dashboard-purpose-or-existing-report>] [<audience>] [<platform>]"
---

# KPI Dashboard Design

Turn a business or operational question into a small set of well-defined metrics and a usable
dashboard specification. Reuse the actual project's schema, formulas, reporting tools, and design
system. This curated guide is usable on its own; it does not install or run the upstream plugin.

No input means clarify the intended dashboard or reuse an unambiguous current discussion. A design
request does not authorize data access, implementation, production queries, publishing, alerts, or
schedules. For implementation, hand the agreed specification to the appropriate existing workflow.

## Workflow

1. Identify the audience, the decision/action the dashboard supports, and its expected reading
   cadence. Distinguish executive trends, analyst exploration, and operational investigation;
   do not force all audiences into the same layout or choose metric targets for the owner.
2. Inspect current metric definitions, source grain, filters, schema, and relevant reports. Find
   the governing definition when two reports disagree. Keep unavailable data or unknown formulas
   explicitly unverified; do not infer a metric from a screenshot or trust a copied query blindly.
3. Define each KPI with the [metric contract and checks](references/metric-contract.md): source,
   numerator/denominator, grain, units, population, time window/timezone, comparison, freshness,
   missing-data behavior, and owner. Reuse one definition across dashboard and monitor exports.
4. Select the few measures needed for the decision. Include comparisons, trend context, and useful
   drilldowns rather than vanity metrics. A suggested KPI count is not a fixed requirement: an
   operational table may need more information than a summary. Explain what each measure prompts
   the audience to do; thresholds and alert responses remain explicit project decisions.
5. Arrange the view from current exceptions and key outcomes to trends and investigation detail.
   Match charts to the question: time series for change, bars for category comparisons, tables
   for exact values/actions, and distributions for variability. Avoid decorative 3D charts and
   misleading axes. Reuse platform conventions, predictable filters, units, and readable labels.
6. Treat empty, zero, stale, loading, partial, and failed data as different states. Show the measured
   period and refresh context without calling an old value live. Use text/symbols as well as color
   for status; account for metric direction, accessibility, and mobile constraints when relevant.
7. Validate the calculations with small known cases before choosing colors. Check denominator
   populations, join multiplicity, duplicate events, zero/null values, and time boundaries. Use
   appropriate query/model tooling only when available and authorized, and distinguish reasoning
   checks from actual executed tests. Verify visual/filter behavior if implementation is in scope.
8. Deliver the metric definitions, page/panel plan, interactions, data-state behavior, validation
   evidence, and open choices. Save only requested artifacts at the explicit destination or the
   project's established documentation location. Do not create another KPI registry or dashboard
   inventory when the project already has one.

## Calculation and Performance Guidance

- Cohort retention divides distinct returning cohort members in the period by the original
  eligible cohort population, not only the people who generated activity in that period. Use
  a full elapsed-period index rather than a month-of-year component for multi-year cohorts.
- Aggregate costs and acquisition counts at their intended grain before combining them. Joining
  a monthly spend row to every customer must not multiply the cost or change the denominator.
- Define whether MRR is a point-in-time subscription measure or another agreed business metric.
  Do not treat invoice-month revenue as historical MRR without verifying the required semantics.
  Retain agreed billing, cancellation, currency, and proration rules rather than impose a sample.
- Ratios and period-over-period growth need explicit zero-denominator and missing-period handling.
  Reconcile units and percentage versus percentage-point differences before comparisons.
- Refresh frequency should match source availability and the decision, not a generic real-time
  default. Inspect actual query cost and existing aggregation/cache facilities before proposing
  infrastructure. Never create schedules, summary tables, or dynamic thresholds from examples.
- No data is not success. A dashboard/collector can work correctly while a service is unhealthy;
  status must communicate those separately when the report is used for monitoring.

## Reuse and Boundaries

`harness-report` chooses an authoring platform and coordinates actual artifact creation and
validation. This skill supplies its common metric/layout guidance without duplicating every
platform manual. `harness-monitor` evaluates exported observations and tracks incident proposals;
this skill can help define that metric contract but does not declare or activate monitors.

`powerbi-modeling` shares grain and measure semantics but owns Power BI relationships, DAX, RLS,
and model validation. Reuse this skill's business metric definitions there; retain this skill
for dashboard layout and platform-independent contracts. Neither skill grants live model access
or permission to implement the other's recommendations.

Do not invent business targets, production endpoints, permission grants, query results, or
performance claims. Synthetic examples are not live data. Do not publish/share artifacts, mutate
semantic models, accept tasks, or relax privacy/access controls as a side effect of design.
Keep raw sensitive records and credentials out of specifications and examples.

## Source and Adaptation

Curated from Seth Hobson's [KPI dashboard design skill](https://github.com/wshobson/agents/tree/main/plugins/business-analytics/skills/kpi-dashboard-design)
in wshobson/agents under the [MIT license](LICENSE). This adaptation keeps metric selection,
hierarchy, comparisons, drilldowns, and refresh guidance, while adding explicit metric contracts
and verification boundaries. It omits the upstream executable SQL and hard-coded Streamlit
examples: they are not a tested report generator, and the reviewed retention/spend queries need
correction before use. The small worked checks in the reference are illustrative reasoning cases,
not executed SQL or a promise of portable platform syntax.

No upstream scripts, runtime, connectors, or test framework are bundled. The declared version is
explicitly unknown (`null`), not an invented upstream release. Installing this guide runs nothing.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.
