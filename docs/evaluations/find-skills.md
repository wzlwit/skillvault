# Find Skills Evaluation

- Evaluated: 2026-09-26
- Selected candidate: `find-skills` from `vercel-labs/skills`
- Canonical source: https://github.com/vercel-labs/skills/tree/main/skills/find-skills
- Latest skill-file change reported by GitHub: `773fb2c7bbf16781670a3520affc4abd0c6151ae`
- Skill version: Unknown; its frontmatter declares no version
- CLI metadata inspected on `main`: `skills` version `1.7.0`, Node.js `>=22.20.0`; not an installed-version claim
- License: MIT, Vercel, Inc.; preserve attribution if adapting upstream material
- Recommendation: Skip a separate SkillVault bundle; keep the existing discovery and installation skills
- Scope: Upstream skill, directory listing, README, package metadata, license, and local counterpart instructions; no candidate execution

## Purpose and Workflow

Find Skills helps coding-agent users find reusable skills for a task and optionally install them.
It is an instruction workflow for the separate Skills CLI, not the search engine or installer itself.

The current guide identifies the task and domain, checks the skills.sh leaderboard, searches with
`npx skills find <query>` and optional `--owner`, then presents names, sources, popularity, links,
and installation commands. It recommends checking install counts, source reputation, and repository
stars before recommending a candidate. After the user wants to proceed, its installation example
uses `npx skills add <owner/repo@skill> -g -y`. It also points to updates and skill creation.

The inspected global/current-project inventory contained no `find-skills` copy. The current local
and official SkillVault catalogs contained no matching entry, and no optional local cache catalog
was present. The skills.sh entry identifies the selected Vercel repository as its source.

## Value, Fit, and Overlap

Value is medium for discovering public ecosystem skills, but low as an additional installed
workflow in SkillVault. The CLI's owner filter and public directory are useful discovery options.
Fit is an optional external source within the existing discovery workflow, without a new bundle.

- [SkillVault discovery](../../skills/core/skillvault-discovery/SKILL.md) already owns capability
  search, evaluation, and explanation. Its search procedure checks installed/local/configured
  sources before external registries and separates discovery from installation. Find Skills starts
  with the public leaderboard and has broad triggers such as ordinary requests for task help.
- [SkillVault installation](../../skills/core/skillvault-installation/SKILL.md) already owns scoped
  copies, source verification, replacement approvals, pins, and runtime coordination. Importing
  another discovery-and-install workflow would create a competing route for those operations.

Installed recommendation: Keep both existing SkillVault skills; skip installing Find Skills here.
The upstream directory can remain a manually selected external discovery source. A future explicit
request could add useful source-specific search guidance to the existing discovery skill.

## Risks and Limits

- Popularity is a discovery signal, not proof of task fit, safety, or maintenance quality. The guide's
  thresholds of 1,000 installs and 100 repository stars cannot replace reading candidate instructions,
  dependencies, permissions, and licensing. Small specialist skills can still be appropriate.
- Broad triggers can divert ordinary coding requests into skill shopping. Keep searches tied to a
  real capability gap or an explicit discovery request.
- The example `-g -y` selects user-wide installation and skips CLI prompts. It still needs an exact
  reviewed target and approval; discovery alone is insufficient. The CLI documents recommended
  symlinks and a Copilot project path under `.agents/skills/`, while SkillVault uses managed copies
  under `.github/skills/`. Do not replace managed skills through a second installer implicitly.
- Public search queries must exclude private identifiers and content. The CLI documents telemetry
  and security-audit requests, disabled by `DISABLE_TELEMETRY=1` or `DO_NOT_TRACK=1`. Its README warns
  that non-GitHub remote source identifiers may be included in install telemetry when visibility
  cannot be checked. Disabling telemetry does not make an external search query private.
- Unpinned `npx skills` invokes separately distributed executable code. Review the selected version,
  prerequisites, installation targets, and upstream instructions before a separately approved trial.

Standalone use: Browsing the directory is useful; a scoped CLI search may be worth trying when the
existing discovery flow misses a public candidate. No CLI command was run in this evaluation.
Harness integration: No new topic, runtime action, scheduler, or automatic installation is warranted.
Skill recommendation: Skip. Reconsider if a distinct, recurring CLI-specific workflow emerges that
cannot be covered by the existing discovery and installation boundaries.

This is a source review, not a runtime test or security audit of the CLI or listed third-party skills.
README and package metadata were read from `main`; their npm release contents were not verified.
Only this public-safe evaluation record was added. Skill bundles, catalog entries, installed copies,
and unrelated work were not changed by the evaluation.

## Sources

- [Find Skills instructions](https://github.com/vercel-labs/skills/blob/773fb2c7bbf16781670a3520affc4abd0c6151ae/skills/find-skills/SKILL.md)
- [Directory entry](https://skills.sh/vercel-labs/skills/find-skills)
- [CLI README](https://github.com/vercel-labs/skills/blob/main/README.md)
- [CLI package metadata](https://github.com/vercel-labs/skills/blob/main/package.json)
- [License](https://github.com/vercel-labs/skills/blob/main/LICENSE)