
# Description Rules

Contents: Keep an existing description; Write a new description; Gather evidence first; Checklists
and test evidence; Scenario table; Prose; Check findings.

Use these rules before every publish, including a run that stops at "show me first". Write into
local UTF-8 files, preview them with the helper's `Publish` command, and fix or explain each check
finding.

## Keep an existing description

An open PR's description stays as written, whoever wrote it: you, GitHub's Copilot summary, or an
earlier run. Write only the table, or "No behavior change.", into a file; publishing adds it, or
replaces the Current vs. to-be section, and changes nothing else. A new `### Current vs. to-be`
section closes the first `##` section, or follows the text when the description has no sections.
Change other text only when the user asks, such as "rewrite the description", and say what
changed. Keep link targets, issue references, and code.

## Write a new description

1. Load the `create-pull-request` skill from the VS Code GitHub Pull Requests extension when it is
   available, and write the title and description under its Prepare PR Details and its title and
   description best practices; its draft advice doesn't apply. Without it, apply the same points: a
   title in the imperative mood under 72 characters, and a description that opens with a
   one-sentence summary, says why the change is needed, references the issue (`Fixes #<number>`),
   notes implementation decisions a reviewer needs, and lists the main files or components only for
   a large change.
2. A repository PR template decides the sections: follow its headings, their order, and its
   instructions, such as deleting options that don't apply, remove its instruction text once a
   section is filled, and keep each section short. The table goes in the template's Current vs.
   to-be section when it has one, otherwise at the end of the first section.
3. Write the description and the table into separate files; the helper puts the table in.

Add no per-file list, type of change, checklist, or test evidence section unless the template asks
for one, and keep the description short. To use GitHub's Copilot summary instead, create the PR on
GitHub with Copilot's **Summary** in the description field; `/pr-publish` then adds only the table.

## Gather evidence first

1. Find the base branch: the open PR's base, the repository's documented PR target, or the remote
   default branch. Use the merge-base of `origin/<base>` and `HEAD` for every comparison.
2. Read every changed production hunk and the tests added or changed. The Current column comes
   from the merge-base code, not from memory or the old description.
3. Use results produced on the current head only. After a rebase or new commit, rerun the checks
   or leave them out.

## Checklists and test evidence

Only when a template asks for them:

- **Checklist:** tick only what was done. Keep a short reason beside an unticked item that applies.
- **Test evidence:** one bullet per check with its command and result from the current head; name
  the tests behind each table row only when the template asks. When end-to-end runs aren't
  possible, give evidence in this order: unit tests per row, checks over repository data (for
  example, every package resolving the same way), then any staging or live run IDs.

## Scenario table

| # | Scenario | Current (`develop`) | To-be (this PR) |
|---|---|---|---|
| 1 | Install a dependent package while its dependency runs 1.0.9.0 and 1.0.10.0 is the latest | The dependency stays on 1.0.9.0 | One upgrade to 1.0.10.0 is requested; the install doesn't wait for it |

- One row per scenario: the starting state and action, then each version's outcome.
- Reuse the same example values across rows, taken from the tests.
- Include unchanged neighbors (guards and the common case) and mark them "Same as current".
- Merge variants that share an outcome; keep the table to about ten rows.
- No behavior change, as in a docs-only or refactor PR: write "No behavior change" instead.

The Current vs. to-be table is the description's only table, apart from tables the repository's
template asks for. Write everything else as bullets; long cells in a path or command table wrap and
are harder to read than a list.

## Prose

Apply the upstream Humanizer guidance in embedded mode to the text pr-publish writes: plain words, no
em or en dashes, no bold labels, no stock AI phrases, no restated closers. Text kept from an existing
description, such as a Copilot summary, stays as written. Keep template headings, code, commands,
paths, and link targets unchanged. Title: imperative mood, under 72 characters, saying what the PR
does.

## Check findings

The `Publish` preview and `-Action Check` report these. With an open PR, the live description is
the previous one, so `MissingSection`, `TemplateText`, `ExtraTable`, `TableColumns`, and `Dash`
cover only lines that are new or changed.

| Code | Meaning |
| --- | --- |
| `MissingSection` | A template heading is missing |
| `TemplateText` | Template instruction text was left in |
| `ScenarioTable` | No scenario table with filled cells and no "No behavior change" |
| `TableColumns` | A table row has a different number of cells than its header |
| `ExtraTable` | A table outside Current vs. to-be that the repository template doesn't have; use bullets |
| `Dash` | An em or en dash outside code |
| `LinkRemoved` | A link target in the previous description is gone |
| `UnknownTest` | A test name in a Validation or Test Validation Proof section isn't found in the repository |
