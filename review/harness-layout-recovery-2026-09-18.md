# Harness Layout Investigation

- Date: 2026-09-18
- Scope: Suspected rollback of the agreed topic/action skill layout.
- Status: Approved obsolete-harness cleanup applied; recovery copy retained.

The findings below describe the pre-cleanup evidence. The recovery outcome follows them.

## Findings

### Obsolete Source Files Coexist With the Current Implementation

The agreed contract is `/harness-<topic> <action>`, with `/harness` for root/init/context.
`/hn-*` is conversational shorthand, not a second registered family. The current
[catalog](../catalog.json), [agent notes](../AGENTS.md), and
[topic plan](../docs/plans/2026-09-16-topic-skill-refactor.md) still specify that contract.

All 11 cataloged harness bundles were compared byte-for-byte with their corresponding
project-installed copies: every comparison passed. The current topic/action and Root
instruction tests also passed. The canonical implementation has not been replaced by
the obsolete folders shown in Explorer.

However, 25 files remain under these 13 retired source directories:

| Retired Directory | Current Owner |
| --- | --- |
| `harness-context` | `harness`, action `context` |
| `harness-decide` | `harness-decision` |
| `harness-fallback` | `harness-policy`, fallback target |
| `harness-init` | `harness`, action `init`, and shared runtime |
| `harness-loc` | `harness`, action `root`, with legacy board routing |
| `harness-management` | `harness` |
| `harness-ref` | `harness-link` |
| `harness-report-create` | `harness-report`, action `create` |
| `harness-restrict` | `harness-policy`, limits target |
| `harness-root` | `harness`, action `root` |
| `hn-decision` | `harness-decision` |
| `hn-management` | `harness` |
| `hn-timer` | `harness-timer` |

These are not an intentionally supported compatibility layer. Some are intermediate
wrappers, while others contain older instruction text or partial resources. For example,
the archived `harness-init` wrapper forwards to `hn-management`, and the archived
`harness-management` entry advertises `loc|init|context|status|help`. The current
[development topic](../skills/planning/harness-dev/SKILL.md) uses `list|run|queue`.
Keeping these parallel source trees violates the repository's agreed layout and contributes
to the existing repository-wide validation failures.

### Retained Editor State Contains the Obsolete Paths

The active chat's persisted editing session still lists all 25 obsolete files as accepted
snapshot entries. Their on-disk text exactly matches those stored snapshots. The last
recorded operation for each is a text edit at its former path, not a deletion. A separate
old file, `harness-management/references/root.md`, is recorded as deleted and is absent.

The refactor history includes filesystem-level moves outside the editor edit timeline.
The evidence is consistent with stale editor-tracked paths being left or re-saved alongside
the new directories, but it does not identify the exact write/restore event or actor.
Reading the installed VS Code restore implementation does not prove that reopening the
chat alone recreated the files; its missing-file restore path can skip an entry.

Git HEAD remains `c7af2af`. The reflog shows no checkout or reset after the September 16
commit sequence. This excludes a later recorded branch/HEAD rollback, not individual file
restores or editor writes. The topic refactor is still uncommitted, so restoring HEAD would
discard newer work rather than recover the agreed implementation.

### No Newer Implementation Found in Orphaned Sessions

The local session index contains the current SkillVault conversation and one older related
session last updated at 2026-09-16 02:23 UTC, before the topic refactor decisions.
The current workspace retains five additional editing-session directories without matching
chat files: four contain no edits or content, and one contains only an untitled historical
`/sv-upsert` command. None supplies a newer harness implementation.

This result covers the available local index and retained snapshots for this workspace.
It does not claim recovery of physically deleted history or investigation of other devices.

## Recovered Decision State

The current conversation `a105743a-7ff7-46eb-b242-871d42f57068` retains the relevant decisions:

- September 16, turns 332/335/336: topic/action routing proposed, selected, and authorized.
- Turn 355: full `harness-*` registrations; `hn-*` only for conversation or quick typing.
- Turns 357 onward: top-level `harness`, unified root selection, and `harness-link`.
- Turns 368/371/379: read-only `list` defaults and concise, nonoverlapping primary actions.
- Later clarification: root changes keep the new selection; an initialized previous harness
  moves after the displayed Move-default prompt, including no answer, unless explicitly overridden.
- Turn 403: full `skillvault-*` registrations; `sv-*` only as conversational shortcuts.

Separate design work remains unfinished, not rolled back:

- Q2 selected whole-repository coverage for the fresh review pass. The
  [current worker prompt](../skills/planning/harness/scripts/harness-runner.ps1)
  still limits that pass to the selected change set; implementation was not started during grilling.
- Q3 verified that completion means validation/review in the assigned workspace, not integration;
  final design confirmation remained pending.
- Q4 discussed normalized exact matching. The
  [current intake matcher](../skills/planning/harness/scripts/harness-store.ps1)
  still compares source, scope, and repository reference case-sensitively.
- Q5 linked follow-up tasks remained a proposal. No acceptance is inferred from adjacent requests.

## Recommended Recovery

1. Preserve the current canonical source, installed copies, and retained edit history. Do not
   reset the worktree or restore an entire earlier snapshot.
2. After approval of the exact selection, back up the 13 retired directories outside skill
   discovery, then remove their files through editor-aware edits so their old tracked paths
   are no longer treated as current. Preserve any newly discovered unique changes for review.
3. Recheck the source tree after editor/session reconciliation. Do not edit VS Code's active
   persistence database or discard unrelated unsaved buffers as an automatic cleanup step.
4. Run the naming contract and catalog/resource checks. Other obsolete source artifacts,
   including the separately reported legacy Jarvis bundle, require their own reviewed selection;
   do not weaken validation or claim a full pass while they remain.
5. Keep the agreed topic/action structure. Complete the remaining design interview separately
   before implementing its unresolved matching and lifecycle choices.

No source bundles, installed copies, Git references, live harness state, or schedules were
changed by this investigation. Only this report was added.

## Recovery Applied

The user approved removing the exact 13 obsolete harness directories after backup. All 25 files
were copied and verified before editor-aware deletion; only the resulting empty directory shells
were removed afterward. No live process or saved task referenced their source paths.

Recovery copy: `C:/Users/zhaolongwang/.copilot/skillvault/recovery/harness-topics-20260918-db9c3ecceb1e40019452f0d83cf20072/`.

The canonical naming test passes and now explicitly rejects every retired directory in the
selection. Task intake remains separate from dev execution. `/harness clean` owns history and
retention; timer cleanup is schedule-only, and weekly maintenance reuses the harness history
engine. These boundary changes do not implement the separate unfinished design choices above.
No Git reset, session-database edit, or live data cleanup was performed.

The six affected existing installed copies were refreshed and verified against source. All 19
Node contracts and every runtime/installer fixture group passed; full catalog validation remains
blocked by the separately reported uncataloged `jarvis-metrics-create` bundle, left untouched.
The live scheduler JSON and SkillVault/PACS task definitions were unchanged after refresh.