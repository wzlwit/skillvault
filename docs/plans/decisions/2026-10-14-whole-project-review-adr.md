# ADR: Whole-Project Review, Round 1

- Date: 2026-10-14
- Status: Accepted. On 2026-10-12 the owner asked to grill the whole project. The agent audited the
  menu skills, documents and ADRs, scripts, and catalog, fixed the clear defects, and put ten
  questions with recommended answers. On 2026-10-14 the owner answered "all recomm", choosing every
  recommended answer.
- Decision owner: Zhaolong Wang
- Scope: Releasing the convention work, ADRs accepted by delegation, the last command options, stopped
  ownership claims, where review records live and which names history keeps, legacy harness
  controllers in the owner's projects, grilling under Autopilot, and two items left as they are.
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
   writing the old paths; the next round decides whether built-in ADO and folder monitors replace it
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

## Open Questions for the Next Round

- Walk through the standing intake ADR's delegated choices: generic `auto` intake, worker flows,
  environment handoff, retries and exit codes, automatic monitor timers, generic health sources, and
  staged AI follow-up workers.
- DAS: replace its custom adapter with built-in ADO and folder monitors, then convert it.
- Should writers, such as installers and refresh, also pass and remove stopped read-only claims?
  Recommended yes, because a stopped read leaves nothing partial.

## References

- [Bare, text, and menu convention ADR](./2026-10-09-bare-text-menu-convention-adr.md)
- [Concise commands ADR](./2026-10-08-concise-commands-adr.md)
- [Shared ownership ADR](./2026-09-23-shared-ownership-adr.md)
- [Old-name retirement ADR](./2026-10-07-retire-old-names-adr.md)
- [Ownership helper](../../../skills/core/skillvault-install/scripts/skill-ownership.ps1)
- [Grilling adaptation](../../../skills/planning/grilling/SKILL.md)
