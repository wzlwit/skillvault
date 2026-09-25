
# SkillVault Install

This skill installs, updates, and explores existing skills from the `skillvault` catalog at
`https://github.com/wzlwit/skillvault`.

Use `/skillvault-installation install` to install a missing skill or update an installed copy from the catalog.
It does not create or edit source skills. Use `/skillvault-authoring upsert` to create or change a skill's source
in SkillVault; that workflow can optionally install the result afterward.

## Parameters

Parse these from the user's invocation text as positional arguments:

- `skillName` — the name of a specific skill to install or update (matches an entry in `catalog.json`).
- `folderName` — the name of a category or folder under `skills/`. If the invocation
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
- `--repo <path>` - optional explicit source checkout, separate from installation scope. Resolve
  relative paths against the original working project. Use this to approve a different checkout;
  never infer that another session's clone is the intended source because its origin matches.

Examples of invocations to recognize:
- `/skillvault-installation install` → explore the catalog, no specific install.
- `/skillvault-installation install schedule-manager` → install, update, or use `schedule-manager` with its manifest-defined default scope.
- `/skillvault-installation install schedule project latest` → install or update all catalog entries whose name, description, or path matches `schedule` into project scope from latest.
- `/skillvault-installation install public` → install or update all skills under `skills/`.
- `/skillvault-installation install schedule-manager project` → install into the current project's
  `.github/skills/`.
- `/skillvault-installation install schedule-manager session latest` → use `schedule-manager` only in the current AI
  session.
- `/skillvault-installation install public global v1.0.0` → install the skills under `skills/` from tag
  `v1.0.0` globally.
- `/skillvault-installation update` → refresh the approved managed installed skills in global scope and
  the current project, preserving pins unless explicitly changed.
- `/skillvault-installation install harness-review project latest --repo C:\repos\skillvault` selects an exact source
  while keeping the current project as the installation target.
- `/skillvault-authoring upsert my-skill` → create or update a local SkillVault source skill, then
  install it using its default scope.

## Source Checkout

Before browsing, installing, updating, or using a session skill, run the bundled
[read-only source resolver](../scripts/resolve-source-repo.ps1) in its default Install mode:

```powershell
& <install-skill-folder>/scripts/resolve-source-repo.ps1 -ProjectPath <original-project-root>
```

Map `--repo <path>` to `-RepoPath <path>`. The installer selects only:

1. The explicit source checkout, when supplied.
2. Otherwise the known Windows checkout `C:\repos\skillvault`, when present and verified.

There is no automatic fallback to `~/.copilot/skillvault-src`, the working directory, a temporary
worktree, or any clone created by another session. If the known checkout is absent, including on
platforms without that path, `NeedsSource` requires the user to identify the actual checkout with
`--repo`. A matching repository name, catalog layout, or Git origin alone does not approve another
checkout. The resolver's Upsert mode belongs to the separate authoring workflow; do not select it
to bypass this installation rule or override the known path with a discovered clone.

Require `Status: Resolved`. Verification checks that the selected directory is the exact Git
root, contains `catalog.json` and `skills/`, and has one `origin` fetch URL identifying
`github.com/wzlwit/skillvault` using standard HTTPS or SSH. Invalid explicit/known sources block
installation without retargeting remotes or selecting another source. The helper uses PowerShell
5.1+ or PowerShell 7 and Git; if verification cannot run, report the missing prerequisite.

Read `CatalogPath` and the selected manifests/bundle files from the resolved checkout on every
invocation. Do not use cached search results, an earlier session's summary, or installed copies
as the source of truth. Installed copies are comparison targets for pins and customization review.
Show the resolved `RepoRoot`, catalog, selected source folders, and separate installation targets
before copying. Invoke that checkout's installer with an explicit `-RepoRoot <resolved-root>`;
keep `-ProjectPath` bound to the original project even when it differs from the source checkout.

Use the selected checkout as-is, preserving uncommitted work. For local `latest`, report that
the source is the current checkout contents, which may include unpublished edits; this does not
claim they match the remote tip. Do not fetch, pull, reset, switch branches, or clone as an implicit
install step. If a checkout or revision must be obtained, get approval for that exact destination
and operation first, then re-resolve the explicit path. Never overwrite another session's work.

## Behavior

### No `skillName` given (catalog exploration)

1. Resolve the actual source checkout using Source Checkout above; do not synchronize a cache.
2. Read its current `catalog.json` and list skills in a short table sorted by skill name. Include name,
   description, path, version, and whether it's already installed globally (check
   `~/.copilot/skills/<name>` for a match) or in the project (`.github/skills/<name>`).
   If the user asks for grouping, derive it from `path`. Keep `catalog.json` to its compact
   fields: name, description, path, and version.
3. Ask the user (via ask_user, multiple choice from the catalog list) which skill(s) they
   want to install or update, or offer "install all public skills".
4. Proceed to the install/update steps below for the chosen skill(s).

### `skillName`, `folderName`, or `keyword` given (install/update mode)

1. Resolve the actual source checkout and read its current catalog; stop if no source is resolved.
2. Resolve the argument as either:
   - A catalog skill name. Use its `catalog.json` `path` as the source folder.
   - A containing folder under `<path>/skills/<folderName>`. Install/update each child
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
  with `-Name`, `-Scope`, explicit `-RepoRoot <resolved-root>`, and the original project's `-ProjectPath`.
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
    `/skillvault-refresh` uses this metadata for managed global `latest` installs only.
    Upstream provenance does not authorize replacing a curated guide with an upstream plugin.
