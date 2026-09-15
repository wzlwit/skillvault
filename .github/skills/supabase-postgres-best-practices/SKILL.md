---
name: supabase-postgres-best-practices
description: Review Postgres SQL, schemas, migrations, query plans, indexes, connection pooling, locks, and row-level security. Use for Postgres-backed work; do not apply database-specific advice to SQL Server or other engines.
metadata:
  author: Supabase
  maintainer: wzlwit
  version: null
---

# Supabase Postgres Best Practices

Use database evidence to select the smallest justified improvement. The source covers
Postgres in general, with additional Supabase-specific guidance; it is not a general data
analysis or Power BI skill.

## Workflow

1. Confirm the engine version, hosting environment, application access path, and requested
   change. Read the relevant schema, migration, query, indexes, and access policies.
2. Select the matching topic in the upstream references: query performance, connections,
   security and RLS, schema design, locking, access patterns, diagnostics, or advanced
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
6. State what remains unmeasured. Do not claim a speedup from an example in the upstream
   guide or treat successful parsing as proof of database correctness.

## Boundaries

- No database, client, extension, or Supabase account is installed by this skill.
- Keep production access read-only unless explicitly authorized. `EXPLAIN ANALYZE` executes
  its statement; use it only when execution is safe and authorized, including for writes.
- Do not expose connection strings, row contents, or tenant identifiers in reports. Use
  sanitized query shapes and synthetic examples in public documentation.
- This guide links to, rather than bundles, the upstream reference library. If a needed
  reference or database cannot be accessed, disclose the limitation instead of guessing.

## Source and Curation

Curated SkillVault guide for
[Supabase's Postgres skill](https://github.com/supabase/agent-skills/tree/main/skills/supabase-postgres-best-practices).
Upstream [references](https://github.com/supabase/agent-skills/tree/main/skills/supabase-postgres-best-practices/references)
are [MIT licensed](https://github.com/supabase/agent-skills/blob/main/LICENSE).
Authorship stays with Supabase; wzlwit maintains this curated guide. The wording is
rephrased for SkillVault and is not the unchanged upstream skill. This guide declares no
version because it does not track an upstream release.