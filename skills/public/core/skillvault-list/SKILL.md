---
name: skillvault-list
description: List global, project, or explicit session SkillVault skills with indexes, and uninstall selected skills by index, list, range, or keyword. Triggers on "/skillvault-list", "skillvault-list", "/sv-list", "sv-list", "list skillvault skills", or "uninstall skillvault skill".
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|uninstall] [selector] [scope]"
---

# SkillVault List

This skill inventories installed SkillVault skills and gives each result a stable index for
the current command run. It can uninstall selected skills by index, comma list, range, or
keyword.

## Parameters

- `action` — optional first positional argument: `list` or `uninstall`. Default: `list`.
- `scope` — optional scope filter: `all`, `global`, `project`, or `session`. Default: `all`.
   `all` lists global and discovered project skill folders. Use `session` explicitly for
   session-only skill folders when present.
- `selector` — optional second positional argument for uninstall. Supports:
  - Single index: `2`
  - Comma list: `1,3,5`
  - Range: `4-7`
  - Mixed list and range: `1,3-5,9`
  - Keyword: `sync` or `review`

## Behavior

When listing:

1. Scan the current user's global skill directory: `~/.copilot/skills`.
2. Scan discovered project skill directories when present: `.github/skills` in the current
   repo and common local repo parents such as `C:\repos`, `C:\ghe`, `~/repos`, and `~/source`.
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

When uninstalling:

1. Build the same indexed list first.
2. Resolve the selector:
   - Numeric selectors target exact indexes.
   - Ranges target all indexes inside the range.
   - Keywords match skill name, source path, or target path case-insensitively.
3. Show the selected skills before deletion.
4. Ask for confirmation before deleting unless the user has already explicitly confirmed in
   the same request.
5. Delete only the selected skill folders under `~/.copilot/skills`, discovered `.github/skills`,
   or known session skill roots when `session` is explicitly requested.
6. Report deleted and skipped entries.

Cross-project discovery is intentional. Confirmation must cover the exact displayed names,
paths, and scopes, not just a remembered index. Re-list and confirm if the matched set changes.
Linked skill directories and reserved session, staging, or backup containers are not global
uninstall targets. `-GlobalSkillsPath` supports explicit fixture roots for testing.

## Script

The bundled Windows script can run the list and uninstall operations directly:

```powershell
~/.copilot/skills/skillvault-list/scripts/skillvault-list.ps1
~/.copilot/skills/skillvault-list/scripts/skillvault-list.ps1 -Scope project
~/.copilot/skills/skillvault-list/scripts/skillvault-list.ps1 -Scope session
~/.copilot/skills/skillvault-list/scripts/skillvault-list.ps1 -Uninstall -Selector "2"
~/.copilot/skills/skillvault-list/scripts/skillvault-list.ps1 -Uninstall -Selector "1,3-5"
~/.copilot/skills/skillvault-list/scripts/skillvault-list.ps1 -Uninstall -Selector "sync"
```

Use `-Force` only when the user has explicitly confirmed deletion.

## Safety

- Do not delete anything outside `~/.copilot/skills` or `.github/skills`.
- Prefer listing first when selector matching is ambiguous.
- Never uninstall by keyword without showing the matched indexes first.
- Do not commit or push after uninstalling unless the user explicitly asks.