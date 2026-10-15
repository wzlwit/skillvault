# ADR: Monitor Standing Intake and Flow Workers

- Date: 2026-10-08
- Status: Accepted. The owner confirmed all twelve decisions on 2026-10-14 in the
  [whole-project review](./2026-10-14-whole-project-review-adr.md): decisions 1-10 in its second round
  and 11-12 in its third, with the built-in AI follow-up worker of decision 12 kept as a later step.
  They were first accepted by delegation. The owner asked the agent to design and build
  this overnight ("you take care of B and grilling") and was not available to answer questions, so the
  agent answered the grilling questions below with its recommendations. On 2026-10-08 at 10:33 the owner
  asked to make it generic, with an `auto` action that follows up issues or monitoring; decisions 11 and
  12 record that, with the agent's recommended options because the owner did not answer.
- Decision owner: Zhaolong Wang
- Scope: How a `/harness-monitor` source or health monitor can turn what it finds into work and do that
  work without a human accept per item, and the limits on that.

## Context

A discovery check finds candidates and proposes tasks, but every task needed an explicit
`/harness-monitor accept`, and the only thing that runs a task is the AI development loop for a coding
repository. A queue such as the active incidents in one saved incident query fits neither: the owner's
standing policy is "work every active incident in the query", and the work is a local, draft-only
investigation by another tool, not code. The owner's incident project therefore ran its own scan script
on an hourly harness test-flow timer: it refreshes the list and investigates the next items itself, so
the harness sees one flow run, not the items.

## Decisions

1. **The standing approval lives in the source declaration.** A discovery monitor may declare
   `intake`: `mode: "auto"`, the worker flow, limits, and `approvedBy` and `reason`. Without `intake`,
   acceptance stays manual exactly as before. Applying the declaration still needs a human Actor and
   Reason; a direct edit of `config/monitors.json` must state `approvedBy` and `reason` itself.
2. **Work runs as a declared flow, never the AI development loop.** The worker is a `/harness-work test`
   flow. Worker flows, and feed producers in decision 7, must declare `effects: "local"`: they write only
   local files such as drafts and reports and change nothing outside the machine. The harness cannot
   prove that; the declaration is the owner's statement. Anything that posts, writes to another system,
   or changes code stays manual, and external writes keep their own approvals.
