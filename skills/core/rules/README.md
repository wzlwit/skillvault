# Rules

The rule library is the core working rules (`references/core.md`) and the extra rules
(`references/extra.md`) in this repository.

- `/rules` alone lists every rule, numbered: the core and extra rules, your Personal rules, and this
  project's rules, with where the rules are in effect.
- `/rules apply [core|extra|<number or name>|<your words>] [global|project|session]` puts rules into
  effect. `/rules apply core` writes the core rules into a generated block at the top of
  `~/.copilot/copilot-instructions.md`, which every Copilot chat on this machine loads, and
  `/rules apply extra` writes the extra rules into this project's `.github/copilot-instructions.md`,
  so a chat in the project gets each rule once. `/rules apply` alone, one rule from the list, or your
  own words apply to this chat only and are saved nowhere. A scope after `apply` overrides these
  defaults; `global` or `project` alone writes both sets there.
- Type a rule after `/rules`, such as `/rules always run the focused test first`, to add or change
  your own rule after confirmation: the private Personal rules in the global file by default, or
  this project's instructions when you say project. `/rules remove <rule>` removes one after
  confirmation. These never change this repository.
- The library changes only when you name it: say `extra` or `core` with the rule. It is public, so
  rules with private or work-specific details stay global or project.
- `/rules` alone also offers to write the global copy when it is missing or out of date. A limit the
  harness can enforce belongs in `/hn-setup policy` instead.
