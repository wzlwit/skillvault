# Power BI Modeling Evaluation

- Evaluated: 2026-09-24
- Canonical source: https://github.com/github/awesome-copilot/tree/main/skills/powerbi-modeling
- Reviewed repository revision: `1f5644080a525d26a2e24f61a7609fb9b261c21a`
- Declared skill version: Unknown; the inspected frontmatter declares none.
- License: Root MIT license, copyright GitHub, Inc.; preserve its notice for copied substantial material.
- Attribution: GitHub Awesome Copilot contributors; the skill frontmatter does not identify an individual author.
- Scope: Skill instructions, all five bundled references, directory listings, license, and the installed KPI counterpart. Source review only.
- Skill recommendation: **Upsert a curated, URL-derived guide; do not import unchanged.**
- Installed recommendation: **Coexist; keep kpi-dashboard and the existing modeling tools.**

## Purpose and Value

**Purpose:** Help Power BI developers design and review semantic models: fact/dimension structure,
grain, relationships, DAX measures, row-level security, documentation, and performance.

**Value: High for model-oriented work, conditional on curation.** The guide adds a reusable
modeling workflow above an MCP server's object operations. Its references are small enough to
load by topic, and its trigger phrases describe concrete modeling tasks rather than generic BI.

**Fit: Skill.** This is repeated domain guidance with supporting references, not one prompt,
an always-on instruction, or an executable modeling engine. The selected bundle consists of
the main instructions and five Markdown references; no runtime or automated test suite is
bundled in that directory.

## Verified Capabilities

The main workflow inventories an existing model, checks its structure and metadata, then loads
the relevant reference. Coverage includes:

- Star schemas, consistent fact grain, keys, date dimensions, and role-playing dimensions.
- Relationship cardinality, filter direction, inactive relationships, and bridge patterns.
- Explicit measures, common DAX patterns, naming, descriptions, and display folders.
- Model/data reduction, DirectQuery considerations, and representative performance testing.
- Static/dynamic RLS, additive roles, identity mappings, and edge-case testing.

Power BI Modeling MCP is required for model inspection and modification. Microsoft Learn MCP
is recommended, not required, for additional research. The evaluating session exposes modeling
tool families, but no model connection, permission, example execution, or performance result was
verified. Tool availability is not proof that a target model is accessible or writable.

## Overlap

The installed [kpi-dashboard guide](../../skills/data/kpi-dashboard/SKILL.md) owns metric meaning,
grain, comparisons, presentation, and data-state behavior. This candidate overlaps on measure
correctness and grain, but adds Power BI-specific relationships, DAX, security, and model metadata.
Keep the KPI guide; reuse its metric contracts rather than creating a competing KPI registry.

The modeling MCP remains the execution tool, not a competing instruction skill. A guide can
improve how those tools are used without installing another runtime. Any later report-workflow
handoff should reuse the existing authoring workflow; this evaluation does not create one.

## Changes Needed Before Adoption

1. **Separate design from live access.** The upstream instructions require connecting to an
   active model before any guidance. That is useful for existing-model changes but unnecessarily
   excludes designing from requirements and supplied schemas. Add distinct design-only and
   existing-model modes; neither should select or connect to an arbitrary open model.
2. **Add explicit operation boundaries.** The guide contains create/update and security examples
   without a complete read-versus-write approval workflow. Require an identified model and
   authorized scope, present proposed changes, preserve a recoverable definition before writes,
   and validate results. Do not infer permission to publish, deploy, change role membership,
   delete objects, or broaden data access from a modeling-design request. Keep sensitive rows,
   identifiers, and credentials out of generated documentation and public artifacts.
3. **Correct the cardinality table.** The relationships reference labels `*:1` one-to-many and
   `1:*` many-to-one. Its later dimension `(1)` to fact `(*)` example uses the expected orientation.
   Align the table with that orientation and make the from/to table roles explicit.
4. **Make measures grain-aware.** The measure reference uses `COUNTROWS(Sales)` as Order Count
   and uses that count as the average-order-value denominator. At order-line grain, this counts
   lines, not orders. Three lines belonging to two orders yield 3 rather than 2. Require the
   intended business grain and a verified order identifier before choosing a distinct-order
   count; `COUNTROWS` is valid only when one row really represents one order.
5. **Do not present performance rewrites as automatically equivalent.** The performance guide
   replaces a filtered-table argument with a direct Boolean column filter. Existing filters on
   that column can make their semantics differ; preserve the intended intersection/overwrite
   behavior and test it. Treat compression and timing statements as hypotheses to measure for
   the selected storage mode, not guaranteed improvements.
