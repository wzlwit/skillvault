# User-Wide PR Review Runtime

## Storage and Dependencies

The default controller root is `~/.copilot/pr-review`, not the current repository and not an
installed skill folder. PR review, watchlist actions, and the PR timer route share it across projects:

| Path under the root | Purpose |
| --- | --- |
| `watchlist.json` | Exact PR/repository entries, stable W- IDs, repository filters |
| `.harness/config.json` | Explicit PR settings and shared runner/restriction/fallback settings |
| `.harness/state.json` | Shared review runs, durable pauses, and PR result history |
| `reports/pr/` | PR-level status, verified revisions, findings, and engine evidence links |
| `reports/history/` | Shared review evidence and snapshots |
| `workspaces/` | Isolated fetched PR checkouts retained for evidence |

List and removal previews do not initialize storage. Add creates only the watchlist. Explicit
configuration initializes the dedicated controller, never the source/target project's harness.
Removal only unregisters the selected watch; it does not delete reports, checkouts, or remote PRs.
There is no implicit retention cleanup. `-DataRoot` exists for isolated tests or an explicitly
approved relocation of the one controller, not automatic project-specific lists/timers.

Use PowerShell 7, Git, authenticated `gh`, and an approved Copilot CLI supporting prompt stdin,
`--context`, `--reasoning-effort`, `--no-custom-instructions`, the existing read-only tool flags,
and finite credit limits. Install `harness` beside `pr-review` and make Rules Core available
globally or through `runner.rulesPath`. Install `differential-review` globally when security mode
is requested. No tool installation, login, connector setup, or permission widening is automatic.

The dispatcher is `scripts/pr-review.ps1` in the installed `pr-review` bundle. In examples below,
`$review` means its verified absolute path. Do not point a persistent task at an ephemeral copy.

```powershell
& $review -Action List
& $review -Action Add -Url https://github.com/owner/repository -Limit 5
& $review -Action Remove -Selector W-001
& $review -Action Remove -Selector W-001 -Apply
& $review -Action Review -Url https://github.com/owner/repository/pull/123
& $review -Action Review
```

An enabled timer reads the current list on each tick, so a newly added entry becomes eligible
then. Adding does not run it immediately. Unknown/removed GitHub hosts are blocked by the saved
host allowlist; URLs cannot contain credentials, query strings, or non-HTTPS endpoints.

## Approved Configuration

Use one JSON definition with only `runner` and `prReview`, preview it, then apply the exact
approved contents. This replaces only those documented settings, not restrictions, fallback,
history, or pauses. Configuring is not approval to enable scheduling or to start work.

Illustrative structure only: model and numbers below are not defaults, verified availability,
or authorization. Choose them with the owner before writing/applying a real definition.

```json
{
  "runner": {
    "command": "copilot",
    "maxMinutes": 15,
    "maxCredits": 5,
    "rulesPath": null
  },
  "prReview": {
    "profiles": [
      {
        "model": "choose-a-verified-model",
        "efforts": ["high", "max"],
        "contexts": ["default", "long_context"]
      }
    ],
    "githubHosts": ["github.com"],
    "maxPullRequests": 5,
    "maxCycleMinutes": 60,
    "maxCycleCredits": 25,
    "allowScheduled": false,
    "securityReview": false
  }
}
```

```powershell
& $review -Action Configure -DefinitionPath <approved-file>
& $review -Action Configure -DefinitionPath <approved-file> -Apply
```

- `profiles` is strongest-first, not sorted by model name. Verify account access and the actual
  per-model supported choices in the attended host/CLI before declaring them. There is no
  hardcoded universal model ranking or assumption that every model supports `max`/long context.
- Select the first approved model allowed by `restrictions.allowedModels`; choose the highest
  effort and context in its declared supported/approved sets intersected with current CLI help.
  General CLI choices alone do not prove per-model support. A provider/model failure blocks;
  there is no automatic switch to another model. Show the selected settings before execution.
- Effort order is max, xhigh, high, medium, low, minimal, none. Context order is long_context,
  default. Large evidence is streamed through stdin; workers read complete relevant code.
  Context tier is a request, not a fabricated exact token count or assurance of adequate coverage.
- Missing/null runner values inherit the current controller settings. With no existing per-agent
  limits, `maxMinutes`/`maxCredits` use the declared cycle budgets; preview shows `effectiveRunner`.
  Empty/blank and `None`/`Max` placeholders follow the same rule. Empty model allowance lists
  add no restriction; concrete lists still filter the declared profiles.
  The cycle/profile declaration remains explicit, so inheritance does not make PR collection unbounded.
- `runner.maxMinutes`/`maxCredits` bound each session. Restrictions can only tighten them.
  `maxCycleMinutes` also bounds collection/fetch subprocesses and reserves time for both passes.
  `maxCycleCredits` reserves at most two per-session ceilings per reviewed PR; it is a conservative
  CLI ceiling allocation, not measured provider usage, account balance, or a daily quota.
- `maxPullRequests` bounds new/repeated review attempts per cycle. Each repository's list entry
  separately limits discovery (default five, maximum 100), ordered by recent updates. Explicit
  PRs and repository results deduplicate. Open PRs are selected; closed/merged targets are
  reported without launching reviewers. Explicit PR URLs can select drafts.
- `allowScheduled` must be explicitly true before timer setup. `securityReview` chooses the saved
  methodology for list/timer runs; ad-hoc `-SecurityReview` can request it without changing settings.
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

Use the existing `harness/scripts/harness.ps1` with `-ProjectPath <controller-root>` and
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

These controls are not an OS security sandbox. Host/account filesystem isolation and provider
billing are external boundaries; do not infer them from a tool allowlist or reported CLI setting.