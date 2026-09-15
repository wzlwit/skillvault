---
name: humanizer
description: Reference guide to the upstream Humanizer rewriting skill; its full editing rules are not bundled. Use to locate authoritative Humanizer guidance before rewriting prose.
metadata:
  author: blader
  maintainer: wzlwit
  version: null
---

# Humanizer Reference

Humanizer revises prose that sounds generic or machine-generated while keeping the source's
facts, links, and intended voice. This entry is a short reference to that upstream project.

## Scope

- No upstream editing rules, word lists, scripts, or hooks are installed by this entry.
- Invoking this entry runs nothing. The command below is an example to show the user, not an
  action to run automatically.
- Before real rewriting work, fetch and read the authoritative upstream guidance instead of
  relying on this summary.
- Keep code, data, frontmatter, and link targets unchanged when revising a file, and review
  the rewritten text before publishing.

## Official Source

- Repository: https://github.com/blader/humanizer
- License: MIT
- Upstream skill: `SKILL.md`

## Installing Upstream

Installing the upstream package is the user's decision. Example only; confirm the current
command and its scope options in the upstream documentation:

```powershell
npx skills add blader/humanizer --global
```

## Curation

Curated SkillVault reference for blader's Humanizer. Authorship stays with blader; wzlwit
maintains this reference, which is written for SkillVault rather than copied from upstream.
It declares no version because it does not track an upstream release.