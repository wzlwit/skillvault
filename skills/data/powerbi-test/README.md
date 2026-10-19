# powerbi-test

Tests for Power BI reports saved in the enhanced report format (PBIR), run before check-in or release, and a
comparison of two Power BI projects. `SKILL.md` is the skill.

- `scripts/verify_report.py` runs the structural checks on a `.Report` folder, a Power BI project (PBIP, `.pbip`),
  or a Power BI Desktop file (PBIX, `.pbix`): generic rules, geometry, field bindings, text fit, and parity between a
  PBIX and its project.
- `scripts/check_style.py` checks a project's house style from its style file. `examples/report-style.example.yaml`
  shows every setting with illustrative values; nothing about style is checked by default.
- `rules/generic.yaml` is the generic pbir-utils rule pack. `references/` explains project checks, `compare`, and the
  rendered check.

Install: `/skillvault-install powerbi-test`

Requirements: Python 3.10 or later with `pbir-utils` 2.5 or later and `pyyaml`. `pbixray` is optional: it reads the
model inside a PBIX. The text-fit check needs Windows. The scripts only read reports. Tests: run
`python -m unittest discover -s tests` from this folder.

`skill.json` `origins` lists the original skills and command this skill was written from, which
`/skillvault-author powerbi-test check origins` compares for changes.
