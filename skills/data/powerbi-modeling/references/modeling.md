# Modeling Guide

Use these checks with the actual source schema and business definitions. Defaults are starting
points, not reasons to rewrite a working model or invent missing requirements.

## Grain, Keys, and Storage

- State what one row represents before choosing measures: order, order line, daily balance,
  snapshot, or event. Separate facts with different grains. Do not sum repeated header amounts
  after joining them to lines, or aggregate balances across dates without the correct rule.
- Identify keys from real source constraints. Test uniqueness and blank behavior in each
  dimension; define how unmatched facts are handled. Stable surrogate keys require a consistent
  mapping across refreshes and corresponding fact keys. An arbitrary Power Query index by itself
  does not provide that mapping or persistence, especially with incremental refresh or history.
- Use conformed dimensions for facts that share business entities. A Type 2 dimension needs
  versioned keys and effective-date assignment for facts, normally prepared upstream. Do not
  join every historical fact to the current version merely because its business key matches.
- Use a date dimension when time analysis requires one; agree the calendar, fiscal periods,
  coverage, and roles. Verify the requirements of the chosen time-intelligence feature instead
  of hard-coding a calendar range. Mark/configure dates as required by that feature.
- Import, DirectQuery, and Direct Lake have different source, feature, freshness, and performance
  constraints. Check current platform support. Neither a lakehouse nor a large table alone
  establishes which mode or capacity the user has approved.

## Relationships

| Endpoint ordering | Cardinality | Meaning |
| --- | --- | --- |
| Dimension to fact | `1:*` | One unique dimension member can match many fact rows. |
| Fact to dimension | `*:1` | Many fact rows can reference one unique dimension member. |
| One-to-one | `1:1` | Both endpoints are unique; justify the split and filter behavior. |
| Many-to-many | `*:*` | Neither endpoint is unique; justify semantics and consider a bridge. |

For a conventional star, start with filters flowing from dimension to fact. Endpoint ordering
in an API is not filter direction. Inspect its actual from/to cardinality fields before writing.
Check data types, uniqueness, referential integrity, and filter paths, not just column names.

Bidirectional relationships need a concrete requirement and tests for ambiguous propagation and
security behavior. A bridge needs explicit keys and a valid propagation design; its presence
alone does not prove the result. Role-playing dates can use separate dimensions or inactive
relationships activated by selected measures. Choose from reporting and security needs, not a
universal rule that all date relationships must be inactive. Recheck RLS restrictions before
using relationship modifiers; do not turn off security to make a measure run.

## Measures and Filter Semantics

Write the population, grain, numerator, denominator, date basis, and empty-result behavior first.
Order-line tables require an order identifier to count orders. `COUNTROWS` is an order count
only when a row represents an order. For a nonblank identifier unique within the model's business
scope, `DISTINCTCOUNT` can count orders across their lines. If keys repeat across companies,
sources, or periods, resolve the real order identity before writing the measure. Do not silently
drop blank identifiers or incomplete orders merely to make an example formula work.

Use explicit measures for shared business metrics. Averages of averages and sums of ratios
need the correct weights. `DIVIDE` provides a controlled zero-denominator result; choose blank,
zero, or another permitted result from the metric contract. It does not fix a wrong denominator.
Use qualified column references, clear measure names, units, descriptions, and agreed folders.
Preserve existing naming conventions unless renaming is part of the approved change.

`CALCULATE` Boolean filters can replace existing filters on their columns; `KEEPFILTERS` can
express intersection when that is the intended calculation. Replacing a whole-table `FILTER`
with a column predicate is not automatically equivalent: expanded tables, relationships, and
other context can matter. Test existing selections, subtotals, empty cases, and date boundaries.
Do not recommend a rewrite solely because a short example labels one form faster.

## Security

Map an actual authenticated identity to allowed business keys, then propagate filters through
the validated model. Region labels are not email addresses: comparing a Region column with
`USERPRINCIPALNAME()` is valid only if that column truly stores that identity, not ordinary region
names. Unknown or blank identities must not become unrestricted access by accident.

Power BI RLS roles combine additively; do not assume their intersection. Validate combinations
and the actual consumer's effective workspace/model permissions. Administrative or write-capable
test access may not represent a restricted viewer. Hidden columns and measures are not security.
Treat OLS, RLS filters, role membership, and workspace permissions as distinct controls.

Test permitted and forbidden rows using the platform's supported identity/role-testing mechanism.
Changing memberships, removing security, or creating grants requires separate explicit scope.
Never copy real identity mappings or sensitive rows into examples, logs, or public specifications.

## Performance and Tool Use

Start with representative questions, baseline results, and measurements. Identify whether cost
comes from source queries, refresh, model size, DAX, or report behavior before proposing changes.
Removing columns, pre-aggregating, changing grain/types, or rounding values changes what users
can ask or calculate; obtain agreement on that impact. Numeric-looking text may contain meaningful
leading zeros. Do not promise fixed byte savings or universal compression gains.

Keep cache state, row population, storage mode, and security context comparable in measurements.
Expensive traces, query execution, cache clearing, and refreshes need approved scope. A DAX
syntax check is not a numerical, performance, or security test. Check current tool schemas and
feature support rather than copying an old MCP request or installing missing tools silently.

Authoritative follow-up references:

- [Star-schema guidance](https://learn.microsoft.com/power-bi/guidance/star-schema)
- [Relationship guidance](https://learn.microsoft.com/power-bi/transform-model/desktop-relationships-understand)
- [CALCULATE semantics](https://learn.microsoft.com/dax/calculate-function-dax)
- [KEEPFILTERS semantics](https://learn.microsoft.com/dax/keepfilters-function-dax)
- [RLS guidance](https://learn.microsoft.com/power-bi/enterprise/service-admin-rls)
- [Power BI modeling MCP](https://github.com/microsoft/powerbi-modeling-mcp)