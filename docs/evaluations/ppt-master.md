# PPT Master Evaluation

- Evaluated: 2026-09-27
- Source: https://github.com/hugohe3/ppt-master
- Skill directory: `skills/ppt-master`
- Reviewed revision: `680de11f1bef4628b68d5daad9dffec569fbd51f` (2026-09-27)
- Declared skill version: `6.6.0`
- Author: Hugo He
- License: MIT; root notice names Hugo He, 2025-2026
- Requested capabilities: native editable PPTX, reusable templates, consistent brand colors, fonts, and layouts

## Recommendation

Purpose: Generate presentations, create reusable presentation templates, or edit an existing PPTX
while retaining its native design. Value: High for the requested work. Fit: A substantial script-backed
presentation workflow, with a useful reference-only entry for SkillVault.

Skill recommendation: Upsert an original repository-only reference to the upstream skill. Keep
installation and execution separate; do not vendor its converter, assets, or full instructions as
part of that reference. Unlike a screenshot-to-slide wrapper, the inspected source has native
PowerPoint chart/workbook construction and theme-font handling.

Installed recommendation: Coexist with the existing `harness-report` and `kpi-dashboard` skills;
replace neither. Standalone use: Worth an explicitly approved trial using a representative template
and non-sensitive material. Actual PowerPoint editing, font fidelity, and rendering remain untested
in this assessment.

Harness integration: Defer execution integration. The current report dispatcher supports Power BI,
Grafana, Jarvis, web, and query routes, not a declared PPTX route. A reference does not add a renderer,
controller action, data access, or permission to install dependencies.

The approved [PPT Master reference](../../skills/writing/ppt-master/SKILL.md) now lives in
`skills/writing/ppt-master`, kind `reference`, with an explicit null version distinct from the
upstream 6.6.0 version. It retains Hugo He's attribution and the reviewed source revision. The
global availability default describes a future explicitly requested install; this entry remains
repository-only. Upstream tools are not bundled.

## Requirement Fit

These verdicts are grounded in source and documented contracts, not a generated-deck test.

| Requirement | Assessment | Important condition |
| --- | --- | --- |
| Native editable PPTX | Supported for supported SVG content converted to DrawingML | SVG is an authoring intermediate, not necessarily one embedded image per slide. Photos and some unsupported source objects are not freely editable vector/text elements. |
| Editable chart data and table cells | Separate supported export path | Default charts/tables are editable shapes. `--native-charts-and-tables` plus valid object metadata emits native Chart/Table objects; charts include embedded workbooks. |
| Reuse an existing corporate PPTX | Source-preserving Edit Native PPTX route | Unchanged pages and objects are restored; selected content is edited. The route preserves masters/layouts and does not support editing inherited Master/Layout objects or changing slide size. |
| Reusable standardized templates | Create Template, then Generate | Brand, Style, Layout, and Deck workspaces have distinct roles. Layout/Deck can drive structured Master/Layout/placeholder output; Brand/Style alone remains flat. |
| Consistent brand colors | Explicit identity specification and locked values | Brand values carry official/user/approximate provenance. Literal color substitutions do not automatically redesign derived tints or update every explanatory reference. |
| Fonts and layout consistency | Theme typography and structured-layout support | Code handles Latin/East Asian theme faces, title/body defaults, and source embedded-font sidecars. Rendering and editing still require compatible fonts, rights, and target PowerPoint validation. |

For the user's strict native-editability requirement, choose the native object path for each required
chart/table and inspect the delivered variant. A `.pptx` extension, editable vector shapes, and a
chart whose values can be changed through PowerPoint's Edit Data are different guarantees.

## Source Evidence

No matching candidate was found in 55 inspected global/current-project skill folders or the local
and official SkillVault catalogs; the optional cache and prior assessment were absent. The public
directory and repository description identified `hugohe3/ppt-master`. This assessment excludes forks
and similarly named tools. Popularity and directory audit badges were not treated as proof.

