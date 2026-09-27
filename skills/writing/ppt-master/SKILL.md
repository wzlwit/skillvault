---
name: ppt-master
description: "Reference guide to hugohe3/ppt-master for native editable PowerPoint/PPTX, reusable templates, brand colors, fonts, and slide layouts. Use /ppt-master to locate upstream guidance. Overlaps with harness-report on artifact validation and kpi-dashboard on presentation design; upstream tools are not bundled."
license: MIT
metadata:
  author: Hugo He
  maintainer: wzlwit
  version: null
argument-hint: "[<deck-or-template>] [<presentation-goal>]"
---

# PPT Master Reference

This original SkillVault guide points to PPT Master's presentation workflows. No upstream scripts,
assets, converter, or full workflow are bundled. This reference does not generate a deck, install
dependencies, or add a PPTX route to `harness-report`.

## Use and Limits

Before applying an explicitly requested upstream workflow, fetch and read the upstream instructions
and selected route for the intended revision. If the guidance or required tools are unavailable,
report the limitation; do not claim that reading this reference ran the workflow. Preserve the
upstream route's required checks within the user's approved scope and applicable host restrictions.

Choose the route by the requested result, not just the input file extension:

| Upstream route | Intended result | Important boundary |
| --- | --- | --- |
| Generate PPTX | A new deck from content and selected design inputs | Supported content can become editable DrawingML; not every image or unsupported object becomes editable text/vector content. |
| Create Template | A reusable Brand, Style, Layout, or Deck workspace | Brand/Style supplies appearance and remains flat; Layout/Deck can supply Master/Layout/placeholder structure. |
| Edit Native PPTX | Preserve an existing deck while editing selected content | Retains source masters/layouts and unchanged objects; editing inherited Master/Layout objects or changing slide size is unsupported in this route. |

- Resolve preservation versus redesign when intent is ambiguous. An existing corporate PPTX and a
  reusable template workspace are different inputs; do not silently regenerate or flatten the source.
- Specify the required editing actions. Default charts/tables are editable shapes. Data-backed native
  charts and native tables require eligible metadata and `--native-charts-and-tables`; native charts
  include embedded workbooks for Edit Data. Unsupported types and atomic source proxies remain limited.
  Inspect the actual exported variant and verify required edits, save, and reopen in the target app.
  Neither a screenshot nor a `.pptx` extension proves these capabilities.
- Reuse authoritative brand values and distinguish estimates. Check palette, title/body and language
  fonts, fixed layout elements, and any required template structure. Font mappings and preserved source
  font payloads do not guarantee that every requested font is available, licensed, or correctly rendered.
  Bulk color/font substitutions do not replace layout, overflow, or mixed-language validation.
- No installation or execution is implied by discovering, reading, or adding this reference. Runtime
  setup, source/provider access, optional services, cost, and publication need their corresponding
  approval. Local conversion does not make model communication local. Upstream MIT licensing does not
  license user templates/fonts or override optional dependencies' separate terms.

Original request example, not a tested output:

```text
/ppt-master Use the supplied corporate template for a Chinese/English deck. Preserve its brand
fonts and layouts; require Edit Data for charts and editable table cells.
```

## Source

- Repository: https://github.com/hugohe3/ppt-master
- Reviewed revision: `680de11f1bef4628b68d5daad9dffec569fbd51f` (2026-09-27)
- Upstream declared skill version: `6.6.0`; this independently written reference is unversioned.
- Upstream author: Hugo He; [MIT license](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/LICENSE).
- [Skill entrypoint](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/SKILL.md)
- [Route selection](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/workflows/routing.md)
- [Native editing](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/workflows/edit-native-pptx.md)
- [Brand authority](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/workflows/create-template/create-brand.md)
- [Native chart/table contract](https://github.com/hugohe3/ppt-master/blob/680de11f1bef4628b68d5daad9dffec569fbd51f/skills/ppt-master/references/native-data-interface.md)

## Curation and Overlap

Written for SkillVault and maintained by wzlwit, with upstream authorship retained in metadata.
This is navigation and scope guidance, not an import or implementation of the presentation engine.
Source inspection does not certify PowerPoint editing, font fidelity, or rendering quality.

`harness-report` coordinates artifact identity, authoring, and validation through its declared routes;
this reference supplies no additional report route or writer. `kpi-dashboard` supplies reusable metric,
layout, and brand/template contracts; this reference points to the separate presentation workflow.