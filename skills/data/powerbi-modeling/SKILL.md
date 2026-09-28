---
name: powerbi-modeling
description: "Design and review Power BI semantic models, star schemas, fact and dimension grain, relationships, DAX measures, RLS, and performance. Use for /powerbi-modeling, model design, cardinality, cross-filter direction, or model optimization. Overlaps with kpi-dashboard on grain and metric definitions; owns model structure and validation, not dashboard layout or automatic deployment. Design-only use needs no live connection."
license: MIT
metadata:
  author: null
  maintainer: wzlwit
  version: null
argument-hint: "[<model-or-requirements>] [<design-or-review-goal>]"
---

# Power BI Modeling

Turn business questions and source schemas into an explicit semantic-model design, or review
an identified existing model. This curated guide supplies modeling judgment, not a server,
connector, deployment pipeline, or guarantee that a target is accessible.

## Choose the Scope

| Request | Permitted starting point |
| --- | --- |
| Design or explain | Use supplied requirements, schemas, and authorized local model files. No live connection is required. Keep unknowns explicit. |
| Review an existing model | Confirm the exact model/file and read scope. Inspect metadata first; row data and queries need appropriate authorization. |
| Implement a model change | Confirm target and change scope, preserve a recoverable definition, apply only approved changes, and validate. |

With no input, reuse unambiguous current context or ask what model or question to address.
Do not select the first open Desktop model, current MCP connection, or similarly named Fabric
item. Designing, explaining, reviewing, and installing this guide do not authorize model writes.

## Workflow

1. Establish business purpose, audience, source schemas, freshness needs, and existing metric
   definitions. Ask only for decisions or inputs that authorized evidence cannot establish.
   Reuse `kpi-dashboard` for metric meaning and dashboard requirements.
2. Write each fact table's grain in business terms, then identify dimensions, stable unique keys,
   unknown members, history, and role-playing dates with the [modeling guide](./references/modeling.md).
3. Choose Import, DirectQuery, or Direct Lake from source capability, freshness, scale, and
   permissions; explain the trade-off and prefer the existing supported mode for scoped edits.
   Do not infer a capacity, connector, refresh schedule, or entitlement from a sample.
4. Specify each relationship's endpoint tables, keys, cardinality, active state, and filter
   direction, verifying uniqueness on the one side. Dimension-to-fact is `1:*`; the reverse
   ordering is `*:1`.
5. Define measures with grain, population, filters, denominator, time basis, units, and blank
   behavior, preserving agreed semantics. Line counts are not order counts, and a filter rewrite
   is not equivalent merely because one expression looks faster.
6. Design RLS from actual identity-to-key mappings with default-deny for unmapped identities.
   Keep model filters, role membership, and workspace permissions distinct. Never weaken existing
   security or change access assignments as a modeling side effect.
7. For authorized live work, inspect current MCP tool schemas and availability before calling
   them. The Power BI modeling MCP supplies operations; Microsoft Learn tools are optional research
   aids. Missing tools do not block design-only work or justify installing a runtime. Use one
   identified source of truth: an active model may hold changes not yet serialized to its PBIP/TMDL
   files, so reconcile instead of editing stale files in parallel.
8. Before writes, present the proposed object changes and reuse approval only when it covers the
   exact scope. Preserve a recoverable model definition in an approved private location; this does
   not back up source data or service permissions. Use transactions only when the actual tools
   support the required operations, and report partial outcomes honestly.
9. Run the [scoped validation checks](./references/validation.md): inspect resulting metadata and,
   when authorized, test measures, relationship propagation, security identities, and
   representative performance. Report unexecuted checks as pending, not passed.
10. Deliver the design or change summary, assumptions, validation evidence, and open choices.
    Save requested documentation at the project's established destination. Do not create a second
    metric registry, deploy a model, or publish a report to finish a design task.

## Boundaries and Reuse

- Live connections, queries, security changes, deletions, refreshes, deployment, publication, and
  access grants remain separately scoped; a write-capable MCP server does not permit all of them.
- Never delete same-named models to resolve ambiguity, infer credentials, or retry a failed
  operation without checking its actual effect. Keep sensitive rows, identities, connection
  secrets, and restricted metadata out of public prompts, examples, and documents.
- `kpi-dashboard` owns metric contracts and presentation; this skill owns Power BI model
  structure and validation. Keep both. An optional implementation handoff can use the project's
  existing authoring workflow without a new runner or automatic integration.

## Source and Adaptation

Curated from the GitHub Awesome Copilot contributors' [Power BI modeling skill](https://github.com/github/awesome-copilot/tree/1f5644080a525d26a2e24f61a7609fb9b261c21a/skills/powerbi-modeling),
under the [MIT license](./LICENSE). Individual authorship is not declared by the upstream skill;
`wzlwit` maintains this adaptation. Version is explicitly unknown (`null`), not an upstream release.

This is rephrased guidance, not an unchanged import. It adds design-only use and explicit access
boundaries; corrects cardinality orientation and grain-dependent counting; requires semantic
checks for performance rewrites and identity mappings. No upstream reference files, scripts,
MCP server, or model data are bundled. Worked cases are illustrative and not executed DAX tests.

## Supporting Research

Honor an explicit source first; otherwise inspect local and configured accessible internal
evidence before authoritative external sources. Keep private identifiers out of public searches.
Research never expands model access or write approval; report unavailable evidence explicitly.