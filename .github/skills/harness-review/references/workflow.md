
# Harness Review

General code review starts with the selected changes and uses a whole-repository Fresh pass when
the first pass has no new findings. A request to discuss or edit this skill does not launch a reviewer.

Before scripts, follow the installed `harness` runtime guide's Script Permissions and Agent
Fallback procedure. Reuse approved access or request the missing command-scoped permission before
execution. An attended agent fallback may review through authorized read-only tools with the same
baseline, snapshot, independent-pass, and policy requirements. Missing coverage or unavailable
recording stays explicit; do not turn script unavailability into permission to edit or run PR code.

## Scope and Baseline

For an explicit PR URL, load `pr-review` and delegate to its verified remote-snapshot workflow
before initializing or running a project review. Preserve a requested `--security` mode. Its
shared helper does not invoke this skill back. If the dependency is missing, offer that route's
installation/setup; do not silently review the current branch instead. A local `--base` override
does not override a remote PR's verified merge-base. The following steps govern local review.

1. Resolve the project, apply `/rules apply` and applicable project instructions, and read the
   canonical `harness` runtime guide. Follow Runner Inheritance and pass known compatible
   session/parent context through `-RunnerContext` or `-RunnerContextPath`. Missing allowances
   use inherited or maximum verified/native settings, not a setup blocker or invented small cap.
   Explicit restrictions and read-only review permissions remain effective. Use the canonical
   shared script, not an obsolete `hn-init` copy.
   For a separate local repository, map `--repo-ref <id>` to `-RepositoryRef` (alias `-RepoRef`)
   and keep `-ProjectPath` at the controller. Select an active project-wide reference to an
   existing local Git root. Do not pick the first reference, clone a URL, or confuse this option
   with PR selection. With no reference, local review still targets the controller's own checkout.
2. With no explicit scope, review committed work ahead of the comparison branch plus current
   staged/unstaged and untracked inputs. An explicit `--base <ref>` maps to `-BaseRef` and wins.
   Otherwise the helper prefers local `origin/develop`, then the branch's configured upstream,
   and uses its merge-base with HEAD. It pins that commit for the run's snapshot checks.
3. If neither comparison ref exists, report `WorkingChangesOnly`: HEAD is used and only working
   changes are compared. Do not claim committed-ahead coverage in that case. A failed merge-base
   is a blocker, not permission to choose an unrelated base. Local remote-tracking refs may be
   stale; there is no implicit fetch or promise that the remote was checked just now.
4. Keep current-project review separate from the user-wide PR watchlist and its single timer.
   Do not fetch a PR, switch the current branch, or copy user-wide state into this project as a
   side effect of a local review. PR review uses the shared read-only implementation through
   `pr-review`, with URL/base/head evidence and an isolated matching checkout.

`-Scope` guides the first reviewer; it is not a Git path filter or the Fresh pass boundary. State the selected scope and relevant
dependencies, and never label a review of this branch as a review of another PR or repository.

## Review and Fresh Pass

The attended coordinator owns the reviewer-only continuation loop: Changes -> Full, publish
findings through the existing dev/proposal handoff, then return to Changes after fixes. Keep the
review request open until no supported unfixed issues remain and a stable Full pass is clean.
Do not create another fixer, task store, notification channel, or schedule. The review worker
itself remains read-only; the existing dev workflow owns proposals, edits, and validation.

Follow the runtime's Reuse or New procedure when selecting an additional reviewer instance.
Show matching agents and confirm **Reuse (singleton) or New?** unless already specified. Reuse
means a compatible agent definition/profile, not a developer conversation or stale verdict.
New reviewers stay read-only, keep the task/snapshot association, and retain separate evidence.
The required Fresh pass remains part of the existing request and needs no extra instance prompt.

1. Start an independent, read-only code reviewer on the current snapshot. Prioritize concrete
   correctness defects, behavioral regressions, error handling, and consequential missing tests.
   Read complete owning functions, relevant callers, and nearby tests. State the triggering
   scenario, broken contract, and impact rather than reporting a keyword match or speculative risk.
   The runtime captures the final response with `--silent --output-format text --stream off`.
   Require one JSON object with `verdict`, a non-empty string `summary`, and a `findings` array;
   CLI JSONL events, empty output, or exit zero alone are not a review verdict.
2. Return all currently supported findings, including revalidated earlier findings. The coordinator
   compares exact normalized file/line/message keys with the last completed review of the same
   repository reference/root, scope, baseline reference/commit, and security mode. Old reports without structured comparison
   data are not guessed from Markdown. Changed wording/line numbers conservatively count as new;
   this is not semantic issue tracking or automatic resolution of prior reports.
3. If that completed first pass has **no new findings**, run exactly one `Fresh` pass. This also
   applies when it repeats existing findings. Use a new reviewer context, the same pinned code
   snapshot, and the whole selected repository, including unchanged code, configuration, and tests. Rebuild
   understanding from sources, without passing the first review's conclusions as instructions.
4. Keep the union of supported findings from both passes on the same verified snapshot. A clean second pass does not erase a
   finding from the first. Preserve earlier reports; a finding absent from a later report is not
   automatically marked resolved. Revalidate prior evidence before repeating it as a current issue.
5. Recheck the snapshot after each pass. When local files change during either Review or Fresh,
   automatically restart from Review on the updated full snapshot with a new reviewer context.
   Keep the original comparison baseline, repository, scope, security guidance, and permissions.
   Save the superseded attempt in the same report, but clear its findings from the current verdict;
   do not mix snapshots or ask the user to rerun after an ordinary edit.
