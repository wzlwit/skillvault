# ADR: Bare, Text, and Menu Convention

- Date: 2026-10-09
- Status: Accepted and implemented. The owner proposed the convention and chose every decision below in a
  topic-by-topic walk-through on 2026-10-09, then asked for the implementation the same night.
- Decision owner: Zhaolong Wang
- Scope: What a bare command, the text after it, and the menu do in SkillVault's own multi-action
  skills; five renames; the review-level name; and install selectors.
- Supersedes in part:
  - decisions 1-3 of the [verb-named topics ADR](./2026-10-09-verb-named-topics-adr.md): a verb topic
    no longer always runs its verb when bare, lists it first, or defaults its action input to it.
    Its SkillVault renames (decisions 4-5) stand; their menus change here;
  - the topic names and group shapes in decisions 1-2 of the
    [harness topic consolidation ADR](./2026-10-07-harness-topic-consolidation-adr.md);
  - decision 2 of the [old-name retirement ADR](./2026-10-07-retire-old-names-adr.md) (action aliases
    stay), and its retirement of `harness-dev`, `harness-decide`, `/hn-dev`, and `/hn-decide`, which
    return as current names;
  - the kept options `--broad`, `--repo`, and `--exact` and the `harness-write` inputs in decision 4 of
    the [concise commands ADR](./2026-10-08-concise-commands-adr.md);
  - the level name `critical` in the [review levels ADR](./2026-10-08-review-levels-adr.md) and its
    decision 4 rule that development always reviews at that level, and the same level name in decision 7
    of the [real-tests ADR](./2026-10-08-real-tests-in-development-loop-adr.md);
  - the action sets of the three topics in the
    [SkillVault topic consolidation ADR](./2026-10-07-skillvault-topic-consolidation-adr.md).

## Context

After the verb-named topics change, the owner proposed one convention for all their skills: harness
topics named `/hn-<verb of the leading action>`, a bare command that runs a specific action, text after
the skill (without an action word) that does a special job, and descriptions that list only the other
actions. The 16 skills with menus offered 63 menu entries, counting `list`. Many actions repeated what
plain text could say (`run`, `context`, `declare`, `record`, `upsert`, `search`), a dozen aliases
duplicated them, and some menu words did not say what text did: `context` was described as "show
briefing or remove source" while text added sources. A bare `/harness-review` acted at once, but a bare
`/harness-work` only listed, with no rule saying which to expect. The level name `critical` read like a
severity, although it means "blocks merging the change or finishing its task".

## Decision

1. **Bare.** A bare command acts at once only on a fixed target: `/harness-review` reviews the current
   changes, `/pr-review` the watched PRs, and `/pr-publish` the current branch's PR, because typing the
   command is the request. Every other bare command shows where things stand and offers the next step,
   asking once; without an answer nothing changes. A bare command that would act on a target guessed
   from the conversation (`harness-write`, `skillvault-author`) says what it would do and asks first.
   Each bare view ends with one line naming the text uses.
2. **Text.** Anything after the skill that is not a menu word does the skill's special job (decision 5).
   A menu word counts only when the rest of the text fits that action; otherwise the agent asks. Plain
   words replace the removed options: `--broad` becomes a menu action, `--repo` and the `harness-write`
   options become plain words, `--exact` gives way to decision 8, and `clean --policy` becomes
   `policy set retention <file>`.
3. **Menu.** The menu lists only the other actions. A skill left with nothing else keeps one or two
   quick-navigation words for its most important view or action, even though text also reaches it:
   `closed` and `all` in `harness-decide`, `remove` in `pr-watch`, and `investigate` in `dri`. This is
   a refactor, so old words go: actions that bare or text now cover, and the aliases `loc`, `link`,
   `now`, `next`, `add`, `update`, `create`, `modify`, `record`, `eval`, `expl`, `catalog`, `preview`,
   `task`, `public`, `remove` and `uninstall` (for `delete`), and the `/rules core` shortcut. The
   installer's former-name map still lists old skill folder names so installed copies are replaced, not
   duplicated; users never type them.
4. **Description and hint.** A description starts with the menu words in brackets, then two labels:
   `Alone:` says what the skill does by itself and `Text:` what it does with the user's own words, as
   in `[broad|list] Alone: review your changes. Text: review that scope.` Every skill has a menu
   (decision 3), so every description starts with a bracket. Brackets hold only words the user types.
   A noun after `Alone:` means the skill shows something, and a verb means it acts. This lead fits in
   the first 80 characters, the part the `/` picker shows (75 at most across the 16 skills), and the
   purpose and overlap notes follow it. The
   `argument-hint`, shown in the chat input after the skill is picked, keeps the two kinds apart:
   menu words first, then the kind of text, as in `[broad|list] [<scope>]` or `[closed|all] [<question or ID>]`.
