
# SkillVault Source Refresh

Contents: Parameters; Behavior; Scheduled Contention Retries; Runtime Compatibility; Windows
Implementation; Notes.

This skill refreshes managed global `latest` copies installed through SkillVault, including
`/skillvault-installation install`, in two steps:

1. **Adaptations to GitHub.** Merge upstream changes into each adapted skill in the SkillVault
   repository, commit the merge in refresh's own clone, and push it. This happens only when the
   current credentials may push there.
2. **GitHub to your machine.** Bring new commits to the local checkout recorded at install, then to
   the installed copies, merging changes made in them. Installed originals follow their upstream.

Refresh never pushes your own commits or uncommitted work, never commits in your checkout, and
leaves every conflict for your decision.

Load this procedure only for explicit `/skillvault-refresh run` or `schedule`, or legacy fresh/sync
requests. `run` passes `-RunOnce`; bare `/skillvault-refresh` remains read-only and loads no schedule.

## Parameters

- `intervalDay` — optional first positional argument. Default: `1`. Decimal values are
   allowed. Use `0` to run one immediate refresh without creating or updating a schedule.

## Behavior

When the user invokes `/skillvault-refresh <intervalDay>`, `/skillvault-refresh <intervalDay>`, or `/skillvault-refresh <intervalDay>`:

1. Parse `intervalDay`; if omitted, use `1` day. Decimal values are allowed, such as `0.5`.
   If it is `0`, run one immediate refresh and do not create or update a schedule. Reject
   values lower than `0`.
2. For positive intervals, delegate to `/harness-timer set refresh` with that day value. That topic
   owns the single heartbeat and logical schedule. Do not call this script's legacy OS-task creation path.
3. The scheduled refresh checks installed skills that contain `.skillvault-install.json` with
   `installedBy` equal to `skillvault` or `skillvault-bootstrap`.
4. Skip any installed skill whose `requestedVersion` is not `latest`.
5. **Merge adaptations (step 1).** Fetch each SkillVault repository recorded by those installs into
   refresh's own clone under the cache. A missing repository defaults to
   `https://github.com/wzlwit/skillvault.git`. For catalog entries whose `skill.json` declares
   `install.strategy: adapted`:
   - Check push permission first with `git push --dry-run`: to `origin`, then to the push URL of a
     verified local checkout of the same repository. Without permission, skip this step, fetch
     nothing for it, say so, and continue with step 2.
   - Fetch the upstream repository at the declared `version`: `latest`, a tag, or a full commit.
   - Compare the upstream skill folder at that commit with the folder at the recorded
     `upstream.commit`. If it did not change, do nothing.
   - Otherwise replace the original section of `SKILL.md`, between `<!-- upstream:begin -->` and
     `<!-- upstream:end -->`, with the new original text; SkillVault's changes outside it stay.
     Merge the original's other files file by file, record the new `upstream.commit`, and keep
     `UPSTREAM-LICENSE` current. Without an upstream license file, that skill fails and nothing is
     copied. SkillVault changes belong only on the wrapper side; a conflict means a SkillVault
     change to a file that the original also changed. It changes nothing and defers the skill
     (`AdaptationConflict`): undo SkillVault's change to that file, moving what it needs to the
     wrapper side, and the next refresh merges.
   - Commit each merge as `refresh: merge <repository>@<commit> into <name>`, then push to the
     default branch. If GitHub moved meanwhile, rebase once and retry. A push that still fails
     drops the commits from refresh's clone and defers those skills (`PublishFailed`), so no
     installed copy gets content that GitHub does not have.
6. **Update the checkout (step 2).** An install made from a local checkout records its
   `sourceCheckout` and `sourceRevision`. Use the checkout only when it is a Git checkout root whose
   `origin` is the recorded repository, then fetch:
   - On a branch other than the default branch, leave it and defer its installs
     (`CheckoutOnOtherBranch`).
   - Only behind GitHub: fast-forward. If uncommitted changes touch incoming files, Git refuses and
     the checkout waits (`CheckoutBlocked`).
   - Ahead and behind: merge only when no tracked file has uncommitted changes (`CheckoutBlocked`
     otherwise). On a conflict, abort the merge so the checkout is unchanged, and defer
     (`CheckoutConflict`).
   - If the fetch fails, installs follow the checkout's local commits; the run reports
     `CheckoutFetchFailed`.
7. **Update installed copies (step 2).** Compare each copy with the checkout's committed files:
   - Same as the committed files or as the working copy: report `Unchanged`.
   - Nothing new committed for that skill since the recorded base: keep the copy and its changes.
   - Copy equal to the recorded base: replace it with the committed files.
   - Otherwise merge file by file from the base, the copy, and the committed files. Line-ending
     differences alone are not changes. Install a clean merge and report it as merged; a conflict
     leaves the copy unchanged and defers it (`MergeConflict`). Without a recorded base, defer
     (`NoMergeBase`).

   Installed originals (`sourceType: upstream`) refresh from their recorded upstream repository and
   path the same way: the recorded `sourceRevision` is the base, so local edits are merged, and a
   conflict defers the copy. A copy whose SkillVault source has become a reference is skipped with
   a hint to reinstall it.

   Installs without `sourceCheckout` refresh from refresh's own clone of the recorded `sourceRepo`
   and `sourcePath`, and are overwritten. Fetch each repository once per run and resolve its
   default branch, not a hardcoded `main`. Reject failed Git operations, mismatched cache remotes,
   and dirty caches.
   Source access temporarily disables Git/GCM prompts with `GIT_TERMINAL_PROMPT=0` and
   `GCM_INTERACTIVE=Never`, restoring the caller's settings on success or failure. Existing
   credentials remain usable; no credentials or saved Git configuration are changed. If sign-in
   is required, report the failure for attended authentication instead of opening UI or retrying
   login automatically.
   If a recorded `skills/public/<category>/<name>` path is missing, use
   `skills/<category>/<name>` only when that same repository's catalog uniquely confirms the
   identical skill name and destination. Do not guess another category, name, or repository.
