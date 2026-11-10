# Rules

The rule library is the core working rules (`references/core.md`) and the extra rules
(`references/extra.md`) in this repository.

- `/rules` alone lists every rule, numbered: the core and extra rules, your Personal rules, and this
  project's rules, with where the rules are in effect.
- `/rules apply [core|extra|<number or name>|<your words>] [global|project|session]` puts rules into
  effect. Without a scope it acts on this chat only: the core and extra rules, only the core or extra
  rules, one rule from the list, or your own words, which are saved nowhere. `global` writes a
  generated block with the core and extra rules, or only the core rules, at the top of
  `~/.copilot/copilot-instructions.md`, which every Copilot chat on this machine loads; `project`
  writes the same block into this project's `.github/copilot-instructions.md`.
- Type a rule after `/rules`, such as `/rules always run the focused test first`, to add or change
  your own rule after confirmation: the private Personal rules in the global file by default, or
  this project's instructions when you say project. `/rules remove <rule>` removes one after
  confirmation. These never change this repository.
- The library changes only when you name it: say `extra` or `core` with the rule. It is public, so
  rules with private or work-specific details stay global or project.
- `/rules` alone also offers to write the global copy when it is missing or out of date. A limit the
  harness can enforce belongs in `/hn-setup policy` instead.
