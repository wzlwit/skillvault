# ADR: SkillVault Topic Consolidation

- Date: 2026-10-07
- Status: Accepted
- Superseded in part 2026-10-09: the three topics are now `skillvault-install`,
  `skillvault-discover`, and `skillvault-author`, with `/sv-install`, `/sv-discover`, and
  `/sv-author` as shorthands; see the [verb-named topics ADR](./2026-10-09-verb-named-topics-adr.md).
- Superseded in part 2026-10-09 (later): their action sets change, with search and evaluation in one
  flow; see the [bare, text, and menu convention ADR](./2026-10-09-bare-text-menu-convention-adr.md).
- Decision owner: Zhaolong Wang
- Scope: The registered SkillVault management topics, where refresh lives, and which old command names still route.
- Supersedes: The separate `skillvault-refresh` registration in the [topic refactor plan](../2026-09-16-topic-skill-refactor.md) and the legacy command routes it kept for SkillVault topics (`/skillvault-source`, `/sv-source`, `/sv-install`, `/sv-list`, `/sv-uninstall`, `/sv-search`, `/sv-evaluate`, `/sv-key-points`, the fresh and sync spellings, and their `/skv-*` and full-name forms). The [harness topic consolidation](./2026-10-07-harness-topic-consolidation-adr.md) is unaffected; its old harness commands still route. *Updated 2026-10-07:* later the same day, the [old-name retirement ADR](./2026-10-07-retire-old-names-adr.md) retired those old harness commands too.

## Context

After the harness topics were consolidated, the owner asked whether the four `/sv-` topics could
shrink too. They held 14 actions and about 1,900 characters of descriptions, and their names
already said what each did. Typed usage was uneven: discovery about 56 commands (mostly
`evaluate`), authoring about 32, installation about 25, and refresh only two or three. Refresh
usually runs as a scheduled job.

The one real overlap was "update my skills": `/sv-installation update` copies from the local
checkout, while `/sv-refresh run` merges upstream changes into adapted skills, pulls the recorded
checkout, and updates managed global latest copies.

The owner then rejected verb shortcuts such as `/sv-eval`, because typed shortcuts never appear in
the `/` list and only add things to remember. The owner chose the three-topic layout, asked to
retire the old names, and asked for installed copies to follow.

## Decision

1. **Three topics.** `skillvault-refresh` folds into `skillvault-installation` as the `refresh`
   action: `/skillvault-installation [list|install|update|uninstall|clean|refresh]`. Discovery and
   authoring stay separate: discovery holds the most-used command, and authoring is for the
   maintainer, while the public bootstrap installs discovery and installation.
2. **Refresh behavior is unchanged.** `refresh` runs once. `/harness-timer set refresh` still owns
   scheduling. The refresh script and guide move into the installation bundle as
   `scripts/skill-refresh.ps1` and `references/refresh.md`. Its saved cache
   (`~/.copilot/skillvault-fresh-src`) and the legacy OS task name stay, so existing state keeps
   working. *Amended 2026-10-07:* the cache moved to `~/.copilot/skillvault-cache/refresh` and the
   refresh interface to `structured-refresh: 2`; see the
   [old-name retirement ADR](./2026-10-07-retire-old-names-adr.md).
3. **Installation's source boundary gains one exception.** Installation still never edits SkillVault
   sources or application code, except that `refresh` keeps the owner's 2026-09-30 exception:
   commit merged adaptation updates only in its own clone and push them when permitted, never the
   owner's commits or checkout.
4. **Runtime contract moves with the script.** `skillvault-installation` now declares
   `ownershipProtocol: 1` and `structured-refresh: 1`, and `harness-timer` requires that interface
   from it. The bash bootstrap treats installation as a runtime bundle, as it did refresh.
5. **Old names are retired.** Current descriptions, guides, and docs no longer advertise or route
   the old SkillVault command spellings. `/sv-<topic>` shorthand for the three topics and in-topic
   aliases (`eval`, `expl`, `catalog`, and `create`/`update` for `upsert`) remain. The installer's
   former-name map and the bootstrap's legacy list still retire installed copies under old names.
6. **No new verb shortcuts.** Typed `/sv-<verb>` commands are not added.

## Consequences

- The `/` menu shows three SkillVault topics instead of four, and one skill fewer is installed.
- Users who typed retired spellings use the topic commands instead; natural-language requests still
  route by meaning.
- A refresh schedule saved before this change points at the removed folder. Running
  `/harness-timer set refresh <duration>` once points it at the new script and keeps its cadence. The
  owner's machine had no saved refresh job.
- Versions: `skillvault-installation` 2.0.0, `skillvault-discovery` 2.0.0, and
  `skillvault-authoring` 3.0.0 (retired command spellings are removed inputs); `harness-timer`
  keeps its pending patch. *Updated 2026-10-07:* the [old-name retirement ADR](./2026-10-07-retire-old-names-adr.md)
  later moved `harness-timer` to 2.0.0.
- The `graphify` and `awesome-gamedev-agent-skills` guides still mention `/skillvault-refresh`;
  editing those external-source guides needs the owner's approval. *Resolved 2026-10-07:* both are
  SkillVault-written guides, and they now point to `/skillvault-installation refresh`.

## Alternatives Considered

- **Keep four topics.** No migration, but the update/refresh overlap stays.
- **Hide refresh from the menu only.** Three menu entries with nothing moved, but the overlap and its
  description stay.
- **Two topics.** Merging discovery into installation or authoring hides `evaluate` behind a broad
  name and mixes consumer bootstrap with maintainer authoring.
- **Verb shortcuts (`/sv-eval`) or registered `sv-*` names.** Shortcuts never autocomplete;
  registering `sv-*` reverses the earlier naming correction and moves the shared runtime folder.

## References

- [Installation topic](../../../skills/core/skillvault-install/SKILL.md)
- [Refresh procedure](../../../skills/core/skillvault-install/references/refresh.md)
- [Topic refactor plan](../2026-09-16-topic-skill-refactor.md)
