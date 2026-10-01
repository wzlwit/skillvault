---
name: architecture-decision-records
description: Write or review architecture decision records. Use for ADRs, significant technology choices, design trade-offs, decision history, or superseding an accepted architectural decision. Overlaps with grilling on trade-offs, planning-with-files on decision notes, harness-decision on decision history, and harness-doc on reader-facing rationale; focuses on lasting rationale and supersession.
metadata:
  author: Seth Hobson
  maintainer: wzlwit
  version: null
---

# Architecture Decision Records

Adapted from Seth Hobson's ADR skill (`https://github.com/wshobson/agents`,
`plugins/documentation-generation/skills/architecture-decision-records`), MIT; see
`UPSTREAM-LICENSE`. The original's templates and examples are in the Original section below.
Where it differs, the SkillVault rules above it win: save records as in Save Location, not the
original's `docs/adr/`; write the files directly instead of installing `adr-tools`; and use the
original's examples for structure only, not their historical claims.

Record why a consequential technical choice was made, not just what the implementation
does. Routine fixes and configuration edits do not need new decision records by default.

## Save Location

For a new ADR, use the first applicable destination:

1. The file or directory the user supplied for this request.
2. The target project's established ADR location, from its instructions, ADR index, or existing
   decision records.
3. `plans/decisions/` under the project's documentation root, discovered from project instructions,
   documentation configuration, README links, and existing content. Reuse `doc/` or `docs/` rather
   than creating a competing root.
4. `<project-root>/docs/plans/decisions/` when no documentation root is established. Create the
   directory when writing the record; this unambiguous fallback needs no location argument or
   extra prompt.

Resolve relative destinations against the target project's root, not the skill's installation
folder; global installation changes availability, not where records are saved. If both `doc/` and
`docs/` exist, follow the documented or used root and ask only if conventions remain ambiguous.
Keep an existing ADR in place unless the user requests a move, and do not relocate other projects'
records as part of this fallback.

## Workflow

1. Read the existing ADR index, template, and any governing design sections. Identify the
   decision owner, current status, scope, and relevant code or authoritative references.
2. Separate facts, constraints, alternatives, assumptions, and open decisions. Ask only for
   decisions the user must make. Do not turn a deferred question into an accepted decision.
3. Resolve the destination using Save Location above and use the repository's format and
   numbering. If no format exists, use a short Markdown record with status, context, decision,
   alternatives, consequences, and supporting links.
4. Draft with `Proposed` status unless acceptance is explicitly established. Include the
   chosen option's real costs, compatibility concerns, and reversibility; do not invent
   measurements, approval, deployment dates, or benefits to make the decision sound stronger.
   Keep the record short and easy to follow: state each point once and link supporting
   material instead of copying it.
5. Preserve accepted history. When a decision changes, write a new record and link the
   superseded one, updating its status and index as authorized. Do not silently rewrite the
   rationale of an accepted record to match today's preference.
6. Read the finished record as a future maintainer: can they identify the decision, reasons,
   alternatives rejected, consequences, and unresolved questions without the chat? Check
   links, numbering, status consistency, and code-derived facts with the cheapest useful checks.
7. Report the record path, status, related records, and remaining decisions. Writing an ADR
   does not authorize implementation, commits, PRs, or notification to other people.

## Fit

- `grilling` resolves choices before documentation; `humanizer` can improve prose afterward
  without changing facts or status.
- `harness-decision` shows open/recent decision bulletins and keeps a compact CSV register; this
  skill owns the full architectural rationale and superseding ADRs.
- `harness-doc` turns verified rationale into feature guides, onboarding, and troubleshooting
  material, referencing accepted records without replacing decision history or changing statuses.
- No CLI, external service, template bundle, or automatic hook is required by this skill.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.

## Original

<!-- upstream:begin -->
<!-- Original: https://github.com/wshobson/agents plugins/documentation-generation/skills/architecture-decision-records at 156b7a5e7a8b93642628a339ee4039c925b34c7f. Refresh replaces this section; put SkillVault changes outside it. -->

