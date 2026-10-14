# Test Declarations

Contents: Shape; Meaning; When Tests Run; Updates; Invocation.

Layout-2 declarations are authoritative in `.harness_sv/config/tests.json`, combined as `testing`
only in memory. Direct edits and `/harness-dev test declare <file>` update that same configuration;
no separate editable active copy exists. Legacy controllers keep their flat config until their layout
is converted; those without `testing` retain their existing legacy validation behavior.

## Shape

The declaration file contains the sections below, not the entire harness config. This example
assumes the project already owns a `test` npm script and a reviewed PPE smoke wrapper. Replace them
with verified commands from the actual project; importing an example is not proof that its tests or
environment are available.

```json
{
  "environments": [
    {
      "name": "local",
      "workingDirectory": ".",
      "variables": { "TEST_TARGET": "local" },
      "requiredVariables": [],
      "allowScheduled": false
    },
    {
      "name": "localPPE",
      "workingDirectory": ".",
      "variables": { "TEST_TARGET": "localPPE" },
      "requiredVariables": ["LOCALPPE_TEST_URL"],
      "allowScheduled": false
    }
  ],
  "flows": [
    {
      "name": "smoke",
      "method": "Run the project's existing smoke-test suite against TEST_TARGET",
      "defaultEnvironment": "local",
      "maxMinutes": 10,
      "effects": "local",
      "steps": [
        { "name": "smoke-tests", "executable": "npm", "arguments": ["test"] }
      ]
    },
    {
      "name": "ppe-smoke",
      "method": "Start the service against PPE and run a bounded smoke scenario",
      "defaultEnvironment": "localPPE",
      "maxMinutes": 20,
      "effects": "external",
      "steps": [
        { "name": "smoke", "executable": "pwsh", "arguments": ["-NoProfile", "-File", "scripts/ppe-smoke.ps1"] }
      ]
    }
  ],
  "afterDev": [
    { "flow": "smoke", "environment": "local" }
  ],
  "afterReview": [
    { "flow": "ppe-smoke", "environment": "localPPE" }
  ],
  "unitTests": "blocking"
}
```

## Meaning

- Names use letters, digits, dots, underscores, or hyphens. Supply exact declared names when
  managing schedules. Unknown names are errors, not aliases for local or another environment.
- `workingDirectory` is relative to the tested workspace unless absolute. Post-dev tests use
  the task's current checkout or worktree. Standalone tests use the project workspace unless a
  task ID selects a saved workspace. An absolute directory intentionally targets that directory;
  it does not guarantee that it contains the task's current code.
- `variables` is a JSON object of non-secret child-process overrides. `requiredVariables` lists
  names that must have values in those overrides or the calling process environment. Set secrets
  securely in the execution environment; never embed them in JSON or command arguments.
- `allowScheduled` is an explicit boolean. False still permits a user-requested ad-hoc run but
  blocks both test timers and scheduled post-development tests against that environment. Changing
  it does not create a schedule. Check credentials/access under the actual scheduled-task account.
- A flow declares its purpose/method, default environment, positive time budget, and ordered
  steps. Each step uses an executable plus an argument array; there is no implicit shell-command
  parsing or special test framework. Use the existing runner's filters to select test classes,
  methods, scenarios, or suites. Include explicit readiness/version checks when required.
- A zero exit code means that command succeeded according to the declared test runner. Require
  commands that return nonzero on failure, and inspect runner reports when skipped/no-test results
  matter. This wrapper does not invent test counts or turn missing environments into passes.
- Optional flow `effects` is `local` or `external`. `local` states that the flow writes only local
  files, such as drafts and reports, and never posts, changes another system, or changes code.
  `external` means it deploys or writes somewhere else, such as shared PPE data. A
  `/harness-monitor` feed producer or standing-intake worker must declare `local`. An `external` flow
  in `afterDev` is allowed with a warning, described under When Tests Run. The harness cannot verify
  the statement, so review the commands first.
- Optional step `repeatable` is a boolean, false by default. Set it true only after explicitly
  reviewing that repeating this command is safe. It enables no retry by itself: the failure policy
  (`/harness-setup policy set fallback <file>`) must also declare that command's known transient exit codes. With those codes declared, omitted
  retry count/delay default to one additional attempt after five seconds. Explicit overrides remain
  effective, including `maxRetries: 0` to disable retries. Approved eligible retries need no further
  per-attempt confirmation. Attempts and delays share the original flow/validation time budget,
  and earlier steps are not rerun. Do not mark unknown external-write outcomes safe to repeat.
  Reports retain each attempted exit. A generic assertion failure is not transient by default.
