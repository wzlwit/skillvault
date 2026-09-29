
# SkillVault List

This skill inventories installed SkillVault skills and gives each result a stable index for the
current command run. Removing selected entries belongs to [uninstall](uninstall.md), which uses the
same index.

## Parameters

- `scope` — optional scope filter: `all`, `global`, `project`, or `session`. Default: `all`.
   `all` lists global and discovered project skill folders. Use `session` explicitly for
   session-only skill folders when present.
- A legacy `list uninstall <selector>` request, such as `/sv-list uninstall 2`, follows
  [uninstall](uninstall.md).

## Behavior

1. Scan the current user's global skill directory: `~/.copilot/skills`.
2. Scan discovered project skill directories when present: `.github/skills` in the current
   repo and common local repo parents such as `C:\repos`, `C:\ghe`, `~/repos`, and `~/source`.
   This cross-project discovery is intentional.
3. If the user specifies `global`, `project`, or `session`, filter to that scope; otherwise
   list global and project scopes.
4. Include skill folders even when they do not contain `skill.json`; use the folder name,
   blank version fields, and `managed = no` for those entries.
5. Read `.skillvault-install.json` when present and show whether the skill is managed by
   SkillVault, its requested version, source path, and install time.
6. Sort by scope, then skill name, then path.
7. Assign indexes starting at `1` for the current result set.
8. Show a concise table with index, scope, skill name, installed version, requested version,
   managed status, and path.
   For project entries, show the project name in the `Scope` column instead of a separate
   `Project` column.

Listing never changes files.

## Script

```powershell
~/.copilot/skills/skillvault-installation/scripts/skillvault-list.ps1
~/.copilot/skills/skillvault-installation/scripts/skillvault-list.ps1 -Scope project
~/.copilot/skills/skillvault-installation/scripts/skillvault-list.ps1 -Scope session
```

`-GlobalSkillsPath` selects an explicit fixture root for testing.