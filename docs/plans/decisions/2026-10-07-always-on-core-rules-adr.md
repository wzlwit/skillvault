# ADR: Always-On Core Rules and Personal Rule Edits

- Date: 2026-10-07
- Status: Accepted. Amended 2026-10-08: the owner asked to keep extra rules in the repository and to
  treat add, upsert, and apply as putting rules into a scope, not editing SkillVault. The rule library
  is the public `core.md` and a new `extra.md` (one bullet per rule). `/rules apply [core]
  [global|project|session]` puts the core and extra rules, or only the core rules with `core`
  (`/rules core`), into the generated block of the global file (default) or the project's
  `.github/copilot-instructions.md`, or into the current chat; the block records its set. Upsert and
  remove still default to the private Personal rules, now with a `project` option, and change the
  library only when the owner names `extra` or `core`. Another skill's "apply `/rules apply`" means
  session. This closes decision 5; `rules` moves to 3.0.0.
- Decision owner: Zhaolong Wang
- Scope: How the four core working rules reach every chat, where rule edits go, and how `/rules`
  relates to `/hn-project policy`.

## Context

The owner asked how `/rules` differs from `/hn-project policy` and then worked through the design in
a grilling session. `/rules` holds the four core working rules and rule edits; the AI follows them as
guidance. `/hn-project policy` holds limits that the harness runtime checks before starting work in
one project. Nothing loaded the core rules automatically: an ordinary chat got them only when the
owner typed `/rules apply`, while harness workers always received them from the runtime. The core
rules live in this public repository, so personal or work-specific rules cannot go there.

VS Code documents `~/.copilot/copilot-instructions.md` as the personal always-on instructions file for
Copilot Agent Host sessions; Copilot CLI sessions, including scheduled automations and harness
workers, load it too. It does not roam through Settings Sync.

## Decision

1. **Two topics stay separate.** `/rules` is guidance for every task; `/hn-project policy` is enforced
   limits for one project. A rule the harness can enforce, such as allowed models, time or credit
   caps, reviewer concurrency, test retries, failure thresholds, or pauses, is sent to policy with its
   matching field; a written rule is added only if the owner still wants one.
2. **The core rules are always on.** `/rules` keeps a generated copy of the four numbered rules
   between `<!-- rules:core:begin -->` and `<!-- rules:core:end -->` at the top of
   `~/.copilot/copilot-instructions.md`. The bundled `scripts/always-on.ps1` reports Missing,
   Unmanaged, InSync, or Drifted without writing, and with `-Apply` regenerates only that block.
   Bare `/rules` shows the status; a confirmed core change or a confirmed repair reruns it.
   Installing the skill writes nothing there.
3. **Personal rules stay private.** `/rules upsert` and `remove` change the Personal rules section
   after the generated block by default. The shared core changes only when the owner says `core`,
   in the SkillVault checkout, and is published only on request. An explicit location wins, and a
   project-specific rule belongs in that project's instructions.
4. **Harness workers keep the runtime copy.** The runtime still passes `core.md` to every worker, so
   workers get the rules on machines without the personal file; the duplicate on this machine is
   about 2 KB.
5. **Personal rules live only in the always-on file for now.** A new devbox recreates the core block
   with the helper; personal rules move by hand until there are enough to justify a synced source.

## Consequences

- Every Copilot chat, CLI run, scheduled automation, and harness worker on this machine follows the
  four rules without `/rules apply`.
- Editing the generated block by hand shows up as Drifted, and the next confirmed repair replaces it.
- The `rules` skill stays at 2.0.0: it is already one major step past its `rules/v1.0.0` tag.
- `scripts/test-rules-always-on.ps1` covers the helper with temporary files only.

## References

- [Rules skill](../../../skills/core/rules/SKILL.md)
- [Rule management](../../../skills/core/rules/references/manage.md)
- [Harness restrictions](../../../skills/planning/harness-project/references/limits.md)
