---
name: harness-review
description: "[broad|list] Alone: review your changes. Text: review that scope. Review current-project changes for blocking issues with two independent reviewers per pass, GPT and Claude Opus, plus a whole-repository Fresh pass when no new findings appear, restarting when local files change; broad also reports minor and existing issues. Shorthand: /hn-review. Overlaps with pr-review on general review, differential-review on security, and harness-dev, whose development loop runs the same passes; PR URLs delegate to pr-review."
metadata:
  author: wzlwit
  version: "4.0.0"
argument-hint: "[broad|list] [<scope>]"
---

# Harness Review

`/harness-review` reviews current-project changes with two independent reviewers per pass and adds a
whole-repository Fresh pass when no new findings appear. PR URLs delegate to `pr-review`.
`/hn-review` is chat shorthand for the same topic, not a separate skill or folder.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | [Reviews](./references/workflow.md) the current changes now, ahead commits plus working changes, at the `blocking` level |
| Text | [Reviews](./references/workflow.md) that scope at `blocking`: a folder or file, a commit range such as "since main", a task ID, or "security"; a PR URL goes to `pr-review` |
| `broad [<scope>]` | [Reviews](./references/workflow.md) at the `broad` level, which also reports minor and existing issues and audits the whole repository |
| `list` | Shows past review results; starts nothing |

- **Alone** acts at once, because the target is fixed: committed work ahead of the comparison branch
  plus staged, unstaged, and untracked changes, at `blocking`, with two reviewers per pass. The loop
  runs until nothing more is found. Its report ends with one line naming the text uses: a folder,
  file, commit range, task ID, or "security" to review that scope, or a PR URL.
- **Text** follows the same [review procedure](./references/workflow.md) at `blocking`. A folder or
  file guides the reviewers (`-Scope`). "since <ref>" sets the comparison base (`-BaseRef`), and
  "since HEAD" reviews only working changes. A task ID names that task as the scope and reviews its
  bound coding repository when it has one; a registered repository ID such as `R-001` selects that
  repository (`-RepositoryRef`). "security" adds the security methodology to the same passes
  (`-SecurityReview`). Words combine, as in "security since main". A PR URL loads `pr-review` with
  the same level and security request.
- **`broad`** maps to `-ReviewLevel broad` for the current changes or the scope that follows it.
  `blocking` reports only what blocks merging the change or completing its task, and its Full pass
  looks only for what the change breaks elsewhere. `broad` reports every issue with evidence,
  including minor and pre-existing ones, and its Full pass audits the whole repository. Either level
  keeps the loop going until it finds nothing more; Review Levels in the runtime guide defines both.
- **`list`** shows past review results, newest first, from the board's run history and linked
  reports, without launching a reviewer.
- Apply `/rules apply` and project instructions, then the `harness-runtime` guide's Script Permissions and
  Agent Fallback, Runner Inheritance, and Reuse or New procedures.
- The coordinator repeats Changes -> Full until no supported unfixed issues remain: findings go
  through the existing dev/proposal workflow, and review resumes after fixes without a new request.
  Only a stable clean round with no outstanding issues completes the request; unavailable fixes,
  access, or validation leave it pending or blocked.
- Keep snapshots, read-only permissions, and up to two passes per snapshot. Inadequate coverage is
  blocked, not clean. Local edits restart review up to twice; continued edits return `Partial`.
- Each pass has two independent read-only reviewers: the strongest allowed GPT and Claude Opus
  models from the bundled default list (or approved runner-context profiles), now `gpt-6-astra` and
  `claude-opus-5.5`, at `max` effort or the highest the CLI accepts, running at the same time unless
  `maxParallelReviewers` is 1. The session's or project's own model never replaces them. When the
  session runs the reviewers as its own sub-agents, it sets each one's model and `max` effort
  explicitly instead of leaving the host's default. It starts them in the background as read-only
  general-purpose agents, never the Code Review agent type, whose launch switches the whole chat so
  that switching back stops every running agent. It then ends its turn and reads each result as it
  arrives, so it can answer the user meanwhile. `/harness-setup policy list limits` lists the
  models; `allowedModels` narrows them. Unavailable models are skipped at no cost. A pass is clean
  only when both are clean and blocked when either is.
  With one usable family, or `runner.secondReviewer: false`, one reviewer runs and the result says
  so. PR review keeps its single approved profile.
- Security guidance joins the same passes, not an extra pass. Existing budgets, limits, and
  pause/stop requests apply; no permissions are added. Do not add a fixer or busy-loop on unchanged code.
- Use `/grilling` in the attended coordinator only for a consequential design or risk choice;
  workers never launch interviews, and grilling never replaces independent review.
