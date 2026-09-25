# Report Authoring Routes

Use the selected route only. This table names candidate skills, not guaranteed installed
capabilities. Verify their current instructions and host tools before dispatch; installation and
any platform connection retain their own approvals. None of these routes changes the monitor's
local-JSON input contract or permits automatic publication.

Use the resolved output from the [report workflow](workflow.md): new specifications default to
`<root>/.harness_sv/docs/plans/`, and new local report/query artifacts to `<root>/.harness_sv/artifacts/`,
unless the user specifies another destination. Existing user-selected artifacts and application
source stay in place. Pass the resolved path explicitly to the selected specialist or worker.

## Power BI

- Design: the upstream [Power BI report-design consultation](https://github.com/github/awesome-copilot/tree/main/skills/power-bi-report-design-consultation)
  guides chart selection, layouts, interactions, and accessibility. Its output is recommendations.
- Data layer: [powerbi-modeling](https://github.com/github/awesome-copilot/tree/main/skills/powerbi-modeling)
  uses Power BI Modeling MCP for semantic models, relationships, and DAX. Read the actual model
  only with authorized access; model changes are not implicitly permitted by report design.
- Artifact: use an existing report project and an available, verified report-authoring tool or
  documented file format. Preserve its model binding, report ID, pages, filters, and custom work.
  A model export or DAX measure is not a finished Power BI report. Do not invent binary report
  files or claim that the Modeling MCP alone creates report pages. If no report writer is available,
  report that gap and offer design/model work only with the user's agreement.
- Validate: open/render the report using compatible tooling, check model bindings and measures
  under intended filters, interactions, access/RLS context where relevant, and mobile layouts when
  requested. Publishing to a workspace is a separate operation with explicit target authorization.

## Grafana

- Use installed [grafana-dashboards](https://github.com/wshobson/agents/tree/main/plugins/observability-monitoring/skills/grafana-dashboards)
  when available; pair it with the chosen data source's query guidance. It is a candidate guide,
  not a bundled Grafana service or connector. Upstream example panel/alert formats require checking
  against the target Grafana version before reuse.
- Artifact: native dashboard JSON or the existing dashboard-as-code project. For updates, retain
  the dashboard UID and verified organization/folder/data-source identities, not just its title.
  Do not assume Prometheus when another data source owns the requested metrics.
- Validate: JSON/schema checks appropriate to the target, actual panel rendering, queries/units,
  variable filters, null/empty states, and measurement freshness. Do not register alerts, edit live
  data sources, or apply provisioning/Terraform as a side effect of local dashboard creation.

## Jarvis

- Read the selected `jarvis-metrics` skill for source selection, dimensions,
  pre-aggregation, widgets, layers, and parameters. Reuse a suitable existing Geneva/MDM metric
  before considering Kusto-to-Metrics or Logs-to-Metrics; do not add application telemetry as an
  implicit reporting step. Confirm source availability and UI/schema support in the target deployment.
- Artifact: a metric/query contract and dashboard configuration specification for design-only
  work, or a saved dashboard/widget through an available, explicitly authorized Jarvis authoring
  surface. The specialist is a planning/configuration guide, not a bundled client or executor.
  Do not invent dashboard JSON, APIs, or saved items from illustrative UI steps. Preserve existing
  report/widget identity and verified metric source bindings when updating.
- Keep output scope explicit. A query-only request stays on the Query route below; reuse relevant
  Jarvis source guidance without silently converting the query into a metric or building visuals.
  Metric creation, scheduled conversion, and new telemetry are separate effects to approve.
- Validate the agreed numerator/denominator, source filters and windows, units, bounded dimensions,
  missing-data behavior, and pre-aggregation against available evidence. A saved visual deliverable
  also requires actual rendering, parameter/layer behavior, and intended-audience readability.
  State unrun live checks rather than calling a design or unexecuted query a validated dashboard.
- Missing authoring/access capability is Blocked or Partial unless the user accepts a design-only
  deliverable. Offer `/handoff` for an attended next step only when needed and explicitly requested;
  do not launch a second writer. Publishing, sharing, Jarvis monitors/alerts, and IcM routing retain
  separate authorization. Harness monitoring instead needs its current local numeric JSON contract,
  not the Jarvis dashboard URL or a Jarvis-native monitor definition.

## Web Dashboard

- Use `kpi-dashboard`, the project's frontend conventions, and an installed suitable
  implementation skill when present. Use `webapp-testing` for authorized browser validation.
- Artifact: working source in the current application's framework and design system. Do not
  mandate Streamlit, React, or a new server simply because an upstream example uses one. A new
  project requires its own agreed setup. Preserve the existing report route and component identity.
- Validate: calculation tests against small known datasets, filters/drilldowns, refresh/empty/error
  states, accessibility, and rendered desktop/mobile layouts. Start a local dev server only when
  needed for the requested web artifact, and give its URL; deployment and public sharing are separate.

## Query or Saved Query

- Identify the actual SQL/KQL/DAX or other supported engine, schema, connection, query scope, and
  output grain before writing. Use the relevant installed query skill and approved database tools;
  `supabase-postgres-best-practices` applies only to Postgres, not every SQL engine. For Azure-backed
  queries, follow the applicable Azure skill/tool best practices rather than assuming generic SQL.
- Artifact: native query text/parameters at the resolved artifact destination or an explicitly selected
  saved-query item. Preserve its stable path/ID. Query creation does not itself execute that query,
  create a table, or authorize access to production data. Do not embed credentials.
- For a Jarvis-bound query, read `jarvis-metrics` when its source/dimension guidance is
  relevant or explicitly requested. Preserve the query artifact and its semantics; conversion,
  metric scheduling, and dashboard creation are not required for query-only delivery.
- Validate: compatible parser/native validation, schema and aggregation checks, zero/null handling,
  and bounded sample execution when authorized. Record which checks were possible; an unexecuted
  query is not a validated data result. A saved query does not imply a rendered dashboard.

## Common Handoff

Supply the chosen worker with the report purpose, stable destination, data/metric contract, source
evidence, selected route instructions, permitted actions, and acceptance checks. Do not send the
entire reference collection or start one worker per route. Keep calculations and definitions
shared between the visual artifact and an optional monitor exporter, but obtain separate approval
for its data access, cadence, and threshold declarations.