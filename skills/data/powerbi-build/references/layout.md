# Layout edits

Contents: Files; Pages; Names; Positions, layers, and tab order; Groups; Field bindings; Formatting values; Filters;
Slicers; Display units and text; Bookmarks and tab-like switching; Buttons and drill-through; Alt text; Generating
visuals with a script.

How to edit the enhanced report format (PBIR) JSON of a Power BI project's report. Facts come from Microsoft's
[report folder page](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report) and the public
[PBIR JSON schemas](https://github.com/microsoft/json-schemas/tree/main/fabric/item/report) unless marked observed.
Observed means seen in real reports but not documented: confirm it in Desktop. Symptoms and fixes are in the
[pitfalls table](./round-trip.md#pitfalls).

## Files

The report is in `<Name>.Report/definition/`:

| Path | Holds |
| --- | --- |
| `report.json` | Report settings: theme, report-level filters, Filters pane state (`objects.outspacePane`) |
| `pages/pages.json` | `pageOrder`, and the page the report opens on (`activePageName`) |
| `pages/<page>/page.json` | Display name, size, page view (`displayOption`), page filters, visibility, drill-through binding |
| `pages/<page>/visuals/<visual>/visual.json` | One visual or group: position, fields, formatting, visual filters |
| `bookmarks/` | One `<name>.bookmark.json` per bookmark, and `bookmarks.json` for their order and groups |
| `reportExtensions.json` | Report-level measures |
| `version.json` | The PBIR version |

`definition.pbir`, one level up, points at the model: `byPath` holds a relative path with forward slashes to a local
model folder; `byConnection` names a published model, which this project can't edit.

A new page needs its name in `pageOrder`. Pages missing from the list come after the listed ones, sorted by display
name.

## Pages

- Each page keeps its own view in `displayOption`: `FitToPage`, which a new page starts with, `FitToWidth`, or
  `ActualSize` ([page view settings](https://learn.microsoft.com/en-us/power-bi/create-reports/power-bi-report-display-settings)).
  The first two scale the page to the window, so its text and visuals grow or shrink with it. Actual size keeps the
  page's pixel size: a wider window shows canvas beside the page, and viewers scroll down a page longer than the window.
- The view and the canvas size are the project's house style. Set the view on every page, hidden pages included.
- In Actual size, size each page to its content: its `height` at least the bottom of its lowest visual plus a margin,
  adding a group's position to its members' positions ([Groups](#groups)). Pages may differ in height.
- Desktop saves each page's view, the Filters pane state, and the page that was open
  ([what Desktop rewrites](./round-trip.md#what-desktop-rewrites-on-save)), so set them before saving a PBIX.

## Names

- Each page, visual, and bookmark has a `name` that is also its folder or file name. Desktop makes 20-character hex
  names; older reports also have names such as `ReportSection…`. Both work.
- A name may hold only letters, digits, underscores, and hyphens, and page and visual names at most 50 characters.
  Desktop skips a folder whose name breaks the rule, so the page or visual silently disappears.
- Users see a page's or bookmark's `displayName` and a visual's title; change those, not `name`. Renaming a `name`
  breaks whatever refers to it (`pageOrder`, bookmarks, buttons, drill-through), and after renaming files or folders
  Desktop must be restarted.
- To find a visual's folder, turn on the Desktop report setting "Copy object names when right clicking on report
  objects", right-click the visual, select Copy object name, and search for it.

## Positions, layers, and tab order

- `position` needs `x`, `y`, `width`, and `height` in pixels from the page's top-left corner. Keep each visual inside
  its page's `width` and `height`.
- `z` is the layer: a higher `z` draws on top and takes the clicks. A button placed over a table needs a higher `z`
  than the table.
- `tabOrder` is the keyboard and screen reader order. Set it in Desktop (View > Selection > Tab order) and copy the
  values rather than computing them: the item Desktop listed first has carried the highest value, and items taken out
  of the tab order have carried negative values (observed).
- Remove decorative shapes, images, and background boxes from the tab order
  ([accessibility](https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-accessibility-creating-reports)).
- A hidden visual has `"isHidden": true`.

## Groups

A group is a `visual.json` with `visualGroup` in place of `visual`. Each member names it in `parentGroupName`:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/<version used by the other visuals>/schema.json",
  "name": "3f9c1a7e5b2d4c8e6a10",
  "position": { "x": 24, "y": 160, "z": 2000, "width": 640, "height": 360 },
  "visualGroup": { "displayName": "Orders by region", "groupMode": "ScaleMode" }
}
```

- `ScaleMode` resizes the members with the group; `ScrollMode` keeps their size and adds a scrollbar.
- A member's `position` counts from its group's top-left corner rather than the page's (observed on over a hundred
  grouped visuals). Add the offsets of every enclosing group to get page coordinates.
- Hiding a group hides its members.

## Field bindings

A visual lists its fields under `visual.query.queryState`, one entry per role. Role names depend on the visual type
(`Category`, `Y`, `Values`, and so on), so copy them from a visual Desktop made of the same type:

```json
"query": {
  "queryState": {
    "Category": { "projections": [ {
      "field": { "Column": { "Expression": { "SourceRef": { "Entity": "Region" } }, "Property": "Region Name" } },
      "queryRef": "Region.Region Name",
      "nativeQueryRef": "Region Name"
    } ] },
    "Y": { "projections": [ {
      "field": { "Measure": { "Expression": { "SourceRef": { "Entity": "Orders" } }, "Property": "Order Count" } },
      "queryRef": "Orders.Order Count",
      "nativeQueryRef": "Order Count"
    } ] }
  }
}
```

- `Entity` is the table and `Property` the column or measure, spelled exactly as in the model's Tabular Model
  Definition Language (TMDL) files. Use `Column` for a column and `Measure` for a measure.
- `queryRef` must be unique within the visual; for a plain column or measure, Desktop writes `Table.Field`.
- Keep `nativeQueryRef` as Desktop writes it, which for a plain column or measure is the field's own name, and set
  `displayName` on the projection to change the label users see. A table whose `nativeQueryRef` held a label instead
  rendered empty, with no error (observed).
- `active` marks the current drill level of a hierarchy. Leave it off table projections: `active: true` there also
  emptied a table (observed).

## Formatting values

- `visual.objects` formats the visual itself (labels, axes, data points). `visual.visualContainerObjects` formats its
  frame: title, background, border, header, alt text, and button action.
- Values are wrapped literals: `{ "expr": { "Literal": { "Value": "true" } } }`. Inside `Value`, Desktop writes text
  in single quotes (`"'Dropdown'"`, with an embedded quote doubled), a double with a `D` suffix (`"11D"`), an integer
  with `L`, a decimal with `M`, and a date as `"datetime'2026-01-31T00:00:00'"`.
- A setting for one field, such as a column width or a series color, has `"selector": { "metadata": "<queryRef>" }`
  with that field's `queryRef`, not its `nativeQueryRef`.
- The schema fixes the frame's object names but not the names in `visual.objects`, which vary by visual type. Set the
  option once in Desktop, save, and copy what Desktop wrote, and set nothing Desktop wouldn't: tables with extra
  properties have rendered empty (observed). For one series' color, Desktop wrote two `dataPoint` entries, one without
  a selector and one with it; keep both (observed).
- Colors can be theme references (`ThemeDataColor`) or literal hex values; follow what the project uses.

## Filters

- Report, page, and visual filters are in `filterConfig.filters` of `report.json`, `page.json`, and `visual.json`.
  Each has a report-unique `name`, a `field`, a `type` (`Categorical`, `Advanced`, `TopN`, `RelativeDate`, and
  others), and a `filter` body. Build a new one in Desktop and copy it.
- `howCreated` records the filter's origin. A drill-through page's filter must be `Drillthrough`, which Desktop writes;
  a hand-written `User` filter got no drill context (observed). See drill-through below.
- Filter and slicer selections are saved with their data values, so check them for values that don't belong in
  source control.
- A visual's automatic filters reach `visual.json` only after the Filters pane has been opened once while editing.

## Slicers

Slicer property names here are as Desktop wrote them for the classic slicer (`visualType` `slicer`) (observed).

- A slicer shows as a list unless `objects.data` sets `mode` to `'Dropdown'`.
- A date range slicer uses `mode` `'Between'` on a date column, so users set a start and an end date. A saved default
  range is `startDate` and `endDate` in `objects.data` plus a filter under `objects.general`: on or after the start
  (comparison kind 2) and before the day after the end (kind 3). Fixed dates don't roll forward: move them when the
  period ends, or leave out all three to open on every date.
- The range slider is optional. With `objects.slider.show` false, users type the two dates and the slicer can stay
  compact. With the slider on, the slicer must be tall enough to draw it (observed with one style: hidden at 85 and
  90 px, shown at 95 px), so check it in a render with your formatting.
- A slicer that shows only the two dates isn't broken when its slider is off. Make it taller or turn the slider on
  only when users should drag the range. To reuse another report's date slicer, copy its mode, field, filter, and
  sync group; its size is that report's layout choice.
- `syncGroup` (`groupName`, `fieldChanges`, `filterChanges`) keeps slicers with the same group name in step across
  pages. It applies only to slicers.

## Display units and text

- With display units on Auto, Power BI shortens large values to `8K`, or an axis to `0K`, `5K`, `10K`, whatever the
  measure's format string says. Desktop stores the choice as `labelDisplayUnits`, where `1D` means None: in a card's
  `labels`, a chart's `valueAxis` (with `secLabelDisplayUnits` for the second axis of a combo chart), and shown data
  labels (observed). Whether values may be shortened is the project's house style.
- A long title wraps, and on a small card the wrapped line covers the value (observed). Shorten it, and move a unit
  into the measure's format string ([model edits](./model.md#measures-and-format-strings)).
- A titled textbox shorter than about 48 px shows a scrollbar when it holds any paragraph at all, including an empty
  one (observed). For a one-line note, leave the paragraphs empty (`paragraphs` `[]` in `objects.general`) and show the
  text as the textbox's title.
- Category labels cut short with "…" get more room from `categoryAxis.maxMarginFactor`, a share of the visual's
  width (observed).

## Bookmarks and tab-like switching

- To switch between visuals in one spot, like tabs: stack the visuals at one position, add a bookmark per tab that
  shows one and hides the others, put those bookmarks in their own bookmark group, and insert a bookmark navigator
  (Insert > Buttons > Navigator > Bookmark navigator) that shows only that group. Its selected button follows the
  last bookmark chosen, so it marks the current tab for you
  ([navigators](https://learn.microsoft.com/en-us/power-bi/create-reports/button-navigators)).
- Hand-built tabs need two buttons per tab at the same spot, one styled as selected and one as plain, each linked to
  the tab's bookmark. Each bookmark shows its own tab's selected button and the other tabs' plain buttons. Keep the
  buttons above the visuals in `z`.
- Capture bookmarks in Desktop rather than writing them
  ([bookmarks](https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-bookmarks)). A bookmark stores each
  visual's state by name under `explorationState.sections.<page>.visualContainers`, where a hidden visual has
  `singleVisual.display.mode` `hidden`; `options` can limit it to `targetVisualNames`, or skip data or display state.
- Desktop drops a bookmark's states for visuals missing from its page when it saves, so a bookmark copied without its
  page and visuals loses most of its content.
- Visuals stacked for tabs share one position; tell them apart by the bookmark that shows each.

## Buttons and drill-through

- A button's action is `visualContainerObjects.visualLink`: `type` `'Bookmark'` with `bookmark`, `'PageNavigation'`
  with `navigationSection` (a page name), `'Drillthrough'` with `drillthroughSection`, or `'Back'` (type values as
  Desktop writes them, observed).
- Set up a drill-through page in Desktop by adding the field to the page's Drill through well
  ([drill-through](https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-drillthrough)). Desktop writes
  the `Drillthrough` filter, the `pageBinding` with its parameter, and a back button; such pages are usually hidden
  in view mode (`"visibility": "HiddenInViewMode"`).
- `pageBinding.acceptsFilterContext`: `Default` lets the source page's other filters through to the drill page;
  `None` stops them. Desktop's Keep all filters toggle sets it (observed). Let filters through on purpose, for
  example when one drill page leads to another.
- Users can reach a drill page from any visual that uses the drill field, not only from buttons. A `Back` button has
  returned to the source page carrying the drill filter, so the numbers changed while the slicers looked the same
  (observed). A `PageNavigation` button to the source page avoids that, but it always goes to that one page, so use it
  only if a single page leads to the drill page. List the source pages first (below).
- A drill-through button greys out while nothing is selected only when its color comes from the button's own `fill`,
  not from the container background (observed).
- To show the selected item in the drill page's header, use a measure such as
  `IF ( ISFILTERED ( Customer[Name] ), SELECTEDVALUE ( Customer[Name] ) )`; a card bound to the column itself didn't
  show it (observed).

Source pages of a drill page are the pages with a button that targets it or a visual that uses one of its drill fields
as is. This lists them; a field used through an aggregation or hierarchy level needs a look by hand:

```python
import json, pathlib

pages = pathlib.Path(r"<Name>.Report\definition\pages")
target = "<drill page name>"
binding = json.loads((pages / target / "page.json").read_text(encoding="utf-8")).get("pageBinding", {})
drill_fields = {json.dumps(p["fieldExpr"], sort_keys=True) for p in binding.get("parameters", []) if "fieldExpr" in p}

sources = set()
for path in pages.glob("*/visuals/*/visual.json"):
    page, visual = path.parts[-4], json.loads(path.read_text(encoding="utf-8")).get("visual", {})
    links = visual.get("visualContainerObjects", {}).get("visualLink", [])
    targets = {link.get("properties", {}).get("drillthroughSection", {}).get("expr", {}).get("Literal", {}).get("Value")
               for link in links}
    used = {json.dumps(p["field"], sort_keys=True)
            for role in visual.get("query", {}).get("queryState", {}).values() for p in role.get("projections", [])}
    if page != target and (f"'{target}'" in targets or used & drill_fields):
        sources.add(page)
print(sorted(sources))
```

## Alt text

- Set `altText` in `visualContainerObjects.general` on every visual that carries information, at most 250 characters
  ([accessibility](https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-accessibility-creating-reports)).
- Screen readers already announce the title and visual type, so say what the visual is about and the insight it
  should give, rather than current values. For values, bind the alt text to a measure.
- Decorative items need no alt text and leave the tab order.

## Generating visuals with a script

When many visuals follow one pattern, generate them from a visual Desktop saved, changing only what differs:

```python
import copy, json, pathlib, secrets

page = pathlib.Path(r"<Name>.Report\definition\pages\<page>")
template = json.loads((page / "visuals" / "<template visual>" / "visual.json").read_text(encoding="utf-8"))

def add_card(measure, x, y):
    visual = copy.deepcopy(template)
    visual["name"] = secrets.token_hex(10)  # 20 hex characters, like Desktop's names
    visual["position"].update(x=x, y=y)
    projection = visual["visual"]["query"]["queryState"]["Values"]["projections"][0]  # the template's role name
    projection["field"]["Measure"]["Property"] = measure
    projection["queryRef"] = f"Orders.{measure}"
    projection["nativeQueryRef"] = measure
    folder = page / "visuals" / visual["name"]
    folder.mkdir()
    (folder / "visual.json").write_text(json.dumps(visual, indent=2, ensure_ascii=False), encoding="utf-8")

for i, measure in enumerate(["Order Count", "Average Order Value"]):
    add_card(measure, x=24 + i * 216, y=24)
```

- Check each name against the TMDL first, keep the template's `$schema`, and remove settings that still name the
  template's field, such as a `selector.metadata` entry, a title, or alt text.
- Python's `utf-8` writes no byte order mark. Desktop reformats the files when it saves; review the diff after that.
