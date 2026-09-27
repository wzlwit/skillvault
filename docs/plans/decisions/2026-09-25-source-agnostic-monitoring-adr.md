# ADR: Source-Agnostic Monitoring and Evidence Reconciliation

- Date: 2026-09-25
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: Partial results, evidence revalidation, explicit source correlation, coverage, and conflicts.
- Refines: [Declarative layout and Auto verification](2026-09-25-declarative-harness-and-auto-verification-adr.md). Existing layout, filenames, model selection, permissions, and execution approvals remain unchanged.

## Context

A failed source should not conceal independently verified work. Requirements can appear in
multiple sources, and completed work can regress without a source edit. Large checks must make
progress within approved budgets. These behaviors belong to the shared monitoring pipeline;
ADO and local folders are examples, not provider boundaries.

## Decisions

1. Keep the overall result Partial when coverage is incomplete. Expose a separately labeled
   verified subset for explicit manual acceptance, with unavailable sources and remaining coverage
   visible. A subset is neither a complete pickup list nor permission for automatic execution.
2. Check current implementation and acceptance evidence before reusing completion. Changed evidence
   triggers revalidation, not an assumed defect. Verified regressions or material requirement changes
   propose explicit follow-ups with Unknown risk and automatic eligibility off. Completed task
   history remains intact; unchanged source status alone does not reopen it.
3. Correlate requirements only through explicit same-requirement links or declarations. Preserve
   every source's identity, revision, owner, acceptance, timestamps, and evidence. Aliases share one
   work item; text similarity is insufficient. Existing separate tasks and repository boundaries
   require explicit review rather than silent merging or retargeting.
4. Store coverage checkpoints in existing runtime state. Resume pending verification at the next
   approved check and reuse still-current evidence only after input/freshness checks. Ordinary
   capacity deferral is Partial, not a safety pause. Actual timeouts, stops, interruptions, and
   policy violations retain their existing handling. Add no budget, timer, or automatic retry.
5. For substantive contradictions, use explicitly declared authority for the exact disputed fact.
   Otherwise preserve both claims and mark affected work Unverified, withholding dependent acceptance
   and completion conclusions. Different source owners or status labels alone are not conflicts.
   Unrelated verified work remains available.

## Alternatives

- Hiding all work after one source fails discards useful verified evidence.
- Trusting historical completion forever misses regressions; reopening from source labels rewrites
  history without implementation evidence.
- Fuzzy merging can combine distinct requirements and lose ownership or acceptance obligations.
- Choosing a provider, newest timestamp, or owner as implicit authority invents a decision.
- Restarting every large check from unchanged early items can prevent remaining work from being reviewed.

## Consequences

The normalized adapter contract supports explicit relationships and evidence-bound named claims.
Optional correlation declarations and fact authorities live beside monitors, not in another task
store. All-source collection precedes verification; read ownership and snapshots remain held until
group reconciliation. Canonical views expose provenance and conflicts without duplicating tasks.
Retention and approved relocation preserve checkpoint reports and owned evidence paths.

The monitor-discovery interface is version 5; the existing harness-runtime interface remains 4.
Source/copy updates add no connector, listener, credential, live source, migration, remote write,
development worker, or schedule. Validation uses temporary fixtures and fake providers/workers;
managed latest copies follow the repository's guarded installation procedure.

## References

- [Current plan](../2026-09-15-harness-command-and-record-contracts.md#monitoring)
- [Source contract](../../../skills/planning/harness-monitor/references/discovery.md)
- [Shared runtime](../../../skills/planning/harness/references/runtime.md#monitoring)