# pbi-report-visual-conventions

Conventions for Power BI report visuals: page defaults, numbers and display units, blanks, titles and captions, and
chart details. It comes with a static checker, `scripts/check_visual_conventions.py`, and a render-check procedure,
`references/render-check.md`. `SKILL.md` is the skill itself.

Status: a draft in `templates/`, not in `catalog.json`, so it cannot be installed yet. It was written from a dashboard
review and render checks of a new report in October 2026. The text names no internal repositories, people or ids,
but review it before you publish it: the repository is public.

Tests: run `python -m unittest discover -s tests` from this folder (Python 3, standard library only). The checker was
also run on:

- the reviewed report: no findings;
- its earlier build, which had 84 measures that replaced blanks: 84 findings;
- four other team reports: no errors. Their findings are real deviations from these conventions, or text-fit
  findings to confirm with a render.
