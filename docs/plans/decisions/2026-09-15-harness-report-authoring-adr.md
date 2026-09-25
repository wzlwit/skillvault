# ADR: Report Authoring Dispatch

- Date: 2026-09-15
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: Report-authoring workflow and reusable KPI design guidance, not live reporting setup.
- Supersedes: Only the report-authoring-skill deferral in the
  [harness command ADR](./2026-09-15-harness-command-and-record-contracts-adr.md).
- Installation-default clause superseded by the [scope audit](../../../review/install-scopes-2026-09-15.md).
  The authoring workflow remains Accepted; the original decision below is retained for history.

## Context

Monitoring evaluates observations and proposes investigations, while creating queries, dashboards,
and reports needs platform-specific authoring tools. Repeating that distinction in general
development requests does not provide a reusable way to choose the appropriate authoring workflow.
The inspected upstream KPI skill supplies useful design guidance but its examples are not a
validated cross-platform report generator.

## Decision

Add native `harness-report-create` as a thin session-level dispatcher and a curated, reusable
`kpi-dashboard-design` companion, both project-default. Reuse local development/task handling
and existing platform tools, load only the relevant specialist, preserve artifact identity, and
distinguish design-only from created, validated, and separately published results.

Keep monitoring and publication separate. Do not add a renderer, runtime dispatcher action,
connector installation, report registry, or recurring authoring timer. Preserve Seth Hobson's
MIT attribution for the KPI adaptation and omit unverified upstream executable examples.
See the [current authoring workflow](../2026-09-15-harness-command-and-record-contracts.md#report-authoring)
for command contracts and capability checks rather than duplicating them here.

## Alternatives and Consequences

- General `/hn-dev` alone remains available, but does not specialize platform selection or delivery claims.
- A universal reporting engine is not selected: it adds integrations beyond the requested workflow.
- Copying all upstream platform guides is not selected: it duplicates maintenance and confuses
  installed instructions with working tools. Specialist skills stay separately discoverable.

The dispatcher can be available before a platform writer is installed, so missing capabilities
must remain explicit. This decision authorizes the skill implementation, not a report deployment,
source connection, automatic skill installation, publishing operation, or monitoring policy.