3. **The item is handed over in environment variables.** `HARNESS_ITEM_ID` (the adapter's item ID),
   `HARNESS_TASK_ID`, `HARNESS_SOURCE`, `HARNESS_SOURCE_REVISION`, and `HARNESS_MONITOR`. Flow arguments
   stay literal.
4. **Exit codes decide the outcome.** Exit 0 completes the task. An exit code listed in
   `setupExitCodes` (such as an expired sign-in) stops this check's work without counting an attempt;
   the item stays queued. Any other failure or a timeout counts an attempt; at `maxAttempts` (default 2)
   the task fails. A completed task is not reopened when the source item changes later; that stays
   evidence, as before.
5. **Intake takes only what manual acceptance would.** It uses the existing proposal rules: a fresh,
   complete collection, a Relevant assessment for scoped sources, and a verified-open outcome when
   verification is on. It skips follow-up proposals and blocked proposals, which stay for a human, and
   it works only items present in the current collection; a Missing item waits.
6. **Tasks bound to a worker stay out of the development loop.** They keep Unknown risk and no automatic
   eligibility, and development selection skips them. An explicit `run` or `queue` of one resets its
   attempts and requeues it for its monitor's next check; this is how a failed item is retried. If the
   monitor no longer declares `intake`, that request releases the task to normal development review.
7. **Monitor and work are one job.** Intake and work run at the end of a named check (`check <name>` and
   its `monitor <name>` timer), under the same run lock; `check all` still only collects and proposes.
   A `json-feed` source may declare a `producer` flow that refreshes the feed before collection; a failed
   producer fails the check, and nothing is taken in. A producer exit listed in `setupExitCodes`, such as
   a busy shared browser profile, blocks the check without counting a failure.
8. **Limits reuse existing targets.** `maxPerCheck` (1 to 20) caps worker runs per check; the worker
   flow's `maxMinutes` caps each run. Each run records its outcome on the flow's `test:<flow>:<env>`
   target, so the existing pause, stop, budget, and failure-threshold rules apply to the worker. Any
   outcome that pauses or stops something (a timeout, stop, pause, restriction, or blocked start) ends
   the check's work; restrictions and blocked starts count no attempt.
9. **Recovery counts once.** A worker whose process cannot be confirmed stopped stays Running and keeps
   its checkout claim. The first recovery, explicit `Recover` or a Cycle's recovery check, counts the
   attempt and returns the task to Queued, or Failed at the cap. The flow target stays paused, as for
   any interrupted run.
10. **Compatibility.** The runtime's `monitor-discovery` interface moves to 6; `harness-monitor` requires
    it and moves to 1.1.0. `harness-runtime` and `harness-work` stay at their untagged versions.
    *Updated:* decisions 11 and 12 move the interface to 7.
11. **One `auto` action, owned by `harness-monitor`.** Monitors own sources, so the generic switch lives
    there; `harness-work` keeps listing worker tasks and retrying them with `run <task>`.
    `/harness-monitor auto` lists every monitor's intake, worker, limits, last check, and tasks.
    `auto <name> --worker <flow> [--every <duration>] [--max <n>] [--attempts <n>] [--setup-exit
    <code>...]` previews, then on the owner's approval writes the intake (`approvedBy` is that owner)
    and `allowScheduled: true` through the runtime's `MonitorAuto` action, and delegates the
    `monitor <name>` timer to `/harness-timer` (default `1h`). `auto <name> off` removes the intake and
    disables that timer; removal records a `StandingIntakeRemoved` event.
12. **Generic sources, staged workers.** Health monitors take the same intake: an Unhealthy incident's
    proposal becomes a task, and its worker receives the incident ID in `HARNESS_ITEM_ID`; a recovered
    episode is not worked. Workers are any declared local-only flow now. A built-in read-only AI
    follow-up worker (`--worker agent`) is the next step and needs its own approval: a prompt contract,
    a credit cap, an output format, and local drafts only.

## Adoption

- **The owner's incident project switched on 2026-10-08 at about 07:10.** Overnight, another session
  was running that project's own work, so the switch was prepared, validated against the current
  configuration in memory, and left unapplied. In the morning the owner said "continue" but did not
  answer the confirmation question, so the agent applied its recommendation, keeping the old loop as a
  rollback:
  - The hourly scan flow timer is disabled, not deleted.
  - The project's incident-query monitor now has `intake` and a feed producer, and runs hourly.
  - The switch files and the rollback command are kept in that project's `.harness_sv/definitions/`.
  - Two wrappers leave the original scan script unchanged. The worker wrapper runs it for one item,
    exits 0 only when the draft exists, and exits 2 for setup problems or a held scan lock. The feed
    wrapper runs the feed adapter under the same machine-wide lock, because the adapter and the
    investigation tool share one browser profile.

## Alternatives Considered

- **A separate `workers.json`.** Rejected: flows already provide the executor, environments, budgets,
  pauses, and reports.
- **Running worker tasks in the development Cycle.** Rejected: the Cycle is built around a coding
  workspace and review loop, and one automatic pickup per cycle; mixing them risks a non-code task
  reaching the AI loop.
- **Auto-accepting without work.** Rejected: it fills the board without closing the loop the owner asked
  for.
- **Placeholders in flow arguments.** Rejected for now: environment variables need no parser change and
  cannot alter the argument list.

## Consequences

- A source with standing intake shows each item as a task with its own runs and reports, instead of one
  opaque scan.
- The owner's statement that a flow is local-only is the safety boundary; review a worker before
  declaring it.
- Long checks: a check with work can run for up to `maxPerCheck` times the worker's budget.
