---
name: webapp-testing
description: Verify local web applications with Playwright. Use for browser regression checks, frontend interactions, UI failures, screenshots, and browser console diagnostics.
metadata:
  author: Anthropic
  maintainer: wzlwit
  version: null
---

# Web Application Testing

Check a specific user-visible workflow against observable expectations. Use the project's
existing browser tests or available Playwright tools before creating another test harness.

## Workflow

1. Identify the page, action, and expected outcome from the request and current code. Read
   the nearest test and the project's test commands; keep coverage within the requested scope.
2. Reuse an appropriate running local server, or start the documented development server on
   a free port. For static content, open the local HTML directly. Do not touch production.
3. Navigate and inspect the rendered page. Wait for the relevant element or response with a
   bounded timeout; avoid arbitrary sleeps and assuming that network-idle proves readiness.
4. Choose locators from the observed DOM, preferably accessible roles and names or existing
   test IDs. Exercise the workflow and assert visible state, navigation, or expected errors.
5. Capture screenshots and relevant console or request failures. Check desktop and mobile
   layouts when the changed behavior is responsive. Do not call a screenshot an assertion.
6. Add a focused regression to an existing test file when durable coverage is useful. Run
   that test and report its actual outcome. Stop processes and close browsers you started.

## Setup and Boundaries

- Reuse the existing Playwright language and tooling. When a standalone Python check is
  appropriate, use the project's `.venv` and its interpreter, not system Python or conda.
- Install missing browser dependencies only for the agreed test task. This guide installs
  no Playwright runtime, browser binaries, upstream helper scripts, or hooks.
- Use test accounts and non-sensitive fixtures. Purchases, account deletion, and external
  submissions require separate authorization; never record credentials in test artifacts.
- Report URL or file tested, actions, assertions, failures, and evidence paths. Disclose any
  skipped browser execution; a passing catalog check does not prove a web app works.

## Source and Curation

Curated SkillVault guide for Anthropic's
[webapp-testing skill](https://github.com/anthropics/skills/tree/main/skills/webapp-testing),
which is [Apache-2.0](https://github.com/anthropics/skills/blob/main/skills/webapp-testing/LICENSE.txt).
Authorship stays with Anthropic; wzlwit maintains this curated guide. The wording is
rephrased for SkillVault and is not the unchanged upstream skill. Its optional server helper
and examples remain upstream, and no upstream files are bundled here. This guide declares no
version because it does not track an upstream release.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.
