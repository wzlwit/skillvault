# Tracker guide

Use with the [shared workflow](workflow.md).

## Design the tracker

- Header: one line on the goal and its dates, a call to action for owners, a short legend, links to
  the guide and runbook, and the source snapshot (commit or date). Add a dated update line when the
  status changes materially.
- One table per group of items. Suggested columns: Item, Current state, Owner, Result, and Notes.
  Fold low-value columns into Notes, such as `Group: <name>`.
- Put the table with open work first, and open rows first within each table. Keep completed rows
  while their result still needs monitoring.
- An owner cell holds an authoritative owner or `TBD: A or B, asked <date>`.
- Make the result column a label with Not started, In progress, Completed, and Off track.

## Choose the location and access

- Create the tracker in a shared team workspace. A new workspace can have its creator as the only
  member, so everyone else needs a share link.
- With the user's approval, create a page link (**Share** > **Page link**). Loop creates a link that
  people in the organization can edit; read the full URL from the dialog, which may render inside a frame.
- Sensitivity labels can limit who can open the page, for example to employees only. Tell the user
  when partners or vendors are among the readers.
- After a move or a new link, update the links in invites and messages, or note which old ones remain.

## Build the page

These observations come from Loop on the web in a signed-in browser; confirm them with a page
snapshot before relying on them.

1. Create a page in the workspace, or reuse its empty starter page. Click the title, select all, type
   the title, and read it back; typing into the placeholder can interleave text.
2. Click the page body and dispatch a synthetic paste on the focused canvas: a `ClipboardEvent` named
   `paste` whose `DataTransfer` holds `text/html` and `text/plain`. Loop turns paragraphs, lists, and
   HTML tables into its own blocks and tables.
3. Use each table's **Expand table** button for full width.
4. Convert the result column: open the column header menu, then **Change column type** > **Label** >
   **Progress**, and confirm **Yes, proceed**. Keyboard navigation (focus the item, then Right, Down,
   and Enter) opens these submenus more reliably than hovering.
5. Reload, scroll the whole page because tables render lazily, collect every row
   (`tr[data-testid=tableRowTestId]` with `td[role=cell]`), and compare it with the intended rows.

## Edit the page

- Text cell: click just after its last character, confirm that the focus is in the cell editor,
  delete the old value with Backspace, type the new one, and press Escape.
- Label cell: click the cell and choose the option whose label starts with the value, such as
  `[data-testid=label-list-row-test-id][aria-label^="Completed"]`.
- New row: use **Add new row** below the table, then fill each cell.
- Block order: hover the block, then open **Block Context Menu** > **Move block** > **Up** or **Down**.
- Column removal: open the column header menu and choose **Delete**.
- Link: select the link text with the keyboard (Shift+Arrow), press Ctrl+K, edit **Address**, and
  choose **Insert**. Clicking a link opens a new tab; close stray tabs.
- Paragraph text: click after its last character, then type, or press Enter for a new paragraph.

## Move between workspaces

**Copy to workspace** can fail between workspaces hosted in different SharePoint environments or
tenants. Rebuild the page in the target instead: paste the content again, reapply labels and widths,
re-enter later edits, and verify after a reload. Delete the original only with approval; it goes to
that workspace's recycle bin and can be restored.

## Without browser automation

Produce paste-ready HTML and Markdown tables with a short checklist for the user, and do not report
the tracker as created.
