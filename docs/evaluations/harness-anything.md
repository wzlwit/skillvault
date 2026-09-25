# Harness Anything Evaluation

- Evaluated: 2026-09-22
- Selected source: https://github.com/yb2460/harness-anything
- Reviewed revision: `dcb3e516dee1e7b4c83e1909a07062a0bb8dea0a` on `master`
- Declared root package: `cli-anything-wps`, version `1.0.0`, Beta, Python `>=3.10`
- License: root MIT license, copyright `cli-anything-wps contributors`
- Scope: README, packaging, WPS/Zotero skill instructions, WPS backend, document model, and nearby unit tests; source review only
- Recommendation: Upsert a curated reference-only guide; do not import or install the executable collection automatically
- Installed recommendation: Coexist; keep the existing harness and webapp-testing skills

## Identity and Purpose

The name was not found in the inspected global/current-project installed inventory, local
SkillVault catalog, or public SkillVault catalog. No local cache catalog was present. Public
lookup identified the Windows-oriented `yb2460/harness-anything` project; this assessment
selects that source, not the separately published `FairladyZ625/harness-anything` rewrite.

Harness Anything gives an AI agent command-line interfaces for operating desktop applications.
The agent decides what to do; these adapters translate commands into application operations.
It is not itself another model or a replacement for SkillVault's development controller.

Its primary value is structured access to documents, cells, slides, layers, and exports instead
of relying on screen coordinates. The repository advertises WPS/Microsoft Office, Zotero,
Illustrator, and Photoshop workflows. This is application-specific automation, not a promise
to control every desktop application or every button on screen.

## What Is Grounded

- **WPS:** The backend calls `win32com.client.Dispatch` with `KWPS.Application`,
  `KET.Application`, or `KWPP.Application`. It contains document creation/opening, save/export,
  content-reading, close, and application-exit helpers. Installed Windows software and working
  COM registration are prerequisites, not bundled capabilities.
- **Document workflow:** The inspected core creates and edits a structured project dictionary;
  its open/save functions read and write JSON project files. Do not interpret those commands
  as arbitrary round-trip editing of an existing DOCX/PPTX. The upstream guide separately
  documents native export and JSON-driven presentation-building scripts.
- **Microsoft Office:** The README describes changing COM ProgIDs to the Microsoft equivalents.
  The inspected main connector contains WPS ProgIDs, so turnkey Word/Excel/PowerPoint support
  is not established by the broad README claim alone.
- **Zotero:** Its skill describes library queries, citations, imports, notes, and research
  workflows. It explicitly requires the Local API for several operations, live GUI/library
  context for adding notes, and treats experimental SQLite writes as non-stable operations.
  Its declared skill version is `0.1.0`, separate from the root WPS package version.
- **Adobe:** The README describes separate Illustrator and Photoshop packages using COM,
  with layer/shape/text or image operations and exports. Those implementations were not audited
  or exercised in this assessment.
- **Packaging:** The root setup registers only the `cli-anything-wps` console script. Do not
  promise that a root install creates every command advertised in the collection. Zotero's
  skill also documents a Python module entrypoint; Adobe packages have separate install paths.
- **Tests:** The inspected WPS test module explicitly exercises the data layer without COM.
  These tests provide examples of expected project behavior, not evidence of working native
  exports, Office compatibility, or fidelity on this machine. No tests were run.

The advertised command and academic-skill counts are upstream claims, not coverage or quality
measurements independently established here. The repository page listed no published releases;
the root package version is not evidence of a verified downloadable release.

## Value, Fit, and Overlap

**Value: High for a concrete Windows office/design automation task; conditional otherwise.**
A small trial on disposable documents is worthwhile when native application behavior matters.
For simply producing a file, compare the adapter with an existing document-generation library
before accepting a dependency on an installed GUI application. No trial is required merely
to explain or catalog the project.

**Fit: A URL-derived, reference-only tool-use guide.** Teach prerequisites, supported command
surfaces, project-versus-native-document distinctions, output verification, and application
lifecycle handling. Link to the runtime rather than copying its code or its entire collection
of academic instructions and presentation-specific layout rules.

