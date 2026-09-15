---
name: skillvault-fresh
description: Create or run scheduled one-way latest refreshes for source-backed SkillVault installs. Triggers on "/skillvault-fresh", "skillvault-fresh", "/sv-fresh", "sv-fresh", "/skv-fresh", "skv-fresh", "/skillvault-sync", "/sv-sync", "schedule skillvault refresh", or "refresh skillvault skills".
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[intervalDay]"
---

# SkillVault Source Refresh

This skill creates or runs a scheduled one-way latest refresh for source-backed skills
installed through SkillVault, including `/sv-install`. It pulls from recorded source repositories into installed skill
folders. It does not push local changes back upstream.

## Parameters

- `intervalDay` — optional first positional argument. Default: `1`. Decimal values are
   allowed. Use `0` to run one immediate refresh without creating or updating a schedule.

## Behavior

When the user invokes `/skillvault-fresh <intervalDay>`, `/sv-fresh <intervalDay>`, or `/skv-fresh <intervalDay>`:

1. Parse `intervalDay`; if omitted, use `1` day. Decimal values are allowed, such as `0.5`.
   If it is `0`, run one immediate refresh and do not create or update a schedule. Reject
   values lower than `0`.
2. For positive intervals, create or update an operating-system schedule that runs the bundled refresh script at that
   interval.
3. The scheduled refresh checks installed skills that contain `.skillvault-install.json` with
   `installedBy` equal to `skillvault` or `skillvault-bootstrap`.
4. Skip any installed skill whose `requestedVersion` is not `latest`.
5. For latest installs, refresh from the recorded `sourceRepo` and `sourcePath` when present.
   A missing repository defaults to `https://github.com/wzlwit/skillvault.git`; a missing path
   is skipped. Fetch each Git repository once per run and resolve its default branch, not a
   hardcoded `main`. Reject failed Git operations, mismatched cache remotes, and dirty caches.
6. Require the source's matching `skill.json` and `SKILL.md`. Compare the installed version
   and actual file contents (excluding install metadata and Git internals). If both match,
   report `Unchanged` without copying or changing `installedAt`. Same-version file changes
   still refresh, including unversioned skills. Timestamps are not the comparison key.
7. Stage the new files and metadata before replacing the installed target. Restore the prior
   install on a failed swap; preserve its backup if automatic recovery is impossible. This
   one-way refresh overwrites edits inside managed `latest` targets; pin or keep custom skills
   unmanaged when local edits must be retained. Record a skill-scoped Git tree revision when
   available; record source revisions only after successful retrieval.
8. Report updated, unchanged, skipped, and failed skills. Isolate per-skill failures so later
   skills can refresh; an aggregate failure makes the run exit unsuccessfully.

## Windows Implementation

Use the bundled script:

```powershell
~/.copilot/skills/skillvault-fresh/scripts/skillvault-fresh.ps1 -IntervalDay 1
~/.copilot/skills/skillvault-fresh/scripts/skillvault-fresh.ps1 -IntervalDay 0.5
```

To run one refresh immediately without scheduling:

```powershell
~/.copilot/skills/skillvault-fresh/scripts/skillvault-fresh.ps1 -RunOnce
~/.copilot/skills/skillvault-fresh/scripts/skillvault-fresh.ps1 -IntervalDay 0
```

The schedule name is `SkillVault Source Refresh`. It runs for the current Windows user.

Compatibility aliases `/skillvault-sync` and `/sv-sync` are accepted, but the preferred
commands are `/skillvault-fresh`, `/sv-fresh`, and `/skv-fresh`.

## Notes

- Pinned installs such as `v1.0.0` are intentionally skipped.
- `session` scope installs are not persisted, so they are not candidates for scheduled refresh.
- The script refreshes global installs only. Project copies need an explicit local install or
   update; they are not automatically included in the schedule.
- The bundled `skillvault-install` skill supplies the shared staged-copy helper and must be installed
   alongside `skillvault-fresh`. This command does not install upstream runtime dependencies.
- Only recorded Git sources are supported. There is no automatic local-versus-remote ranking,
   dirty workspace copying, or arbitrary webpage/raw-URL downloading.
- Install metadata must identify the actual copied SkillVault folder. `upstream` links in a
   curated guide describe provenance, not its refresh source.
- `-GlobalSkillsPath` and `-CachePath` let scripts/tests use explicit roots. Scheduling forwards
   these roots to the task; normal usage keeps the default global paths.