- Steps stop at the first unrecovered failure/timeout. There is no automatic environment provisioning,
  reset, or guaranteed cleanup after a failed step. Use a reviewed wrapper with its own cleanup
  contract for flows that allocate resources.
- `unitTests` is `blocking` (the default when omitted) or `broad`. It tells the developer how much
  unit testing to add and the reviewers what a missing test means: `blocking` covers the defect being
  fixed, data loss, security or permissions, public contracts, and known regressions, with realistic
  cases; `broad` covers new and changed behavior and its main edge cases. Tests the repository
  requires still apply. `/harness-setup policy set unit-tests <level>` writes the same field, and
  `/harness-dev broad <task>` raises one task's unit tests to `broad` together with its reviews.

## When Tests Run

The harness runs tests; the developer AI does not choose them. Only these lists put a flow into a
task's development loop:

- `afterDev` flows run after `runner.validationCommands`, at the same time as the first (Changes)
  review pass, on the same code. With neither declared, the harness runs the repository test entry
  (`scripts/test-all.ps1`, then `npm test`) and stops as Blocked when none exists. A failed test goes
  back to the developer with the end of its output, together with any review findings, as one fix
  round; the Full pass waits until both are clean. If the same test fails again right after a fix
  round, the loop stops for a decision. Timeouts, stops, and blocked starts keep their outcomes. A
  blocked review, or code that changes after the tests or a review, sends the task back to these
  tests, so a retry never skips them.
  An `external` flow, such as a local PPE test you want every round, may be listed here. It then
  runs on code that review has not passed yet, so the declaration result and the context summary
  carry a warning, and each run's report notes that it ran before review was clean.
- `afterReview` flows run once after the Full pass is clean, on that exact code. A failure starts a
  fix round that goes through the tests and both review passes again. This is the safer place for
  flows that write shared data or take long, such as a bounded local PPE smoke check. A repeat
  failure of the same flow stops for a decision.
- Scheduled runs use only environments with `allowScheduled: true`, in both lists. Otherwise the
  task stops as Blocked until someone develops it with `/harness-dev <task>`.
- A flow in neither list runs only on demand or on a timer. Use this for checks that need a
  deployment first, such as PPE online: declare its environment and run it after each release.
  A task's Completed means verified in its workspace, not deployed.

Each task records the tests that ran (`testsRun`); when no declared flow ran, its report says
that only the repository's own tests ran. Passing tests alone never grant merge or deployment
permission.

## Updates

Environment and flow arrays are merged by name, preserving unmentioned entries. If a name is
repeated within one declaration, validation fails. An explicitly supplied `afterDev` or
`afterReview` replaces that entire list; an empty list removes those hooks and is a policy change
that must be requested. `unitTests` replaces the saved level. Omitted sections stay unchanged.
Invalid definitions do not overwrite the saved config. Declaring flows requires a stopped runner;
it does not cancel an active or interrupted run.

## Invocation

```text
/harness-dev test
/harness-dev test declare
/harness-dev test declare test-flows.json
/harness-dev test run smoke
/harness-dev test run smoke localPPE
/harness-dev test run smoke local --task T-001
/harness-schedule project 12h test smoke localPPE
/harness-schedule
/harness-schedule <id> off
/harness-schedule <id> on
```

`test declare` without a file drafts a declaration from the coding repository: its agent
instructions, README, test projects, scripts, and pipelines. Save the draft under
`.harness_sv/definitions/`, show it with the effects and lists you chose, and ask to save it: it saves
on a yes or after 1 minute without an answer, unless held. Never guess a command or mark a flow `local` without reading what it does; leave a
method you could not verify out of the draft and say so.

Scheduling requires prior explicit `allowScheduled: true` for that environment. The shared timer
maps the test target to `-TestFlow` and `-TestEnvironment`, then the dispatcher to `-Action Test`,
`-Flow`, `-TestEnvironment`, and `-Scheduled`. It runs tests only, without selecting development
tasks or starting Copilot. `/harness-schedule` alone shows each schedule's id; `<id> off` works even
after the flow is removed, and `<id> on` rechecks the current declaration and prerequisites.

All triggers honor the environment, launcher, and directory limits and the durable target pauses set
through `/harness-setup policy`. A failed run counts once for `test:<flow>:<environment>` after retries, not once per
error line or attempt. Changing a flow, turning a schedule back on, or runtime recovery does not clear a safety
pause. Inspect the cause and explicitly resume that target before expecting another run.

Standalone reports and `history.csv` include flow, environment, timestamps, actual exits, and
the report path. Detailed output goes into the linked Markdown report. Development test results are
nested in the Validate and AfterReview reports. No additional competing test-state store is created.