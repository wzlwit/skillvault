# ADR: Harness Topic Consolidation

- Date: 2026-10-07
- Status: Accepted; decision 3 amended later the same day (see [Amendment](#amendment-runtime-renamed-to-harness-runtime)), and decision 5 superseded by the [old-name retirement ADR](./2026-10-07-retire-old-names-adr.md)
- Decision owner: Zhaolong Wang
- Scope: Which harness topics register as skills, their names, where their procedures live, and how old commands route.
- Supersedes: The per-topic registration of `harness`, `harness-task`, `harness-dev`, `harness-test`, `harness-link`, `harness-policy`, `harness-doc`, `harness-comms`, and `harness-report` in the [topic refactor plan](../2026-09-16-topic-skill-refactor.md) and the topic names in the [documentation](./2026-09-26-harness-documentation-adr.md), [communications](./2026-09-29-harness-communications-adr.md), [report authoring](./2026-09-15-harness-report-authoring-adr.md), and [review panel and sprints](./2026-10-02-review-panel-dev-loop-and-sprints-adr.md) ADRs. Their behavior decisions stand.

## Context

The owner found thirteen `/hn-` topics too many. They exposed 51 actions, and their descriptions made
up about a third of the skill-description text loaded into every chat. Several pairs overlapped
(task and dev, test and review and monitor, doc and comms and report), and the owner's own questions
were about those boundaries.

Two findings shaped the choice:

- **Topic choice is the weak step, not action choice.** Once a topic loads, its action table and the
  3-4 letter shortcut pick the action reliably. Picking the topic depends on what the agent can see. In
  the owner's VS Code chat, the skill list showed descriptions for 33 of 59 skills, user skills last;
  only 3 of the 13 harness topics had descriptions, and the other 10 appeared by name only. Names
  therefore carry most of the routing, and a broad name hides actions merged into it.
- **The runtime path must not move.** The live heartbeat runs the installed
  `harness-timer/scripts/harness-heartbeat.ps1`, which loads `../../harness/scripts`, and `pr-review`
  does the same. The live scheduler registry held no jobs that name a topic.

The owner first chose five topics, asked whether the agent would still pick actions reliably, then
chose seven with the suggested names, and kept full `harness-*` names in the `/` menu with `/hn-*` as
the typed shorthand.

## Decision

1. **Seven topics.** Merge the steps of one flow, setup, and drafting; keep standalone intents separate:

   | Topic | Actions | Takes over |
   | --- | --- | --- |
   | `harness-project` | list, root, init, migrate, context, clean, link, policy | the `harness` topic, `harness-link`, `harness-policy` |
   | `harness-work` | list, add, update, run, queue, sprint, test | `harness-task`, `harness-dev`, `harness-test` |
   | `harness-write` | list, upsert doc, tracker, meeting, email, or report, slots | `harness-doc`, `harness-comms`, `harness-report` |
   | `harness-review`, `harness-decision`, `harness-monitor`, `harness-timer` | unchanged | none |

2. **Groups.** `link`, `policy`, and `test` take a verb. Without one they list (read-only); with one they
   act. The 3-4 letter shortcut also selects a verb inside a group.
   *Amended 2026-10-07:* `harness-work` merged `add` and `update` into `upsert`, and `harness-project`
   merged `link` into `context`: bare `context` shows the briefing with the registered sources, and
   `context add|remove` keeps the one source registry. `link`, `add`, and `update` remain aliases.
3. **Hidden runtime.** The `harness` folder keeps the scripts, the runtime guide, and the review model
   list, with `user-invocable: false` and `disable-model-invocation: true`. Script paths, runtime
   interfaces, and ownership stay where they were. Topic procedures moved into the topics; a topic
   names the runtime guide by path instead of linking across bundles.
4. **Names.** Registered names stay full (`harness-*`); `/hn-*` stays conversational shorthand with an
   exact suffix match, so `/hn-<x>` always means `/harness-<x>`.
5. **Old commands.** `/harness`, `/hn`, and every retired topic name, including earlier legacy names,
   route as text to the matching new action. Each new topic lists the names it accepts.
6. **No data change.** Runtime action names, saved state, boards, schedules, permissions, and approvals
   are unchanged. Behavior from the superseded registrations carries over unchanged into the merged
   topics.

## Consequences

- The `/` menu shows seven harness topics instead of thirteen, and visible description text drops by
  about a quarter (4,910 to 3,656 characters). Merged topics carry longer `SKILL.md` routers; per-group
  detail stays in reference files.
- Installing `harness-runtime` alone gives only the runtime. Install `harness-project` for setup
  commands; it depends on the runtime.
- `harness-write` depends on `harness-work` and `harness-project` because report authoring did, so
  installing it brings the harness suite even for doc or email use.
- External guides and references that name a retired topic (`ppt-master`, `office-documents`,
  `humanizer-ch`) keep their text until the owner approves an update; their old names route to
  `harness-write`.
- Pins to retired topics still resolve through their existing tags. Installed copies move through the
  installer's former-name mapping and `update --topics`, with preview and approval.
- Typed `/hn-*` stays text the agent interprets; the full-name menu entries load a skill directly.

## Alternatives Considered

- **Five topics** (also review into work and decisions into project): fewest menu entries, but the
  broad names hide decisions and review when only names are visible, and `/hn-review` and
  `/hn-decision`, used on their own, would become legacy routes.
- **Hide only** (`user-invocable: false` on seven topics): fewer menu entries, but every description
  still loads and the overlapping boundaries remain.
- **Register `hn-*` names:** typed commands would become exact slash commands, but the names are
  cryptic when only names are visible, every folder and the live heartbeat path would move, and it
  reverses the earlier full-name decision.

## Implementation and Validation

Source moves keep reference content and rename only command text and links; installed-copy migration
uses the existing former-name mapping. The topic map, contract tests, and installer fixture cover the
seven topics, the hidden runtime, and the mappings.

## Amendment: Runtime Renamed to harness-runtime

Later on 2026-10-07 the owner saw the `skills/planning/harness` folder and asked why an old name
remained. Decision 3 is amended: the hidden runtime bundle is renamed `harness-runtime`, so no skill
or folder keeps the old base name `harness`. Everything else in decision 3 stands: the bundle stays
hidden, holds the same scripts, guide, and model list, and keeps its runtime interfaces and ownership.

Moving the path is safe because the heartbeat's scheduled command runs `harness-timer`'s own script,
whose path does not change; the sibling runtime path is updated in `harness-timer`, `pr-review`, and
every topic in the same installed-copy migration, and no saved scheduler job stored a runtime path.
The installer's former-name map sends an installed `harness` folder to `harness-project`, whose
dependency installs `harness-runtime`, so an older copy of the old topic gets both its replacement
and the runtime. Old `/harness` and `/hn` commands were later retired by the
[old-name retirement ADR](./2026-10-07-retire-old-names-adr.md).

## References

- [Project topic](../../../skills/planning/harness-project/SKILL.md)
- [Work topic](../../../skills/planning/harness-work/SKILL.md)
- [Writing topic](../../../skills/planning/harness-write/SKILL.md)
- [Runtime guide](../../../skills/planning/harness-runtime/references/runtime.md)
- [Topic refactor plan](../2026-09-16-topic-skill-refactor.md)
