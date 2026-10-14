# ADR: Review Levels

- Date: 2026-10-08
- Status: Accepted by delegation; owner review pending. The owner proposed a `critical|broad` option
  for `/hn-review`, with `critical` as the default: critical focuses on findings that block the PR or
  the fix for the current issue, and broad tries to find every possible issue. The agent asked which
  reviews the option should cover; the owner was not available, so the agent adopted its recommended
  answer (decision 4).
- Superseded in part 2026-10-09: `critical` is renamed `blocking`, with saved values still read;
  `runner.criticalReview` gets a clearer name; and development can review at `broad` through
  `/hn-dev broad`, replacing decision 4's rule that development always uses the default level. See the
  [bare, text, and menu convention ADR](./2026-10-09-bare-text-menu-convention-adr.md). What each level
  reports is unchanged.
- Decision owner: Zhaolong Wang
- Scope: What reviewers report in `/harness-review`, development runs, and `/pr-review`.
- Supersedes in part: decision 6 of the [review-panel ADR](./2026-10-02-review-panel-dev-loop-and-sprints-adr.md)
  for development runs, as described under Consequences. The panel and the loop stand.

## Context

Every reviewer was told to report every finding it could support, rated P1 to P3, and every finding
started another fix round or kept a standalone review open. The loop therefore ran until minor issues
were fixed too. The Full pass audited the whole repository, so pre-existing issues in unrelated code
joined the loop: as findings in standalone and PR reviews, and as follow-up proposals in development.
The owner wanted reviews to focus on what blocks the change by default, with a way to ask for everything.

## Decision

1. **Two levels.** `critical`, the default, reports only what blocks merging the change or completing
   its task: a defect or regression the change introduces; the change not achieving its purpose, such
   as the task's issue left unfixed; a security, permission, or data-loss risk; a broken public
   contract, or a caller, consumer, or configuration the change breaks; a crash or unhandled error on a
   realistic path; or a missing unit test the declared `unitTests` level calls for. Findings are rated
   P1 or P2. It does not report style, naming, refactoring ideas, performance without a concrete
   failure, speculative risks, or pre-existing issues the change neither causes nor depends on; a
   severe pre-existing security or data-loss issue noticed in passing goes in the reviewer's summary,
   not the findings. `broad` reports every issue with evidence, rated P1 to P3, including edge cases,
   performance, maintainability, documentation that no longer matches the code, test gaps, and
   pre-existing issues.
2. **Full pass by level.** The Full pass keeps its whole-repository coverage at both levels. At
   `critical` it looks only for what the change breaks or leaves inconsistent elsewhere: callers and
   consumers, other copies of the changed logic, configuration, contracts, and tests. At `broad` it
   audits the whole repository.
3. **Same loop.** Every reported finding still starts a fix round or keeps the review open, so the loop
   ends when the current level finds nothing more. Findings need evidence at both levels.
4. **Where the level applies.** `/harness-review run --broad` (`-ReviewLevel broad`) and
   `/pr-review run --broad` choose broad for one run, `--critical` names the default, and a PR URL given
   to `/harness-review` passes the level on. `/pr-review` also saves `reviewLevel` for list and timer
   runs, like `securityReview`; timer ticks take no per-run override. Development reviews always use
   `critical`, and the runtime dispatcher rejects `-ReviewLevel` on other actions.
   *Amended 2026-10-08:* under the concise rule in AGENTS.md, `--critical` is no longer offered: the
   default needs no option, and a plain request selects critical when `broad` is saved.
5. **Comparison by level.** A standalone review compares only with earlier reviews at the same level,
   so a critical review never rechecks findings from a broad one. Reviews recorded before levels existed
   reported every finding and count as `broad`. A PR snapshot already reviewed at broad also counts as
   reviewed for a later critical request; `--again` still forces a new review.
6. **Compatibility.** The runtime provides interface `review-levels` 1, which `harness-review` and
   `pr-review` require. `runner.criticalReview` is unrelated: it only decides whether the panel's
   second reviewer runs.

## Alternatives Not Chosen

- **A project setting for development** (`/harness-project policy set review critical|broad`), so the
  development loop could review at broad. Not chosen: development's job is to finish its task, and one
  more setting is not needed while `/harness-review run --broad` covers a wider audit. It can be added
  later without changing these levels.
- **Levels for `/harness-review` only**, leaving development and PR review reporting everything. Not
  chosen: the owner's description of `critical` names both the PR and the current issue's fix.
- **Listing non-blocking issues as notes at `critical`** without starting fix rounds. Not chosen: it
  splits the reviewers' attention and lengthens reports; the summary line keeps severe pre-existing
  issues visible.
- **Skipping the Full pass at `critical`.** Not chosen: it would miss callers and other copies of the
  logic that the change breaks outside the diff.

## Consequences

- Default reviews are narrower: fix loops end once blocking issues are fixed, and minor or unrelated
  pre-existing issues need an explicit `--broad` review.
- A reviewer may judge a real problem non-blocking and leave it out. A `--broad` review is the remedy.
- In development, the Full pass no longer reports unrelated pre-existing issues, so the follow-up
  proposals of the review-panel ADR's decision 6 become rare. `outsideTaskScope` still turns any such
  finding into a proposal instead of a fix round.
- Defaults change, so `harness-runtime` 3.0.0, `harness-review` 3.0.0, `harness-work` 2.0.0, and
  `pr-review` 2.0.0 carry this decision. Saved state needs no migration.
