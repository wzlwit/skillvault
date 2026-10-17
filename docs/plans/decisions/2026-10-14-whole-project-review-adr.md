# ADR: Whole-Project Review

- Date: 2026-10-14
- Status: Accepted. On 2026-10-12 the owner asked to grill the whole project. The agent audited the
  menu skills, documents and architecture decision records (ADRs), scripts, and catalog, fixed the clear defects, and put ten
  questions with recommended answers. On 2026-10-14 the owner answered "all recomm", choosing every
  recommended answer. That evening a second round put five follow-up questions, and the owner again
  chose every recommendation; see [Round 2](#round-2). On 2026-10-15 a third round settled the rest of
  the standing intake design and moved DAS to the built-in monitors; see [Round 3](#round-3).
- Decision owner: Zhaolong Wang
- Scope: Releasing the convention work, ADRs accepted by delegation, the last command options, stopped
  ownership claims, where review records live and which names history keeps, legacy harness
  controllers in the owner's projects, grilling under Autopilot, and two items left as they are. Round
  2 covers the standing intake review, the DAS adapter, writers and stopped readers, a leftover PACS
  script, and committing round 1. Round 3 covers standing intake decisions 11 and 12, DAS, and when to
  commit round 2.
- Supersedes in part:
  - decision 4 of the [concise commands ADR](./2026-10-08-concise-commands-adr.md), for the options it
    still kept;
  - decision 4 of the [shared ownership ADR](./2026-09-23-shared-ownership-adr.md), for stopped claims
    that hold only reads;
  - the 2026-10-07 amendment to decision 3 of the [old-name retirement ADR](./2026-10-07-retire-old-names-adr.md),
    for later renames.

## Context

The [bare, text, and menu convention](./2026-10-09-bare-text-menu-convention-adr.md) was implemented
and validated but not committed: 188 changes, with 17 skills at unreleased versions. The audits also
found:

- two ADRs still marked "accepted by delegation; owner review pending", plus the standing intake ADR;
- nine options that the concise-commands rule still kept: `--worker`, `--every`, `--hold`,
  `--repo-ref`, `--follow-up`, `--task`, `--new`, `--reuse`, and `--instance`;
- an open defect: a claim left by a stopped reader, such as an interrupted heartbeat, made later runs
  return `NeedsRecovery` until the owner cleared it, although a reader changes nothing;
- review records in a top-level `review/` folder, outside the `docs/` root;
- a 2026-10-07 amendment that rewrote old names inside history records, so every rename edited them;
- three legacy controllers in the owner's projects: DaaP on layout 1; DAS on layout 1 with a custom
  adapter that writes the old state and observation paths; and PACS, whose `.harness` is a junction
  into the D365 controller and holds two review scripts that nothing runs;
- grilling under Autopilot, where questions are answered automatically, so a round could look
  answered without the owner;
- the Bash bootstrap installing the Windows-only `schedule-manage`, and `/harness-review list` having
  no script of its own.

## Decision

1. **Release.** Commit the convention work as one commit, tag each changed skill's version with an
   annotated tag (17 tags), and push them together. Done as `1b8ebeb` after a full test run.
2. **Delegated ADRs.** The [review levels](./2026-10-08-review-levels-adr.md) and
   [real tests](./2026-10-08-real-tests-in-development-loop-adr.md) ADRs are confirmed. The
   [standing intake ADR](./2026-10-08-monitor-standing-intake-adr.md) stays pending for a walk-through
   in the next round.
3. **Plain words for the last options.** `worker <flow>` and `every <duration>` after `auto <name>`;
   `hold`; naming the `R-*` repository reference; `follow-up of <id>`; `for <id>` in a test run; and
   `as new <name>`, `reuse`, and `instance <name>` for schedules. Each maps to the same script
   parameter as before. `--apply` stays a compatibility answer that menus and examples never show.
4. **Stopped read-only claims.** Reads leave nothing partial, so a later reader passes a stopped claim
   that holds only reads and removes it. A stopped claim that holds a write stays as recovery evidence:
   a reader that meets its write, and any writer, still gets `NeedsRecovery` until the owner confirms
   the worker stopped.
5. **Review records.** `review/` moves to `docs/reviews/`, beside the decisions and evaluations.
6. **History keeps its names.** ADRs, evaluations, and review records keep the skill and command names
   they were written with; a rename fixes only their links. Plans and guides name the current topics.
   The [prefix-matching ADR](./2026-09-23-topic-action-prefix-matching-adr.md) is the exception,
   because a contract test checks its examples against the current menus.
7. **Legacy controllers.** Convert DaaP to layout 2 now. DAS waits, because its adapter would keep
   writing the old paths; the next round decides whether built-in Azure DevOps (ADO) and folder monitors replace it
   before conversion. PACS keeps its shared layout, and its two unused review scripts are deleted.
8. **Grilling under Autopilot.** When answers cannot come back during the turn, the grilling wrapper
   shows the round in the final reply and stops. Recommendations are never taken as the user's answers.
9. **Bash bootstrap.** It keeps installing `schedule-manage` on every platform. Both bootstrap
   installers read one `bootstrap-skills.json`, and a per-platform rule for one skill costs more than
   an unused folder.
10. **`/harness-review list`.** It keeps no script: the agent reads past results from the board's run
    history and linked reports.

## Alternatives Not Chosen

- **Commit without tags, or after more work.** Pins install from tags, so untagged versions cannot be
  pinned, and waiting kept a large change set uncommitted.
- **Keep the nine options.** Decision 4 of the concise-commands ADR kept them because each carries an
  input or a hold, but plain words carry the same input and match every other command.
- **Expire stopped claims by age.** Age cannot prove a worker stopped. A stopped read is safe to pass
  because it left nothing behind, not because time passed.
- **Let writers clear stopped read-only claims too.** Left for the next round; until then an installer
  or refresh that meets one still asks for recovery.
- **Keep `review/` at the root.** It is a second documentation root beside `docs/`.
- **Rename old names inside history records.** Each rename rewrote dozens of records and erased what
  they said when written.
- **Convert all three controllers now.** DAS's adapter would keep writing old paths after conversion,
  and PACS's junction is a deliberate shared layout.
- **Take the recommendations after a timeout under Autopilot.** Ask Once's no-answer default suits
  saving a declaration, not design decisions.

## Consequences

- Removing the options is a major change: `harness-dev` and `harness-monitor` 4.0.0 and
  `harness-schedule` 5.0.0. The ownership change and the link fix below are patches: `skillvault-install`
  and `harness-runtime` 4.0.1. The grilling adaptation keeps no version of its own.
- Applying decision 7 found a defect. OneDrive folders carry the reparse-point attribute, and ownership
  and Root moves treated every reparse point as a link, so the DaaP conversion was refused. Only
  symbolic links and junctions count as links now, as elsewhere in the runtime, and real junctions are
  still refused. A fixture mocks a cloud-style folder; the live DaaP path was checked read-only.
- `test-skill-files.mjs` flags the nine options in command examples and treats `docs/reviews/` as
  history.
- The standing intake ADR and the DAS controller are unchanged until the next round.

## Open Questions After Round 1

- Walk through the standing intake ADR's delegated choices: generic `auto` intake, worker flows,
  environment handoff, retries and exit codes, automatic monitor timers, generic health sources, and
  staged AI follow-up workers.
- DAS: replace its custom adapter with built-in ADO and folder monitors, then convert it.
- Should writers, such as installers and refresh, also pass and remove stopped read-only claims?
  Recommended yes, because a stopped read leaves nothing partial.

Round 2 confirmed decisions 1-10 of the first and settled the other two.

## Round 2

On the evening of 2026-10-14 the owner chose every recommendation for five follow-up questions:

1. **Standing intake.** Decisions 1-10 of the [standing intake ADR](./2026-10-08-monitor-standing-intake-adr.md)
   are confirmed. Decisions 11 and 12, the `auto` action and generic sources with staged workers, get
   their own walk-through.
2. **DAS stays as it is for now.** A read-only comparison found that the built-in monitors replace its
   adapter only in part. They need a saved ADO query and a token for its exact ADO selection, and they
   turn its fixed filters into categories that the AI assigns. By design they never create, complete,
   mark stale, or reopen tasks on their own, or infer risk or repositories, all of which the adapter
   does. Its two hand-written concerns would need a reviewed feed. The adapter runs only when started
   by hand and last ran on 2026-09-25; layout 1 stays supported.
3. **Writers and stopped readers.** Installers and refresh now also pass a stopped claim that held only
   reads and remove it. A stopped claim that held a write still needs recovery.
4. **PACS.** Its last unused review script, `review-report.ps1`, is deleted after a backup; nothing
   referred to it.
5. **Round 1 is committed** as `2375dac` with five tags.

Consequences:

- `skillvault-install` 4.0.2 for the ownership change.
- The DAS comparison found a runtime defect. The board check grouped source types regardless of case
  but counted each group case-sensitively, so a state holding both `ADO` (written by the adapter) and
  `ado` (from a built-in monitor) failed every board update after the state was saved. Grouping now
  matches the count: `harness-runtime` 4.0.2, with a regression test.

## Open Questions After Round 2

- Walk through decisions 11 and 12 of the standing intake ADR.
- DAS: leave it as it is, move it to built-in monitors, or turn its adapter into a feed producer.

Round 3 answered both.

## Round 3

On 2026-10-15 the owner answered five more questions:

1. **Decision 11 is confirmed:** `auto` stays in `harness-monitor` as built.
2. **Decision 12 is confirmed:** health monitors take the same intake, and a worker can be any declared
   local-only flow.
3. **The built-in AI follow-up worker stays a later step**, designed when a source needs it.
4. **DAS moves to the built-in monitors now**, against the recommendation to leave it until the owner
   next works on it:
   - It is converted to layout 2 with its 46 tasks, project identity, and 33 reports unchanged.
   - The three health monitors that only watched the adapter's output are removed. The 19 tasks the
     adapter created stay as manual tasks.
   - A `das-design-concerns` folder monitor over R-008 is saved without a timer. Its prefilter is the
     adapter's ADO words plus `PBI`, `PACS`, `DaaP`, `DPC`, `MEF`, and `UCC`; security-compliance and operations
     work are excluded, and reporting and real-time work stay at priority 4 or lower.
   - At the owner's request, the adapter, its observation files, and three old state snapshots are
     deleted after a backup.
   - An ADO monitor for the focused backlog follows once the owner saves its query in ADO.
5. **The owner reviews round 2 before it is committed.**

The round-2 board fix matters here. DAS's adapter tasks store `ADO` and `Design`, and the first
built-in candidate adds a lowercase source type beside them, which broke every board update before
that fix.

A follow-up the same day: a session working on the owner's incident project had found that a job deferred behind a running
job in the same project waited for the 30-minute active-worker recheck, so two schedules in one
project took turns at half speed, and it had patched the installed scheduler to recheck every 2
minutes. The owner chose to adopt the fix in the source, tightened to jobs that wait only behind a
running job: those are rechecked every 2 minutes while it runs, and jobs deferred as unhealthy or
behind an unavailable project keep the fallback recheck. `harness-schedule` 5.0.1 has fixture cases
for both, and the installed copy is replaced from the source.

## Open Items

None. The last one closed the same day: at the owner's request, the agent saved the focused DAS query
as a private query in the owner's ADO account and saved the `das-focused-backlog` ADO monitor from it,
without a timer. Its checks read an ADO token from the session, never from saved files.

## References

- [Bare, text, and menu convention ADR](./2026-10-09-bare-text-menu-convention-adr.md)
- [Concise commands ADR](./2026-10-08-concise-commands-adr.md)
- [Shared ownership ADR](./2026-09-23-shared-ownership-adr.md)
- [Old-name retirement ADR](./2026-10-07-retire-old-names-adr.md)
- [Ownership helper](../../../skills/core/skillvault-install/scripts/skill-ownership.ps1)
- [Grilling adaptation](../../../skills/planning/grilling/SKILL.md)
