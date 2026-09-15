---
name: skillvault-evaluate
description: Evaluate a source URL or existing SkillVault skill name for purpose, value, fit, overlap, and risks before deciding whether to upsert it. Triggers on "/skillvault-evaluate", "skillvault-evaluate", "/sv-evaluate", "sv-evaluate", "/skv-evaluate", "skv-evaluate", "evaluate skillvault skill", or "review skill before upsert".
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "<url|skillName> [location]"
---

# SkillVault Evaluate

This skill reviews a URL or existing SkillVault skill before creating or updating any skill
files. It helps the user decide whether an upsert is worthwhile.

## Parameters

- `<url|skillName>` — required first positional argument.
  - URL: inspect the project page, README, docs, or repository metadata when available.
  - Skill name: inspect the local SkillVault catalog entry and skill folder.
- `[location]` — optional explicit local path or source URL for a named skill. When supplied,
   evaluate this location directly instead of following the default name lookup flow.

## Behavior

1. Determine whether the first argument is a URL or skill name. If `location` is supplied,
   inspect that exact location and skip steps 3-6. An inaccessible explicit location is a
   reported failure, not permission to silently select a different source.
2. For a URL, fetch or inspect the source page. Prefer official project docs or README over
   summaries from search snippets. Direct URLs skip name lookup in steps 3-6.
3. For a skill name, first reuse the `/skillvault-list` inventory logic or script to check
   installed global, project, and explicit session skill folders. This avoids duplicating
   installed-skill discovery logic.
4. If the skill is not installed, read local SkillVault sources: current `catalog.json`, then
   `~/.copilot/skillvault-src/catalog.json` when present.
5. If the skill is still not found, check the official SkillVault repository at
   `https://github.com/wzlwit/skillvault`, including its `catalog.json` and matching skill folder.
6. If the skill is still not found, search online for the most credible source URL, such as the
   official project homepage or GitHub repository, then evaluate that URL.
7. For any local skill found, read the skill's `skill.json`, `README.md`, and `SKILL.md` when present.
8. Summarize the source or skill in concise terms:
   - Purpose
   - Audience
   - Key workflows or capabilities
   - What a SkillVault skill would automate or teach
9. Evaluate value and fit:
   - Does this belong in SkillVault?
   - Is it broadly reusable or too project-specific?
   - Is it better as a skill, prompt, instruction, script, or no customization?
   - Does it overlap with an existing skill?
   Read any relevant installed counterpart before recommending replacement, including for a
   direct URL. State `keep`, `coexist`, `replace <name>`, or `skip`, with the reason. These are
   recommendations only; evaluation never uninstalls or modifies an installed skill.
10. Identify risks:
   - Secrets, internal URLs, or private content
   - Licensing or attribution concerns
   - Vague trigger phrases
   - Excessive maintenance burden
11. Recommend one of:
   - `upsert`: good candidate for `/skillvault-upsert`
   - `defer`: useful idea, not enough value yet
   - `skip`: not a good SkillVault skill
12. If recommending upsert, suggest:
   - Skill name
   - Category folder
   - Default scope
   - Short catalog description
   - Whether it should be native, URL-derived, or script-backed

## Output Shape

Use this compact structure:

```text
Purpose: ...
Value: high/medium/low
Fit: skill/prompt/instruction/script/skip
Overlap: ...
Installed recommendation: keep/coexist/replace <name>/skip
Risks: ...
Recommendation: upsert/defer/skip
Suggested upsert: /skillvault-upsert <name|url> <scope>
```

## Safety

- Do not create, edit, commit, push, or open a PR while evaluating.
- Do not vendor upstream documentation. Link to source material instead.
- Do not write secrets or private content into an evaluation.
- If evidence is thin, say what could not be verified.