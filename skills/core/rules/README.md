# Rules

`/rules apply` (or `/rules core`) applies the four core working rules to the current task without
editing files. Bare `/rules` shows those rules, the available actions, and whether the always-on
copy is current.

`/rules` keeps a generated copy of the four rules in `~/.copilot/copilot-instructions.md`, so every
Copilot chat loads them. Your private Personal rules follow that block in the same file.

`/rules upsert|remove <rule>` proposes a narrowly scoped change and applies it only after
confirmation. It changes your private Personal rules by default, and the shared core rules only
when you say `core`. A limit the harness can enforce belongs in `/hn-project policy` instead.
