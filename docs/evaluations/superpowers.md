# Superpowers Evaluation

- Evaluated: 2026-09-30
- Canonical source: https://github.com/obra/superpowers
- Reviewed revision: `8ca22dba9a94f28898bbce59f2537ff4d87c747d` (release v6.4.2, 2026-09-25, latest `main` commit when inspected)
- Author: Jesse Vincent and Prime Radiant; MIT license
- Recommendation: Skip a SkillVault bundle or reference for the whole framework; defer adapting
  single skills, with `systematic-debugging` as the first candidate
- Scope: Source review only; nothing was installed or run

## Purpose and Capabilities

Superpowers is a software-development method for coding agents. It has 15 skills, including a
bootstrap skill, `using-superpowers`, that plugin hooks load at session start so the other skills
trigger on their own. Its basic flow is brainstorming, a Git worktree, a written plan, execution by subagents
or inline, test-driven development, code review, and finishing the branch. Other skills cover
systematic debugging, verification before claiming completion, receiving review feedback, parallel
agents, writing skills, and diagnosing Superpowers sessions.

Upstream installs itself per tool through plugin marketplaces, including Claude Code, Codex,
Cursor, Gemini CLI, and GitHub Copilot CLI. VS Code Chat is not listed as a supported tool.

## Value, Fit, and Overlap

Value is high as a method and as source material, and medium for this setup. Much of it is already
covered here, and its automatic, mandatory flow conflicts with this repository's rule that commits,
pushes, and other side effects need an explicit request.

- `brainstorming` in SkillVault is a rewritten adaptation of the upstream skill with the same name:
  SkillVault's own text that works by itself, not a copy of the upstream file and not a link-only
  reference. It already covers the upstream's newer points on shared intent and approval before
  implementation.
- `harness-dev`, `harness-test`, `harness-review`, and `pr-review` overlap with plan execution,
  review requests, and verification gates. `harness-dev` already treats review feedback as claims to
  verify.
- `rules` partly overlaps with verification before completion; see the proposal below.
- `skillvault-authoring` overlaps with `writing-skills`. Upstream's release history shows a
  test-first rule for skill edits; SkillVault keeps comparative checks optional by decision.
- No local counterpart: systematic debugging, test-driven development, finishing a branch,
  parallel agents, and session diagnosis. Harness worktree mode partly covers Git worktrees.

Fit: no SkillVault bundle. The framework depends on hooks and helper scripts that a copied bundle
cannot carry, it changes often, and 15 imported skills could not be edited under the external-source
rule. A reference entry would add little, because upstream already ships official installers.

Installed recommendation: No SkillVault scope or Copilot plugin folder has it. An older Claude Code
project install (v4.2.0, February 2026) exists; update it there if it is still used. Before
installing the Copilot CLI plugin next to SkillVault's `brainstorming`, resolve the name clash: two
skills called `brainstorming` would compete.

Standalone use: Worth using in the tools it supports, such as Claude Code or Copilot CLI, for new
feature work where the full brainstorm, plan, test, and review flow is wanted. It is not a good
always-on default for approval-heavy work.

Skill recommendation: Skip a bundle or reference for the whole framework. Defer adapting single
skills. `systematic-debugging` is the clearest gap; adapt it like `brainstorming`, without mandatory
triggers, when a debugging workflow is wanted.

Harness integration: Defer. This matches the harness plan's "reuse, not wholesale adoption". Harness
already gates completion on validation and review; upstream's automatic commits and "rule and
continue" handling of plan conflicts differ from harness approvals.

## Risks and Limits

- The bootstrap tells the agent to use a skill if there is "even a 1% chance" it applies, before any
  response, and the README calls the workflows mandatory. It says user instructions such as
  `AGENTS.md` take precedence, but the default adds heavy process to small tasks.
- Default Git side effects: the test-driven cycle ends with a commit, worktrees create branches,
  and finishing offers merge or pull request options.
- Session hooks inject context. Subagent development uses bash helper scripts, and in Claude Code
  on Windows the session hook needs Git Bash.
- The optional visual companion in brainstorming loads a logo from the maintainer's site with the
  version number. Setting `SUPERPOWERS_DISABLE_TELEMETRY` turns this off.
- It changes quickly: v6.4.2 shipped on 2026-09-25, while the local Claude Code copy is v4.2.0.

## Existing-Skill Improvement

### Evidence Before Success Claims

| Detail | Proposal |
| --- | --- |
| Target | `rules`, section "4. Verify proportionately" in `skills/core/rules/references/ai-principles.md`, changed through `/rules` management |
| Evidence and gap | Upstream `verification-before-completion` at the reviewed revision requires running the proving command fresh and reading the full output, exit code, and failure count before any success claim. It lists an earlier run, a partial check, and an agent's own success report as not sufficient. Locally, rule 4 asks for the cheapest focused check, and the detailed guidance says to keep exit status and output, but nothing says what counts as proof of success. `harness-dev` covers only worker replies. |
| Proposed change | Add one bullet: before claiming success, check the evidence from this change, meaning the command's exit status and full result, such as failure counts. Empty filtered output, an earlier run, or a tool's or agent's own success report is not proof; confirm the actual output, file, or diff. Checks stay proportionate: a focused check can still be enough. |
| Expected benefit | Fewer false "done" reports caused by filtered logs, stale runs, or tools that report success without applying a change. |
| Validation | Instruction review: a build whose filtered log is empty but whose exit code is 1 must be reported as failed; an edit reported as successful while the file is unchanged is not done. A focused test with exit code 0 and a passing count needs no extra full-suite run. |

Considered, not proposed: a mandatory failing baseline for every skill edit (a policy SkillVault
chose not to adopt); rules for receiving review feedback (already in `harness-dev`); updates to the
`brainstorming` adaptation (already covered, and it is an external-source skill).

## Verification Limits

Read at the reviewed revision: repository metadata and license, the release commit and its changed
files, the skill list, the README, and the `using-superpowers`, `verification-before-completion`,
and `systematic-debugging` skills. Not read: the other 12 skills, hook and script code, plugin
manifests beyond the release diff, and tests. Nothing was installed or run, and behavior in Copilot
CLI or VS Code was not tested. Popularity (about 293,000 stars when inspected) is context, not a
sign of quality or safety.

## Sources

- [Repository](https://github.com/obra/superpowers)
- [README](https://github.com/obra/superpowers/blob/8ca22dba9a94f28898bbce59f2537ff4d87c747d/README.md)
- [using-superpowers](https://github.com/obra/superpowers/blob/8ca22dba9a94f28898bbce59f2537ff4d87c747d/skills/using-superpowers/SKILL.md)
- [verification-before-completion](https://github.com/obra/superpowers/blob/8ca22dba9a94f28898bbce59f2537ff4d87c747d/skills/verification-before-completion/SKILL.md)
- [systematic-debugging](https://github.com/obra/superpowers/blob/8ca22dba9a94f28898bbce59f2537ff4d87c747d/skills/systematic-debugging/SKILL.md)
- [Release commit](https://github.com/obra/superpowers/commit/8ca22dba9a94f28898bbce59f2537ff4d87c747d)
