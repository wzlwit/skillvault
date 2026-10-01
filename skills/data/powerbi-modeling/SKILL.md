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

Adapted from the GitHub Awesome Copilot contributors' Power BI modeling skill
(`https://github.com/github/awesome-copilot`, `skills/powerbi-modeling`), MIT; see
`UPSTREAM-LICENSE`. The original is in the Original section below, with its reference files under
`references/`. Where it differs, the SkillVault rules above it win. In particular, the original
connects to a live model first; here, design and explanation need no live connection, and live
work follows Choose the Scope.

Turn business questions and source schemas into an explicit semantic-model design, or review
an identified existing model. This skill supplies modeling judgment, not a server, connector,
deployment pipeline, or guarantee that a target is accessible.

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

## Using the Original

The SkillVault rules above add design-only use and explicit access limits; state cardinality
orientation and grain-dependent counting explicitly; and require semantic checks for performance
rewrites and identity mappings. Apply the original's reference files within those rules. The
worked cases in the validation checks are illustrative, not executed DAX tests. No MCP server or
model data is bundled.

## Supporting Research

Honor an explicit source first; otherwise inspect local and configured accessible internal
evidence before authoritative external sources. Keep private identifiers out of public searches.
Research never expands model access or write approval; report unavailable evidence explicitly.

## Original

<!-- upstream:begin -->
<!-- Original: https://github.com/github/awesome-copilot skills/powerbi-modeling at d6131471b85fbb4799e64175ebc42c9309ecc28a. Refresh replaces this section; put SkillVault changes outside it. -->

# Power BI Semantic Modeling

Guide users in building optimized, well-documented Power BI semantic models following Microsoft best practices.

## When to Use This Skill

Use this skill when users ask about:
- Creating or optimizing Power BI semantic models
- Designing star schemas (dimension/fact tables)
- Writing DAX measures or calculated columns
- Configuring table relationships (cardinality, cross-filter)
- Implementing row-level security (RLS)
- Naming conventions for tables, columns, measures
- Adding descriptions and documentation to models
- Performance tuning and optimization
- Calculation groups and field parameters
- Model validation and best practice checks

**Trigger phrases:** "create a measure", "add relationship", "star schema", "optimize model", "DAX formula", "RLS", "naming convention", "model documentation", "cardinality", "cross-filter"

## Prerequisites

### Required Tools
- **Power BI Modeling MCP Server**: Required for connecting to and modifying semantic models
  - Enables: connection_operations, table_operations, measure_operations, relationship_operations, etc.
  - Must be configured and running to interact with models

### Optional Dependencies
- **Microsoft Learn MCP Server**: Recommended for researching latest best practices
  - Enables: microsoft_docs_search, microsoft_docs_fetch
  - Use for complex scenarios, new features, and official documentation

## Workflow

### 1. Connect and Analyze First

Before providing any modeling guidance, always examine the current model state:

```
1. List connections: connection_operations(operation: "ListConnections")
2. If no connection, check for local instances: connection_operations(operation: "ListLocalInstances")
3. Connect to the model (Desktop or Fabric)
4. Get model overview: model_operations(operation: "Get")
5. List tables: table_operations(operation: "List")
6. List relationships: relationship_operations(operation: "List")
7. List measures: measure_operations(operation: "List")
```

### 2. Evaluate Model Health

After connecting, assess the model against best practices:

- **Star Schema**: Are tables properly classified as dimension or fact?
- **Relationships**: Correct cardinality? Minimal bidirectional filters?
- **Naming**: Human-readable, consistent naming conventions?
- **Documentation**: Do tables, columns, measures have descriptions?
- **Measures**: Explicit measures for key calculations?
- **Hidden Fields**: Are technical columns hidden from report view?

### 3. Provide Targeted Guidance

Based on analysis, guide improvements using references:
- Star schema design: See [STAR-SCHEMA.md](references/STAR-SCHEMA.md)
- Relationship configuration: See [RELATIONSHIPS.md](references/RELATIONSHIPS.md)
- DAX measures and naming: See [MEASURES-DAX.md](references/MEASURES-DAX.md)
- Performance optimization: See [PERFORMANCE.md](references/PERFORMANCE.md)
- Row-level security: See [RLS.md](references/RLS.md)

## Quick Reference: Model Quality Checklist

| Area | Best Practice |
|------|--------------|
| Tables | Clear dimension vs fact classification |
| Naming | Human-readable: `Customer Name` not `CUST_NM` |
| Descriptions | All tables, columns, measures documented |
| Measures | Explicit DAX measures for business metrics |
| Relationships | One-to-many from dimension to fact |
| Cross-filter | Single direction unless specifically needed |
| Hidden fields | Hide technical keys, IDs from report view |
| Date table | Dedicated marked date table |

## MCP Tools Reference

Use these Power BI Modeling MCP operations:

| Operation Category | Key Operations |
|-------------------|----------------|
| `connection_operations` | Connect, ListConnections, ListLocalInstances, ConnectFabric |
| `model_operations` | Get, GetStats, ExportTMDL |
| `table_operations` | List, Get, Create, Update, GetSchema |
| `column_operations` | List, Get, Create, Update (descriptions, hidden, format) |
| `measure_operations` | List, Get, Create, Update, Move |
| `relationship_operations` | List, Get, Create, Update, Activate, Deactivate |
| `dax_query_operations` | Execute, Validate |
| `calculation_group_operations` | List, Create, Update |
| `security_role_operations` | List, Create, Update, GetEffectivePermissions |

## Common Tasks

### Add Measure with Description
```
measure_operations(
  operation: "Create",
  definitions: [{
    name: "Total Sales",
    tableName: "Sales",
    expression: "SUM(Sales[Amount])",
    formatString: "$#,##0",
    description: "Sum of all sales amounts"
  }]
)
```

### Update Column Description
```
column_operations(
  operation: "Update",
  definitions: [{
    tableName: "Customer",
    name: "CustomerKey",
    description: "Unique identifier for customer dimension",
    isHidden: true
  }]
)
```

### Create Relationship
```
relationship_operations(
  operation: "Create",
  definitions: [{
    fromTable: "Sales",
    fromColumn: "CustomerKey",
    toTable: "Customer",
    toColumn: "CustomerKey",
    crossFilteringBehavior: "OneDirection"
  }]
)
```

## When to Use Microsoft Learn MCP

Research current best practices using `microsoft_docs_search` for:
- Latest DAX function documentation
- New Power BI features and capabilities
- Complex modeling scenarios (SCD Type 2, many-to-many)
- Performance optimization techniques
- Security implementation patterns
<!-- upstream:end -->