---
name: office-documents
description: "Reference to Anthropic's PDF, Word, and Excel document skills for merging PDFs, cleaning spreadsheets, and document formatting. Use /office-documents to locate the relevant guidance. Overlaps with harness-doc on document output and harness-report on workbook/report validation; upstream tools are not bundled and their proprietary terms apply."
metadata:
  author: Anthropic, PBC
  maintainer: wzlwit
  version: null
argument-hint: "[<file-or-task>] [<required-output>]"
---

# Office Documents Reference

This original SkillVault entry links to three separate Anthropic document skills. It is navigation
and scope guidance, not an office application or a copy of the upstream workflows. No upstream
prompts, scripts, examples, assets, or document-processing dependencies are bundled.

## Select the Guidance

Choose by the actual input, requested operation, and deliverable, not the informal "office trio"
label. These links refer specifically to PDF, DOCX, and XLSX, not a Word/Excel/PowerPoint bundle.

| Need | Upstream guidance | Boundary |
| --- | --- | --- |
| Merge/split PDFs or extract text, tables, and images | [PDF](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/pdf/SKILL.md) | PDF page operations are not a universal lossless merger for every document format. |
| Create, format, or edit Word documents | [DOCX](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/docx/SKILL.md) | Existing-file preservation and rendered pagination need checks beyond creating a new file. |
| Clean tabular files or work with spreadsheet formulas and formatting | [XLSX](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/xlsx/SKILL.md) | Cleaning needs an intended schema; formula, macro, and external-reference preservation are separate requirements. |

Before an authorized use of upstream materials, fetch and read the selected instructions and
their license for the intended revision. Confirm that the applicable agreement permits that use.
If access, rights, or required tools are unresolved, report the limitation; do not claim that this
reference ran the workflow or that its tools are preinstalled in the current host.

For an actual file task, reuse the selected files, preservation requirements, output destination,
and existing scoped approvals. Conversion or recalculation can write files; reading or installing
this reference authorizes no such operation, data upload, decryption, or publication. Changes of
scope require their normal approval. Do not run setup commands merely to explain the guidance.

Original navigation example, not an executed document test:

```text
/office-documents Find the guidance for cleaning this spreadsheet while preserving its formulas.
```

## Source and Rights

- Repository: https://github.com/anthropics/skills
- Selected directories: `skills/pdf`, `skills/docx`, and `skills/xlsx`
- Reviewed revision: `33375500bcea98d610eb30ce10ac4e59b89c390d` (2026-09-24)
- Upstream author: Anthropic, PBC; versions are not declared in the inspected entrypoints.
- All three skills declare proprietary, source-available terms. Their
  [license text](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/pdf/LICENSE.txt)
  ties use to the applicable Anthropic agreement and restricts copying, outside retention,
  derivative works, and redistribution. Do not infer Apache licensing from other repository content.

This reference grants no rights to the upstream materials and does not copy or adapt their
implementation. Separately licensed document libraries retain their own terms. Source inspection
does not certify file preservation, calculation accuracy, or Chinese/mixed-language rendering.

## Curation and Overlap

Written for SkillVault and maintained by wzlwit, with upstream attribution retained in metadata.
This original guide has no declared release version or license; upstream rights are recorded
separately, not assigned to the reference by inference.

`harness-doc` owns evidence-grounded reader documentation and checks requested paginated output.
`harness-report` owns its declared report/query routes and workbook-backed figure validation.
Neither this reference nor those overlap notes add a renderer, a document-report route, a required
dependency, or permission to install the upstream toolkit in another host.