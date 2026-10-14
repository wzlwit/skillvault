---
name: pr-watch
description: "[remove] Alone: the watchlist. Text: watch a URL. Manage the single user-wide PR review watchlist. Watchlist changes do not run reviews or change schedules; pr-review owns execution and review results, and harness-schedule owns its logical schedule."
metadata:
  author: wzlwit
  version: "4.0.0"
argument-hint: "[remove] [<PR or repository URL>]"
---

# PR Watchlist

`/pr-watch` manages the single user-wide PR review watchlist. Watch changes never run reviews or
change schedules.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | [Shows the watchlist](./references/list.md): targets, filters, and W- IDs |
| Text | [Watches that PR or repository URL](./references/add.md) at once |
| `remove <W-ID or URL>` | [Removes that watch entry](./references/remove.md) after confirmation |

- **Alone** shows each stable W- ID, PR or repository URL, kind, discovery count and draft filter,
  and when it was added (`-Action List`), and changes nothing. It ends with one line: paste a PR or
  repository URL to watch it, or say remove W-002.
- **Text**: an HTTPS PR or repository URL is watched at once (`-Action Add -Url <URL>`). A repository
  entry selects its five most recently updated open, non-draft PRs on each run; plain words change
  the count (`-Limit`, up to 100) or include drafts (`-IncludeDrafts`). An exact PR URL watches that
  PR, including a draft. The same URL again updates only the filters mentioned.
- **`remove`** previews the exact entry, asks for confirmation, then applies it
  (`-Action Remove -Selector <W-ID or URL>`, then `-Apply`).
- Review results, including ad-hoc and in-progress reviews, belong to `/pr-review list`.
- Use the `pr-review` runtime and its existing user-wide controller, never the working project's
  source or a new project-local list. It works from any folder with no harness Root, harness setup,
  or data-root choice. Preserve IDs, explicit filters, reports, and removal confirmations.
- Applying `/rules apply` and project instructions authorizes no provider call, review, timer, or
  publication. Review execution belongs to `/pr-review`; schedules to `harness-schedule`
  (`/harness-schedule pr 1d`).