5. **Each skill.**

   | Skill (shorthand) | Bare | Text | Menu |
   | --- | --- | --- | --- |
   | `harness-setup` (`/hn-setup`), was `harness-project` | Brings the harness up to date: creates it or converts an old layout after one question; otherwise shows status | Adds a link, file, folder, or repository as a source; a task ID shows its briefing; a question is answered from the briefing; `remove R-<n>` unregisters a source after confirmation | `root`, `clean`, `policy` |
   | `harness-dev` (`/hn-dev`), was `harness-work` | Shows the board and, when idle with a ready task, offers to start the next one | Develops a task ID or a plain request (recorded first), starting it or queuing it when busy; `<id> now` asks the running task to yield at its next checkpoint | `upsert`, `queue`, `sprint`, `test`, `broad` |
   | `harness-decide` (`/hn-decide`), was `harness-decision` | Shows open decisions and offers to go through them | Explains an ID, question, or statement, then asks for the choice (decision 9); an ID with a choice is saved at once | `closed` (the five most recently decided items, or the number given), `all` (open and recently decided items, plus the setup checklist) |
   | `harness-schedule` (`/hn-schedule`), was `harness-timer` | Shows every schedule and offers to convert an old SkillVault Windows task | `<target> <duration>` sets; `<target> off` or `on` disables or resumes; a target alone shows it; `maintenance` uses its fixed window | `clean` |
   | `harness-monitor` (`/hn-monitor`) | Shows monitors with their last results and offers to check all | A monitor name checks it; a link, folder, or file starts monitoring it; a name with a change updates it after one question | `accept`, `auto` |
   | `harness-write` (`/hn-write`) | Confirms a target clear from the conversation; otherwise shows drafts and asks what to write | What to write, with kind, audience, location, thread, and time in plain words; drafts only | `slots` |
   | `harness-review` (`/hn-review`) | Reviews the current changes at `blocking` | A folder, file, commit range, task ID, or "security"; a PR URL goes to `pr-review` | `broad`, `list` |
   | `pr-review` | Reviews the watched PRs that changed | Reviews a PR or repository URL without watching it; "again", "drafts", "security", or a count adjust the run | `broad`, `list`, `configure` |
   | `pr-watch` | Shows the watchlist | Watches a URL at once, with count and drafts in plain words | `remove` (a W- ID or URL, after confirmation) |
   | `pr-publish` | Publishes the branch's PR | "show me first", "push", "as draft", "rewrite the description", or a PR URL or number | `list` |
   | `skillvault-install` (`/sv-install`) | Shows the catalog with each skill's state here and offers to update copies behind the checkout | Installs by selector (decision 8), with "global", "project", "session", "origin", or a version | `list`, `update`, `uninstall`, `clean`, `refresh` |
   | `skillvault-discover` (`/sv-discover`) | Shows past evaluations and asks what to look for | A purpose searches, then offers to evaluate the best match; a URL or skill name is evaluated and recorded unless "chat only" | `explain` |
   | `skillvault-author` (`/sv-author`) | Confirms a target clear from the conversation; otherwise shows the checkout's catalog and asks | What to create or change; "from this session", "from <document>", or "in <checkout>" | `remove` |
   | `rules` | Shows the rules and where they apply, offering to apply them when the global copy is missing or out of date | Adds or changes the user's own rule after confirmation | `apply`, `remove` |
   | `schedule-manage`, was `schedule-manager` | Lists Windows scheduled tasks, numbered | A keyword or number filters the list | `enable`, `disable`, `delete` |
   | `dri` | Shows the DRI profile's status and asks which incident | Investigates an incident ID or link, read-only | `investigate` |

6. **Names.** Multi-word skill names end in their main verb; single-word names such as `rules` and `dri`
   stay. Registered names stay full; `/hn-*` and `/sv-*` remain chat shorthand. The renames are in the
   table above.
7. **`clean` and levels.** `clean` means the same in the three skills that have it: remove stale things
   the skill owns, after showing them and asking once (old run history, stale schedules, and installed
   copies that load twice, conflict, or cannot load). The review level `critical` is renamed `blocking`
   for reviews, PR reviews, and unit tests. Saved values and earlier run records that say `critical` are
   read as `blocking`, and `runner.criticalReview` gets a name that says it controls the second reviewer,
   with the old key still read. `/hn-dev broad [<task>]` runs that task's reviews at `broad`, fixing
   minor and existing issues in its code while findings outside the task stay follow-up proposals, and
   has the developer add broad unit tests. Bare and text stay at `blocking`.
8. **Install selectors.** A name without `*` matches one skill exactly, ignoring case; `name*`, `*name`,
   and `*name*` match by start, end, or contents, and `*` alone selects all. An exact name installs that
   skill and what it needs at once; a partial match shows its matches and asks once. No exact match
   installs nothing and suggests skills whose descriptions match. `uninstall` uses the same rule, plus
   the numbers from `list`. This replaces substring matching with a description fallback, `--exact`, and
   `public`.
