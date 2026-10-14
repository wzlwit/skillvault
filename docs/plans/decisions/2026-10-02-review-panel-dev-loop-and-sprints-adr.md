# ADR: Review Panel, Development Review Loop, and Sprints

> Topic and command names in this record were updated to the current topics on 2026-10-07; see the [old-name retirement ADR](./2026-10-07-retire-old-names-adr.md).

- Date: 2026-10-02
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: Independent review in `/harness-review` and development runs, development fix rounds, reviewer concurrency, goal-based sprints in `/harness-work`, and setup-free defaults for review models, credit caps, and `/pr-review`.
- Supersedes: The development critical-review clause of the [September 24 baseline](./2026-09-24-recovery-compatibility-and-harness-baseline-adr.md#current-harness-baseline) and the "development Critical retains its change scope" part of decision 2 in the [September 18 ADR](./2026-09-18-upsert-and-harness-work-contracts-adr.md#decision). Standalone review continuation and the PR-review contract remain as accepted.
- Topic names superseded 2026-10-07: development and sprints are now `/harness-work run|queue|sprint`, and limits are `/harness-project policy limits`; the decisions below stand. See the [topic consolidation ADR](./2026-10-07-harness-topic-consolidation-adr.md).
- Superseded in part 2026-10-08: The [real-tests ADR](./2026-10-08-real-tests-in-development-loop-adr.md) runs the tests together with the Changes review and turns a test failure into a fix round, replacing the order and the "Validation failures still stop the task" sentence of decision 5. The rest of decision 5 stands.
- Superseded in part 2026-10-08: The [review-levels ADR](./2026-10-08-review-levels-adr.md) has reviewers report at a level, `critical` by default and always in development, so development's Full pass no longer reports unrelated pre-existing issues and the follow-up proposals of decision 6 become rare. The panel and the loop stand.
- Superseded in part 2026-10-08: At the owner's request, reviewers always start from the strongest allowed profile or listed model at `max` effort, and the owner ranks `gpt-6-astra` first. The runner's own model, often the session's, reviews only when restrictions allow nothing listed in its family; this replaces the runner-model step of decision 1. `runner.criticalReview: false` keeps the strongest allowed reviewer instead of the runner's model in decision 4. A session that runs the reviewers as sub-agents sets their model and effort explicitly.

## Context

The owner asked whether harness needed a separate `/hn-auto` command and chose two smaller changes
instead: development runs should reuse the standalone review loop with a stronger review, and
`/harness-work` should run goal-based sprints.

Before this change, standalone `/harness-review run` already repeated Changes, then one Full pass,
around fixes, with no fixed round count. Development ran Develop, Validate, a change-scoped Review,
and an optional Critical pass by the same model. Review findings stopped the task as `NeedsDecision`
and nothing re-ran it automatically. Every review pass used one model; PR review selects one approved
profile.

The owner then answered five questions. Q1, Q3, Q4, and Q5 took the recommended option. Q2 chose
parallel reviewers as the default. The owner then supplied the default model list (their VS Code model
picker) and asked that `/hn-project policy list limits` list the models and that the runtime check which are available.
Later that day the owner asked for AI credit caps to be unlimited unless explicitly restricted, and for
`/pr-review` and `/pr-watch` to work on their own, without a data root or other setup.

## Decision

1. **Two-family panel.** Each Changes and Full pass in `/harness-review` and development runs uses two
   independent read-only reviewers: the strongest allowed GPT model and the strongest allowed Claude
   Opus model. Each family takes runner-context `profiles` first, then an explicit runner model, then the
   bundled default list `harness-runtime/scripts/review-models.json`: the owner's picker models, strongest first,
   as CLI IDs. `allowedModels`, declared through `/harness-project policy limits`,
   narrows every source, and that view lists the models. Default candidates start at `max` effort and
   `long_context`. Findings are merged; a pass is clean only when both reviewers are clean, blocked when
   either is blocked, and has no new findings only when neither reports one. `/pr-review` keeps its
   single approved profile.
2. **Parallel by default (Q2).** The two reviewers run at the same time on the same pinned snapshot,
   inside the existing run lock. The new limit `maxParallelReviewers: 1` runs them one after the other.
   Runs stay serialized: one development, review, test, or monitor run per controller at a time. A
   failed reviewer fails its pass after both finish, with no automatic retry.
3. **Availability and one family (Q4).** The Copilot CLI has no command that lists models, but it
   rejects an unavailable model, or an effort level the model doesn't accept, before any model work.
   So the runtime checks availability as each reviewer starts: on such a rejection it tries the next
   lower effort, then the next model, at no cost, and records what it skipped. A family with no usable
   model is dropped; the remaining reviewer runs, and the result and report say "Only one reviewer
   ran" with the reason. If neither family has a usable model, the runner's own model (or `auto`)
   reviews alone. An explicit runner model or a PR profile is never replaced; a rejection fails that pass.
4. **Critical replaced (Q3).** The separate Critical phase is removed; the second-family reviewer takes
   its place. `runner.criticalReview` stays as the switch: explicit `false` keeps one reviewer, the
   runner's model. Tasks saved in the Critical phase resume at the Changes review.
5. **Development review loop.** Development runs Develop, Validate, then a Changes review. Findings
   start a fix round: the developer gets them as `reviewFindings`, then Validate and Changes run again.
   A clean Changes pass gets one Full pass; in-scope Full findings start another fix round. There is
   no fixed round count. The loop stops for a decision when a round makes no progress: the developer
   reports ready without changing code, or every finding from the previous round is reported again
   (matched by file and message, ignoring line numbers). A developer that disputes findings returns
   `needs-decision`. Validation failures still stop the task; there is no automatic test-fix loop.
   In scheduled runs each pickup takes at most one review round; the fix waits first in the resume
   queue, and each further round is another pickup counted by `maxTasksPerCycle`.
6. **Findings outside the task (Q1).** The Full reviewer marks a pre-existing issue that the task
   neither caused nor must fix with `outsideTaskScope: true`. Such findings become follow-up proposals
   on the task and in its report, and the task can complete. A proposal becomes a task only through
   explicit task intake.
7. **Sprints.** `/harness-work sprint` is a session workflow, not a runtime action. Plan: the user picks
   the goal and ready, Low-risk tasks. Run: each task goes through the development loop. Sprint review:
   a status draft through `harness-write`, and a PR through `pr-publish` only on explicit request. Retro:
   proposed rule or skill changes, applied only by a separate request. There is no calendar time-box;
   a sprint ends when its tasks are done or blocked. The sprint record lives under
   `.harness_sv/docs/sprints/`; the board stays the task source of truth.
8. **Default and versions (Q5).** The panel and loop are on by default. Because defaults change and the
   Critical phase is removed, the runtime, development, and review topics move to 2.0.0.
   the policy topic takes a minor version for the new limit and `harness-timer` a patch for timer
   sizing. The `harness-runtime` interface stays at 4 because existing callers, including PR review,
   keep their contract.
9. **Defaults instead of setup.** Limits apply only when declared: no AI credit cap is passed unless
   `runner.maxCredits`, `maxAgentCredits`, or a PR `maxCycleCredits` sets one, and the CLI's 30-credit
   minimum applies only to a declared cap. `/pr-review` and `/pr-watch` work from any folder with no
   harness Root, initialization, or data-root choice; they always use `~/.copilot/pr-review`. Every
   PR setting is optional: without saved settings, `run` uses github.com, one reviewer from the bundled
   list (strongest allowed first, skipping models the CLI rejects), and no time, PR-count, or credit
   limits, and its first run creates the controller. Saved settings override these, saved profiles
   are never replaced, and scheduling still needs saved `allowScheduled: true`. Because this new
   pr-review needs the harness list, it checks for it and asks to update both together when missing.

## Alternatives

| Alternative | Assessment |
| --- | --- |
| A separate `/hn-auto` command | Rejected: it would duplicate development and review ownership. |
| Reviewers one after the other by default | Kept as an option: no rule change, but about twice the review time. |
| Keep Critical as well | Rejected: another same-model session adds cost for little independent coverage. |
| Block when one family is unavailable | Rejected: every project where a family is excluded or unavailable would stop reviewing. |
| Require a one-time approved profile file | Rejected: the bundled default list works without setup; `allowedModels` narrows it. |
| Probe every listed model with a test call | Rejected: the CLI rejects unavailable models for free at launch, while a probe of an available model spends credits. |
| Fix out-of-scope Full findings inside the task | Rejected: tasks could grow without limit and leave their accepted scope. |
| A fixed fix-round cap | Rejected: conflicts with the accepted no-fixed-count rule; stop on no progress instead. |
| Opt-in panel | Rejected: the stronger review would stay unused unless each project enabled it. |
| Keep `/pr-review configure` mandatory | Rejected: every user would repeat a model, host, and budget setup that defaults already answer. |
| Default PR review to the two-reviewer panel | Not chosen: Q1-Q5 kept PR review at one reviewer; saved profiles can still choose any model. |

## Consequences

- Each review pass costs two reviewer sessions; parallel runs spend them at once. Per-session time and
  credit limits apply to each reviewer. A standalone round can use up to 4 sessions per snapshot and 12
  across its two snapshot restarts.
- The bundled list must be edited when the picker's models change. Stale entries cost a few seconds
  each at launch, since the CLI rejects them before model work; later passes in the same run reuse the
  choice that worked. The CLI's error wording is matched to recognize these rejections, so a changed
  wording makes a rejection fail the pass instead of moving on.
- Automatic fix rounds can spend more time and credits than the old stop at `NeedsDecision`. Pause and
  stop controls and the no-progress rule bound them, not a round cap. Exact-text recurrence can miss a
  reworded unresolved finding; the code-change requirement still applies every round.
- Project timer limits size review sessions per pass: parallel or single reviewers keep the old limits;
  one-after-the-other panels lengthen them.
- "Concurrency fixed at one" now means one run at a time; reviewers inside one pass may overlap.
- Without saved limits, a large watchlist or a long fix loop can spend more time and credits in one
  run. Saved PR limits, `maxAgentCredits`, and pause/stop bound it when wanted; the per-entry discovery
  limit (default five PRs) still applies.

## Implementation and Validation

The [current plan](../2026-09-15-harness-command-and-record-contracts.md#execution-and-review) owns the
operational detail. The shared runtime implements the panel, the bundled list, launch-time skipping,
process groups, and the loop. Focused fixtures cover the bundled list and its narrowing, family
selection, the observed CLI rejection messages, skipping models and effort levels, dropped families,
the one-family note, sequential and parallel panels, merged verdicts, fix rounds, both no-progress stops,
scheduled one-round ticks, proposals, and resumed Critical tasks. While verifying the list, the CLI was
probed with a few trivial calls. Implementation creates no schedule, installed copy, or publication.

## References

- [Development workflow](../../../skills/planning/harness-dev/references/dev.md)
- [Sprint workflow](../../../skills/planning/harness-dev/references/sprint.md)
- [Review workflow](../../../skills/planning/harness-review/references/workflow.md)
- [Restrictions](../../../skills/planning/harness-setup/references/limits.md)
- [Runtime guide](../../../skills/planning/harness-runtime/references/runtime.md)
