# Skill Installation Scope Audit

> Topic and command names in this record were updated to the current topics on 2026-10-07; see the [old-name retirement ADR](../docs/plans/decisions/2026-10-07-retire-old-names-adr.md).

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
| [archify](../skills/codeview/archify/skill.json) | Project | Portable reference; no renderer or CLI is installed. |
| [architecture-decision-records](../skills/writing/architecture-decision-records/SKILL.md) | Global | Reusable rationale workflow; records use the selected project's docs root. |
| [brainstorming](../skills/planning/brainstorming/SKILL.md) | Project | Reusable design discussion; implementation still needs approval. |
| [differential-review](../skills/security/differential-review/SKILL.md) | Project | Shared security methodology for local and PR review, not a scanner. |
| [github-issues](../skills/github/github-issues/SKILL.md) | Project | Reusable issue workflow with explicit repository and write approval. |
| [graphify](../skills/codeview/graphify/SKILL.md) | Global | Portable reference; upstream CLI remains separate. |
| [grilling](../skills/planning/grilling/SKILL.md) | Global | Reusable decision interview; unanswered choices stay open. |
| [handoff](../skills/planning/handoff/SKILL.md) | Project | Explicit-only continuation notes; destinations stay project-aware. |
| [harness-project context](../skills/planning/harness-setup/references/context.md) | Project | Shared reader for the selected project's context. |
| [harness-decision](../skills/planning/harness-decide/SKILL.md) | Project | Shared decision helper; each project retains its register. |
| [harness-work](../skills/planning/harness-dev/SKILL.md) | Project | Shared executor; task scope, workspaces, and permissions stay explicit. |
| [harness-project policy fallback](../skills/planning/harness-setup/references/fallback.md) | Project | Shared policy commands; target pauses stay in project state. |
| [harness-project init](../skills/planning/harness-setup/references/init.md) | Project | Shared runtime; ProjectPath selects every project's configuration. |
| [harness-project root](../skills/planning/harness-setup/references/root.md) | Project | Shared command selecting a project's board, not relocating records. |
| [harness-monitor](../skills/planning/harness-monitor/SKILL.md) | Project | Shared evaluator; observations and incidents remain project-specific. |
| [harness-project context](../skills/planning/harness-setup/SKILL.md) | Project | Shared reference helper; registered links stay in the project board. |
| [harness-write](../skills/planning/harness-write/SKILL.md) | Project | Reusable authoring dispatcher; artifact identity/access stays explicit. |
| [harness-project policy limits](../skills/planning/harness-setup/references/limits.md) | Project | Shared boundary commands; no permission is granted by installation. |
| [harness-review](../skills/planning/harness-review/SKILL.md) | Project | Shared reviewer; current-project baseline and scope remain unchanged. |
| [harness-work](../skills/planning/harness-dev/SKILL.md) | Project | Shared intake command; tasks are saved only in the selected project. |
| [harness-work test](../skills/planning/harness-dev/SKILL.md) | Project | Shared test flow executor; methods/environments stay project-local. |
| [harness-timer](../skills/planning/harness-schedule/SKILL.md) | Project | Shared scheduler helper beside the harness runtime; project task identities persist. |
| [humanizer](../skills/writing/humanizer/skill.json) | Global | Reusable reference, with upstream editing rules not bundled. |
| [jarvis-metrics](../skills/monitoring/jarvis-metrics/SKILL.md) | Project | Reusable Jarvis guidance; no account or connector comes with it. |
| [kpi-dashboard](../skills/data/kpi-dashboard/SKILL.md) | Project | Reusable metric methodology; actual metric definitions stay task-specific. |
| [openapi-spec](../skills/api/openapi-spec/SKILL.md) | Project | Reusable contract workflow targeting the selected API. |
| [planning-with-files](../skills/planning/planning-with-files/skill.json) | Project | Portable reference; no upstream hooks or state are installed. |
| [pr-review](../skills/github/pr-review/SKILL.md) | Global | Shared controller with its explicit user-wide root, independent of install scope. |
| [pr-watch add](../skills/github/pr-watch/SKILL.md) | Global | Adds to the same user-wide watchlist; does not start reviews. |
| [pr-watch list](../skills/github/pr-watch/SKILL.md) | Global | Reads the shared watchlist without remote calls or initialization. |
| [pr-watch remove](../skills/github/pr-watch/SKILL.md) | Global | Removes a shared watch entry, preserving PRs and reports. |
| [harness-timer set pr](../skills/planning/harness-schedule/SKILL.md) | Global | One current-user timer for the whole list, not per installation. |
| [rules](../skills/core/rules/SKILL.md) | Global | Shared rule-editing workflow; authoritative destination is explicitly resolved. |
| [rules apply](../skills/core/rules/SKILL.md) | Global | Reusable guidance; installation is not always-on injection. |
| [schedule-manager](../skills/system/schedule-manage/SKILL.md) | Global | User-wide schedule inventory; mutations retain confirmation. |
| [skillvault-discovery evaluate](../skills/core/skillvault-discover/SKILL.md) | Global | Reusable adoption assessment without installation or execution. |
| [skillvault-installation refresh](../skills/core/skillvault-install/SKILL.md) | Global | Explicit refresh of managed global copies; no schedule on install. |
| [skillvault-installation](../skills/core/skillvault-install/SKILL.md) | Global | Shared catalog installer; verifies source separately from copy destination. |
| [skillvault-discovery explain](../skills/core/skillvault-discover/SKILL.md) | Global | Reusable read-only explanations, not target workflow execution. |
| [skillvault-installation list](../skills/core/skillvault-install/SKILL.md) | Global | User-wide installed-skill inventory and scoped administration. |
| [skillvault-authoring remove](../skills/core/skillvault-author/SKILL.md) | Global | Explicit source maintenance; remains excluded from bootstrap. |
| [skillvault-discovery search](../skills/core/skillvault-discover/SKILL.md) | Global | Cross-source skill discovery without installation. |
| [skillvault-installation uninstall](../skills/core/skillvault-install/SKILL.md) | Global | Shared installed-copy administration with confirmed exact targets. |
| [skillvault-authoring](../skills/core/skillvault-author/SKILL.md) | Global | Explicit source authoring; remains excluded from bootstrap. |
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