
# Description Rules

Use these rules for `preview` and before every `upsert` that writes a description. Draft into a
local UTF-8 file, run the helper's `-Action Check` on it, and fix or explain each finding.

## Gather evidence first

1. Find the base branch: the open PR's base, the repository's documented PR target, or the remote
   default branch. Use the merge-base of `origin/<base>` and `HEAD` for every comparison.
2. Read every changed production hunk and the tests added or changed. The Current column comes
   from the merge-base code, not from memory or the old description.
3. Use results produced on the current head only. After a rebase or new commit, rerun the checks
   or leave them out.
4. For an existing PR, take the issue link and other links from its live description.

## Sections

Follow the repository's PR template: its headings, their order, and its instructions, such as
deleting options that don't apply. Remove its instruction text once a section is filled. Without a
template, use Description, Current vs. to-be, Type of change, Checklist, and Test Validation Proof.

The Current vs. to-be table is the description's only table, apart from tables the repository's
template asks for. Write everything else as bullets: code changes, limits, checks, and which tests
cover each row. Long cells in a path or command table wrap and are harder to read than a list.

- **Description:** the issue link, then one to three sentences: what the base branch does today and
  the fix chosen. Name a rejected alternative only when the issue proposed it. Then the code changes
  as bullets: one per file, folder, or method, saying what changed in one line, with the rows it
  implements when that helps. Group files that change together, and leave longer explanations to
  the design doc or issue. Add any limit or trade-off that changes what a reviewer or deployer does.
  End with one sentence for legacy or non-blocking issues left out, after checking that each is tracked.
- **Current vs. to-be:** the template's section, or a `### Current vs. to-be` heading under
  Description when the template has none. See the table rules below.
- **Checklist:** tick only what was done. Keep a short reason beside an unticked item that applies.
- **Test Validation Proof:** the head and base commits, then one bullet per check with its command
  and result from that head, then bullets naming the tests or checks behind each scenario row.
  Rows that share their evidence can share a bullet.

## Scenario table

| # | Scenario | Current (`develop`) | To-be (this PR) |
|---|---|---|---|
| 1 | Install a dependent package while its dependency runs 1.0.9.0 and 1.0.10.0 is the latest | The dependency stays on 1.0.9.0 | One upgrade to 1.0.10.0 is requested; the install doesn't wait for it |

- One row per scenario: the starting state and action, then each version's outcome.
- Reuse the same example values across rows, taken from the tests.
- Include unchanged neighbors (guards and the common case) and mark them "Same as current".
- Merge variants that share an outcome; keep the table to about ten rows.
- No behavior change, as in a docs-only or refactor PR: write "No behavior change" instead.

When end-to-end runs aren't possible, give evidence in this order: unit tests per row, checks over
repository data (for example, every package resolving the same way), then any staging or live run IDs.

## Prose

Apply the upstream Humanizer guidance in embedded mode: plain words, no em or en dashes, no bold
labels, no stock AI phrases, no restated closers. Keep template headings, code, commands, paths,
and link targets unchanged. Title: imperative mood, under 72 characters, saying what the PR does.

## Check findings

`-Action Check -BodyFile <file> [-PreviousBodyFile <file>]` reports:

| Code | Meaning |
| --- | --- |
| `MissingSection` | A template heading is missing |
| `TemplateText` | Template instruction text was left in |
| `ScenarioTable` | No scenario table with filled cells and no "No behavior change" |
| `TableColumns` | A table row has a different number of cells than its header |
| `ExtraTable` | A table outside Current vs. to-be that the repository template doesn't have; use bullets |
| `Dash` | An em or en dash outside code |
| `LinkRemoved` | A link target in the previous description is gone |
| `UnknownTest` | A test name in Test Validation Proof isn't found in the repository |