The entrypoint and routing guide distinguish Generate PPTX, Create Template, and Edit Native PPTX.
The native-edit route uses a round-trip workspace and separate original package backing; it does not
silently regenerate an existing deck through the ordinary generation route. Its output receipt
distinguishes unchanged, cloned, patched, and rebuilt pages.

`native_objects._build_native_chart` writes `p:graphicFrame`, chart relationships/parts, and embedded
XLSX data. The workbook helper writes category/series or XY/bubble data through XlsxWriter, openpyxl,
or a minimal OOXML path. The native interface defines `a:tbl` table output and explicitly separates
default shape rendering from native Chart/Table activation. Invalid or stale required metadata can
block the native variant rather than justify silently delivering a different object type.

The Brand workflow owns palette, typography, logo, voice, and icon identity, not slide structure.
It distinguishes literal official values, user decisions, and visual estimates. The theme-font code
loads locked title/body families, writes major/minor fonts into theme parts, and updates East Asian
script mappings. The embedded-font helper validates and carries source font payloads; it does not
establish that every newly requested font will be installed or embedded automatically.

## Limits and Prerequisites

- The project declares Python 3.10+. Export uses Python libraries including python-pptx and workbook
  tooling; optional source conversion, image generation, preview, and narration have additional
  dependencies. The broad requirements file includes optional services; a reference entry installs none.
- Native conversion has a supported feature set. Source SmartArt, complex effects, and media may be
  preserved as atomic proxies, not reconstructed into unrestricted editable components. Some imported
  tables become shapes when edited. Unsupported chart types must not be promised as native charts.
- Editing imported chart/table JSON requires `--native-charts-and-tables`; the native-edit guide says
  omitting it can preserve the source chart and its original data. The final path and data must be checked.
- A reusable template workspace and an existing corporate PPTX are different inputs. No automatic
  Master/Layout grafting onto an arbitrary deck is supported. Choose preservation versus redesign
  explicitly when intent is ambiguous; do not silently discard slides/content to make a layout fit.
- Deck-wide bulk updates cover literal `colors.*` values and a universal font-family substitution.
  Sizes, derived tints, icons/images, and semantic layout changes need targeted edits and revalidation.
  Chinese/Latin font combinations, text overflow, and substitution need checks in the intended viewer.
- Local conversion does not make model communication local. Source material, brand assets, research,
  image generation, and optional narration must stay within approved data, provider, and cost scope.
  Core MIT licensing does not license user templates/fonts; optional PyMuPDF has separate AGPL terms.
- The skill requires its attribution/integrity preflight and several route-specific gates. This
  evaluation neither executed nor bypassed them. Runtime availability, performance, and full workflow
  reliability were not demonstrated. Structural validation alone is not a visual or editability test.

## Existing-Skill Improvements

The current [report workflow](../../skills/planning/harness-report/references/workflow.md) already
preserves requested formats, validates plotted data, and limits fallback. The
[KPI guide](../../skills/data/kpi-dashboard/SKILL.md) already reuses design systems and verifies metric
semantics. The following are narrower additions, not reasons to replace those workflows.

### 1. Explicit Editability Acceptance

- Target: `harness-report`, Resolve the Contract and Validate and Deliver.
- Evidence and gap: PPT Master's shape-versus-native-object exports demonstrate why "editable" is
  ambiguous. Existing report checks cover native formats and visual behavior but do not explicitly
  distinguish editable text/shapes, data-backed charts/tables, and inherited template objects.
- Proposed change: When editability is requested, name the required object types and editing actions
  before choosing a tool. Verify the delivered artifact's objects and a representative edit/save/reopen
  in the intended application; record unsupported or flattened objects. A preview or file extension
  cannot satisfy that requirement. Keep fallback subject to the existing approval and budget rules.
- Expected benefit: Avoid delivering a visually correct file that cannot support the user's next edit.
- Validation: Compare a chart rendered as shapes with a native chart containing its data; only the
  latter passes an Edit Data requirement. A PNG-only or design-only request must not acquire an
  unnecessary native-editability gate. This proposal does not add a PPTX route or renderer.

### 2. Brand and Template Authority

