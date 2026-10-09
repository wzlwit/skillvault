---
name: pbi-report-visual-conventions
description: "Power BI report visual conventions: canvas #FAF9F8 and Fit to width, full numbers, \"(Blank)\" for blanks, titles that fit, chart labels and lines, with a checker for formats, blanks and text fit. Use when building or reviewing report visuals; pbi-report-layout-tests automates the layout checks on PBIR and PBIX, pbi-tmdl-workflow covers editing the files, kpi-dashboard platform-agnostic design, powerbi-modeling DAX."
metadata:
  author: wzlwit
  version: "1.0.0"
---

# Power BI Report Visual Conventions

What every page and visual of a Power BI report must look like, and how to check it. The rules come from a full
dashboard review of a new report (October 2026) and a survey of the team's shipped reports. `pbi-tmdl-workflow`
covers how to edit TMDL and PBIR files; this skill covers the result.

## Workflow

1. Before you set or change a convention, look at the team's shipped reports (their `visual.json` and TMDL) and
   follow what they do. A reviewer's request that contradicts every shipped report needs an explicit decision,
   written down in the design doc, before you implement it.
2. Build the visuals by the rules below.
3. Run the checker (see [Checks](#checks)) after every generation. Fix each finding, or write down why it does not
   apply. For page geometry, field bindings and PBIX-vs-PBIP parity, also run `pbi-report-layout-tests`.
4. Before a release, render every page on test data. Read [references/render-check.md](references/render-check.md)
   first. Static checks cannot see label lengths that come from data, lines that hide each other, or scrollbars.

## Page and report settings

Every page, including hidden drill-through and placeholder pages:

| Setting | Value | PBIR |
| --- | --- | --- |
| Canvas background | `#FAF9F8`, transparency 0% | `page.json` `objects.background`: `color` and `transparency` `0D` |
| Page view | Fit to width | `page.json` `"displayOption": "FitToWidth"`. It is stored per page, and a new page defaults to Fit to page |
| Filters pane | Collapsed, still available | `report.json` `objects.outspacePane`: `expanded` false, `visible` true. Never set it per page |

Desktop saves the pane state, each page's view and the active page into the file. Before `Save As` `.pbix`,
collapse the Filters pane, leave every page on Fit to width and select the first page. The JSON blocks are in
`pbi-tmdl-workflow` under Page and Report Settings.

## Numbers

| Kind | `formatString` | Shows |
| --- | --- | --- |
| Count | `#,##0` | 1,234 |
| Rate | `0.0%;-0.0%;0.0%` | 63.3% |
| Any other number (averages, ratios) | `#,##0.0` | 4,515.1 |
| Duration | `#,##0.0 \h`, `#,##0.0 \d` | 4,515.1 h |

- A duration carries its unit in the value, never in the title: "Time to resolution (hrs)" wrapped onto the value
  in a KPI tile. The backslash makes `h` and `d` literal text; without it they are time codes. Unit letters are not
  translated, but the number follows the viewer's locale ("4.515,1 h" in German).
- Never K or M. Set display units to None (`1D`) on every card value (`labels.labelDisplayUnits`), on every value
  axis (`valueAxis.labelDisplayUnits`, plus `secLabelDisplayUnits` on combo charts) and on shown data labels
  (`labels.labelDisplayUnits`). Auto turned an hours axis into "0K / 5K / 10K".
- Donut and pie percent labels get one decimal, `labels.percentageLabelPrecision` `1D`. Auto showed "37.75%" next
  to "32%".
- Give each quantity one unit across the report. The same value in hours and in days on one page reads as two
  different numbers.

## Blank vs 0

A blank stays blank. This is the convention of the team's shipped reports: none of them shows a dash, and their
classic cards show "(Blank)".

- No measure replaces a blank. That rules out `COALESCE`, an `IF ( NOT ISEMPTY ( T ), ... )` guard,
  `IF ( ISBLANK ( x ), <constant>, ... )`, `+ 0`, a `DIVIDE` alternate result other than `BLANK()`, and dash or
  "N/A" text.
- Real zeros still show. A count whose rows sum to 0 shows `0`, and `DIVIDE(0, 129)` shows `0.0%`.

| Situation | Card | Table |
| --- | --- | --- |
| Count whose rows sum to 0 | `0` | `0` |
| Count with no row to count (the filter leaves none) | (Blank) | empty cell |
| Rate or average without a denominator | (Blank) | empty cell |
| Rate with a denominator and a zero numerator | `0.0%` | `0.0%` |
| Name with nothing to name (a top item, a ranked member), and its sub-label | (Blank) | |
| Drill-through header with nothing selected: `IF ( ISFILTERED ( c ), SELECTEDVALUE ( c ) )` | (Blank) | |

A column the pipeline has not computed yet (NULL) stays blank too, not a made-up 0 or 0.0%.

Substitutes were tried on a new report and reverted:

- A classic card has no "show blank as" setting; in Desktop 2.154 only the new card visual and chart data labels
  have one. Replacing "(Blank)" on cards therefore needs a hidden display measure for every card. That doubled the
  measure count, turned numbers into text (`FORMAT ( v, <format>, USERCULTURE () )`), and made card tooltips show
  the display measure's internal name.
- `COALESCE ( x, 0 )` makes a measure non-blank for every member, so tables and charts list members that have no
  data. Avoiding that takes an `ISEMPTY` guard on every count.
- A dash in a table turns a numeric column into text, so the column sorts alphabetically.

When the shipped reports disagree (some return 0 from rates with `DIVIDE ( x, y, 0 )`, most return blank), pick one
rule for the report and keep it everywhere.

## Titles, captions and notes

- Every title and subtitle fits its visual on one line in English. A wrapped KPI title overlaps the value under it,
  and a cut one ends in "…". Other languages run longer, so English is the minimum. Allow about 24 px of padding;
  the checker measures this.
- Keep titles short and unit-free. Give each measure the same name on every page. A chart's title uses its legend's
  terms: "Time to first vs final resolution" over the series "Time to first resolution" and "Time to final
  resolution".
- A card sub-label that pairs a number with a name puts the number first, because a narrow card cuts the end of the
  text. Write it as `FORMAT ( [Count], "#,##0", USERCULTURE () ) & " · " & [Name]`, which shows
  "103 · Default entity queue". Return blank when there is no name. `USERCULTURE ()` formats for the viewer's locale.
- For a fixed one-line note under a KPI ("No update in 7 days"), use a textbox whose title holds the text, so it can
  be localized, and set `objects.general.paragraphs` to `[]`. A titled textbox under about 48 px with any
  paragraph, even an empty one, shows a scrollbar.
- If a trend groups by a cohort, say so in a subtitle ("By month created, resolved cases only"). Recent cohorts hold
  only the quick cases, so such a line falls.
- Bind every title, subtitle, slicer label, button label and alt text to the localization constants
  (`pbi-tmdl-localization-visual-titles`). Leave no literal report text.

## Charts

- Bar charts: let category labels take up to 40% of the width (`categoryAxis.maxMarginFactor` `40D`), so names
  like "Problem Solved" are not cut to "Problem So…". A chart whose names come from data (product names) needs more
  width, for example 400 px with 50% for labels. Only a render shows how long those names are.
- Donut: put the legend on the right (`legend.position` `'RightCenter'`), one name per line. Keep series captions
  short enough for about 30% of the visual's width minus 30 px ("SLA breached", not "SLA breached cases"). Use the
  label style "Data value, percent of total", with one decimal.
- Two series that can be equal, such as first and latest resolution with no reopens: draw the first solid, stroke 3,
  with circle markers of size 6, and the second dashed on top, stroke 2, with square markers of size 3. Set them in
  `objects.lineStyles`, one entry per series with `selector.metadata` set to its `queryRef`. Turn markers on. Where
  the values are equal, the circle rings the square, even with a single data point.
- Ordinal categories (priority High, Normal, Low): sort by a sort-by column holding the code, and turn data labels
  on. If labels can differ only in case or trailing spaces, set the sort value to the lowest code among labels the
  engine treats as equal. Power Query compares exactly but the engine does not, so two sort values for one label
  fail the refresh.
- Filter categories by code, not by label, so values an organization adds still show.
- A descending "busiest" or top ranking requires a value above 0, so a member summing to 0 is never named. Rank on
  the ID so equal names never merge, break ties by name and then ID, and give "lowest" or "worst" rankings a
  minimum-volume measure.

## Checks

```text
python scripts/check_visual_conventions.py <Report folder> [--model <SemanticModel folder>] [--resx <en-US .resx>]
    [--checks pages,units,blanks,formats,captions,text] [--format <regex>]... [--separator " · "]
```

The script needs only the Python standard library and exits with 1 when it finds a problem.

| Check | Finds |
| --- | --- |
| `pages` | A page that is not Fit to width or not on the `#FAF9F8` canvas at 0%; a Filters pane that is not collapsed, is hidden, or is set per page |
| `units` | Display units other than None on card values, value axes and shown data labels; donut and pie percent labels without one decimal |
| `blanks` | A measure that replaces a blank (needs `--model`) |
| `formats` | A visible measure's format string outside the report formats; add one with `--format` (needs `--model`) |
| `captions` | A number-and-name caption that puts the name first (needs `--model`) |
| `text` | A title or subtitle wider than its visual, a side-legend name wider than the legend, a short titled textbox with a paragraph (Windows only; reads bound titles from `--resx`) |

- The text margins were calibrated on one 1280 x 720 report in Segoe UI. On another report, confirm a text finding
  with a render before you change a title.
- Titles that are hidden by default (buttons, shapes, textboxes, slicers) count only when the visual turns them on.
- The tests use a small synthetic report: run `python -m unittest discover -s tests` from this folder. When you
  change a check, add a case that fails without the change.

## Related skills

- `pbi-report-layout-tests`: automated layout tests with pbir-utils and PBIXRay, on PBIR folders and PBIX files
  (page settings and display units as rules, geometry, bindings, parity). It shares the page-setting and
  display-unit checks with this skill's checker.
- `pbi-tmdl-workflow`: editing TMDL and PBIR, the Desktop round trip, the page-settings JSON.
- `pbi-tmdl-localization`, `pbi-tmdl-localization-visual-titles`: captions and report text.
- `pbi-localization-pr-review`: the localization gate for a PR.
