---
name: github-issues
description: Find, draft, create, or update GitHub issues. Use for bug reports, feature requests, issue triage, labels, assignees, milestones, and issue relationships in an explicitly identified repository.
metadata:
  author: GitHub contributors
  maintainer: wzlwit
  version: null
---

# GitHub Issues

Turn a concrete problem or request into a useful issue, or make a scoped change to an
existing issue. This skill does not authorize publishing merely because it is installed.

## Workflow

1. Determine whether the user wants a query, local draft, new issue, or update. Resolve the
   repository and issue number from their request or the current repository's configured
   remote. Confirm ambiguities; never use an upstream example repository as the target.
2. Prefer available GitHub tools, loading their definitions before use. If the needed
   capability is unavailable, use an already authenticated `gh` CLI. Do not request secrets
   in chat or widen token permissions automatically.
3. Read relevant issue templates, current labels, supported issue types, and existing issues.
   Search for duplicates using the problem's names and symptoms. For updates, read the
   current issue before preparing changes so unrelated content and metadata are preserved.
4. Draft a concise title and useful body. Bug reports need reproduction steps, expected and
   observed behavior, environment, and evidence. Feature requests need the problem, proposed
   outcome, scope, and acceptance criteria. Mark unknown facts instead of inventing them.
5. Use existing repository labels, types, milestones, and assignees only when appropriate
   and authorized. Do not replace entire label or assignee lists to add one item. Check the
   tool's actual schema for issue types and relationships rather than assuming CLI flags.
6. A draft or review request is read-only remotely. Create, comment, close, reopen, assign,
   or otherwise update issues only on explicit user instruction or confirmation of the
   proposed action. Batch changes need an approved target set and action.
7. After a write, read back the issue and verify the changed fields. Report its URL, number,
   and what changed. For a failed write, report the failure without claiming publication.

## Boundaries

- GitHub permissions and an available integration or CLI are runtime requirements, not
  bundled dependencies. This guide installs no tools or account configuration.
- Redact secrets and private data from issue bodies and logs. Never copy internal material
  into a public issue without authorization. Publishing is separate from drafting.
- Commits, pushes, releases, PR creation, and repository administration are not implied by
  an issue-management request.

## Source and Curation

Curated SkillVault guide for
[github-issues in GitHub's Awesome Copilot collection](https://github.com/github/awesome-copilot/tree/main/skills/github-issues),
under the repository's [MIT license](https://github.com/github/awesome-copilot/blob/main/LICENSE).
Authorship stays with its GitHub contributors; wzlwit maintains this curated guide. The
wording is rephrased for SkillVault and is not the unchanged upstream skill. Extended
upstream references remain upstream. This guide declares no version because it does not
track an upstream release.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.
