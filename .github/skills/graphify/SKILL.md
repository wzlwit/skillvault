---
name: graphify
description: Reference guide to the upstream Graphify knowledge-graph skill; its CLI is not installed here. Use to locate authoritative Graphify guidance and its official install workflow.
metadata:
  author: Graphify-Labs
  maintainer: wzlwit
  version: null
---

# Graphify Reference

Graphify turns a codebase and supporting material into a queryable knowledge graph. This entry
is a short reference to that upstream project; it does not copy, modify, or replace it.

## Scope

- The `graphify` CLI is not installed here, and no upstream skill files, hooks, or reference
  library are bundled.
- Invoking this entry runs nothing. The commands below are examples to show the user, not
  actions to run automatically.
- Graphify's platform-specific skill files, including any Copilot-facing files, are generated
  and placed by its official CLI. Treat the upstream repository root as authoritative rather
  than assuming a fixed in-repo skill path.
- Before real use, fetch and read the authoritative upstream guidance instead of relying on
  this summary.

## Official Source

- Repository: https://github.com/Graphify-Labs/graphify
- License: Apache-2.0
- Upstream path: repository root

## Installing Upstream

Installing and updating Graphify is the user's decision, handled by its own CLI. Examples
only; confirm the current commands in the upstream documentation:

```powershell
uv tool install graphifyy
graphify vscode install
```

Graphify manages the files it installs and their updates. `/skillvault-refresh` refreshes
SkillVault-managed installs and does not overwrite an upstream-owned Graphify installation.

## Curation

Curated SkillVault reference for Graphify-Labs' Graphify. Authorship stays with
Graphify-Labs; wzlwit maintains this reference, which is written for SkillVault rather than
copied from upstream. It declares no version because it does not track an upstream release.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.
