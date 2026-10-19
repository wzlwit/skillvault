# Power BI Report Layout Tests Evaluation

- Evaluated: 2026-10-16
- Source: https://github.com/wzlwit/skillvault/tree/ebfb40533f2552637d59b80e89e0d498eceb8266/templates/pbi-report-layout-tests,
  a native SkillVault draft that was never in the catalog; retired on 2026-10-19
- Reviewed revision: `ebfb405` (version `1.0.0`), plus uncommitted local edits that were in progress
  during the review and raise it to `1.1.0`
- Author: wzlwit; no license declared, like other native SkillVault skills
- Scope: SKILL.md, README, manifest, rules reference, rule pack, script, and tests, read as source.
  Nothing was installed or run.

## Recommendation

Purpose: Test a Power BI report saved in the enhanced report format (PBIR), as a `.Report` folder, a
Power BI project (PBIP), or a PBIX file with PBIR metadata, before check-in or release. Value: High.
Fit: A script-backed skill.

Skill recommendation: Upsert after the in-progress edits land and the changes below are made.
Installed recommendation: Not installed anywhere; nothing to keep or replace. Standalone use: Usable
now on the owner's own reports. Harness integration: Once published, name it as the static check in
the Power BI route of the harness-write report workflow, before the rendering check that route
already requires.

## What It Checks

`scripts/verify_report.py` reads the report definition and, when given, the model's Tabular Model
Definition Language (TMDL) folder or a PBIX model through PBIXRay. It has four check groups:

- Rules from a YAML rule pack: page view and size, background, Filters pane, page names, display
  units, pie labels, localized titles, and alt text.
- Geometry: shown visuals stay on the page, content visuals don't overlap, buttons over content get
  a warning, and grouped visuals' relative positions are resolved first.
- Bindings: every table, column, measure, filter, sort, and localized text binding exists in the
  model.
- Parity: a PBIX's report definition matches its PBIR folder byte for byte, and its measures match
  the TMDL ones with whitespace ignored.

It prints findings or JSON and exits 1 on errors, or on warnings with `--strict`. It needs Python
3.10 or later, `pbir-utils`, and `pbixray`. It needs neither Power BI Desktop nor a network, except
for fonts when viewing the optional HTML wireframe. Tests use synthetic report fixtures and cover a
passing report, every error rule, geometry, bindings, strict mode, and PBIX report parity.

## Overlap and Earlier Evaluations

- The sibling draft [pbi-report-visual-conventions](pbi-report-visual-conventions.md) also checks
  page settings, the Filters pane, background, and display units. Each check needs one owner.
- `powerbi-modeling` owns model design; this draft only checks that report bindings resolve and that
  two copies of the measures match.
- `kpi-dashboard` is platform-neutral design guidance with no file checks.
- The [powerbi-modeling evaluation](powerbi-modeling.md) (2026-09-24) kept report authoring out of
  that skill's scope. This draft fills part of that gap without changing that verdict, and none of
  that record's reconsider conditions is met.

## Risks and Changes Needed

1. **Team policy as defaults.** The default rule pack encodes one team's conventions: canvas size and
   view, background color, Filters pane state, display units, and localized titles. The in-progress
   edits strengthen this with a fixed canvas width in Actual size view. Ship neutral defaults
   (bindings, geometry, parity, page names, alt text) and move policy into an example rule pack
   that a project passes in. The team's own pack belongs in the team's repository.
2. **Internal names.** The README cites team reports, and the in-progress edits add internal report
   names. Remove them before committing to this public repository.
3. **Metadata.** Remove `"visibility": "private"`, which hides nothing in a public repository.
   Declare the Python dependencies. Add the catalog entry with the same description in all three
   places, default to global availability, and use a name in the catalog's style that ends in its
   verb, such as `powerbi-report-test`.
4. **Untested path.** Model parity through PBIXRay has no test, and the README's results on real
   reports can't be reproduced from the repository. Add a synthetic test or mark the path
   unverified.
5. **Maintenance.** PBIR and `pbir-utils` still change, so the rule paths need periodic rechecks.

Suggested description: "Test Power BI reports saved as PBIR before release: rule-pack checks,
layout geometry, model bindings, and PBIX/PBIP parity, without Power BI Desktop. Overlaps with
powerbi-modeling on model bindings and harness-write on report validation; checks report files,
not rendered pages."

Suggested next request: `/skillvault-author pbi-report-layout-tests`, which promotes the draft with
the changes above. Installing it is a separate step.

## Existing-Skill Improvements

| Detail | Proposal |
| --- | --- |
| Target | `powerbi-modeling`, [validation cases](../../skills/data/powerbi-modeling/references/validation.md), Before and After a Real Change |
| Evidence and gap | Microsoft's [TMDL overview](https://learn.microsoft.com/en-us/analysis-services/tmdl/tmdl-overview) says TMDL uses strict single-tab indentation, multi-line expressions sit one level deeper than properties, breaking these rules is a parse error, and a `///` description must sit directly above its object. A private team workflow reviewed alongside this draft records the same failures. The validation cases cover persistence but say nothing about checking a hand-edited TMDL file. |
| Proposed change | When an approved change edits TMDL files directly, keep the indentation and description rules, then confirm the folder loads in Power BI Desktop, Tabular Editor, or the TMDL API before calling the change applied. Design-only work is unchanged. |
| Expected benefit | Catches TMDL broken by text edits before it is committed or deployed. |
| Validation | A contract test that the validation cases name the load check for TMDL edits, and that design-only use still needs no live connection. |

## Verification Limits and Reconsideration

This was a source review. No script, test, or report was run, and the in-progress edits may change
after the review. Reconsider when those edits are committed, when team policy is separated from the
defaults, or when PBIR or `pbir-utils` changes in a way that affects the rule paths.

## Follow-up

On 2026-10-16 the owner chose to consolidate this draft, the visual conventions draft, and related
team skills into three native skills written in SkillVault's own words:
[powerbi-build](../../skills/data/powerbi-build/SKILL.md),
[powerbi-test](../../skills/data/powerbi-test/SKILL.md), and
[powerbi-localize](../../skills/data/powerbi-localize/SKILL.md). This draft's checker became
`powerbi-test`'s `verify_report.py`. Its generic rules run by default, and house style moved to a
project style file with a neutral example. Each skill's `skill.json` lists the team skills it was
written from as `origins`, and `/skillvault-author <skill> check origins` lists their later commits.
On 2026-10-19 the owner retired this draft and the visual conventions draft, together with the local
copies of the team skills; the skills' origin entries for the drafts were dropped. The source link
above keeps the reviewed revision. The TMDL load check proposed above went to `powerbi-build`, which
owns file edits and checks that Desktop loads them; `powerbi-modeling` now names `powerbi-build` as its
counterpart instead of repeating the check.
