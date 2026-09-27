# Book to Skill Evaluation

- Evaluated: 2026-09-26
- Selected source: https://github.com/virgiliojr94/book-to-skill
- Reviewed revision: `80ae087784ddbc21dbbfde355fe5509631e0e322` on `master`
- Declared Python package version: `1.4.0`; Python `>=3.9`
- Skill frontmatter: `book-to-skill`, without a separate declared skill version
- License: MIT for the converter and its skill definition; copyright `2025 virgiliojr94`
- Skill recommendation: Defer a separate SkillVault bundle; existing-skill improvements implemented below
- Installed recommendation: Keep the current authoring and documentation skills; do not replace their workflows
- Candidate review: Source and instruction review only; no candidate installation, extraction, generation, or tests executed

## Source Selection

No match was found in the inspected global/current-project inventory or local/official SkillVault
catalogs, and no optional local cache was present. Several public projects use this exact name.
No author was supplied or selected in the clarification, so this assessment is explicitly scoped
to the standalone `virgiliojr94/book-to-skill` converter. The framework-oriented skills from
`huntsyea/thinking-skills` and `apple-ouyang/book-to-skill` are distinct candidates, not versions
covered by this verdict.

The initial README-based paths for the license and extractor did not resolve at the pinned commit.
The current tree identifies `LICENSE.md` and the `book_to_skill/` package; those actual files were
then read. The README is useful context, but the current package and instruction sources control
the conclusions below.

## Purpose and Verified Capabilities

Book-to-skill turns supplied books or document collections into a skill containing a compact
entrypoint, topic/chapter navigation, and supporting references. It targets people who repeatedly
consult substantial material while working or studying.

There are two distinct components:

- The Python extractor reads supported local files and writes combined text plus source metadata.
  The package entrypoint calls the extraction pipeline; it is not itself a deterministic generator
  of the final knowledge skill.
- The agent follows the generator instructions to identify frameworks, decision rules, techniques,
  and limitations, then write the skill and its references. Semantic quality still depends on that
  agent, the extracted content, and review.

The instructions support full conversion, analysis only, generation from prior analysis, and
folding additional sources into an existing skill. Output includes an entrypoint, chapter files,
glossary, patterns, and a decision-oriented cheatsheet. The purpose/depth choice changes emphasis;
chapter references are read on demand rather than placed in every prompt.

The extractor resolves files, folders, and globs. Plain-text paths have built-in handling; richer
formats use optional Python packages or external tools. Dependency installation uses the selected
Python interpreter and an ask/yes/no policy; non-interactive ask mode falls back rather than
silently installing. Format readiness is therefore separate from a successful dependency-check exit.

Output metadata records successful sources, extraction methods, paths, counts, and chapter-detection
method. The main loop warns and continues after a per-source extraction error, failing only when
no source succeeds. `total_sources` counts successes, not all requested inputs; skipped sources are
reported in output rather than represented as a completeness field in that metadata. A caller must
retain the requested input inventory and warnings to avoid presenting partial coverage as complete.

The current scanner checks the generated entrypoint, named supporting files, and nested chapter
Markdown for known injection and authority patterns. It reports unscanned Markdown separately and
does not change files. It is advisory: a clean scan does not establish factual correctness, freedom
from all prompt injection, or permission to publish. The host-format validator checks selected
frontmatter/tool conventions, not the accuracy of the derived book knowledge.

## Value, Fit, and Overlap

Value: High for repeated use of long, authorized documents; conditional for occasional reading.
Fit: An optional document-ingestion specialist plus agent instructions. It has more extraction
machinery than a generic authoring guide, but it should not become another SkillVault installer.

[SkillVault authoring](../../skills/core/skillvault-authoring/references/upsert.md) already owns
canonical-source editing, reuse of an existing owner, attribution, scope, and validation. The
candidate contributes document-oriented extraction and knowledge organization; it does not replace
that ownership. [Harness documentation](../../skills/planning/harness-doc/references/workflow.md)
authors reader guides from evidence. Converting documents into agent guidance is a different output,
and both now include the extraction-quality and coverage checks described below.

