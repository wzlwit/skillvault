# Humanizer CH Evaluation

- Evaluated: 2026-09-27
- Source: https://github.com/zjqc/humanizer-ch
- Reviewed revision: `ae195e61e90b97d32aca683382c5732608b17fb1` (2026-06-17)
- Version: Not declared in the inspected bundle; identify it by revision
- Publisher: `zjqc`; original authorship is not separately declared
- License: Unknown; no license declaration/file found in the complete inspected tree or README
- Scope: This exact-name repository, not `humanizer-chinese`, `humanizer-zh`, or other adaptations

## Recommendation

Purpose: Diagnose and rewrite Chinese critical essays and theory-heavy commentary while preserving
argument density, authorial judgment, and a disciplined academic voice.

Value: Medium for that specialized writing task; limited incremental value for engineering guides.
Fit: A genre-specific editing skill, not a general Chinese translation of Humanizer or an AI detector.

Installed recommendation: Keep the existing `humanizer` reference and `harness-doc` workflow.
Skill recommendation: Add an original reference-only entry, as explicitly selected by the user on
2026-09-27. Importing the upstream package remains deferred until its license is clarified. The
reference does not replace the general Humanizer or become the default technical-document pass.

Standalone use: The editing ideas are relevant to explicitly requested Chinese essays, art reviews,
and theoretical commentary. The core is an instruction workflow; the helper scripts are maintenance
tools, not a rewriting engine. No writing-quality improvement or host compatibility was tested here.

Harness integration: No new runner, mandatory dependency, or automatic Chinese-language substitution
is justified. Preserve the current documentation pass and its technical-content safeguards.

## Source Resolution

At evaluation time, no matching Chinese variant was found among 55 global/current-project folders or in
the current/official SkillVault catalogs. The optional cache and prior evaluation were absent.
The public skill directory returned related names; a repository search then found the exact
`zjqc/humanizer-ch` match. Its own metadata confirms the skill name, so this assessment does not
silently substitute the more broadly named Chinese adaptations.

The pinned tree contains the skill instructions, README, Codex UI metadata, and four Windows
maintenance wrappers. All were read. The repository's license metadata is also null; the MIT terms
of the existing base Humanizer cannot be assumed to cover this separate repository.

## Intended Workflow

The skill first identifies the text's genre and desired register, diagnoses the main problems,
rewrites sentences and paragraphs, then checks whether the argument and voice survived. Its default
response contains a diagnosis, a complete rewrite, and a short explanation of the edits.

Its useful distinctions include:

- Meaningful abstraction versus unsupported claims of depth: concepts should explain a specific
  object or mechanism rather than provide atmosphere.
- Real conceptual distinctions versus mechanical lists or repetitive reversal formulas.
- Analytical long sentences versus translation-like clauses that obscure the actor or argument.
- Preserving an author's supported stance instead of flattening a critical essay into neutral summary.
- Connecting theory to supplied material rather than using theorists' names as decoration.

The stated scope covers philosophy, psychology, social science, cultural criticism, art/film/photo
reviews, exhibition text, and reading notes. It explicitly discourages default use for news,
official or promotional prose, product descriptions, and general popular-science writing.

## Comparison With Current Guidance

The [local Humanizer reference](../../skills/writing/humanizer/SKILL.md) preserves facts, links,
and intended voice and requires reading the authoritative upstream rules before rewriting.
It does not bundle those rules or install another runtime.

For the substantive comparison, the base `blader/humanizer` instructions were read at revision
`9862685f575c65a8247f90369951df1b3416e3d6`, which declares version `3.0.0`. That source already:

- Matches a supplied writing sample or infers voice from the genre; technical, legal, and factual
  writing stays neutral, while essays retain opinions and uncertainty.
- Requires supported claims to survive and prohibits invented facts, names, numbers, dates, quotes,
  and citations. Missing detail calls for a question or a simpler sentence, not fabrication.
- Keeps meaningful contrasts and necessary lists; it does not treat every formal word or long
  sentence as an automatic defect.
- Separates pasted-text, file, and embedded output modes, keeping only final prose in authored files.

