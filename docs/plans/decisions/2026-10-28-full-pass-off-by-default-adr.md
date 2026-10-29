# ADR: Full Pass Off by Default

- Date: 2026-10-28
- Status: Accepted. The owner asked that review paths turn the Full pass off by default, running it
  only when the user explicitly turns it on. The agent put five questions with recommended answers,
  and the owner took all five: every review path changes, a request or a saved setting turns the
  pass on, `broad` turns it on, the extra rule on unit tests follows, and the work builds on another
  chat's uncommitted runtime edits.
- Decision owner: Zhaolong Wang
- Scope: When the whole-repository Full pass runs in `/harness-review`, the `/harness-dev` loop, and
  `/pr-review`.
- Supersedes in part: decision 5 of the
  [review-panel ADR](./2026-10-02-review-panel-dev-loop-and-sprints-adr.md) and its 2026-10-16
  amendment, where every round ran Changes, then Full; decision 9 of the
  [real-tests ADR](./2026-10-08-real-tests-in-development-loop-adr.md), where `afterReview` waited
  for a clean Full pass; and the "Skipping the Full pass" alternative of the
  [review-levels ADR](./2026-10-08-review-levels-adr.md). Who runs the Full pass stays as the
  [one Full pass reviewer ADR](./2026-10-21-one-full-pass-reviewer-adr.md) decided.

## Context

Since 2026-10-02, each review round ran the Changes pass and then, when it found nothing new, a Full
pass that reads the whole selected repository. Standalone reviews could skip it with "changes only",
and their reports then called the review incomplete. Development and PR review always ran it. It is
the slowest pass of each round, and the owner saw it run long in day-to-day work.

## Decision

1. **Off by default.** A clean Changes pass completes a review; in development, it also needs passing
   tests. This holds for `/harness-review`, the `/harness-dev` loop, `/pr-review`, and a session that
   runs the reviewers as its own sub-agents.
2. **On when asked.** For one request: "full pass" (`-FullPass`), "both on full" (`-FullPanel`, which
   also runs both reviewers in it), or the `broad` level, whose Full pass is the whole-repository
   audit. Development saves "full pass" and "both on full" on the task, like `broad`, and any other
   named development request returns the task to the default. For every run: `runner.fullPass: true`
   in a harness project, or `fullPass: true` in the `/pr-review configure` settings, so scheduled runs
   can have it too. `runner.fullPanel` keeps choosing the reviewers and doesn't turn the pass on.
3. **"Changes only" stays.** `-ChangesOnly` skips the Full pass for one review even when a saved
   setting turns it on. A review it limits is complete when its Changes pass is clean.
4. **No changes.** With the Full pass off, a review with no changes returns `NoChanges` and starts no
   reviewer. With it on, the Full pass runs alone, as before.
5. **After-review tests.** `testing.afterReview` flows run once after the review is clean: after the
   Changes pass when the Full pass is off, or after the Full pass when it's on.
6. **Tasks already waiting.** A task saved at the Full pass before it was turned off completes without
   one, running its after-review tests first when it has them.
7. **Records.** Standalone results and run records add `fullPass`, PR review records and reports add
   it too, and reports say when the Full pass was off. A PR review saved without the field ran the
   Full pass, so it still counts as covering a later request for one.
8. **Versions.** A default changes, so `harness-runtime` 7.0.0, `harness-review` 7.0.0, `harness-dev`
   6.0.0, and `pr-review` 4.0.0 carry this decision. The runtime provides interface `full-pass` 2,
   with `-FullPass`, and all three topics require it. The extra rule "Run unit tests once the review
   is clean" now counts the Full pass only when it's on (`rules` 4.3.1).

## Alternatives Not Chosen

- **Only `/harness-review` and `/harness-dev`.** `/pr-review` would have kept a Full pass the other
  paths dropped. The owner chose all three paths.
- **A request word only, with no saved setting.** Scheduled development and PR reviews take no words,
  so they could never run the Full pass.
- **Keeping `broad` without the Full pass.** `broad` exists for the whole-repository audit; without
  the pass, it would only widen what the Changes pass reports.
- **Removing "changes only".** It still overrides a saved setting for one quick review.
- **Treating `runner.fullPanel: true` as turning the pass on.** It answers who runs the Full pass,
  not whether it runs; projects that set it keep the new default.

## Consequences

- A default review round uses up to two reviewer sessions instead of three, so a standalone review's
  churn bound is 6 attempted sessions across two local restarts, 9 with the Full pass, or 12 with
  both reviewers in it.
- By default, nothing reads unchanged code for what a change breaks elsewhere. The Changes pass still
  reads the callers and tests it needs, and "full pass", `broad`, or a saved setting brings the whole
  repository back when a change warrants it.
- `/pr-review` still reserves two per-session ceilings of a cycle's credits for each PR, so a PR
  review without the Full pass gets no larger share of the cycle budget than before.
- `scripts/test-harness.ps1` keeps its Full pass coverage with `runner.fullPass: true` and adds the
  default, the request, `broad`, the saved task request, "changes only" over the setting, the
  `NoChanges` result, and a task already waiting at the Full pass. `scripts/test-pr-review.ps1`
  covers the PR setting and request.

## References

- [Review-panel ADR](./2026-10-02-review-panel-dev-loop-and-sprints-adr.md)
- [Real-tests ADR](./2026-10-08-real-tests-in-development-loop-adr.md)
- [Review-levels ADR](./2026-10-08-review-levels-adr.md)
- [One Full pass reviewer ADR](./2026-10-21-one-full-pass-reviewer-adr.md)
- [Runtime guide: Full Pass](../../../skills/planning/harness-runtime/references/runtime.md#full-pass)
