# Skill Installation Scope Audit

- Date: 2026-09-15
- Request: verify every catalog skill and prefer global default installation where appropriate.
- Scope: all 47 catalog manifests and bundled workflows, installation routing, and dependencies.
- Decision: change 26 project defaults to global; retain 21 global defaults. Global availability
  suits these reusable bundles; it is a usability choice, not a claim that project installs fail.
- Existing installed copies, pins, project configuration, schedules, and provider accounts are unchanged.

## Criteria

Global is appropriate for reusable instructions and shared helpers whose target is selected at
invocation. Project-local outputs and state do not require project-installed code. Explicit
project copies remain supported where already declared, for repository pinning/customization.
Keep sibling helpers in the same selected scope. No `project`/`session` support flags, versions,
authorship, licences, source paths, or compact catalog fields are changed by this audit.

This updates the earlier project-default installation recommendations, including that clause
in the [report-authoring ADR](../docs/plans/decisions/2026-09-15-harness-report-authoring-adr.md).
It does not change the accepted workflows, project-first review, or the one user-wide PR timer.
Missing manifest defaults still fall back to project. Future project-specific bundles can make
their own explicit choice; global is not a replacement for runtime target selection or consent.

## Per-Skill Assessment

All rows below now default to global. `Project` in Before identifies a changed manifest;
`Global` identifies an unchanged default. The guide link identifies the reviewed source bundle.

