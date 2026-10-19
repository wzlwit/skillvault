---
name: powerbi-localize
description: "[review] Alone: translation coverage. Text: localize that. Translate Power BI semantic model captions through Tabular Model Definition Language (TMDL) culture files, often generated from .resx resource files, and report text such as visual titles, buttons, slicer headers, and alt text through a translation table bound to visuals. Use to add a language, translate captions, generate culture files, localize titles and buttons, or review a localization change or pull request. Overlaps with powerbi-build on TMDL and enhanced report format (PBIR) edits; powerbi-test on literal-text and binding checks; Microsoft's semantic-model-authoring on the culture file format."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[review] [<model, report, or change>]"
---

# Power BI Localization

`/powerbi-localize` translates what a Power BI report shows. Model captions (the names of tables, columns, measures,
hierarchies, and levels) live in Tabular Model Definition Language (TMDL) culture files in a Power BI project (PBIP).
Text written into the report, such as a visual title or a button label, comes from a translation table in the model
that the visual binds to. The skill also checks both before a change ships.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | Show translation coverage per culture, with the gaps, then offer the next step |
| Text | Localize what the text names: a language, culture files, report text, or literal titles |
| `review [<change>]` | Check a change before merge or release and summarize the findings by severity |

- **Alone** finds the model's `definition/cultures/` folder, its resource files (`*.resx`), and any translation table,
  then runs the [checker](#checker) and shows, per culture, translated against translatable captions, missing
  resource keys, and whether the translation table's relationship is in place. With several models, it shows each.
  It offers the most useful next step, such as regenerating stale culture files, asking once; no answer changes
  nothing. It ends with one line: name a language to add, resource files to generate from, a title or page to
  localize, or say review.
- **Text** localizes what it names: add a culture, regenerate culture files after a translation round, add keys for
  new report text, or switch literal titles to bound text. Extend the mechanism the project already uses. Text that
  only names a model or report shows its coverage and asks once what to localize.
- **`review`** checks a change (the working tree, a branch, or a pull request) against its base: the checker with
  the previous version as baseline, then the checklist a person must judge. It summarizes findings by severity, with
  file and fix, and writes nothing.

## Which mechanism

| What the viewer sees | Mechanism | Where it lives |
| --- | --- | --- |
| Names of tables, columns, measures, hierarchies, and levels: field list, headers, axis and legend labels, default visual titles, slicer headers that show a column name | Model captions | `definition/cultures/<culture>.tmdl` |
| Text typed into the report: visual titles and subtitles, button and shape text, overridden slicer headers, alt text, headings | Report text: a translation table, bound through a measure or a column | The table in the model; bindings in each `visual.json` |
| Values in the data, such as product names | Data translation | The data source; outside this skill |
| Page tab names | None: they can't be translated, so hide the tabs and navigate with bound buttons | |

## Rules

- Look first: find the culture files, resource files, translation table, and bindings, and run the checker before
  and after every change.
- When the project has resource files, they hold the translations. Regenerate culture files and the translation table
  from them instead of editing generated output by hand, and read them with an XML parser.
- The model's `culture` property is the base culture; its object names serve as its captions. New keys go into the
  base culture only and wait for your translation pipeline. Never paste base text into other cultures to close a gap.
- Leave no literal text in the report layout: Power BI can't translate it, and that includes a field renamed for one
  visual. A default title built from field names is already translated through captions.
- Give every culture your viewers use its own culture file. For tables and columns the service needs an exact match,
  so `fr-CA` doesn't fall back to `fr-FR`; measures fall back to the closest culture.
- A viewer never sees a blank: a missing translation falls back to the base text, never to an empty value.
- Desktop shows object names, not translations. Check captions in Tabular Editor, and test a culture in the service
  by adding `?language=<culture>` to the report URL.
- Change only the files the request needs. Never publish, deploy, refresh in the service, change permissions, or
  delete items as a side effect.

## References

- Before generating or editing culture files, read [model captions](./references/model-captions.md).
- Before adding report-text keys, designing a translation table, or binding titles, read
  [report text](./references/report-text.md).
- Before `review`, read [review](./references/review.md); it lists every check and its severity.

## Checker

```text
python scripts/check_translations.py --model <X.SemanticModel> --resx <resource folder> [--base <culture>]
    [--allow-pending] [--names-are-keys] [--text-table <table>]
    [--baseline-model <folder>] [--baseline-resx <folder>] [--details] [--json]
```

- Python 3.10 or later, standard library only. It reads files and writes nothing; give `--model`, `--resx`, or both.
- `--allow-pending` reports keys that only the base culture has as pending, for a change that adds them before the
  translation round. `--names-are-keys` compares captions with the resource files when keys are object names.
  `--text-table` requires a relationship to the translation table. The baseline options compare with the previous
  version to catch lost cultures, captions, keys, and text fields.
- Exit code 1 when a finding is an error. `--json` prints the whole result for a pipeline; `--details` lists every
  missing caption.
- Tests: `python -m unittest discover -s tests` from this folder.

## Related skills

- `powerbi-build`: editing TMDL and enhanced report format (PBIR) files, and the Desktop round trip.
- `powerbi-test`: literal-text and binding checks on report files, and Power BI Desktop file (PBIX) parity.
- `powerbi-modeling`: model design, relationships, and DAX.
- Microsoft's
  [semantic-model-authoring](https://github.com/microsoft/skills-for-fabric/tree/main/plugins/powerbi-authoring/skills/semantic-model-authoring)
  skill authors whole models, culture files included, with its own tooling.
