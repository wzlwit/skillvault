# Rules

The rule library is the four core working rules (`references/core.md`) and the extra rules
(`references/extra.md`) in this repository.

- `/rules apply [core] [global|project|session]` puts the rules into effect: the core and extra
  rules, or only the four core rules with `core` (`/rules core` is short for `/rules apply core`).
  `global`, the default, writes a generated block at the top of `~/.copilot/copilot-instructions.md`,
  which every Copilot chat on this machine loads; `project` writes the same block into this project's
  `.github/copilot-instructions.md`; `session` applies them to the current chat without editing files.
- `/rules upsert|remove <rule> [global|project]`, or just "add a rule: ...", changes your own rules
  after confirmation: the private Personal rules in the global file by default, or this project's
  instructions. These never change this repository.
- The library changes only when you name it: `/rules upsert extra <rule>` or `/rules upsert core
  <rule>`. It is public, so rules with private or work-specific details stay global or project.
- Bare `/rules` shows the rules, the actions, and where they are applied. A limit the harness can
  enforce belongs in `/hn-project policy` instead.
