
# SkillVault Evaluate

This skill reviews a URL or existing SkillVault skill before creating or updating any skill
bundle files. It helps the user decide whether an upsert is worthwhile and saves a compact
public-safe evaluation record by default. `--chat-only` disables that record write.
Use `/skillvault-discovery explain` for principles and step-by-step usage without an adoption recommendation.

## Parameters

- `<url|skillName>` — required first positional argument.
  - URL: inspect the project page, README, docs, or repository metadata when available.
  - Skill name: inspect the local SkillVault catalog entry and skill folder.
- `[location]` — optional explicit local path or source URL for a named skill. When supplied,
   evaluate this location directly instead of following the default name lookup flow.
- `--chat-only` - return the assessment without writing a record.
- `--repo <path>` - explicit verified SkillVault checkout for the record, not the candidate source.

## Behavior

1. Determine whether the first argument is a URL or skill name. If `location` is supplied,
   inspect that exact location and skip steps 3-6. An inaccessible explicit location is a
   reported failure, not permission to silently select a different source.
2. For a URL, fetch or inspect the source page. Prefer official project docs or README over
   summaries from search snippets. Direct URLs skip name lookup in steps 3-6.
3. For a skill name, first reuse the `/skillvault-installation list` inventory logic or script to check
   installed global, project, and explicit session skill folders. This avoids duplicating
   installed-skill discovery logic.
4. If the skill is not installed, read local SkillVault sources: current `catalog.json`, then
   `~/.copilot/skillvault-src/catalog.json` when present.
5. If the skill is still not found, check the official SkillVault repository at
   `https://github.com/wzlwit/skillvault`, including its `catalog.json` and matching skill folder.
6. If the skill is still not found, search online for the most credible source URL, such as the
   official project homepage or GitHub repository, then evaluate that URL.
7. For any local skill found, read the skill's `skill.json`, `README.md`, and `SKILL.md` when present.
   Consult a prior evaluation for the same canonical source before repeating research; verify
   changed sources and stale conclusions instead of treating the record as fresh evidence.
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
11. Recommend one of the following for the SkillVault guide only:
    - `upsert`: good candidate for `/skillvault-authoring upsert`
    - `defer`: postpone creating or updating the skill
    - `skip`: do not add a SkillVault skill for this candidate

    For a tool or product, separately assess standalone usefulness and whether it is worth
    trying, and harness integration fit when relevant. A tool can be worth trying standalone
    while its guide or integration is deferred. Omit inapplicable decisions. Recommendations
    do not authorize installation, execution, integration, or replacement.
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
Standalone use: ... (when relevant)
Skill recommendation: upsert/defer/skip
Harness integration: ... (when relevant)
Suggested upsert: /skillvault-authoring upsert <name|url> <scope>
```

Omit standalone-use and harness-integration fields when inapplicable. For example, a tool
evaluation can conclude: "Worth trying standalone; defer a SkillVault guide; defer harness
integration." These are independent recommendations, not permission to perform those actions.

## Safety

- The only default write is the public-safe evaluation record described below. Do not change
   target skills, manifests, catalog entries, installed copies, or application code. Never commit,
   push, open a PR, install a runtime, or execute the evaluated tool as part of evaluation.
- Do not vendor upstream documentation. Link to source material instead.
- Do not write secrets or private content into an evaluation.
- If evidence is thin, say what could not be verified.

## Evaluation Record

For every completed `upsert`, `defer`, or `skip` assessment, save one Markdown record under
`docs/evaluations/<candidate>.md` in the verified SkillVault checkout, unless `--chat-only` is
requested. This is a narrow record-only exception to read-only evaluation, not skill authoring.
Use the sibling `skillvault-installation/scripts/resolve-source-repo.ps1` in Upsert mode with the original
working project and optional explicit RepoPath. Accept only a verified resolved repository; do
not clone, pull, or switch branches. If unavailable, return the evaluation with `Record: Not saved`
and the reason instead of writing in an unrelated project or claiming success.

Match an existing record by canonical source URL and reuse its filename. Normalize a new name
to lowercase hyphen-separated words; include the source owner when two candidates share a name.
Read before updating and preserve unrelated notes. Keep the latest assessment in place, including
date, canonical source, verified version/revision or Unknown, purpose/audience, capabilities,
value/fit, actual overlap, installed recommendation, risks, skill recommendation/rationale,
separate standalone-use and harness-integration recommendations when relevant, verification limits,
and when to reconsider. Search candidates alone do not require records. Backfill only completed
evaluations actually available in the conversation or an explicitly selected record, not invented
historical conclusions.

Keep records concise and public-safe. Internal candidates or private assessments require a
separately selected private destination; otherwise use chat-only and explain why. Evaluation
records are lasting repository documentation, not harness run reports or retention candidates.
The catalog remains an index of actual skill bundles. End the response with `Record: <path>` or
`Record: Not saved (<reason>)` and distinguish source review from runtime testing.