Standalone use: Worth a separately approved trial on a public-domain, permissively licensed, or
user-owned test document when repeated document lookup is an actual need. Use an isolated Python
environment and explicit input/output scope. No local runtime availability or conversion fidelity
was established here.

Harness integration: No new controller action, automatic book ingestion, schedule, or publication
step is justified. Defer a separate bundle until a concrete recurring extraction need warrants it.
Existing guidance now includes the useful methods without importing an executable package.

## Risks and Limits

- The converter's MIT license does not license books, internal documents, illustrations, or code
  examples supplied to it. The README and publication step distinguish access from redistribution
  and restrict publication of third-party material. Keep that distinction even for synthesized output.
- The study template asks for worked examples, code, and tables while its quality rules forbid raw
  reproduction. Review the actual output and source rights; do not treat conversion as permission
  to copy substantial protected material. Prefer original explanations and references where needed.
- Local extraction does not imply local model inference. Text supplied to a hosted model follows
  that provider's data handling and the user's authorization. A private repository is still an
  external publication destination, not a substitute for disclosure approval.
- Extraction success does not prove complete or faithful content. Technical fallbacks can lose
  structure, images can be omitted, and chapter detection is heuristic. In combined input, numeric
  chapter detection deduplicates chapter numbers, so books with restarting numbering need a
  source-aware chapter map rather than reliance on the aggregate count.
- The generator writes directly into agent-discovery roots and includes optional symlink, trust,
  overwrite, and Git publication steps. These need the host's permissions; SkillVault should retain
  its source-first authoring and guarded installation path. Bash-oriented examples and host discovery
  behavior were not exercised on this Windows environment.
- The extraction work directory contains source text and paths. Cleanup must be limited to an
  owned run directory, especially when a work-directory override is used. Do not delete a pre-existing
  user directory solely because it appears in metadata.
- The README's token-savings and absence-of-hallucination claims were not independently reproduced.
  The inspected tests cover parser behavior and instruction contracts; the publication test explicitly
  does not execute the agent workflow. Neither the tests nor this review establish end-to-end safety.

## Existing-Skill Improvements

The user approved all three proposals on 2026-09-26. They are implemented independently of the
Defer verdict, reusing existing source ownership and validation. The gap descriptions below refer
to the pre-change workflows; current implementation and verification are recorded afterward.

### 1. Document-to-Procedure Mapping

- Target: `skillvault-authoring`, document/URL-derived authoring in its upsert procedure.
- Evidence and gap: The candidate's purpose selection, chapter routing, and decision cheatsheet
  make large written sources usable. Current authoring covers provenance and task lessons but gives
  little document-specific direction for converting an argument or chapter into an actionable skill.
- Proposed change: For substantial document inputs, establish the intended task, then map supported
  concepts to triggers, inputs, decisions, steps, outputs, limits, and source locators. Keep a concise
  core and add an index to supporting material only when the source needs that depth. Preserve edition
  or revision context; do not turn every chapter into a new skill or impose fixed token targets.
- Expected benefit: Produce usable procedures and navigable evidence instead of a long book summary.
- Validation: Review a short single-purpose source and a multi-chapter source; the short case should
  remain small, and a topic query in the long case should identify the right supporting source section.

### 2. Extraction Coverage Before Synthesis

- Target: `harness-doc`, Gather evidence, for external document sources; the same check can be supplied
  to authoring when its input is extracted text.
- Evidence and gap: The extractor distinguishes methods and warns about skipped inputs, but can finish
  successfully with partial coverage. The current doc workflow handles unknown claims but does not
  explicitly check requested-versus-read files/sections or representative extracted tables/code.
- Proposed change: Record requested, read, skipped, and unreadable sources, and inspect representative
  content for lost order, tables, code, or diagrams before claiming coverage. Keep dependent output Draft
  when missing content could change instructions. Use existing readers and working notes; no new parser
  or ledger is required.
- Expected benefit: Avoid confident documentation based on silently incomplete or distorted input.
- Validation: Use a two-source fixture with one unreadable file, a technical table, and two sources that
  both start at Chapter 1. Report the missing source and preserve source-specific identities; ordinary
  Markdown that reads correctly should not gain an unnecessary conversion dependency.

