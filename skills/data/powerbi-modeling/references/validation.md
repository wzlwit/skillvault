# Validation Cases

These small synthetic cases check reasoning and documented expectations. They are not a Power
BI engine, an executed DAX suite, or proof that a real model is correct. The repository's Node
contract test checks the fixture arithmetic and selection expectations only.

## Order-Line Grain and Filtering

Assume one business scope, nonblank order IDs, one row per order line, and additive line amounts
in one currency. These assumptions must be verified for any real model.

```json
{
  "grain": "order line",
  "rows": [
    { "OrderId": "O-100", "LineId": 1, "Amount": 40, "RegionKey": "west" },
    { "OrderId": "O-100", "LineId": 2, "Amount": 60, "RegionKey": "west" },
    { "OrderId": "O-200", "LineId": 1, "Amount": 50, "RegionKey": "east" }
  ],
  "expected": {
    "lineCount": 3,
    "orderCount": 2,
    "totalAmount": 150,
    "averageOrderValue": 75
  },
  "filterCase": {
    "existingMaximum": 50,
    "newMinimumExclusive": 50,
    "intersectionRows": 0,
    "replacementRows": 1
  },
  "identityMapping": [
    { "identity": "analyst@example.invalid", "region": "west" }
  ],
  "securityCases": [
    { "identity": "analyst@example.invalid", "expectedRows": 2 },
    { "identity": "unknown@example.invalid", "expectedRows": 0 },
    { "identity": null, "expectedRows": 0 }
  ]
}
```

A row count returns three lines, not two orders; using it as the denominator gives 50 instead
of the intended average order value of 75. In a real model, verify distinct-order identity,
blank handling, and the effect of selecting only some lines of an order before accepting a measure.

The filter case first selects amounts at most 50. Intersecting with amounts above 50 selects
no rows; replacing that column's selection selects the 60 line. This demonstrates why a rewrite
needs a filter-context check. It does not assert a DAX SUM result of zero for an empty selection;
blank/zero behavior must be tested separately.

The security cases apply an explicit identity-to-region mapping, not a comparison of the region
name with the identity string. They express intended access only. Real RLS requires engine tests
under actual effective permissions, including additive roles and blank/unmatched model keys.

## Before and After a Real Change

| Area | Evidence to collect when authorized |
| --- | --- |
| Structure | Fact grain; dimension uniqueness; key types; unmatched keys; endpoint cardinalities and filter paths. |
| Measures | Known totals, distinct entities, ratios, blanks/zero denominators, filters, subtotals, and time boundaries. |
| Security | Allowed and forbidden rows for known, unknown, blank, and multi-role identities; applicable workspace permissions. |
| Performance | Equal results and comparable queries, cache state, source population, storage mode, and security context. |
| Writes | Recoverable definition and approved change set; resulting object metadata; partial failures and remaining checks. |
| Persistence | Confirm which model or PBIP/TMDL definition contains the change; do not silently deploy or overwrite another copy. |

For design-only work, return these as proposed checks with explicit unknowns. For executed
changes, distinguish planned, applied, and verified outcomes. Do not call a model validated
because this synthetic fixture passes, a command exits successfully, or DAX parses.