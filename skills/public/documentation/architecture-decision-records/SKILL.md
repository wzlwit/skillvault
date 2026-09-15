---
name: architecture-decision-records
description: Write or review architecture decision records. Use for ADRs, significant technology choices, design trade-offs, decision history, or superseding an accepted architectural decision. Overlaps with grilling on trade-offs and planning-with-files on decision notes; focuses on lasting decision history.
metadata:
  author: Seth Hobson
  maintainer: wzlwit
  version: null
---

# Architecture Decision Records

Record why a consequential technical choice was made, not just what the implementation
does. Routine fixes and configuration edits do not need new decision records by default.

## Workflow

1. Read the existing ADR index, template, and any governing design sections. Identify the
   decision owner, current status, scope, and relevant code or authoritative references.
2. Separate facts, constraints, alternatives, assumptions, and open decisions. Ask only for
   decisions the user must make. Do not turn a deferred question into an accepted decision.
3. Use the repository's format and numbering. If none exists, propose a short Markdown
   record with status, context, decision, alternatives, consequences, and supporting links.
4. Draft with `Proposed` status unless acceptance is explicitly established. Include the
   chosen option's real costs, compatibility concerns, and reversibility; do not invent
   measurements, approval, deployment dates, or benefits to make the decision sound stronger.
5. Preserve accepted history. When a decision changes, write a new record and link the
   superseded one, updating its status and index as authorized. Do not silently rewrite the
   rationale of an accepted record to match today's preference.
6. Read the finished record as a future maintainer: can they identify the decision, reasons,
   alternatives rejected, consequences, and unresolved questions without the chat? Check
   links, numbering, status consistency, and code-derived facts with the cheapest useful checks.
7. Report the record path, status, related records, and remaining decisions. Writing an ADR
   does not authorize implementation, commits, PRs, or notification to other people.

## Fit

`grilling` helps resolve choices before documentation. This skill preserves the decision
history; `humanizer` can improve prose afterward without changing its facts or status.
No CLI, external service, template bundle, or automatic hook is required by this guide.

## Source and Curation

Curated SkillVault guide for Seth Hobson's
[ADR skill in wshobson/agents](https://github.com/wshobson/agents/tree/main/plugins/documentation-generation/skills/architecture-decision-records),
which is [MIT licensed](https://github.com/wshobson/agents/blob/main/LICENSE).
Authorship stays with Seth Hobson; wzlwit maintains this curated guide. The wording is
rephrased for SkillVault and is not the unchanged upstream skill. Its worked examples remain
upstream; use their structure only, not their historical claims. This guide declares no
version because it does not track an upstream release.