
# SkillVault Clean

Find skills that load twice or conflict, show overlaps, and fix only the findings the user picks.
Clean changes nothing until the user picks; its fixes reuse the existing uninstall, topic
migration, install, and authoring steps.

## Scan

Resolve the SkillVault checkout as for install (Install mode; `--repo` maps to `-RepoPath`), then run
the read-only scan:

```powershell
~/.copilot/skills/skillvault-installation/scripts/skillvault-list.ps1 -Check [-RepoPath <checkout>] [-ProjectPath <project>]
```

It reads the same places as [list](./list.md) (global `~/.copilot/skills` and discovered project
`.github/skills` folders), plus `~/.agents/skills` and `~/.claude/skills`, and returns JSON with
`places`, `findings`, and `catalogOverlaps`. A project's skills load together with the global
folders, not with another project's, so one skill in two projects is not a duplicate.

## Findings

| Kind | Meaning | Suggested fix (`action`) |
| --- | --- | --- |
| `Duplicate` | One skill name loads twice: in two global folders, or in a global folder and a project | Keep one copy, preferably the global SkillVault copy, and `uninstall` the other. A pinned copy (`decide`) needs the user's choice. |
| `AdaptationAndOriginal` | An adaptation and its original load together, under one name or as a renamed pair such as `kpi-dashboard` and `kpi-dashboard-design` | Keep the adaptation, the install default, and `uninstall` the original |
| `FormerName` | A SkillVault copy still uses an old name | `update-topics`: follow [topic-layout migration](./install.md#topic-layout-migration) |
| `NotInCatalog` | A SkillVault copy whose name no catalog skill uses | `uninstall` |
| `CannotLoad` | `SKILL.md` is missing or has no `name` or `description` header | `reinstall` a SkillVault copy with `install <name>`; otherwise `report` |

`report` marks copies SkillVault did not install, in any folder: show them, but never remove them.

## Overlaps

1. Show `catalogOverlaps`, the pairs that a catalog description names after "Overlaps with", on one
   line. They are known and need no fix.
2. Compare the names and descriptions of all skills this session loads, including the VS Code,
   extension, and plugin skills the host lists. Add pairs that would answer the same request as
   "possible overlap", leaving out catalog pairs. This is a judgment from descriptions, not proof.
3. An overlap never removes a skill. For a SkillVault skill, the fix is a clearer description
   through `/skillvault-authoring upsert`; for other skills, report only. For a closer comparison,
   use `/skillvault-discovery evaluate`.

## Show and Fix

1. Show one numbered table: finding, skills with their places, and the suggested fix. Mark the rows
   that SkillVault cannot fix.
2. Ask the user to reply with numbers, `all`, or nothing. No answer changes nothing.
3. Fix only the picked rows, each through its existing procedure and confirmations:
   - `uninstall`: run `skillvault-list.ps1 -Uninstall -Selector "<indexes>"` with the same scope and
     project path as the scan, check that the preview shows the expected paths, then rerun with
     `-Force`. A copy in another repository is a tracked file there; say that removing it leaves an
     uncommitted change in that repository.
   - `update-topics`, `reinstall`, and description fixes follow their own previews and approvals.
4. Scan again and show the result.

Picking a row approves only the fix shown for it. Ownership checks, rollback, and the other
confirmations still apply.