The installed [harness-dev](../../.github/skills/harness-dev/SKILL.md) owns tracked execution,
validation, and independent review. This project supplies application operations that a task
might use; it does not replace that controller. The installed
[webapp-testing](../../.github/skills/webapp-testing/SKILL.md) operates web pages with Playwright,
whereas these desktop adapters primarily use application APIs. Keep both existing skills.
Shared outcome verification is useful; their tool surfaces and responsibilities differ.

## Risks and Boundaries

- **Unsaved work:** The WPS skill explicitly recommends force-killing WPS before execution.
  The backend also provides a helper that force-kills processes by application name. These
  operations can terminate unrelated open documents; do not carry blanket process cleanup
  into a curated guide. Review process ownership and preserve unsaved work before any trial.
- **Real side effects:** Backend saves can create directories and write chosen file paths;
  COM calls can close documents or quit applications. They are real application operations,
  not a browser sandbox or dry-run guarantee. The calling agent must retain user approvals.
- **Environment dependence:** Windows, pywin32, application versions, COM registration, and
  application licenses matter. The WPS skill specifies WPS 12.0+, while the root README uses
  a year-based requirement; verify the actual installed application instead of assuming equivalence.
- **Research data:** Zotero workflows can access local libraries and notes; experimental
  database writes deserve a separate backup and compatibility check. Academic-skill and model
  integration claims do not establish data-locality or citation accuracy.
- **Import scope and maintenance:** Upstream instructions mix reusable automation with specific
  presentation content, fonts, layouts, and build scripts. Root MIT attribution must be preserved;
  inspect separately sourced skills and assets before copying them. Native-app fidelity,
  broader dependencies, and multi-command workflows remain unverified.

## Recommendation

**Upsert a small reference guide, not an unreviewed executable bundle.** Keep the source
project's name in its title and attribution, but use a distinct SkillVault name so it is not
confused with the existing `harness-*` controller topics.

- Suggested name: `desktop-app-automation`
- Category: `skills/system/desktop-app-automation`
- Default availability: global; execution and application access remain explicitly scoped
- Type: URL-derived, reference-only
- Description: Guide Windows desktop-app automation with Harness Anything, with runtime setup and output verification kept explicit.
- Suggested next request: `/skillvault-authoring upsert https://github.com/yb2460/harness-anything none`, naming the guide `desktop-app-automation`

A later separately approved trial should select one adapter, use a dedicated `.venv` and
non-sensitive copies, and verify the resulting document in its native application. Reconsider
broader integration only after command availability, output fidelity, and cleanup behavior
are checked for the selected application. Trying an adapter is separate from replacing the harness.

Only this evaluation record was written. No runtime, skill bundle, catalog entry, installed
copy, application document, schedule, credential, Git index, or remote publication was changed.

## Sources

- [Repository README](https://github.com/yb2460/harness-anything/blob/dcb3e516dee1e7b4c83e1909a07062a0bb8dea0a/README.md)
- [Package metadata and entrypoint](https://github.com/yb2460/harness-anything/blob/dcb3e516dee1e7b4c83e1909a07062a0bb8dea0a/setup.py)
- [Root license](https://github.com/yb2460/harness-anything/blob/dcb3e516dee1e7b4c83e1909a07062a0bb8dea0a/LICENSE)
- [WPS architecture](https://github.com/yb2460/harness-anything/blob/dcb3e516dee1e7b4c83e1909a07062a0bb8dea0a/WPS.md)
- [WPS skill](https://github.com/yb2460/harness-anything/blob/dcb3e516dee1e7b4c83e1909a07062a0bb8dea0a/cli_anything/wps/skills/SKILL.md)
- [WPS COM backend](https://github.com/yb2460/harness-anything/blob/dcb3e516dee1e7b4c83e1909a07062a0bb8dea0a/cli_anything/wps/utils/wps_backend.py)
- [Document model](https://github.com/yb2460/harness-anything/blob/dcb3e516dee1e7b4c83e1909a07062a0bb8dea0a/cli_anything/wps/core/document.py)
- [WPS data-layer tests](https://github.com/yb2460/harness-anything/blob/dcb3e516dee1e7b4c83e1909a07062a0bb8dea0a/cli_anything/wps/tests/test_core.py)
- [Zotero skill and limitations](https://github.com/yb2460/harness-anything/blob/dcb3e516dee1e7b4c83e1909a07062a0bb8dea0a/cli_anything/zotero/skills/SKILL.md)