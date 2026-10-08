# DRI Agent Proposal

Status: Proposed. Nothing here is a command yet except `investigate`. It records the design to grow
`/dri` into and the principles behind it, distilled from the owner's notes on AI-assisted
engineering. Service-specific planning stays in the owner's private projects.

Contents: Principles; Staged Roles; Planned Commands; Preflight Checks; Rollout; Evaluation;
Learning Loop; Guardrails; Measures of Success.

## Principles

- **Build reusable assets, not one-time prompts.** When an investigation works, save it as a
  command, query, profile entry, or check, so the next incident starts further ahead.
- **Ground the agent in authoritative sources and live state:** clear success criteria, the
  product's own documentation, real telemetry and configuration, and explicit rules about what is
  supported.
- **Separate responsibilities.** Focused roles that check each other catch confident but wrong
  conclusions that one general agent misses.
- **Start from a known baseline and handle the difference.** Standard checks remove repeated setup,
  so effort goes to what is unusual about this incident.
- **Measure.** Judge results against explicit criteria and known cases, not impressions.
- **Feed repeated gaps back into the product.** A manual step that keeps coming back should become
  validation, self-healing, or better diagnostics, not a permanent workaround.

## Staged Roles

| Role | Responsibility |
| --- | --- |
| Investigator | Collects evidence; changes nothing |
| Classifier | Assigns a category, such as readiness, provisioning, configuration, validation, execution, monitoring, or a dependency |
| Planner | Proposes a mitigation or repair, with rollback and verification |
| Reviewer | Challenges the plan's assumptions, safety, and scope |
| Executor | Runs only approved operations that the profile allows |
| Verifier | Checks postconditions independently, not from the executor's report |
| Recorder | Writes the incident summary and saves reusable findings |

The same agent must never propose, approve, and execute its own repair.

## Planned Commands

Each becomes an action only after it defines its required evidence, decision rules, outputs, and
failure handling:

- `preflight <target>`: readiness checks before an onboarding, a migration, or a repair.
- `plan <incident>`: a mitigation or repair plan as a dry run, for the Reviewer and the DRI.
- `verify <target>`: postcondition checks after a repair.
- `record <incident>`: an incident summary, plus new or corrected profile entries such as
  signatures, queries, and runbook gaps.

`investigate` starts with bounded, common, low-risk cases, such as a job that ends right after it
starts, and grows its signature catalog from there.

## Preflight Checks

Report each check as Pass, Fail, or Unknown, with its evidence:

- The current path and its dependencies are understood.
- Readiness requirements are met.
- Required configuration records exist, and the references between them are valid.
- Settings and feature flags are correct.
- The operation is safe to retry.
- Required components and service dependencies are deployed.
- No running job conflicts with it.
- Rollback and verification steps are defined.

## Rollout

1. A read-only brief for a few structured, high-volume incident types.
2. Replay on resolved incidents still within retention, scored against what the DRIs actually did.
3. Shadow mode: the brief is shared with the DRIs, who decide and give feedback on its misses.
4. Approved actions, one narrow action at a time, once shadow results meet the bar, such as no
   false resolutions.

## Evaluation

- **Diagnostic accuracy:** did it find the actual failure category?
- **Evidence completeness:** did it gather every required signal?
- **Unsupported-assumption rate:** did it label unknowns instead of inventing causes?
- **Repair safety:** was the proposed action scoped, reversible, and safe to retry?
- **Verification quality:** did it confirm postconditions, not just that a command succeeded?
- **Time saved:** how much investigation and mitigation time did it save?
- **Reuse rate:** how often did a saved check or profile entry help with another incident?

Every significant incident adds a regression case.

## Learning Loop

Record recurring failure categories with their frequency, customer impact, and manual
investigation time, and rank them. The top ones are product backlog candidates: native validation,
self-healing, or better diagnostics instead of agent-only workarounds. Typical categories include
missing or inconsistent configuration, wrong readiness flags, jobs that end without actionable
diagnostics, stale references, suppressed or unsafe retries, gaps in monitoring, and unsupported
transition states.

```text
Observe -> Investigate -> Verify -> Reuse -> Measure -> Productize
```

## Guardrails

- Read-only by default, with the DRI's existing identity and permissions only.
- No production change without explicit approval; only allowed operations; a dry run first; safe
  to retry, with rollback; verified independently afterward.
- No root cause without supporting evidence.
- A complete audit trail: sources read, actions proposed, approvals, executions, and outcomes.
- Escalate when confidence is low, impact is high, or no safe investigation is available.

## Measures of Success

- Less time to the first actionable step and to the right owner.
- More updates that carry evidence and a concrete next step.
- Less duplicated investigation.
- No unapproved production change, and no guess presented as fact.
