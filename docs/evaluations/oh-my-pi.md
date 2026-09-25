# Oh My Pi

- Evaluated: 2026-09-16
- Source: https://github.com/can1357/oh-my-pi
- Documentation: https://omp.sh
- Version/revision: Unknown; official main-branch README and license reviewed, no release pinned
- Recommendation: Defer runtime integration; coexist with existing harness skills

## Assessment

Oh My Pi (`omp`) is a terminal-first coding agent derived from Mario Zechner's Pi. It serves
developers who want a configurable multi-provider agent with hash-anchored edits, LSP and debugger
tools, persistent execution, subagents, and TypeScript extensions. Its documented one-shot,
RPC, and SDK interfaces make it a candidate worker backend, not a drop-in Copilot skill.

Value is high as a standalone runtime and medium as an incremental addition to this setup.
Development, delegation, and review overlap with `harness-dev` and `harness-review`; those skills
also own task tracking, workspace selection, approval boundaries, validation, and evidence.
Keep them. A future focused guidance skill could teach OMP setup, model routing, and extensions,
but must not claim to bundle or install the application.

## Integration Decision

Do not point the existing Copilot adapter at `omp`: CLI arguments, credentials, permission
controls, event transport, termination, and output envelopes must be verified separately.
Before adoption, test one bounded local fixture through a dedicated adapter, including failure
exit handling, cancellation, read-only review, approved models/budgets, and structured results.
An SDK/RPC integration remains an option after those checks, not an implemented capability.

## Risks and Evidence

- Shell/file/desktop tools and extensions need explicit host and data-access approval.
- Imported configuration is not a verified transfer of this harness's permissions.
- Provider credentials and subscription authorization require their own setup; none was accessed.
- The official license is MIT, with upstream attribution and separate third-party notices.
- Published benchmark claims were not independently validated.
- The installed inventory and local/public SkillVault catalogs had no matching entry when checked.
- No OMP installation, code execution, live authentication, or end-to-end adapter test was performed.

Reconsider when a concrete workflow needs OMP capabilities or the user requests a separately
approved local backend trial. Sources: [README](https://github.com/can1357/oh-my-pi/blob/main/README.md),
[license](https://github.com/can1357/oh-my-pi/blob/main/LICENSE).