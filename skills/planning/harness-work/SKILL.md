---
name: harness-work
description: "[upsert|run|queue|sprint|test] Add or update tasks; run or queue development, verification, and fixes with the two-reviewer review loop; run goal-based sprints; and declare or run reusable tests. Shorthand: /hn-work. Overlaps with harness-monitor on intake and checks, harness-review on code review, and harness-write on report implementation; sprints can draft status through harness-write. Bare invocation only lists; work starts only with an explicit verb."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|upsert|run|queue|sprint|test] [<arguments>...]"
---

# Harness Work

`/harness-work` records tasks and does the work: development, verification, and fixes with
independent review, goal-based sprints, and reusable tests. `/harness-review` reviews code without
development, and `/harness-monitor` finds and proposes work.
`/hn-work` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.
The same rule selects a verb inside the `test` group.

| Action | Outcome |
| --- | --- |
| `list` | Show tasks, queue, current execution, and latest test results |
| `upsert` | [Record a new task or update a matching one, with its readiness, without running it](./references/task.md) |
| `run [<task>]` | [Start when idle or queue when busy](./references/dev.md); `--now` requests a cooperative checkpoint |
| `queue <task>` | Queue only; map to `-Mode next`, never start a worker |
| `sprint [<goal>] [<task>...]` | [Plan a goal-based sprint](./references/sprint.md), run its tasks through the review loop, then review and retro |
| `test [list\|declare\|run]` | [Show, declare or draft, or run reusable tests](./references/test.md) |

- Bare invocation, `list`, `status`, and `help` show tracked state, latest test results, and actions
  without selecting or running work or tests; bare `test` lists declarations and results. Queue
  selection without an ID applies only to an explicit `run`. Unknown actions show help without
  creating work.
- `upsert` owns task records, identity, and readiness; `add` and `update` are aliases. No intake route starts execution or
  grants automatic eligibility. Keep requirement Source separate from the coding repository.
  Ad-hoc `run` requests register through the same intake first; there is no second task registry.
- `run`, `queue`, or explicit task input follows the development procedure. Legacy `now` selects
  `run --now` (`-Mode now`) and `next` selects `queue`; queue-only input never becomes permission to
  execute. Tasks that `/harness-monitor auto` bound to a monitor's worker flow run only through that
  monitor's check; `run` or `queue` on one resets its attempts and requeues it for that monitor's
  next check, without starting development. If the monitor no longer declares intake, the request
  releases the task to normal development review instead.
- Before planning or resuming a sprint, read the [sprint procedure](./references/sprint.md). The user
  picks the tasks and goal; a sprint ends when its tasks are done or blocked, with no calendar time-box.
- Before declaring or changing a test flow or environment, read
  [test declarations](./references/test-flows.md). Test-only runs need no AI worker; keep
  environments, approvals, and post-development gates unchanged, and never relabel a failure as passing.
- Apply `/rules apply` and project instructions, then the Script Permissions and Agent Fallback,
  Runner Inheritance, and Reuse or New procedures in the runtime guide (`harness-runtime/references/runtime.md`,
  installed beside this skill). Preserve task identity, workspace, checks, budgets, and reviewer
  independence. Do not commit, publish, or change schedules.
- After development, the declared tests run while the first (Changes) review pass reads the same code,
  and `afterReview` tests run once after a clean Full pass; only declared tests run, never ones the AI
  picks. Each Changes and Full pass has two independent read-only reviewers, the strongest allowed GPT
  and Claude Opus models from the bundled list, running in parallel by default. Failed tests and
  in-scope findings go back to the developer as one fix round until everything is clean, a fix round
  makes no progress, or the same test fails again right after a fix. Full findings outside the task
  become follow-up proposals. The developer adds unit tests at the declared level, `critical` by default.
- Offer `/grilling` only when a consequential human choice remains, including unresolved scope or
  acceptance choices at intake; never invent task fields. It is not another review pass or an
  automatic rule editor. An unattended worker reports questions and defers the dependent action; it
  does not interview itself or claim the choice was accepted.