# Architecture Decision Records

Comprehensive patterns for creating, maintaining, and managing Architecture Decision Records (ADRs) that capture the context and rationale behind significant technical decisions.

## When to Use This Skill

- Making significant architectural decisions
- Documenting technology choices
- Recording design trade-offs
- Onboarding new team members
- Reviewing historical decisions
- Establishing decision-making processes

## Core Concepts

### 1. What is an ADR?

An Architecture Decision Record captures:

- **Context**: Why we needed to make a decision
- **Decision**: What we decided
- **Consequences**: What happens as a result

### 2. When to Write an ADR

| Write ADR                  | Skip ADR               |
| -------------------------- | ---------------------- |
| New framework adoption     | Minor version upgrades |
| Database technology choice | Bug fixes              |
| API design patterns        | Implementation details |
| Security architecture      | Routine maintenance    |
| Integration patterns       | Configuration changes  |

### 3. ADR Lifecycle

```
Proposed → Accepted → Deprecated → Superseded
              ↓
           Rejected
```

## Templates

### Template 1: Standard ADR (MADR Format)

```markdown
# ADR-0001: Use PostgreSQL as Primary Database

## Status

Accepted

## Context

We need to select a primary database for our new e-commerce platform. The system
will handle:

- ~10,000 concurrent users
- Complex product catalog with hierarchical categories
- Transaction processing for orders and payments
- Full-text search for products
- Geospatial queries for store locator

The team has experience with MySQL, PostgreSQL, and MongoDB. We need ACID
compliance for financial transactions.

## Decision Drivers

- **Must have ACID compliance** for payment processing
- **Must support complex queries** for reporting
- **Should support full-text search** to reduce infrastructure complexity
- **Should have good JSON support** for flexible product attributes
- **Team familiarity** reduces onboarding time

## Considered Options

### Option 1: PostgreSQL

- **Pros**: ACID compliant, excellent JSON support (JSONB), built-in full-text
  search, PostGIS for geospatial, team has experience
- **Cons**: Slightly more complex replication setup than MySQL

### Option 2: MySQL

- **Pros**: Very familiar to team, simple replication, large community
- **Cons**: Weaker JSON support, no built-in full-text search (need
  Elasticsearch), no geospatial without extensions

### Option 3: MongoDB

- **Pros**: Flexible schema, native JSON, horizontal scaling
- **Cons**: No ACID for multi-document transactions (at decision time),
  team has limited experience, requires schema design discipline

## Decision

We will use **PostgreSQL 15** as our primary database.

## Rationale

PostgreSQL provides the best balance of:

1. **ACID compliance** essential for e-commerce transactions
2. **Built-in capabilities** (full-text search, JSONB, PostGIS) reduce
   infrastructure complexity
3. **Team familiarity** with SQL databases reduces learning curve
4. **Mature ecosystem** with excellent tooling and community support

The slight complexity in replication is outweighed by the reduction in
additional services (no separate Elasticsearch needed).

## Consequences

### Positive

- Single database handles transactions, search, and geospatial queries
- Reduced operational complexity (fewer services to manage)
- Strong consistency guarantees for financial data
- Team can leverage existing SQL expertise

### Negative

- Need to learn PostgreSQL-specific features (JSONB, full-text search syntax)
- Vertical scaling limits may require read replicas sooner
- Some team members need PostgreSQL-specific training

### Risks

- Full-text search may not scale as well as dedicated search engines
- Mitigation: Design for potential Elasticsearch addition if needed

## Implementation Notes

- Use JSONB for flexible product attributes
- Implement connection pooling with PgBouncer
- Set up streaming replication for read replicas
- Use pg_trgm extension for fuzzy search

## Related Decisions

- ADR-0002: Caching Strategy (Redis) - complements database choice
- ADR-0005: Search Architecture - may supersede if Elasticsearch needed

## References

- [PostgreSQL JSON Documentation](https://www.postgresql.org/docs/current/datatype-json.html)
- [PostgreSQL Full Text Search](https://www.postgresql.org/docs/current/textsearch.html)
- Internal: Performance benchmarks in `/docs/benchmarks/database-comparison.md`
```

