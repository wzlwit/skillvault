# ADR: Real Tests in the Development Loop

- Date: 2026-10-08
- Status: Accepted. The owner confirmed it on 2026-10-14 in the
  [whole-project review](./2026-10-14-whole-project-review-adr.md); it was first accepted by delegation.
  The owner proposed running real tests after
  development (local, local PPE, PPE online), keeping unit tests to critical and realistic cases by
  default, and showing test methods in project context, and asked whether real tests belong before or
  after review. A grilling round put eight questions; the owner was not available to answer, and the
  session was told to continue, so the agent adopted its recommended answers. Decision 9 is the second
  round, answered the same way after a lookup of the owner's repositories. On 2026-10-08 at 17:20 the
  owner reviewed decision 5 and changed it from refusing external flows in `afterDev` to a warning.
- Decision owner: Zhaolong Wang
- Supersedes in part: the test order and the stop on test failures in decision 5 of the
  [review-panel ADR](./2026-10-02-review-panel-dev-loop-and-sprints-adr.md).
- Superseded in part 2026-10-09: the unit-test level `critical` in decision 7 is renamed `blocking`,
  with saved values still read, and `/hn-dev broad` raises it to `broad` for one task; see the
  [bare, text, and menu convention ADR](./2026-10-09-bare-text-menu-convention-adr.md).
- Superseded in part 2026-10-28: the Full pass is off by default, so in decisions 3 and 9 the review
  completes, and `afterReview` runs, after a clean Changes pass with passing tests; the Full pass
  comes first only when it's turned on. See the
  [Full pass off by default ADR](./2026-10-28-full-pass-off-by-default-adr.md).
- Scope: Which tests the development loop runs, when, what happens when they fail, and how much unit
  testing the developer adds.

## Context

After the developer finishes, the loop ran the declared `afterDev` flows, or else the repository's test
entry (`scripts/test-all.ps1`, then `npm test`), and only then the two-reviewer Changes pass. A failed
test left the task Failed at the Validate step: running it again only repeated the tests on the same
code, and the developer never saw the failure. Every declared test ran before review, on every fix
round.

The owner's teams test in three places: local, local PPE (pre-production), and PPE online. A lookup in
one of the owner's service repositories found that its local PPE mode runs the service on the developer
machine against shared PPE resources and writes shared state there, and that some scenarios wait
hours for a downstream pipeline. PPE online is reachable only after the pre-production release deploys
the change.

## Decisions

1. **PPE online is a post-deployment check, not part of a task.** Declare its environment and flow and
   run it with `/harness-work test run` or a test timer after deployments. A task's Completed still means
   verified in its workspace. Recording PPE results on the tasks a deployment contains is a later option.
2. **Declared flows are the only trigger.** The harness runs tests; the developer AI does not choose test
   commands for the loop. `/harness-work test declare` without a file drafts flows from the coding
   repository (its instructions, README, scripts, and pipelines) for the owner to approve, and nothing
   runs until a declaration is applied. `/harness-project context` shows "How this project is tested".
3. **Tests run while the first review reads the code.** The Validate step starts the declared tests in a
   background thread and runs the Changes review at the same time, on the same snapshot. Both results
   feed one fix round. The Full pass waits until the review is clean and the tests pass. If the review
   is blocked, or the code changes after the tests or a review, the task returns to this step, so a
   retry tests and reviews the current code again. Fixtures that replace runtime functions set
   `SKILLVAULT_INLINE_VALIDATION`, which runs the tests first in the same thread.
4. **A failed test becomes a fix round.** The exit code and the end of the output go to the developer as
   a finding with source `test`. The developer fixes the code, never weakening or skipping the test, or
   returns needs-decision when the environment caused the failure. If the same test fails again right
   after a fix round, the loop stops at NeedsDecision. Timeouts, stops, restrictions, and blocked starts
   keep their existing outcomes.
5. **External flows before review are allowed, with a warning (owner decision).** A flow that declares
   `effects: "external"` may be listed in `afterDev`, for example a local PPE test worth running every
   round. It then runs on code that review has not passed yet, so the declaration result and the
   context summary warn about it, and each Validate run that executed one notes it in the task and its
   report. `afterReview` stays the safer place for such flows. The agent first recommended refusing
   them; the owner chose the warning because some external tests belong in every round.
6. **Unattended runs keep the environment rule.** A scheduled run uses only environments with
   `allowScheduled: true`, after review too. Otherwise the task stops as Blocked until the owner runs it
   with `/harness-work run <task>`.
7. **The unit-test level is a test setting.** `unitTests` is `critical` (default) or `broad` in the test
   declarations; `/harness-project policy set unit-tests <level>` writes it through the same declaration.
   `critical` limits new unit tests to the defect being fixed, data loss, security or permissions, public
   contracts, and known regressions, using realistic cases. `broad` covers new and changed behavior and
   its main edge cases. The developer and the reviewers follow the same level; tests the repository
   requires still apply.
8. **No declared test still completes.** The task records the tests that ran. When no declared flow ran,
   the report and the task's `testsRun` say that only the repository's own tests ran.
9. **`afterReview` runs once, on the reviewed code.** A new list in the test declarations runs after the
   Full pass is clean, on that exact snapshot. A failure starts a fix round; the fix goes through the
   tests, the Changes and Full passes, and `afterReview` again. External flows such as a bounded local
   PPE smoke check fit here best; scenarios that take hours stay on demand.
10. **Compatibility.** The runtime provides a new interface, `development-tests` 1, which `harness-work`
    and `harness-project` require; `harness-runtime` 4 is unchanged for its other consumers. Existing
    declarations stay valid. The Validate run now includes the Changes pass, so a clean task records
    three runs instead of four.

## Alternatives Considered

- **All tests before review (the previous order).** Rejected: shared environments would receive unreviewed
  code, and slow tests would repeat on every fix round.
- **All tests after review.** Rejected: reviewers would spend credits on code that does not build or pass
  its unit tests, and every test failure would need another review.
- **Test methods described in context prose for the AI to run.** Rejected: runs would differ, nothing
  would prove what ran, and the AI could touch PPE with unreviewed code.
- **Stopping the reviewers when a test fails.** Rejected: it saves credits but loses findings the same
  fix round could address.
- **Refusing external flows in `afterDev`.** First adopted, then replaced by the owner with a warning:
  some external tests, such as local PPE, are worth running on every round.
- **Tracking deployments per task now.** Deferred: it needs release-pipeline and commit-inclusion data.

## Consequences

- A round takes as long as the slower of the tests and the Changes review, not both.
- A round whose tests fail still pays for a review; its findings go into the same fix round.
- Flows that write shared data, such as local PPE, should be declared `external`. Listed in `afterDev`
  they run on unreviewed code with a warning; listed in `afterReview` they run only on reviewed code.
- The runtime starts a PowerShell thread job for tests during review; when thread jobs are unavailable it
  runs the tests first.
