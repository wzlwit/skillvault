# Round trip and conversion

Contents: Setup; Convert; Edit, open, save, refresh; What Desktop rewrites on save; Review noise; Pitfalls.

How a Power BI project (PBIP) and its Tabular Model Definition Language (TMDL) and enhanced report format (PBIR) files
go through Power BI Desktop: one-time setup, conversion to and from a Power BI Desktop file (PBIX), the order of
editing, opening, saving, and refreshing, what Desktop changes when it saves, and what goes wrong. Facts come from
Microsoft's [PBIP overview](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview),
[external editing](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-external-editing), and
[report folder](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report) pages unless marked
observed. Observed means seen in real projects but not documented: confirm it before relying on it.

## Setup

Once per machine. Read the current state and show the user what to change; change a machine setting only when asked.

1. **Desktop.** Power BI Desktop for Windows. From the September 2026 release, PBIP and PBIR are generally available
   and PBIR is the default report format. Older releases need these under File > Options and settings > Options >
   Preview features: Power BI Project (.pbip) save option, with Store semantic model using TMDL format and Store
   reports using enhanced metadata format (PBIR); and, for PBIX files, Store PBIX reports using enhanced metadata
   format (PBIR).
2. **Reload without reopening (optional).** From the August 2026 release, the preview option Detect and reload
   external PBIP changes lets Desktop apply file edits while the project stays open. Restart Desktop after turning
   it on.
