# Feature doc-set template

Use this outline for a full set. Adapt lifecycle names and deep topics to the actual feature.
For a focused update, reuse the existing pages instead of generating the whole outline. Do not
write empty pages just to reach a count, rename a working set to impose numbering, or invent a
legacy path, lifecycle event, contact, or operational step.

| Default page | Reader purpose and content |
| --- | --- |
| `README.md` | Audience, short old/new comparison when applicable, big-picture and end-to-end diagrams, start-here table by role, verified example packages, and help/escalation route |
| `01-why-<feature>.md` | Problem and rationale, comparison by area with Improvement/trade-offs, onboarding differences, evidenced legacy maintenance costs and continued support, remaining gaps, what did not change, and required steps |
| `02-concepts-and-terms.md` | Glossary, first-use abbreviation expansions or evidenced descriptions, and mappings from terms to actual fields/files |
| `03-how-it-works.md` | Each actual lifecycle event with a diagram, owning components, state/config inputs, outcomes, and relevant old/new comparison |
| `04-onboarding.md` | Prerequisites, roles, details to supply, numbered required steps, verified opt-outs, a trimmed real configuration example, expected validation results, and common mistakes |
| `05-<deep-topic>.md` | A feature-specific difficult behavior with decision tables, limitations, and maintainer guidance; split only when useful |
| `06-troubleshooting.md` | Symptom-to-cause/evidence table, decision trees, preferred fix versus one-off repair, operational approval boundaries, and escalation evidence |

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

- Assume a reader lands directly on any page. Give enough context and define abbreviations on
  first use there, including in tables and diagrams. Link the glossary without relying on it
  to repair unexplained terms. An unknown expansion stays a reviewer question.
- Explain behavior with source-backed diagrams and text. Overview, actual lifecycles, onboarding
  transitions, and troubleshooting branches are useful diagram locations. Compare workflows
  side by side when the supported renderer keeps both readable; otherwise use separate diagrams.
- Keep the rationale page's full comparison as the reference. Repeat only the differences needed
  to understand another page. Glossary and troubleshooting pages do not need a generic comparison
  table, and first-version features do not need an invented old implementation.
- Cite current files, symbols, configuration, package examples, and verified history where they
  support a claim. Use references the audience may access; do not leak a private evidence ledger.
- Keep limitations and unchanged behavior visible. If a feature cannot meet an onboarding or
  repair requirement yet, say so rather than turning a proposal into an instruction.
- Link Previous/Next and the overview using the actual page order. At the boundaries, omit the
  nonexistent direction. Update the existing parent index when the new set needs an entry.

## Evidence examples

Use a verified feature-specific example to show the cost of a supported legacy approach. Explain
the actual repeated work and its impact before giving PR references or counts. Hard-coded IDs,
conditional branches, hidden flags, coordinated releases, and growing source files are possible
costs to investigate, not findings to copy into every set.

For a configuration example, include the minimum real fields needed to explain the behavior,
identify its source/revision, and redact secrets and inaccessible identifiers. Label altered values
as illustrative. Do not imply that a trimmed example is production-ready or independently tested.