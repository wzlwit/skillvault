# ADR: Bounded Refresh Contention Retries

- Date: 2026-09-24
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: Temporary ownership contention during scheduled global skill refresh
- Extends: The [shared ownership contract](./2026-09-23-shared-ownership-adr.md), without changing its safety boundaries

## Context

Ownership protection skips an update while its runtime bundle is in use. Previously, that
deferral created no retry request: a manual update needed another invocation, while a scheduled
refresh waited for its next ordinary run. The owner requested three retry intervals and selected
one minute, ten minutes, and thirty minutes before requesting implementation.

Keeping a refresh process asleep through those delays would retain its exclusive scheduler slot
and block unrelated jobs. The existing heartbeat and logical-job state can schedule the bounded
rechecks without another service, timer, or installation queue.

## Decision

1. Allow three additional attempts for temporary `Busy` target ownership during a scheduled
   refresh. Delays are 1, 10, and 30 minutes after preceding attempt completion. Nominal elapsed
   waiting is 41 minutes, excluding execution, scheduler conflicts, and host availability.
2. End each attempt, release its active slot, persist retry state on the existing logical job,
   and re-arm the shared heartbeat. Reconcile outstanding refresh receipts within the one-minute
   cap if the completion callback could not acquire the scheduler lock. Keep normal job exclusion
   during each attempt, not throughout the waiting period.
3. Retry only the original deferred names with matching source repository/path/tree revision and
   installation metadata fingerprint. A changed source, target, pin, or root ends that target's
   retry chain. Recheck ownership before copying. Do not repeat completed targets or erase
   unrelated failure/terminal-deferral evidence.
4. Do not retry unknown legacy transitions, recovery-required claims, self-owned or heartbeat
   parent-owned dependencies, missing source revision evidence, or actual Git/copy failures.
   Never stop workers, clear pauses, grant confirmation, or infer idle from missing information.
5. Stop after the third unsuccessful retry and report Deferred with exhaustion. Preserve the
   independent regular cadence and anchor, coalescing elapsed ordinary ticks. Disable or explicit
   definition changes cancel an idle retry; uncertain worker termination still requires recovery.

Manual one-shot installs and refreshes remain explicit and create no background jobs. This adds
no default live refresh schedule and changes no agent or named-test retry policy. Installation,
schedule setup, and publication retain separate approvals.

## Alternatives and Consequences

- **Wait for the next normal refresh:** Simpler, but can leave a short ownership conflict pending
  for the entire configured interval. Retained after bounded retries are exhausted.
- **Sleep inside the worker:** Easy to implement, but holds exclusive refresh execution during
  long waits. Rejected.
- **Unbounded retry until idle:** Could eventually succeed, but has no clear stopping point and
  risks indefinitely carrying stale intent. Rejected.
- **Bounded heartbeat rechecks:** Selected. Reuses the scheduler and leaves room for other jobs,
  but requires structured receipts and persisted target bindings.

Retry deadlines are best-effort, not an exact wall-clock guarantee. Busy claims can outlast the
window, and source updates can make a pending retry ineligible. Self-updating protected helpers
still need an approved separate installer while idle. Reverting this extension requires cancelling
pending retry fields during an idle, approved transition; it must not reinterpret them as new work.

## Implementation and Verification

The [refresh runner](../../../skills/core/skillvault-refresh/scripts/skillvault-fresh.ps1) reports
structured retry targets and terminal outcomes. The
[heartbeat](../../../skills/planning/harness-timer/scripts/harness-heartbeat.ps1) passes scoped
retry plans and records receipts; the [scheduler](../../../skills/planning/harness-timer/scripts/harness-scheduler.ps1)
owns attempt counts, deadlines, slot release, and regular cadence.

The existing [refresh fixture](../../../scripts/test-skillvault-fresh.ps1) checks target/source
binding, self/parent exclusions, recovery/legacy gates, mixed results, and scoped success. The
[scheduler fixture](../../../scripts/test-harness-scheduler.ps1) uses simulated time and fake tasks
for the full 1/10/30 sequence, exhaustion, disable behavior, independent jobs between attempts,
and local child-process receipt transport. No real waits, live installs, or live schedules are
required by these fixtures.

No policy question remains open in this record. It does not change the unresolved historical
proposal status in the original harness ADR or authorize a live rollout.