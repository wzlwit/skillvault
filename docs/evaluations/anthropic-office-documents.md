# PDF, Word, and Excel Toolkit Evaluation

- Evaluated: 2026-09-27
- Assumed source: https://github.com/anthropics/skills
- Scope: `skills/pdf`, `skills/docx`, and `skills/xlsx`
- Reviewed revision: `33375500bcea98d610eb30ce10ac4e59b89c390d` (2026-09-24)
- Author: Anthropic, PBC
- Declared skill versions: Not declared in the inspected entrypoints
- License: Proprietary, source-available; all three license files have identical content
- Requested work: file merging, spreadsheet cleaning, and document formatting

## Source Assumption

The supplied "PDF/Word/Excel office trio" label is descriptive, not a unique package identity.
This assessment uses Anthropic's official `pdf`, `docx`, and `xlsx` skills as the direct match
for those file types. It does not attribute an unidentified publisher's marketing claim to
Anthropic. A different intended toolkit needs its exact URL before these conclusions are reused.

The name lookup checked 55 global/current-project skill folders, the local catalog, the absent
optional source cache, and the 36-entry official SkillVault catalog. No matching named toolkit was
identified there. Public directory entries also use "office trio" for different Word/Excel/PPT
bundles; they were not treated as interchangeable with this PDF/DOCX/XLSX scope.

## Recommendation

Purpose: Give a coding agent task-specific methods and helpers for processing PDFs, producing or
editing Word documents, and creating, cleaning, or analyzing spreadsheet files. Audience: people
automating routine local document work with an appropriately authorized agent and toolchain.

Value: High. The requested tasks are directly covered, and the instructions address important
format-specific failure cases. Fit: Three specialized agent workflows, not a one-click office
application or a guarantee that every document can be processed without review.

Skill recommendation: **An original reference-only guide**, not an import of these bundles.
The approved [office-documents reference](../../skills/writing/office-documents/SKILL.md) now lives
under `skills/writing/`, kind `reference`, version null. It contains original navigation and
boundaries, linking to the three sources without copying their prompts, scripts, examples, or
assets. Its global availability default describes a future explicit install; the entry remains
repository-only. Upstream proprietary rights are separate from the reference's undeclared license.

Suggested description: "Reference to Anthropic's PDF, Word, and Excel document skills for file
processing; overlaps with harness-doc on document output and harness-report on workbook/report
validation. Upstream tools are not bundled and their terms apply."

Installed recommendation: Coexist with `harness-doc` and `harness-report`; replace neither.
The former owns evidence-grounded reader documentation, while the latter coordinates its declared
report/query platforms. Neither becomes a PDF, DOCX, or XLSX engine by naming this toolkit.

Standalone use: Worth trying in an environment permitted by the applicable Anthropic agreement,
with representative non-sensitive files. Do not assume that public source availability grants
permission to install the upstream bundles in Copilot or another host.

Harness integration: Defer executable integration. No new document-report route, renderer, parser,
controller, or environment is justified merely by creating a reference.

The user separately approved the reference and both existing-skill improvements after evaluation.
Their completed scope and checks are recorded under Applied Locally below; upstream execution and
new installation were not approved or performed.

## Capability Fit

| Requested work | Evidence-backed capability | Important boundary |
| --- | --- | --- |
| Merge and split files | The PDF guide provides page-based merge/split operations with pypdf and CLI alternatives | This is explicit PDF support, not a universal lossless merger for Word documents or workbooks. Complex forms, bookmarks, attachments, and signatures need their own acceptance checks. |
| Extract PDF content | Text/table extraction, image extraction, OCR, and PDF creation are covered | Scans and complex tables can need OCR or layout-specific handling. The table example assumes first-row headers and concatenates extracted tables; that is not semantic data cleaning. |
| Clean Excel/CSV/TSV data | The XLSX trigger and workflow cover malformed rows, misplaced headers, tabular restructuring, bulk pandas processing, and openpyxl editing | Cleaning rules still need the intended schema and business meaning. Formulas, macros, external references, and original formatting are distinct preservation requirements. |
| Format Word documents | New documents use the npm `docx` library; existing documents use targeted OOXML editing, followed by validation and rendering | The creation library does not open existing documents. Legacy `.doc` conversion, comments, revisions, and paginated layout require separate handling. |
| Reliable delivery | DOCX rendering and XML/redline checks; XLSX recalculation and result inspection | Passing a parser, schema check, or formula-error scan does not prove correct content, correct calculations, or visual fidelity. |

