---
name: pbi-report-layout-tests
description: "Test a Power BI report's layout and visuals in a PBIR folder, PBIP or PBIX: pbir-utils rules, page geometry, field bindings read with PBIXRay, and PBIX-vs-PBIP parity. Use before check-in or release; pbi-report-visual-conventions defines the conventions and checks text fit and blank handling."
metadata:
  author: wzlwit
  version: "1.0.0"
---

# Power BI Report Layout Tests

Automated tests for what a report shows: page settings, where visuals sit, and the fields behind each visual. Run
them on the PBIR folder while you develop, and on the PBIX files you ship.

## Which library does what

| Library | Reads | Used here for |
| --- | --- | --- |
| [pbir-utils](https://pypi.org/project/pbir-utils/) (MIT) | PBIR folders: report, pages, visuals, bookmarks, themes | The rule engine (YAML expression rules) and the wireframe |
| [PBIXRay](https://pypi.org/project/pbixray/) (MIT) | The model inside a PBIX: tables, columns, measures and their DAX | Field bindings and model parity of a PBIX |
| `scripts/verify_report.py` | Positions, groups, zip parts, TMDL names | Geometry with group offsets, the PBIX's report, report parity |

PBIXRay does not read the report layer (visuals, pages, bookmarks, themes), and it does not read PBIP folders. A PBIX
saved with "Store PBIX reports using enhanced metadata format (PBIR)" holds its report as PBIR files under
`Report/definition/`; the script copies them to a temporary folder for pbir-utils. A PBIX in the legacy `Layout`
format is refused: open it in Desktop with that option on and save it again.

## Setup

```text
pip install "pbir-utils>=2.5" "pbixray>=0.15"
```

Python 3.10 or later. Tested with pbir-utils 2.5.2 and PBIXRay 0.15.5.

## Workflow

1. While you edit or generate the PBIR, run `python scripts/verify_report.py <X.Report>` (a `.pbip` works too). It
   runs the rules and the geometry checks, and checks bindings against the model the report binds to by path in
   `definition.pbir`.
   - A thin report's PBIP model can be a DirectQuery cache that Desktop regenerates, and a stale cache reports fields
     as missing. Check against the source model instead: `--model <source X.SemanticModel>`.
2. Before a release, run it on the PBIX files Desktop saved:
   - Report PBIX: `verify_report.py <X.pbix> --against <X.Report>`. The same checks run on the shipped report,
     bindings are read with PBIXRay from the PBIX's own model, and every `Report/definition` file must equal the PBIR
     folder's.
   - Model PBIX: `verify_report.py <X_Model.pbix> --checks none --model-against <X_Model.SemanticModel>`. Every
     measure's DAX must equal the TMDL. A model-only PBIX holds Desktop's empty placeholder page, so skip the layout
     checks on it.
3. For a human look at the layout, add `--wireframe <out.html>`. It writes pbir-utils' wireframe of every page, with
   positions, visual types and fields. The page loads web fonts from Google Fonts.
4. The `pbi-report-visual-conventions` checker covers number formats, blanks and text fit; its render check covers
   what only a rendered page shows. This skill does not render.

Errors fail the run (exit code 1); `--strict` fails warnings too; `--json` prints the result for a pipeline.

## Checks

| Check | Finds | Severity |
| --- | --- | --- |
| `rules` | Violations of the rules in `rules/pbir-rules.yaml` (below) | As each rule sets |
| `geometry` | A shown visual outside its page; two shown content visuals that overlap | Error |
| `geometry` | A button over a content visual | Warning |
| `bindings` | A table, column or measure that the report, a page or a visual uses but the model does not have | Error |
| `parity` (`--against`) | A `Report/definition` file that differs from the PBIR folder's, or is missing on either side | Error |
| `parity` (`--model-against`) | A measure whose DAX differs from the TMDL (whitespace aside), or that is missing on either side | Error |

Rules in `rules/pbir-rules.yaml`:

| Rule | Severity | Requires |
| --- | --- | --- |
| `page_fit_to_width` | error | Page view Fit to width |
| `page_canvas_background` | error | Canvas `#FAF9F8` at transparency 0 |
| `page_size` | warning | 1280 x 720 (`params`) |
| `filters_pane_collapsed` | error | Filters pane collapsed and visible in `report.json`, not set per page |
| `explicit_page_names` | warning | No default "Page N" names |
| `card_display_units`, `axis_display_units`, `secondary_axis_display_units`, `data_label_display_units` | error | Display units None wherever a number shows |
| `pie_labels` | error | Donut and pie labels with full numbers and one-decimal percentages |
| `title_text_localized` | warning | Shown titles and subtitles bound to report text, not literal |
| `alt_text_present` | warning | Alt text on every shown data visual |

Geometry details:

- Decorative visuals (textbox, shape, basicShape, image) may lie under content, as KPI tiles and section backgrounds
  do. Cards may stack on cards, as a KPI value and its caption do. Hidden visuals and visuals in hidden groups do not
  count. Edges may touch: overlaps of 1 px or less are ignored.
- PBIR stores a grouped visual's position relative to its group; the script adds each group's offset. This was
  checked on 138 grouped visuals of a shipped report, all of which fit their group only as relative positions.
- A real overlap is worth fixing even when it looks fine: the hidden part of a wide slicer container takes the clicks
  meant for the slicer under it.

Bindings cover query fields, sorts, filters (aliases resolved through `From`), and title, subtitle and text bindings
to localization constants. Report-level measures from `reportExtensions.json` count as present.

## Rules: customize and extend

Before you add or change a rule, read [references/rules.md](references/rules.md): the expression context, the helper
functions, and how the engine silently skips a visual whose expression raises. Pass your own file with
`--rules <file>`; a `rules:` list in it replaces the default list. Give every new rule a case in
`tests/test_verify_report.py` that fails without the rule.

pbir-utils also has sanitizer checks (`pbir-utils validate <X.Report> --source sanitize`), for unused bookmarks,
custom visuals and hidden pages. They run as dry runs, but deliberate choices show up as findings, such as a hidden
placeholder page that a report record needs.

## Tests

From this folder: `python -m unittest discover -s tests`. A synthetic report covers every rule, both geometry checks
(including a group offset), bindings, report parity, warnings with and without `--strict`, and the legacy-PBIX
refusal. PBIXRay needs a real PBIX: check that path on one of yours, and on one whose model you know differs.

## Limits

- PBIXRay reads the model only. It does not evaluate DAX, refresh or render.
- Geometry reads positions, not rendered text: a visual inside its page can still cut a label.
- The wireframe uses two pbir-utils functions outside its public API. If a pbir-utils release changes them, the run
  reports a warning; use `pbir-utils visualize <X.Report>` instead.

## Related skills

- `pbi-report-visual-conventions`: the conventions, a static checker for formats, blanks and text fit, and the
  render check.
- `pbi-tmdl-workflow`: editing TMDL and PBIR, and the Desktop round trip that produces the PBIX.
- `pbi-localization-pr-review`: the localization gate on PBIX files.