### Template 2: Lightweight ADR

```markdown
# ADR-0012: Adopt TypeScript for Frontend Development

**Status**: Accepted
**Date**: 2024-01-15
**Deciders**: @alice, @bob, @charlie

## Context

Our React codebase has grown to 50+ components with increasing bug reports
related to prop type mismatches and undefined errors. PropTypes provide
runtime-only checking.

## Decision

Adopt TypeScript for all new frontend code. Migrate existing code incrementally.

## Consequences

**Good**: Catch type errors at compile time, better IDE support, self-documenting
code.

**Bad**: Learning curve for team, initial slowdown, build complexity increase.

**Mitigations**: TypeScript training sessions, allow gradual adoption with
`allowJs: true`.
```

### Template 3: Y-Statement Format

```markdown
# ADR-0015: API Gateway Selection

In the context of **building a microservices architecture**,
facing **the need for centralized API management, authentication, and rate limiting**,
we decided for **Kong Gateway**
and against **AWS API Gateway and custom Nginx solution**,
to achieve **vendor independence, plugin extensibility, and team familiarity with Lua**,
accepting that **we need to manage Kong infrastructure ourselves**.
```

### Template 4: ADR for Deprecation

```markdown
# ADR-0020: Deprecate MongoDB in Favor of PostgreSQL

## Status

Accepted (Supersedes ADR-0003)

## Context

ADR-0003 (2021) chose MongoDB for user profile storage due to schema flexibility
needs. Since then:

- MongoDB's multi-document transactions remain problematic for our use case
- Our schema has stabilized and rarely changes
- We now have PostgreSQL expertise from other services
- Maintaining two databases increases operational burden

## Decision

Deprecate MongoDB and migrate user profiles to PostgreSQL.

## Migration Plan

1. **Phase 1** (Week 1-2): Create PostgreSQL schema, dual-write enabled
2. **Phase 2** (Week 3-4): Backfill historical data, validate consistency
3. **Phase 3** (Week 5): Switch reads to PostgreSQL, monitor
4. **Phase 4** (Week 6): Remove MongoDB writes, decommission

## Consequences

### Positive

- Single database technology reduces operational complexity
- ACID transactions for user data
- Team can focus PostgreSQL expertise

### Negative

- Migration effort (~4 weeks)
- Risk of data issues during migration
- Lose some schema flexibility

## Lessons Learned

Document from ADR-0003 experience:

- Schema flexibility benefits were overestimated
- Operational cost of multiple databases was underestimated
- Consider long-term maintenance in technology decisions
```

### Template 5: Request for Comments (RFC) Style

```markdown
# RFC-0025: Adopt Event Sourcing for Order Management

## Summary

Propose adopting event sourcing pattern for the order management domain to
improve auditability, enable temporal queries, and support business analytics.

## Motivation

Current challenges:

1. Audit requirements need complete order history
2. "What was the order state at time X?" queries are impossible
3. Analytics team needs event stream for real-time dashboards
4. Order state reconstruction for customer support is manual

## Detailed Design

### Event Store
```

OrderCreated { orderId, customerId, items[], timestamp }
OrderItemAdded { orderId, item, timestamp }
OrderItemRemoved { orderId, itemId, timestamp }
PaymentReceived { orderId, amount, paymentId, timestamp }
OrderShipped { orderId, trackingNumber, timestamp }

