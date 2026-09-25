---
name: planning-with-files
description: Reference guide to the upstream planning-with-files workflow; its hooks and scripts are not bundled. Use to locate authoritative guidance on persistent plan files for long-running tasks. Overlaps with grilling on planning and architecture-decision-records on notes; the upstream focus is task recovery.
metadata:
  author: OthmanAdi
  maintainer: wzlwit
  version: null
---

# Planning with Files Reference

Persistent planning files keep a multi-step coding task recoverable after context compaction,
`/clear`, or a crashed session. The upstream workflow maintains a task plan, findings, and
progress on disk. This entry is a short reference to that project.

## Scope

- No upstream skill body, hooks, scripts, templates, or slash commands are installed by this
  entry.
- Invoking this entry runs nothing. The command below is an example to show the user, not an
  action to run automatically.
- Before real use, fetch and read the authoritative upstream guidance instead of relying on
  this summary.

## Official Source

- Repository: https://github.com/OthmanAdi/planning-with-files
- License: MIT
- Upstream Agent Skills path: `.agents/skills/planning-with-files`

## Installing Upstream

Installing the upstream package is the user's decision. Example only; confirm the current
command and its supported options in the upstream documentation:

```powershell
npx skills add OthmanAdi/planning-with-files --skill planning-with-files
```

Adding the skill does not register every hook, and it does not make `/plan-doctor` available
everywhere. Hooks and that check are route-specific: only the installation route that provides
them registers them. Verify what the chosen route actually installed, run `/plan-doctor` only
where it exists, and do not assume a global flag or agent target that upstream does not
document.

## Curation

Curated SkillVault reference for OthmanAdi's planning-with-files. Authorship stays with
OthmanAdi; wzlwit maintains this reference, which is written for SkillVault rather than copied
from upstream. It declares no version because it does not track an upstream release.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.
