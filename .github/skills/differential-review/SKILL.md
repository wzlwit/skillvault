---
name: differential-review
description: Review security implications of code changes against a baseline. Use for security reviews of PRs, commits, uncommitted diffs, or removed validation; not for routine formatting or a claim of full-codebase audit coverage. Overlaps with harness-review and pr-review on code review; focuses on reachable security regressions.
license: CC-BY-SA-4.0
metadata:
  author: Trail of Bits
  maintainer: wzlwit
  version: null
---

# Differential Security Review

Assess what a change introduces or removes. Keep demonstrated security regressions,
pre-existing issues, and uncertainty distinct.
`harness-review` covers current-project correctness and `pr-review` owns verified remote PRs;
this guide supplies the specialized security methodology, not a worker runtime.
Use `/harness-review --security` to supply this installed guide to its general reviewer and bounded
fresh pass on the same scope/snapshot. Keep this methodology here rather than maintaining a
second copied checklist; general review does not itself establish security audit coverage.
`/pr-review <PR-URL> --security` supplies the same installed methodology to its bounded shared
reviewer without copying it, adding a scanner, or executing untrusted PR code.

## Workflow

1. Confirm the repository, requested diff, and comparison base from the user's request or
   configured upstream. Preserve dirty files. If there is no usable baseline, state that a
   differential review is unavailable; do not invent one or create a commit to obtain it.
2. Inspect changed files and the complete functions that control security-relevant behavior.
   Prioritize authorization, input boundaries, secret handling, external calls, and removed
   protections. Use history to understand why a removed guard existed when history is available.
3. Follow relevant callers and data flow far enough to establish reachability. For a finding,
   identify the actor, controllable input, required permissions, affected operation, and
   concrete impact. Check existing validation, authorization, and isolation that may refute it.
4. Compare the suspected behavior with the base revision. Do not label an existing exposure
   a new regression or treat a missing test alone as proof of an exploitable vulnerability.
5. Inspect the nearest tests. Use a bounded local check when it can distinguish a real defect
   from a false positive. Scale follow-up work to consequential risks; do not scan unrelated
   repositories or run attacks against live services.
6. Report findings first, ordered by evidenced severity, with current file/line anchors,
   impact, prerequisites, baseline comparison, and a focused remediation suggestion. Separate
   coverage gaps and assumptions. Say when no supported finding was identified.
7. Use the requested report location when one is provided. Remain read-only during review;
   implement fixes, publish findings, or create a PR only when separately authorized.

## Boundaries

- No scanner, plugin, or specialist subagent is installed by this guide. A review's accuracy
  depends on the available code and reviewer expertise; it is not a security certification.
- Keep secrets and private data out of reports. Use synthetic local reproduction inputs.
- Do not weaken explicit security requirements or change policy to make a check pass.
- Upstream methodology and pattern references can deepen an agreed audit, but do not
  assume that plugin-specific tools or agents named in them exist in the current host.

## Attribution and Changes

Adapted by SkillVault from Trail of Bits'
[differential-review skill](https://github.com/trailofbits/skills/tree/main/plugins/differential-review/skills/differential-review),
under [CC-BY-SA-4.0](https://creativecommons.org/licenses/by-sa/4.0/), which this adaptation
keeps. Authorship stays with Trail of Bits; wzlwit maintains this curated adaptation. It is
shortened and rephrased rather than unchanged upstream text, uses the host's available tools,
separates coverage from severity, and bundles no upstream plugin or supporting files. It
declares no version because it does not track an upstream release.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.
