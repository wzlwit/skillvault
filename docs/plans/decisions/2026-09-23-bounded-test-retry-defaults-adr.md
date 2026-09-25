# ADR: Bounded Test Retry Defaults

- Date: 2026-09-23
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: Default retry bounds for eligible named test steps
- Replaces: Zero retries as the fallback default; explicit settings and eligibility gates remain

## Context

The existing test-flow executor already retries an explicitly repeatable step when its exit
code is classified as transient. The fallback policy previously defaulted to zero retries and
required count, delay, and exit codes in every retry declaration. The owner requested applying
the recommendation for bounded automatic retries of known transient, safely repeatable operations.
Whole AI-session restart and recovery behavior remain separate and are not included.

## Decision

1. Supply defaults of one additional attempt and a five-second delay through the existing
   fallback resolver. Retry declarations may omit count and delay rather than repeating them
   in each project. These implementation defaults are bounded and remain overridable.
2. Keep `repeatable: true` and explicitly classified command exit codes as eligibility gates.
   No code, including 75, is transient globally. An absent retry declaration classifies no
   failures; merely marking a step repeatable still causes no retry.
3. A supplied retry policy needs nonempty transient exit codes unless its `maxRetries` is 0.
   Explicit saved count/delay/code settings win, including `maxRetries: 0`. Validate resolved
   values against the existing ranges and continue rejecting success 0, timeout 124, and
   unknown fields. Invalid supplied values are not replaced with defaults.
4. Use the existing failed-step loop. Do not repeat earlier successful steps, reset the flow
   or enclosing validation budget, hide attempt evidence, or request confirmation per attempt
   after the repeatability and transient classification have been approved.
5. Preserve stop, timeout, restriction, and durable-pause handling. Do not retry failed AI
   sessions, legacy validation commands, or unclassified errors; do not auto-requeue tasks,
   change models, add failure thresholds, or alter the review/fix continuation contract.

Missing fields resolve in memory. Saving a short declaration keeps it short; inspection and
execution do not rewrite existing policy. Removing the fallback object also removes its exit
classifications, so it does not enable retries accidentally. Installed copies and live policies
are not updated by this source change.

## Alternatives and Consequences

- Retain zero retries until every bound is configured: explicit but requires repeated setup
  even after a command's transient failure and repeatability are known.
- Retry all failures or assign common exit codes globally: rejected because command exit-code
  meanings and side effects differ; repeating an assertion failure is not a substitute for a fix.
- Default bounded retries only for eligible failures: selected. It reuses the existing policy
  and executor, preserves explicit opt-out, and needs no new runner or scheduling action.

An eligible failure can consume one more attempt and five seconds of the same budget. Projects
can tune those values or disable retries. A partial declaration that formerly failed validation
can now use defaults, while existing complete valid declarations retain their behavior.
This adds no reliability guarantee for unknown failures or partially completed external writes.

## Implementation and Verification

The [fallback resolver](../../../skills/planning/harness/scripts/harness-policy.ps1)
fills omitted bounds and validates partial declarations. The
[test-flow loop](../../../skills/planning/harness/scripts/harness-tests.ps1) is reused
without a new execution path. The [policy fixture](../../../scripts/test-harness-policy.ps1)
covers defaults, persistence, opt-out, failed-step-only retries, invalid/unclassified exits,
repeatability, stops, timeouts, shared budgets, and durable pauses using temporary state.

The [fallback guide](../../../skills/planning/harness-policy/references/fallback.md)
owns the declaration contract; the [current plan](../2026-09-15-harness-command-and-record-contracts.md#restrictions-and-fallback)
links this decision. No live installation, policy, schedule, or automatic AI retry is authorized
by the implementation. The interrupted grilling questions Q3 and Q4 were unanswered when this
retry decision was recorded. Their later accepted outcome is separate: see the
[decision bulletin contract](../2026-09-15-harness-command-and-record-contracts.md#decision-bulletin).