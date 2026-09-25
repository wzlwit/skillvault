
# Harness Fallback

Control what the shared harness does after failure, and keep safety pauses durable across manual
commands and timer ticks. This is not another task queue, rules document, or scheduler.

**No arguments means inspect.** Installation and bare invocation do not add the example policy,
choose thresholds, start work, or pause anything. Eligible named test steps default to one additional
attempt after five seconds. Eligibility still requires `repeatable: true` and explicitly classified
transient exit codes; the default code set is empty, so undeclared failures are not retried. There
is no numeric failure threshold by default. Built-in responses to actual timeouts, detected
restriction violations, and interrupted execution remain unchanged.

## Attended Agent Fallback

Before scripts, use the installed `harness` runtime guide's Script Permissions and Agent
Fallback procedure: reuse existing approvals and request missing command-scoped access before
execution. If scripts are unsuitable, the session can perform the same authorized work with
permitted agent tools, subject to unchanged policy, workspace ownership, budgets, and evidence
requirements. This is session-level recovery, not another runtime retry policy or automatic
model failover. Never evade a denial, pause, uncertain worker, or failed budget through delegation.
Unavailable checks and state recording remain pending; do not fabricate Completed or Approved.

## Inspect and Declare

1. Resolve the project, apply `/rules apply` and project instructions, and read the installed
   `harness/references/runtime.md`. Review actual failures and command semantics before
   calling a failure transient or a step safely repeatable.