6. **Ground security and key examples in actual schemas.** One RLS example compares a Region
   column directly with `USERPRINCIPALNAME()`. That only fits if the column actually stores the
   identity, unlike ordinary region labels. Use an explicit identity mapping and test unknown,
   blank, and multi-role cases. Likewise, an index-column example alone does not establish stable
   surrogate keys across refreshes or the corresponding fact-key mapping.
7. **Check current tool contracts before use.** The examples are illustrative operation calls,
   not verified requests against this session's server. Resolve actual tool schemas and supported
   operations, and retain the source references for periodic revalidation. MCP and Power BI
   changes make maintenance moderate rather than zero-cost.

These are adoption conditions, not changes made to upstream or proof of failures in a real model.
The review does not establish that every DAX example is correct under every filter context.

## Recommendation

**Skill recommendation: Upsert.** Preserve the useful topic structure and rewrite the guidance
around verified model grain, read-only design, explicit execution approval, and scoped validation.
Do not vendor the upstream documentation wholesale or copy its examples as tested automation.

- Suggested name: `powerbi-modeling`
- Category: `skills/data/powerbi-modeling`
- Default availability: global; explicit project installation remains available for a pinned copy.
- Type: URL-derived, curated instruction skill; no bundled server or executable scripts required.
- Version: Explicit `null` unless a separately maintained version is deliberately declared.
- Short description: Design and review Power BI semantic models, relationships, DAX, and RLS; overlaps with kpi-dashboard on grain and metric definitions, focusing on model structure and validation.
- Suggested next request: `/skillvault-authoring upsert https://github.com/github/awesome-copilot/tree/main/skills/powerbi-modeling none`

The suggested command authors source only. A global install is a separate approved step, not
implied by the recommended default availability.

**Standalone use:** Worth a bounded trial after the corrections, starting with a non-sensitive
sample or supplied schema. Existing-model operations need separately confirmed model access.
**Harness integration:** No new runner or automatic integration is needed to gain value from
the guide. Defer any live authoring integration until its target, permissions, and validation
workflow are explicitly selected.

## Verification Limits and Reconsideration

No model was connected, queried, edited, refreshed, or deployed. No DAX, RLS, performance,
authentication, or end-to-end MCP test was run. Installation status and the nearby KPI guide were
inspected in the preceding discovery and this evaluation; the candidate was not installed.

Recheck when the pinned upstream instructions change, when curation addresses the conditions
above, or when a concrete model/workflow is selected for an authorized trial. Broader model
authoring alternatives may fit a later deployment requirement better; that is not a reason to
replace this explicitly selected source during evaluation.

The initial evaluation wrote only this public-safe record. It did not change catalog entries,
skill bundles, installed copies, model files, schedules, credentials, or Git publication.

## Curation Follow-up

On 2026-09-24 the owner requested the recommended curated version. The
[source skill](../../skills/data/powerbi-modeling/SKILL.md) now separates design, review, and
approved changes; addresses the seven curation conditions above; and retains MIT provenance.
Its manifest uses explicit `null` authorship/version where the upstream does not declare them,
pins the reviewed revision, and defaults future installation to global availability.

The catalog and KPI counterpart document their distinct ownership and overlap. Bundled synthetic
cases check order-line grain, filter intersection/replacement, and identity mapping expectations
through the existing Node contract fixture. These are documentation/reasoning checks, not DAX or
RLS engine tests. Source curation installs no copy, connects to no model, and performs no live
query, edit, security change, refresh, or deployment. The runtime verification limits above remain.

## Sources

- [Pinned skill instructions](https://github.com/github/awesome-copilot/blob/1f5644080a525d26a2e24f61a7609fb9b261c21a/skills/powerbi-modeling/SKILL.md)
- [Star schema reference](https://github.com/github/awesome-copilot/blob/1f5644080a525d26a2e24f61a7609fb9b261c21a/skills/powerbi-modeling/references/STAR-SCHEMA.md)
- [Relationship reference](https://github.com/github/awesome-copilot/blob/1f5644080a525d26a2e24f61a7609fb9b261c21a/skills/powerbi-modeling/references/RELATIONSHIPS.md)
- [Measures and DAX reference](https://github.com/github/awesome-copilot/blob/1f5644080a525d26a2e24f61a7609fb9b261c21a/skills/powerbi-modeling/references/MEASURES-DAX.md)
- [Performance reference](https://github.com/github/awesome-copilot/blob/1f5644080a525d26a2e24f61a7609fb9b261c21a/skills/powerbi-modeling/references/PERFORMANCE.md)
- [RLS reference](https://github.com/github/awesome-copilot/blob/1f5644080a525d26a2e24f61a7609fb9b261c21a/skills/powerbi-modeling/references/RLS.md)
- [MIT license](https://github.com/github/awesome-copilot/blob/1f5644080a525d26a2e24f61a7609fb9b261c21a/LICENSE)