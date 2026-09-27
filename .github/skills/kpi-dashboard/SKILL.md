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
  For open-ended tabular visualization, use the [profiling guidance](#profile-before-chart-selection)
  before choosing a chart; reuse sufficient evidence already available.
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
  For branded or template-based output, resolve [brand and template authority](#brand-and-template-authority).
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
  inventory when the project already has one. Carry agreed brand/template requirements and any
  unverified constraints into the existing presentation handoff when applicable.

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

`ppt-master` references a separate presentation workflow. Reuse this guide's metric, layout, and
brand/template contract for a requested presentation handoff; neither this guide nor that reference
provides a bundled PPTX writer or permission to install one.

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
