---
name: skillvault-uninstall
description: Uninstall global, project, or session skill folders by index, range, comma list, keyword, or skill name after showing matches and confirming deletion. Triggers on "/skillvault-uninstall", "skillvault-uninstall", "/sv-uninstall", "sv-uninstall", "remove skillvault skill", or "delete skillvault skill".
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "<selector> [scope]"
---

# SkillVault Uninstall

This skill removes installed skill folders after first showing the selected matches and
requiring confirmation. It reuses the indexed inventory behavior from `/skillvault-list`.

## Parameters

- `selector` — required first positional argument. Supports:
  - Single index: `2`
  - Comma list: `1,3,5`
  - Range: `4-7`
  - Mixed list and range: `1,3-5,9`
  - Keyword or skill name: `web-design-guidelines`, `fresh`, `review`
- `scope` — optional scope filter: `all`, `global`, `project`, or `session`. Default: `all`.
  `all` includes global and discovered project skill folders. Use `session` explicitly for
  session-only skill folders when present.

## Behavior

1. Build the same indexed inventory used by `/skillvault-list`.
2. Resolve the selector:
   - Numeric selectors target exact indexes.
   - Ranges target all indexes inside the range.
   - Keywords and skill names match name, source path, or target path case-insensitively.
3. Show the selected skill folders before deletion.
4. Ask for confirmation before deleting unless the user already explicitly confirmed deletion
   in the same request.
5. Delete only selected folders under allowed skill roots:
   - `~/.copilot/skills`
   - discovered `.github/skills` folders
   - known session skill roots, when `session` is explicitly requested
6. Report deleted and skipped entries.

## Script

Use the bundled list script for the actual deletion so selector behavior stays in one place:

```powershell
~/.copilot/skills/skillvault-list/scripts/skillvault-list.ps1 -Uninstall -Selector "2"
~/.copilot/skills/skillvault-list/scripts/skillvault-list.ps1 -Uninstall -Selector "1,3-5"
~/.copilot/skills/skillvault-list/scripts/skillvault-list.ps1 -Uninstall -Selector "web-design-guidelines"
~/.copilot/skills/skillvault-list/scripts/skillvault-list.ps1 -Uninstall -Selector "fresh" -Scope global
```

Use `-Force` only after the user explicitly confirms the selected matches should be deleted.

## Safety

- Always list or show selected matches before deletion.
- Never delete by keyword without showing matched indexes first.
- Never delete outside the allowed skill roots.
- Do not commit or push after uninstalling unless the user explicitly asks.