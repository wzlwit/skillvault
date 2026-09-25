# ADR: Current-Copy-Only Skill Installation

- Date: 2026-09-25
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: Installed skill updates, archive retention, and obsolete source/skill cleanup.
- Supersedes: Only Recovery Location and Backup Retention in the [September 24 ADR](./2026-09-24-recovery-compatibility-and-harness-baseline-adr.md). Runtime interface checks and harness baseline acceptance remain in force.

## Context

Retaining copies from successive refactors left stale skill names and backup directories beside
the current installation, then introduced a separate recovery store and retention policy. The
owner explicitly rejected that storage and requested current repository/copy contents plus removal
of stale or old-named files. The earlier archive policy is therefore not the current requirement.

## Decision

1. Maintain canonical source and current installed skills. Explicit update scope permits replacing
   stale managed copies or retiring verified old names after replacements validate. Keep unrelated,
   customized, and pinned skills unless their replacement/removal is explicitly selected.
2. Keep no historical installation archives, recovery directory, age/generation retention policy,
   backup storage budget, or backup-maintenance job. Remove the archive-management CLI and helper.
3. Use temporary complete originals only while replacement, migration, or uninstall is in progress.
   Successful updates and verified rollback discard them. Failed new installs remove their own
   partial targets. If rollback itself fails, report the temporary path and preserve the unrestored
   originals until that interrupted transaction is resolved; this is not a retained version history.
4. Declare `installation-transactions: 1` instead of the removed `recovery: 1` interface. Reuse the
   existing ownership and compatibility gates for updates and runtime startup. Do not satisfy old
   consumers from unrelated source copies or bypass stopped-worker confirmation for older runtimes.
5. The owner's cleanup request authorizes removing the existing user-wide SkillVault recovery store
   and the verified obsolete source/installed names in this checkout and its current-user scope.
   It does not authorize deleting unrelated worktrees, Git history, project run evidence, schedules,
   third-party skills, or installing the separately deferred Power BI guide.

## Alternatives and Consequences

- Retain bounded archives: rejected by the owner; creates storage and classification work that is
  not wanted for this repository's development workflow.
- Replace without rollback: simpler, but a failed filesystem operation can lose the current copy.
  Temporary transactions protect that operation without keeping completed historical copies.
- Keep duplicate legacy folders: rejected; they obscure the canonical implementation and can
  expose stale instructions through skill discovery.

After a verified successful replacement there is no automatic older-install rollback. Reinstalling
an earlier version requires an explicitly selected source. Git and ADRs preserve source/decision
history; they do not guarantee recovery of every uncommitted installed customization. Explicit
cleanup of existing archives intentionally removes those historical snapshots.

## Implementation and Verification

The [transaction helper](../../../skills/core/skillvault-installation/scripts/skill-transactions.ps1)
supports the shared installer, migration, and uninstall paths. The scheduler no longer delegates
installation-archive cleanup. The [installation guide](../../../skills/core/skillvault-installation/references/install.md#transactional-updates)
owns the operational contract.

Existing temporary fixtures verify current-copy-only success, complete originals during work,
partial/new-install failures, successful rollback cleanup, visible rollback failure, old-name
migration, exact cross-scope rollback targets, ownership exclusion, and unchanged scheduler/history
behavior. The full repository gate passed. Existing global/project copies verified against current
source after synchronization; the approved recovery-store and obsolete-source cleanup completed
without replacement archives. Scheduler state and protected task definitions remained unchanged.

No design question remains open. This request does not authorize a new commit or push.