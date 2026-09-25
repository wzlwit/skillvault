# ADR: Shared Checkout and Runtime Ownership

- Date: 2026-09-23
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: Participating harness execution and SkillVault installed-bundle updates
- Replaces: Operator-only coordination across controllers and manual runtime updates

The [September 25 installation ADR](./2026-09-25-current-copy-only-installation-adr.md)
clarifies backup protection below as temporary, in-progress rollback only, not retained
installation archives. The ownership protocol and stopped-worker requirements remain accepted.

## Context

Controller-local run locks serialize one controller, and the shared heartbeat already excludes
conflicting scheduled work. They do not coordinate a manual run from another controller or a
manual replacement of its installed runtime. The existing rules prohibit competing writers and
replacement of scripts used by active workers, but those paths needed a common executable gate.

During the fresh whole-design interview, the owner accepted cross-controller checkout ownership,
runtime/dependency update deferral, protection through development/validation/review, and an
attended transition for older runtimes. The subsequent implementation request authorized source
and fixture changes, not installed-copy rollout or live schedule changes.

## Decision

1. Use one user-wide ownership registry shared by cooperating manual and scheduled entrypoints.
   Reserve canonical checkout paths, not an entire Git common directory: separate worktrees
   remain independent. Keep existing controller locks and current/worktree defaults.
2. Hold exclusive checkout ownership across the active development, validation, and review
   sequence. Checkout-based tests are potential writers. Independent reviews may share an
   identical stable snapshot fingerprint while excluding writers. Keep snapshot validation,
   cooperative checkpoints, review independence, and existing restart limits.
3. Hold read claims for running bundles and their declared colocated dependencies. Installation,
   migration, uninstall, and refresh take conflicting write claims for affected targets. Busy
   results identify the owner; updates defer rather than stop workers or change schedules.
4. Preserve uncertain claims after interrupted execution. Do not steal claims based on age,
   clear safety pauses, requeue failed work, or automatically assume a dead coordinator means
   all children stopped. Existing explicit recovery requires stopped-worker confirmation.
5. Mark participating runtime bundles with `ownershipProtocol: 1`. Missing ownership from older
   affected runtimes is not evidence of idleness. Their transition is attended, backed up, and
   explicitly confirmed after stopping workers and preventing restarts. Confirmation cannot
   bypass an active new-protocol claim; unattended refresh has no transition override.

The registry stores ownership evidence, not tasks, queues, scheduling policy, or billing data.
Read-only status remains available without checkout reservations. No second scheduler or
versioned runtime snapshot system is introduced. This is cooperative single-machine coordination,
not an OS sandbox or protection against arbitrary external editors or nonparticipating tools.

## Alternatives and Consequences

- **Keep operator-only coordination:** Smaller implementation, but manual and scheduled paths
  can still collide despite following their own local locks. Not selected.
- **Shared ownership with deferred updates:** Selected. Reuses current execution and installation
  workflows while making their coordination rule enforceable for participating processes.
- **Serialize every worktree of a repository:** Unnecessarily blocks independent checkouts.
  Not selected; shared Git administration remains subject to Git's existing locks.
- **Versioned runtime snapshots:** Could permit hot replacement, but adds version selection,
  lifecycle, and retention mechanisms. Deferred in favor of waiting for affected runtimes to idle.
- **Automatic expiry or force takeover:** Cannot prove child workers stopped. Not selected.

Contention can delay a run or update. Unknown legacy installations can block unattended updates
until their attended transition. A running refresh or heartbeat cannot replace its own protected
helpers; those updates need an approved local-source installer while the affected processes are
idle. Registry evidence and backups consume local storage; malformed evidence needs inspection,
not silent deletion. Reverting the protocol requires a coordinated idle transition, not mixing
participating and older writers while assuming protection remains complete.

## Implementation and Verification

The shared [ownership helper](../../../skills/core/skillvault-installation/scripts/skill-ownership.ps1)
uses process-held claim locks and a short registry mutex. The default registry is
`~/.copilot/skillvault/ownership`; explicitly isolated environments use a common
`SKILLVAULT_OWNERSHIP_ROOT`. Fixtures supply temporary roots rather than touching live claims.
The [harness adapter](../../../skills/planning/harness/scripts/harness-ownership.ps1) binds claims
to controller, role, task, workspace, and snapshot evidence. Controller/scheduler recovery retains
its existing pause and stopped-worker requirements.

The [installer fixture](../../../scripts/test-install-skills.ps1) covers real cross-process
contention, owner reporting, shared readers, independent paths, explicit recovery, target-set
admission, and legacy backups. Harness, test-flow, monitor, scheduler, PR, refresh, inventory,
and bootstrap fixtures exercise the affected consumers. The full repository gate remains
[test-all](../../../scripts/test-all.ps1); passing fixtures do not claim a live rollout.

## Boundaries

No new coordination choice remains open. Installation, controller initialization, schedule
activation, source publication, and any future snapshot-versioning design remain separate.
This ADR does not accept or reclassify the unrelated clauses marked Proposed in the
[original harness ADR](./2026-09-15-harness-command-and-record-contracts-adr.md#still-proposed).
That historical status mismatch still requires acceptance evidence, not inference from code.