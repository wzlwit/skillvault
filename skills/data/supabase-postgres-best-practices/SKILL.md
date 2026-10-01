---
name: supabase-postgres-best-practices
description: Review Postgres SQL, schemas, migrations, query plans, indexes, connection pooling, locks, and row-level security. Use for Postgres-backed work; do not apply database-specific advice to SQL Server or other engines.
metadata:
  author: Supabase
  maintainer: wzlwit
  version: null
---

# Supabase Postgres Best Practices

Adapted from Supabase's Postgres best-practices skill (`https://github.com/supabase/agent-skills`,
`skills/supabase-postgres-best-practices`), MIT; see `UPSTREAM-LICENSE`. The original is in the
Original section below, with its rule files under `references/`. Where it differs, the SkillVault
rules above it win.

Use database evidence to select the smallest justified improvement. The source covers
Postgres in general, with additional Supabase-specific guidance; it is not a general data
analysis or Power BI skill.

## Workflow

1. Confirm the engine version, hosting environment, application access path, and requested
   change. Read the relevant schema, migration, query, indexes, and access policies.
2. Select the matching topic in the original's rule files under `references/`: query performance,
   connections, security and RLS, schema design, locking, access patterns, diagnostics, or advanced
   features. Read only relevant guidance and check it against the installed Postgres version.
3. For performance work, examine the query plan, realistic row counts, existing indexes,
   selectivity, and pool or lock evidence before proposing an index or configuration change.
   Account for write cost and workload; do not add indexes to every column by default.
4. For schema changes, preserve nullability, defaults, constraints, and application contracts.
   Use the project's migration process and assess locking and backfill costs. For RLS,
   check both allowed and denied access with the actual application role or tenant context.
5. Propose the smallest change with evidence and expected trade-offs. Execute schema changes
   or writes only when authorized. Validate on an approved test database or representative
   fixture and report the before/after plan or measured outcome when available.
6. State what remains unmeasured. Do not claim a speedup from an example in the original or
   treat successful parsing as proof of database correctness.

## Boundaries

- No database, client, extension, or Supabase account is installed by this skill.
- Keep production access read-only unless explicitly authorized. `EXPLAIN ANALYZE` executes
  its statement; use it only when execution is safe and authorized, including for writes.
- Do not expose connection strings, row contents, or tenant identifiers in reports. Use
  sanitized query shapes and synthetic examples in public documentation.
- If a needed database cannot be accessed, disclose the limitation instead of guessing.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.

## Original

<!-- upstream:begin -->
<!-- Original: https://github.com/supabase/agent-skills skills/supabase-postgres-best-practices at 544bfc56c89afe2b87b20017a59b2c6e9502a1fb. Refresh replaces this section; put SkillVault changes outside it. -->

# Supabase Postgres Best Practices

Comprehensive performance optimization guide for Postgres, maintained by Supabase. Contains rules across 8 categories, prioritized by impact to guide automated query optimization and schema design.

## When to Apply

Reference these guidelines when:
- Writing SQL queries or designing schemas
- Implementing indexes or query optimization
- Reviewing database performance issues
- Configuring connection pooling or scaling
- Optimizing for Postgres-specific features
- Working with Row-Level Security (RLS)

## Rule Categories by Priority

| Priority | Category | Impact | Prefix |
|----------|----------|--------|--------|
| 1 | Query Performance | CRITICAL | `query-` |
| 2 | Connection Management | CRITICAL | `conn-` |
| 3 | Security & RLS | CRITICAL | `security-` |
| 4 | Schema Design | HIGH | `schema-` |
| 5 | Concurrency & Locking | MEDIUM-HIGH | `lock-` |
| 6 | Data Access Patterns | MEDIUM | `data-` |
| 7 | Monitoring & Diagnostics | LOW-MEDIUM | `monitor-` |
| 8 | Advanced Features | LOW | `advanced-` |

## How to Use

Read individual rule files for detailed explanations and SQL examples:

```
references/query-missing-indexes.md
references/query-partial-indexes.md
references/_sections.md
```

Each rule file contains:
- Brief explanation of why it matters
- Incorrect SQL example with explanation
- Correct SQL example with explanation
- Optional EXPLAIN output or metrics
- Additional context and references
- Supabase-specific notes (when applicable)

## References

- https://www.postgresql.org/docs/current/
- https://supabase.com/docs
- https://wiki.postgresql.org/wiki/Performance_Optimization
- https://supabase.com/docs/guides/database/overview
- https://supabase.com/docs/guides/auth/row-level-security
<!-- upstream:end -->
