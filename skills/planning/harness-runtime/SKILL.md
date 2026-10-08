---
name: harness-runtime
description: "Shared PowerShell 7 runtime for the harness topics: the harness.ps1 entry point, the runtime guide, and the default review model list. Not invoked directly; use harness-project (setup, context, policy), harness-work, harness-write, harness-review, harness-decision, harness-monitor, or harness-timer."
metadata:
  author: wzlwit
  version: "2.0.0"
user-invocable: false
disable-model-invocation: true
---

# Harness Runtime

This bundle holds the shared runtime that every harness topic calls. It has no actions of its own,
so it stays out of the `/` menu and is never loaded automatically.

- [scripts/harness.ps1](./scripts/harness.ps1) is the entry point, called with `-ProjectPath` and
  `-Action`.
- The [runtime guide](./references/runtime.md) owns Script Permissions and Agent Fallback, Root and
  Runner Inheritance, Reuse or New, Artifact Storage, layout migration, history cleanup, monitoring,
  and the Review Panel.
- [scripts/review-models.json](./scripts/review-models.json) is the default review model list.

Install it in the same scope as the harness topics that depend on it. Installing it creates no
project state, workers, or schedules. Until 2026-10-07 this bundle was the `harness` topic folder.
