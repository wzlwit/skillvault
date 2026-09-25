# ADR: Harness Command and Record Contracts

- Date: 2026-09-15
- Status: Proposed
- Decision owner: Zhaolong Wang
- Scope: Harness initialization, shared rules, skill installation, and decision records.
- Supersedes: None.

The overall harness remains proposed. The confirmed choices below do not accept every
execution contract or authorize implementation. The linked
[working plan](../2026-09-15-harness-command-and-record-contracts.md) contains the current
command details and remaining questions; this record preserves the reasons behind the choices.

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
| No-argument `/hn-decide` shows open decisions first, then recent decisions | Put choices needing the owner's attention before recent outcomes, without changing decision state. | [Decision Bulletin](../2026-09-15-harness-command-and-record-contracts.md#decision-bulletin) |
| Canonical `harness-*` names with `/hn-*` shortcuts | Follow the full-name/short-trigger convention without duplicate skill installations. | [Command Contracts](../2026-09-15-harness-command-and-record-contracts.md#command-contracts) |
| Shared declared test flows and environments for ad-hoc, timer, and post-dev runs | Reuse one test definition and executor across triggers while keeping environment identity and evidence explicit. | [Test Flows](../2026-09-15-harness-command-and-record-contracts.md#test-flows) |

### Still Proposed

The shared coordinator, unified development/verification/fix executor, independent reviewer,
`now`/`next` scheduling, and bounded fresh-critical review pass remain proposed in the working
plan. The [local runtime](../../skills/public/planning/harness-init/references/runtime.md) now provides
the command implementations and single-machine state handling. It does not accept the owner's
per-project workspace/model/permission choices or create a live timer. No `/adr` alias is added.

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

- [Rules Core](../../skills/public/core/rules-core/SKILL.md)
- [SkillVault Install](../../skills/public/core/skillvault-install/SKILL.md)
- [Architecture Decision Records](../../skills/writing/architecture-decision-records/SKILL.md)
- [Graphify reference](../../skills/codeview/graphify/SKILL.md)