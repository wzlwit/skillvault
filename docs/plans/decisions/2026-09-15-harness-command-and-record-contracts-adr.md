# ADR: Harness Command and Record Contracts

- Date: 2026-09-15
- Status: Partially superseded (original status: Proposed)
- Decision owner: Zhaolong Wang
- Scope: Harness initialization, shared rules, skill installation, and decision records.
- Supersedes: None.

At this record's proposal stage, the overall harness remained proposed. The confirmed choices
below did not by themselves accept every execution contract or authorize implementation. The linked
[working plan](../2026-09-15-harness-command-and-record-contracts.md) contains the current
command details and remaining questions; this record preserves the reasons behind the choices.

The later [accepted upsert and work-contract ADR](./2026-09-18-upsert-and-harness-work-contracts-adr.md)
records the September 18 authoring, Fresh-scope, completion, matching, and follow-up decisions.
The historical proposal text below is retained; that later record resolves its Fresh-scope question.

## Context

The requested harness coordinates development, verification, fixes, and independent review
through shared task and run state. Work can arrive through conversation, local reports, or
external links. Initialization should establish rules and project context before further work.

The [external harness draft](../2026-09-15-project-agent-harness.md) is background for discussion,
not a prerequisite to implement its whole platform. Its project-specific choices, capability
claims, and accepted decisions are not automatically adopted or superseded by this record.

Keeping every command detail and decision rationale in one growing document would mix a
changing plan with lasting decision history. Installing a guide is also different from loading
its rules into a worker or providing an upstream runtime.

## Decision

### Confirmed Choices

Keep the choices and rationale here; maintain workflow details in the linked plan sections.

