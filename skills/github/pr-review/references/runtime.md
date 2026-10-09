# User-Wide PR Review Runtime

Contents: Storage and Dependencies; Optional Configuration; One Timer; Pauses, Recovery, and
Results.

## Storage and Dependencies

The default controller root is `~/.copilot/pr-review`, not the current repository and not an
installed skill folder. PR review, watchlist actions, and the PR timer route share it across projects;
no harness Root, initialization, or `-DataRoot` choice is needed:

| Path under the root | Purpose |
| --- | --- |
| `watchlist.json` | Exact PR/repository entries, stable W- IDs, repository filters |
| `.harness_sv/config/` | Optional saved PR settings and shared runner/restriction/fallback settings (a legacy `.harness/` controller keeps its files) |
| `.harness_sv/runtime/state.json` | Shared review runs, durable pauses, PR result history, and the review in progress |
| `reports/pr/` | PR-level status, verified revisions, findings, and engine evidence links |
| `reports/history/` | Shared review evidence and snapshots |
| `workspaces/` | Isolated fetched PR checkouts retained for evidence |

List, results, and removal previews do not initialize storage. Add creates only the watchlist. The
first review run or explicit configuration initializes the dedicated controller, never the
source/target project's harness.
Removal only unregisters the selected watch; it does not delete reports, checkouts, or remote PRs.
There is no implicit retention cleanup. `-DataRoot` exists for isolated tests or an explicitly
approved relocation of the one controller, not automatic project-specific lists/timers.

Use PowerShell 7, Git, authenticated `gh`, and an approved Copilot CLI supporting prompt stdin,
`--context`, `--reasoning-effort`, `--no-custom-instructions`, the existing read-only tool flags,
and `--max-ai-credits` (minimum 30 when a cap is declared). Install `harness-runtime` beside `pr-review`
and make Rules Core available globally or through `runner.rulesPath`. Install `differential-review`
globally when security mode is requested. No tool installation, login, connector setup, or
permission widening is automatic.

The dispatcher is `scripts/pr-review.ps1` in the installed `pr-review` bundle. In examples below,
`$review` means its verified absolute path. Do not point a persistent task at an ephemeral copy.

```powershell
& $review -Action List
& $review -Action Results
& $review -Action Add -Url https://github.com/owner/repository -Limit 5
& $review -Action Remove -Selector W-001
& $review -Action Remove -Selector W-001 -Apply
& $review -Action Review -Url https://github.com/owner/repository/pull/123
& $review -Action Review -Url https://github.com/owner/repository/pull/123 -ReviewLevel broad
& $review -Action Review
```

An enabled timer reads the current list on each tick, so a newly added entry becomes eligible
then. Adding does not run it immediately. Unknown/removed GitHub hosts are blocked by the saved
host allowlist; URLs cannot contain credentials, query strings, or non-HTTPS endpoints.

## Optional Configuration

Nothing needs configuring before `run`. Without saved settings, PR review uses:

| Setting | Default |
| --- | --- |
| `profiles` | The harness review model list (`harness-runtime/scripts/review-models.json`), strongest first |
| `githubHosts` | `github.com` |
| `maxPullRequests`, `maxCycleMinutes`, `maxCycleCredits` | No limit; per-entry discovery limits still apply |
| `allowScheduled` | `false`; set it to `true` before timer setup |
| `securityReview` | `false`; ad-hoc `-SecurityReview` can request it per run |
| `reviewLevel` | `critical`: report only what blocks merging the PR; `broad` reports every issue with evidence. Ad-hoc `-ReviewLevel` can choose either per run |

To override any of these, use a JSON definition with `runner`, `prReview`, or both, preview it, then
apply the exact approved contents. Every field is optional; omitted fields keep their defaults. A
supplied `prReview` replaces the saved one; an omitted `prReview` keeps it. Restrictions, fallback,
history, and pauses are unchanged. Configuring is not approval to enable scheduling or to start work.

Illustrative structure only: the model and numbers below are not defaults, verified availability,
or authorization. Choose them with the owner before writing/applying a real definition.

```json
{
  "prReview": {
    "profiles": [
      {
        "model": "choose-a-verified-model",
        "efforts": ["high", "max"],
        "contexts": ["default", "long_context"]
      }
    ],
    "maxPullRequests": 5,
    "allowScheduled": true
  }
}
```

```powershell
& $review -Action Configure -DefinitionPath <approved-file>
& $review -Action Configure -DefinitionPath <approved-file> -Apply
```

- Saved `profiles` are strongest-first, not sorted by model name. Verify account access and the
  actual per-model supported choices in the attended host/CLI before declaring them. The first
  profile allowed by `restrictions.allowedModels` runs at the highest effort and context in its
  declared sets intersected with current CLI help. A saved profile is never replaced: a
  provider/model failure blocks that review.
- Default models follow the harness Review Panel rules, as one reviewer: `allowedModels` narrows
  the list, each model starts at `max` effort and `long_context`, and a model or effort the CLI
  rejects before any model work is skipped at no cost. The PR report shows the requested model and,
  when different, the model and effort that actually reviewed. If no listed model starts, the
  review fails with the models tried. `Unchanged` compares the requested settings.
- Effort order is max, xhigh, high, medium, low, minimal, none. Context order is long_context,
  default. The whole prompt, evidence included, goes to the CLI on standard input, so its size isn't
  limited by the command line; workers read complete relevant code.
  Context tier is a request, not a fabricated exact token count or assurance of adequate coverage.
