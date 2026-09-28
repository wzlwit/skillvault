# ADR: Quiet Script Execution

- Date: 2026-09-27
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: Agent-initiated script execution across skills and a repository-only read-only launcher audit
- Supersedes: None

The owner accepted all three grilling recommendations on 2026-09-27: include unexpected terminal
focus changes, obtain permission when no suitable quiet path exists, and audit this repository's
launchers read-only. The audit does not authorize launcher fixes or live schedule changes.

## Context

Routine scripts should not unexpectedly open additional consoles or graphical windows. The owner
requested quiet execution across skills, with visible interaction when user action is required.
The shared rules now express that preference while preserving explicitly requested UI.

Quiet execution and background execution are different choices. A one-shot script can run in the
current terminal without another window and still return its result. Detaching every command or
discarding output would make completion and failures harder to verify and could hide needed prompts.

## Decision

1. Run routine scripts quietly where supported. Prefer the current execution tool or terminal
   and documented quiet or no-window options; do not create a separate console or GUI merely
   to perform routine script work. Keep logs accessible without automatically revealing VS Code
   terminal panels or stealing focus where supported by the host. Bring UI forward only when
   explicitly requested or required for user action.
2. Await one-shot scripts and retain exit status, relevant output, and errors. Quiet execution
   must not turn missing results into a success claim or leave required work unverified.
3. Run long-lived services and watchers in the background with retrievable status and logs.
   Background execution is not a general substitute for waiting on builds, tests, or installers.
4. Show interactive UI only when explicitly requested or required for authentication, consent,
   or manual input. Explain why before opening it. Never auto-approve, bypass denials, hide a
   needed prompt, or request secrets through chat. If a required command has no verified no-window
   option, try an approved non-GUI alternative first. Otherwise explain the limitation and wait
   for permission before opening a window. Reuse explicit approval for that visible action;
   no answer leaves the command pending, including unattended runs.
5. Maintain the guidance in the shared rules instead of copying it into every skill. Apply it
   regardless of which skill initiates the script, within the host's tool and permission rules.
   Installation makes guidance available; it does not provide automatic instruction injection
   or enforce the behavior of every third-party launcher.
6. Audit existing launchers only in this repository and report findings first. Launcher fixes,
   changes to installed third-party tools, and live schedule changes need separate approval.

## Alternatives and Consequences

- Open a new visible console for each script: keeps that console visible but conflicts with the
  requested default and creates unnecessary interruptions for routine work.
- Hide and detach every command: avoids some visible windows but can obscure required interaction,
  lose useful execution evidence, and leave dependent work pending without a clear result.
- Quiet execution with observable completion and explicit interaction exceptions: selected by the
  existing rule. It preserves necessary user involvement without routinely opening extra windows.

Quiet options and process-launch behavior depend on the host, platform, and command. Use supported
mechanisms rather than assuming one flag works everywhere. Output can remain accessible in the
current tool or terminal; quiet does not mean suppressing diagnostics or promising zero windows.

This guidance does not retrofit existing launchers, disable authentication, change schedules, or
alter retry eligibility, ownership, or permissions. Any such implementation requires its own scope
and checks. The independent
[bounded test retry decision](2026-09-23-bounded-test-retry-defaults-adr.md) remains unchanged.

The preference can be revised through confirmed rule management with a superseding ADR.
No application migration, rollback mechanism, or new execution service is needed.

## Implementation and Verification

[Rules Core](../../../skills/core/rules/references/core.md) includes the quiet-execution default
under rule 2. The [detailed guidance](../../../skills/core/rules/references/ai-principles.md)
clarifies one-shot completion, background services, focus preservation, diagnostics, and permission
when quiet execution is unavailable.
The [instruction contracts](../../../scripts/test-skill-files.mjs) cover those boundaries and
preserve the four-rule structure. Those checks do not constitute an operating-system window audit.

The focused quiet-execution and existing rule-management contracts passed. Affected existing
managed rule copies follow the normal previewed, guarded refresh and source-parity checks; this
does not authorize new installations. The ADR's links, status, and whitespace are checked separately.
No accepted decision is superseded and no policy choice remains open from this interview.

## Read-Only Launcher Audit

Source inspection on 2026-09-27 found these existing gaps. No worker, scheduled task, login flow,
or popup reproduction was run during that audit. The findings below retain the pre-remediation
snapshot; the subsequently authorized fixes are recorded in Approved Remediation.

