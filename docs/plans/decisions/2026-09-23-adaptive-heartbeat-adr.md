# ADR: Adaptive Heartbeat Baseline

- Date: 2026-09-23
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: Shared scheduler baseline, next-trigger selection, and deferred-job rechecks
- Replaces: The unconditional 30-minute routine fallback; job timing and execution permissions remain unchanged

## Context

The [timer design](../2026-09-15-harness-command-and-record-contracts.md#timer-workflows)
uses one Windows heartbeat for multiple logical schedules. Its 30-minute fallback caused
routine checks even when jobs were much less frequent. The owner clarified that the requested
daily or half-day default concerns the heartbeat, not each job, then requested implementation
of the adaptive daily-baseline recommendation.

The heartbeat also reconciles worker receipts. Simply changing every check to daily would
delay clearing active claims and could delay conflicting jobs. Previously, an overdue job
blocked by availability or workspace conflicts could re-arm the heartbeat one minute later.

## Decision

1. Default the persisted user-wide `heartbeatInterval` to `1d`. Missing values in older
   scheduler state use that default in memory; reads do not rewrite state.
2. Reuse the timer topic's `set` and `list` actions with a settings-only `heartbeat` target.
   Accept fixed `m/h/d` durations of at least one minute, including `12h`. Omission reuses the
   saved baseline. Preview before applying; baseline setup creates no work schedule.
3. With ordinary work enabled or active, use the minimum of the baseline, enabled non-recovery
   fixed job intervals, and a 30-minute cap while active claims need reconciliation. Clamp
   Windows repetition to one minute. Calendar jobs retain their calculated deadlines.
4. Schedule an earlier pending job deadline or maintenance start when present. Use the adaptive
   interval for the repeating fallback too. Synchronize on approved schedule/baseline changes,
   cleanup, and completed ticks. A fast timer never makes unrelated jobs execute early.
5. Track the overdue jobs that the current tick found unavailable or conflicting. Exclude those
   overdue timestamps from that tick's next-trigger calculation, while preserving their anchor
   and nextDue. Reconsider them on the next heartbeat, due to the adaptive fallback or another
   earlier job. Add no retry queue, artificial completion, or automatic recovery.
6. Keep maintenance-only Saturday 08:30 scheduling and its weekly fallback. Disable the heartbeat
   when no work, active claims, or maintenance remains. Keep signed-in/non-elevated operation,
   no automatic machine wake, ownership checks, locks, and existing permissions.

Baseline-only configuration does not reset job anchors, intervals, nextDue, enabled states,
or maintenance. This decision adds no daily job default, fixed morning start, or overnight-only
execution window. Ordinary job Set and missed-tick semantics remain as before.

The baseline has no AI model: it is PowerShell dispatch. Harness AI workers retain explicit
project settings, supplied session/parent settings, and verified-profile selection, with native
`auto` intelligence routing only when no model is resolved. PR review retains its own profile
contract. No worker configuration is changed by this decision.

## Alternatives and Consequences

- Keep 30-minute routine checks: simpler, but retains unnecessary wakeups for infrequent work.
- Use only a fixed daily trigger: fewer checks, but can miss earlier jobs and delay result handling.
- Use adaptive deadlines with a daily baseline: selected; preserves job timing while reducing
  idle checks. Shorter enabled jobs or active claims still require more frequent heartbeats.
- Add completion notifications or a permanent scheduler process: could reduce active polling,
  but introduces another mechanism not needed for this change.

A longer idle baseline may delay detecting conditions that have no earlier scheduled check.
It is not a model-cost saving guarantee or real-time service. Baseline overrides can restore a
shorter interval; no job/state-schema migration is required. Routine source edits do not install
new helpers, reconfigure existing Windows tasks, or change unrelated schedules.

## Implementation and Verification

The [scheduler](../../../skills/planning/harness-timer/scripts/harness-scheduler.ps1)
owns baseline validation, persistence, adaptive timing, and tick-local deferred IDs. The existing
[timer dispatcher](../../../skills/planning/harness-timer/scripts/harness-timer.ps1)
exposes settings and synchronizes applied cleanup. The
[scheduler fixture](../../../scripts/test-harness-scheduler.ps1) covers baseline defaults and
overrides, old-state reads, preview purity, unchanged job timing, shortest intervals versus exact
deadlines, active results, disabled/calendar jobs, blocked rechecks, and release after completion.
Existing maintenance, migration, receipt, no-overlap, and real local test-adapter checks remain.
The fixtures use temporary state and fake Windows registration/AI workers, not live tasks.

Operational guidance is in the [scheduler contract](../../../skills/planning/harness-timer/references/scheduler.md).
Installed-copy rollout and live synchronization are separate, unrequested operations.