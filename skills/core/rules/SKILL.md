---
name: rules
description: "[apply|upsert|remove] Apply the four core working rules (also /rules core) to the current task without editing files, or manage AI rule documents; persistent rule changes require confirmation."
metadata:
  author: wzlwit
  version: "2.0.0"
argument-hint: "[list|apply|upsert|remove] [<arguments>...]"
---

# Rules

Route by the first subcommand or an unambiguous natural-language request. No arguments or `list`
shows the four core rules, the actions, and the always-on copy's status without changing files;
`show`, `status`, and `help` are
read-only aliases, `core` aliases `apply`, and `add`, `update`, and `modify` alias `upsert`. Unknown keywords show help and never approve a rule.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Load only this guidance |
| --- | --- |
| `apply` (alias `core`) | [Core working rules](./references/core.md), applied to the current task without editing files |
| `list` | Show the four [core working rules](./references/core.md), the actions, and the always-on status from the read-only [always-on helper](./scripts/always-on.ps1) check, without applying or editing anything |
| `upsert`, `remove` | [Rule management](./references/manage.md): your private personal rules by default, the shared core rules only when you say `core`; confirmed edits only |

- The four core rules are maintained once in the bundled reference; load the
  [detailed reference](./references/ai-principles.md) only for clarification.
- **Always on.** `/rules` keeps a generated copy of the four rules at the top of
  `~/.copilot/copilot-instructions.md`, which Copilot Agent Host and CLI sessions load in every chat;
  the private Personal rules section follows it. Never hand-edit the generated block. Run the
  [always-on helper](./scripts/always-on.ps1) without `-Apply` to report Missing, Unmanaged, InSync,
  or Drifted; after a confirmed core change, or when the user confirms creating or repairing the
  copy, rerun it with `-Apply`. It changes nothing outside the block. Installing the skill alone
  writes nothing there. Harness coordinators still pass core guidance and project instructions to
  workers, not the rule-editing workflow.
- **Enforceable limits belong to policy.** A rule the harness can enforce, such as allowed models,
  time or credit caps, reviewer concurrency, test retries, failure thresholds, or pauses, goes to
  `/hn-project policy set limits` or `set fallback` with its matching field. Add a written rule only
  if the user still wants one; a written rule never enforces anything.
- Applying rules grants no tools, permissions, or new work.
- Grilling may propose a reusable rule, but never edits the authoritative rule document, overrides a
  security requirement, or substitutes for tests and independent review. Persistent changes use the
  confirmed management route.
- Lessons from completed work use the same
  [proposal checks](./references/manage.md#lessons-proposed-as-rules): verify cause and scope, test
  for overgeneralization, and keep the approval boundary. This adds no reflection hook and does not
  change the four rules applied to ordinary work.