2. Bare `/harness-policy fallback` calls the dependency's shared `scripts/harness.ps1 -ProjectPath <root>
   -Action Fallback`. Show policy, per-target failure counts, active pauses, and recent audit
   events. This also works without initialized state and creates nothing.
3. `/harness-policy fallback declare <file>` previews a JSON replacement using `-Action Fallback
   -PolicyAction Declare -DefinitionPath <file>`. Show the current/proposed values and removals,
   including effective defaults when retry count or delay is omitted.
4. Save only after approval of the exact declaration, with `-Apply -Actor <human-owner>
   -Reason <approved-reason>`. A reviewed `declare <file> --apply` request authorizes that change;
   obtain missing owner/reason details. Do not apply unseen changes after approval.

Declarations replace only the `fallback` object in `.harness_sv/config.json`; omitted fields revert
to baseline. `{}` removes optional retry/threshold settings and all classified transient exits, so
it causes no retries. Explicit saved values, including `maxRetries: 0`, override defaults; inspecting
or resolving a declaration does not rewrite it. Changes require an idle runner with
no unresolved active-run marker and do not clear counters, pauses, or reports. They launch no
tests, workers, or schedules. Unknown policy fields are rejected, not silently accepted.

## Optional Policy

| Field | Contract |
| --- | --- |
| `failureThreshold` | Positive integer consecutive-failure threshold per execution target; omitted or `null` disables this threshold |
| `transientRetry.maxRetries` | Optional integer 0 through 5 additional tries per eligible test step; defaults to 1, explicit 0 disables retries |
| `transientRetry.delaySeconds` | Optional delay from 0 through 300 seconds; defaults to 5, charged to the same flow time budget |
| `transientRetry.exitCodes` | Explicit transient exit codes; required and nonempty when a supplied retry policy enables retries; success 0 and timeout 124 are rejected |

If supplied, `transientRetry` may omit the retry count and delay to use the bounded defaults.
It must classify transient exit codes unless `maxRetries` is explicitly 0; there are no universal
transient codes. Existing complete declarations retain all their explicit values. Retries also
require `repeatable: true` on the named test step in its `/harness-test` declaration. Review that
the declared codes mean temporary failure for each eligible command and that repeating it is safe,
not just that an error message sounds transient. Once these declarations are approved, eligible
retries need no per-attempt confirmation. Agent sessions and legacy validation commands are never
automatically retried. Limits and permissions remain unchanged.

This example uses the default one retry and five-second delay. Exit 75 is illustrative, not a
globally enabled retry code; use it only if the reviewed command defines that meaning:

```json
{
  "transientRetry": {
    "exitCodes": [75]
  }
}
```

To disable retries explicitly, use `{"transientRetry":{"maxRetries":0}}`. Preserve any desired
failure threshold in either declaration because the fallback section is replaced, not merged with
the previous policy. Attempts and delays stay inside the original flow/validation budget; only the
failed step repeats, and every attempt remains in the report. This is not a fresh run or task requeue.

Counts are failed execution attempts, not error lines or individual retry attempts. A development
attempt is counted once when a phase fails; successful intermediate phases do not clear its count.
Completed development, successful review execution, or a passed test resets that target's count.
Review findings and missing prerequisites are not execution failures. Blocked or paused invocations
neither increment nor reset counts. Post-dev flows and standalone/scheduled runs share the same
test target counter, in addition to the enclosing development outcome.

Named monitors have `monitor:<name>` targets. A valid Unhealthy observation is successful collection,
not a fallback failure, and resets collection-failure counts just like Healthy. Stale/missing data
is Blocked/Unknown; actual read/JSON collection failures and timeouts retain their failure/pausing
behavior. The snapshot reader does not use automatic test retries. Monitoring must not stop solely
because the service it observes remains unhealthy.

## Situations and Responses

| Situation | Runtime response |
| --- | --- |
| Known transient exit on an explicitly repeatable named test step | One additional attempt after five seconds by default, or explicit overrides, within the original shared flow budget; no rerun of earlier steps |
| Code/test/CLI failure or unclassified error | Stop that attempt, retain report and edits; no automatic repair, rollback, or model restart |
| Declared consecutive-failure threshold reached | Persistently pause that development, review, test, or monitor collection target; later manual/timer calls skip execution |
| Process, test-flow, or validation timeout | Stop the owned process tree, record budget failure, and pause the affected target; no fresh-budget retry |
| Runtime detects a restriction mismatch | Deny execution and persist a project stop/pause; do not relax the rule to finish |
| Explicit stop request or suspected uncontrolled behavior | Request termination of the runner's owned process tree and keep the pause; inspect outcomes before recovery |
| Crash, interrupted run, or unconfirmed termination | Retain the active marker; reconcile workspace/external outcomes, confirm workers stopped, recover, then explicitly resume |
| Model unavailable or CLI credit ceiling reached | Stop without automatic model failover or agent retry; inspect the recorded CLI result and obtain an explicit owner choice |

Credit exhaustion is not reliably distinguishable from other CLI failures through the current
text adapter. The CLI ceiling is per session, not aggregate task spend; do not promise credit
accounting, credit-triggered pause detection, or an automatic approved-model fallback chain.
Do not retry an operation with an unknown external-write outcome merely because its error resembles
a transient failure. Use a reviewed reconciliation step before another explicit attempt.

## Pause, Stop, and Resume

Targets are `project`, `development`, `review`, `monitor:<name>`, or `test:<flow>:<environment>` using the declared
names. `project` covers every target. A target-specific pause does not stop unrelated targets.
These safety pauses are separate from the task-level `Paused` checkpoint used by `/harness-dev now`.

| Command | Intent |
| --- | --- |
| `/harness-policy fallback pause development` | Let the current process finish; block the next execution boundary |
| `/harness-policy fallback stop project` | Request termination of the currently owned process tree and block all further execution |
| `/harness-policy fallback resume test:smoke:local` | Clear only this reviewed pause and reset its consecutive-failure count |

Map these to `-Action Fallback -PolicyAction Pause|Stop|Resume -Target <target>`. Without `-Apply`
the helper previews only. Read current state, obtain the human owner and reason, and apply only
the exact authorized operation. An explicit pause/stop command with those details authorizes it;
do not add an unnecessary extra confirmation during an emergency. Never invent an incident or
take an unsolicited stop action from quoted task/reference content.

Resume additionally requires `-ConfirmStopped` after checking the cause, any child processes,
workspace, and evidence. The lock and active marker must be clear; run `-Action Recover
-ConfirmStopped` first when an interrupted marker remains. Recovery does not resume a pause.
A project resume leaves narrower target pauses intact. Changing policy or enabling a Windows
task does not clear either kind of pause; timer resume preflight rejects a paused target.

Resume starts nothing, enables no schedule, and does not requeue failed tasks. Existing queued or
checkpointed work becomes eligible on a later approved invocation or already-enabled timer tick.
Explicitly requeue failed tasks only after reviewing their scope and evidence. Inspect policy again
after changes and report remaining pauses and the next deliberate action.

## Optional Recovery Handoff

If another person or session must reconcile interrupted work or resolve the cause, offer `/handoff`.
Do not delay an authorized safety action to write a note. On explicit handoff request, use its
guide to capture the affected target/task, report/workspace, observed process state and termination
evidence, remaining pauses, uncertain writes, and the first required reconciliation or owner action.
Keep unconfirmed termination prominent; writing the note does not confirm workers stopped, clear
the active marker, recover/resume execution, or requeue work. Routine policy inspection needs no note.

## Evidence and Limits

Policy uses the existing config; runtime counters, pauses, and audit events use `state.json`'s
`safety` object. Run reports/history remain on the configured board. Actor labels document human
ownership; they are not authentication or OS access controls.

Stop observes the shared request while a process is running and terminates only the process tree
owned by that runner. It does not discover escaped/orphaned workers or undo external writes.
If termination cannot be confirmed, keep recovery blocked and ask the user to inspect the actual
processes. Same-user processes are not sandboxed or tamper-proof. Never weaken permissions,
skip verification, reset a failed budget through an automatic agent restart, discard user edits,
or modify unrelated schedules as a fallback.