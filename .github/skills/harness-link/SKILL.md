---
name: harness-link
description: "Manage all project and task links in one registry. Use /harness-link or /hn-link with list, add, or remove for HTTP/HTTPS URLs, local files, folders, and coding-repository paths. Accepts legacy /harness-ref and /hn-ref. Adding upserts a link; removing unregisters it, never deletes its target. Does not copy sources, clone repositories, or start work."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|add|remove] [<arguments>...]"
---

# Harness Links

`/harness-link` keeps one registry for project and task URLs, files, folders, and coding-repository paths.
`/hn-link` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

- Bare invocation or `list` shows all link types together; `help` and unknown actions list choices.
- `add`, explicit URL/path input, `remove`, and legacy ref commands follow the
  [reference procedure](./references/workflow.md). `add` sets or updates a link and its note under
  one stable ID for the same source/task.
- `remove` unregisters a link after confirmation; it never deletes the target document or repository.
- Preserve explicit repository binding. Apply `/rules apply` and project instructions. A link is
  evidence, not a grant of access, execution, or migration.