[Harness documentation](../../skills/planning/harness-doc/references/workflow.md#humanizer-pass)
adds a neutral technical voice, frozen headings/anchors, preservation of facts and qualifications,
and post-edit validation of evidence, links, terms, and diagrams. Its requirements are deliberately
different from the candidate's complete-essay rewrite and three-part conversational output.

The candidate adds Chinese critical-writing examples and emphasis. The sources overlap in general
editing principles, but this comparison did not validate equivalent Chinese-language performance.
The user subsequently chose a separate reference-only entry, described below.

## Risks and Limits

- **Unclear redistribution rights:** Public repository access does not grant a license to copy or
  redistribute the bundle. Clarify the author's terms before a later import or adaptation of its text.
- **Genre mismatch:** Preserving a critic's strong judgments can be appropriate for an essay and
  inappropriate for an operational guide. Language alone is not enough to select this skill.
- **Unsupported specificity:** Some before/after examples introduce scene details not supplied in
  the quoted original. In real nonfiction editing, concrete details require source evidence or
  author input; making prose vivid must not manufacture observations or strengthen unsupported claims.
- **Output and structure changes:** The default diagnosis/rewrite/explanation format and permission
  to rewrite paragraphs are not suitable substitutes for a final-prose-only pass with stable technical
  headings. Its suggested diagnosis count is guidance, not evidence that every input has that many flaws.
- **Host-dependent maintenance:** The validator wrapper requires Python and an existing Codex system
  `skill-creator` validator under `CODEX_HOME` or the home-directory fallback. That validator is not
  bundled here. The metadata regenerator overwrites fixed UI fields in the skill directory. The CMD
  wrappers request PowerShell `ExecutionPolicy Bypass`; do not adopt that as permission to evade host
  restrictions. None of these maintenance commands was run.
- **No quality or authorship guarantee:** Structural validation does not establish better prose,
  factual fidelity, or human authorship. Style patterns are editing cues, not reliable proof of who
  wrote a passage; legitimate academic terminology and rhetorical choices need contextual judgment.

## Existing-Skill Improvements

No additional rewriting rules were justified by the source comparison. Genre-aware voice, source
fidelity, meaningful rhetorical structure, and technical-document safeguards already exist. This
is not evidence that either workflow has been tested on Chinese documents.

The reference entry remains a scoped specialization, not an automatic replacement or a copied
word blacklist. Its reciprocal overlap note changes navigation, not the general editor's behavior.

## Reference Entry Added

The user approved option 2: an original SkillVault reference at
[humanizer-ch](../../skills/writing/humanizer-ch/SKILL.md). Delivery is repository-only: the source
bundle and catalog entry are retained, and the global copy was removed at the user's request.
It links to the exact upstream and records the reviewed revision. Unknown authorship,
version, and licensing remain `null` in its manifest; wzlwit maintains the original reference text.
No upstream rewriting rules, examples, scripts, or Codex UI files were copied.

The entry includes an original Chinese invocation example, requires reading the selected upstream
instructions before an authorized rewrite, and preserves project/file permissions and genre limits.
The existing Humanizer reference declares the overlap. `harness-doc` retains its current dependency
and technical-preservation workflow; no automatic Chinese-language substitution was introduced.

Four focused instruction/metadata contracts passed, including reference-only packaging, unknown
rights, reciprocal descriptions, global defaults, and the unchanged documentation dependency.
Catalog/resource validation passed for 38 public skills and 30 project-installed copies. A read-only
review found no blocking reference-scope issue. These checks do not constitute a Chinese rewriting
benchmark or installation of the upstream package.

## Verification and Reconsideration

Read the complete candidate tree, instructions, README, UI metadata, and maintenance wrappers,
plus the installed/source Humanizer reference, pinned base Humanizer instructions, and installed
documentation workflow. No candidate rewrite, validator, metadata generator, installation, or
publishing action was executed during evaluation. The later reference-entry creation above does
not copy or execute that package.

Reconsider importing upstream only after licensing is explicit and the intended use warrants it. A
focused trial should preserve an existing argument and its necessary terminology, avoid adding
unprovided evidence to a vague passage, and leave a technical guide in its required register and
output format. Report such a trial separately from this source review.

## Sources

- [Pinned candidate instructions](https://github.com/zjqc/humanizer-ch/blob/ae195e61e90b97d32aca683382c5732608b17fb1/SKILL.md)
- [Candidate README](https://github.com/zjqc/humanizer-ch/blob/ae195e61e90b97d32aca683382c5732608b17fb1/README.md)
- [Complete candidate tree](https://github.com/zjqc/humanizer-ch/tree/ae195e61e90b97d32aca683382c5732608b17fb1)
- [Codex UI metadata](https://github.com/zjqc/humanizer-ch/blob/ae195e61e90b97d32aca683382c5732608b17fb1/agents/openai.yaml)
- [Validation helper](https://github.com/zjqc/humanizer-ch/blob/ae195e61e90b97d32aca683382c5732608b17fb1/scripts/validate-skill.ps1)
- [Metadata generator](https://github.com/zjqc/humanizer-ch/blob/ae195e61e90b97d32aca683382c5732608b17fb1/scripts/regenerate-openai-yaml.ps1)
- [Base Humanizer 3.0.0](https://github.com/blader/humanizer/blob/9862685f575c65a8247f90369951df1b3416e3d6/SKILL.md)