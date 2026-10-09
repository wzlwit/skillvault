---
name: rules
description: "[apply|upsert|remove] Put the core and extra rules, or only the four core rules with /rules core, into effect globally (default), in a project, or for this chat; add or change your own global or project rules. The SkillVault rule library changes only when you name extra or core, and persistent rule changes require confirmation."
metadata:
  author: wzlwit
  version: "3.0.0"
argument-hint: "[list|apply|upsert|remove] [<arguments>...]"
---

# Rules

Route by the first subcommand or an unambiguous natural-language request, such as "add a rule: ...".
No arguments or `list` shows the core and extra rules, the actions, and where they are applied
without changing files; `show`, `status`, and `help` are
read-only aliases, `core` aliases `apply core`, and `add`, `update`, and `modify` alias `upsert`. Unknown keywords show help and never approve a rule.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Load only this guidance |
| --- | --- |
| `apply [core] [global\|project\|session]` | Put the [core rules](./references/core.md) and [extra rules](./references/extra.md), or only the core rules with `core`, into effect: `global` (default), `project`, or `session` |
| `list` | Show the core and extra rules, the actions, and the global and current project status from the read-only [always-on helper](./scripts/always-on.ps1) check, without changing anything |
| `upsert`, `remove` | [Rule management](./references/manage.md): your own rules, `global` (default) or `project`; the SkillVault library only when you say `extra` or `core`; confirmed edits only |

- **The library** is the four core rules in [core.md](./references/core.md) and the extra rules in
  [extra.md](./references/extra.md), one bullet each, in the public SkillVault repository; load the
  [detailed reference](./references/ai-principles.md) only for clarification. `apply`, `upsert`, and
  `remove` never change the library unless the user names `extra` or `core`.
- **Scopes.** `global` is a generated block at the top of `~/.copilot/copilot-instructions.md`, which
  Copilot Agent Host and CLI sessions load in every chat on this machine; the private Personal rules
  section follows it. `project` is the same block at the top of the current project's
  `.github/copilot-instructions.md`, followed by its Project rules; that file is usually committed and
  shared with the team. `session` applies the rules to the current chat without editing files.
- **Applying.** For `global` or `project`, run the [always-on helper](./scripts/always-on.ps1) with
  `-Scope`, `-Set all` or `-Set core`, and `-Apply`, then report the target, set, and status. An
  explicit `/rules apply` or `/rules core` approves rewriting that generated block, which records its
  set so later repairs keep it; nothing outside the block changes. Without `-Apply` the helper only
  reports Missing, Unmanaged, InSync, or Drifted. Never hand-edit the block, and installing the skill
  alone writes nothing.
- **Other skills.** When another skill says to apply `/rules apply`, it means `session`: follow the
  core and extra rules in that work. It never writes files. Harness coordinators still pass core
  guidance and project instructions to workers, not the rule-editing workflow.
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