
# SkillVault Remove

Remove selected skills from a local source repository, including their catalog entries.
This is not uninstall: global, project, and session installed copies remain untouched.
Creating or invoking this skill does not authorize commits, pushes, or remote deletion.

## Parameters

- `name`: one exact catalog skill name, or a comma-separated list of exact names. Do not
  interpret names as keywords, wildcards, folder paths, or remembered inventory indexes.
- `repo-path`: optional local source checkout. An explicit path must contain `catalog.json`
  and `skills/`; an invalid path is an error, not permission to choose another repo.
  Otherwise prefer the current workspace, then `~/.copilot/skillvault-src` when present.
  If neither is a SkillVault checkout, ask for a source path. Do not clone or search other
  repositories automatically for a destructive operation.

## Workflow

1. Read the selected repository's instructions and catalog. Resolve the exact names and
   inspect their source folders, uncommitted changes, and references in active documentation,
   dependency manifests, and bootstrap registrations. Do not remove historical records.
2. Run the bundled script without `-Force`. Show the repository, exact source paths, catalog
   entries, local changes that would be deleted, and any related documentation edits needed.
   The script refuses unresolved dependencies and bootstrap registrations; resolve those
   only as part of an explicitly approved change, not by silently dropping dependencies.
3. Ask for confirmation covering that exact removal set unless the user already explicitly
   approved it in the same request. A request to create this skill is not approval to remove
   any existing skill. Reconfirm if the set or selected repository changes.
4. After confirmation, run the same script with `-Force`. It stages the source folders,
   replaces the catalog, and then deletes the staged copies. A pre-completion failure restores
   the sources where possible; if recovery or cleanup fails, report the retained recovery path
   and stop rather than claiming the repository is clean.
5. Apply only the approved active-documentation cleanup. Do not uninstall copies, edit other
   repositories, alter schedules, or publish. Source removal does not disable refresh tasks;
   offer `/skillvault-installation uninstall` separately if installed copies should also be removed.
6. Run the repository's required checks. In SkillVault, use `scripts/validate-catalog.ps1`,
   `scripts/test-all.ps1`, and `git diff --check` after the once-per-checkout `npm ci` setup.
   Report removed names, repository path, validation results, and unchanged installed copies.

## Script

Use the [bundled removal script](../scripts/skillvault-remove.ps1), which requires the sibling
`skillvault-installation` skill's shared file helpers. Preview is the default:

```powershell
~/.copilot/skills/skillvault-authoring/scripts/skillvault-remove.ps1 -Name architecture-decision-records -RepoRoot C:\repos\skillvault
```

After explicit confirmation, repeat with `-Force`. For multiple names, pass a PowerShell
array such as `-Name architecture-decision-records,planning-with-files`.

## Safety

- Delete only the selected catalog-backed `skills/<category>/<name>` directories.
- Reject traversal, linked source paths, duplicate catalog names, and unknown names before
  writing anything. Do not recursively delete a category, repository, or installed-skill root.
- Preserve unrelated files and local work outside the confirmed source directories.
- Never commit, push, open a PR, or delete from a remote repository without a separate request.