| Skill | Before | Why Global Fits |
| --- | --- | --- |
| [archify](../skills/codeview/archify/SKILL.md) | Project | Portable reference; no renderer or CLI is installed. |
| [architecture-decision-records](../skills/writing/architecture-decision-records/SKILL.md) | Global | Reusable rationale workflow; records use the selected project's docs root. |
| [brainstorming](../skills/planning/brainstorming/SKILL.md) | Project | Reusable design discussion; implementation still needs approval. |
| [differential-review](../skills/security/differential-review/SKILL.md) | Project | Shared security methodology for local and PR review, not a scanner. |
| [github-issues](../skills/github/github-issues/SKILL.md) | Project | Reusable issue workflow with explicit repository and write approval. |
| [graphify](../skills/codeview/graphify/SKILL.md) | Global | Portable reference; upstream CLI remains separate. |
| [grilling](../skills/planning/grilling/SKILL.md) | Global | Reusable decision interview; unanswered choices stay open. |
| [handoff](../skills/planning/handoff/SKILL.md) | Project | Explicit-only continuation notes; destinations stay project-aware. |
| [harness-context](../skills/planning/harness/references/context.md) | Project | Shared reader for the selected project's context. |
| [harness-decide](../skills/planning/harness-decision/SKILL.md) | Project | Shared decision helper; each project retains its register. |
| [harness-dev](../skills/planning/harness-dev/SKILL.md) | Project | Shared executor; task scope, workspaces, and permissions stay explicit. |
| [harness-fallback](../skills/planning/harness-policy/references/fallback.md) | Project | Shared policy commands; target pauses stay in project state. |
| [harness-init](../skills/planning/harness/references/init.md) | Project | Shared runtime; ProjectPath selects every project's configuration. |
| [harness-loc](../skills/planning/harness/references/loc.md) | Project | Shared command selecting a project's board, not relocating records. |
| [harness-monitor](../skills/planning/harness-monitor/SKILL.md) | Project | Shared evaluator; observations and incidents remain project-specific. |
| [harness-ref](../skills/planning/harness-link/SKILL.md) | Project | Shared reference helper; registered links stay in the project board. |
| [harness-report-create](../skills/planning/harness-report/SKILL.md) | Project | Reusable authoring dispatcher; artifact identity/access stays explicit. |
| [harness-restrict](../skills/planning/harness-policy/references/limits.md) | Project | Shared boundary commands; no permission is granted by installation. |
| [harness-review](../skills/planning/harness-review/SKILL.md) | Project | Shared reviewer; current-project baseline and scope remain unchanged. |
| [harness-task](../skills/planning/harness-task/SKILL.md) | Project | Shared intake command; tasks are saved only in the selected project. |
| [harness-test](../skills/planning/harness-test/SKILL.md) | Project | Shared test flow executor; methods/environments stay project-local. |
| [harness-timer](../skills/planning/harness-timer/SKILL.md) | Project | Shared scheduler helper beside harness-init; project task identities persist. |
| [humanizer](../skills/writing/humanizer/SKILL.md) | Global | Reusable reference, with upstream editing rules not bundled. |
| [jarvis-metrics-create](../skills/monitoring/jarvis-metrics/SKILL.md) | Project | Reusable Jarvis guidance; no account or connector comes with it. |
| [kpi-dashboard-design](../skills/public/data/kpi-dashboard-design/SKILL.md) | Project | Reusable metric methodology; actual metric definitions stay task-specific. |
| [openapi-spec-generation](../skills/public/api/openapi-spec-generation/SKILL.md) | Project | Reusable contract workflow targeting the selected API. |
| [planning-with-files](../skills/planning/planning-with-files/SKILL.md) | Project | Portable reference; no upstream hooks or state are installed. |
| [pr-review](../skills/github/pr-review/SKILL.md) | Global | Shared controller with its explicit user-wide root, independent of install scope. |
| [pr-review-add](../skills/public/github/pr-review-add/SKILL.md) | Global | Adds to the same user-wide watchlist; does not start reviews. |
| [pr-review-list](../skills/public/github/pr-review-list/SKILL.md) | Global | Reads the shared watchlist without remote calls or initialization. |
| [pr-review-remove](../skills/public/github/pr-review-remove/SKILL.md) | Global | Removes a shared watch entry, preserving PRs and reports. |
| [pr-review-timer](../skills/public/github/pr-review-timer/SKILL.md) | Global | One current-user timer for the whole list, not per installation. |
| [rules](../skills/core/rules/SKILL.md) | Global | Shared rule-editing workflow; authoritative destination is explicitly resolved. |
| [rules-core](../skills/public/core/rules-core/SKILL.md) | Global | Reusable guidance; installation is not always-on injection. |
| [schedule-manager](../skills/system/schedule-manager/SKILL.md) | Global | User-wide schedule inventory; mutations retain confirmation. |
| [skillvault-evaluate](../skills/public/core/skillvault-evaluate/SKILL.md) | Global | Reusable adoption assessment without installation or execution. |
| [skillvault-fresh](../skills/public/core/skillvault-fresh/SKILL.md) | Global | Explicit refresh of managed global copies; no schedule on install. |
| [skillvault-install](../skills/public/core/skillvault-install/SKILL.md) | Global | Shared catalog installer; verifies source separately from copy destination. |
| [skillvault-key-points](../skills/public/core/skillvault-key-points/SKILL.md) | Global | Reusable read-only explanations, not target workflow execution. |
| [skillvault-list](../skills/public/core/skillvault-list/SKILL.md) | Global | User-wide installed-skill inventory and scoped administration. |
| [skillvault-remove](../skills/public/core/skillvault-remove/SKILL.md) | Global | Explicit source maintenance; remains excluded from bootstrap. |
| [skillvault-search](../skills/public/core/skillvault-search/SKILL.md) | Global | Cross-source skill discovery without installation. |
| [skillvault-uninstall](../skills/public/core/skillvault-uninstall/SKILL.md) | Global | Shared installed-copy administration with confirmed exact targets. |
| [skillvault-upsert](../skills/core/skillvault-authoring/SKILL.md) | Global | Explicit source authoring; remains excluded from bootstrap. |
| [supabase-postgres-best-practices](../skills/data/supabase-postgres-best-practices/SKILL.md) | Project | Reusable Postgres advice; database type, target, and access stay scoped. |
| [trading-signal-analysis](../skills/finance/trading-signal-analysis/SKILL.md) | Project | Reusable research workflow; data/evaluator/licensing remain prerequisites. |
| [webapp-testing](../skills/testing/webapp-testing/SKILL.md) | Project | Reusable browser test workflow; app, test accounts, and browser setup stay explicit. |

## Verification and Follow-Ups

Metadata/frontmatter/resource checks cover every catalog entry. Installation fixtures cover
every bundle's default destination, byte-for-byte copy, source/version metadata, explicit
project override, and project-state separation when sharing a global runtime. They use only
temporary roots; no existing copy is refreshed or moved.

Passed: the full `scripts/test-all.ps1` suite, all 47 default-install fixtures, ten Node contract
tests, PowerShell/Bash bootstrap fixtures, catalog validation, and `git diff --check`.

This is not live verification of external services, model access, credentials, or domain test
environments. Reference-only entries remain references. Existing execution/preflight findings
in the [harness review](harness-2026-09-15.md) remain separate and are not closed by scope changes.
No third-party extension skills or unlisted templates were changed.