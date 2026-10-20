---
name: powerbi-build
description: "[convert] Alone: projects here. Text: build or change that. Change Power BI project (PBIP) files as code: Tabular Model Definition Language (TMDL) models, enhanced report format (PBIR) layouts, the Power BI Desktop round-trip, and Power BI Desktop file (PBIX) to PBIP conversion, with the pitfalls that break them. Use to edit TMDL, change a measure or visual, add a slicer or page, fix a Desktop load error, or convert a PBIX. Overlaps with powerbi-modeling on model changes (it owns model design); Microsoft's powerbi-report-cli and semantic-model-authoring on PBIR and TMDL authoring (they use Microsoft's CLI; this has the file-level tricks); powerbi-test, which checks the result; and powerbi-localize on translations."
metadata:
  author: wzlwit
  version: "1.1.0"
argument-hint: "[convert] [<model or layout change>]"
---

# Power BI Build

`/powerbi-build` changes a Power BI project (PBIP) as code: the Tabular Model Definition Language (TMDL) files of
its semantic model, the enhanced report format (PBIR) JSON of its report layout, the Power BI Desktop round trip that
loads and saves them, and conversion to and from a Power BI Desktop file (PBIX). It holds file-level tricks and the
pitfalls that break these files. Model design belongs to `powerbi-modeling` and checking to `powerbi-test`.
Microsoft's [powerbi-report-cli and semantic-model-authoring](https://github.com/microsoft/skills-for-fabric/tree/main/plugins/powerbi-authoring)
skills are the alternative for full authoring with Microsoft's command-line tool.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | Lists the PBIP projects under the current folder with their model and report formats, then offers the next step |
| Text | Builds or changes what the text names, then has Desktop load it |
| `convert [<file or folder>]` | [Converts](./references/round-trip.md#convert) between PBIX and PBIP, upgrades a legacy report to PBIR, or does the one-time setup |

- **Alone** looks under the current folder for `*.pbip` files and `*.SemanticModel` and `*.Report` folders. It shows
  each project with its model format (a `definition/` folder is TMDL; `model.bim` is the older JSON format, Tabular
  Model Scripting Language or TMSL), its report format (a `definition/` folder is PBIR; `report.json` beside
  `definition.pbir` is PBIR-Legacy), and the model that `definition.pbir` points at (`byPath`: a local model folder;
  `byConnection`: a published model, not editable here). PBIX files without a project are listed as `convert`
  candidates. It only reads, then asks once which project and change to work on; no answer changes nothing. The view
  ends with one line: describe a change to build it, such as "add a Region slicer to the Sales page", or say
  `convert <file>`.
- **Text** builds or changes what the text names:
  1. Pick the project: the only one here, or ask once which.
  2. Plan the edit: the files to touch and the exact model names to use, read from the model's files. For what a
     measure or relationship should mean, use `powerbi-modeling`; for translations, use `powerbi-localize`.
  3. Read the matching reference below, then edit with Desktop closed, keeping existing names and IDs (rules below).
  4. Load check: ask the user to open the project in Desktop, or to apply the external changes, and fix any error it
     names. Then offer `powerbi-test`.
- **`convert`** guides the user through Desktop's Save as, from PBIX to PBIP and back, upgrades a legacy report to
  PBIR, and does the one-time setup: Desktop options and Windows long paths. Desktop does the conversion; the skill
  checks the folders it writes and reads machine settings, and changes a machine setting only when asked. Before
  `convert`, read the [round trip reference](./references/round-trip.md).

## Rules for every edit

- **One source of truth.** Desktop keeps its own copy of an open project and writes it back on save, over file
  edits. Before editing, check whether Desktop is running (`Get-Process PBIDesktop`). Edit with it closed, or have
  the user save in Desktop first and apply the external changes afterward (a preview option). Never edit files while
  Desktop holds unsaved changes.
- **Exact names.** A visual's fields (`Entity` and `Property`), its `queryRef` values and selectors, filters, and
  TMDL references (`sortByColumn`, relationships, DAX) must match the model's names exactly. Read names from the
  model files, not from labels on screen. A renamed table, column, or measure breaks every visual that still uses the
  old name, in this report and in any other report bound to the model.
- **Keep names and IDs.** Don't rename existing pages, visuals, bookmarks, filters, page bindings, sync groups,
  relationships, or lineage tags. Give each new object a new unique name; never reuse one from a copied file.
- **Follow the schema.** Each PBIR file names its JSON schema in `$schema`, and a property the schema doesn't allow
  stops the load. Copy property shapes from a file Desktop saved in the same project, and keep that file's schema
  version. Save files as UTF-8 without a byte order mark.
- **The project's style.** Match the existing pages and the project's style file, if it has one. This skill sets no
  canvas size, colors, fonts, number formats, display units, or blank-versus-zero policy.
- **Only the requested change.** Change only the files the request needs. Never edit a PBIX by hand, and never
  publish, deploy, refresh in the Power BI service, change workspace permissions, or delete items as a side effect.
- **Verify.** Before the Desktop check, parse each changed JSON file and confirm that each field it uses exists in
  the model files. The change is done when Desktop opens the project without errors and the changed pages and
  measures look right. Full checks belong to `powerbi-test`.

## References

- Before editing TMDL, read [model edits](./references/model.md): indentation, expressions, names, descriptions,
  format strings, lineage tags, `ref` ordering, renames.
- Before editing PBIR, read [layout edits](./references/layout.md): folders, names, positions and layers, groups,
  field bindings, filters, slicers, display units, bookmarks, drill-through, alt text, scripted visuals.
- Before `convert`, before the load check, or when Desktop shows an error, read the
  [round trip reference](./references/round-trip.md): setup, conversion, the edit, open, save, and refresh order,
  what Desktop rewrites, review noise, and the pitfalls table.

## Related skills

- `powerbi-modeling` designs the model: grain, relationships, DAX meaning, row-level security, performance.
- `powerbi-test` checks the result before check-in or release; `powerbi-localize` translates captions and report text.
- `kpi-dashboard` covers metric meaning and dashboard design.