- Missing/null runner values inherit the current controller settings. With no per-agent limits,
  `maxMinutes` uses `maxCycleMinutes` and `maxCredits` uses `maxCycleCredits` when those are saved;
  preview shows `effectiveRunner`. Empty/blank and `None`/`Max` placeholders count as omitted.
  Empty model allowance lists add no restriction; concrete lists still filter the profiles.
- `runner.maxMinutes`/`maxCredits` bound each session. Restrictions can only tighten them.
  A saved `maxCycleMinutes` also bounds collection/fetch subprocesses and reserves time for both
  passes. A saved `maxCycleCredits` reserves at most two per-session ceilings per reviewed PR; it is a
  conservative CLI ceiling allocation, not measured provider usage, account balance, or a daily
  quota. Each session's share must stay at least 30 AI credits, the CLI minimum, or that review is blocked.
- A saved `maxPullRequests` bounds new/repeated review attempts per cycle. Each repository's list
  entry separately limits discovery (default five, maximum 100), ordered by recent updates. Explicit
  PRs and repository results deduplicate. Open PRs are selected; closed/merged targets are
  reported without launching reviewers. Explicit PR URLs can select drafts.
- `allowScheduled` must be saved as true before timer setup. `securityReview` chooses the saved
  methodology for list/timer runs; ad-hoc `-SecurityReview` can request it without changing settings.
- `reviewLevel` chooses the review level for list/timer runs (Review Levels in the harness runtime
  guide); ad-hoc `-ReviewLevel critical|broad` (`--broad`, or a plain request for critical) chooses
  it for one run without changing settings, and timer ticks take no override. Results and reports
  record the level.
  `Unchanged` treats an earlier broad review of the same snapshot as covering a critical request;
  results saved before levels existed count as broad.
- Enterprise hosts require explicit `githubHosts` entries and an existing authenticated `gh`
  account on each host. There is no implicit host/account discovery or Azure DevOps adapter.
- An authenticated `gh` read uses only fixed REST GET endpoints and a fixed GraphQL query.
  Pagination must complete. Git fetch uses the same account's credential helper without changing
  global Git settings. Checkout uses an empty template/configuration outside its tracked tree,
  so PR files cannot become controller hooks or be moved away as temporary input. It uses no
  user/system Git filters or hooks, disabled symlinks, and no recursive submodule update.
  Baseline and snapshot reads retain that isolated Git environment through bounded child
  processes. The original checkout and parent Git environment are untouched.

## One Timer

The only task identity is root task path `\` plus `SkillVault PR Review <current-user-SID>`.
Neither repository, PR, working directory, model, nor timestamp creates another timer. A different
ownership description blocks replacement; do not delete it or invent a suffixed task name.

```powershell
& $review -Action Timer -TimerAction Status
& $review -Action Timer -IntervalDays 0.5
& $review -Action Timer -IntervalDays 0.5 -Apply
& $review -Action Timer -TimerAction Disable -Apply
& $review -Action Timer -TimerAction Resume -Apply
```

Bare `harness-timer` requests Set, previews until approved, and reuses the single saved cadence.
With no saved cadence, ask for positive fractional days (at least one minute). Zero is not an
immediate-run alias. A resolved setup request authorizes that exact change after missing choices
are answered; editing/installing the skill is not a setup request.

Set creates or updates the same task and starts one interval later. Resume enables its existing
trigger without resetting cadence or requesting an immediate run. Disable prevents future ticks,
not a running review. Actions are read back for verification. Unrelated schedules remain intact.

The task runs the installed dispatcher with `-Action Review -Scheduled`, no target override.
It uses the current user's interactive logon at limited privilege, `IgnoreNew`, and a finite
cycle time limit plus cleanup allowance. Do not claim logged-out execution or request credentials
or elevation implicitly. The shared cycle lock also excludes overlapping manual list runs.
No tick invokes setup, changes model permissions, registers another timer, or publishes reports.

## Pauses, Recovery, and Results

Use the existing `harness-runtime/scripts/harness.ps1` with `-ProjectPath <controller-root>` and
the `Restrict`, `Fallback`, or `Recover` actions described by those installed skills. The target
is `review`; `project` pauses also apply. Show the explicit controller path so it is not confused
with the user's current repository. Do not initialize or modify an unrelated project to resume
PR work. Confirm owned processes have stopped before recovery, and inspect uncertain results.
Resume clears only the explicitly selected pause, starts no review, and changes no schedule.

A per-PR `clean` or `findings` result is complete only for its recorded base/head/profile/security
snapshot. `Unchanged` reuses that completed snapshot; it does not resolve its findings. `Stale`,
`blocked`, failure, or incomplete evidence stays pending. `Closed` launches no worker. Cycle
`Bounded` reports deferred candidates; `Partial` reports blockers. Neither means all PRs are clean.
Post-review remote revision failure leaves the target pending even if the engine's local snapshot
was internally stable. Earlier reports remain evidence and are not automatically removed.

`-Action List` returns watched targets and filters only. `-Action Results` returns the latest result
for every reviewed PR or repository target, watched or ad hoc, with the W- IDs that watch it. Each
attempt records its PR as the review in progress and clears it when that attempt's result is saved.
Results show it as `Running` while the recording process is alive, otherwise `Interrupted`, with the
last completed result kept beside it; an interrupted attempt stays pending.

These controls are not an OS security sandbox. Host/account filesystem isolation and provider
billing are external boundaries; do not infer them from a tool allowlist or reported CLI setting.