```

### Projections

- **CurrentOrderState**: Materialized view for queries
- **OrderHistory**: Complete timeline for audit
- **DailyOrderMetrics**: Analytics aggregation

### Technology

- Event Store: EventStoreDB (purpose-built, handles projections)
- Alternative considered: Kafka + custom projection service

## Drawbacks

- Learning curve for team
- Increased complexity vs. CRUD
- Need to design events carefully (immutable once stored)
- Storage growth (events never deleted)

## Alternatives

1. **Audit tables**: Simpler but doesn't enable temporal queries
2. **CDC from existing DB**: Complex, doesn't change data model
3. **Hybrid**: Event source only for order state changes

## Unresolved Questions

- [ ] Event schema versioning strategy
- [ ] Retention policy for events
- [ ] Snapshot frequency for performance

## Implementation Plan

1. Prototype with single order type (2 weeks)
2. Team training on event sourcing (1 week)
3. Full implementation and migration (4 weeks)
4. Monitoring and optimization (ongoing)

## References

- [Event Sourcing by Martin Fowler](https://martinfowler.com/eaaDev/EventSourcing.html)
- [EventStoreDB Documentation](https://www.eventstore.com/docs)
```

## ADR Management

### Directory Structure

```
docs/
├── adr/
│   ├── README.md           # Index and guidelines
│   ├── template.md         # Team's ADR template
│   ├── 0001-use-postgresql.md
│   ├── 0002-caching-strategy.md
│   ├── 0003-mongodb-user-profiles.md  # [DEPRECATED]
│   └── 0020-deprecate-mongodb.md      # Supersedes 0003
```

### ADR Index (README.md)

```markdown
# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for [Project Name].

## Index

| ADR                                   | Title                              | Status     | Date       |
| ------------------------------------- | ---------------------------------- | ---------- | ---------- |
| [0001](0001-use-postgresql.md)        | Use PostgreSQL as Primary Database | Accepted   | 2024-01-10 |
| [0002](0002-caching-strategy.md)      | Caching Strategy with Redis        | Accepted   | 2024-01-12 |
| [0003](0003-mongodb-user-profiles.md) | MongoDB for User Profiles          | Deprecated | 2023-06-15 |
| [0020](0020-deprecate-mongodb.md)     | Deprecate MongoDB                  | Accepted   | 2024-01-15 |

## Creating a New ADR

1. Copy `template.md` to `NNNN-title-with-dashes.md`
2. Fill in the template
3. Submit PR for review
4. Update this index after approval

## ADR Status

- **Proposed**: Under discussion
- **Accepted**: Decision made, implementing
- **Deprecated**: No longer relevant
- **Superseded**: Replaced by another ADR
- **Rejected**: Considered but not adopted
```

### Automation (adr-tools)

```bash
# Install adr-tools
brew install adr-tools

# Initialize ADR directory
adr init docs/adr

# Create new ADR
adr new "Use PostgreSQL as Primary Database"

# Supersede an ADR
adr new -s 3 "Deprecate MongoDB in Favor of PostgreSQL"

# Generate table of contents
adr generate toc > docs/adr/README.md

# Link related ADRs
adr link 2 "Complements" 1 "Is complemented by"
```

## Review Process

```markdown
## ADR Review Checklist

### Before Submission

- [ ] Context clearly explains the problem
- [ ] All viable options considered
- [ ] Pros/cons balanced and honest
- [ ] Consequences (positive and negative) documented
- [ ] Related ADRs linked

### During Review

- [ ] At least 2 senior engineers reviewed
- [ ] Affected teams consulted
- [ ] Security implications considered
- [ ] Cost implications documented
- [ ] Reversibility assessed

### After Acceptance

- [ ] ADR index updated
- [ ] Team notified
- [ ] Implementation tickets created
- [ ] Related documentation updated
```

## Best Practices

### Do's

- **Write ADRs early** - Before implementation starts
- **Keep them short** - 1-2 pages maximum
- **Be honest about trade-offs** - Include real cons
- **Link related decisions** - Build decision graph
- **Update status** - Deprecate when superseded

### Don'ts

- **Don't change accepted ADRs** - Write new ones to supersede
- **Don't skip context** - Future readers need background
- **Don't hide failures** - Rejected decisions are valuable
- **Don't be vague** - Specific decisions, specific consequences
- **Don't forget implementation** - ADR without action is waste
<!-- upstream:end -->
