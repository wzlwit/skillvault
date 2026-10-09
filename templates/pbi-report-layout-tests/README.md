# pbi-report-layout-tests

Automated layout and visual tests for Power BI reports, built on pbir-utils (the PBIR rule engine and wireframe) and
PBIXRay (the model inside a PBIX). `SKILL.md` is the skill. `scripts/verify_report.py` runs the checks,
`rules/pbir-rules.yaml` is the rule pack, and `references/rules.md` explains how to write rules.

Status: a draft in `templates/`, not in `catalog.json`, so it cannot be installed yet. It names no internal
repositories, people or ids.

Dependencies: `pip install "pbir-utils>=2.5" "pbixray>=0.15"`, Python 3.10 or later. Tested with pbir-utils 2.5.2
and PBIXRay 0.15.5.

Tests: run `python -m unittest discover -s tests` from this folder. Breaking the group offsets, the geometry check or
the rule run makes them fail. The script was also run on shipped reports:

- the reviewed report as a PBIR folder, a PBIP and its shipped PBIX: no findings, and 200 fields resolved with
  PBIXRay;
- the shipped PBIX against the PBIR it was saved from: 234 of 234 files equal; against a later PBIR: 69 differences;
- the shipped model PBIX against its TMDL: 132 measures equal; against a later TMDL: 46 extra measures and 38
  changed;
- three other team reports: real findings (pages not Fit to width, Auto display units, literal titles, overlapping
  slicers), and bindings that fail only against a stale DirectQuery cache, as expected.
