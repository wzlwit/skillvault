# ADR: Concise Commands

- Date: 2026-10-08
- Status: Accepted. The owner asked for no "fancy" flags, a simple default, and only the options that
  are needed, and for "concise" to be a rule of this repository. Which options went was the agent's
  recommendation, open to owner review; the owner was not available for the scope question.
- Superseded in part 2026-10-09: of the options kept in decision 4, `--broad` becomes a menu action,
  `--repo` and the `harness-write` inputs become plain words, and `--exact` gives way to exact-or-wildcard
  selectors; see the [bare, text, and menu convention ADR](./2026-10-09-bare-text-menu-convention-adr.md).
  The rule in decision 1 stands.
- Decision owner: Zhaolong Wang
- Scope: The options that users type for SkillVault's own skills, and how summaries describe them.

## Context

The skills had collected many options. Some named the default (`--critical`), some repeated an
action (`check all`), and many toggled something rare. A summary of `/pr-publish` also showed internal
helper steps and check names, which the owner read as new commands. An AI agent can turn a plain
request into the same script parameter, so most of these options add reading without adding power.

## Decision

1. **The rule.** Defaults cover the common case. An option exists only when neither a default nor a
   plain request can do its job, such as a required input, a safety hold, or a choice scheduled runs
   need. Script parameters, check codes, and helper steps stay out of menus, examples, and summaries.
   The rule is in `AGENTS.md` under Skill Rules.
2. **`/pr-publish` has no options.** `upsert` creates a ready PR or refreshes only the scenario table
   of an existing one. A draft, a ready PR, or a rewritten description is a plain request.
3. **Removed options**, each now a plain request that maps to the unchanged script parameter:

   | Skill | Removed |
   | --- | --- |
   | `harness-review`, `pr-review` | `--critical`, `--security` |
   | `pr-review`, `pr-watch` | `--again` (`pr-review` only), `--limit`, `--include-drafts` |
   | `harness-decision` | `--recent` |
   | `harness-monitor` | `--max`, `--attempts`, `--setup-exit`, and `check all` (same as `check`) |
   | `harness-timer` | `--all`, `clean --delete-stale`, `clean --retire` |
   | `harness-work` | `run --now` |
   | `harness-project` | `root --current-file`, `root --view` with `--monitors`, `init --current-file` |
   | `harness-write` | `--design-only` |
   | `skillvault-discovery` | `--chat-only` |
   | `skillvault-installation` | `update --topics` |

4. **Kept options** carry an input or a hold: `--worker`, `--every`, `--hold`, `--broad`, `--base`,
   `--repo-ref`, `--follow-up`, `--task`, `--new`/`--reuse`/`--instance`, `--repo`, `--exact`, and the
   inputs of `harness-write` and `jarvis-metrics`. `--apply` stays a compatibility answer, not a
   menu option. Action lists already have one outcome per action and needed no change.

## Consequences

- Fewer things to learn: users type the action and say anything unusual in plain words.
- Saved settings, scripts, timers, and tests keep working, because script parameters did not change.
- `differential-review` is an adapted outside skill; its wrapper still mentions `--security` and is
  left for the owner to change.
- Major versions: `harness-decision` 3.0.0, `harness-write` 2.0.0, `pr-watch` 3.0.0,
  `skillvault-discovery` 3.0.0, `skillvault-installation` 3.0.0, and `harness-project` 2.0.0. The
  unreleased majors of `pr-publish`, `pr-review`, `harness-review`, `harness-monitor`,
  `harness-timer`, and `harness-work` already cover their removals.
