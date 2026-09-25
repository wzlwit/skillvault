# ADR: Recovery Backups, Runtime Compatibility, and Harness Baseline

- Date: 2026-09-24
- Status: Partially superseded; runtime interfaces and harness baseline remain Accepted
- Decision owner: Zhaolong Wang
- Scope: Retained installation backups, executable dependency interfaces, and acceptance of the current reusable harness baseline.
- Supersedes: Only the proposed coordinator, unified executor, independent reviewer, `now`/`next` scheduling, and development critical-review clauses in the [original harness ADR](./2026-09-15-harness-command-and-record-contracts-adr.md#still-proposed).
- Extends: The [shared ownership contract](./2026-09-23-shared-ownership-adr.md); later accepted work and scheduling decisions remain in force.

The [September 25 current-copy-only ADR](./2026-09-25-current-copy-only-installation-adr.md)
supersedes Recovery Location and Backup Retention below. Those sections preserve the earlier
decision history, not the current installation policy. Interface checks and baseline acceptance
remain unchanged.

## Context

Recovery bundles stored beside active skills have appeared in the host's available-skill list.
Excluding `.skillvault-backup-*` from SkillVault's own inventory does not keep the host from
discovering their skill instructions. Complete recovery copies are still needed for rollback.

The [installation helper](../../../skills/core/skillvault-installation/scripts/skill-files.ps1)
removes temporary staging and ordinary successful-swap backups, but retains legacy-transition
and failed-recovery copies. The [topic migration helper](../../../skills/core/skillvault-installation/scripts/migrate-topics.ps1)
also retains originals after success. Existing harness maintenance prunes run history and stale
schedules, not these archives. Moving retained copies alone would leave their growth unbounded.

Separately updated runtime bundles can expose different interfaces despite sharing a package
version. Structured refresh results and retry plans are a concrete timer-to-refresh dependency;
the existing `ownershipProtocol` marker describes ownership participation, not that interface.
The original harness ADR also still labels five baseline clauses Proposed, although the current
plan describes their reusable implementation. Implementation alone was not acceptance.

The owner explicitly accepted backup relocation, interface checks, and the current baseline
through grilling, then accepted the retention defaults below. This record preserves those choices;
it does not infer earlier approval from completed implementation or installation.

## Decision

### Recovery Location

Keep complete retained backups under the user-wide SkillVault recovery directory,
`~/.copilot/skillvault/recovery/`, outside all skill-discovery roots. Preserve the original bundle,
installation metadata, and target identity needed for rollback. Distinguish global copies and
each project's exact installation target.

Moving existing backups requires an explicitly approved, verified migration that preserves
rollback. Relocation does not itself authorize pruning. Existing archives must be previewed and
classified before becoming automatic cleanup candidates; unknown archives remain protected.

### Backup Retention

Use configurable defaults for managed retained installation backups:

| Rule | Default and boundary |
| --- | --- |
| Age | Completed, classified backups older than 30 days become pruning candidates. |
| Generations | Completed, classified backups beyond the latest 3 per canonical skill and exact installation target also become candidates. Age or generation excess is sufficient; neither overrides protection. |
| Rollback floor | Always retain the newest verified rollback copy for each skill and installation target, even when older than 30 days. |
| Protected evidence | Never automatically prune pinned, incomplete, failed, or unclassified recovery evidence. |
| Storage budget | 1 GiB total across managed retained installation backups, not a separate allowance per skill or scope. If eligible pruning cannot meet it, warn and defer further backup-producing updates instead of deleting protected evidence. |
| Cleanup triggers | After verified updates and through the existing approved weekly maintenance window. Reuse the heartbeat; add no separate timer. |

These rules apply to retained backup archives, not active installed skills, source bundles,
project documents, or worktrees. They do not replace harness run-history retention. Keep the
existing Saturday 08:30-09:00 local maintenance window and its approvals; do not silently enable
backup deletion through an existing history-cleanup approval.

### Runtime Interfaces

Executable bundles must declare the interfaces or protocols they provide and require from
their dependencies. Check compatibility before launching work. An incompatible dependency
blocks that launch and identifies the required companion update set; it does not trigger an
implicit update or bypass ownership, recovery, or installation approvals.

Follow the explicit `ownershipProtocol` pattern, but check each required interface rather than
treating that marker or equal package versions as universal compatibility. Unrelated skills need
not share one version. The structured refresh interface introduced by the
[refresh-retry decision](./2026-09-24-refresh-contention-retries-adr.md) is a concrete consumer of
this check. The agreed checks address partial-update risk; this is not a claim that the verified
joint rollout failed.

### Current Harness Baseline

Accept the current reusable shared coordinator, unified development/verification/fix executor,
independent reviewer, `now`/`next` scheduling, and development critical-review contract. Their
operational detail remains in the [current execution and review plan](../2026-09-15-harness-command-and-record-contracts.md#execution-and-review).
`now` uses the existing idle/checkpoint behavior, not a hard kill; `next` queues without
interrupting. Development's critical review remains separate from standalone review.

This supersedes only the original proposal status of those clauses, not the original rationale
or every historical command spelling. The [September 18 work contracts](./2026-09-18-upsert-and-harness-work-contracts-adr.md)
and later accepted ownership, heartbeat, and retry decisions retain precedence. Bare multi-action
topics, including `/harness-timer`, remain read-only `list`; this does not revive the original
bare-timer setup wording.

Per-project workspace, model, permission, review-policy, and scheduling choices remain
[configuration when needed](../2026-09-15-harness-command-and-record-contracts.md#configuration-when-needed).
Accepting the reusable design does not select those settings or authorize live execution.

## Alternatives

| Alternative | Assessment |
| --- | --- |
| Keep hidden backup folders beside skills | Rejected: SkillVault inventory filtering does not prevent host skill discovery. |
| Move backups but retain all forever | Rejected: fixes discovery exposure but leaves storage growth unbounded. |
| Delete all old or over-budget backups | Rejected: age or size alone cannot establish that recovery evidence is disposable. |
| Force all skills onto one package version | Rejected: couples unrelated updates and does not explicitly establish required interface support. |
| Infer baseline acceptance from implementation | Rejected: execution evidence is not the owner's design decision. Record the explicit acceptance now and preserve history. |

## Consequences

Recovery needs enough metadata to distinguish completed backups, protected evidence, and exact
installation targets. Legacy archives need classification before pruning; moving them is a
separate operation with verification and recovery costs.

Protected copies can keep storage above 1 GiB. The budget therefore bounds further managed
backup-producing work, not permission to erase evidence or a guarantee against unrelated disk
use. No current backup-size measurement or imminent disk-exhaustion claim underlies this default.
Dependency authors must maintain accurate interface declarations, and partial installations may
need a coordinated update set before work can resume.

The decisions are reversible through a later approved change, but deleted archives are not.
Preserving rollback, previewing existing archives, and keeping live cleanup approval separate
remain necessary even after the policy is implemented.

## Implementation and Verification

The initial ADR was documentation-only. The owner's subsequent implementation request authorized
source changes: the [then-current recovery helper](https://github.com/wzlwit/skillvault/blob/6a51cbf0b60e81d88c56e8975bcf68a1f6812092/skills/core/skillvault-installation/scripts/skill-recovery.ps1)
now owns complete originals, records, protected retention, and the preview-first administration
command. The [then-current installation guide](https://github.com/wzlwit/skillvault/blob/6a51cbf0b60e81d88c56e8975bcf68a1f6812092/skills/core/skillvault-installation/references/install.md#recovery-backups)
describes explicit policy, migration, and classification operations. Existing archive migration,
cleanup activation, installed-copy rollout, and schedule changes remain separately approved.
No live backup is moved or deleted by this source implementation, and no publication is implied.

Executable manifests declare provided and required interfaces independently of package versions.
Admission verifies dependency contracts while holding ownership; scheduled refresh also verifies
the actual saved adapter before launch. Catalog validation checks source declarations and edges.
Existing installer and scheduler fixtures cover complete rollback, discovery isolation,
age/count/budget protections, preview/apply boundaries, incompatible dependencies, and maintenance
opt-in. These use temporary archives and fake tasks, never live recovery data or schedules.

No policy decision remains open in this record. Live rollout and project-specific configuration
remain separate work, not unaccepted choices in this decision.