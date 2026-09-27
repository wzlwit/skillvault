# ADR: Project-Qualified Current Board Names

- Date: 2026-09-25
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: Canonical current-work CSV naming, explicit renames, and requested filtered exports.
- Refines: The board filename convention in the [declarative layout decision](2026-09-25-declarative-harness-and-auto-verification-adr.md); other storage, ownership, execution, and retention decisions remain unchanged.

## Context

A generic current.csv is difficult to distinguish in editor tabs or exported material. The board
is shared by monitoring, development, and task intake, combining multiple sources. It contains
proposed, running, blocked, and uncertain work, so todo would describe it too narrowly. Independent
monitor-specific filenames would also create competing views and break shared consumers.

## Decisions

1. New controllers default to `current-<project-slug>.csv`, such as `current-das.csv`. Derive a
   lowercase ASCII slug once from the selected root folder and persist the chosen filename in
   project configuration as `currentFileName`. An explicit safe filename can override that default.
2. Keep one canonical all-source view per controller. Use the shared path resolver for writing,
   navigation, status/context, snapshots, relocation, migration, and cleanup projections. Root moves
   retain the persisted name rather than deriving a new one from the destination folder.
3. Configurations without `currentFileName` retain `current.csv`. Reconnect, installation, and layout
   migration do not silently rename existing boards. An explicit Board rename previews first and
   applies only after approval, updating configuration, navigation, and registered/decision links.
4. Renames preserve task identities, queues, and evidence. They reject active/unrecovered work,
   filename collisions, reserved paths, and filesystem links. Temporary originals support rollback;
   incomplete recovery stays blocked. Custom external consumers require separate path review.
5. `current-<project>-<topic>.csv` is reserved for explicitly requested filtered snapshots. Require
   exact monitor filters; the topic is a label, not a guessed semantic filter. Store snapshots under
   `artifacts/board-views/`, use the canonical schema/writer, and record ownership/filter/time metadata.
   They do not replace the canonical file, edit task state, or create execution approval. No automatic
   per-source or per-topic copies are generated.

## Alternatives

- Keep current.csv everywhere: simple but ambiguous when several projects or exports are open.
- Use todo-<project>.csv: clearer project identity but incorrectly suggests only queued work.
- One canonical file per source/topic: rejected because cross-source priority and task ownership
  need one shared view. Explicit filtered exports cover inspection without another task store.
- Rename all existing files on update: rejected because custom consumers may depend on old paths.

## Consequences

Consumers must resolve the configured path rather than hard-code a basename. The ownership marker
records the published filename for safe transitions, not another editable configuration. A direct
filename declaration edit requires the guarded rename to publish it; ordinary runtime settings keep
their existing direct-edit activation contract. Filtered exports are point-in-time artifacts and
refresh only on an explicit request. No live board rename or schedule change is implied by this ADR.

## References

- [Current plan](../2026-09-15-harness-command-and-record-contracts.md#plans-and-records)
- [Current-view procedure](../../../skills/planning/harness/references/loc.md#current-view-names)
- [Shared runtime](../../../skills/planning/harness/references/runtime.md#configuration-and-state)