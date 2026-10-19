# Model edits

Contents: Files; Indentation; Expressions; Names and references; Descriptions; Measures and format strings;
New objects and lineage tags; Ordering with ref; Renames and removals; Leave these alone; Sort-by columns.

How to edit the Tabular Model Definition Language (TMDL) files of a Power BI project (PBIP). Facts come from
Microsoft's [TMDL overview](https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview) and
[semantic model folder](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset) pages unless
marked observed. Observed means seen in real projects but not documented: confirm it in Desktop before relying on it.
Symptoms and fixes are in the [pitfalls table](./round-trip.md#pitfalls).

## Files

The model is in `<Name>.SemanticModel/definition/`:

| File | Holds |
| --- | --- |
| `database.tmdl`, `model.tmdl` | Compatibility level; model settings and the `ref` lines that order tables, roles, cultures, and perspectives |
| `tables/<Table>.tmdl` | One table: its columns, measures, hierarchies, and partitions |
| `relationships.tmdl` | Every relationship |
| `expressions.tmdl` | Shared Power Query (M) queries and parameters |
| `cultures/`, `roles/`, `perspectives/` | One file each |

A `model.bim` in place of `definition/` means the model was saved in the older JSON format, Tabular Model Scripting
Language (TMSL); see [Convert](./round-trip.md#convert).

The [TMDL extension for VS Code](https://marketplace.visualstudio.com/items?itemName=analysis-services.TMDL) adds
highlighting and error checks. When Desktop is already open, its
[TMDL view](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-tmdl-view) applies a TMDL script to the
open model, in a project or a Power BI Desktop file (PBIX), with no file round trip.

## Indentation

Indent with tabs, one tab per level. A wrong level is a parse error. In a table file:

| Tabs | Holds |
| --- | --- |
| 0 | The object: `table Orders` |
| 1 | Its children: `column`, `measure`, `hierarchy`, `partition` |
| 2 | Their properties: `dataType:`, `formatString:`, `isHidden` |
| 3 | A multi-line DAX or M expression |

Top-level objects (`table`, `relationship`, `role`, `expression`, `culture`) start at the left margin of their file.

## Expressions

- A short expression stays on the declaration line, after `=`.
- A long one starts on the next line, one level deeper than the object's properties (three tabs for a measure in a
  table file), and every line of it stays at that depth or deeper. The properties after it go back to two tabs.
- Blank lines inside an expression are part of it; trailing blank lines and spaces are dropped. To keep whitespace
  exactly, wrap the expression in triple backticks right after the `=`.

```tmdl
table Orders

	measure 'Order Count' = COUNTROWS(Orders)
		formatString: #,##0

	measure 'Average Order Value' =
			DIVIDE(
				SUM(Orders[Amount]),
				[Order Count]
			)
		formatString: #,##0.00
```

## Names and references

- Put a name in single quotes when it contains a space, dot, equals sign, colon, or single quote, and double an
  embedded quote: `'Customer''s Region'`.
- Properties that point at another object use the same quoting: `sortByColumn: 'Month Number'`. A qualified name
  joins with a dot: `Orders.'Order Date'`. Inside DAX, use DAX syntax instead: `Orders[Order Date]`.
- A property value sits on one line after its colon. A boolean property written alone means true: `isHidden`.
- Children can come in any order, and a table can even be split across files, but each object and property can be
  declared only once in the whole folder: a measure declared in two files fails to load. Search the `definition`
  folder for a name before adding it.

## Descriptions

A description is one or more `///` lines directly above the object, with no blank line between them and the
declaration:

```tmdl
	/// Orders placed in the period, including cancelled ones.
	measure 'Order Count' = COUNTROWS(Orders)
		formatString: #,##0
```

## Measures and format strings

- `formatString` uses Excel-style codes with up to three sections, positive;negative;zero
  ([custom format strings](https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-custom-format-strings)).
- A backslash makes the next character literal, so a unit can live in the value instead of the title:
  `#,##0.0 \h` shows `12.5 h`. Without the backslash, letters such as `h` and `d` are date and time codes.
- A visual can still shorten a formatted value to `8K` when its display units are Auto; that's a report setting
  ([display units](./layout.md#display-units-and-text)).
- Return blank or zero for "no data" the way the project's other measures do; that choice is house style.
- Hide helper measures with `isHidden` and group measures with `displayFolder`.

## New objects and lineage tags

- A data column needs `dataType` and a `sourceColumn` equal to a column the table's partition query returns; a new
  source column also needs the query to return it, and has no data until a refresh. A calculated column is
  `column <Name> = <DAX>`.
- `lineageTag` keeps an object's identity across renames
  ([lineage tags](https://learn.microsoft.com/en-us/analysis-services/tom/lineage-tags-for-power-bi-semantic-models)).
  Leave existing tags alone. A new object doesn't need one; if you add one, make it a new GUID that is unique in the
  model, never a copy.
- A new relationship needs a unique name; Desktop uses a GUID. `New-Guid` in PowerShell makes one.

## Ordering with ref

`model.tmdl` lists tables, roles, cultures, and perspectives in `ref` lines, which fix their order. A table file with
no `ref` line still loads and goes to the end of the list; a `ref` line without a file is ignored. Add a `ref table`
line where a new table belongs, or Desktop's next save lists the table last, and remove the line with the table:

```tmdl
ref table Date
ref table Region
ref table Orders
```

## Renames and removals

- Report visuals find model objects by name. Before renaming a table, column, or measure, search the report's
  `definition` folder, and other reports bound to the model, for the old name, and update every `Entity`,
  `Property`, `queryRef`, and selector that uses it.
- In a composite or Direct Lake model, objects synced from the source come back at the next schema sync unless the
  change is declared: a `changedProperty` for a renamed or changed property, and a `PBI_RemovedChildren` annotation for
  a removal (see the lineage tags page).

## Leave these alone

- Auto date/time tables (named `LocalDateTable_…` and `DateTableTemplate_…`): Desktop owns them, and a date column
  added outside Desktop gets none.
- `diagramLayout.json`: not editable outside Desktop.
- Pending query edits: if `.pbi/unappliedChanges.json` exists, have the user apply or discard those changes in Desktop
  first. Applying them later replaces any query edits made in the files.

## Sort-by columns

Each label needs exactly one sort value in its `sortByColumn`. The engine treats labels that differ only in case or
trailing spaces as one label, so two sort values for such labels fail the refresh (observed).
