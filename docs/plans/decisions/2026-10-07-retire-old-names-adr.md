# ADR: Retire Old Skill and Command Names

- Date: 2026-10-07
- Status: Accepted
- Superseded in part 2026-10-09: `skillvault-install` is a current name again, and
  `skillvault-installation` is retired instead; see the [verb-named topics ADR](./2026-10-09-verb-named-topics-adr.md).
- Superseded in part 2026-10-09: decision 2 no longer holds, because action aliases inside topics are
  dropped too, and `harness-dev`, `harness-decide`, `/hn-dev`, and `/hn-decide` are current names
  again; see the [bare, text, and menu convention ADR](./2026-10-09-bare-text-menu-convention-adr.md).
- Decision owner: Zhaolong Wang
- Scope: Old skill, topic, and command names that current skills still accepted or advertised, the folders and copies that carried them, and stale repository files.
- Supersedes: Decision 5 ("Old commands") of the [harness topic consolidation](./2026-10-07-harness-topic-consolidation-adr.md) and the compatibility routes kept for older names in the [topic refactor plan](../2026-09-16-topic-skill-refactor.md). The [SkillVault topic consolidation](./2026-10-07-skillvault-topic-consolidation-adr.md) already retired the old SkillVault spellings.

## Context

After the harness and SkillVault topics were consolidated, the owner asked whether all old names
were retired, found the runtime folder still named `harness`, and then asked for the installed
skills and the repository to be clean. Current skills still accepted, and in several descriptions
advertised, names of skills and commands that no longer exist. Every chat loaded those
descriptions, and the names invited the use of topics that are gone.

## Decision

1. **Old names are not accepted or advertised.** Current descriptions, guides, and documentation no
   longer route or list these names:
   - the former `/harness` and `/hn` topic and the retired harness topics (task, dev, test, link,
     policy, doc, comms, report), with their `/hn-*` spellings;
   - earlier harness commands (ref, restrict, fallback, root, loc, init, context, decide,
     report-create, management);
   - `/pr-review-add`, `/pr-review-list`, `/pr-review-remove`, and `/pr-review-timer`;
   - `/jarvis-metrics-create`, `/kpi-dashboard-design`, `/openapi-spec-generation`, and `rules-core`.
2. **Action aliases inside current topics stay.** `loc` (for `root`), `now` and `next` (for `run --now`
   and `queue`), `eval` and `expl`, `catalog`, the old `declare` policy form, and `create` or `update`
   for `upsert` are not separate names. They never appear as skills, folders, or menu entries.
   *Amended 2026-10-07:* at the owner's request, `/rules core` is an alias of `/rules apply`, and bare
   `/rules` shows the four core rules, because the retired separate command had been the visible
   way to find them. *Amended 2026-10-08:* `/rules core` is now short for `/rules apply core`, which
   applies only the four core rules; `/rules apply` adds the extra rules.
3. **Retirement mechanisms stay.** The installer's former-name map, the bootstrap installers' legacy
   lists, the ownership check for older runtimes, and the fixtures that test them keep old names so
   that copies installed under them are found and retired. *Amended 2026-10-07:* older ADRs, review
   notes, plans, and evaluations now name the current topics, and each rewritten record says so
   under its title. Only this ADR and the two consolidation ADRs keep old names, because they
   record the renames.
4. **Old-named files are renamed.** The decision helper is `harness-decision.ps1`. Installation's
   inventory and refresh scripts are `skill-inventory.ps1` and `skill-refresh.ps1`, authoring's
   removal script is `skill-remove.ps1`, and the runtime's limits, fallback, and pause module is
   `harness-safety.ps1`. The tests are `test-harness-decision.ps1`, `test-harness-write.ps1`,
   `test-harness-safety.ps1`, `test-skill-refresh.ps1`, `test-skill-refresh-merge.ps1`,
   `test-skill-remove.ps1`, and `test-skill-upsert.ps1`, and test temporary folders use current
   names. Because `harness-timer` finds the refresh script by path, the `structured-refresh`
   interface moves to version 2, so mismatched copies fail the compatibility check instead of
   calling a missing script; a refresh schedule saved with the old path needs
   `/harness-timer set refresh` once. The runtime no longer reads a `rules-core` folder; it reads
   the `rules` skill's core reference.
5. **External guides name current topics.** `graphify`, `awesome-gamedev-agent-skills`,
   `office-documents`, `humanizer-ch`, and `ppt-master` now name `harness-write` and
   `/skillvault-installation refresh`, at the owner's request. Their upstream records are unchanged.
6. **Stale copies are removed.** The tracked root `plans/` folder, an older duplicate of two
   documents under `docs/plans/`, is deleted, and an orphaned `~/.copilot/skillvault-sync-src` cache
   from the retired sync skill is removed. Git history keeps the old documents. The refresh and
   original-skill caches move to `~/.copilot/skillvault-cache/refresh` and
   `~/.copilot/skillvault-cache/originals`; existing caches on the owner's machine were moved there.
7. **Some names stay because they are not ours to change.** The `.skillvault-install.json` marker
   stays, because every installed copy uses it. Source links keep the originals' own folder names,
   such as `kpi-dashboard-design` and `openapi-spec-generation`. Legacy `.harness` controller
   folders in other projects stay until their owner approves a migration.

## Consequences

- Typing a retired command no longer has a documented meaning; use the current topic, such as
  `/hn-work run` instead of `/hn-dev run`, or `/hn-project policy list limits` instead of
  `/hn-restrict`. Natural-language requests still route by meaning.
- Removing accepted inputs is a major change: `harness-decision`, `harness-timer`, `pr-watch`,
  `rules`, and `jarvis-metrics` move to 2.0.0. Topics first released today stay at 1.0.0, and
  adapted, reference, and guide skills keep `null`.
- Machines with copies under old names still clean up through `update --topics` or the bootstrap
  installers, which keep the old names for that purpose.

## References

- [Harness topic consolidation](./2026-10-07-harness-topic-consolidation-adr.md)
- [SkillVault topic consolidation](./2026-10-07-skillvault-topic-consolidation-adr.md)
- [Topic refactor plan](../2026-09-16-topic-skill-refactor.md)