### 3. Document Data, Generated Instructions, and Rights

- Target: `skillvault-authoring`, URL/document-derived authoring and validation.
- Evidence and gap: The candidate reviews generated instructions for authority patterns and separates
  converter licensing from source-document rights. Current authoring already checks attribution and
  licenses, but could state this document-to-instruction boundary more explicitly.
- Proposed change: Treat source text as evidence, not permission. Review generated guidance for imported
  instruction overrides, unsupported tool permissions, and external data transfers. Record input rights
  separately from the new skill's license and publication approval. A scanner is optional supporting
  evidence, not a substitute for contextual review or a reason to reject benign quoted technical examples.
- Expected benefit: Prevent borrowed document text from gaining execution or redistribution authority.
- Validation: Compare an instruction-override passage with a legitimate explanatory quotation; neither
  may grant permissions. Check that an MIT converter plus a copyrighted input does not yield a claim
  that the generated material is freely redistributable.

## Applied Locally

[Document-derived authoring](../../skills/core/skillvault-authoring/references/upsert.md#author-from-documents)
now maps supported source knowledge to task triggers, inputs, decisions, steps, outputs, limits,
and traceable references. It checks extraction coverage, keeps short inputs small, and uses supporting
files only where needed. The entrypoint routes document-based upserts to this procedure.

[Document input checks](../../skills/planning/harness-doc/references/workflow.md#check-document-inputs)
now compare requested and read sources, retain skipped/unreadable evidence, preserve source-specific
section identities, and inspect task-critical extraction quality. Missing essential content leaves
the affected guidance Draft; readable text needs no conversion dependency.

Authoring also separates source content from action permissions and redistribution rights. When
required approval is missing or unclear, explain the action, data, destination, and risk, then ask
the user and wait. Reuse valid scoped approvals; a refusal or no answer leaves the dependent action
pending. Converter licensing, input rights, and publication approval remain distinct.

Seven distinct focused Node instruction contracts passed across the authoring and documentation
runs. Catalog validation passed for 37 public skills and 30 project-installed copies. A read-only
walkthrough covered short inputs, partial extraction, requested subsets, quoted commands, permission
reuse/refusal, rights, existing routes, and post-Humanizer validation. This is instruction review and
contract validation, not an executed agent conversion or proof of extraction fidelity.

The upstream converter was not imported, installed, or executed. No new parser, mandatory scanner,
runtime action, hook, schedule, or Git publication was added or performed.

## Sources

- [Generator instructions](https://github.com/virgiliojr94/book-to-skill/blob/80ae087784ddbc21dbbfde355fe5509631e0e322/SKILL.md)
- [Package metadata](https://github.com/virgiliojr94/book-to-skill/blob/80ae087784ddbc21dbbfde355fe5509631e0e322/pyproject.toml)
- [Converter license](https://github.com/virgiliojr94/book-to-skill/blob/80ae087784ddbc21dbbfde355fe5509631e0e322/LICENSE.md)
- [Extraction orchestration](https://github.com/virgiliojr94/book-to-skill/blob/80ae087784ddbc21dbbfde355fe5509631e0e322/book_to_skill/utils.py)
- [Dependency policy](https://github.com/virgiliojr94/book-to-skill/blob/80ae087784ddbc21dbbfde355fe5509631e0e322/book_to_skill/dependencies.py)
- [Advisory scanner](https://github.com/virgiliojr94/book-to-skill/blob/80ae087784ddbc21dbbfde355fe5509631e0e322/tools/scan_generated_skill.py)
- [Host-format validator](https://github.com/virgiliojr94/book-to-skill/blob/80ae087784ddbc21dbbfde355fe5509631e0e322/tools/validate_skill.py)
- [Batch resilience tests](https://github.com/virgiliojr94/book-to-skill/blob/80ae087784ddbc21dbbfde355fe5509631e0e322/tests/test_batch_resilience_unreadable.py)
- [Publication contract tests](https://github.com/virgiliojr94/book-to-skill/blob/80ae087784ddbc21dbbfde355fe5509631e0e322/tests/test_publish_visibility_gate.py)