---
name: pr-publish
description: "[list] Alone: publish this branch's PR. Text: adjust it, like show me first. Commit working changes in grouped commits after one question, push, and create or update your own pull request with a current vs. to-be scenario table. A new PR gets a short description in the style of the GitHub Pull Requests extension's create-pull-request skill and opens ready for review; an existing PR keeps its description and gets only the table. Overlaps with that skill on opening PRs and uses its VS Code tool when available, otherwise gh; pr-review reviews PRs instead. Never force-pushes without approval."
metadata:
  author: wzlwit
  version: "4.0.0"
argument-hint: "[list] [<adjustment or PR>]"
---

# PR Publish

`/pr-publish` takes your work on the current repository and branch to a pull request, on GitHub or
an authenticated GitHub Enterprise host: it commits working changes in grouped commits, pushes the
branch, then creates or updates the PR with a current vs. to-be scenario table. It
writes a new PR's description the way the `create-pull-request` skill does, and owns the table, its
evidence, and the fallbacks when editor tools fail.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | [Publishes](./references/publish.md) the current branch's PR: commits any working changes in grouped commits after one question, pushes, then creates the PR with a short description and the table, or adds or refreshes only the table of an existing PR |
| Text | [Publishes](./references/publish.md) with plain-word adjustments: "show me first", "leave the changes out", "rebase first", "as draft", "ready", "rewrite the description", or a PR URL or number to target |
| `list` | Shows the branch, its PR, and whether its description has the table; writes nothing |

- **Alone** acts at once when everything is committed, because the target is fixed: the current
  branch's PR. Before writing, read the [description rules](./references/description.md) and
  [publishing](./references/publish.md). With working changes, staged, unstaged, or untracked, it
  first plans commits grouped by concern and shows them with any files left out, then asks once; a
  yes commits, pushes, and publishes, and no answer writes nothing. On the base branch, the plan
  moves the work to a new branch. It fetches the base first, and never rebases on its own: when the
  branch is behind, the question also offers **Rebase first**, naming any force push that needs;
  with nothing to commit, it publishes as is and says how far behind the branch is. It writes the
  title, description, and table locally, checks them, and shows them, then publishes. Its report
  names the text uses in one line, then ends with the PR link.
- **Text** adjusts the same run. "show me first" stops after the planned commits, local files,
  checks, and preview, before any commit, push, or remote write. "leave the changes out" publishes
  only what is already committed and leaves the working changes alone. "rebase first" rebases onto
  the latest base before pushing, asking once only when that needs a force push; a conflict undoes
  the rebase and pushes nothing. "as draft" makes the PR a
  draft (`gh pr ready <number> --undo`), and "ready" marks it ready for review
  (`gh pr ready <number>`). "rewrite the description" also replaces an existing PR's description
  (`-BodyFile`), not just its table. A PR URL or number names the PR to update; it must be the open
  PR of the current branch, or of a local checkout the request names (`-RepositoryPath`).
- **`list`** runs the bundled [helper](./scripts/pr-publish.ps1) with `-Action Status`, then
  `-Action Check` on an open PR's description, and writes nothing.
- The skill takes no options; plain words adjust a run. A new PR opens ready for review unless the
  request says "as draft". An existing PR keeps its description, including GitHub's Copilot summary,
  and its draft state; publishing changes only the table unless the request asks for more.
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
- `/pr-publish` itself is the request for its push and PR writes, unless the request says "show me
  first"; its commits wait for the one question. Commit every working change or list it as left
  out, and never commit secrets, credentials, build output, logs, or temporary files. Force-push only
  with approval of that exact update. Never comment, reply, resolve threads, request reviewers, set
  labels, retarget, or merge.
- After every write, read the PR back and compare it with what was sent. End with the PR link.
