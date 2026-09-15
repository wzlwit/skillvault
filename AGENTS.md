# SkillVault Agent Notes

SkillVault is a catalog-driven repository for public, shareable Copilot skills.

## Layout

- `catalog.json` is the compact lookup index for install/discovery.
- `skills/public/core/` contains SkillVault management skills.
- `skills/public/system/` contains OS/system utility skills.
- `skills/templates/` contains reusable scaffolds.
- `scripts/` contains repeatable automation. Use scripts or code when they make a repeated or error-prone task clearer, safer, or easier to rerun.

## Catalog Rules

Keep `catalog.json` simple and sorted by `name`. Each entry has only:

```json
{
  "name": "skill-name",
  "description": "Short purpose.",
  "path": "skills/public/<category>/<skill-name>",
  "version": "1.0.0"
}
```

Every public skill must appear in `catalog.json`. The catalog `name` and `version` must match the skill's `skill.json`.

The `version` field must be present in both files: use a non-empty string for a declared
version, or explicit JSON `null` when unversioned. `latest` is an installation policy,
not a substitute for an unknown version.

## Skill Rules

- Each skill folder has `skill.json` and usually `SKILL.md`; add `README.md` when useful for humans.
- `skill.json` owns richer metadata such as `title`, `tags`, `source`, and `install.defaultScope`.
- Preserve verified original authorship for imports and disclose adaptations. Do not infer a redistribution license from repository access.
- `install.defaultScope` must be `global`, `project`, or `session`; missing defaults are treated as `project` by `/sv-install`.
- Keep `SKILL.md` concise, direct, and specific about trigger phrases and safety rules.
- When skills materially overlap, briefly name the counterpart and shared work in `catalog.json`,
  `skill.json`, and `SKILL.md` frontmatter descriptions, while making each skill's distinct role clear.
  Verify against the relevant skill instructions; preserve trigger phrases and reference-only limits.
  Recheck these notes during upserts and update relevant docs without adding catalog fields or treating overlap as removal approval.
  An optional follow-up alone is not material overlap; describe it directly, such as "can install afterward."
- Prefer bundled scripts for repeated or tedious operations when they make the work clearer, safer, or easier to rerun.

## Management Skills

- `/skillvault-install`, `/sv-install`, or `/skv-install` installs, updates, and explores existing catalog skills by name, folder, keyword, scope, and version. It changes installed copies, not source skills.
- `/skillvault-evaluate` or `/sv-evaluate` reviews a source URL or existing skill name for purpose, value, fit, and risks before any upsert.
- `/skillvault-search` or `/sv-search` discovers candidates across installed, local, configured internal, official, and external sources without installing them.
- `/skillvault-upsert`, `/sv-upsert`, or `/skv-upsert` creates/updates local SkillVault source skills from a name or URL and can optionally install the result. Use install for existing catalog skills, upsert for source authoring; publishing requires an explicit request.
- `/skillvault-remove`, `/sv-remove`, or `/skv-remove` removes exact source skill folders and catalog entries from a selected local checkout after confirmation. Installed copies stay unchanged; use `/sv-uninstall` for those.
- `/rules` proposes and, after confirmation, adds, modifies, or removes rules in an authoritative AI-rules document. `/rules-core` supplies the compact four-rule guidance set.
- `/skillvault-fresh`, `/sv-fresh`, or `/skv-fresh` schedules one-way latest refreshes from source repos to installed skill folders. The interval is in days, defaults to `1`, supports decimals, and `0` runs one immediate refresh. It does not push upstream.
- `/skillvault-list` or `/sv-list` lists global/project installed skills by index. `/skillvault-uninstall` or `/sv-uninstall` uninstalls by index, range, list, keyword, or skill name after confirmation.
- `/schedule-manager` lists Windows scheduled tasks and enables, disables, or deletes selected tasks by index, range, list, or keyword after confirmation.

## Validation

Run this after changing catalog entries, skill manifests, skill instructions, or scripts:

```powershell
npm ci
.\scripts\validate-catalog.ps1
.\scripts\test-all.ps1
git diff --check
```

`npm ci` is needed once per checkout for Node 20+ YAML validation tooling, not for installed
skills. `test-all.ps1` uses fixtures and fake task/Git commands; it does not alter live schedules.
Use `scripts/install-skills.ps1` for selected local installs and
`scripts/verify-installed-skills.ps1` for an explicit source/copy parity check. Local customized
copies need not match a newer checkout unless a refresh is requested.

For bootstrap installer changes, run `scripts/test-bootstrap.ps1`, then run
`scripts/install-global.ps1` for approved targets and verify installed metadata against the
catalog. Changed or pinned installs require review and explicit `-Force` (`--force` in Bash).

## Git Safety

Do not commit, push, force-push, or open a PR unless the user explicitly asks. This repo may intentionally keep all work uncommitted while the design is still moving.