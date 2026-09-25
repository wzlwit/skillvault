# ADR: Flattened Skill Source Layout

- Date: 2026-09-23
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: SkillVault source directories, template location, and source-path compatibility
- Replaces: The `skills/public/<category>/<skill>` and `skills/templates/` layout only

## Context

SkillVault is a repository for public, shareable skills, organized by category. The owner
explicitly requested removal of the intermediate `public` directory and moving templates up
one level, with a rename only if useful. The source move was implemented before this record.

The extra directory did not distinguish separate source classes in the intended layout.
Templates are scaffolds, not catalog skills, so they belong outside the catalog's source root.
The [topic plan](../2026-09-16-topic-skill-refactor.md#folder-layout) remains the current layout
reference. The [earlier work-contract ADR](./2026-09-18-upsert-and-harness-work-contracts-adr.md)
continues to govern authoring, execution, and approval boundaries; it is not superseded.

## Decision

1. Store skill bundles at `skills/<category>/<skill>/`, without a `public` intermediate
   directory. Keep existing categories, skill names, versions, and bundle contents except for
   the source-path and compatibility changes required by the move.
2. Move `skills/templates/` to top-level `templates/`. Retain the conventional, descriptive
   name `templates` rather than abbreviating it to `skillTemp`. Templates remain outside the
   installable catalog.
3. Update catalog paths, manifest source paths, source resolvers, validators, installers,
   tests, and documentation links together. Preserve historical labels and recorded legacy
   installation paths where they are evidence or compatibility inputs, not active source paths.
4. Preserve managed global `latest` refreshes across the move: when the recorded old path is
   missing, accept the flattened path only if the same repository's catalog uniquely confirms
   the identical skill name and category destination. Use the existing staged replacement to
   update metadata, including when content is unchanged. Do not guess a new name, category,
   or repository; existing pin, scope, ownership, and failure-isolation rules still apply.
5. Keep this a source-only change. Do not update installed copies, retarget live schedules,
   move project records, stage or commit work, or publish remotely as part of this decision.
   Existing installation and publication approvals remain separate.

## Alternatives and Consequences

- **Keep the old layout:** Avoids changing source paths, but retains the nesting the owner
  asked to remove in a repository dedicated to shareable skills.
- **Flatten skills but leave templates inside `skills/`:** Keeps scaffolds among catalog
  sources and requires distinguishing them during source discovery and validation.
- **Flatten skills and use top-level `templates/`:** Selected. Keeps category organization
  while separating reusable scaffolds from installable skills.
- **Rename to `skillTemp`:** Not selected. The abbreviation is less explicit than `templates`
  and adds a naming change without a corresponding structural benefit.

Direct callers of removed source paths must update. Installed tools that still require
`skills/public/` are not repaired by moving repository files; their updates need separate
approval. The refresh compatibility above is implemented in the new source helper, not injected
into old installed copies. No filesystem alias preserves the removed directory.

Reversal would require another coordinated directory, catalog, consumer, and metadata change.
The one-way refresh relocation does not automatically reverse newer recorded source paths.
Neither direction requires moving harness boards, workspaces, or schedules, and neither
authorizes discarding local changes or rewriting accepted decision history.

## Implementation and Verification

The [source validator](../../../scripts/validate-skill-files.mjs) checks the three-part catalog
path and reads templates from the repository root. The
[refresh helper](../../../skills/core/skillvault-refresh/scripts/skillvault-fresh.ps1) implements
the catalog-confirmed relocation, covered by the [refresh fixture](../../../scripts/test-skillvault-fresh.ps1).

During implementation on 2026-09-23, all 23 Node instruction tests and all PowerShell/Bash
fixture groups in the [regression suite](../../../scripts/test-all.ps1) passed. Catalog/manifest
source-path agreement, PowerShell syntax, and rebased local links were also checked. The full
suite then stopped on the pre-existing uncataloged `jarvis-metrics-create` bundle; this was not
a clean full-suite result. That bundle and existing Jarvis whitespace were preserved, not
cleaned up under the directory-move request.

No layout decision remains open. Recording this ADR did not authorize installed-copy rollout
or unrelated catalog cleanup. The later authorization below is limited to the listed copies.

## Approved Installed-Copy Rollout

- Date: 2026-09-23
- Status: Accepted; completed and verified

After the source move, the owner accepted updating both affected installed scopes with complete
local bundles and backups. The owner then explicitly confirmed applying the six-copy rollout,
including replacing global `skillvault-source` with `skillvault-authoring` and retiring the old
folder after verification. This fulfills the separate-approval requirement above; it does not
retroactively expand the original source-only decision.

### Scope and Rationale

| Skill | Version | Approved destinations |
| --- | --- | --- |
| `skillvault-installation` | 1.1.0 | Global and current workspace |
| `skillvault-refresh` | 1.0.0 | Global and current workspace |
| `skillvault-discovery` | 1.0.0 | Global only |
| `skillvault-authoring` | 1.0.0 | Global only, replacing `skillvault-source` |

Global destinations are `~/.copilot/skills/<name>/`; workspace destinations are
`<SkillVault-checkout>/.github/skills/<name>/`. All selected originals were managed `latest`
copies, not pinned versions. The source was the verified local SkillVault checkout's current
contents, including unpublished edits, not a claim of parity with the remote branch.

- Updating both existing scopes avoids leaving affected workspace copies on the old path
  contract while only the global copies are repaired. No new project-scoped copies were added.
- Complete bundles keep guidance, helpers, and metadata consistent with source. Path-only
  patches would be smaller but leave locally divergent bundles; full replacement also brings
  pending source improvements and overwrites any installed-copy edits in the selected targets.
- Retiring the verified, backed-up legacy authoring folder avoids duplicate registered entries.
  `/skillvault-source` and `/sv-source` remain compatibility text commands in the new guide.
- A catalog-wide refresh was not selected: unrelated skills and other projects were outside
  the approved target set.

### Outcome and Recovery

The [migration helper](../../../skills/core/skillvault-installation/scripts/migrate-topics.ps1)
updated the four global copies with retained backups. The two workspace copies were backed up
and updated through the [staged installer](../../../scripts/install-skills.ps1). Original bundles
and installation metadata remain in excluded `.skillvault-backup-migration-*` directories under
each installation root. Restoring those originals can undo the copy rollout, but older tools
may again require the removed source layout; backup availability is not a compatibility fix or
automatic rollback approval.

The [parity verifier](../../../scripts/verify-installed-skills.ps1) confirmed all six copies and
their metadata match source. Both installed installation resolvers and the global authoring
resolver accepted the flattened checkout. YAML, JSON, resource-link, and editor checks passed.
These focused results do not resolve the repository-wide catalog blocker recorded above.

No refresh job or timer was run. Other skills, live schedules and project state, source files,
Git staging, commits, and remote publication were unchanged by this rollout. No decision remains
open for these six copies; broader updates and Jarvis catalog cleanup require separate requests.