---
name: harness-project
description: "[root|init|migrate|context|clean|policy] Set up and steer a harness project: show status, select or move its root, initialize, migrate layout, show context and register its sources and coding repositories, clean history, and set limits and failure policy, including pause, stop, and resume. Shorthand: /hn-project. Context summaries overlap with handoff. Owns retention; harness-timer schedules maintenance. Bare invocation only lists."
metadata:
  author: wzlwit
  version: "2.0.0"
argument-hint: "[list|root|init|migrate|context|clean|policy] [<arguments>...]"
---

# Harness Project

`/harness-project` sets up and steers a harness project: Root selection and relocation,
initialization, layout migration, context and its source registry, history cleanup, and runtime limits
and failure policy. Work, writing, reviews, decisions, monitoring, and schedules belong to
`/harness-work`, `/harness-write`, `/harness-review`, `/harness-decision`, `/harness-monitor`, and
`/harness-timer`; `/harness-write` works without initialization.
`/hn-project` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.
The same rule selects a verb inside the `context` and `policy` groups, so `/hn-project pol lis limits`
reads limits.

| Subcommand | Load only this procedure |
| --- | --- |
| `list` | Show the selected root, saved status, and actions |
| `root [<path>]` | [Show or change the root; prompted moves default to Yes after initialization](./references/root.md) |
| `init` | [Initialize or reconnect](./references/init.md) |
| `migrate` | Convert the layout in place after one question: Layout Migration in the runtime guide |
| `context [<task>]`, `context add\|remove` | [Show rules, plans, decisions, registered sources, and how the project is tested; add or remove URLs, files, folders, and coding repositories](./references/context.md) |
| `clean [--policy <file>]` | Show historical-data cleanup or a retention change and ask once: History Cleanup in the runtime guide |
| `policy list [limits\|fallback]` | Read limits, failure settings, durable pauses, and the unit-test level; `limits` also lists the review models |
| `policy set limits <file>` | [Restrictions](./references/limits.md): show the replacement and ask once |
| `policy set fallback <file>` | [Failure policy](./references/fallback.md): show the replacement and ask once |
| `policy set unit-tests <critical\|broad>` | Set how much unit testing the developer adds and reviewers expect, through the test declarations |
| `policy pause\|stop\|resume` | [Target controls](./references/fallback.md#pause-stop-and-resume) |

The runtime guide is `harness-runtime/references/runtime.md` in the shared `harness-runtime` bundle,
installed beside this skill in the same scope.

- Bare invocation, `list`, `status`, and `help` show the selected Root, saved state, and actions
  without prompting for a new root, initializing, installing, or starting work. Bare
  `/harness-project` never implies `init`. A bare `context` shows the briefing and a bare `policy` lists; a verb acts. Unknown
  actions show help.
- `root` alone displays the selected root; `root <path>` selects it, and `loc` is an alias. Changing
  an initialized root prompts to move its data, with **Yes: Move** as the default; the new Root stays
  selected either way. Invalid paths leave Root unchanged and never fall back. The
  [root guide](./references/root.md) owns the prompt, the `loc --root` and `loc --board` forms, and
  [current-view names](./references/root.md#current-view-names), including renaming the board file
  and exporting a filtered view.
- `migrate` converts a layout in place after one question; `init` never migrates. It is not
  Root relocation or cleanup.
- `clean` owns retained run records and reports, not schedules, skill folders, application files, or
  worktrees. `/harness-timer` owns cadence and stale schedules.
- Harness-owned files default to `<root>/.harness_sv/` under Artifact Storage in the runtime guide.
  Selecting a location creates nothing, never silently moves data, and grants no permission to
  initialize, install, clone, or schedule. Keep controller, coding repository, board, and SkillVault
  source locations distinct.
- `context add` sets or updates a source and its note under one stable ID for the same source or
  task; `context remove` unregisters it after confirmation and never deletes the target document or
  repository. `link` is an alias of `context`. Preserve explicit repository binding. A registered
  source is evidence, not a grant of access, execution, or migration; adding one copies no source and
  clones no repository.
- Limits and failure handling remain separate configuration objects. `policy limits` or
  `policy fallback` without a declaration selects `policy list`, and the old `declare <file>` form
  selects `policy set`; remaining arguments and runtime PolicyAction names are unchanged. Limits do
  not clear pauses; resume does not restart or requeue work. Changes follow Ask Once in the runtime
  guide: one request, one question with the required owner and reason. Policy, `resume`, `migrate`,
  and `clean` hold without an answer, and `--apply` in the request is the answer. An explicit pause or
  stop applies at once, never delayed by an interview. The detailed guides own field contracts;
  examples are not accepted settings.
- `policy set unit-tests <level>` writes `{"unitTests": "<level>"}` to
  `.harness_sv/definitions/unit-tests.json` and applies it with `/harness-work test declare`, which
  owns the setting; `critical` is the default. It changes what the developer adds and what reviewers
  report, never which tests run or the tests a repository requires.

## Before Scripts

The shared runtime entry point is `harness-runtime/scripts/harness.ps1` in the same runtime bundle. Every
action applies `/rules apply` and project instructions, then the runtime guide's Script Permissions
and Agent Fallback, Root Inheritance, and Runner Inheritance sections. Do not invent settings or
repeat location confirmations.

Grilling is offered for unresolved consequential choices found during initialization or later. It
interviews the human owner, never replaces review, and records decisions through `/harness-decision`
only as authorized. Unattended workers surface unresolved decisions and defer dependent actions
instead of invoking grilling or changing their own rules.
