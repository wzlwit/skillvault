
# Harness Sprint

Contents: Start or Resume; Plan; Run; Sprint Review; Retro; Record.

`/harness-work sprint [<goal>] [<task>...]` runs a goal-based sprint: plan it, run each task through
the development loop, review the outcome, and propose improvements. It is a session workflow over
existing actions, not a runtime action, scheduler, or second task store. There is no calendar
time-box: a sprint ends when every planned task is done or blocked.

## Start or Resume

1. Resolve the project and apply `/rules apply` and project instructions. Follow the installed
   `harness-runtime` guide's Script Permissions and Agent Fallback, Runner Inheritance, and Reuse or
   New procedures, as for `run`. Choose Reuse or New once for the sprint, not for every task.
2. Look for an open sprint record (Status other than `Closed`) under
   `<controller>/.harness_sv/docs/sprints/`. Resume one at its recorded stage; with several, list them
   and ask which. When a new goal arrives while a sprint is open, ask whether to close that sprint first.

## Plan

1. Show candidate tasks from the board: ready tasks with scope and acceptance, plus any requested IDs.
   Mark tasks that are not ready or not Low risk; they return to `/harness-work upsert` for readiness. The
   sprint never changes a task's risk, scope, acceptance, or automatic eligibility.
2. Propose a goal and an ordered task list. The user picks the tasks and confirms the goal. Without
   that answer, nothing is written or started.
3. Write the sprint record (see Record) with Status `Planned`.

## Run

1. Set Status `Running`. Run the tasks in order, one at a time, with
   `harness.ps1 -ProjectPath <root> -Action Dev -Id <task-id>`, passing the approved runner context.
   Each run is the full development loop with the review panel.
2. After each task, record its outcome, report, workspace, review rounds, and follow-up proposals.
   `NeedsDecision`, `Blocked`, or `Failed` does not end the sprint: note what the task needs and
   continue with the next one. A safety pause, `NeedsRecovery`, `Busy`, or ownership conflict stops
   the run; resume the sprint after it is resolved.
3. Collect questions for the user instead of interviewing inside workers. Offer `/grilling` only for
   a consequential choice that blocks a task.

## Sprint Review

When every task is done or blocked, set Status `Review` and summarize: whether the goal was met,
completed tasks with their evidence, blocked tasks and what each needs, follow-up proposals, and
notable time or credit use. Completed means verified in the assigned workspace, not merged or deployed.

- Status update: on request, draft it through `/harness-write upsert tracker` or `email`. Drafts
  only; sending or sharing needs an explicit request.
- Pull request: only on explicit request, through `/pr-publish`, after the user approves the commits.

## Retro

From the evidence, list what helped and what slowed the sprint: repeated review findings,
no-progress stops, validation failures, and blockers. Write specific rule or skill changes as
proposals in the record. Applying one is a separate request through `/rules` or
`/skillvault-authoring upsert`. Then set Status `Closed`.

## Record

Save the record at `<controller>/.harness_sv/docs/sprints/<yyyy-mm-dd>-<goal-slug>.md` unless the
user names another path. It is a plan and a point-in-time summary; the board stays the source of
truth for task state.

```markdown
# Sprint: <goal>

- Status: Planned | Running | Review | Closed
- Started: <date>
- Closed: <date>
- Project: <controller path>

## Tasks

| Order | Task | Outcome | Report | Notes |
| --- | --- | --- | --- | --- |

## Review

## Retro proposals
```
