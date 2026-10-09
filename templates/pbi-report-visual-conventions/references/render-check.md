# Render Check

Contents: When; Test items; Push changes without Desktop; Embed page; Screenshot each page; What to look for;
Gotchas; Clean up.

A static check reads the files. A render shows what a viewer sees: label lengths that come from data, series that
hide each other, scrollbars, and where "(Blank)" shows.

## When

- After any change to titles, labels, legends, line styles, card captions or blank handling.
- Before re-saving the release PBIX files, so that one re-save carries every fix.

## Test items

Use a workspace you own on a capacity that allows embedding (PPU, Premium or Fabric). Never use the release or
production workspace.

1. Import the model and report PBIX once (`POST https://api.powerbi.com/v1.0/myorg/groups/<ws>/imports`). Keep their
   ids in a local state file outside the repository.
2. Point the model at test data. Change the data-path parameter in the pushed definition (below) or with the
   parameters API.
3. Set data-source credentials. List them with `GET .../groups/<ws>/datasets/<id>/datasources`, then
   `PATCH .../gateways/<gatewayId>/datasources/<datasourceId>` with an OAuth2 token for the source, for example
   `https://storage.azure.com/.default` for ADLS. Do this again after every model update.
4. Refresh (`POST .../datasets/<id>/refreshes`), then poll `GET .../refreshes?$top=1` until the status is
   `Completed`. On `Failed`, read `serviceExceptionJson`.

## Push changes without Desktop

Fabric item definitions update the test items straight from the PBIP folders, with no Desktop re-save:

- Model: `POST https://api.fabric.microsoft.com/v1/workspaces/<ws>/semanticModels/<id>/updateDefinition` with
  `{"definition": {"format": "TMDL", "parts": [...]}}`. The parts are every file under the `.SemanticModel` folder
  except `.pbi/` and `.platform`, each as `{"path": "<relative path>", "payload": "<base64>", "payloadType":
  "InlineBase64"}`. Change the data-path parameter in `definition/expressions.tmdl` in the payload only; the
  repository file keeps its value.
- Report: `POST .../reports/<id>/updateDefinition` with `"format": "PBIR"` and the files under the `.Report` folder.
  Replace `definition.pbir` in the payload with a `byConnection` reference to the test model:
  `Data Source=powerbi://api.powerbi.com/v1.0/myorg/<workspace name>;initial catalog=<model name>;integrated
  security=ClaimsToken;semanticmodelid=<model id>`.
- Both calls can answer `202`. Poll the `Location` header, waiting `Retry-After` seconds between polls, until the
  status is `Succeeded`.

## Embed page

Serve a small page on `127.0.0.1` only. It loads `powerbi-client`, fetches an embed URL and token from the local
server, and embeds the report:

- Embed config: `type: "report"`, `tokenType: Aad`, the signed-in user's token for
  `https://analysis.windows.net/powerbi/api`, `embedUrl` from `GET .../groups/<ws>/reports/<id>`, `pageName` from the
  page URL (`?page=<pageName>`), and `settings.panes.filters.visible` and `settings.panes.pageNavigation.visible` set
  to false.
- Set a global such as `window.__state` on the `loaded`, `rendered` and `error` events, so the browser script can
  wait on it.
- Never write the token to disk or into the page source. Serve it from the local endpoint on each request.

## Screenshot each page

For each page (Playwright or any browser automation):

1. Navigate to `http://127.0.0.1:<port>/?page=<pageName>`. Navigate by URL; `report.setPage` did not repaint
   reliably in a headless browser.
2. Poll `window.__state` until it is `rendered` or an error, then wait about 4 seconds more. Visuals keep painting
   after the event.
3. Take the screenshot at a fixed viewport (1280 x 790 holds a 1280 x 720 page and the frame).

Hidden pages (drill-through, placeholders) render by `pageName` too. A drill-through page without a selection shows
its header as "(Blank)", as expected.

## What to look for

- Each title on one line; no "…" in titles, legend names or category labels.
- Full numbers: no K or M on axes or cards; one decimal on averages and percent labels.
- Both series visible where two lines are equal.
- "(Blank)" only where the data has nothing; no dashes or made-up zeros.
- No scrollbar in small textboxes; canvas `#FAF9F8`; the page filling the width.

## Gotchas

- A blank or "Loading data…" capture is transient: wait and take it again. "Execution context was destroyed"
  means the page was still navigating: run the wait again.
- `AzureCliCredential` gives up after 10 seconds by default, and `az` can take longer to start. Pass a longer
  `process_timeout`, or run `az account get-access-token` once first.
- Browser tools may write screenshots only under allowed folders, such as the repository. Move them out right after
  and delete the folder, so nothing lands in a commit.

## Clean up

Stop the local server, close the browser, and keep the test items for the next round. Delete them when the report
ships.
