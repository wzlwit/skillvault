---
name: powerbi-test
description: "[compare] Alone: reports here. Text: test that report. Tests Power BI reports in the enhanced report format (PBIR) before check-in or release: layout, field bindings, text fit, parity between a Power BI Desktop file (PBIX) and its Power BI project (PBIP), and house style from a project style file. Also compares two Power BI projects. Use to test, check, or verify a report, or to compare a base and a target project. Overlaps with powerbi-build on project files, which it changes and this skill checks; with Microsoft's powerbi-report-cli on validation and screenshots; and with powerbi-localize on literal-text and translation checks."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[compare] [<report path>]"
---

# Power BI Report Tests

`/powerbi-test` checks Power BI reports in the enhanced report format (PBIR) with scripts, before check-in or
release: where visuals sit, the fields behind them, whether text fits, and whether a released Power BI Desktop file
(PBIX) still matches its Power BI project (PBIP). House-style checks run only from a project's own style file. It also
compares two projects. The checks only read; `powerbi-build` covers fixing what they find.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | Lists the reports under the current folder and offers to test them |
| Text | Tests that report: the structural checks, then the style checks when the project has a style file |
| `compare <base> <target>` | Compares two projects and writes a report of the differences by severity |

- **Alone** lists the reports under the current folder, skipping `.git` and dependency folders: `.Report` folders
  that hold `definition/report.json`, `.pbip` files, and `.pbix` files. A `.Report` folder with only a `report.json`
  is the legacy format (PBIR-Legacy), which Desktop converts to PBIR when it saves the report again. It names the
  project's style file if it finds one, then asks once whether to test them all or one; no answer changes nothing.
  It ends with one line: name a report or a path to test it, or say `compare <base> <target>`.
- **Text** names a report: a path, or a report from the Alone list. Run the structural checks, then the style checks
  when the project has a style file. Summarize errors first, grouped by check, with where each one is; say which
  checks were skipped and why; then offer the rendered check. Plain words map to options: "against <folder>" for
  parity, "strict" to fail on warnings, "wireframe" for a picture of the layout.
- **`compare`** compares a base project (the reference) with a target (the one to update): model, measures, visuals,
  formatting, and optionally values read from screenshots. Before `compare`, read
  [references/compare.md](./references/compare.md).

## Setup

Python 3.10 or later with `pbir-utils` and `pyyaml`; `pbixray` reads the model inside a PBIX. The text-fit check
measures with Windows fonts and is skipped elsewhere. When a package is missing, say so and offer to install it in a
virtual environment: `pip install "pbir-utils>=2.5" pyyaml pbixray`. Tested with pbir-utils 2.5.2 and PyYAML 6.0.3.

## Structural checks

`python scripts/verify_report.py <X.Report | X.pbip | X.pbix>` runs these on every report:

| Check | Finds | Severity |
| --- | --- | --- |
| `rules` | The generic rules in [rules/generic.yaml](./rules/generic.yaml): a range slicer that shows its slider but is too short to draw it, a slicer whose start date is after its end date, a data visual without alt text, a default "Page N" name | Warning |
| `geometry` | A shown visual outside its page, or two shown content visuals that overlap | Error |
| `geometry` | A button over a content visual | Warning |
| `bindings` | A table, column, or measure that the report uses and the model lacks | Error |
| `text` | A title or subtitle wider than its visual, a legend name wider than a side legend, a short titled textbox that shows a scrollbar | Warning |

- Geometry adds group offsets, since PBIR stores a grouped visual's position relative to its group. Decorative
  visuals (textbox, shape, image) may lie under content, cards may stack on cards, hidden visuals don't count, and
  edges may touch.
- Bindings use the model the report binds to by path. For a thin report, or when that model is a stale DirectQuery
  cache, give `--model <X.SemanticModel>`. A PBIX is checked against its own model, read with PBIXRay.
- Text margins were calibrated on one report in Segoe UI: confirm a text finding with a render before changing a
  title. Titles bound to a text table are measured only when `--resx <base-language .resx>` gives their text.
- `--rules <pack.yaml>` runs a project's own pbir-utils rules after the generic ones.

Before a release, check the PBIX files Desktop saved:

- Report PBIX: `verify_report.py X.pbix --against X.Report`. Every `Report/definition` file must equal the PBIR
  folder's.
- Model PBIX: `verify_report.py X_Model.pbix --checks none --model-against X.SemanticModel`. Every measure's DAX must
  equal the Tabular Model Definition Language (TMDL) files. Skip the layout checks: a model-only PBIX holds an empty
  placeholder page.

`--wireframe <out.html>` writes pbir-utils' wireframe of every page for a human look; the page loads web fonts.

## Style checks

House style (canvas size and view, background, display units, number formats, blank handling, title and caption
rules) is a project's choice, so no style is checked by default. A project records its choices in a style file: the
file the user names, otherwise `report-style.yaml` next to the `.pbip` or at the repository root.
`python scripts/check_style.py <X.Report | X.pbip | X.pbix> --style report-style.yaml [--model <X.SemanticModel>]`
checks only the settings the file contains; `formats`, `blanks`, and `captionSeparator` read the model's measures. Start
a new style file from the [example](./examples/report-style.example.yaml), whose values are illustrative only. Before
writing or changing a style file or a rule pack, read [references/rules.md](./references/rules.md).

## Output

Both scripts print a line per check, a line per finding (`SEVERITY check where: message`), then the counts; `--json`
prints `input`, `summary`, `findings`, and `failed` instead. Exit codes: 0 when nothing fails; 1 on an error finding
(with `verify_report.py --strict`, on a warning too; every style finding is an error); 2 when the input, the style
file, or the arguments can't be used.

## Rendered check

Static checks can't see label lengths that come from data, series that hide each other, or how blanks show. Offer a
rendered check after changes to titles, labels, legends, or blank handling, and before a release. Before it, read
[references/render.md](./references/render.md).

## Rules

- The scripts and `compare` only read; a PBIX is read from a temporary copy. Change report or model files only when
  the user asks for a fix.
- Never publish, deploy, refresh, or delete anything in the Power BI service as a side effect. A rendered check in
  the service needs the user's explicit approval and a test workspace.
- Keep tokens and credentials out of files, logs, and chat.
- Report what was not checked: skipped checks, a missing model, titles not measured.
- Related: `powerbi-build` makes the changes, `powerbi-localize` reviews translations and literal text,
  `powerbi-modeling` covers model design, and Microsoft's powerbi-report-cli in the
  [powerbi-authoring plugin](https://github.com/microsoft/skills-for-fabric/tree/main/plugins/powerbi-authoring)
  validates PBIR against its schemas and previews pages.

## Tests

From this folder: `python -m unittest discover -s tests` (needs pbir-utils and PyYAML; text cases run on Windows
only). When you change a check, add a case that fails without the change.
