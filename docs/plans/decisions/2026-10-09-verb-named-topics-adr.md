# ADR: Topics Named for a Verb Run It When Bare

- Date: 2026-10-09
- Status: Accepted. The owner decided that `/pr-publish` publishes by default, "since the skill name
  ends with a verb", and asked to check the other skills with the same pattern. The agent asked which
  ones should follow; the owner was not available, so the agent adopted its recommended answer for
  `harness-review`, `pr-review`, and `harness-write` (decision 2). The owner then proposed the
  SkillVault renames in decisions 4 and 5; for decision 5 the agent asked how and was again not
  answered, so it adopted its recommended answers.
- Superseded in part 2026-10-09: decisions 1-3 give way to the [bare, text, and menu convention ADR](./2026-10-09-bare-text-menu-convention-adr.md),
  where only bare commands with a fixed target act at once and menus list only the other actions.
  Decisions 4-5 stand; their menus change there.
- Decision owner: Zhaolong Wang
- Scope: What a bare multi-action topic does, its menu order, and the rules in AGENTS.md.
- Supersedes in part: the AGENTS.md rule that every bare multi-action topic shows a read-only `list`;
  the names `skillvault-installation`, `skillvault-discovery`, and `skillvault-authoring` from the
  [SkillVault topic consolidation ADR](./2026-10-07-skillvault-topic-consolidation-adr.md), which also
  retired `/sv-install` as an old route that now returns as the new name's shorthand; and the
  retirement of `skillvault-install` in the [old-name retirement ADR](./2026-10-07-retire-old-names-adr.md).

## Context

Every multi-action topic showed a read-only `list` when invoked bare, so `/pr-publish` only reported
the branch and its PR, and `/harness-review` only showed earlier results. When a topic's name already
says what it does, typing the bare name is the request to do it, and a list makes the user type the
action again.

## Decision

1. **A topic named for a verb runs that verb when bare.** Its menu lists that action first, and its
   `skill.json` action input defaults to it. `list` stays available as an action. Topics whose names
   are nouns keep the read-only `list` default.
2. **Which topics.** `/pr-publish` runs `upsert`, which shows the local draft before it publishes.
   `/harness-review` and `/pr-review` run `run`; a bare `/pr-review` reviews the watched PRs that
   changed. `/harness-write` runs `upsert` and asks what to write when the kind isn't clear.
   `pr-watch`, `harness-work`, and `harness-monitor` keep `list`: their last word names the
   watchlist, the work, and a monitor, and a bare run would start development or check every source.
3. **Approvals stay.** A bare run is the same request as the named action, with the same questions,
   limits, and confirmations.
4. **`skillvault-installation` becomes `skillvault-install`** (owner request, the same day), so a bare
   `/skillvault-install` runs `install`, which browses the catalog when no skill is named and copies
   nothing; `list` shows installed skills. `/sv-install` is its shorthand. The installer's former-name
   map now retires copies named `skillvault-installation` and no longer retires `skillvault-install`.
   Installed copies switch as one set, the renamed skill with the skills that depend on it
   (`harness-runtime`, `harness-timer`, `pr-review`, `harness-project`, `skillvault-discover`, and
   `skillvault-author`), through the topic-layout migration; a mixed set stops with a request to
   install a compatible update set rather than running.
5. **`skillvault-discovery` becomes `skillvault-discover` and `skillvault-authoring` becomes
   `skillvault-author`**, so all three SkillVault topics are verbs. A bare `/skillvault-discover`
   runs `search` and lets the input decide: a purpose searches, while a URL or one skill's name goes
   to `evaluate`; input that could be either searches, since search saves nothing. `search` and
   `evaluate` stay separate actions because their results differ: a shortlist, or a verdict with a
   saved record. A bare `/skillvault-author` runs `upsert` and asks what to create or change. The
   shorthands are `/sv-discover` and `/sv-author`, and the longer names join the former-name map.

## Alternatives Not Chosen

- **Only `pr-publish`.** Not chosen: the owner asked for the pattern, and `review` and `write` name
  their actions just as `publish` does.
- **Keeping `pr-review` as a list**, because a bare run reviews every watched PR that changed. Not
  chosen: unchanged PRs are skipped, and saved limits still apply.
- **Merging `search` and `evaluate` into one action.** Not chosen: a shortlist and a saved verdict are
  different results, and letting the bare command pick by input already removes the need to name them.
- **Other names for authoring**: `skillvault-create` hides update and remove, `skillvault-edit` hides
  create, `skillvault-build` suggests compiling, and `skillvault-write` collides with `harness-write`.

## Consequences

- The defaults change, so `pr-publish` 3.0.0, `harness-review` 4.0.0, `pr-review` 3.0.0,
  `harness-write` 3.0.0, and `skillvault-install`, `skillvault-discover`, and `skillvault-author`
  4.0.0 carry this decision. Saved state needs no migration; installed copies of the renamed skills
  need the topic-layout migration.
- A bare `/harness-review` or `/pr-review` now starts reviewers and uses AI credits; `list` shows
  results without running anything.
