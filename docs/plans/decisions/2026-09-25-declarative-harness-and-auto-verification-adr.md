# ADR: Declarative Harness Layout and Auto Verification

- Date: 2026-09-25
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: New-controller layout, explicit migration, configuration authority, and discovery status verification.
- Partially supersedes: Flat storage and collection-only status handling in the [original harness record](2026-09-15-harness-command-and-record-contracts-adr.md). Other execution, ownership, approval, and retention decisions remain unchanged.

## Context

Flat controller folders mixed configuration, generated views, state, reports, and locally authored
files. Imported declarations could leave two plausible editable configurations. Source monitors
also needed to distinguish unfinished work from concerns already resolved or superseded in code
and current requirements. Source status and age alone cannot establish those outcomes.

## Decision

1. Use responsibility-based layout version 2 for new controllers. Keep shared task/reference/run
   state rather than separate stores per workflow. DAS is the first migration candidate, not an
   authorization to migrate it or any other existing controller now.
2. Keep one editable configuration home per domain under `config/`. Commands edit these same
   declarations; direct edits need no import. Validate and combine them only in memory at the next
   operation or safe boundary. In-flight work stays stable; stop/pause remains live.
3. Separate generated `board/` views, `runtime/` state and locks, and monthly `history/` evidence.
   A short README links these locations without copying status rows. Authored documents, adapters,
   and artifacts keep their own responsibility folders and existing explicit destinations.
4. Name new reports with UTC timestamp, topic, and run ID. Explicit migration reorganizes owned
   existing reports and updates stored paths while preserving contents and identities.
5. Add `/hn migrate` as an in-place layout/configuration conversion. Preview first; apply only
   after approval. `init` reconnects without migration. Root relocation and OS-timer migration
   remain separate actions. Refuse active/unrecovered work and ambiguous/colliding storage.
6. Discovery follows collection, service relevance, Auto status verification, local reconciliation,
   and priority ranking. Auto means AI model-selection mode `auto`, not Max or merely scheduling.
   Development retains its strongest permitted double-check and independent validation/review.
7. Reconcile evidence-backed local already-fixed/stale outcomes automatically. Unknown stays
   unverified. Current repository/source revisions, exact evidence, ownership, and unchanged task
   records guard reconciliation. External ADO/document updates require separate source-specific
   enablement and approval; the built-in verifier provides no external writeback.

## Alternatives

- Workflow-specific folders and stores were rejected because shared tasks, queues, and evidence
  would gain competing owners.
- Importing declarations into another editable active configuration was rejected because changes
  could target the wrong copy.
- Silent migration during initialization was rejected because existing adapters and external
  board locations need an explicit reviewed transition.
- A Max monitor verifier was revised to model auto because development already performs the
  stronger double-check. Terminal monitor outcomes still need their own evidence: they may never
  reach development.
- Source Closed, disappearance, or elapsed age as automatic completion rules were rejected.

## Consequences

Configuration reads must validate a consistent set, and scheduler progress must not overwrite
direct declaration edits. Migration and report retention need coordinated path handling. Temporary
originals protect an in-progress update; successful completion or verified rollback removes them.
There is no permanent backup archive. Custom adapters/snapshots are preserved, not blindly rewritten
or deleted, and their old path assumptions must be reviewed before a live migration.

Verification is read-only and shares existing budgets, permissions, ownership, and pause controls.
It checks code and evidence but does not execute tests or certify deployed behavior. Missing required
runtime or release evidence stays unverified. Existing terminal tasks are not silently reopened;
revised completed work uses the existing explicit follow-up workflow.

## Implementation and Rollout

The [accepted project-qualified naming decision](2026-09-25-project-qualified-board-names-adr.md)
refines the current-work CSV filename for new controllers and provides guarded explicit rename
and filtered-export behavior. Existing board filenames are preserved unless explicitly changed.
The [source-agnostic monitoring decision](2026-09-25-source-agnostic-monitoring-adr.md) refines
partial-result visibility, evidence revalidation, related-source reconciliation, and resumable coverage.

The [current plan](../2026-09-15-harness-command-and-record-contracts.md),
[runtime contract](../../../skills/planning/harness/references/runtime.md), and
[discovery contract](../../../skills/planning/harness-monitor/references/discovery.md) describe current behavior.
Source validation uses isolated controllers and fake workers. Affected existing managed latest
skill copies follow the repository's guarded synchronization instruction. No live controller
migration, monitor execution, external writeback, or schedule change is authorized by this record.