1. **Shared child-process launches do not suppress console creation.**
   [Invoke-HarnessProcess](../../../skills/planning/harness/scripts/harness-runner.ps1#L206)
   sets `UseShellExecute` to false and redirects output but leaves `CreateNoWindow` unset.
   The [.NET default is false](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.createnowindow).
   The [heartbeat's Execute path](../../../skills/planning/harness-timer/scripts/harness-heartbeat.ps1#L48)
   uses this helper to start each job. The outer
   [scheduled-worker launcher](../../../skills/planning/harness-timer/scripts/harness-scheduler.ps1#L303)
   sets `CreateNoWindow`, but that setting is not applied to the separate child launch. On Windows,
   a console executable started from that no-console worker can create a window. Capturing streams
   and waiting for exit do not replace a no-window launch setting.
2. **Unattended refresh inherits interactive credential behavior.**
   [Sync-Repo](../../../skills/core/skillvault-refresh/scripts/skillvault-fresh.ps1#L55)
   invokes Git fetch and clone using inherited credential settings. Its scheduler call supplies no
   noninteractive Git environment override. If a registered source requires authentication and
   usable credentials are unavailable, a configured helper can prompt or open a browser.
   [GCM permits interaction by default](https://raw.githubusercontent.com/git-ecosystem/git-credential-manager/main/docs/environment.md#GCM_INTERACTIVE).
   This depends on the inherited configuration and credentials, not on every refresh. The
   [PR command wrapper](../../../skills/github/pr-review/scripts/pr-review-runner.ps1#L12)
   already disables interactive Git/GCM prompts for its own unattended operations.
3. **Direct legacy timer actions omit window suppression.** The registration branches in
   [project timers](../../../skills/planning/harness-timer/scripts/harness-project-timer.ps1#L196),
   [PR timers](../../../skills/github/pr-review/scripts/pr-review-runner.ps1#L320), and
   [refresh timers](../../../skills/core/skillvault-refresh/scripts/skillvault-fresh.ps1#L309)
   build direct PowerShell actions without a hidden-window option. These can open consoles when
   used in an interactive Windows session. The
   [canonical timer dispatcher](../../../skills/planning/harness-timer/scripts/harness-timer.ps1#L115)
   uses prepared definitions and the shared heartbeat instead of those registration branches.
   This finding does not establish that any legacy task is currently installed or enabled.

The current heartbeat action requests `-WindowStyle Hidden`, and its worker wrapper explicitly
uses `CreateNoWindow`. Those are useful controls, not proof that every descendant or startup
transition is invisible. The reviewed process fixture checks output, exit codes, and input handling;
it does not observe Windows windows or VS Code focus. The audit also inspected bootstrap delegation,
which reuses the invoking shell. Third-party internals, live scheduler state, and host UI behavior
were not audited. At audit close, remediation was not approved and launcher code and schedules
were unchanged.

## Approved Remediation

On 2026-09-27 the owner explicitly requested fixing the three findings. The source changes keep
the accepted quiet-execution policy and do not supersede this decision:

1. The shared process runner now sets `CreateNoWindow = true`, retaining output/error capture,
   exit status, input handling, permission isolation, time budgets, and stop handling.
2. Source refresh scopes `GIT_TERMINAL_PROMPT=0` and `GCM_INTERACTIVE=Never` to repository access
   and restores previous values, including absent settings, on success or failure. Existing
   credentials and saved Git configuration are untouched. Network-command failures explain that
   interaction is disabled and attended authentication may be needed; they do not classify every
   network failure as an authentication error or turn a failed update into success.
3. Direct legacy project, PR, and refresh timer registrations now request `WindowStyle Hidden`
   and noninteractive PowerShell. Migration accepts the hidden option, still rejects unapproved
   alternatives, and retains existing identity, cadence, and enabled-state checks. No duration
   conversion was changed.

The focused process fixture checks the no-window assignment before launching children and verifies
their output, error, exit, permission, and input behavior. Existing refresh, scheduler, PR-review,
and harness fixtures passed with new prompt-setting, restoration, fake-timer, and migration checks.
The tests use temporary controllers/installations, fake Git/providers/agents, and fake OS task
registration. They do not constitute a desktop window or VS Code focus test.

The full repository gate passed: all 48 Node contracts, all fixture groups, catalog/resource
validation for 41 public skills and 30 project copies, and whitespace checks. A pre-existing
catalog-map omission for four reference entries was repaired separately before the successful run.

The existing managed `latest` copies of `harness`, `harness-timer`, `pr-review`, and
`skillvault-refresh` were previewed and refreshed in global and current-project scopes. All eight
copies passed source parity and dependency-interface checks; their installer companions already
matched and were left unchanged. No missing, pinned, or unrelated installation was replaced.
Existing OS task actions were not rewritten, enabled, disabled, or started; a live task-action
update still requires separate approval. Third-party application UI and the pre-existing whole-day
conversion in the direct legacy refresh branch remain outside this change.