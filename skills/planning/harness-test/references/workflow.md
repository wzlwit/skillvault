
# Harness Tests

Declare once and run the same test flow manually, on a timer, or as a development/fix gate.
Do not duplicate test frameworks: invoke the project's existing scripts, test runner, or test
methods through explicit executable/argument steps. Test-only execution does not require Copilot.

Use `/harness-monitor` to evaluate exported observations and propose incident-linked investigations.
An unhealthy service can be a successful monitor check; test process failures retain the Test
executor's exit-code semantics. Do not turn every repeated health observation into a new task.

## Start Here

1. Resolve the project, read and apply `/rules apply` and applicable project instructions, then
   read the installed `harness` runtime guide and [test declarations](test-flows.md).
  Follow its Script Permissions and Agent Fallback procedure before dispatcher or test scripts;
  reuse approvals and request only missing command-scoped access before execution. An attended
  agent fallback can use an approved test tool that actually runs the required checks. Otherwise
  report tests as unverified; inspecting code is not a passing test or a completed harness run.
    Runner Inheritance also supplies parent/current restrictions and resource ceilings through
    `-RunnerContext` or `-RunnerContextPath`. Missing optional runner allowances do not require an
    AI profile or extra configuration for tests; actual flow/environment prerequisites still apply.
2. Inspect the relevant existing test commands and environment documentation. `local` and
   `localPPE` are project-defined targets, not interchangeable labels or proof of provisioned
   infrastructure. Do not invent endpoints, credentials, test results, or approval to reset data.
3. No arguments lists declared flows, environments, and `afterDev` hooks using the shared
   `harness/scripts/harness.ps1 -ProjectPath <root> -Action Test`. It is read-only and does
   not initialize state, create a declaration, or launch tests.

## Declare

`/harness-test declare <JSON-file>` imports a reviewed declaration through:

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action TestConfig -DefinitionPath <JSON-file>
```

Resolve the declaration path against the project. For a prose request, derive steps from the
actual test framework, clarify unresolved commands or environment permissions, and author the
requested declaration before importing it. Read the existing configuration before any update.

Environment and flow definitions upsert by name; omitted definitions are preserved. Supplying
`afterDev` replaces that hook list; omitting it preserves the list. Declaration validates and
saves the configuration only. It never provisions environments, runs setup/tests, installs a
framework, creates a schedule, or silently changes runner/model settings.

## Run

- `/harness-test run <flow> [environment]` calls the shared script with `-Action Test -Flow <flow>`
  and optional `-TestEnvironment <environment>`. Omitted environment uses the flow's declared
  default, never a guessed fallback.
- Optional `--task <task-id>` maps to `-Id <task-id>`: use its saved workspace when present and
  link evidence to that task. If the task selects a repository reference but has no workspace yet,
  test that local repository checkout without allocating a development worktree. Revalidate the
  active reference and saved-worktree ownership. With no task/repository selection, test the
  controller project workspace. Passing tests does not complete or requeue development.
- Require initialized harness state and available rules; do not initialize as a side effect of
  running tests. Required directories, variable names, and executables are checked before steps.
  A missing target/prerequisite is Blocked, not Passed. Do not supply missing secrets through chat.
- Steps execute in order, fail fast, and share the flow's time budget. Environment overrides apply
  only to the child process. Honor the harness run lock: report Busy rather than running alongside
  development or another test flow in the same project.
- Honor `/harness-policy limits` limits and `/harness-policy fallback` safety pauses for every trigger. Only an explicitly
  `repeatable: true` named step may use approved transient retries, within the original budget.
  Report PolicyPaused without launching tests; never clear a pause merely to obtain a passing result.

## Scheduled and Post-Development Runs

`/harness-timer 0.5 test <flow> <environment>` configures that flow/environment every 12 hours.
Use `status`, `disable`, or `resume` in place of the interval for the same exact target. The timer
skill owns schedule creation; declaration and manual tests never create one. The target must
explicitly permit scheduling with `allowScheduled: true`. Test timers are separate from the
development timer, but all use the same runner lock and flow implementation.

Put selected flow/environment pairs in `testing.afterDev` to run them in the existing validation
phase after `/harness-dev` development, fixes, and verification, before independent review. Legacy
`runner.validationCommands` still execute first. Named flows can also supply the entire gate.
Any failure or blocked flow prevents completion; scheduled development also honors environment
scheduling permission. An explicit or inherited `runner.maxMinutes` caps the total validation phase;
otherwise native limits apply. With no configured commands/hooks, the runtime can discover
`scripts/test-all.ps1` or the repository's declared `npm test`; an empty check phase never passes.
Relative environment working directories resolve within the selected coding workspace, while
declarations, policies, and reports remain owned by the controller project. Choose existing
commands appropriate to that repository; a reference never infers test commands or permissions.

For another skill, explicitly call `/harness-test run` afterward using the intended workspace/task.
There is no hidden hook on arbitrary skills. Fix work already belongs to `/harness-dev`; no separate
`/harness-fix` skill is implied.

## Results and Boundaries

Report flow, method, environment, executed directory, Passed/Failed/Blocked/Busy/PolicyPaused status, actual
check exits, and report link. Ad-hoc/scheduled runs write a local report and history row; post-dev
results appear in the validation report. Already-paused calls create no new run/report. Include source snapshot evidence when Git is available,
but do not equate a source snapshot with the identity of a separately deployed localPPE service.
Include target/version checks in the project's flow when that identity matters.

Do not modify product code to make tests pass, suppress failures, deploy, reset a database,
publish feedback, commit, or push. Setup/cleanup commands require their own explicit scope in a
reviewed flow. Tests run as the configured OS user, not in a security sandbox. Keep credentials
out of declarations, command arguments, and captured logs. Installing this skill runs nothing.