---
name: pr-publish
description: "[preview|upsert] Create or update your own pull request with a current vs. to-be scenario table. A new PR gets a short description in the style of the GitHub Pull Requests extension's create-pull-request skill and opens ready for review; an existing PR keeps its description and gets only the table. Overlaps with that skill on opening PRs and uses its VS Code tool when available, otherwise gh; pr-review reviews PRs instead. Never pushes or writes to a PR without an explicit ask."
metadata:
  author: wzlwit
  version: "2.0.0"
argument-hint: "[list|preview|upsert] [<arguments>...]"
---

# PR Publish

`/pr-publish` creates or updates your own pull request from the current repository and branch, on
GitHub or an authenticated GitHub Enterprise host, and adds a current vs. to-be scenario table. It
writes a new PR's description the way the `create-pull-request` skill does, and owns the table, its
evidence, and the fallbacks when editor tools fail.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Procedure |
| --- | --- |
| `list` | Show the branch, its PR, and whether its description has the table |
| `preview` | [Write the title, description, and table](./references/description.md) locally and check them |
| `upsert` | [Create the PR, or add or refresh its table](./references/publish.md) |

- Bare invocation or `list` runs the bundled [helper](./scripts/pr-publish.ps1) with
  `-Action Status`, then `-Action Check` on an open PR's description. It writes nothing. `help` or
  an unknown action shows choices.
- Before `preview` or `upsert`, read the [description rules](./references/description.md). Before
  `upsert`, also read [publishing](./references/publish.md). `upsert` always previews first.
- The actions take no options. A new PR opens ready for review. An existing PR keeps its
  description, including GitHub's Copilot summary, and its draft state; `upsert` changes only the
  table. For anything else, such as a draft, a ready PR, or a rewritten description, ask in plain
  words.
- Requires PowerShell 7, Git, and `gh` signed in to the PR's host. The VS Code tool and the
  `create-pull-request` skill are optional.

## Rules

- Write only from evidence: the diff against the base, the code and tests it changes, and checks
  run on the current head. A search hit locates code; reading it decides a claim. Never claim an
  unrun check or tick a checklist item that wasn't done; give the reason next to an unticked one.
- A new PR's title and description follow the `create-pull-request` skill: a one-sentence summary,
  why, the issue reference, and notable decisions, under the repository's PR template when it has
  one. Keep it short, with no per-file list, checklist, or test evidence section unless the template
  asks. A bug fix or behavior change gets a current vs. to-be scenario table with concrete example
  values and unchanged cases; otherwise write "No behavior change".
- Never make a PR a draft on your own, whatever is pending; list pending items in the description.
- Change existing description text only when the user asks. The helper backs up the current title
  and description before replacing them.
- A remote write needs an explicit ask: `upsert`, or a request such as "push and create a PR".
  Push only when asked; force-push only with approval of that exact update. Never comment, reply,
  resolve threads, request reviewers, set labels, retarget, or merge.
- After every write, read the PR back and compare it with what was sent. End with the PR link.