6. For `session`, read the resolved skill's `SKILL.md` or `README.md`, follow it for the current
  request, and confirm that no persistent install was written.
7. Confirm to the user: what was installed or used, the version from its `skill.json`, the
  requested source version (`latest` or tag), and the exact target path when files were copied.

### `/skillvault-installation update` (explicit installed-copy refresh)

1. Resolve the actual source checkout and read its current catalog. Apply the version rules below;
  do not refresh from a cache or another clone just because its metadata records the same origin.
2. Use the shared inventory to identify managed installed skills in global scope and the
  current project that exist in the catalog. Preserve pinned versions unless the user
  explicitly requests changing that pin. Preview replacements and install approved targets
  through `scripts/install-skills.ps1`; do not silently adopt unrelated unmanaged folders.
3. Report a short summary: which skills were updated, and their versions.

## Runtime Coordination

The shared [ownership helper](../scripts/skill-ownership.ps1) reserves selected replacement targets
before copying. It excludes active readers of those runtime bundles or dependencies, including
manual harness runs, and keeps a multi-target installer or migration reservation until it finishes.
`-Force` approves replacement; it does not bypass `Busy`, uncertain claims, or other required
approvals. A conflict names its owner and changes no reserved targets.

An older installed runtime without `ownershipProtocol: 1` cannot establish that it is idle.
Affected updates require an attended transition: inspect the relevant workers, confirm they have
stopped and will not restart during the transition, then supply `-ConfirmStopped` with the exact
approved `install-skills.ps1`, `install-global.ps1`, or migration invocation. Temporary originals
protect only the in-progress operation. This flag cannot take over an active ownership claim.
Never save that confirmation as an unattended permission; scheduled refresh has no such override.

Bash bootstrap delegates to the guarded PowerShell installer when available. Without PowerShell,
it defers changes when installed runtimes make ownership uncertain; it does not assume a missing
lock means idle. Run the attended transition through PowerShell rather than weakening this guard.
Source-only implementation changes do not update installed helpers or live schedules.

Executable bundles declare `runtimeInterfaces` and `requiredInterfaces` separately from package
versions. Requirements name declared dependencies and exact positive integer interface versions.
Admission checks the actual same-scope bundles while holding runtime ownership. Missing or
incompatible interfaces block execution and identify the companion update set; they do not
authorize its installation. An installed copy cannot satisfy a missing sibling from a source
checkout. Older admission helpers must be updated with the affected consumers. Catalog validation
checks interface declarations and source dependency compatibility before rollout.

## Transactional Updates

Keep one current installed copy at its canonical name. Replacement, topic migration, and
uninstall retain no historical installation archives or user-wide recovery directory. They use
the shared [transaction helper](../scripts/skill-transactions.ps1) to preserve complete originals
only while the operation is in progress, including local metadata and hidden files.

Temporary originals live under the OS temporary directory's `skillvault-updates/update-<id>/`,
outside source and skill discovery. The installer validates new contents before discarding originals.
A failed replacement restores the original and removes its temporary transaction after verified
rollback. A failed new installation removes its own partial target. Topic migration rolls back
the affected batch when work fails; successful migration leaves only the canonical copies.

If restoration itself fails, stop and report the temporary original path. Those files are an
unresolved transaction, not a retained version archive; finish recovery before discarding the
only unrestored original. Successful operations do not leave a rollback history, age/generation
policy, storage-budget configuration, or scheduled archive-cleanup job. The old recovery CLI
and retention interface are retired; `installation-transactions: 1` declares the new helper
contract. Update required companion bundles together through the normal ownership gate.

Preview exact managed replacements and obsolete names before an approved update. Retire an old
registered name only after its selected canonical replacement verifies. Do not delete third-party,
customized, pinned, or unrelated files merely because they are old. Existing archive and legacy
source removal requires an identified, approved set; an install request alone is not bulk cleanup.
Older command spellings may remain conversational aliases without duplicate installed folders.

Fixtures set `SKILLVAULT_TRANSACTION_ROOT` to an isolated temporary directory and use temporary
`SKILLVAULT_OWNERSHIP_ROOT` values. No test may write to installed copies, live histories, or
the retired recovery store. Recreating older versions is a separate explicit source/install
operation; current-copy maintenance never rewrites Git history, runs workers, or changes schedules.

## Notes on versioning

- Local `latest` uses the resolved checkout's current files. For a requested tag, require an
  explicitly selected clean checkout at that tag and pass `-RequestedVersion v#.#.#` to the
  installer. It verifies HEAD matches the tag before recording the pin. A missing tag or dirty
  tagged checkout blocks installation; do not silently switch the actual working repository or
  use another session's clone. Selecting/preparing another checkout requires explicit approval.
- Release version may be null. It is distinct from requested install policy and source
  revision; never substitute `latest` for an undeclared release version.
- After copying, read the target's `skill.json` `version` field back to confirm what was
  installed, so the user can see it changed after an update.

## Safety

- Source selection and installation targets are separate. A verification failure never authorizes
  a cache/clone fallback, source edits, Git publishing, or changes to unrelated installations.
- Never delete unrelated files outside the target skill's own folder.
- Always show the user a short summary of what changed before finishing.
- Use `scripts/validate-catalog.ps1` for repeated catalog and skill validation.
