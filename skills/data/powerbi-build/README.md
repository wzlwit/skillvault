# Power BI Build

Tricks for building and changing Power BI models and report layouts as code in a Power BI project (PBIP): Tabular
Model Definition Language (TMDL) model files, enhanced report format (PBIR) layout JSON, the Power BI Desktop round
trip, conversion to and from a Power BI Desktop file (PBIX), and the pitfalls that break these files. It is generic:
a project's own style, such as canvas size, colors, and number formats, stays the project's. Start with
[the skill instructions](SKILL.md).

Install: `/skillvault-install powerbi-build`

Requirements: Power BI Desktop on Windows to load, save, refresh, and convert projects, and a text editor; VS Code
checks PBIR files against their published schemas. There are no scripts or packages to install.

It changes only the files a request needs and never publishes, deploys, or refreshes in the Power BI service. Model
design belongs to `powerbi-modeling`, checking to `powerbi-test`, and translation to `powerbi-localize`.

`skill.json` `origins` lists the original skills this one was written from, which
`/skillvault-author powerbi-build check origins` compares for changes.
