# Test Declarations

Declarations are stored in the project's `.harness_sv/config.json` under `testing`. Existing
configurations without `testing` behave as an empty declaration set and keep legacy validation.
Use an existing project test-declaration file, or create the explicitly requested JSON file using
the project's documentation/configuration conventions. Import it with `/harness-test declare <file>`.

## Shape

The declaration file contains the sections below, not the entire harness config. This example
assumes the project already owns a `test` npm script. Replace it with verified commands from the
actual project; importing an example is not proof that its tests or environment are available.

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
      "steps": [
        { "name": "smoke-tests", "executable": "npm", "arguments": ["test"] }
      ]
    }
  ],
  "afterDev": [
    { "flow": "smoke", "environment": "local" }
  ]
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
- Optional step `repeatable` is a boolean, false by default. Set it true only after explicitly
  reviewing that repeating this command is safe. It enables no retry by itself: `/harness-policy fallback`
  must also declare that command's known transient exit codes. With those codes declared, omitted
  retry count/delay default to one additional attempt after five seconds. Explicit overrides remain
  effective, including `maxRetries: 0` to disable retries. Approved eligible retries need no further
  per-attempt confirmation. Attempts and delays share the original flow/validation time budget,
  and earlier steps are not rerun. Do not mark unknown external-write outcomes safe to repeat.
  Reports retain each attempted exit. A generic assertion failure is not transient by default.
- Steps stop at the first unrecovered failure/timeout. There is no automatic environment provisioning,
  reset, or guaranteed cleanup after a failed step. Use a reviewed wrapper with its own cleanup
  contract for flows that allocate resources.
- `afterDev` selects mandatory validation flows for feature/fix/verify tasks, before review.
  Flows run after existing `runner.validationCommands`, within the remaining validation budget.
  Passing tests alone never grants merge/deployment permission.

## Updates

Environment and flow arrays are merged by name, preserving unmentioned entries. If a name is
repeated within one declaration, validation fails. An explicitly supplied `afterDev` replaces
the entire list; `"afterDev": []` removes those hooks and is a policy change that must be requested.
Omitted sections stay unchanged. Invalid definitions do not overwrite the saved config.
Declaring flows requires a stopped runner; it does not cancel an active or interrupted run.

## Invocation

```text
/harness-test
/harness-test declare test-flows.json
/harness-test run smoke
/harness-test run smoke localPPE
/harness-test run smoke local --task T-001
/harness-timer 0.5 test smoke localPPE
/harness-timer status test smoke localPPE
/harness-timer disable test smoke localPPE
/harness-timer resume test smoke localPPE
```

Scheduling requires prior explicit `allowScheduled: true` for that environment. The shared timer
maps the test target to `-TestFlow` and `-TestEnvironment`, then the dispatcher to `-Action Test`,
`-Flow`, `-TestEnvironment`, and `-Scheduled`. It runs tests only, without selecting development
tasks or starting Copilot. Disable can target a removed flow by supplying both saved names;
resume rechecks the current declaration and prerequisites.

All triggers honor `/harness-policy limits` environment/launcher/directory limits and `/harness-policy fallback` durable
target pauses. A failed run counts once for `test:<flow>:<environment>` after retries, not once per
error line or attempt. Changing a flow, timer resume, or runtime recovery does not clear a safety
pause. Inspect the cause and explicitly resume that target before expecting another run.

Standalone reports and `history.csv` include flow, environment, timestamps, actual exits, and
the report path. Detailed output goes into the linked Markdown report. Post-development test
results are nested in the validation report. No additional competing test-state store is created.