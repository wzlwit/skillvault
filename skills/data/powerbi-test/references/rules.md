# Project Checks: Style Files and Rule Packs

Contents: Two ways to add checks; Style file settings; Rule pack shape; Scopes and names; Helpers; Writing a safe
expression; Test a rule; Limits.

## Two ways to add checks

The generic checks always run on a report in the enhanced report format (PBIR). A project adds its own in one of two
ways:

- A **style file** (YAML) lists house-style settings, and `check_style.py --style <file>` checks them. No
  expressions are needed. Use it for the settings below.
- A **rule pack** holds pbir-utils expression rules, and `verify_report.py --rules <pack>` runs it after
  [the generic pack](../rules/generic.yaml). Use it for anything the style file doesn't cover.

Keep both in the project, next to the `.pbip` or at the repository root, so every review and build reads the same
file.

## Style file settings

A setting that is absent is not checked. An unknown setting or value stops the run with exit code 2, so a typo can't
silently skip a check. [The example](../examples/report-style.example.yaml) shows every setting.

| Setting | Checks | Values |
| --- | --- | --- |
| `page.view` | The view of every page (`displayOption` in `page.json`) | `FitToPage`, `FitToWidth`, `ActualSize` |
| `page.width`, `page.height` | The canvas size of every page | Pixels |
| `page.background` | An explicit canvas color at transparency 0 | A quoted color such as `"#FFFFFF"` |
| `page.wallpaper` | The color of the area outside every page (Format page > Wallpaper, `objects.outspace` in `page.json`), with no transparency other than 0 | A quoted color such as `"#FFFFFF"` |
| `filtersPane` | The Filters pane state in `report.json`, and that no page sets it itself | `collapsed`, `expanded`, `hidden` |
| `displayUnits` | Display units on card values, value axes (both axes of a combo chart), and shown data labels | `none` (full numbers), `auto`, `thousands`, `millions`, `billions`, `trillions` |
| `percentDecimals` | Decimals on pie and donut percent labels | A whole number |
| `dateSlicer.mode` | The mode of every slicer in a date mode | `Between`, `Relative`, `Before`, `After` |
| `dateSlicer.slider` | Whether Between slicers show their range slider | `true`, `false` |
| `dateSlicer.sameSyncGroup` | All date slicers share one sync group, so a range follows the user from page to page | `true` |
| `titles` | Shown titles and subtitles take their text from a field, such as a translation table, not literal text | `bound` |
| `formats` | The format string of every visible measure | A list: each entry is an exact format string, or a regular expression for the whole string |
| `blanks` | No measure turns a blank into a value with `COALESCE`, an `IF` on `ISBLANK` or `ISEMPTY` with a constant branch, `+ 0`, a `DIVIDE` alternate result other than `BLANK()`, or dash or N/A text | `keep` |
| `captionSeparator` | A caption that joins a number and a name with this separator puts the number first, so a narrow card cuts the name, not the number | A quoted string |

- `formats`, `blanks`, and `captionSeparator` read measures from the model's Tabular Model Definition Language (TMDL)
  files: `--model`, or the folder a Power BI project's report binds to by path. Without a model they are reported as
  skipped.
- PBIR stores display units as a number literal: `0D` is Auto (also the default when unset), `1D` None, `1000D`
  thousands. Only classic cards (`card`) are checked; other card visuals keep their settings elsewhere.
- Hidden visuals are checked too, since a bookmark can show them.

## Rule pack shape