3. **Paths.** Desktop needs every project file path under 260 characters. Turning on Windows long paths didn't lift
   that limit for Desktop (observed); the setting affects only apps declared long-path aware
   ([Windows path limit](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation)). Keep
   the project root short, such as `C:\pbi\<project>`, or open the project through a short link to a deep folder:
   `mklink /D C:\p "<deep folder>"` in an elevated prompt; `rmdir C:\p` later removes only the link (observed). Long
   paths still help other tools: set `LongPathsEnabled` to 1 (administrator, then restart Windows) and run
   `git config --global core.longpaths true`. To copy deep folders, use `robocopy` or a `\\?\` path prefix.
4. **Git.** Keep the `.gitignore` that Desktop writes, which leaves out `.pbi/localSettings.json` and `.pbi/cache.abf`.
   Desktop writes CRLF line endings, so set `core.autocrlf` to avoid whole-file diffs. Save projects in a local folder,
   not a OneDrive or SharePoint one, where syncing can make saves fail.

## Convert

Only Desktop converts between PBIX and PBIP, with File > Save as; no API or tool does it. The user drives Desktop:
give the steps, then check the folders it wrote.

- **PBIX to PBIP.** Open the PBIX and save it as a Power BI project (`.pbip`) in a short local folder. Desktop writes
  `<Name>.pbip`, `<Name>.SemanticModel\`, `<Name>.Report\`, and a `.gitignore` if the folder or its Git repository has
  none.
- **PBIP to PBIX.** Open the `.pbip`, or the report's `definition.pbir`, and save it as a Power BI file (`.pbix`).
  Then close Desktop, reopen the PBIX, refresh it, and check the changed pages before anyone ships it.
- **Legacy report to PBIR.** A report folder with `report.json` beside `definition.pbir` and no `definition\` folder
  is PBIR-Legacy. A current Desktop converts it to PBIR the next time the report is edited and saved, and keeps a
  backup for 30 days in `%USERPROFILE%\AppData\Local\Microsoft\Power BI Desktop\TempSaves\Backups` (Microsoft Store
  version: `%USERPROFILE%\Microsoft\Power BI Desktop Store App\TempSaves\Backups`). An older release needs the PBIR
  preview option first. Expect one large diff, and keep it apart from other changes.
- **TMSL to TMDL.** A model folder with `model.bim` uses the older JSON format, Tabular Model Scripting Language
  (TMSL). Where the release still lists Store semantic model using TMDL format, turn it on and save the project again;
  a `definition\` folder replaces `model.bim`.
- **Check the result.** The model folder has `definition\` with `.tmdl` files, the report folder has `definition\`
  with `pages\`, and `definition.pbir` points at the model.
- Power BI projects don't support sensitivity labels. Follow the organization's labeling rules before converting a
  labeled PBIX.
- Never edit or repack a PBIX by hand: a repacked PBIX that the Power BI service accepted still wouldn't open in
  Desktop (observed). Change the project, then save it as a PBIX from Desktop.

## Edit, open, save, refresh

With Desktop closed, which always works:

1. Save in Desktop and close it. Keep `.pbi\cache.abf`: it holds the data, and without it the project opens with no
   data until a refresh.
2. Edit the files.
3. Open the `.pbip`. Desktop takes the model definition from the files and the data from the cache. When a file is
   wrong, Desktop names it and usually the place; fix it and open again.
4. Check the changed pages and measures. Measures work on the cached data at once; a new or changed table, source
   column, or query has data only after a refresh.
5. Refresh when the change needs data. If a refresh fails only in the project, as it has with a Delta Lake source
   (observed), skip it here and refresh the PBIX in step 7.
6. Save. Desktop rewrites some files (next section), so review the diff after this save, not before it.
7. When a PBIX is what ships: save as PBIX, quit Desktop, start it again with the PBIX, refresh, check, and save.
   Refreshing right after Save as, without restarting Desktop, has failed where a restart fixed it (observed).

With Desktop open and the reload preview option on: save in Desktop, edit and save the files, then select Apply
external changes in Desktop's banner. Applying discards Desktop's unsaved changes, resets filters, and doesn't reload
`cache.abf`. Some files, such as `definition.pbir`, can't be applied this way during the preview; close and reopen
for those.

## What Desktop rewrites on save

Expect changes in files nobody touched, and your edits in Desktop's own form:

- TMDL is written out again: keywords in camelCase, a `ref` line for every table, role, culture, and perspective,
  descriptions wrapped at 80 characters, trailing whitespace trimmed, and expressions whose whitespace matters wrapped
  in backticks ([TMDL overview](https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview)). Objects you
  added can gain a `lineageTag`.
- Settings Desktop can repair, such as an invalid `activePageName`, are fixed with a warning, and bookmarks lose the
  states of visuals that no longer exist.
- `pages.json` records the page that was open as `activePageName`, `report.json` keeps the Filters pane as it was
  left, and each page keeps its page view (observed).
- `$schema` URLs can move to newer versions when a newer Desktop saves (observed).
- A PBIR-Legacy report becomes PBIR.
- In a composite model built on a published model, the local copy of the remote model is regenerated when Desktop
  reconnects: `EXTERNALMEASURE` stubs and `sourceLineageTag` values change (observed).
- File and folder names stay as they are.

## Review noise

Usually noise, worth only a glance: `$schema` version changes alone, `activePageName`, `diagramLayout.json`, reordered
`ref` lines, rewrapped descriptions, new lineage tags on added objects, line-ending changes, and the regenerated copy
of a remote model in a composite model (review the source model's project instead).

Always review: measure expressions and format strings; visual fields, filters, positions, and visibility; page
bindings and bookmarks; filter and slicer selections, which hold data values; and `unappliedChanges.json`, which
holds pending query edits and is tracked by default (ignore it in Git to keep unfinished work out). `cache.abf` and
`localSettings.json` should never show up.

## Pitfalls

| Symptom | Cause | Fix |
| --- | --- | --- |
| Save as PBIP fails, or Desktop won't open the project, with a path error | A project file path over 260 characters | Use a short root or a short link ([Setup](#setup)) |
| Desktop names a `.tmdl` file and line | Wrong tab depth, a blank line between `///` and its object, or something declared twice | Fix it by the [model rules](./model.md) |
| Desktop names a PBIR file | Broken JSON, a property its schema doesn't allow, or a missing required one | Validate the file against its `$schema`, as VS Code does |
| A page or visual is gone after an edit | Its folder name has characters other than letters, digits, underscores, and hyphens, so Desktop skipped it | Rename it and restart Desktop |
| A visual shows an error about its fields | A field name doesn't match the model, often after a rename | Fix `Entity` and `Property` in the visual |
| A table renders empty, with no error | `nativeQueryRef` holds a label, or a table projection has `active: true` (observed) | Copy projections as Desktop writes them |
| A column width or series color is ignored | `selector.metadata` isn't the field's `queryRef` | Use the `queryRef` |
| A matrix shows the error `SecondaryGroupsWithoutPrimary` (observed) | Values switched to rows with no row field | Add a row field, or use a table |
| File edits vanished | Desktop was open with the old version and saved over them | Save in Desktop before editing; apply the external changes or reopen |
| Query edits made in the files are gone | Pending changes in `unappliedChanges.json` were applied over them | Apply or discard pending changes before editing queries |
| The project opens with no data | `cache.abf` is missing | Refresh, or open the PBIX and save it as a project again |
| A refresh fails only in the project (observed with a Delta Lake source) | The connector fails in project mode | Refresh the PBIX in a fresh Desktop session |
| A refresh fails right after Save as PBIX (observed) | The same session still holds the project's connection | Close Desktop, reopen the PBIX, and refresh |
| Desktop calls a PBIX corrupted or made by an unknown version | The PBIX was changed outside Desktop | Rebuild it from the project in Desktop |
| A copied page fails because `pageBinding.name` must be unique | The copy kept the original's binding name | Give the copy a new binding name |
| A copied bookmark lost most of its state | Its visuals don't exist on its page | Copy the page and visuals with it |
| A drill page shows all data (observed) | Its drill filter was written by hand | Add the field to the Drill through well in Desktop |
| A drill page also gets the source page's other filters | `acceptsFilterContext` is `Default` | Turn Keep all filters off (`None`) unless that's intended |
| After Back, the source page stays filtered while its slicers look unchanged (observed) | `Back` carried the drill filter | Switch the button to `PageNavigation` if only one page leads to the drill page |
| A button flickers or can't be clicked | A visual under it has a higher `z` | Raise the button's `z` |
| A card shows `8K`, or an axis `0K, 5K, 10K` | Display units are Auto | Set them to None where exact values matter |
| A card reads (Blank) | Nothing matches the selection, so the measure returns blank | Expected; blank versus zero is the project's choice |
| A title wraps onto a card's value (observed) | It's too long for the visual | Shorten it; put a unit in the format string |
| A small textbox shows a scrollbar (observed) | A short titled textbox has a paragraph | Empty the paragraphs and show the text as the title |
| A date slicer shows two dates but no slider | The slider is off (`slider.show` false), or the slicer is too short to draw it (observed: under about 95 px) | Expected when users type the dates. To let them drag, turn the slider on, make the slicer about 100 px tall, and check it in a render |
| Text and visuals grow or shrink with the window | The page view is Fit to page, a new page's default, or Fit to width | Set the project's page view on every page; Actual size keeps pixel sizes ([pages](./layout.md#pages)) |
| A colored page sits in a band of another color | The wallpaper is unset or differs; the canvas background colors only the page | Set the wallpaper (`objects.outspace`) on every page, hidden pages included ([pages](./layout.md#pages)) |
| A slicer is a list, not a dropdown (observed) | `mode` isn't `'Dropdown'` | Set `mode` in `objects.data` |
| A refresh fails on a sort-by column | A label has more than one sort value | One sort value per label ([model edits](./model.md#sort-by-columns)) |
| A visual's automatic filters are missing from `visual.json` | The Filters pane was never opened while editing | Open it once in Desktop and save |
