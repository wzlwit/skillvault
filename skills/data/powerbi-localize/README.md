# Power BI Localization

`powerbi-localize` translates what a Power BI report shows and checks the translations before they ship:

- Model captions (the names of tables, columns, measures, hierarchies, and levels) in Tabular Model Definition
  Language (TMDL) culture files, often generated from .resx resource files.
- Report text, such as visual titles, buttons, slicer headers, and alt text, from a translation table in the model
  that each visual binds to.
- Reviews of a localization change: a checker script for resource-key parity, culture files, caption coverage, the
  translation table's relationship, and anything lost since the previous version, plus a checklist for a person.

Run `/powerbi-localize` alone to see translation coverage per culture, give it text to localize something, or use
`/powerbi-localize review` on a change.

Install: `/skillvault-install powerbi-localize`

Requirements: Python 3.10 or later for the checker, standard library only; Power BI Desktop or Tabular Editor to
verify the result.

`skill.json` `origins` lists the original skills this one was written from, which
`/skillvault-author powerbi-localize check origins` compares for changes.
