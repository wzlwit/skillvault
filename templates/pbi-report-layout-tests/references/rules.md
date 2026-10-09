# Writing pbir-utils Rules

Contents: File shape; Scopes and names; Helpers; Writing a safe expression; Test a rule; Limits.

Checked against pbir-utils 2.5.2. pbir-utils evaluates rules with
[simpleeval](https://pypi.org/project/simpleeval/), a safe subset of Python: no assignments, no lambdas, no imports.
Comprehensions, generator expressions and `and`/`or`/`not` work.

## File shape

```yaml
options:
  fail_on_warning: false        # true: warnings fail pbir-utils' own strict mode

rules:                          # optional; when present it replaces the default list
  - my_rule

definitions:
  my_rule:
    description: "What a passing report has"     # shown for each violation
    severity: error                              # error | warning | info
    scope: visual                                # report | page | visual | measure | bookmark
    params:                                      # names available in the expression
      max_width: 1280
    expression: >
      get_path(visual, "position.width", 0) <= max_width
```

A file without `rules:` runs every definition, including pbir-utils' own defaults. `include:` adds rule ids and
`exclude:` removes them. A user definition with the same id as a default overrides the fields it sets.

## Scopes and names

| Scope | Runs | Names in the expression |
| --- | --- | --- |
| `report` | once | `report` (report.json), `pages`, `bookmarks`, `reportExtensions`, `customTheme`, `baseTheme`, `version` |
| `page` | per page | the above, plus `page` (page.json, with a `visuals` list) |
| `visual` | per visual of every page | the above, plus `visual` (visual.json) and its `page` |
| `measure` | per report-level measure | `measure`, `entity` |
| `bookmark` | per bookmark | `bookmark` |

A visual group is a `visual`-scope item without a `visual` key, so test `has_path(visual, "visual.visualType")`
where it matters. Positions are as stored: a grouped visual's `position` is relative to its group, so do geometry in
`verify_report.py`, not in a rule.

## Helpers

`len`, `str`, `int`, `float`, `bool`, `sum`, `min`, `max`, `any`, `all`, `abs`, `round`, `sorted`, `reversed`, and:

- `get_path(obj, "a.b[0].c", default)`: a nested value, or `default` when any step is missing.
- `has_path(obj, "a.b")`: true when the path resolves to a value.
- `find_all(obj, "key")`: every value of `key` at any depth.
- `re_match(pattern, text)` and `re_search(pattern, text)`: false for empty text.

A PBIR literal keeps its type marker: a boolean reads `"true"` or `"false"`, a number `"1D"` or `"0L"`, a string
`"'Dropdown'"` with the quotes.

## Writing a safe expression

In `visual` scope the engine **skips a visual whose expression raises**, with no output. The rule then passes for
that visual, so a wrong path hides every violation. To avoid that:

- Read every value through `get_path(..., default)` or `has_path`, never `visual["a"]["b"]`.
- Write the rule as "does not apply, or passes": `get_path(visual, "visual.visualType", "") != "card" or <test>`.
- Choose defaults that fail the test when the property is missing: `get_path(..., "")` where the test wants `"1D"`.

In `report` and `page` scope an exception becomes an "Expression error" violation instead.

## Test a rule

1. Add a case to `tests/test_verify_report.py` that breaks only this rule, and check that the run fails with it.
2. Run the rule on a real report and look at every violation.
3. Check that the rule never raises. This uses internal pbir-utils functions, which is fine for a one-off check:

```python
from pbir_utils.rule_engine import load_pbir_context, _safe_eval
from pbir_utils.rule_config import load_rules
ctx = load_pbir_context(r"<X.Report>")
for rule in load_rules(config_path=r"rules/pbir-rules.yaml").rules:
    if rule.scope == "visual":
        for page in ctx["pages"]:
            for visual in page["visuals"]:
                _safe_eval(rule.expression, {**ctx, **rule.params, "visual": visual, "page": page})  # raises if unsafe
```

## Limits

- No rendering and no fonts: text width belongs to the `pbi-report-visual-conventions` checker.
- No model: a rule cannot see the TMDL or PBIX model; bindings belong to `verify_report.py`.
- simpleeval caps string and power sizes; very large reports are fine, but keep expressions linear in the number of
  visuals (a pairwise check over every visual on a page belongs in the script).
