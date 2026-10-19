# Power BI Report Visual Conventions Evaluation

- Evaluated: 2026-10-16
- Source: https://github.com/wzlwit/skillvault/tree/ebfb40533f2552637d59b80e89e0d498eceb8266/templates/pbi-report-visual-conventions,
  a native SkillVault draft that was never in the catalog; retired on 2026-10-19
- Reviewed revision: `ebfb405` (version `1.0.0`), plus uncommitted local edits that were in progress
  during the review and raise it to `1.1.0`
- Author: wzlwit; no license declared, like other native SkillVault skills
- Scope: SKILL.md, README, manifest, render-check reference, script, and tests, read as source.
  Nothing was installed or run.

## Recommendation

Purpose: Conventions for building and reviewing Power BI visuals (page settings, number formats and
display units, blank values, titles and captions, chart styling, and date slicers), with a static
checker for report folders in the enhanced report format (PBIR) and a procedure for rendering every
page on test data. Value: High for the team whose reports it describes; medium elsewhere, because
most of it is that team's style. Fit: A project skill, plus checker mechanics that could be generic.

Skill recommendation: Defer. Keep the team's conventions in the team's repository, and publish only
a policy-neutral version if another team needs it. Installed recommendation: Not installed anywhere.

## What It Checks

`scripts/check_visual_conventions.py` reads a PBIR report folder and, when given, its model and an
English resource file. It checks page settings, date slicers, display units, blank handling in
measures, format strings, number-first captions, and whether titles and legends fit. The fit check
measures text with Windows GDI and is skipped elsewhere. The script uses only the Python standard
library and exits 1 on findings. The render reference needs a Power BI test workspace, tokens,
browser automation, and network access.

## Overlap and Earlier Evaluations

- [pbi-report-layout-tests](pbi-report-layout-tests.md), evaluated the same day, also checks page
  settings, the Filters pane, background, and display units. Give each check one owner.
- `kpi-dashboard` already treats zero, missing, and empty data as distinct states, which covers the
  general lesson behind keeping a blank value blank.
- The harness-write report workflow already requires checking the rendered result, not only the
  files, which covers the general lesson behind the render procedure.
- The [powerbi-modeling evaluation](powerbi-modeling.md) (2026-09-24) covers model design only; this
  draft does not change it.

## Risks

- Most rules are one team's style, presented as general rules.
- The published draft names two skills that aren't public and contains an internal-looking test
  literal. The in-progress edits add an internal report's name and exact layout. Remove these before
  committing to this public repository.
- The render procedure handles workspace access and tokens without explicit approval boundaries.
  Publishing to a workspace needs its own approved target, as the harness-write Power BI route
  already says.
- `"visibility": "private"` hides nothing in a public repository, and the optional Windows-only and
  service dependencies are not declared.
- The draft was being edited during this review.

## Existing-Skill Improvements

None justified beyond the TMDL proposal saved in the
[layout tests evaluation](pbi-report-layout-tests.md); the general lessons here are already covered.

## Verification Limits and Reconsideration

This was a source review. No script, test, render, or report was run. Reconsider when the in-progress
edits are committed, when the team's style is separated from generic checks, or when another team
asks for these conventions.

## Follow-up

On 2026-10-16 the owner chose to consolidate this draft into native SkillVault skills instead of
publishing it as is. Its checker became `check_style.py` in
[powerbi-test](../../skills/data/powerbi-test/SKILL.md). It checks only what a project's style file
sets, and the bundled example uses neutral values. The draft's general Power BI behavior notes moved
to [powerbi-build](../../skills/data/powerbi-build/SKILL.md), and its rendered check moved to
`powerbi-test`. No team's house style is published. On 2026-10-19 the owner retired the draft, and
the skills' origin entries for it were dropped; the source link above keeps the reviewed revision.
