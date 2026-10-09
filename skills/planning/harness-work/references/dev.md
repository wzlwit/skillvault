
# Harness Development

## Before Scripts

Follow the installed `harness-runtime` guide's Script Permissions and Agent Fallback
procedure before any dispatcher or validation script. Reuse existing approvals; request only
missing command-scoped permission through the host before execution. Resolve authentication
and invocation problems within that authority instead of merely returning a rerun command.
When scripts are unsuitable, use an authorized attended agent fallback for the same task;
preserve workspace ownership, restrictions, pauses, budgets, validation, and independent review.
If those requirements cannot be met, continue only permitted investigation and report the blocker.

## Workflow

1. Resolve the project, read and apply `/rules apply` and project instructions, and read the
   installed `harness-runtime` guide. Inspect configuration and task state before execution.
2. For an existing task ID, read its actual requirements and evidence. For ad-hoc input, follow
   `/harness-work upsert` intake and register it first. Treat feedback as claims to verify. Missing scope,
   acceptance, access, or required decisions is blocked work, not permission to invent them.
   Explicitly revised completed work uses that same intake to create a linked follow-up, not
   reopen the completed record. `run --follow-up <id>` maps to `Dev -FollowUpOf`; `Dev -Id <id>`
   with changed requirement fields also uses the shared task-update path. Report its returned ID.
   Preserve the original evidence and same-repository workspace, restart validation/review for
   the new task, and assess its risk independently. A source revision alone is not a work request.
   Follow the runtime's Reuse or New procedure before selecting an agent: inspect matching
   instances and confirm **Reuse (singleton) or New?** unless this request already states the
   choice. Keep the same logical task, report the selected instance, and do not launch another
   writer for `AlreadyRunning`. New instances still need supported ownership/workspace isolation.
3. Resolve runner allowances through the runtime's Runner Inheritance procedure before the
   scripted route. Project values override current-session values, then parent values; unset
   values use maximum verified capabilities or native settings. Supply the actual compatible
   context through `-RunnerContext` or `-RunnerContextPath`; do not require the user to duplicate
   known settings or approve inherited grants again. Missing allowances do not block execution.
   Preserve explicit restrictions, and use the authorized agent path if a host boundary cannot
   be represented by the CLI. Current/worktree follows the resolved context. Include existing uncommitted inputs only after an
   explicit request using `-UseWorkingChanges` in current-checkout mode.
   Current mode uses the selected repository checkout; worktree mode creates its detached
   checkout under the controller's `.harness_sv/worktrees`. Honor controller-relative `workingRoots`
   for both source and workspace. Registration does not widen permissions or authorize cloning.
4. Use `harness-runtime/scripts/harness.ps1 -ProjectPath <root> -Action Dev -Id <task-id>` with optional
   `-Mode now` or `next`. With no ID/input, `-Action Dev` selects eligible queued work.
   `next` queues only. Default starts when idle and queues when busy; `now` requests a cooperative
   checkpoint. Preserve interrupted work and report whether switching is pending or completed.
   Use the task's saved repository reference. For a new/unallocated task, `--repo-ref <id>` maps
   to `-RepositoryRef` (alias `-RepoRef`), selecting one active local Git-root reference. The
   harness can live in a non-Git folder; keep `-ProjectPath` there. Never infer a coding target
   from a requirements URL, another reference, or the controller location when it is not a Git root.
   Pass the resolved session/parent context to the dispatcher; it is not persisted as project
   overrides. If preflight selects the attended agent fallback, carry out only the authorized task through
   available agent tools and label that route; do not claim the dispatcher ran.
