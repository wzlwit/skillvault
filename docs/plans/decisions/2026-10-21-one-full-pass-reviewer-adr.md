# ADR: One Full Pass Reviewer

- Date: 2026-10-21
- Status: Accepted. The owner asked that the Full pass at the end of the review loop run one reviewer
  by default, the Claude Opus one, and both only when a request asks for them or a setting enables the
  GPT reviewer. The session ran under Autopilot, so the agent chose the setting name, saving the
  request on development tasks, and the fallbacks below without asking; the owner can change them.
- Decision owner: Zhaolong Wang
- Scope: The reviewers of the Full pass in `/harness-review` and development runs.
- Supersedes in part: decision 1 of the
  [review-panel ADR](./2026-10-02-review-panel-dev-loop-and-sprints-adr.md), for the Full pass only.
  The Changes pass keeps both reviewers.
- Amended 2026-10-28: the Full pass itself is now off by default, so these decisions apply when it's
  turned on; see the [Full pass off by default ADR](./2026-10-28-full-pass-off-by-default-adr.md).

## Context

Since 2026-10-02, every Changes and Full pass has run two reviewers: the strongest allowed GPT and
Claude Opus models, at `max` effort. The Full pass runs once after each clean Changes pass and reads
the whole selected repository, so two reviewers there doubled the most expensive pass of each round.
The owner judged one Claude Opus reviewer enough for it by default.

## Decision

1. **One reviewer by default.** The Full pass runs the panel's Claude Opus reviewer alone. The
   Changes pass keeps both reviewers.
2. **Both when asked.** Plain words such as "both on full" add the GPT reviewer to one review's Full
   pass (`Review -FullPanel`). In development, the same words save the request on the task
   (`Dev -FullPanel`), as `broad` is saved, so a later pickup's Full pass keeps it; any other named
   development request returns the task to one reviewer. `runner.fullPanel: true`, in the project
   configuration or the session's runner context, makes both reviewers the project's default.
3. **Fallbacks.** Without a usable Claude Opus reviewer, because restrictions exclude the family,
   `runner.secondReviewer` is false, or the CLI accepted no Claude Opus model in the Changes pass, the
   remaining reviewer runs the Full pass. When the CLI accepts no Claude Opus model in the Full pass
   itself, the GPT reviewer takes its place there, so the runner's own model still never replaces a
   listed reviewer that is available. A reviewer the CLI rejected is not tried again in later passes
   of the same run.
4. **Visibility.** Reports name the Full pass reviewers. Standalone review results and run records add
   `fullPassReviewers` and `fullPassNote`, and the panel view (`Context` and
   `/harness-setup policy list limits`) adds `fullPass`, the models the Full pass starts with. A
   session that runs the reviewers as its own sub-agents starts only the Claude Opus one for the Full
   pass unless both are asked for.
5. **Unchanged.** `/pr-review` keeps its one approved profile. `runner.secondReviewer: false` still
   keeps one reviewer in every pass, GPT first. Review levels, the fix loop, and its stopping rules
   stay as they were.
6. **Compatibility and versions.** The default changes, so `harness-runtime` 6.0.0, `harness-review`
   6.0.0, and `harness-dev` 5.0.0 carry this decision. The runtime provides interface `full-pass` 1,
   which `harness-review` and `harness-dev` require because both document `-FullPanel`. Saved state
   needs no migration: tasks and configurations without `fullPanel` get one reviewer.

## Alternatives Not Chosen

- **A count of Full pass reviewers** (`runner.fullReviewers: 1|2`). A true-or-false setting says the
  same thing, like `runner.secondReviewer`.
- **A setting named for the GPT family**, such as `gptFullReview`. `fullPanel` keeps family names in
  the review model list rather than in settings.
- **Naming the Full pass family in `review-models.json`.** The owner named Claude Opus, and one
  constant in the runtime is simpler; the choice can move to the list if the owner wants to switch
  families.
- **A per-run request only, not saved on development tasks.** A scheduled pickup can reach the Full
  pass in a later run, which would lose the request; saving it on the task matches `broad`.
- **The runner's own model when the CLI rejects Claude Opus in the Full pass.** Since 2026-10-08,
  listed reviewers come before the runner's model, and the GPT reviewer is listed.
- **A shorter time limit for the older OS review timers.** `harness-schedule` still sizes them for
  two reviewers per pass when reviewers run one after the other; that only leaves room under the
  ceiling.

## Consequences

- A default Full pass uses one reviewer session instead of two. A standalone review round uses up to
  three sessions, two in the Changes pass and one in the Full pass, so its churn bound is 9 attempted
  sessions across two local restarts, or 12 with both reviewers in the Full pass.
- By default the Full pass loses the GPT reviewer's independent view, so an issue only GPT would find
  outside the diff can go unreported unless a request asks for both.
- Reports and run records gain the Full pass reviewer fields; earlier records stay as written.
- `scripts/test-harness.ps1` covers the default, the request, the setting, the request saved on a
  task, the panel view, and the GPT reviewer standing in when the CLI rejects Claude Opus.

## References

- [Review-panel ADR](./2026-10-02-review-panel-dev-loop-and-sprints-adr.md)
- [Review-levels ADR](./2026-10-08-review-levels-adr.md)
- [Runtime guide: Full Pass](../../../skills/planning/harness-runtime/references/runtime.md#full-pass)