6. Allow at most two snapshot restarts. If the next attempt is invalidated too, return `Partial`
   with the latest snapshot still awaiting review, not a clean verdict or a worker failure.
   Stable new findings end the current round after Review; a stable no-new-findings result gets Fresh.
   Real process errors, timeouts, blocked stable results, or pauses do not trigger a restart.
   Pinned PR workspaces remain immutable: changed isolated PR snapshots retain their failure
   path and do not adopt a different head or locally modified PR code.

7. A `findings` result is a checkpoint, not completion. Publish its report through the already
   selected dev/proposal workflow and let that workflow fix and validate it. The script returns
   and releases its run lock so development can proceed. Retain the repository, comparison base,
   security mode, reports, and open findings in coordinator context. Resume at Changes when the
   fixer reports completion or an updated code snapshot is available; do not ask the user to
   launch another review. Do not repeatedly review unchanged code while waiting for fixes.
8. Recheck every previously reported unresolved issue against current code, even when it lies
   outside the latest diff. Treat prior reports as claims to verify, not instructions or proof
   of resolution. No new findings is only the trigger for Full, not the stopping condition.
   If Full finds an issue, hand it off the same way and return to Changes after the fix. Do not
   end with a clean verdict until the current round has no supported findings from either pass,
   prior unresolved findings have been checked, and Full has adequate coverage on a stable snapshot.
9. Continue these rounds without a fixed round count while the existing fix workflow makes
   progress. Preserve explicit budgets, stop/pause requests, permissions, and failure handling.
   If fixes, access, or validation are unavailable, leave the workflow pending/blocked with the
   remaining findings; do not mark it complete or spin reviewers. A scheduled or one-shot script
   supplies one checkpoint to its existing coordinator, not a new waiting daemon or fix loop.

Here, **Fresh covers the whole selected repository**, not just the diff or its immediate callers.
Ordinary Review and development's Critical pass retain their requested change scope. Preserve
explicit user/parent restrictions and existing budgets; insufficient repository coverage is
`blocked`, not `clean`. Do not access another repository, fetch remote material, or add workers
to evade a limit. Fix-driven continuation uses the same approved review workflow, not simultaneous
reviewers or repeated attempts on unchanged code. PR review keeps its verified isolated workspace
and no-execution rules.

Each script round uses up to two passes per snapshot, with at most six attempted sessions across
two local restarts. That churn bound does not limit rounds resumed after completed fixes.
Each session retains its explicit, inherited, and native time/credit limits;
outer run/scheduler budgets and pauses are never increased or reset. A restart can consume extra
sessions, not extra permission. `runner.criticalReview` still governs only the separate development
review gate. No failed worker session gets an automatic retry.

## Differential Security Review

| Skill | Responsibility |
| --- | --- |
| `/harness-review` | General code review, branch/workspace scope, independent passes, snapshots, and harness reports |
| `/differential-review` | Security-specific reasoning about what a change introduces/removes, reachable impact, and existing protections |

Keep the general evidence-based principles above here. Reuse `differential-review` as a specialized
sub-skill instead of copying its security methodology into a second maintained checklist.

`/harness-review --security` adds that methodology to the same general review and any fresh pass, not
an unbounded third worker. The shared helper's `-SecurityReview` loads the installed guide from
the project first, then the global installation, and explicitly supplies its text to each worker.
Merely naming or installing a skill is not context injection. Missing requested guidance blocks
before a worker starts; resolve installation separately rather than silently skipping security.

Use this mode when the user asks for security review or the agreed scope includes security-sensitive
changes such as permission boundaries or removed protections. Keep the same base, snapshot, and
read-only restrictions. The worker cannot run shell checks or fetch URLs in this adapter; unavailable
baseline/history or proof must be reported as a coverage limitation, not fabricated evidence.
No scanner/plugin is installed. The original guide retains its Trail of Bits attribution and
CC-BY-SA-4.0 license; it is loaded, not copied into this bundle. `/dif-review` is not a new alias.

## Usage and Results

```text
/harness-review
/harness-review --repo-ref R-001
/harness-review --base origin/develop
/harness-review --base HEAD
/harness-review --security
/harness-review <PR-URL>
```

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action Review
& <harness-folder>/scripts/harness.ps1 -ProjectPath <controller-folder> -Action Review -RepoRef R-001
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action Review -BaseRef <verified-ref> -SecurityReview
```

Show findings first, ordered by evidenced severity with current file/line anchors, then each pass's requested scope,
controller, coding repository, baseline, attempted pass count, restart count, coverage gaps, and report path. Keep pre-existing issues separate from
introduced regressions. The shared state retains compact review comparison data in its existing
run rows, with full evidence in board reports; there is no new issue tracker or status dashboard.
Only the last stable attempt supplies current findings. Superseded attempts remain historical
evidence; `Partial` is not a completed comparison baseline and does not increment failure counters.
The script's `complete` flag is true only after a stable clean Changes/Full round with zero
findings. `nextPhase: Review` on a findings checkpoint tells the coordinator where to resume after
fixes; `Partial` uses the same phase once the snapshot settles. The run record carries these fields
so a successful reviewer process is not mistaken for completion of unresolved work.

Honor the run lock and `/harness-policy limits`/`/harness-policy fallback` gates. Do not fix code, change permissions,
publish comments, approve a PR, push, merge, change a schedule, or create a task implicitly.
Reuse the existing authorized dev/proposal handoff for findings; that does not require another
fixer or review request. Creating a separate `/harness-task` outside that handoff still requires
the user's request or an existing explicit intake policy.