| Confirmed choice | Rationale | Plan details |
| --- | --- | --- |
| CSV indexes with linked Markdown detail; no duplicate dashboard | Keep structured records filterable without duplicating narrative evidence. | [Plans and Records](../2026-09-15-harness-command-and-record-contracts.md#plans-and-records) |
| Rules Core and project instructions at every entrypoint and worker | Parent context and global installation do not provide automatic rule inheritance. | [Rules Before Work](../2026-09-15-harness-command-and-record-contracts.md#rules-before-work) |
| Graphify and ADR context before offering grilling | Ground the interview in project evidence while leaving decisions with the user. | [Initialization](../2026-09-15-harness-command-and-record-contracts.md#initialization) |
| Install declared missing SkillVault dependencies without repeated prompts | Init approval covers the known dependency set, not replacements or arbitrary upstream runtimes. | [Missing Skill Installation](../2026-09-15-harness-command-and-record-contracts.md#missing-skill-installation) |
| Global ADR and Graphify guides, with project overrides | Reuse guides across projects without changing where their outputs belong or implying a bundled Graphify CLI. | [Missing Skill Installation](../2026-09-15-harness-command-and-record-contracts.md#missing-skill-installation) |
| Separate ADR history and current plans | Preserve reasons and superseded choices while authorized plan updates reflect accepted outcomes. | [Plans and Records](../2026-09-15-harness-command-and-record-contracts.md#plans-and-records) |
| Project documentation under its established root, with `docs/` as the fallback | Reuse `doc/` or `docs/` conventions rather than create parallel roots; this repository now keeps plans and their ADRs under `docs/`. Runtime boards and skill-owned files are separate. | [Plans and Records](../2026-09-15-harness-command-and-record-contracts.md#plans-and-records) |
| No-argument `/hn-decide` shows open decisions first, then recent decisions | Put choices needing the owner's attention before recent outcomes, without changing decision state. | [Decision Bulletin](../2026-09-15-harness-command-and-record-contracts.md#decision-bulletin) |
| Canonical `harness-*` names with `/hn-*` shortcuts | Follow the full-name/short-trigger convention without duplicate skill installations. | [Command Contracts](../2026-09-15-harness-command-and-record-contracts.md#command-contracts) |
| Shared declared test flows and environments for ad-hoc, timer, and post-dev runs | Reuse one test definition and executor across triggers while keeping environment identity and evidence explicit. | [Test Flows](../2026-09-15-harness-command-and-record-contracts.md#test-flows) |
| Separate restriction and fallback commands over existing runtime state | Distinguish permitted boundaries from failure responses; inspect by default, require explicit policy changes, and preserve safety pauses across timer/recovery operations. This selects no live thresholds. | [Restrictions and Fallback](../2026-09-15-harness-command-and-record-contracts.md#restrictions-and-fallback) |
| Bare timer invocation requests E2E schedule setup; topic text selects a workflow | Make the primary recurring workflow directly accessible while keeping status explicit. Reuse the gated executor, require concrete custom flows, and leave cadence/permissions as explicit project choices. This replaces the earlier bare-status timer behavior, not other skills' read-only defaults. | [Timer Workflows](../2026-09-15-harness-command-and-record-contracts.md#timer-workflows) |
| Add monitoring evaluation and incident proposals; initially defer a separate report-authoring skill | Reuse structured observations, timer, tasks, and references; separate health from collection failure and execution approval. Only the authoring deferral is superseded by the [report-authoring ADR](./2026-09-15-harness-report-authoring-adr.md). No live sources or conditions are selected. | [Monitoring](../2026-09-15-harness-command-and-record-contracts.md#monitoring) |

### Still Proposed

This heading preserves the original proposal status. The five baseline clauses below are now
accepted in their current form by the [September 24 ADR](./2026-09-24-recovery-compatibility-and-harness-baseline-adr.md#current-harness-baseline).
Only their proposal status is superseded; the original wording below remains historical.

The shared coordinator, unified development/verification/fix executor, independent reviewer,
`now`/`next` scheduling, and development's critical-review policy remain proposed in the working
plan. The [local runtime](../../../skills/planning/harness/references/runtime.md) now provides
the command implementations and single-machine state handling. It does not accept the owner's
per-project workspace/model/permission choices or create a live timer. No `/adr` alias is added.

The [standalone review contract](../2026-09-15-harness-command-and-record-contracts.md#standalone-review)
implements ahead/working-change scope and a bounded fresh pass with optional security-guide
composition. At this record's proposal stage, whole-repository refresh scope was unconfirmed.
That question is resolved by the later accepted ADR linked above; neither record authorizes
live execution while the owner is unavailable.

## Alternatives

| Alternative | Assessment |
| --- | --- |
| Separate dev and fix skills with independent execution | Not preferred: they share intake, validation, and scheduling; independent state could duplicate work. Thin aliases can be reconsidered without creating another runner. |
| One worker that implements and reviews its own changes | Not preferred: simpler coordination, but self-review does not provide independent scrutiny. |
| Shared coordinator, unified dev, independent review | Proposed: separates responsibilities while reusing task state and executable validation. Requires a real runner, not just prompts. |
| Load the rules only in init | Not selected: direct entrypoints and fresh workers need the same applicable rules in their own execution context. |
| Project-only ADR and Graphify guides | Not the default: these reusable guides should be available across projects. Explicit project installs remain supported for project-specific needs. |
| Prompt for every missing declared skill | Not preferred: approving init's declared dependency set avoids repeated prompts, while replacements and upstream runtime setup remain separately controlled. |
| Rewrite plans instead of preserving ADRs | Not selected: plans should show the current direction, while ADRs retain earlier rationale and supersession history. |
| Markdown-only status and one growing log | Not selected for structured records: retain Markdown for explanation and use CSV for filterable indexes. |
| Adopt a full external runtime and task database immediately | Deferred: existing tools may supply timers or task claims, but their dependencies and policies have not been selected. |

## Consequences

Shared rules and explicit dependency handling make the intended startup behavior consistent
across entrypoints. Global guides avoid requiring a new copy for every project, but updates
can affect multiple projects, so init must not silently overwrite existing installs. Global
availability does not imply always-on rules or a ready Graphify runtime.

Separating the plan and ADR avoids repeating detailed rationale while preserving why choices
were made. Accepted changes require keeping affected plan sections and decision links aligned.
CSV is useful for filtering and inspection, but it is not a transactional scheduler and does
not make an unbounded record cheap to read.

Writing or accepting these records does not authorize workers, schedules, remote comments,
commits, pushes, PR approval, merging, or deployment. Such actions retain their own permissions.

## Open Decisions

See the [working plan's open decisions](../2026-09-15-harness-command-and-record-contracts.md#open-decisions).

## References

- [Rules Core](../../../skills/core/rules/references/core.md)
- [SkillVault Install](../../../skills/core/skillvault-installation/references/install.md)
- [Architecture Decision Records](../../../skills/writing/architecture-decision-records/SKILL.md)
- [Graphify reference](../../../skills/codeview/graphify/SKILL.md)