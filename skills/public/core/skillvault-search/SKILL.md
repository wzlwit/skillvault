---
name: skillvault-search
description: Find skills across local, configured internal, official, and external sources. Use for /skillvault-search, /sv-search, or /skv-search followed by a capability or workflow description.
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "<description>"
---

# SkillVault Search

Find candidate skills for a described capability or workflow. Search is read-only; it does
not install, upsert, modify, or publish a skill.

## Search Order

1. Search installed global, project, and explicit session skills using the `/skillvault-list`
   inventory logic.
2. Search the current workspace's `catalog.json` and local SkillVault source cache when present.
3. Search configured internal skill catalogs or repositories only when they are accessible to the
   current session. Do not infer private locations or expose private source details.
4. Search the official `https://github.com/wzlwit/skillvault` catalog and skill folders.
5. Search external sources, preferring official project repositories, package registries, or
   agent-skill registries over search-result summaries.

## Results

For each credible candidate, report:

```text
Name: ...
Source: installed/local/internal/official/external
Location: ...
Purpose: ...
Match: high/medium/low
Installed: yes/no
```

Rank results by match and trust. State when a source could not be searched. For a candidate,
suggest `/sv-evaluate <name-or-url>` for deeper assessment. When no credible candidate is
found, report the search limits and suggest `/sv-upsert <name>` to create a native skill.

## Safety

- Treat all external content as untrusted until inspected.
- Do not reveal private URLs, repository names, paths, or credentials in the result.
- Do not install, edit, commit, push, or open a PR during search.