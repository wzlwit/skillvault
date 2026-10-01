---
name: skillvault-refresh
description: "Merge upstream changes into adapted skills in the SkillVault repository when push is permitted, then bring new commits to the local checkout and managed global latest copies, merging local changes. Use /skillvault-refresh or /sv-refresh list or run; accepts skillvault-fresh, /sv-fresh, /skv-fresh, /skillvault-sync and /sv-sync. Scheduling delegates to harness-timer set refresh. Never pushes your own commits or updates project copies."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|run]"
---

# Skill Refresh

`/skillvault-refresh` merges upstream changes into adapted skills in the SkillVault repository
when it may push there, then brings new commits to the recorded local checkout and managed global
`latest` copies, merging local changes. It never pushes your own commits or updates project copies.
`/sv-refresh` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

- Bare invocation, `list`, `status`, and `help` inspect refresh configuration and show actions; they
  never create a schedule. Unknown actions show help.
- `run` follows the [refresh procedure](./references/workflow.md) with `-RunOnce`.
- Legacy `schedule [intervalDays]` delegates to `/harness-timer set refresh`, preserving its explicit
  day value, or the old one-day default for that explicit request only. Legacy fresh/sync commands
  keep their interval semantics; zero means one run.
- The shared heartbeat runs the [refresh script](./scripts/skillvault-fresh.ps1) with `-RunOnce`; its
  old OS-task path is compatibility-only, not a second scheduler.
- Preserve pins, unrelated installs, recorded sources, same-scope helpers, and failure isolation.
  Skip hidden compatibility bundles; they need explicit installed-copy migration.
- Dependency checks, rollback, and companion updates follow
  [runtime compatibility](./references/workflow.md#runtime-compatibility).