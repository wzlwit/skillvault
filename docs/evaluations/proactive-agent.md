# Proactive Agent Evaluation

- Evaluated: 2026-09-27
- Source: https://github.com/halthelobster/proactive-agent
- Reviewed revision: `058ed007012a2c88465d2a59edc5cab48596aa59` (2026-02-04)
- Declared skill version: `3.0.0`
- Declared author: `halthelobster`; the instructions credit Hal Labs / Hal 9001
- License: MIT declared in the instructions; no separate full license file in the pinned tree
- Scope: This publisher's GitHub bundle, not other mirrors, ClawHub versions, or research projects

## Recommendation

Purpose: Encourage an agent to anticipate useful work, preserve context across sessions, recover
after compaction, and learn from previous interactions.

Value: Medium incremental value here. Fit: Instruction patterns for a persistent assistant, rather
than another self-contained runtime or a drop-in SkillVault skill.

Installed recommendation: Keep `harness`, `handoff`, `harness-timer`, and `skillvault-authoring`.
Skill recommendation: Skip this additional bundle in the current setup. Its useful ideas overlap
with existing guidance, and its prescribed memory layout and automatic work would need substantial
adaptation to the project's ownership, permission, and storage conventions.

Standalone use: Useful as a reference when designing a new assistant workspace. Do not follow the
pinned quick start as a complete install: its required assets and audit script are not bundled.
Host integration and operational reliability remain unverified.

Harness integration: No new heartbeat, recurring improvement job, task store, or memory hierarchy
is justified. Installation would not authorize any of those changes.

## Verified Source

The shared inventory found no matching name among 55 current-user global/current-project folders.
Neither the current nor the official SkillVault catalog had a matching entry, and the optional
source cache was absent. The public skill directory identified `halthelobster/proactive-agent`;
the publisher's repository and complete instruction file were then inspected at the revision above.
Popularity and registry audit badges were not used as safety evidence.

The pinned tree contains only `SKILL.md`. There is no bundled README, manifest, template directory,
audit script, or test suite. In particular, the quick start references `assets/*.md` and
`scripts/security-audit.sh`, neither of which is supplied by this tree. Other distributions may
differ; this finding is limited to the verified GitHub source.

The instructions describe:

- Capturing corrections, decisions, preferences, names, and specific values before responding.
- A session-state file, daily notes, curated memory, and a buffer that logs exchanges once context
  reaches a prescribed threshold, followed by a recovery sequence after compaction.
- Searching memory and available historical sources rather than guessing about prior work.
- Periodic checks, proactive suggestions, issue repair, and recurring-request tracking.
- Verifying outcomes before claiming completion and preferring stability over novelty.
- Useful security rules: treat external content as data, confirm deletion, and obtain approval
  before external actions. These should not be mistaken for a complete execution policy.

## Existing Coverage

| Candidate idea | Current workflow and relevant boundary |
| --- | --- |
| Recover task context | [Harness context](../../skills/planning/harness/references/context.md) rechecks current instructions, selected task/workspace, blockers, process state, and evidence; old notes are not current authority |
| Preserve continuation details | [Handoff](../../skills/planning/handoff/SKILL.md) captures decisions, unresolved questions, permissions, side effects, and the next action on explicit request, without another task store or transcript dump |
| Periodic useful work | [Harness timers](../../skills/planning/harness-timer/SKILL.md) dispatch approved jobs under one heartbeat, preserving cadence, pauses, and ownership rather than starting work from an untouched backlog |
| Learn and verify improvements | [Authoring](../../skills/core/skillvault-authoring/references/upsert.md) verifies causes, routes lessons to the existing owner, preserves edit approval, and provides focused or optional comparative/trigger checks |

These workflows already retain the useful principles while limiting when they write or execute.
This is an overlap assessment, not a claim that context loss or workflow failures cannot occur.

## Risks and Limits

- **Incomplete bundle:** The referenced onboarding templates and security-audit command cannot be
  inspected or used from this revision. Do not invent them or claim an audit capability was installed.
- **Additional sensitive records:** The architecture adds root-level identity, user, session, memory,
  heartbeat, and tool notes; the tool-note description even mentions credentials. Logging every
  exchange can duplicate private material. Reuse approved host memory and existing project records;
  do not store secrets in ordinary Markdown or copy templates over existing instructions.
- **Recovery is guidance, not a guarantee:** Its "WAL" is a write-before-response instruction, not
  a transactional storage implementation. Buffer clearing and a fixed 60% context threshold assume
  a suitable context meter and lifecycle. The file does not provide `session_status`, `memory_search`,
  or a scheduler, and their availability was not tested here.
- **Broader local autonomy:** Although external actions and deletion have approval rules, the guide
  also prescribes proactive building, self-healing edits, operating-rule updates, and a weekly cron
  reminder. Those do not grant permission to change this project's files, rules, budgets, or schedules.
  They must not bypass existing approvals or create a competing writer.
- **Uncalibrated quotas:** Five-to-ten alternative approaches, recurring questions, weekly follow-ups,
  and the modification-score threshold are fixed prescriptions, not evidence of value for a task.
  The scorecard does not define its input scoring scale. These should not replace bounded,
  evidence-driven work or require retries after a permission denial.
- **Verification scope:** Claims of automatic context survival and battle-tested security were not
  independently demonstrated. An instruction file and a registry badge do not establish that a
  feature runs, a security audit exists, or the proposed defaults improve outcomes.

## Existing-Skill Improvements

None justified from this candidate after comparison with the current owning guidance. Context
revalidation, explicit handoffs, evidence-backed improvement, outcome checks, and approved periodic
work are already addressed. Recommending them again would duplicate recent changes rather than fill
a demonstrated gap.

The distinctive additions are mostly a competing file layout, automatic capture/work triggers, and
fixed activity quotas. No observed recovery failure or recurring task need was established that
would justify adopting those mechanisms here. This conclusion is independent of the Skip verdict:
a future reproducible gap could support a small native change without importing this package.

## Verification and Reconsideration

Read the publisher metadata, pinned file tree, complete candidate instructions, and the relevant
installed context/handoff/timer guides plus current authoring procedure. No candidate instruction,
audit command, heartbeat, agent worker, or installer was executed. No project instruction, memory
layout, skill, or schedule was changed; only this public-safe evaluation record was added.

Reconsider if a concrete continuity or proactive-work requirement is not served by the current
workflows. First establish the failing case, the intended host's capabilities, an approved storage
and execution scope, and complete source material. Preserve source attribution and confirm the
applicable license notices before any later import.

## Sources

- [Pinned instructions](https://github.com/halthelobster/proactive-agent/blob/058ed007012a2c88465d2a59edc5cab48596aa59/SKILL.md)
- [Pinned repository tree](https://github.com/halthelobster/proactive-agent/tree/058ed007012a2c88465d2a59edc5cab48596aa59)
- [Publisher metadata](https://api.github.com/repos/halthelobster/proactive-agent)
- [Discovery listing](https://www.skills.sh/halthelobster/proactive-agent/proactive-agent)