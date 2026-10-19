# Report text

Contents: [Where report text lives](#where-report-text-lives) · [Binding forms](#binding-forms) ·
[Translation table designs](#translation-table-designs) ·
[How the viewer's language picks the text](#how-the-viewers-language-picks-the-text) · [Keys](#keys) ·
[Bind text](#bind-text) · [Replace literal text in bulk](#replace-literal-text-in-bulk) ·
[From resource files to the table](#from-resource-files-to-the-table)

Power BI translates the semantic model, not the report layout: text typed into a title, a text box, or a button
stays as typed, and page tab names can't be translated
([Microsoft's translation planning guide](https://learn.microsoft.com/en-us/power-bi/guidance/multiple-language-translation)).
To translate such text, give each piece a key, keep its translations in the model, and bind the visual to a measure
or column that returns the viewer's text. A title Power BI builds from field names needs none of this: it follows the
captions ([localized labels guide](https://learn.microsoft.com/en-us/power-bi/guidance/translation-builder-localize-label)).

## Where report text lives

A report in the enhanced report format (PBIR) keeps each visual in
`definition/pages/<page>/visuals/<visual>/visual.json`. The [public schemas](https://github.com/microsoft/json-schemas/tree/main/fabric/item/report)
define where its text sits:

- Title and subtitle: `visual.visualContainerObjects.title[0].properties.text` and the same under `subTitle`.
- Alt text: `visual.visualContainerObjects.general[0].properties.altText`.
- Button and shape text and slicer headers sit under the visual's own `visual.objects`, whose property names the
  public schema leaves open. Bind one by hand in Desktop, save, and copy the shape Desktop wrote.
- A field renamed for one visual stores the new name in its projection's `displayName`. That's layout text, so
  captions don't reach it: remove the rename, or bind the title instead.
- A text box's paragraphs are literal text. For a fixed note, use a visual whose title or text can be bound.
- Pages: hide the tabs and navigate with buttons whose text is bound.

## Binding forms

A text property holds an expression under `expr`. The semantic query schema in the same repository defines three
forms that matter here:

- `Literal`: fixed text. A string value sits in single quotes, with any single quote inside doubled.
- `Measure`: a table (`SourceRef` with `Entity`) and the measure's name (`Property`).
- `Aggregation`: a `Column` reference and a `Function` number. Function 3 is Min, which over the one row left for the
  viewer's culture returns that row's text.

A title bound to a measure, for example:

```json
"title": [
  {
    "properties": {
      "show": { "expr": { "Literal": { "Value": "true" } } },
      "text": {
        "expr": {
          "Measure": {
            "Expression": { "SourceRef": { "Entity": "Report Text" } },
            "Property": "Sales by Region Title"
          }
        }
      }
    }
  }
]
```

## Translation table designs

| Design | Shape | A visual binds to | Watch for |
| --- | --- | --- | --- |
| Long table | One row per key and culture: key, culture, text | One measure per key that picks the viewer's row | One measure per text; the table's columns never change |
| Wide table | One row per culture, one column per key | The key's column, aggregated with Min | Each new key changes the table's columns; keep its relationship |
| Measures only | A `SWITCH` on `USERCULTURE()` inside each measure | The measure | Translations live in DAX, out of reach of resource files |

The third design is the pattern Microsoft's Translations Builder generates; see the localized labels guide above.

## How the viewer's language picks the text

**A measure with `USERCULTURE()`.** In the service the function returns the culture from the viewer's Power BI
language setting, which defaults to the browser's language
([USERCULTURE](https://learn.microsoft.com/en-us/dax/userculture-function-dax)). Put these measures in the model:
the function may return the wrong culture in a report-level measure of a live-connected report, and in an import
model a calculated column or table evaluates it once, at refresh. Fall back from the viewer's exact culture to
another culture of the same language, then to the base culture, so the measure never returns a blank:

```dax
Sales by Region Title =
VAR viewer = USERCULTURE ()
VAR lang = LEFT ( viewer, SEARCH ( "-", viewer & "-" ) - 1 )
VAR keyRows = FILTER ( ALL ( 'Report Text' ), 'Report Text'[Key] = "SalesByRegionTitle" )
VAR exact = MAXX ( FILTER ( keyRows, 'Report Text'[Culture] = viewer ), 'Report Text'[Text] )
VAR sameLanguage =
    MAXX ( FILTER ( keyRows, LEFT ( 'Report Text'[Culture], LEN ( lang ) + 1 ) = lang & "-" ), 'Report Text'[Text] )
VAR base = MAXX ( FILTER ( keyRows, 'Report Text'[Culture] = "en-US" ), 'Report Text'[Text] )
RETURN IF ( LEN ( exact ) > 0, exact, IF ( LEN ( sameLanguage ) > 0, sameLanguage, base ) )
```

Replace `en-US` with your base culture. Generate one such measure per key rather than writing them by hand.

**A relationship from a language table.** A language table with one row per culture filters the wide table through
a relationship, and something outside both tables filters the language table to the viewer's culture: for example a
filter that an embedding application applies when it loads the report. A title then binds straight to the key's
column with Min. Two things go wrong without an error:

- If nothing filters the language table, every culture's row stays in play and Min returns the alphabetically first
  text, in whatever language that is. The filter must also flow from the language table into the wide table.
- Desktop has dropped this relationship when the wide table's columns changed, such as after a new key column. Check
  it after every change; the checker's `--text-table` does.

## Keys

- A key is what visuals bind to: a column name in a wide table, a measure name, or a lookup value in a long table.
  Make keys unique, readable, and stable.
- Decide what happens when the base text is reworded:
  - If keys are derived from the wording, new wording means a new key, which starts with no translations, while the
    old key stays until no binding uses it. Put the new key in the base culture alone; reviews show it as pending
    until translations arrive.
  - If keys are stable, bindings stay, but every culture still holds a translation of the old wording. Your
    translation pipeline has to notice the changed text; check that it does.
  - Either way, a final wording before strings are sent out saves a round.
- Use each key's resource `comment` for translators: where the text shows, any length limit, and what an ambiguous
  word means, such as whether "Order" is a purchase or a sort order.
- If a tool picks entries by their comment, for example only titles and button labels, match the category as a
  prefix or a separate field, not the whole comment. A translator note appended to the comment otherwise drops the
  entry without a word. After each translation round, compare the keys the tool picked with the keys tagged in the
  base file.
- Keep each key in the table where it was first published. A binding records both the table and the column, so
  moving a key elsewhere empties every visual bound to it. When a wide table has to be split, treat the existing
  tables' column lists as fixed: a retired text leaves its column unused instead of moving the others, and new keys
  go into the newest table, which needs its own relationship.
- Remove a key only after removing every binding to it. The checker's baseline comparison lists removed keys.

## Bind text

- In Desktop, select the visual, find the title text in the Format pane, select the fx button beside it, and pick the
  measure or column. The same works for a subtitle, a shape's or button's text, and other text properties. Bind alt
  text too; screen readers read it.
- In PBIR, replace the `Literal` under `text.expr` with a `Measure` or `Aggregation` expression as above. Change
  nothing else in the file: keep its indentation, line endings, encoding, and `$schema` version.
- Override a slicer header only when the column caption doesn't suit; by default the header shows the caption, which
  culture files already translate.

## Replace literal text in bulk

1. Map each base text to its key from the base resource file, limited to keys the table or measures actually have.
2. Visit only text slots: title and subtitle text, alt text, button and shape text, slicer header text. Every other
   literal stays as it is, from colors and font settings to on/off flags and number formats.
3. Replace a literal only when its whole text equals a base text exactly. List near misses that differ only in case,
   spacing, or punctuation for a person to decide; a looser match can catch unrelated text.
4. When two keys share a base text, ask which one the visual means.
5. Show the planned replacements (file, slot, text, key) and the near misses, then write only those expressions.
6. Check that every binding points at a column or measure the model has, with `powerbi-test` if installed: a binding
   to a field that doesn't exist leaves the title empty, with no error anywhere. Open the report in Desktop
   afterward.

## From resource files to the table

- Keep the text in UTF-8 from the resource files to the table. Some exports default to a legacy code page and turn
  non-Latin text into question marks. After an import, look at one right-to-left culture and one East Asian culture.
- A culture without a translation for a key gets the base text, or the key stays out of the table until it's
  translated. Never leave an empty cell: a title bound to it shows a blank.
- Keys only in the base culture are pending. Either ship them with the base text in every culture, or hold the key
  and its bindings back until the translation round returns.
- Desktop stores the rows of an Enter data table, compressed, inside the table's M expression. Regenerate such a
  table in Desktop or with your generator, not by editing the expression.
- When several models carry the same table, such as a shared model and its copies, update and check each one.
- A field parameter shows names stored as rows of its own table. They're data, not captions, so culture files don't
  translate them; treat them as data translation.