9. **Decisions can stay open.** Every `/hn-decide` text is explained and then put to the owner, with
   "Leave it open" among the choices. A new question left open is saved as Open, which needs a small
   script change: today a decision can only be saved with its choice. Without an answer nothing is saved.
10. **Approvals stay.** Ask Once, menu-word prefix matching, limits, pauses, and remote-write rules are
   unchanged. Folding an action into bare or text adds or removes no approval.

The agent stated two follow-ons that the owner did not object to: `uninstall` shares the selector rule,
and a selector with no exact match suggests description matches.

## Alternatives Not Chosen

- **Keep compatibility aliases for a release.** The owner: "it's kind of refactoring, no need to keep old
  words".
- **Bare always runs the verb**, as the verb-named topics ADR had it. Starting development or checks
  spends credits and may pick the wrong item, and looking first is the common case; offering keeps it
  one answer away.
- **Every acting bare asks first.** One uniform rule, but it reverses the review and publish habits the
  owner set the same day, where the target is fixed and typing the command is the request.
- **Keep `context`, `list`, `explain`, `check`, or `disable` and `resume` in menus.** Text covers them.
  The owner briefly asked to keep `disable` and `resume` for quick navigation, then chose `off` and `on`.
- **`/hn-test` as its own topic.** It keeps menus flat but adds a topic, and development depends on the
  test declarations.
- **Merge `pr-watch` into `pr-review`.** Its menu would grow to five, and `list` would mix review results
  with the watchlist.
- **`prune` instead of `clean`.** Clearer alone, but it breaks the shared meaning across three skills.
- **Keep `harness-work` and `harness-timer`, or rename `rules` and `dri` to verbs.** The verb names say
  what the harness skills do; `rules-apply` and `dri-investigate` are long for skills typed often.
- **`broad` in development for reviews only**, with unit tests following the project setting. One word
  should mean thorough for the whole task, and the unit-test level already guides both the developer
  and the reviewers.
- **One bracket for text and menu words**, such as `[<decision>|explain]`. It mixes words the user types
  with the user's own words and never says what the bare command does.
- **Labels in the hint only**, keeping descriptions as `[menu] purpose`. The meanings would appear only
  after the skill is picked, and long hints may be cut off in a narrow chat panel.
- **`Bare:` as the label.** It is the owner's working term, but `Alone:` is plain English for readers of
  the public catalog.
- **No menu for `harness-decide`, `pr-watch`, and `dri`.** Their important views and actions would be
  named only on the bare view's last line; the owner asked for one or two quick-navigation words.
- **`proposal` as the word for `dri`.** The DRI-agent design document matters while that design grows,
  not to someone on call.

## Consequences

- Menu entries across the 16 skills fall from 63 to 34. The five renames, removed inputs, and new
  defaults are major changes: `harness-setup` and `harness-dev` 3.0.0, `harness-decide` and
  `harness-schedule` 4.0.0, `harness-monitor` 3.0.0, `pr-watch` and `rules` 4.0.0, `schedule-manage` and
  `dri` 2.0.0, and `harness-runtime` 4.0.0. `harness-write`, `harness-review`, `pr-review`, `pr-publish`,
  and the three SkillVault topics already carry an unreleased major version from the verb-named topics
  change, which covers this one. The second-reviewer switch is named `runner.secondReviewer`, and the
  runtime's `review-levels` interface moves to 2, which `harness-review`, `pr-review`, and `harness-dev`
  require.
- Installed copies of renamed skills switch through the installer's topic-layout migration. The
  heartbeat Windows task runs a script inside the timer skill's folder, so the switch re-registers it
  for `harness-schedule` in the same step. Copies blocked by another project's ownership claims wait
  for that project's owner.
- Project instructions that name old commands need updating: one line in DAS. Other projects' owners
  update their own.
- Implementation also covers `AGENTS.md`, the README, the [current harness plan](../2026-09-15-harness-command-and-record-contracts.md),
  the runtime guide, the contract tests, and the description validator. The validator's rule changes:
  the description's bracket must equal the hint's menu group, `list` and one-word menus included, and
  `Alone:` and `Text:` must follow it.
- Text routing relies on the agent telling a menu word from text. A rare collision, such as
  `/hn-dev test the login flow`, follows decision 2 and asks when unclear.

## References

- [Verb-named topics ADR](./2026-10-09-verb-named-topics-adr.md)
- [Concise commands ADR](./2026-10-08-concise-commands-adr.md)
- [Ask Once ADR](./2026-10-08-ask-once-adr.md)
- [Review levels ADR](./2026-10-08-review-levels-adr.md)
- [Topic action prefix matching ADR](./2026-09-23-topic-action-prefix-matching-adr.md)
