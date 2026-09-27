# Documentation authoring workflow

Create reader-facing documentation from verified source evidence. This procedure supports a
complete feature set and a focused update. It does not add a runtime action, renderer, task store,
documentation server, or publishing pipeline.

## Resolve the request

1. Reuse the feature, old/new scope, requested pages, audience, evidence sources, required feedback,
   and destination already supplied. Inspect checkable repository facts yourself. Ask only for
   unresolved choices that affect the deliverable. A new feature may have no legacy implementation.
2. Resolve the coding repository from an explicit target or the existing task's verified binding;
   otherwise use the working project. Reuse the selected harness Root for tracking when applicable,
   without changing it or initializing a controller. A controller with several repository links is
   not permission to select the first one; resolve the requested documentation target.
3. Inspect existing entrypoints, guides, design records, and navigation. Match the actual feature
   and purpose before creating a set. Preserve unrelated text and stable paths. An inaccessible or
   ambiguous location requires clarification, not a duplicate folder.
4. Choose internal, authorized partner, or public readers. Outside the owning team does not mean
   public. Reuse a clear established audience; otherwise ask. Include only details and links
   suitable for those readers. Keep any necessary restricted traceability in an approved private
   location, not in public notes or the reusable skill. Do not upload source text to a public service.
5. Honor an explicit output path first, then the coding repository's established documentation
   location. Discover and reuse `doc/`, `docs/`, or a configured root. If both exist, inspect README
   links and configuration; ask only if still ambiguous. With no location convention, use
   `docs/guides/<feature>/`. Creating a guide does not authorize restructuring existing docs.
6. For a full set, adapt the [page template](doc-set.md). For onboarding, a troubleshooting guide
   (TSG), or another focused
   request, change only the relevant pages and navigation. Outline pages, headings, comparison
   tables, and diagrams before drafting. Resolve feedback items to explicit sections and evidence.

## Gather evidence

- Inspect explicit sources first. Otherwise use local sources, configured accessible internal
  sources, then authoritative external sources as needed. Keep private search terms and content
  out of public queries. Supporting sources never expand write permissions or the coding target.
- Read whole governing design sections and current status before explaining a decision. Separate
  accepted rationale, proposed behavior, implemented behavior, and deployment evidence. A design
  is not proof of running code, and code alone is not proof of rollout.
- Follow symbols to owning functions, callers, configuration, package metadata, and relevant tests.
  For related-repository behavior, inspect that repository at the relevant revision. Do not infer
  its contract from a similarly named field in the current repository. Report missing access.
- Check important counts and examples from actual structures instead of estimating. Use Git history
  and PR metadata for verified change examples, with exact repository/revision context. Frame a
  multi-PR migration as an example of maintenance work, not a count presented as its own argument.
- Treat people's statements as leads. Verify a reported fix against its owning implementation and
  revision. Preserve unresolved contradictions as reviewer questions, with the affected claim and
  required evidence. Do not silently choose code, design, or a person as authority for every fact.
- Build a compact working map of claim, source/revision, target section, and confidence. Reuse an
  existing review note if useful; a new durable evidence ledger is not required. Cite actual files,
  symbols, config fields, and relevant PRs in forms the intended reader can access. Never invent
  paths, example packages, parameter values, contact aliases, or abbreviation expansions.
- Unknown essential onboarding or repair behavior blocks that instruction from being marked ready.
  Nonessential unknowns can remain explicit reviewer questions. Distinguish a source limitation
  from an implementation defect; never prescribe a speculative repair as an established fix.

### Check document inputs

For documents and extracted text, compare requested files/sections with those actually read.
Record skipped or unreadable inputs and known omissions in the existing claim/source map; no new
ledger is required. Keep source-plus-section identities with edition/revision when available,
so two sources starting at Chapter 1 do not become one section. Keep restricted source details
in approved private notes, not public documentation.

Use existing approved readers. Check representative content and task-critical tables, code,
formulas, diagrams, and reading order against the original where available. Note the extraction
method or fallback when relevant, OCR uncertainty, missing images, and an unavailable original.
Successful extraction or aggregate counts do not prove complete or faithful coverage; retain
per-source warnings and recheck affected sections before relying on them.

If missing or distorted content could change required instructions, keep the affected guidance
Draft and name the evidence needed. Continue independently supported work without inventing the
missing parts or silently narrowing the requested scope. An explicitly requested subset need not
read unrelated chapters. Reuse already-readable Markdown/text without a conversion dependency;
this check does not authorize installing a parser, running source examples, or uploading documents.

## Draft the set

Write the overview and rationale first, then concepts, behavior, onboarding, deeper topics, and
troubleshooting. For focused work, preserve the rest of the set. Start diagrams early to check the
workflow, then explain them in plain text; diagrams do not replace actionable instructions.

Compare old and new only when there is a real change. Use a short overview comparison, a full
rationale comparison, and per-lifecycle/onboarding comparisons where useful. An Improvement column
must state an evidenced benefit or trade-off, including unchanged or worse behavior. Glossary and
TSG pages need comparisons only where they help. A first-version feature explains the problem and
alternatives without inventing a legacy path.

Explain remaining gaps and what did not change. Where a legacy path remains supported, state when
it is appropriate and use a verified example to explain its maintenance cost. Do not claim every
legacy system has hard-coded IDs, hidden flags, branch proliferation, or release-per-change costs;
include only costs established by this feature's evidence.

For onboarding, name prerequisites, who owns each step, inputs/configuration, required steps,
verified opt-outs, validation, and expected results. Distinguish preferred fixes from one-off
repairs in the TSG. Repairs that change live state still require their normal approval; documenting
a command does not authorize running it. Trim real examples to the relevant fields and remove secrets.

