# ADR: Second Whole-Project Review

- Date: 2026-10-20
- Status: Accepted. After the Power BI skills were released, the owner asked to grill the whole
  project again. The agent checked what had changed since the
  [first whole-project review](./2026-10-14-whole-project-review-adr.md) and put seven questions with
  recommended answers. The owner chose no license, no continuous integration (CI), manual Python
  tests, and keeping the committed project copies, and took the recommendations for the other three.
  The same evening a second round settled the license fields; see [Round 2](#round-2).
- Decision owner: Zhaolong Wang
- Scope: licensing, automated checks, the Power BI skills' Python tests, the installed copies committed
  in `.github/skills/`, the file overwrites seen on 2026-10-19, the size of `AGENTS.md`, and four small
  fixes.

## Context

- The repository has no LICENSE file. The native skills' `license` fields disagree: five say MIT, two
  say null, and fifteen have none. Adapted skills record their originals' licenses.
- Nothing runs on a push: there are no GitHub Actions workflows, and the full local suite takes about
  17 minutes.
- `test-all.ps1` doesn't run the 49 Python tests of `powerbi-test` and `powerbi-localize`.
- Eight installed project copies in `.github/skills/` are committed. They're identical to their
  sources and default to global availability, but none is installed globally.
- Twice on 2026-10-19, at 11:00 and 21:01, files went back to their state before a long-running chat
  first edited them: 13 files, then 9. Both times they were restored from the last commit. The likely
  cause is the editor discarding that chat's tracked edits; it isn't proven.
- `AGENTS.md` was 59 KB (685 lines) and loads into every chat in this repository. About 290 lines
  described harness behavior that the current plan, the ADRs, and the skills already document.
- Two SkillVault references over 100 lines had no contents line. The topic-refactor plan's Rollout
  Status recorded September's live schedule state. A review record showed a local path with the
  owner's user name. `package-lock.json` resolved its one package from a company npm feed.

## Decision

1. **No license.** The repository stays without a LICENSE file: the skills are public, but all rights
   are reserved. Adapted skills keep their originals' licenses, as those licenses require. What the
   native skills' `license` fields should say is an open item.
2. **No CI.** Every check keeps running locally.
3. **Python tests stay manual.** `test-all.ps1` doesn't run them. `AGENTS.md` says to run them when
   `powerbi-test` or `powerbi-localize` changes.
4. **The committed project copies stay.** `AGENTS.md` records that the eight copies are committed on
   purpose, so later reviews don't propose removing them.
5. **Overwrites.** The owner keeps the long chat's pending edits in the editor, and later SkillVault
   work starts in a fresh session from a handoff note, so no long-running chat holds tracked edits.
6. **A shorter `AGENTS.md`.** It keeps what every task needs: layout, documentation rules, catalog and
   skill rules, validation, and Git safety. Harness detail becomes links to the current plan, the
   ADRs, and the skills' guides. A rule found nowhere else moves into the current harness plan instead
   of being dropped. `README.md` waits for a later pass.
7. **Small fixes.**
   - `harness-dev`'s `dev.md` and `harness-write`'s `report-routes.md` get contents lines. The
     validator now requires a `Contents:` line before the first section of every SkillVault reference
     over 100 lines. Adapted skills are exempt, because their references come from the originals.
   - The topic-refactor plan's Rollout Status points to `/harness-schedule` and `/harness-setup` for
     live state instead of recording it.
   - The review record shows `~/.copilot/...` instead of the full local path.
   - `package-lock.json` resolves `yaml` 2.9.0 from the public npm registry with its published SHA-512
     hash. npm fetches it through a configured registry when one is set, so the same file installs
     both publicly and through a company feed.

## Alternatives Not Chosen

- **MIT or Apache-2.0 at the root.** Recommended MIT, so others could reuse the native skills; the
  owner chose to reserve all rights.
- **A small GitHub Actions workflow.** Recommended for contract tests, catalog validation, and the
  Python tests; the owner chose local checks only.
- **Python tests in `test-all.ps1`.** Recommended when Python is installed; the owner kept them manual.
- **Installing the eight copies globally and removing them.** Recommended to avoid two copies of each
  skill in the repository; the owner kept them.
- **Watching for overwrites, or a guard script.** A fresh session takes the long chat's tracked edits
  out of play, without new tooling.
- **Trimming `README.md` now.** Left for later.
- **Regenerating the lock file with npm.** This machine reaches the public registry only through the
  company feed, so npm would have recorded the feed's address again. The tarball from the feed matched
  the public registry's published SHA-512 hash, so the address and hash were set directly and checked
  with `npm ci`.

## Consequences

- `AGENTS.md` went from 59 KB (685 lines) to 23 KB (316 lines). Before a paragraph was removed, each
  of its rules was found in the current plan, an ADR, or a skill's guide; the one rule found nowhere
  else, that moving documentation never relocates harness storage, moved into the plan's
  [Plans and Records](../2026-09-15-harness-command-and-record-contracts.md#plans-and-records).
- `harness-dev` and `harness-write` change only in wording, so their versions stay; their installed
  copies are updated.
- `test-skill-files.mjs` covers the contents-line rule with a fixture.

## Round 2

With no license at the root, five native skills and two SkillVault guides still said MIT, fifteen
native skills had no `license` field, and the README and `AGENTS.md` called the skills "shareable".
On 2026-10-20 the owner chose to keep MIT on the five SkillVault skills:

- `rules`, `schedule-manage`, `skillvault-author`, `skillvault-discover`, and `skillvault-install`
  stay MIT on purpose. Others may reuse this tooling; readers check each skill's own terms.
- Every other native skill and SkillVault guide declares `license: null`. Fifteen native manifests
  gained the field; `graphify` and `awesome-gamedev-agent-skills` changed from MIT to null, and the
  latter dropped `license: MIT` from its `SKILL.md`. The new-skill template changed from MIT to null,
  so new skills don't inherit a license.
- The README and `AGENTS.md` keep "shareable", and the README's example manifest keeps MIT.
- License fields change no behavior, so no version changes; installed copies of the changed skills
  are updated.

Not chosen: `license: null` everywhere with "public" in place of "shareable", which was recommended
so that every file would match the repository's terms; and leaving the fields as they were.

## Open Items

- The five MIT skills carry the label but no license text. MIT's terms require the copyright notice
  and permission notice in copies, and none of the five folders bundles a LICENSE file. Add an MIT
  LICENSE file to each, and whom should its copyright notice name?
