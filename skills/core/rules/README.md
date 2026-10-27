# Rules

The rule library is the core working rules (`references/core.md`) and the extra rules
(`references/extra.md`) in this repository.

- `/rules apply [core] [global|project|session]` puts the rules into effect: the core and extra
  rules, or only the core rules with `core`. `global`, the default, writes a generated block at
  the top of `~/.copilot/copilot-instructions.md`, which every Copilot chat on this machine loads;
  `project` writes the same block into this project's `.github/copilot-instructions.md`; `session`
  applies them to the current chat without editing files.
- Type a rule after `/rules`, such as `/rules always run the focused test first`, to add or change
  your own rule after confirmation: the private Personal rules in the global file by default, or
  this project's instructions when you say project. `/rules remove <rule>` removes one after
  confirmation. These never change this repository.
- The library changes only when you name it: say `extra` or `core` with the rule. It is public, so
  rules with private or work-specific details stay global or project.
- `/rules` alone shows the rules and where they are in effect, and offers to apply them when the
  global copy is missing or out of date. A limit the harness can enforce belongs in
  `/hn-setup policy` instead.
