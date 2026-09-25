# ADR: Topic Action Prefix Matching

- Date: 2026-09-23
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: Conversational action routing for existing multi-action SkillVault topics
- Supersedes: Discovery's exact-alias-only restriction; existing aliases retain their meanings

## Context

The [topic plan](../2026-09-16-topic-skill-refactor.md) retains full registered skill names,
canonical action menus, and read-only bare invocation. Compatibility spellings are text routes,
not separate skills. The [accepted work-contract ADR](./2026-09-18-upsert-and-harness-work-contracts-adr.md)
also preserves existing action aliases, ownership, and approval boundaries.

The owner approved and requested implementation of discovery tuning on 2026-09-22: exact
`eval`/`expl` aliases, separate standalone-use/skill/integration recommendations, explanations
that address the requested tool or product first, and source-only delivery with documentation
fixes. At that point, the [discovery source](../../../skills/core/skillvault-discovery/SKILL.md)
accepted those two aliases but rejected other prefixes. This record preserves that earlier
decision as context; installed-copy refresh remains separate.

The owner subsequently proposed interpreting three or four letters as the beginning of an
action name. Unique-prefix matching within the selected topic was recommended, with exact
actions and documented aliases taking precedence. Recording the proposal alone did not accept it.
On 2026-09-23, the owner requested "apply Action-prefix matching", accepting this policy and
authorizing its source implementation. Installed-copy updates and publication were not requested.

A read-only check on 2026-09-23 found 19 catalog skills with declared action menus and no
ambiguous three- or four-letter canonical prefixes within a topic after exact-name matching.
This is current metadata evidence, not a guarantee about future actions or proof of agent routing.

## Decision

Apply the following rule to the explicit action argument of each multi-action topic:

1. Preserve the existing read-only `list` default when the action is omitted.
2. Match an exact canonical action or an existing documented alias first. Preserve that
   spelling's current meaning, including aliases longer or shorter than three or four letters.
3. Otherwise, only a token of exactly three or four letters is a prefix candidate. Compare it
   with canonical actions in the selected topic, not actions in other topics or prefixes of aliases.
4. If exactly one canonical action starts with the token, select that action's existing procedure
   and pass the remaining arguments unchanged.
5. If multiple actions match, show those choices and ask the user to disambiguate. If no action
   matches, show help. Neither outcome executes an action or silently falls back to another action.

Full names remain in menus, synopsis hints, manifest action enums, and registrations. This adds
no skill folders, runtime operations, or separate implementations. Existing case handling and
unambiguous natural-language routing remain unchanged. Do not apply this rule to skill names,
targets, paths, option names, or other arguments.

Recognizing a shortened action grants exactly the same authority as its full spelling: existing
scope checks, confirmations, denials, and installation/publication boundaries still apply. No
extra confirmation is needed solely because an otherwise valid action was abbreviated.

Action examples:

| Topic | Input | Canonical action |
| --- | --- | --- |
| `skillvault-discovery` | `eva` or `eval` | `evaluate` |
| `skillvault-discovery` | `exp` or `expl` | `explain` |
| `skillvault-installation` | `ins` or `inst` | `install` |
| `skillvault-installation` | `upd` or `upda` | `update` |
| `harness-dev` | `que` or `queu` | `queue` |

For a future menu containing both `declare` and `decline`, `dec` and `decl` would be ambiguous.
An exact existing alias would still take precedence; otherwise the user must choose.

## Alternatives and Consequences

- **Keep exact aliases only:** Explicit and stable, but each additional abbreviation needs its
   own maintained mapping. Replaced as the exclusive rule; existing aliases still take priority.
- **Unique three- or four-letter prefixes:** Selected. It matches the owner's requested
  shorthand while bounding the matching rule and preserving readable canonical menus.
- **Any-length or fuzzy matching:** More permissive, but goes beyond the requested shorthand
  and introduces typo interpretation. Not recommended.

New canonical actions can make a previously unique prefix ambiguous or introduce a new exact
match. Full action names are therefore preferable in durable instructions and automation.
Existing aliases retain priority. Consistent guidance and contract tests are needed across topics;
source updates alone do not refresh installed copies or create nested slash-picker autocomplete.

The change is reversible by removing prefix fallback while retaining full names and existing
aliases. It requires no task, state, schedule, or catalog-schema migration.

## Implementation and Verification

The 19 multi-action source guides include the same routing policy. Each remains self-contained
when installed independently; no shared runtime parser or new dependency is introduced. The
[instruction contract tests](../../../scripts/test-skill-files.mjs) check the routing clauses,
canonical menus, defaults, and existing discovery aliases. They also compare the action examples
above with the declared topic menus.

The policy covers exact-action/alias precedence, unique three/four-letter matches, ambiguity,
no match, unsupported prefix lengths, and topic isolation. For example, `upd` under authoring
does not match the alias `update`; `update` itself retains its exact alias route to `upsert`.
`ins` under discovery is unknown even though installation has an `install` action. A five-letter
fragment such as `evalu` is not accepted unless it is itself a full action or documented alias.
The synthetic `declare`/`decline` example above requires clarification, not a guessed action.

These are instruction and metadata checks, not a live-model routing test. Helpers still receive
their existing canonical arguments. The other accepted discovery improvements and existing
harness review policy are unchanged.

No policy decision remains open in this ADR. Installed-copy rollout remains separately approved.
This request updates source guidance, contract tests, and documentation only; runtime code,
installed copies, schedules, Git index, commits, and remote publication are unchanged.