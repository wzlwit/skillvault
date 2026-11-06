# ADR: Skip Documentation and Configuration Rounds

- Date: 2026-11-05
- Status: Accepted. The owner asked that review skills not run a local Changes review when a round
  changes only documentation or configuration. The agent put six questions with recommended answers,
  and the owner took all six: the local review paths only, configuration by file type with
  exceptions, AI instruction files reviewed as code, a round measured since the last review that ran
  with a safeguard for open findings, a "review anyway" override, and a matching update to the
  owner's personal rule.
- Decision owner: Zhaolong Wang
- Scope: When `/harness-review` and the `/harness-dev` loop start a Changes reviewer. `/pr-review` is
  unchanged.
- Supersedes in part: decision 5 of the
  [review-panel ADR](./2026-10-02-review-panel-dev-loop-and-sprints-adr.md), where every development
  round ran a Changes review.

## Context

The owner's personal rule already skipped the local Changes review for iterations that change only
documentation, even where project instructions ask for a review after every iteration, but it kept
the review for configuration. The harness itself skipped nothing: `/harness-review` read the whole
branch every time, and the `/harness-dev` loop reviewed every round, so a documentation or settings
tweak after a clean review still started two reviewers at `max` effort.

## Decision

1. **Which files.** Documentation is `.md`, `.mdx`, `.markdown`, `.rst`, `.adoc`, and `.txt` files.
   Configuration is `.json`, `.jsonc`, `.yaml`, `.yml`, `.toml`, `.ini`, `.cfg`, `.conf`, `.config`,
   `.properties`, `.editorconfig`, `.gitattributes`, and `.gitignore` files.
2. **Reviewed like code.** AI instruction files (`SKILL.md`, `AGENTS.md`, `AGENT.md`, `CLAUDE.md`,
   `GEMINI.md`, `copilot-instructions.md`, `*.instructions.md`, `*.prompt.md`, `*.agent.md`,
   `*.chatmode.md`, and files under `.claude/commands`, `.claude/agents`, `.github/agents`, and
   `.clinerules`), dependency manifests and lock files (such as `package.json`,
   `requirements*.txt`, and `pubspec.yaml`), continuous integration and delivery (CI/CD) pipelines
   (such as `.github/workflows`, `action.yml`, and `azure-pipelines*.yml`), and `.env` files,
   because they change what agents, builds, and deployments do. The runtime knows them by name and
   folder; "review anyway" covers any it doesn't.
3. **What a round is.** In `/harness-review`, what changed since the last comparable review that
   finished clean or with findings, read from the snapshot in its report; a first review compares
   the whole change. In development, what changed since the task's last completed review, or since
   its first development started, so a retry after a blocked, failed, or interrupted run still counts
   what came before it. The comparison is file by file, on each file's sections of a plain Git diff,
   without external diff tools or submodule logs.
4. **Safeguard.** A round still gets the review when a finding from the last review is in a file the
   round didn't change, so an unfixed finding is never skipped, and when the comparison could miss
   something: in `/harness-review`, a later comparable review didn't finish clean or with findings,
   such as a blocked, partial, or interrupted one, or the last review's report is gone or can't be
   read; in development, the task's last review started but didn't complete, a commit moved the
   round's base, or the task was saved before this version and hasn't completed a review yet.
5. **What happens instead.** `/harness-review` returns `Skipped` with the changed files and any
   earlier findings not checked again, starts no reviewer, and records no run, so the next review
   still compares with the last one that ran. In development, the round's tests still run; passing
   tests complete the round, or lead to the Full pass when it's on. A turned-on Full pass also still
   runs in a standalone review, alone.
6. **Override.** "review anyway" (`-ReviewAnyway`) keeps the Changes review for one review, or for a
   development task, where it's saved like `-FullPass` and cleared by any other named request.
7. **Records and versions.** Standalone results and run records add `changesSkipped`, and reports,
   including development ones, name the changed files. A default changes, so `harness-runtime`
   8.0.0, `harness-review` 8.0.0, and `harness-dev` 7.0.0 carry this decision. The runtime provides
   interface `review-scope` 2, with `-ReviewAnyway`, which `harness-review` and `harness-dev` require.

## Alternatives Not Chosen

- **`/pr-review` too.** It reviews someone else's PR, where a configuration change can matter as much
  as code, and its runs are already bounded per PR snapshot.
- **All configuration by file type.** Dependency, pipeline, and `.env` changes alter builds,
  deployments, and secrets; a reviewer is the cheap check for them.
- **Only the whole change.** Skipping only when everything a branch or task changes is documentation
  or configuration would still review a documentation-only iteration on a branch with code changes,
  the case the owner's rule was written for.
- **A project setting listing the file types.** One built-in list keeps the behavior predictable;
  "review anyway" covers the exceptions.

## Consequences

- Fewer reviewer sessions in iterative work: documentation and settings rounds after a review cost
  only their tests.
- Documentation and configuration fixes to earlier findings aren't checked again; `/harness-review`
  lists them, and development reports name the files.
- A skipped round's documentation and configuration changes are reviewed with the next round that
  changes code, because the whole change is reviewed then.
- `scripts/test-harness.ps1` covers the file types, the per-file comparison, including copies,
  submodules, and external diff tools, the safeguard, including a blocked later review and a missing
  or unreadable report, the `Skipped` result, the Full pass running alone, "review anyway", a
  development round that runs only its tests, the start point saved before development runs, a task
  saved before this version, and retries after blocked development or a blocked review.

## References

- [Review-panel ADR](./2026-10-02-review-panel-dev-loop-and-sprints-adr.md)
- [Full pass off by default ADR](./2026-10-28-full-pass-off-by-default-adr.md)
- [Runtime guide: Skipped Rounds](../../../skills/planning/harness-runtime/references/runtime.md#skipped-rounds)
