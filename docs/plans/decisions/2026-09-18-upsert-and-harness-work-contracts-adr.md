# ADR: Upsert and Harness Work Contracts

- Date: 2026-09-18
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: Source authoring actions, standalone Fresh review, task identity, completion, and follow-ups.
- Resolves: The Fresh-scope question in the [earlier harness ADR](./2026-09-15-harness-command-and-record-contracts-adr.md#still-proposed). Earlier accepted permission and ownership boundaries remain.

## Context

Two authoring menus exposed create and update even though their workflows already determined
whether a target existed. Harness intake compared raw source/scope/repository strings and could
return an old completed task when requirements changed. The user accepted the five choices below
through grilling and then authorized source, documentation, and test implementation.

## Decision

1. Advertise `upsert` for `skillvault-source` and `harness-report`. Keep `create` and `update` as
   aliases with the same semantics. Update an identified existing target or create a confirmed
   missing target; ambiguous identity or unavailable access is not absence. Existing source,
   installation, publication, and overwrite boundaries remain.
2. The standalone Fresh pass reviews the whole selected repository, including unchanged code,
   configuration, and tests. Ordinary Review and development Critical retain their change scope.
   Existing snapshots, restart limits, read-only permissions, budgets, and isolated PR rules stay
   in force. Inadequate repository coverage is blocked, never a clean verdict.
3. Completed means validation and required independent reviews passed in the assigned workspace,
   with evidence. It does not imply integration, commits, merging, pushing, or deployment.
4. Match tasks by source, scope, and repository after meaning-preserving normalization. Trim outer
   whitespace, canonicalize repository IDs and HTTP(S) URI syntax, and normalize absolute path
   dot segments. Preserve opaque identifiers, URL path/query case, and free-form scope/path case
   and internal whitespace. Free-form scopes may contain code identifiers; do not guess their
   semantics or introduce fuzzy matching.
5. Explicitly revised completed requirements create a linked follow-up with separate validation.
   Preserve the original completion and reports. Repeated identical follow-ups reuse their ID;
   source revision changes alone do not create work. Requirement fields can inherit, but risk
   classification and automatic eligibility do not. For the same repository, reuse the saved
   workspace/base so unmerged work remains the starting point; another repository gets a separate
   allocation. Open follow-ups protect ancestor evidence until ordinary retention applies again.

### Review Continuation Clarification

The owner clarified that an existing dev/proposal workflow already receives findings and owns
fixes. The review coordinator must keep the same request open: Changes, then Full when no new
findings appear; findings from either pass go through that existing handoff, and completed fixes
resume Changes. Stop successfully only after prior issues are rechecked and a stable Changes/Full
round has no supported unfixed findings. No new findings is not completion.

Each script call publishes a checkpoint and releases the run lock so dev can proceed. There is
no additional fixer, notifier, scheduler, or busy loop on unchanged code. Fix-driven continuation
has no fixed round count within the existing budgets, permissions, and pause/failure rules;
the two snapshot-restart limit applies within a script round, not across completed fixes.

## Alternatives and Consequences

- Two visible authoring verbs with identical behavior keep an unnecessary existence decision in
  the menu. One upsert action removes it without breaking old spellings.
- Raw string equality creates avoidable duplicates; blanket case-folding or fuzzy matching can
  merge different code/path identities. Conservative normalization preserves those distinctions.
- Reopening completed tasks rewrites their contract after its evidence was recorded. Linked
  follow-ups preserve the earlier outcome and make the new work inspectable.
- Starting every follow-up from repository HEAD can omit unmerged completed work. Reusing its
  saved workspace avoids that loss without committing or integrating it automatically; existing
  workspace ownership and serialized execution still apply.
- Whole-repository Fresh review may require more coverage than existing budgets permit. Report
  that limitation rather than extending budgets or repeatedly reviewing unchanged code for a
  clean verdict. Resuming after externally validated fixes follows the continuation rule above.

## Implementation and Validation

The [current plan](../2026-09-15-harness-command-and-record-contracts.md) owns operational details.
The shared runtime keeps one intake/update implementation and the existing state/CSV/report stores.
Focused fixtures cover normalized and distinct identities, linked follow-ups, original evidence,
queue-only behavior, retention, Fresh versus Review/Critical scope, and review checkpoints across
external fixes without launching development from review. No installed-copy refresh,
live schedule change, worker deployment, or Git publication is authorized by this implementation.