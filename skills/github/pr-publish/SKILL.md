---
name: pr-publish
description: "Create or update your own pull request: a description that follows the repository template, a current vs. to-be scenario table, tests named for each scenario, and draft or ready state. Use /pr-publish list, preview, or upsert. Opens PRs through the VS Code create-pull-request tool when available, otherwise through gh; pr-review reviews PRs instead. Never pushes or writes to a PR without an explicit ask."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|preview|upsert] [<arguments>...]"
---

# PR Publish

`/pr-publish` creates or updates your own pull request from the current repository and branch,
on GitHub or an authenticated GitHub Enterprise host. It owns the description's content and
evidence, the draft or ready state, and the fallbacks when editor tools fail.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Procedure |
| --- | --- |
| `list` | Show the branch, its PR, and gaps in that PR's description |
| `preview` | [Write the title and description](./references/description.md) to a local file and check it |
| `upsert` | [Create the PR, or update its title, description, or draft state](./references/publish.md) |

- Bare invocation or `list` runs the bundled [helper](./scripts/pr-publish.ps1) with
  `-Action Status`, then `-Action Check` on an open PR's description. It writes nothing. `help` or
  an unknown action shows choices.
- Before `preview` or `upsert`, read the [description rules](./references/description.md). Before
  `upsert`, also read [publishing](./references/publish.md). `upsert` always previews first.
- `upsert --draft` opens the PR as a draft or converts an open PR to draft; `upsert --ready` marks
  it ready for review. Otherwise a new PR opens ready for review and an existing PR keeps its state.
- Requires PowerShell 7, Git, and `gh` signed in to the PR's host. The VS Code tool is optional.

## Rules

- Write only from evidence: the diff against the base, the code and tests it changes, and checks
  run on the current head. A search hit locates code; reading it decides a claim. Never claim an
  unrun check or tick a checklist item that wasn't done; give the reason next to an unticked one.
- The repository's PR template decides the sections and their order. A bug fix or behavior change
  gets a current vs. to-be scenario table with concrete example values and unchanged cases, and
  names the tests for each row; otherwise write "No behavior change".
- In an existing description, keep link targets, issue references, and code. The helper backs up
  the current title and description before replacing them.
- A remote write needs an explicit ask: `upsert`, or a request such as "push and create a PR".
  Push only when asked; force-push only with approval of that exact update. Never comment, reply,
  resolve threads, request reviewers, set labels, retarget, or merge.
- After every write, read the PR back and compare it with what was sent. End with the PR link.
