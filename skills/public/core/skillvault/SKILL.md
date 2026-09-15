---
name: skillvault-install
description: Install, update, or explore existing SkillVault catalog skills. Use for /skillvault-install, /sv-install, /skv-install, "install skill", or "update installed skills". Overlaps with skillvault-upsert on installing copies; source authoring belongs to skillvault-upsert.
metadata:
  author: wzlwit
  version: "1.1.0"
argument-hint: "[skill-or-folder-or-keyword] [scope] [version]"
---

# SkillVault Install

This skill installs, updates, and explores existing skills from the `skillvault` catalog at
`https://github.com/wzlwit/skillvault`.

Use `/sv-install` to install a missing skill or update an installed copy from the catalog.
It does not create or edit source skills. Use `/sv-upsert` to create or change a skill's source
in SkillVault; that workflow can optionally install the result afterward.

## Parameters

Parse these from the user's invocation text as positional arguments:

- `skillName` — the name of a specific skill to install or update (matches an entry in `catalog.json`).
- `folderName` — the name of a category or folder under `skills/public/`. If the invocation
  points to a folder that contains multiple skill folders, install or update the skills in that folder.
- `keyword` — a word or phrase to match against catalog `name`, `description`, or `path`.
  If multiple skills match, install or update all matched skills after showing the matched set.
  Numeric or comma-separated selectors are reserved for list/uninstall flows; use words for
  catalog keyword matching.
  If no skill, folder, or keyword is provided, treat this as a catalog exploration request.
- `scope` — optional second positional argument: `global`, `project`, or `session`. If omitted,
  read the resolved skill's `skill.json` `install.defaultScope`. If the manifest does not
  declare `defaultScope`, use `project`.
  - `global` installs into `~/.copilot/skills/<skillName>` (available to the current user across sessions on this machine).
  - `project` installs into `<current repo>/.github/skills/<skillName>` (available only in
    that repo).
  - `session` uses the resolved skill in the current AI session only. Do not copy files into
    `~/.copilot/skills` or `.github/skills`; read the resolved skill instructions and apply
    them for the current request.
- `version` — optional third positional argument: `latest` (default) or a tag in `v#.#.#`
  format, such as `v1.2.0`.

Examples of invocations to recognize:
- `/sv-install` → explore the catalog, no specific install.
- `/sv-install schedule-manager` → install, update, or use `schedule-manager` with its manifest-defined default scope.
- `/sv-install schedule project latest` → install or update all catalog entries whose name, description, or path matches `schedule` into project scope from latest.
- `/sv-install public` → install or update all skills under `skills/public/`.
- `/sv-install schedule-manager project` → install into the current project's
  `.github/skills/`.
- `/sv-install schedule-manager session latest` → use `schedule-manager` only in the current AI
  session.
- `/sv-install public global v1.0.0` → install the skills under `skills/public/` from tag
  `v1.0.0` globally.
- `/sv-install update` → refresh the approved managed installed skills in global scope and
  the current project, preserving pins unless explicitly changed.
- `/sv-upsert my-skill` → create or update a local SkillVault source skill, then
  install it using its default scope.

## Local source cache

Keep a local clone of the source repo at a fixed path so repeat invocations are fast and
support offline diffing:

```
~/.copilot/skillvault-src
```

For remote installs, use a clean cache and check each Git command's exit status. Do not reset
or discard local work to refresh it. When the user selected a local checkout, use that checkout
as-is and disclose that uncommitted changes are not published remotely.

For the remote cache:
1. If `~/.copilot/skillvault-src` does not exist, clone it:
   `git clone https://github.com/wzlwit/skillvault <path>`
2. If the requested version is `latest`, update it: `git -C <path> fetch origin main`
  followed by `git -C <path> checkout main` and `git -C <path> pull --ff-only`.
3. If the requested version is `v#.#.#`, fetch tags with `git -C <path> fetch --tags`, verify
  that the tag exists, then check out that tag. If the tag does not exist, stop and tell the
  user which version could not be found.
4. Read `<path>/catalog.json` to get the list of available skills (name, description,
   path, version). Treat `catalog.json` as a compact lookup index sorted by skill name.
   Derive display titles and grouping from `path`, or read the skill's own `skill.json`
   when richer metadata is needed.

## Behavior

