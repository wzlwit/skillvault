---
name: harness-doc
description: "Create or update evidence-grounded feature doc sets, onboarding, and troubleshooting guides. Use /harness-doc or /hn-doc with list or upsert. Overlaps with architecture-decision-records on design rationale, harness-comms on stakeholder-facing prose, and the office-documents reference on document output; owns reader-oriented guides, with a final Humanizer pass followed by validation. No harness initialization or publication is implied."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|upsert] [<arguments>...]"
---

# Harness Documentation

`/harness-doc` authors evidence-grounded feature doc sets, onboarding, and troubleshooting guides
directly in the session, without requiring an initialized harness.
`/hn-doc` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Result |
| --- | --- |
| `list` | Show existing documentation sets and available actions within the selected repository; no writing or remote research |
| `upsert` | Create or update a full feature doc set or focused page through the [authoring workflow](references/workflow.md) |

```text
/hn-doc
/hn-doc upsert <feature-or-doc-set> [<focused-request>] [--audience <internal|partner|public>] [--output <path>]
/hn-doc upsert cache-refresh --audience partner
/hn-doc upsert cache-refresh troubleshooting --audience internal
```

- Bare invocation means `list`; `status` and `help` show the same read-only view, and `create` and
  `update` alias `upsert`. These are session instructions, not `harness.ps1` actions; installing or
  explaining the skill writes nothing.
- Use the [page template](references/doc-set.md) for a full set; focused requests update only the
  needed pages and navigation. Reuse existing paths; missing access or ambiguous identity is not
  proof that a set is absent.
- Apply `/rules apply` and project instructions. Reuse an existing approved task when applicable,
  keeping its ownership, pause, repository, and permission controls; never start another writer.
- Reader docs go in the selected coding repository's documentation tree unless an explicit output is
  supplied; harness tracking stays controller-local.
- Ground claims in current code, configuration, accepted designs, and verified history, and label
  implemented, planned, and unverified behavior. Read owning sections and functions; keywords only
  locate evidence. Run `humanizer` as the final prose pass, then validate. Missing guidance or checks
  leaves a Draft, never a silent skip or a Validated claim.
- `architecture-decision-records` owns decision history; reference its records without rewriting
  their status. `harness-report` owns dashboards and queries, and `handoff` owns continuation notes;
  none is a second implementation of this workflow. `office-documents` links to separate
  PDF/Word/Excel guidance but supplies no renderer or permission to copy its proprietary tools.
- Do not change application behavior, invent expansions or contacts, leak restricted details to a
  broader audience, or publish by implication. Moves, installs, commits, pushes, PRs, and review
  replies need separate authorization. Keep private examples out of the public bundle.