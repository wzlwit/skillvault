# Feature doc-set template

Use this outline for a full set. Its rows are page roles, not a page count: use the fewest pages
that serve different readers, merge roles that share a reader, and adapt lifecycle names and deep
topics to the feature. For a focused update, reuse the existing pages instead of generating the
whole outline. Do not write empty pages just to reach a count, rename a working set to impose
numbering, or invent a legacy path, lifecycle event, contact, or operational step.

| Default page | Reader purpose and content |
| --- | --- |
| `README.md` | The whole picture on one page: key points first, then the big-picture diagram, status and timeline, one "where to go" table by role, a short old/new comparison when applicable, verified example packages, and the help/escalation route |
| `01-why-<feature>.md` | Problem and rationale, comparison by area with Improvement/trade-offs, onboarding differences, evidenced legacy maintenance costs and continued support, remaining gaps, what did not change, and required steps |
| `02-concepts-and-terms.md` | Only when many terms are shared across pages: expansions or evidenced descriptions mapped to actual fields/files. Otherwise put a short Terms table at the end of how-it-works |
| `03-how-it-works.md` | Each actual lifecycle event, with a diagram when it adds information, owning components, state/config inputs, outcomes, and relevant old/new comparison |
| `04-onboarding.md` | The onboarding owner's checklist: prerequisites, who does what, details to supply, numbered required steps, verified opt-outs, a trimmed real configuration example, expected validation results, and the owner's common mistakes |
| `05-<deep-topic>.md` | A feature-specific difficult behavior with decision tables, limitations, and maintainer guidance; split only when useful |
| `06-troubleshooting.md` | Operator procedures such as fallback, a symptom-to-cause/evidence table, decision trees, preferred fix versus one-off repair, operational approval boundaries, and escalation evidence |

The machine-readable example describes the default outline for tests and tooling. It is not a
second task store or a required file in the target repository:

```json
{
  "pages": [
    { "file": "README.md", "purpose": "overview" },
    { "file": "01-why-<feature>.md", "purpose": "rationale" },
    { "file": "02-concepts-and-terms.md", "purpose": "glossary" },
    { "file": "03-how-it-works.md", "purpose": "lifecycle" },
    { "file": "04-onboarding.md", "purpose": "onboarding" },
    { "file": "05-<deep-topic>.md", "purpose": "deep-topic" },
    { "file": "06-troubleshooting.md", "purpose": "troubleshooting" }
  ]
}
```

## Page-level rules

These page and diagram rules are the baseline, not hard limits. Small, justified exceptions are
fine, such as a page somewhat over its length budget; state them in the report.

- Give each page one reader and one job, as listed above. Onboarding is the owner's checklist;
  operator steps such as fallback stay in the TSG, and each page links to the other.
- Give each table, procedure, rule, and example one owning page, and search the set before adding
  a section. State each rule once, in a decision table where possible, and link to it from steps
  and other pages with at most a one-line summary. The rationale page owns the full old/new
  comparison; other pages show only the differences their reader needs, and a first-version
  feature needs no invented old implementation.
- Link an existing authoritative procedure. If readers need it on the page, quote it as written
  with its source and add short context notes; do not rewrite it.
- Assume a reader lands directly on any page: give one or two sentences of background and link the
  owning pages. Spell out each abbreviation where it first appears on the page, including tables
  and diagram labels, not in a separate abbreviations list. An unknown expansion gets an evidenced
  description and stays a reviewer question.
- Use the names readers know; show IDs such as GUIDs or module names only where a step needs them.
  Put long reference material, such as command lists, in collapsible `<details>` blocks when the
  target renderer supports them, and keep the most-used items visible.
- Give each page a length budget in the outline, such as about two screens for a checklist. Meet it
  by removing repeated or misplaced content first.
- Mark time-sensitive facts, such as status tables and counts, with the commit or date they reflect
  and how to refresh them. Name the change that must update them, including the change that
  retires the feature and the guide.
- Cite current files, symbols, configuration, package examples, and verified history where they
  support a claim. Use references the audience may access; do not leak a private evidence ledger.
- Keep limitations and unchanged behavior visible. If a feature cannot meet an onboarding or
  repair requirement yet, say so rather than turning a proposal into an instruction.
- Link Previous/Next and the overview in page order, omitting the missing direction at either end.
  Add the set to the existing parent index with one sentence in the style of its neighbors, next to
  related guides.

## Diagram rules

- Add a diagram only when it shows what text cannot, such as branches, parallel paths, or component
  structure. A linear sequence stays a numbered list; a branching decision tree is fine.
- Draw one diagram per question: keep stage flow and decision logic apart. Draw parallel flows as
  side-by-side columns with the same stage names, when the renderer keeps them readable.
- Make each diagram read in one direction without crossing arrows. Group steps in bands by actor or
  phase, and number the steps to match the text.
- Label who acts and when: name the actor ("the pipeline that starts the job") instead of vague time
  words such as "every run" or "one-time", and put timing on the arrow it describes.
- Draw each decision in the component that actually makes it, as verified in the code.

## Evidence examples

Use a verified feature-specific example to show the cost of a supported legacy approach. Explain
the actual repeated work and its impact before giving PR references or counts. Hard-coded IDs,
conditional branches, hidden flags, coordinated releases, and growing source files are possible
costs to investigate, not findings to copy into every set.

For a configuration example, include the minimum real fields needed to explain the behavior,
identify its source/revision, and redact secrets and inaccessible identifiers. Label altered values
as illustrative. Do not imply that a trimmed example is production-ready or independently tested.