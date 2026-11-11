# ADR: Apply Rules in the Chat by Default

- Date: 2026-11-10
- Status: Accepted. The owner proposed `/rules core` and `/rules extra` to apply each set, `/rules
  apply` with a rule name or the owner's own words, and bare `/rules` listing every rule. The agent
  pointed out that the 2026-10-09 convention retired the `/rules core` shortcut, that `core` and
  `extra` at the start of plain text edit the rule library, and that with the global default `apply
  core` drops the extra rules from every chat. It put four questions with recommended answers, and
  the owner took all four. Amended 2026-11-10: the owner then gave each set a file default:
  `apply core` writes the core rules into the global instructions, and `apply extra` writes only the
  extra rules, through a new `extra` set, into the project's `.github/copilot-instructions.md`, so a
  chat in that project gets each rule once. A file's block holds exactly what was last applied
  there, so `apply core` on a global block that held all the rules removes the extra rules from it.
  The agent recommended keeping the extra rules in the global file as well, so that chats outside
  those projects keep them, and the owner chose this split. Bare `apply`, one rule, and the owner's
  own words still apply to the chat. This replaces decision 2's sentence that a file always keeps
  the core rules; `rules` moves to 6.0.0.
- Decision owner: Zhaolong Wang
- Scope: What `/rules apply` and bare `/rules` do. Adding, changing, and removing rules is unchanged.
- Supersedes in part: the 2026-10-08 amendment of the
  [always-on core rules ADR](./2026-10-07-always-on-core-rules-adr.md), where `/rules apply` wrote the
  global block by default.

## Context

`/rules apply [core] [global|project|session]` wrote the generated block of the global instructions
file by default. Every Copilot chat on this machine already loads that block, so a plain
`/rules apply` only repaired it, and `/rules apply core` replaced it with the core rules alone,
dropping the extra rules from every chat. The block holds whole sets only, so there was no way to
apply the extra rules alone, one rule, or a rule typed on the spot. Bare `/rules` showed the core and
extra rules, but not the owner's Personal rules or a project's rules.

## Decision

1. **`core` and `extra` stay under `apply`.** The commands are `/rules apply core` and
   `/rules apply extra`; there is no `/rules core` or `/rules extra`. The 2026-10-09 convention
   retired `/rules core` as a duplicate of `apply core`, and `core` or `extra` at the start of plain
   text still edits the rule library, as in `/rules extra <rule>`.
2. **`apply` acts on the current chat by default.** Without a scope, `apply` follows the core and
   extra rules, or the selection, for the rest of the chat and edits no files. `global` or `project`
   writes the generated block, which holds the core and extra rules or only the core rules; `apply
   extra` there writes all the rules, since a file always keeps the core rules. Another skill's
   "apply `/rules apply`" already meant the current chat.
3. **Selections.** `core`, `extra`, one rule by its number from the bare list or by words that
   clearly name it, or the user's own words. Words that could name several rules show them and apply
   nothing. The user's own words are followed in the chat only and saved nowhere; typing them after
   `/rules` still saves a rule after confirmation. With `global` or `project`, one rule or the user's
   own words go through that confirmed route instead.
4. **Bare `/rules` lists every rule.** One running number covers the core rules, the extra rules, the
   Personal rules in the global file, and the Project rules section of the project's
   `.github/copilot-instructions.md`, so `apply` can name a rule by number. It still reports where the
   rules are in effect and offers to write a missing or out-of-date global copy.
5. **Versions.** A default changes, so `rules` moves to 5.0.0. The generated block's comment now
   names `/rules apply global` or `/rules apply project`, so existing blocks show as out of date
   until they are written again.

## Alternatives Not Chosen

- **`/rules core` and `/rules extra` as commands.** Shorter to type, but they repeat `apply` and would
  take over the library-edit route that starts with `core` or `extra`.
- **Keep the global default.** `apply core` would keep quietly dropping the extra rules from every
  chat, and the extra rules alone, one rule, or new words would have no file form.
- **Save `apply <words>` as a Personal rule.** Typing the rule after `/rules` already does that, after
  confirmation.

## Consequences

- Applying rules writes no file unless the user names `global` or `project`; repairs still come from
  bare `/rules`.
- Rule numbers follow the current files, so they shift when a rule is added or removed; `apply` by
  number uses the latest list.
- `scripts/test-skill-files.mjs` checks the chat default, the selections, and the full list, and
  `scripts/test-rules-always-on.ps1` checks the block's comment for each scope.

## References

- [Rules skill](../../../skills/core/rules/SKILL.md)
- [Always-on core rules ADR](./2026-10-07-always-on-core-rules-adr.md)
- [Bare, text, and menu convention ADR](./2026-10-09-bare-text-menu-convention-adr.md)
