
# SkillVault Source Refresh

This skill runs a one-way latest refresh for source-backed skills
installed through SkillVault, including `/skillvault-installation install`. It pulls from recorded source repositories into installed skill
folders. It does not push local changes back upstream.

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
5. For latest installs, refresh from the recorded `sourceRepo` and `sourcePath` when present.
   A missing repository defaults to `https://github.com/wzlwit/skillvault.git`; a missing path
   is skipped. Fetch each Git repository once per run and resolve its default branch, not a
   hardcoded `main`. Reject failed Git operations, mismatched cache remotes, and dirty caches.
   If a recorded `skills/public/<category>/<name>` path is missing, use
   `skills/<category>/<name>` only when that same repository's catalog uniquely confirms the
   identical skill name and destination. Do not guess another category, name, or repository.
6. Require the source's matching `skill.json` and `SKILL.md`. Compare the installed version
   and actual file contents (excluding install metadata and Git internals). If both match and
   the recorded source path is current,
   report `Unchanged` without copying or changing `installedAt`. Same-version file changes
   still refresh, including unversioned skills. A confirmed source relocation updates metadata
   through the same staged replacement even when content is unchanged. Timestamps are not the
   comparison key.
7. Stage the new files and metadata before replacing the installed target. Restore the prior
   install on a failed swap; preserve its backup if automatic recovery is impossible. This
   one-way refresh overwrites edits inside managed `latest` targets; pin or keep custom skills
   unmanaged when local edits must be retained. Record a skill-scoped Git tree revision when
   available; record source revisions only after successful retrieval.
8. Report updated, unchanged, skipped, and failed skills. Isolate per-skill failures so later
   skills can refresh; an aggregate failure makes the run exit unsuccessfully.
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
that exact subset. Structured exit zero means the result was delivered, not that every copy
updated: inspect `status`, `retryTargets`, and `unresolved`. Ordinary one-shot text mode retains
its aggregate unsuccessful exit for failures or deferrals and schedules nothing.

Self-owned or heartbeat-parent-owned runtime dependencies, unknown legacy transitions, recovery
requirements, and actual Git/copy failures do not enter this retry path. Retain their outcomes
even if other targets later update successfully. After the third busy retry, stop that chain and
report deferred targets; an enabled regular refresh schedule retains its normal cadence.
This feature enables no live schedule and changes no agent-session or named-test retry policy.

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

- Pinned installs such as `v1.0.0` are intentionally skipped.
- `session` scope installs are not persisted, so they are not candidates for scheduled refresh.
- The script refreshes global installs only. Project copies need an explicit local install or
   update; they are not automatically included in the schedule.
- The bundled `skillvault-installation` skill supplies the shared staged-copy helper and must be installed
   alongside `skillvault-refresh`. This command does not install upstream runtime dependencies.
- Only recorded Git sources are supported. There is no automatic local-versus-remote ranking,
   dirty workspace copying, or arbitrary webpage/raw-URL downloading.
- Install metadata must identify the actual copied SkillVault folder. `upstream` links in a
   curated guide describe provenance, not its refresh source.
- `-GlobalSkillsPath` and `-CachePath` let scripts/tests use explicit roots. Scheduling forwards
   these roots to the task; normal usage keeps the default global paths.