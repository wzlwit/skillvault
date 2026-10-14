---
name: harness-dev
description: "[upsert|queue|sprint|test|broad] Alone: the board. Text: develop it. Record, queue, and develop tasks with the two-reviewer review loop, run goal-based sprints, and declare or run reusable tests; broad raises one task's reviews and unit tests. Shorthand: /hn-dev. Overlaps with harness-monitor on intake and checks, harness-review on code review, and harness-write on report implementation; sprints can draft status through harness-write."
metadata:
  author: wzlwit
  version: "3.0.0"
argument-hint: "[upsert|queue|sprint|test|broad] [<task or request>]"
---

# Harness Dev

`/harness-dev` records tasks and does the work: development, verification, and fixes with
independent review, goal-based sprints, and reusable tests. `/harness-review` reviews code without
development, and `/harness-monitor` finds and proposes work.
`/hn-dev` is chat shorthand for the same topic, not a separate skill or folder.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.
The same rule selects a word inside the `test` group.

| Input | What happens |
| --- | --- |
| Alone | Show the board: tasks, the queue, what is running, and the latest test results; when nothing is running and a task is ready, offer to start the next one |
| Text | [Develop a task ID or a request](./references/dev.md): start it when idle, queue it when busy; a request is [recorded](./references/task.md) first; `<id> now` asks the running task to stop at its next checkpoint so this one goes next |
| `upsert <task or request>` | [Record a new task or change a matching one, with its readiness, without running it](./references/task.md) |
| `queue <task>` | [Line it up for the next pickup without starting it](./references/dev.md#workflow) |
| `sprint [<goal>] [<task>...]` | [Plan a goal-based sprint](./references/sprint.md), run its tasks through the review loop, then review and retro |
| `test [list\|declare\|run]` | [Show, declare or draft, or run reusable tests](./references/test.md) |
| `broad [<task>]` | [Develop that task with broad reviews and broad unit tests](./references/dev.md#workflow); with no task, offer the next ready one first |

- Alone shows the board (`-Action Status`, plus the latest test results from the board's run
  history) and starts nothing by itself. When nothing is running and a task is ready, it offers to
  start the next ready one, naming it, and asks once; a yes develops it as its task ID would, and
  without an answer nothing starts. The view ends with one line naming the text uses: give a task ID
  or describe the work to develop it, or add `now` after an ID to run it next.
- Text develops at the `blocking` level. A task ID maps to `-Action Dev -Id <task>`, which starts it
  when idle and queues it when busy. A plain request is recorded through the same intake as `upsert`,
  then started or queued; there is no second task registry. `<id> now` adds `-Mode now`, a
  cooperative checkpoint request that never kills the running task. A request that revises completed
  work can name `--follow-up <id>` (`-FollowUpOf`), and a new task can name `--repo-ref <id>` for its
  coding repository (`-RepositoryRef`). A request for status or help shows the alone view; text that
  names no task and describes no work asks first and creates nothing.
- `upsert` owns task records, identity, and readiness. No intake route starts execution or grants
  automatic eligibility. Keep requirement Source separate from the coding repository.
- `queue` maps to `-Mode next` and never becomes permission to execute. A named request without
  `broad`, including `queue`, returns that task to the `blocking` level.
- `broad <task>` maps to `-Action Dev -Id <task> -ReviewLevel broad` and otherwise develops it as
  text does. The level is saved on the task, so a queued pickup still runs broad; its unit tests rise
  to `broad` as well, and findings outside the task still become follow-up proposals. `broad` with no
  task offers the next ready one first and asks once; without an answer nothing starts.
- Tasks that `/harness-monitor auto` bound to a monitor's worker flow run only through that
  monitor's check; developing or queuing one resets its attempts and requeues it for that monitor's
  next check, without starting development. If the monitor no longer declares intake, the request
  releases the task to normal development review instead.
- Before planning or resuming a sprint, read the [sprint procedure](./references/sprint.md). The user
  picks the tasks and goal; a sprint ends when its tasks are done or blocked, with no calendar time-box.
- Before declaring or changing a test flow or environment, read
  [test declarations](./references/test-flows.md). `test` with nothing after it lists declarations,
  results, and declaration files that differ from what's saved, such as held drafts. Test-only runs
  need no AI worker; keep environments, approvals, and post-development gates unchanged, and never
  relabel a failure as passing. `test declare` shows the change and asks to save, saving after 1
  minute without an answer unless held, as Ask Once in the runtime guide describes; it offers no
  timer, because flows run in the development loop or on demand.
- Before acting on an input, read the procedure its row links: [development](./references/dev.md)
  for alone's offer, text, `queue`, and `broad`; [task intake](./references/task.md) for `upsert` and
  for recording a plain request; [tests](./references/test.md) for `test`.
- Apply `/rules apply` and project instructions, then the Script Permissions and Agent Fallback,
  Runner Inheritance, and Reuse or New procedures in the runtime guide (`harness-runtime/references/runtime.md`,
  installed beside this skill). Preserve task identity, workspace, checks, budgets, and reviewer
  independence. Do not commit, publish, or change schedules.
- After development, the declared tests run while the first (Changes) review pass reads the same code,
  and `afterReview` tests run once after a clean Full pass; only declared tests run, never ones the AI
  picks. Each Changes and Full pass has two independent read-only reviewers, the strongest allowed GPT
  and Claude Opus models from the bundled list, running in parallel by default. Development reviews at
  the `blocking` level unless the task was started with `broad`: reviewers report only what blocks the
  task or merging its change, and the Full pass looks only for what the change breaks elsewhere. At
  `broad`, they also report minor and existing issues in the task's code, and the Full pass audits the
  whole repository. For a wider audit without development, use `/harness-review broad`. Failed tests
  and in-scope findings go back to the developer as one fix round until everything is clean, a fix
  round makes no progress, or the same test fails again right after a fix. Full findings outside the
  task become follow-up proposals. The developer adds unit tests at the declared level, `blocking` by
  default, or `broad` for a task started with `broad`.
- Offer `/grilling` only when a consequential human choice remains, including unresolved scope or
  acceptance choices at intake; never invent task fields. It is not another review pass or an
  automatic rule editor. An unattended worker reports questions and defers the dependent action; it
  does not interview itself or claim the choice was accepted.
