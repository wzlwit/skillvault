# ADR: Evidence-Grounded Feature Documentation

- Date: 2026-09-26
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: Reader-facing feature doc sets, focused updates, source evidence, and final readability/validation.
- Related: [Topic contracts](../2026-09-16-topic-skill-refactor.md) and [report authoring](2026-09-15-harness-report-authoring-adr.md).

## Context

Feature documentation needs to explain why a design exists, how it works, how to adopt it, and
how to diagnose problems. Design records retain decisions; they do not by themselves provide
an onboarding or troubleshooting path for new readers. The existing report topic owns dashboards
and queries. A separate documentation topic gives this work a clear authoring and validation flow.

## Decisions

1. Register one `harness-doc` skill, with `/hn-doc` as conversational shorthand. Bare invocation
   and `list` inspect existing sets and actions. `upsert` creates or updates a resolved set/page;
   `create` and `update` are aliases. Do not add a second `feature-doc-set` bundle or runtime action.
2. Support complete feature sets and focused updates. Use the seven-page outline as a default,
   adapting lifecycle/deep-topic pages and preserving existing paths and navigation. Compare old
   and new where change is real; first-version features do not need an invented predecessor.
3. Allow direct session authoring without an initialized harness. Reuse an existing approved task
   when applicable, with its repository, ownership, permissions, and pause controls intact.
4. Ground claims in the owning code, configuration, package metadata, accepted designs, and verified
   history. Distinguish implementation from plans and rollout. Treat feedback as evidence to verify;
   unresolved essential onboarding or repair steps cannot be presented as ready instructions.
5. Distinguish internal, authorized partner, and public readers. Honor explicit output first, then
   the selected coding repository's documentation convention; use `docs/guides/<feature>/` when no
   convention exists. Keep restricted evidence private and harness runtime records controller-local.
6. Run Humanizer as the final prose-editing phase, using its authoritative upstream guidance.
   Preserve facts, caveats, headings, anchors, code/data, diagram logic, and link targets. Follow it
   with factual, terminology, link/anchor, diagram-rendering, navigation, and diff checks.
7. Missing essential evidence, Humanizer guidance, or required validation leaves a Draft with the
   outstanding work named. Validated and Published are separate outcomes. Restructuring, dependency
   installation, rebasing, commits, pushes, PR creation, and review writes need separate authorization.

## Alternatives

- Extending `harness-report` would mix reader guides with platform-specific dashboard/query work.
- Requiring harness initialization would add runtime setup to ordinary documentation requests.
- Producing seven pages for every update would duplicate working documentation and expand scope.
- Repeating a generic old/new table on every page would add little to glossaries and focused troubleshooting guides.
- Treating a style pass or syntax scan as final validation would leave factual and rendering risks unchecked.

## Consequences

The bundle supplies an authoring workflow and page template, not a bundled renderer or document
generator. `rules` and the Humanizer reference are its declared companions. Humanizer's upstream
rules are fetched before rewriting; a reference installation alone does not supply them. Existing
repository validation tools and compatible renderers are reused, with missing prerequisites reported.

The workflow references architecture decision records without changing their status or history.
Its public examples remain generic. Source development does not create reader documents in other
repositories, initialize controllers, change schedules, or publish anything. Installation follows
the normal selected-scope and guarded replacement procedure.

## References

- [Skill entrypoint](../../../skills/planning/harness-doc/SKILL.md)
- [Authoring workflow](../../../skills/planning/harness-doc/references/workflow.md)
- [Page template](../../../skills/planning/harness-doc/references/doc-set.md)
- [Current project plan](../2026-09-15-harness-command-and-record-contracts.md#documentation-authoring)