## Verified Helper Behavior

- `xlsx/scripts/recalc.py` recalculates through LibreOffice and rewrites the workbook in place.
  It uses a temporary LibreOffice profile and installs its recalculation macro there, rather than
  editing the ordinary user profile. Missing prerequisites and unchanged output produce errors.
- The recalculation CLI exits nonzero for an `error` result, but `status: errors_found` exits zero.
  Consumers must inspect the structured result, not only the process exit. Error-location lists
  are capped, while total counts remain available.
- Its external-link guard reads both formula and cached-value views and refuses certain linked
  cells with missing caches. The guard explicitly does not cover every possible external reference;
  `--force` accepts the stated risk. It is not blanket workbook-preservation validation.
- `docx/scripts/merge_runs.py` coalesces matching adjacent runs in `word/document.xml`. It does not
  process headers, footers, or footnotes, and it does not merge across separate tracked-change
  wrappers. Direct file mode overwrites the input unless a separate output is specified.
- `docx/scripts/office/validate.py` offers DOCX schema and optional redlining checks. Redlining
  requires the original document and `--author`; schema validation alone is not that check.
  Its XLSX-family branch explicitly performs no XSD validation and exits zero.

## Risks and Limits

- **Rights:** The three license files bind use to the applicable Anthropic agreement and restrict
  copying, retention outside the Services, derivative works, and redistribution. They are not
  covered by an assumed repository-wide Apache grant. This evaluation is original analysis with
  links, not a grant of rights or a determination of a particular account's contract.
- **Host assumptions:** The guides assume several tools are preinstalled. That was not verified
  in this Windows/VS Code environment. Python packages, Node/docx, LibreOffice, Poppler, and optional
  OCR/CLI utilities remain real prerequisites; the DOCX shell examples are POSIX-oriented.
  The LibreOffice helper also contains a Linux-oriented `gcc`/`LD_PRELOAD` sandbox workaround.
- **Workbook preservation:** Saving an openpyxl workbook loaded with `data_only=True` replaces
  formulas with values. Formula caches can be missing or stale; macros need explicit preservation,
  and external-workbook references can be damaged by a save/recalculation round trip.
- **Calculation coverage:** The XLSX guide documents restrictions of its LibreOffice environment,
  including modern functions and dynamic-array behavior. Those are not universal Excel limitations.
  An error-free calculation can still use the wrong range or omit expected spill results.
- **Document fidelity:** OOXML validity does not prove pagination, font availability, or faithful
  rendering. The DOCX guide also documents differences when accepting deleted paragraphs through
  Word, LibreOffice, or pandoc. Required revision semantics should not be inferred from one preview.
- **Chinese and mixed-language output:** No Chinese OCR, font, table-layout, or rendering trial was
  run. Generic English examples do not establish Chinese-specific quality.
- **Data and scope:** Preserve originals and selected output paths. No private file access, upload,
  decryption attempt, conversion, package installation, or source-file rewrite was performed here.
  Neither discovery nor reference creation authorizes such actions.

## Existing-Skill Improvements

Both improvements were approved and applied on 2026-09-27. The rationale below describes the
pre-change gaps and the resulting guidance. Existing preservation, fallback, and editability
checks remain in force.

### 1. Workbook Formula and Cache Acceptance

- Target: `harness-report`, Resolve the Contract and Validate and Deliver in its
  [authoring workflow](../../skills/planning/harness-report/references/workflow.md).
- Evidence and gap: The XLSX skill distinguishes formulas from cached values, and `recalc.py`
  demonstrates why a zero exit can accompany reported formula errors. Before this update, report
  guidance checked formulas, plotted data, and editable objects without naming this workbook-specific trap.
- Applied change: When a spreadsheet supplies reported figures or is an explicitly requested
  artifact, distinguish formula and value views, check cache freshness and required recalculation,
  inspect structured error results, and verify representative expected values. Preserve formulas,
  macros, and external references within the agreed contract; missing evidence remains Unverified.
  Recalculation may write files, so use only an approved engine and destination. Do not silently
  replace formulas with literals, mutate a source workbook, or add an XLSX route.
