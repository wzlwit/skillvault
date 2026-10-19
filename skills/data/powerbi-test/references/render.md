# Rendered Check

Contents: When; Where to render; A test copy in the service; Screenshots; What to look for; Gotchas; Clean up.

A static check reads files. A render shows what a viewer sees: label lengths that come from data, series that hide
each other, scrollbars, and where "(Blank)" shows.

## When

- After changes to titles, labels, legends, line styles, card captions, or blank handling.
- Before the release Power BI Desktop files (PBIX) are saved for the last time, so one save carries every fix.

## Where to render

Use the cheapest place that shows the pages with real or test data:

1. **Power BI Desktop.** Open the project (`.pbip`), refresh against test data, and look at every page, including
   hidden drill-through and tooltip pages.
2. **Microsoft's powerbi-report-cli skill**, in the
   [powerbi-authoring plugin](https://github.com/microsoft/skills-for-fabric/tree/main/plugins/powerbi-authoring).
   Its `powerbi-report-author` tool validates the enhanced report format (PBIR) files against their schemas and
   previews and screenshots pages in Desktop or the service.
3. **A test copy in the Power BI service**, for an unattended pass over every page. This publishes, so it needs the
   user's explicit approval and a test workspace they own; never the release or production workspace.

## A test copy in the service

Only after approval, and only in the test workspace:

1. Import the model and report once
   ([Post Import In Group](https://learn.microsoft.com/rest/api/power-bi/imports/post-import-in-group)), and keep the
   item IDs in a local file outside the repository.
2. Push later changes from the project folders without a Desktop save, through Fabric's
   [Update Semantic Model Definition](https://learn.microsoft.com/rest/api/fabric/semanticmodel/items/update-semantic-model-definition)
   (format TMDL, the Tabular Model Definition Language) and
   [Update Report Definition](https://learn.microsoft.com/rest/api/fabric/report/items/update-report-definition)
   (format PBIR). Send each file of the `.SemanticModel` or `.Report` folder as a base64 part, leaving out `.pbi/` and
   `.platform`. In the payload only, point the model at test data (for example through its data-path parameter) and
   replace the report's `definition.pbir` with a `byConnection` reference to the test model; the API needs only
   `semanticmodelid=<id>`. The files in the repository keep their values.
3. Both calls may answer `202`: poll the `Location` header, waiting `Retry-After` seconds between polls, until the
   operation succeeds ([long-running operations](https://learn.microsoft.com/rest/api/fabric/articles/long-running-operation)).
4. Set the data-source credentials again after each model update, refresh, and wait for the refresh to complete; on
   a failure, read its error details.

## Screenshots

Embed the report in a small page served on `127.0.0.1` only, with the Power BI JavaScript client
([Embed a report](https://learn.microsoft.com/javascript/api/overview/powerbi/embed-report)):

- The local server hands out the embed URL and the signed-in user's token on each request. Never write a token to
  disk, into the page source, or into logs or chat.
- Hide the filter and page-navigation panes, and set a global flag on the `loaded`, `rendered`, and `error` events so
  a browser script can wait for it.
- For each page: navigate by URL (`?page=<pageName>`), since switching pages through the API did not always repaint
  in a headless browser; wait for `rendered` and a few seconds more, because visuals keep painting; then capture at a
  fixed viewport larger than the page, so a page in Actual size view doesn't scroll sideways.
- Hidden pages render by name too. A drill-through page without a selection shows its header as "(Blank)", as
  expected.

## What to look for

- Each title on one line; no "…" in titles, legend names, or category labels.
- Numbers as the project's style says: display units, decimals.
- Both series visible where two lines can be equal.
- "(Blank)" only where the data has nothing, and no dashes or made-up zeros unless the style says so.
- No scrollbar in small textboxes, and no sideways scrolling at the width viewers use.
- Date slicers work: change the range, by dragging when the slider shows or by typing the dates when it's off, and
  check that the page's numbers change and, with synced slicers, that the range follows to the next page. A slider
  that's switched on but not drawn, as on a slicer too short for it, has no visible size in the rendered page
  (observed).

## Gotchas

- A blank or "Loading data…" capture is transient: wait and take it again. "Execution context was destroyed" means
  the page was still navigating: wait again.
- Token helpers can give up early: `AzureCliCredential` waits 10 seconds for the Azure CLI by default, which can take
  longer to start. Pass a longer `process_timeout`, or run `az account get-access-token` once first.
- Browser tools may save screenshots only under certain folders, such as the repository. Move them out right away
  and delete the folder, so nothing lands in a commit.

## Clean up

Stop the local server and close the browser. Keep the test items for the next round; when the report ships, offer to
delete them, and delete them only when the user asks.
