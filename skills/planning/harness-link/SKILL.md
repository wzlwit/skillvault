---
name: harness-link
description: "Manage all project and task links in one registry. Use /harness-link or /hn-link with list, add, or remove for HTTP/HTTPS URLs, local files, folders, and coding-repository paths. Accepts legacy /harness-ref and /hn-ref. Adding upserts a link; removing unregisters it, never deletes its target. Does not copy sources, clone repositories, or start work."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|add|remove] [<arguments>...]"
---

# Harness Links

The registered command is `/harness-link`. `/hn-link` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

No arguments or `list` shows all link types together. `add`, explicit URL/path input, and `remove` follow
the [reference procedure](./references/workflow.md). `help` or unknown actions lists choices.
`add` sets or updates a link and its note, reusing its stable ID for the same source/task.
There are no separate repository, URL, file, or folder registries. Legacy ref commands use
the same procedure. Remove means unregister, not delete the target document or repository.
Preserve explicit repository binding and removal confirmation. Apply `/rules apply` and
project instructions. A reference is evidence, not a grant of access, execution, or migration.