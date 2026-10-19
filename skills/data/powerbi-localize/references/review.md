# Review a localization change

Contents: [Gather](#gather) · [Run the checker](#run-the-checker) · [Checks](#checks) · [Severity](#severity) ·
[Report files](#report-files) · [What a person checks](#what-a-person-checks) · [Summarize](#summarize) ·
[Blank titles everywhere](#blank-titles-everywhere)

`review` checks a change before it merges or ships. It reads files and writes nothing.

## Gather

- The change: the working tree against its base branch, a branch, or a pull request. Read the diff to see which
  resource files, culture files, model tables, and visuals it touches.
- The base version: copy the model and resource folders as they were before the change into a scratch folder outside
  the repository, with read-only Git commands such as `git archive <base> <folder> | tar -x -C <scratch>` or
  `git show <base>:<file>`. Don't check out, stash, reset, or otherwise change the user's working tree. Delete the
  scratch folder when done.

## Run the checker

```text
python scripts/check_translations.py --model <X.SemanticModel> --resx <resource folder> --allow-pending
    --baseline-model <base model folder> --baseline-resx <base resource folder>
    [--names-are-keys] [--text-table <table>] [--json]
```

- `--allow-pending` because a change may add keys to the base culture before they are translated; the checker lists
  them as pending instead of missing.
- `--names-are-keys` when resource keys are object names, so captions are compared with the resource files.
- `--text-table` when a relationship selects the viewer's row of a wide translation table.

## Checks

| Check | Severity | Finds | Usual fix |
| --- | --- | --- | --- |
| `model-unreadable` | error | No `model.tmdl` under `--model`, or a file can't be read | Point `--model` at the `*.SemanticModel` folder |
| `culture-unreadable` | error | A culture file without a `cultureInfo` declaration | Restore the declaration or the file |
| `culture-ref` | error | A `ref cultureInfo` line without its culture file: that language has no captions | Restore the file, or remove the line if the language was dropped on purpose |
| `culture-ref` | info | Culture files without `ref cultureInfo` lines; they still load | None; Desktop adds the lines |
| `culture-name` | warning | A file named for one culture that declares another | Rename the file or fix the declaration |
| `culture-duplicate` | error | A culture declared in two files, or an object captioned twice in one file | Remove the duplicate |
| `culture-unknown-object` | error | A translation for an object the model doesn't have, usually after a rename | Update the key or mapping and regenerate |
| `culture-base-captions` | info | Base-culture captions that differ from object names | Keep only if intended; Desktop shows the names |
| `culture-linguistic` | warning | Linguistic metadata before translations, an order Desktop has refused | Put translations first or drop the linguistic metadata |
| `culture-linguistic` | info | Linguistic metadata after translations, as in Microsoft's example | None |
| `culture-indentation` | warning | A culture file indented with spaces | Indent with tabs |
| `resx-unreadable` | error | A resource file that isn't well-formed XML, or a folder with none | Fix the file or the path |
| `resx-base-missing` | error | A set without a file for the base culture or a neutral file | Pass `--base`, or restore the file |
| `resx-missing` | error | A key the base culture has but a culture lacks | Wait for the translation round; don't copy base text in |
| `resx-pending` | info | Keys only the base culture has, with `--allow-pending` | Check that this change added each one |
| `resx-empty` | error | An empty value in a culture: viewers would see a blank | Translate it, or remove the key everywhere |
| `resx-empty` | warning | An empty value in the base culture | Give it text or remove it |
| `resx-duplicate` | error | A key defined twice in one file | Keep one |
| `resx-extra` | warning | A key a culture has but the base culture doesn't | Remove it, or restore it in the base culture |
| `resx-untranslated` | warning | Text equal to the base text in every other language | Send it for translation, or confirm it stays the same, as a name might |
| `caption-missing` | warning | With `--names-are-keys`: a translated name with no caption, or no culture file at all | Regenerate the culture files |
| `caption-stale` | warning | With `--names-are-keys`: a caption that differs from the resource file | Regenerate the culture files |
| `text-table` | error | The named table is missing, or no active relationship touches it | Add the relationship back |
| `baseline-culture-lost` | error | A culture file the previous version had | Restore it |
| `baseline-caption-lost` | error | A caption the previous version had, for an object that still exists | Regenerate, or restore the caption |
| `baseline-text-lost` | error | A column or measure of the translation table that the previous version had | Restore it; bound visuals go blank without it |
| `baseline-resx-lost` | error | A resource file the previous version had | Restore it |
| `baseline-key-removed` | warning | A key removed from the base culture | Make sure no binding or caption still uses it |

The checker also prints coverage: per culture, translated against translatable captions by object kind, and per
resource set, translated keys and how many equal the base text. Hidden objects, and everything in a hidden table,
don't count as translatable.

## Severity

- **Error**: the check caught the problem it looks for; don't merge until it's fixed. Missing or unreadable input is
  an error too, since a check that couldn't read its input proves nothing.
- **Warning**: needs a person's look; doesn't block on its own.
- **Info**: context only. Anything harmless is reported here and never higher.

## Report files

The checker reads the model and the resource files, not the visuals. For the visuals, run `powerbi-test`'s
literal-text and binding checks when installed. Otherwise check the changed `visual.json` files by hand:

- No `Literal` under a title, subtitle, alt text, button text, or slicer header that viewers see.
- Every `Measure`, `Column`, or `Aggregation` that points into the translation table names a field the table has.
  A binding to a field that doesn't exist leaves the text empty, with no error anywhere.
- No `displayName` rename on a field whose caption should show.

## What a person checks

1. New keys: present in the base culture only and added by this change (the checker lists them as pending), with a
   comment for translators and final wording.
2. Translations: each reads sensibly in its language, none is empty, and they aren't simply the base text in every
   language. A translation round can leave some text untranslated; send it back rather than filling it in by hand.
3. Reach: a key does nothing on its own. Viewers see it only after the translation table is rebuilt, the model is
   refreshed when the table imports its data, and a visual is bound to it. Check that the change has every step it
   needs.
4. Removals and renames: no binding or caption still uses a removed key or a renamed object.
5. Shipped files: if you ship a Power BI Desktop file (PBIX) built from the project, check that file too; it can
   differ from the project files. `powerbi-test` compares the two.
6. Rendering: after the owner publishes, open the report with `?language=` in one right-to-left language, one East
   Asian language, and one that runs long, such as German or Finnish. Does every title still fit?
7. Coverage: every culture your viewers use has its own culture file.

## Summarize

Lead with the verdict: blocking or not. List errors, then warnings, each with its file and fix; then what the person
still has to check and anything you couldn't check, such as visuals without `powerbi-test` or a PBIX you couldn't
open. Quote the checker's output rather than retyping it.

## Blank titles everywhere

When titles go blank across reports after a model change, a translation table lost a column or measure, or the
relationship that selects the viewer's row was dropped. Start with the checker, `--text-table` and the previous
version as baseline; it usually names the lost field or relationship.