8. Require the source's matching `skill.json` and `SKILL.md`. Compare the installed version
   and actual file contents (excluding install metadata and Git internals). If both match and
   the recorded source path is current,
   report `Unchanged` without copying or changing `installedAt`. Same-version file changes
   still refresh, including unversioned skills. A confirmed source relocation updates metadata
   through the same staged replacement even when content is unchanged. Timestamps are not the
   comparison key.
9. Stage the new files and metadata before replacing the installed target. Restore the prior
   install on a failed swap; preserve its backup if automatic recovery is impossible. Copies
   without a recorded checkout are overwritten; pin or keep custom skills unmanaged when their
   edits must be retained. Record the skill folder's committed Git tree as the new base.
10. Report updated, unchanged, skipped, deferred, and failed skills. Isolate per-skill failures so
   later skills can refresh; an aggregate failure makes the run exit unsuccessfully.
   Active runtime ownership, uncertain claims, or older affected runtimes defer the affected
   replacement and report its owner or transition requirement. Other eligible skills may still
   update; a deferred target is not a successful refresh. Never stop workers or infer idle from
   missing legacy ownership data. Use an attended local-source installer for confirmed transitions.
   Refresh holds a runtime read claim itself, so self/dependency updates wait until it finishes.

## Scheduled Contention Retries

The shared heartbeat can retry temporary `Busy` updates three times, with delays of one, ten,
and thirty minutes between attempts. Each attempt exits and releases its scheduler slot; no
refresh process remains asleep during the wait. Only the originally deferred names, source
tree revisions, and unchanged installation metadata are retried. A changed source or target
stays deferred until a later regular refresh or a separately requested update.

The scheduler uses the script's `-ResultJson` receipt and an internal `-RetryPlanPath` to carry
that exact subset. A retry skips step 1 and checkout updates. Structured exit zero means the
result was delivered, not that every copy updated: inspect `status`, `retryTargets`, and
`unresolved`. Ordinary one-shot text mode retains
its aggregate unsuccessful exit for failures or deferrals and schedules nothing.

Self-owned or heartbeat-parent-owned runtime dependencies, unknown legacy transitions, recovery
requirements, and actual Git/copy failures do not enter this retry path. Retain their outcomes
even if other targets later update successfully. After the third busy retry, stop that chain and
report deferred targets; an enabled regular refresh schedule retains its normal cadence.
This feature enables no live schedule and changes no agent-session or named-test retry policy.

## Runtime Compatibility

Runtime admission checks declared dependency interfaces before refresh work. Matching package
versions are not proof of compatibility; report required companion updates without installing them
implicitly. Replacements keep verified originals outside discovery only while an update is in
progress; success or verified rollback discards them. Refresh keeps no installation archive or
retention policy. A failed rollback is not temporary ownership contention and receives no timed
retry. Existing stale-file deletion is a separately scoped action.

## Windows Implementation

Use the bundled script:

```powershell
~/.copilot/skills/harness-timer/scripts/harness-timer.ps1 -Action Set -Target refresh -Interval 1d
~/.copilot/skills/harness-timer/scripts/harness-timer.ps1 -Action Set -Target refresh -Interval 0.5d
```

To run one refresh immediately without scheduling:

```powershell
~/.copilot/skills/skillvault-refresh/scripts/skillvault-fresh.ps1 -RunOnce
~/.copilot/skills/skillvault-refresh/scripts/skillvault-fresh.ps1 -IntervalDay 0
```

The logical refresh schedule runs for the current signed-in user under the shared heartbeat.
An existing `SkillVault Source Refresh` OS task needs explicit migration; do not enable both.

Compatibility aliases `/skillvault-sync` and `/sv-sync` are accepted, but the preferred
commands are `/skillvault-refresh`, `/skillvault-refresh`, and `/skillvault-refresh`.

## Notes

- Pinned installs, such as `v1.0.0` or an original pinned to a tag or commit, are intentionally
   skipped. An adaptation pinned to a tag or commit is merged up to that pin by step 1.
- `session` scope installs are not persisted, so they are not candidates for scheduled refresh.
- The script refreshes global installs only. Project copies need an explicit local install or
   update; they are not automatically included in the schedule.
- The bundled `skillvault-installation` skill supplies the shared staged-copy helper and must be installed
   alongside `skillvault-refresh`. This command does not install upstream runtime dependencies.
- Only recorded Git sources are supported. Refresh never copies uncommitted work from a checkout;
   it keeps such work only when it is already in the installed copy. There is no arbitrary
   webpage or raw-URL downloading.
- Install metadata must identify the actual copied folder. An `upstream` block is a merge source
   only for adapted skills; in a curated guide it describes provenance.
- `-GlobalSkillsPath` and `-CachePath` let scripts/tests use explicit roots. Scheduling forwards
   these roots to the task; normal usage keeps the default global paths.