### No `skillName` given (explore/sync mode)

1. Sync the local source cache (see above).
2. List all skills from `catalog.json` in a short table sorted by skill name. Include name,
   description, path, version, and whether it's already installed globally (check
   `~/.copilot/skills/<name>` for a match) or in the project (`.github/skills/<name>`).
   If the user asks for grouping, derive it from `path`. Keep `catalog.json` to its compact
   fields: name, description, path, and version.
3. Ask the user (via ask_user, multiple choice from the catalog list) which skill(s) they
   want to install or update, or offer "install all public skills".
4. Proceed to the install/update steps below for the chosen skill(s).

### `skillName`, `folderName`, or `keyword` given (install/update mode)

1. Sync the local source cache.
2. Resolve the argument as either:
   - A catalog skill name. Use its `catalog.json` `path` as the source folder.
   - A containing folder under `<path>/skills/public/<folderName>`. Install/update each child
     directory that contains a `skill.json` manifest, including one-level category folders such
     as `core` or `system`.
   - A keyword match over `catalog.json` `name`, `description`, or `path`. Install or update every matched
     catalog entry after showing the matched set. If nothing matches, stop and report no match.
3. Determine target scope:
   - If the user provided `scope`, use it.
   - If the user omitted `scope`, use the resolved skill's `install.defaultScope`.
    - If `install.defaultScope` is missing, fall back to `project`.
   - `global`: `~/.copilot/skills/<skillName>`
   - `project`: `<current repo root>/.github/skills/<skillName>` (create the
     `.github/skills` folder if missing)
   - `session`: no target path; read the resolved skill instructions and apply them only to
     the current request/session.
4. For `global` or `project`, use `scripts/install-skills.ps1` from the SkillVault checkout
  with `-Name`, `-Scope`, `-RepoRoot`, and the original working project's `-ProjectPath`.
  Omitted scope resolves per manifest. Show existing target differences and use `-Force`
  only for the approved replacements. It stages the copy and metadata before replacement,
  restores the prior install on swap failure, and excludes Git internals. Do not use symlinks.
5. The installer writes `.skillvault-install.json` into each target skill folder:
   - `installedBy`: `skillvault`
   - `sourceRepo`: repository that actually supplies the copied folder; for this catalog use
     `https://github.com/wzlwit/skillvault.git`, not a reference guide's upstream URL
   - `sourcePath`: the copied folder's catalog path within that repository
   - `scope`: resolved scope, either `global` or `project`
   - `requestedVersion`: `latest` or the requested `v#.#.#` tag
  - `installedVersion`: version from the copied skill's `skill.json`, including explicit null
   - `installedAt`: UTC timestamp
    `/skillvault-fresh` uses this metadata for managed global `latest` installs only.
    Upstream provenance does not authorize replacing a curated guide with an upstream plugin.
6. For `session`, read the resolved skill's `SKILL.md` or `README.md`, follow it for the current
  request, and confirm that no persistent install was written.
7. Confirm to the user: what was installed or used, the version from its `skill.json`, the
  requested source version (`latest` or tag), and the exact target path when files were copied.

### `/sv-install update` (explicit installed-copy refresh)

1. Sync the local source cache at `latest` unless the user provides a version tag.
2. Use the shared inventory to identify managed installed skills in global scope and the
  current project that exist in the catalog. Preserve pinned versions unless the user
  explicitly requests changing that pin. Preview replacements and install approved targets
  through `scripts/install-skills.ps1`; do not silently adopt unrelated unmanaged folders.
3. Report a short summary: which skills were updated, and their versions.

## Notes on versioning

- `latest` follows the source's default branch. For a requested tag, select a clean checkout
  of that tag, then pass `-RequestedVersion v#.#.#` to the installer. It verifies HEAD matches
  the tag before recording the pin. A missing tag or dirty tagged checkout is an error.
- Release version may be null. It is distinct from requested install policy and source
  revision; never substitute `latest` for an undeclared release version.
- After copying, read the target's `skill.json` `version` field back to confirm what was
  installed, so the user can see it changed after an update.

## Safety

- Never delete unrelated files outside the target skill's own folder.
- Always show the user a short summary of what changed before finishing.
- Use `scripts/validate-catalog.ps1` for repeated catalog and skill validation.
