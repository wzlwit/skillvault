# Model captions

Contents: [What a culture file holds](#what-a-culture-file-holds) ·
[Base culture and culture list](#base-culture-and-culture-list) ·
[Generate culture files from resource files](#generate-culture-files-from-resource-files) ·
[Linguistic metadata](#linguistic-metadata) · [Renames and Desktop saves](#renames-and-desktop-saves) ·
[Verify](#verify)

Model captions are the translated names of tables, columns, measures, hierarchies, and hierarchy levels. Power BI
shows them wherever the name appears: the field list, table and matrix headers, axis and legend labels, card labels,
and the titles Power BI builds from field names. Microsoft's
[translation planning guide](https://learn.microsoft.com/en-us/power-bi/guidance/multiple-language-translation)
calls this metadata translation.

## What a culture file holds

A semantic model saved as a Power BI project (PBIP) keeps one file per culture in `definition/cultures/`, named after
the culture, such as `de-DE.tmdl`. Its `translations` block repeats the model's tree and gives each translated
object a `caption`, and optionally a `description` and a `displayFolder`. Microsoft's
[TMDL object reference](https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-reference-tabular-object#translations-in-tmdl)
shows the syntax, and the [TMDL overview](https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview)
gives the general rules for names, values, and indentation.

A small file, indented with tabs:

```tmdl
cultureInfo de-DE

	translations

		model Model

			table Orders
				caption: Bestellungen

				column 'Ship Date'
					caption: Versanddatum

				measure 'Order Count'
					caption: Anzahl der Bestellungen
```

When you write these files by hand or with a generator:

- Indent one tab per level, as Desktop does. TMDL's indentation is strict, and a line at the wrong level is a parse
  error.
- Put a name in single quotes when it contains a space, dot, equals sign, colon, or single quote, and double each
  single quote inside it: `'Owner''s Total'`.
- Keep a caption on one line. Put it in double quotes when it starts or ends with a space, and double each double
  quote inside them.
- Spell each object's name as the model does, under the table that holds it; a level goes under its hierarchy.
- Desktop writes the declaration as `cultureInfo`; Microsoft's reference example writes `culture`. TMDL reads
  keywords without regard to case, and the checker accepts both.

## Base culture and culture list

- The `culture` property in `model.tmdl` is the base culture. Its object names act as its captions, so it needs no
  translations. Desktop often keeps a base culture file that holds only linguistic metadata.
- Captions in the base culture that differ from the object names make Desktop, which shows names, and the service,
  which shows captions, look different. Microsoft's
  [locale guide](https://learn.microsoft.com/en-us/power-bi/guidance/multiple-language-locale) advises using them
  sparingly; the checker lists them as info.
- `model.tmdl` orders the cultures with `ref cultureInfo <culture>` lines. On load, a `ref` line without a file is
  ignored, and a file without a `ref` line is added at the end. A `ref` line without its file usually means the file
  was lost, so the checker reports an error. A new file without a line is fine: Desktop writes the line on its next
  save.
- Viewers get captions only for a culture the model has. For tables and columns the service needs an exact match
  between the viewer's culture and a culture file; measures fall back to the closest one. Add a file for every
  culture your viewers use, such as `fr-FR` and `fr-CA`, even when the text is the same.

## Generate culture files from resource files

Resource files (`.resx`) hold one entry per key: a `data` element with a `name`, a `value`, and an optional
`comment` for translators. Files are named `<set>.resx` for the neutral file and `<set>.<culture>.resx` for each
culture ([.NET resource files](https://learn.microsoft.com/en-us/dotnet/core/extensions/create-resource-files)).
To generate culture files:

1. List the model's tables, columns, measures, hierarchies, and levels with their `isHidden` flags; a hidden table
   hides everything in it. Leave hidden objects out, since viewers never see them.
2. Read the base file and each culture's file with an XML parser. It decodes entities such as `&amp;`, which a text
   search would not, and so would miss a measure named `Profit & Loss`. Skip entries with a `type` attribute; they
   aren't text.
3. Map keys to objects. The simplest convention makes the key the object's name. When one name exists in several
   tables, such as a `Date` column in two tables, either let one key serve all of them or put the table in the key
   (`Orders.Date`), and write the convention into the generator. Report keys that match nothing and names that match
   more than one object; don't guess.
4. For each culture, write a caption for every visible object whose key has text in that culture. Leave out objects
   without a translation: the service then shows the object's name. Text equal to the base text can go in; the
   checker counts it, so a reviewer can spot a language that came back untranslated.
5. Merge into existing files instead of overwriting them when they hold anything the resource files don't, such as
   descriptions, display folders, or linguistic metadata.
6. Write UTF-8 in a fixed order, the model's or sorted, so that a regenerated file only differs where text changed.
7. Leave the base culture's file alone unless you mean its captions to differ from the names.
8. Run the checker. With `--names-are-keys` it compares every caption with the resource files and lists captions that
   are missing or stale.

## Linguistic metadata

A culture file can also hold `linguisticMetadata`, the JSON language data that Q&A uses for that culture.
Microsoft's TMDL reference example keeps `translations` and `linguisticMetadata` in one file, translations first. A
generator that added a translations block after existing linguistic metadata produced a file that Desktop refused to
open with an `UnknownKeyword` error. So:

- Put `translations` before `linguisticMetadata` in any file you generate, or leave the linguistic metadata out of
  generated files; Q&A then lacks that culture's language data until Desktop writes it again.
- Desktop can add linguistic metadata back when it saves. Run the checker after each save; it warns when linguistic
  metadata comes before translations.

## Renames and Desktop saves

- A translation names its object. Renaming a table, column, or measure leaves its translations pointing at nothing,
  and the captions are lost. Update the key or the mapping, regenerate, and confirm the checker reports no
  `culture-unknown-object`.
- Desktop can rewrite a culture file in a different order when it saves. A large diff that removes as many caption
  lines as it adds is a reorder; compare the checker's coverage before and after rather than reading the diff.
- Each semantic model has its own culture files. When several models share tables, regenerate and check each one.

## Verify

1. The checker shows no errors and the coverage you expect.
2. Open the project in Power BI Desktop. It parses the culture files and reports an error if one fails to parse, but
   it shows object names, not captions.
3. In Tabular Editor, the
   [Metadata Translation Editor](https://docs.tabulareditor.com/en/features/metadata-translation-editor.html) shows
   each culture's captions side by side; an empty cell is a missing translation.
4. After the owner publishes the model, open the report in the service with `?language=<culture>` added to its URL.
   The parameter doesn't work in the Power BI mobile apps, which follow the device's language.