pbir-utils evaluates rules with [simpleeval](https://github.com/danthedeckie/simpleeval), a safe subset of Python: no
assignments, lambdas, or imports. Comprehensions, generator expressions, and `and`/`or`/`not` work. Checked against
pbir-utils 2.5.2.

```yaml
options:
  fail_on_warning: false        # true: warnings fail pbir-utils' own strict mode

rules:                          # the rules to run; without this list, pbir-utils' own default rules run too
  - page_width

definitions:
  page_width:
    description: "Pages are 1280 px wide"      # shown for each violation
    severity: error                            # error | warning | info
    scope: page                                # report | page | visual | measure | bookmark
    params:                                    # names available in the expression
      width: 1280
    expression: >
      page.get("width") == width
```

`include:` adds rule ids to the list and `exclude:` removes them. Give project rules their own ids: a definition with
the id of one of pbir-utils' defaults merges with it, and a project rule with a generic rule's id runs twice. Run on
its own, `pbir-utils validate` without `--rules-config` picks up a `pbir-rules.yaml` in the current folder or the
report folder.

## Scopes and names

| Scope | Runs | Names in the expression |
| --- | --- | --- |
| `report` | once | `report` (report.json), `pages`, `bookmarks`, `reportExtensions`, `customTheme`, `baseTheme`, `version` |
| `page` | per page | the above, plus `page` (page.json, with a `visuals` list) |
| `visual` | per visual of every page | the above, plus `visual` (visual.json) and its `page` |
| `measure` | per report-level measure | `measure`, `entity` |
| `bookmark` | per bookmark | `bookmark` |

A visual group is a `visual`-scope item without a `visual` key, so test `has_path(visual, "visual.visualType")` where
it matters. Positions are as stored: a grouped visual's `position` is relative to its group, so leave geometry to
`verify_report.py`.

## Helpers

`len`, `str`, `int`, `float`, `bool`, `sum`, `min`, `max`, `any`, `all`, `abs`, `round`, `sorted`, `reversed`, and:

- `get_path(obj, "a.b[0].c", default)`: a nested value, or `default` when any step is missing.
- `has_path(obj, "a.b")`: true when the path resolves to a value.
- `find_all(obj, "key")`: every value of `key` at any depth.
- `re_match(pattern, text)` and `re_search(pattern, text)`: false for empty text.

A PBIR literal keeps its type marker: a boolean reads `"true"` or `"false"`, a number `"1D"` or `"0L"`, a string
`"'Between'"` with the quotes, a date `"datetime'2025-01-31T00:00:00'"`.

## Writing a safe expression

In `visual` scope the engine **skips a visual whose expression raises**, with no output. The rule then passes for that
visual, so a wrong path or a syntax slip hides every violation. To avoid that:

- Read every value through `get_path(..., default)` or `has_path`, never `visual["a"]["b"]`.
- Write the rule as "does not apply, or passes": `get_path(visual, "visual.visualType", "") != "card" or <test>`.
- Choose defaults that fail the test when the property is missing: `get_path(..., "")` where the test wants `"1D"`.
- In a folded block (`expression: >`), a line indented deeper than the first keeps its line break, and a line break
  outside parentheses is a syntax error. Wrap an expression that spans lines in parentheses.

In `report` and `page` scope an exception becomes an "Expression error" violation instead.

## Test a rule

1. Run the rule on a report that breaks it, and on one that passes; look at every violation. For the generic pack,
   add a case to `tests/test_verify_report.py` that fails without the rule.
2. Check that the rule never raises. This uses internal pbir-utils functions, which is fine for a one-off check (the
   tests do the same for the generic pack):

```python
from pbir_utils.rule_engine import load_pbir_context, _safe_eval
from pbir_utils.rule_config import load_rules
ctx = load_pbir_context(r"<X.Report>")
for rule in load_rules(config_path=r"<pack.yaml>").rules:
    for page in ctx["pages"]:
        for visual in page["visuals"] if rule.scope == "visual" else [None]:
            _safe_eval(rule.expression, {**ctx, **rule.params, "page": page, "visual": visual})  # raises if unsafe
```

## Limits

- No rendering and no fonts: text fit belongs to `verify_report.py`'s `text` check.
- No model: a rule cannot see the model, whether in TMDL files or inside a Power BI Desktop file (PBIX); bindings and
  measure checks belong to the scripts.
- simpleeval caps string and power sizes. Keep expressions linear in the number of visuals: a pairwise check over
  every visual on a page belongs in a script.