- Target: `kpi-dashboard`, Workflow and presentation handoff.
- Evidence and gap: The Brand workflow separates evidenced identity from estimates and layout
  structure. Existing guidance reuses the design system but does not spell out this provenance and
  template-versus-appearance distinction for a branded output request.
- Proposed change: Reuse the supplied template/brand authority and record its revision, exact palette,
  title/body and language-specific font requirements, fixed layout elements, and permitted variation
  in the existing artifact specification. Mark sampled colors or inferred fonts as estimates; clarify
  material conflicts. Check representative output against those values without installing fonts or
  altering a template merely to make a check pass.
- Expected benefit: Make brand consistency inspectable instead of relying on a similar-looking output.
- Validation: An official palette overrides a screenshot estimate; an unavailable required font remains
  a reported limitation until an alternative is approved. An unbranded chart keeps its existing simple
  design path, without mandatory brand paperwork or a new registry.

## Applied Locally

On 2026-09-27, explicit approval added the original reference entry and applied both improvements:

- `harness-report` now resolves required object types/editing actions and requires representative
  edit/save/reopen evidence for delivered editable artifacts. Image-only and design-only work retain
  their existing scope; no PPTX route or renderer was added.
- `kpi-dashboard` now records supplied brand/template authority, exact values, font requirements,
  fixed structure, permitted variation, and unresolved limitations in the existing specification
  and handoff. Unbranded work remains lightweight; no font installation or template mutation is implied.

Seven focused Node instruction/metadata contracts passed, along with catalog/resource validation
for 39 public skills, editor diagnostics, and a read-only scope review. Representative cases covered
Edit Data versus shapes, image/design-only exclusions, official palette versus screenshot estimates,
and unavailable required fonts. These are instruction checks, not executed presentation or model
benchmarks; actual host trigger selection and output quality remain unverified.

The existing managed `latest` global/project `harness-report` copies and project `kpi-dashboard` copy
were refreshed through the guarded installer and verified against the current local checkout. The
new `ppt-master` reference and the absent global KPI copy were not installed. No upstream tools,
providers, schedules, or publication were activated.

## Acceptance Trial

A later approved trial should use a small Chinese/English deck with a known brand template, two
layouts, a chart, a table, and a slide that must remain unchanged. Verify:

1. Text and shapes can be selected and edited; saving and reopening causes no repair prompt.
2. The required chart supports Edit Data and the table supports cell editing; values match the source.
3. Masters/layouts, branding, font faces, and fixed elements match the selected route's contract.
4. Long Chinese labels, mixed-language text, and missing-font cases are inspected in the target viewer.
5. Required unchanged pages remain preserved, and unsupported objects are disclosed rather than flattened silently.

These are proposed acceptance criteria, not test results. No PPTX was generated, opened, edited, or
rendered in this evaluation. Source coverage included the entrypoint, README/license/requirements,
routing, native-edit and Brand guidance, template importer, native object/workbook code, typography
helpers, and bulk-update documentation. The entire exporter, every renderer, and every asset were
not audited. The initial evaluation added only this public-safe record; the subsequently approved
source changes are recorded under Applied Locally above.

## Sources

- [Pinned skill entrypoint](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/SKILL.md)
- [README and declared output variants](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/README.md)
- [License](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/LICENSE)
- [Routing and template structure](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/workflows/routing.md)
- [Native PPTX editing](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/workflows/edit-native-pptx.md)
- [Brand authority](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/workflows/create-template/create-brand.md)
- [Native chart/table contract](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/references/native-data-interface.md)
- [Native object construction](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/scripts/svg_to_pptx/native_objects/__init__.py)
- [Embedded chart workbooks](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/scripts/svg_to_pptx/native_objects/workbook.py)
- [Theme fonts and master text styles](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/scripts/svg_to_pptx/drawingml/theme_fonts.py)
- [Embedded source-font handling](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/scripts/pptx_embedded_fonts.py)
- [Bulk color/font update limits](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/scripts/docs/update_spec.md)
- [Dependencies](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/requirements.txt)