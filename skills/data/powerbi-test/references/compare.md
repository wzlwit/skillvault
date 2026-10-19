# Compare Two Projects

Contents: Inputs; Scope; Model; Measures; Visuals; Formatting; Values from screenshots; Severity; Report file;
Present the result.

`compare` lists how a target Power BI project (PBIP) differs from a base project, the reference, so the target can be
brought in line. It reads both projects and changes neither.

## Inputs

- Base and target: two project folders in the enhanced report format (PBIR), each with a `.Report` folder holding
  `definition/pages/`, a `.SemanticModel` folder holding `definition/tables/*.tmdl`, or both. Save a Power BI Desktop
  file (PBIX) as a Power BI project (`.pbip`) in Desktop first.
- Without paths, look for projects in the current folder's immediate subfolders. With exactly two, ask once which is
  the base; with none or more than two, ask for both paths.
- Scope, optional: `all` (the default) or any of `model`, `measures`, `visuals`, `format`, `values`, comma-separated.
- Screenshots, for `values` only: a folder the user names, otherwise `screenshots/` in the current folder. Images sit
  in `base/` and `target/` subfolders, or carry a `base` or `target` prefix and the page name, or are pasted into the
  chat.

## Scope

| Scope | Compares |
| --- | --- |
| `model` | Tables, columns and data types, relationships, storage modes and sources, parameters and shared queries |
| `measures` | Every measure: DAX, format string, data type, display folder |
| `visuals` | Pages, and per page the visuals, the fields they use, and the page and visual filters |
| `format` | Formatting of matched visuals: display units, decimals, fonts, axes, titles, colors |
| `values` | The numbers shown in screenshots of the same page in both projects |
| `all` | All of the above; `values` only when screenshots are available, otherwise it is listed as skipped |

## Model

Read each project's `.SemanticModel/definition` folder:

- `tables/*.tmdl`: tables; columns with name, data type, and source column; partitions with their mode (import or
  DirectQuery) and source.
- `relationships.tmdl`: the columns on both ends, cardinality, cross-filter direction, and whether it is active.
- `expressions.tmdl`, if present: parameters and shared Power Query (M) queries.

Report missing and extra tables and columns, data types that differ, relationship differences, and different sources
or storage modes.

## Measures

- List every measure of both models. `verify_report.py` has a parser: `tmdl_measures(<X.SemanticModel>)` returns the
  DAX, format string, and hidden flag of each (table, measure), so a short Python snippet can diff the two.
- Match by name first. For the rest, propose matches by display folder, caption, or expression; label them as
  proposed, and ask the user to confirm doubtful ones rather than guessing.
- Compare the DAX (whitespace aside), format string, and data type, and units hidden in names or formats: seconds
  against minutes, a percentage against a ratio.
- List base measures the target lacks, grouped by table or display folder.

## Visuals

- Pages: the order in `pages/pages.json`, and from each `page.json` the display name, size, visibility, page filters
  (`filterConfig`), and drill-through or tooltip binding (`pageBinding`).
- Match pages by display name. Compare only pages the target has, and list base pages it lacks.
- For each matched page, read every `visual.json`: visual type, the fields it uses (`query.queryState` projections),
  position and size, and visual filters. Group visuals as slicers, cards, charts, tables, navigation (buttons and
  navigators), and decoration (textboxes, shapes, images).
- Per group, report missing or extra visuals and fields, a different chart type, missing page or visual filters, and
  navigation differences.
- PBIR saves a visual's automatic filters only after the Filters pane has been opened once while editing, so a
  missing automatic filter may not be a real difference
  ([PBIR limitations](https://learn.microsoft.com/power-bi/developer/projects/projects-report)).

## Formatting

For matched visuals, compare `objects` and `visualContainerObjects`: display units and decimals on labels and value
axes, font families and sizes, axis settings, title text and visibility, and colors. Also compare each measure's
format string with what visuals override, such as decimals set on a card.

## Values from screenshots

- Pair the base and target images of each page, and read the numbers shown: cards, data labels, table cells.
- Compare only when slicer and filter selections, date ranges above all, are the same in both; otherwise say so and
  skip that page.
- Classify each pair: **Match** (equal, or within rounding); **Display difference** (the same value formatted
  differently, such as 3.5M shown as 4M; check it against the formatting findings); **Data difference** (the values
  differ: look for a missing page filter, a different measure, row-level filters, or other source data); **All
  blank** (a page that shows only "(Blank)": flag it as possibly broken).
- Explain each data difference with earlier findings where possible.

## Severity

| Level | Meaning | Typical findings |
| --- | --- | --- |
| High | Must fix: numbers or behavior differ | A missing page filter, slicer, measure, or table that a visual needs; a relationship difference; a unit mismatch; lost precision on averages or rates |
| Medium | Should fix | A different chart type, missing navigation, inconsistent format strings or font sizes, different columns in a matched table |
| Low | Nice to fix | Page size, axis formatting, annotations, expression layout |
| None | No action | Visuals only the target has; items already aligned |

A target item that matches a base item under another name keeps a severity: its fields still need aligning.

## Report file

Write Markdown to the path the user gives; otherwise to the project's existing artifacts or documentation folder
(`docs/` when there is none), named after both projects, for example `compare-<target>-vs-<base>.md`. Ask before
overwriting an existing file.

Give each finding an ID for cross-references: `S` for model structure, `M` measures, `P` pages and visuals, `F`
formatting, `D` values from screenshots, numbered in order (`P07`). Include only the sections for the scopes that ran:

1. Header: base and target paths with their page counts, the scope, the date, and notes such as a DirectQuery source.
2. Summary: the gaps ordered High, Medium, Low, each with the finding IDs behind it, then the differences that apply
   to every page.
3. Model, Measures, Pages (a subsection per page), Formatting, and Values: one table each, with the ID, severity,
   item, base, target, and how to fix it.
4. Counts by severity.

## Present the result

Say where the report is, the scope, how many pages were compared, the counts by severity, and the top three High
findings. Name the scopes that were skipped and how to run them.
