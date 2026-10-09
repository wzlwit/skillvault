
# Harness Tests

Contents: Start Here; Declare; Run; Scheduled and Post-Development Runs; Results and Boundaries.

Declare once and run the same test flow manually, on a timer, or as a development/fix gate.
Do not duplicate test frameworks: invoke the project's existing scripts, test runner, or test
methods through explicit executable/argument steps. Test-only execution does not require Copilot.

Use `/harness-monitor` to evaluate exported observations and propose incident-linked investigations.
An unhealthy service can be a successful monitor check; test process failures retain the Test
executor's exit-code semantics. Do not turn every repeated health observation into a new task.

## Start Here

1. Resolve the project, read and apply `/rules apply` and applicable project instructions, then
   read the installed `harness-runtime` guide and [test declarations](test-flows.md).
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
3. No arguments lists declared flows, environments, the `afterDev` and `afterReview` hooks, the
   unit-test level, and `pendingDefinitions` using the shared
   `harness-runtime/scripts/harness.ps1 -ProjectPath <root> -Action Test`. It is read-only and does
   not initialize state, create a declaration, or launch tests. `pendingDefinitions` names each JSON
   file under `.harness_sv/definitions/` that differs from the saved declarations, with its new or
   changed environments, flows, hooks, and unit-test level. These include held drafts, but also older
   files that later declarations passed; saving one of those would undo the later change, so check it
   before `test declare <file>`.

## Declare

`/harness-work test declare <JSON-file>` saves a declaration through the command below. It first shows
what the file adds or changes against the current declarations and asks to save; it saves on a yes or
after 1 minute without an answer, and `--hold`, or asking to hold, saves nothing until you say save
(Ask Once in the runtime guide):

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action TestConfig -DefinitionPath <JSON-file>
```

Resolve the declaration path against the project. For a prose request, derive steps from the
actual test framework, clarify unresolved commands or environment permissions, and author the
requested declaration before applying it. In layout 2, edit `config/tests.json` directly or use
this command to update that same authoritative file; no second imported active copy exists.
Read the existing configuration before any update.

`/harness-work test declare` without a file drafts that declaration from the coding repository, as
described under Invocation in [test declarations](./test-flows.md#invocation), then asks to save it
the same way.

Environment and flow definitions upsert by name; omitted definitions are preserved. Supplying
`afterDev` or `afterReview` replaces that hook list, and `unitTests` replaces the level; omitting
them preserves the saved values. Declaration validates and saves the configuration only. It never
provisions environments, runs setup/tests, installs a framework, creates a schedule, or silently
changes runner/model settings.

## Run

- `/harness-work test run <flow> [environment]` calls the shared script with `-Action Test -Flow <flow>`
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
- Honor `/harness-project policy limits` limits and `/harness-project policy fallback` safety pauses for every trigger. Only an explicitly
  `repeatable: true` named step may use approved transient retries, within the original budget.
  Report PolicyPaused without launching tests; never clear a pause merely to obtain a passing result.

## Scheduled and Post-Development Runs

`/harness-timer set project 12h test <flow> <environment>` runs that flow/environment every 12 hours;
`/harness-timer list` shows its id, which `disable <id>` and `resume <id>` take. The timer
skill owns schedule creation; declaration and manual tests never create one. The target must
explicitly permit scheduling with `allowScheduled: true`. Test timers are separate from the
development timer, but all use the same runner lock and flow implementation.

Put selected flow/environment pairs in `testing.afterDev` to run them with the first review pass
after `/harness-work run` development, fixes, and verification, and in `testing.afterReview` to run
them once on the reviewed code; [When Tests Run](./test-flows.md#when-tests-run) has the order and
what a failure does. Legacy `runner.validationCommands` still execute first. Named flows can also
supply the entire gate. Scheduled development also honors environment scheduling permission. An
explicit or inherited `runner.maxMinutes` caps each test phase; otherwise native limits apply. With
no configured commands/hooks, the runtime can discover `scripts/test-all.ps1` or the repository's
declared `npm test`; an empty check phase never passes.
Relative environment working directories resolve within the selected coding workspace, while
declarations, policies, and reports remain owned by the controller project. Choose existing
commands appropriate to that repository; a reference never infers test commands or permissions.

For another skill, explicitly call `/harness-work test run` afterward using the intended workspace/task.
There is no hidden hook on arbitrary skills. Fix work already belongs to `/harness-work`; no separate
`/harness-fix` skill is implied.

## Results and Boundaries

Report flow, method, environment, executed directory, Passed/Failed/Blocked/Busy/PolicyPaused status, actual
check exits, and report link. Ad-hoc/scheduled runs write a local report and history row; development
test results appear in the Validate and AfterReview reports. Already-paused calls create no new run/report. Include source snapshot evidence when Git is available,
but do not equate a source snapshot with the identity of a separately deployed localPPE service.
Include target/version checks in the project's flow when that identity matters.

Do not modify product code to make tests pass, suppress failures, deploy, reset a database,
publish feedback, commit, or push. Setup/cleanup commands require their own explicit scope in a
reviewed flow. Tests run as the configured OS user, not in a security sandbox. Keep credentials
out of declarations, command arguments, and captured logs. Installing this skill runs nothing.