Expand abbreviations on first use on every page, including tables and diagram labels. If an
expansion is unknown, use an evidenced description and record the open question; do not make one up.
Add Previous/Next navigation within the actual set, plus an overview link. First/last pages link
only to pages that exist. Preserve discoverability from the established documentation index.

## Humanizer pass

This is the final editing phase, not the final validation phase.

1. Read the available `humanizer` skill. The curated SkillVault entry is reference-only; fetch and
   read its authoritative upstream guidance before rewriting. Fetching guidance does not mean
   sending private documents to that source. Do not install an upstream package implicitly.
2. Apply its embedded/file workflow to the requested prose only. Keep a neutral technical voice
   suitable for the audience and preserve the user's supported writing preferences. Remove empty
   slogans, staged contrasts, decorative emphasis, repeated closers, and em-dash prose. Genuine
   old/new comparisons remain because they carry required information.
3. Freeze headings and explicit anchors before this pass. Preserve facts, qualifications, required
   steps, warnings, code fences, inline code, commands, paths, frontmatter, data, link targets,
   and diagram logic. Style guidance never overrides technical accuracy, accepted scope, or
   security/audience boundaries. Bold can identify glossary terms, labels, and table keys when useful.
4. Compare the rewrite with the factual draft. Check that it neither added an unsupported claim
   nor lost a caveat, requirement, contact uncertainty, or limitation. Return only the final prose
   in reader docs, not Humanizer's drafting commentary.
5. If guidance is unavailable, finish only supported draft work and report the missing pass.
   Do not describe the result as humanized or fully validated. A later substantive edit repeats
   the affected style and validation checks; it does not require rewriting unrelated pages.

## Validate and deliver

Run checks after Humanizer. Reuse repository tools and pinned versions where suitable. If tools
are missing, obtain approval before installing dependencies; unpinned `npx -y` downloads are not
an automatic part of authoring. State exactly which checks ran and which remain outstanding.

| Check | Required evidence |
| --- | --- |
| Facts and feedback | Recheck implementation/design/revision claims, required steps, examples, old/new statements, gaps, and the requested feedback sections |
| Links and anchors | Parse changed Markdown and affected inbound links with the target renderer's heading/anchor behavior; cover duplicate headings, explicit IDs, encoded paths, fragments, reference links, images, and folder trailing slashes |
| Terminology | Check first use per page, including tables/diagrams; flag unresolved expansions instead of guessing them |
| Diagrams | Render every Mermaid block in changed pages with a compatible renderer, then inspect legibility, labels, and flow against evidence; verify the intended viewer when its engine differs |
| Paginated output | For requested PDF/DOCX deliverables, inspect final rendered pages for readable content, pagination, and required-language glyphs |
| Prose and navigation | Scan changed prose for em dashes and filler, verify audience suitability and Previous/Next/overview links, and preserve fenced technical content |
| Diff hygiene | Review changed-file scope and run `git diff --check` and `git diff --cached --check` when Git is available |

When PDF/DOCX is an agreed deliverable, inspect all final rendered pages after Humanizer and any
layout-affecting edits. Check clipping, page breaks, split tables, captions, headers/footers, and
font/glyph coverage for the required languages, including mixed-language text where relevant.
Opening the file or passing XML validation does not prove readable pagination. Keep the requested
format and template constraints; record defects and recheck the affected output after correction.

Use only available, authorized renderers. Missing rendering or unresolved page defects keeps the
artifact Draft with the incomplete check named; do not install software or substitute another
format without approval. Markdown-only output requires no Word/PDF conversion. This conditional
check does not add a document renderer or alter the existing post-Humanizer validation order.

A lowercase-and-strip regex is not a general anchor checker. Use the repository or platform's
Markdown parser/slugger, and check its behavior on a known valid heading and duplicate heading
before trusting a new checker. Report pre-existing broken links separately; do not silently fix
unrelated defects or make an all-repository validation claim from a changed-file check.

For Mermaid, prefer the intended viewer's supported dialect and existing configuration. A CLI
render with a newer engine does not prove an older editor preview works. Preserve diagram-specific
entity syntax until tested; do not mechanically replace `#lt;` with `&lt;` or the reverse. Render to
an owned temporary directory and delete only that run's output afterward. If rendering is unavailable,
report it as unverified rather than calling a syntax scan a successful render.

Deliver the exact doc-set/page location, full-versus-focused scope, audience, source revisions,
checks and results, and unresolved questions. A short report is sufficient; do not create a new
status register. Use these outcomes consistently:

| Outcome | Meaning |
| --- | --- |
| Draft | Files exist, but essential evidence, Humanizer, or required validation is incomplete; identify affected sections/checks |
| Validated | The requested scope, factual review, Humanizer pass, and required checks all passed; publication is still separate |
| Published | A separately authorized publication completed and its exact destination was verified |

## Optional restructuring and publication

Only after an explicit move/restructure request, map old paths to new paths and preview the scope.
Reuse the documentation root; `guides/`, `design/`, and `plans/` are useful categories, not mandatory
new folders. Inspect every path consumer before moving: scripts, CI, code comments, instruction
files, indexes, links, and existing bookmarks/anchors. Preserve paths that automation depends on
unless changing those consumers was also approved. Use tracked renames when appropriate and a
reviewed mechanical tool for repetitive link changes, preserving folder trailing slashes. Touch
code only for necessary path comments in this approved scope, never application behavior.

Rebase, commit, push, PR creation, remote review replies, and thread resolution are separate actions.
Do not perform them merely because authoring or validation finished. When publication is requested,
use the owning Git/PR workflow and repository template. After an authorized rebase or source update,
recheck affected facts, versions, package existence, links, and diagrams against the new revision.
Test review suggestions before accepting them, especially markup/diagram changes. Missing credentials
stay a blocker; never obtain or renew authentication implicitly.