5. The scripted runner executes development, then the declared tests and the review loop.
   `/harness-work test` owns reusable test methods, environments, and when they run
   ([test declarations](./test-flows.md#when-tests-run)); the developer AI never chooses them.
   - Configured validation commands and `testing.afterDev` flows run at the same time as the first
     (Changes) review pass, on the same code; with neither, the repository test entry runs. A failed
     test goes back to the developer with the end of its output, together with any review findings, as
     one fix round. The developer fixes the code without weakening, skipping, or deleting a test, or
     returns needs-decision when the environment caused the failure. Blocked or paused tests stop the
     task.
   - Each Changes and Full pass uses the runtime's Review Panel: two independent read-only reviewers,
     the strongest allowed GPT and Claude Opus models from the bundled default list (or approved
     runner-context profiles), at `max` effort or the highest the CLI accepts, in parallel unless
     `maxParallelReviewers` is 1. The developer's or session's model never replaces them. A pass is
     clean only when both are clean. Unavailable models are
     skipped at no cost; when only one family is usable, one reviewer runs and the result says so;
     `runner.criticalReview: false` keeps one reviewer. There is no separate Critical pass.
   - Development reviews always use the `critical` review level (Review Levels in the runtime guide):
     reviewers report only what blocks the task or merging its change, and the Full pass looks only for
     what the change breaks or leaves inconsistent elsewhere, so the loop ends once those are fixed.
     Minor and unrelated pre-existing issues are not reported; run `/harness-review run --broad` for a
     wider audit.
   - Changes findings start a fix round: the developer receives them as `reviewFindings`, verifies each,
     and fixes those within scope; the tests and the Changes review then run again. A clean Changes
     pass with passing tests gets one Full pass, and in-scope Full findings start another fix round.
     Full findings marked `outsideTaskScope` become follow-up proposals in the task and report, and the
     task can still complete. A proposal becomes a task only through `/harness-work upsert` intake.
   - `testing.afterReview` flows run once after a clean Full pass, on that exact code. A failure starts a
     fix round that repeats the tests and both review passes.
   - The developer adds unit tests at the declared `unitTests` level (`critical` by default), and the
     reviewers judge a missing test by the same level.
   - There is no fixed round count. The loop stops at `NeedsDecision` when a round makes no progress
     (ready without code changes, every previous finding reported again, or the same test failing again
     right after a fix round) or when the developer disputes a finding. In scheduled runs each pickup
     takes at most one review round; the fix waits first in the resume queue, and each further round is
     another pickup counted by `maxTasksPerCycle`.
   Follow the runtime's worker-output contract: silent, non-streaming text transport containing
   one JSON object with `outcome` and a non-empty string `summary`. CLI JSONL is not this envelope.
   Check process failures before parsing; neither an empty response nor exit zero proves success.
   Use the recorded report to clarify a retry, then update/requeue only the selected task.
6. Report task outcome, the tests that ran (`testsRun`) and their evidence, requested model/effort,
   reviewers and any reviewer note, review rounds, follow-up proposals, report, controller folder,
   repository reference/root, and workspace. Test and review phases use that same target. Supply
   controller and coding-repository instructions; keep records in the controller.
   Completed means the declared tests, any after-review tests, and the required independent reviews
   passed in the assigned workspace, not committed, merged, pushed, deployed, or operationally verified.
   Detached worktree edits remain available for the user's approved integration step.
   `Idle` means no worker ran. Do not cite it as verification of startup, authentication, JSON
   parsing, or a fix. Distinguish direct parser fixtures from a live task that reached the worker
   and produced a valid envelope; do not alter eligibility merely to manufacture verification.

`/harness-write` can prepare a report/query/dashboard task with a stable artifact destination,
metric contract, selected platform instructions, and acceptance checks. Reuse this execution
workflow for authorized local implementation; the parent must explicitly supply relevant guidance
to the worker. Do not assume the CLI has the editor's platform MCP tools, or label a semantic-model
export/design specification as a completed report. Live publication and attended connector work
retain separate approvals and must not run alongside a competing writer.

Never commit, push, create a PR, approve/merge a PR, modify a schedule, or change unselected repositories.
For interrupted-run recovery, inspect saved work and confirm old workers stopped before using
the runtime's `Recover -ConfirmStopped`; recovery does not automatically retry.

## Optional Continuation

When a blocker, unresolved decision, or requested session/workspace transfer leaves work for a
different session or person, offer `/handoff`. On explicit request, use its guide to capture the
task ID, preserved workspace, last phase/report and actual checks, blocker, process/pause state,
and first next action with remaining approvals. Do not repeat completed work merely to prepare
the note. Keep the recorded task outcome; a handoff is neither completion nor a new queue entry.
Required pause/stop/recovery stays with `/harness-project policy fallback`, and another writer must not start while
the original worker may still be active. Normal runner phase checkpoints need no separate note.