- Expected benefit: Avoid treating empty caches as missing business data or declaring incorrect
  workbooks valid merely because a script completed.
- Validation: A missing formula cache and `errors_found` with exit zero cannot pass. A workbook
  whose formulas evaluate but reference the wrong row also fails its expected-value check. A
  values-only CSV or an unchanged workbook with sufficient verified values needs no forced recalculation.

### 2. Paginated Document Visual Acceptance

- Target: `harness-doc`, Validate and Deliver in its
  [documentation workflow](../../skills/planning/harness-doc/references/workflow.md).
- Evidence and gap: The DOCX skill requires rendering the written file and inspecting its pages;
  the PDF guide calls out unsupported glyphs in default fonts. Before this update, documentation
  checks covered facts, links, diagrams, and prose without explicitly checking the entire paginated artifact.
- Applied change: When PDF/DOCX is an agreed deliverable, inspect the final rendered pages for
  clipping, page breaks, split tables, captions, headers/footers, and required-language glyphs.
  Preserve the requested format and existing post-Humanizer validation order. Use available,
  authorized renderers; missing rendering stays an explicit incomplete check, not automatic
  permission to install software or substitute a different deliverable.
- Expected benefit: Catch a technically valid document whose layout makes content unreadable.
- Validation: A valid DOCX with a table clipped across pages or missing Chinese glyphs remains
  unvalidated. A Markdown-only guide does not acquire a mandatory Word/PDF conversion step.

## Applied Locally

- Added the original `office-documents` reference, catalog entry, reciprocal overlap descriptions,
  and README navigation. No upstream implementation or new renderer/report route was added.
- Added workbook acceptance to report contract resolution and delivery checks, including formula
  preservation, cache interpretation, scoped recalculation, structured errors, and expected values.
- Added final-page visual acceptance for agreed PDF/DOCX deliverables after Humanizer, retaining
  Draft outcomes for missing checks and no conversion requirement for Markdown-only output.

Nine focused Node instruction/metadata contracts passed. Catalog and resource validation passed
for 40 public and 30 project-installed skills; editor diagnostics and a read-only scope review
found no blocking issues. These checks cover the instructions, not real-file processing quality
or observed host triggering. Optional model and representative-document trials have not run.

The existing managed `latest` global `harness-doc` and `harness-report` copies and project
`harness-report` copy were refreshed through the guarded installer and verified against the
current local checkout. The new reference and absent project `harness-doc` copy remain uninstalled.
No user documents, upstream runtimes, provider settings, schedules, or publication were changed.

## Verification and Reconsideration

Source review covered all three pinned entrypoints, their matching license identities, PDF merge
and table-extraction examples, the XLSX recalculation and LibreOffice helpers, and DOCX run-merging
and validator code. The relevant complete companion workflows were inspected. Form-filling helpers,
every schema validator, and every format edge case were not audited.

No upstream helper, office application, or generated-output test was run. Before operational use,
an authorized trial should cover ordered PDF merging, a scanned/table PDF, a workbook with formulas
and external links, a cleanup case with meaningful identifiers, and a paginated Chinese/English DOCX.
Check actual files, values, preserved features, and rendering rather than only completion messages.

Reconsider the assessment when the intended publisher is identified differently, licensing changes,
the host's dependencies are verified, or representative output tests establish the required behavior.
The initial evaluation saved only this public-safe assessment. The subsequently approved source
changes and existing-copy updates are described under Applied Locally; executable integration
remains deferred.

## Sources

- [Pinned PDF skill](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/pdf/SKILL.md)
- [Pinned DOCX skill](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/docx/SKILL.md)
- [Pinned XLSX skill](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/xlsx/SKILL.md)
- [Shared document-skill license text](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/pdf/LICENSE.txt)
- [XLSX recalculation helper](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/xlsx/scripts/recalc.py)
- [LibreOffice helper](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/xlsx/scripts/office/soffice.py)
- [DOCX run-merging helper](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/docx/scripts/merge_runs.py)
- [Office validator entrypoint](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/docx/scripts/office/validate.py)