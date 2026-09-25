---
name: skillvault-refresh
description: "Refresh managed global latest skill copies one way from recorded Git sources. Use /skillvault-refresh or /sv-refresh list or run; accepts skillvault-fresh, /sv-fresh, /skv-fresh, /skillvault-sync and /sv-sync. Scheduling delegates to harness-timer set refresh. Does not push upstream or update project copies."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|run]"
---

# Skill Refresh

The registered command is `/skillvault-refresh`. `/sv-refresh` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

Bare invocation or `list` inspects existing refresh configuration and shows actions.
It never creates a daily schedule as a side effect. Unknown actions show help.

- `run` uses the [refresh procedure](./references/workflow.md) with `-RunOnce`.
- Legacy `schedule [intervalDays]` delegates to `/harness-timer set refresh`; preserve its
  explicit day value, or the old one-day default for that explicit compatibility request only.
- Legacy fresh/sync commands retain their explicit interval semantics; zero means one run.

The [refresh script](./scripts/skillvault-fresh.ps1) is used with `-RunOnce` by the shared heartbeat.
Its old OS-task creation path is compatibility-only, not a second live scheduling implementation.
`status` and `help` alias `list`. Preserve pins, unrelated installs, recorded
sources, same-scope helpers, and failure isolation. Hidden compatibility bundles require an
explicit installed-copy migration and must be skipped by unattended refresh.

Runtime admission checks the declared dependency interfaces before refresh work. Matching package
versions are not proof of compatibility; report the required companion updates without installing
them implicitly. Replacements retain verified originals outside discovery through the installation
helper only while the update is in progress; success or verified rollback discards them. Refresh
keeps no installation archive or retention policy. A failed rollback is not temporary ownership
contention and receives no timed retry. Existing stale-file deletion is a separately scoped action.