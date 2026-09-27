---
name: harness-doc
description: "Create or update evidence-grounded feature doc sets, onboarding, and troubleshooting guides. Use /harness-doc or /hn-doc with list or upsert. Overlaps with architecture-decision-records on design rationale and the office-documents reference on document output; owns reader-oriented guides, with a final Humanizer pass followed by validation. No harness initialization or publication is implied."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|upsert] [<arguments>...]"
---

# Harness Documentation

The registered command is `/harness-doc`. `/hn-doc` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

| Action | Result |
| --- | --- |
| `list` | Show existing documentation sets and available actions within the selected repository; no writing or remote research |
| `upsert` | Create or update a full feature doc set or focused page through the [authoring workflow](references/workflow.md) |

Bare invocation means `list`. `create` and `update` are aliases for `upsert`; `status` and `help`
show the read-only view. These are session-level instructions, not new `harness.ps1` actions.
Installing or explaining the skill does not write documentation or initialize a controller.

```text
/hn-doc
/hn-doc upsert <feature-or-doc-set> [<focused-request>] [--audience <internal|partner|public>] [--output <path>]
/hn-doc upsert cache-refresh --audience partner
/hn-doc upsert cache-refresh troubleshooting --audience internal
```

Use this for a systematic doc set, partner onboarding, a troubleshooting guide (TSG), or an
explanation of why a design changed. Use the [page template](references/doc-set.md) for a full set;
focused requests update only needed pages and navigation. Reuse existing paths rather than
creating a second set. Missing access or ambiguous identity is not proof that a set is absent.

Apply `/rules apply` and project instructions. Author directly in the session without requiring
an initialized harness. Reuse an existing approved task when applicable, retaining ownership,
pause, repository, and permission controls. Never start another writer or bypass a paused task.
Reader documentation belongs in the selected coding repository's documentation tree unless an
explicit output is supplied; harness tracking remains controller-local.

Ground claims in current code, configuration, accepted designs, and verified history. Distinguish
implemented, planned, and unverified behavior. Read owning sections and functions; keywords only
locate evidence. Explain genuine old/new differences and trade-offs without inventing a predecessor.
Keep each page understandable on its own, with expanded terms, limitations, and useful diagrams.

Run `humanizer` as the final prose-editing pass, then validate facts, terminology, links, anchors,
diagrams, and style, plus final rendered pages for agreed PDF/DOCX deliverables. Markdown-only
output requires no conversion. Its local reference does not bundle upstream editing rules: fetch and read
the authoritative guidance before rewriting. Preserve technical meaning, headings, anchors, code,
diagram logic, and link targets. Missing guidance or required checks leaves a Draft with the
outstanding work named, never a silent skip or a Validated claim.

`architecture-decision-records` owns accepted decision history and supersession; reference those
records when explaining rationale without rewriting their status. `harness-report` owns dashboards
and queries. `handoff` owns continuation notes. None is a second implementation of this doc workflow.

`office-documents` links to separate PDF/Word/Excel guidance, sharing document-output concerns.
That reference supplies no document renderer or permission to copy its proprietary upstream tools.

Do not change application behavior, invent acronym expansions or contacts, leak restricted source
details to a broader audience, or publish by implication. Documentation moves/restructuring,
dependency installations, rebases, commits, pushes, PR creation, and review replies/resolution need
separate authorization. Keep private examples out of the public skill bundle.