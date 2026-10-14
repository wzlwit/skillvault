---
name: skillvault-discover
description: "[explain] Alone: past evaluations. Text: search or evaluate it. Discover skills for a purpose, evaluate a candidate against the catalog and earlier evaluations, and explain skills, tools, or products. Shorthand: /sv-discover. Evaluation saves a public-safe assessment unless chat only; search and explanation are read-only. None installs, runs, or edits the target."
metadata:
  author: wzlwit
  version: "4.0.0"
argument-hint: "[explain] [<purpose, URL, or skill>]"
---

# SkillVault Discover

`/skillvault-discover` finds, evaluates, and explains skills, tools, and products without installing,
running, or editing them. Search and explanation are read-only; evaluation writes only its
public-safe record.
`/sv-discover` is chat shorthand for the same topic, not a separate skill or folder.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | Show past evaluations from `docs/evaluations/` and ask what to look for |
| Text | A purpose [searches](./references/search.md), then offers to evaluate the best match; a URL or one skill name is [evaluated](./references/evaluate.md) |
| `explain <skill, tool, or product>` | [Explain it, read-only](./references/explain.md) |

- Alone shows the past evaluations in `docs/evaluations/` of the verified SkillVault checkout,
  resolved as for the [evaluation record](./references/evaluate.md#evaluation-record): each
  candidate, its verdict, its date, and whether it may be stale, judged from its date and its
  reconsider condition. It searches no remote source, then asks what to look for; no answer
  changes nothing.
- The alone view ends with one line naming the text uses: a purpose searches, and a URL or skill
  name is evaluated.
- Text decides the procedure. A purpose or capability searches in the
  [search order](./references/search.md#search-order), then offers to evaluate the best match,
  asking once. A URL or the name of one skill is evaluated, which saves a public-safe record under
  `docs/evaluations/` unless the request says "chat only". Input that could be either searches,
  since search saves nothing, and offers to evaluate.
- Load only the selected procedure. Evaluation reuses verified search evidence and also
  [proposes improvements to existing skills](./references/evaluate.md#improve-existing-skills);
  implementing them needs the user's approval.
- Installation belongs to `/skillvault-install` and authoring to `/skillvault-author`.
  Preserve source verification, attribution, reference-only limits, and explicit approval for either handoff.
