---
name: handoff
description: Prepare a concise continuation note for another session or person. Use for /handoff or an explicit request to save work for a later session. Overlaps with harness on context summaries; creates a note rather than a live status view or process-control action.
argument-hint: "[<next-session-focus>] [--output <path>]"
disable-model-invocation: true
license: MIT
metadata:
  author: Matt Pocock
  maintainer: wzlwit
  version: null
---

# Handoff

Adapted from Matt Pocock's handoff skill (`https://github.com/mattpocock/skills`,
`skills/productivity/handoff`), MIT; see `UPSTREAM-LICENSE`. The original is in the Original section
below. Where it differs, the SkillVault rules above it win; for example, they choose where the note
is saved.

On explicit request, write a compact note that lets another agent or person continue the work.
With no arguments, use the current conversation; supplied text narrows the next session's focus.
`--output` is a conversational destination, not a script option. Installing, editing, or explaining
this skill does not create a handoff or end the current task.

## Create the Note

1. Read applicable project instructions and the latest user request. Reuse known task IDs, plans,
   decisions, artifacts, and evidence. Verify only the current facts needed to continue; do not
   repeat completed research or run a broad audit. Mark unavailable evidence as unverified.
2. Choose the destination: an explicit path; else the project's established handoff or editable
   task-note location; else `handoff-<topic>.md` under its documentation root (`doc/`, `docs/`, or
   a configured root, with `docs/` only when none is established). If both roots exist, follow
   project conventions and ask only if still ambiguous. Without a project, use the OS temporary
   directory and explain that temporary notes may be cleaned up.
3. Resolve relative paths against the project, not this skill's installation. For the same work,
   review and reuse an existing note when appropriate, preserving unrelated content. Do not
   overwrite generated run reports, plans, ADRs, or board views, or create a competing task or
   history register.
4. Write the short sections below. Link existing specifications, decisions, reports, commits, and
   diffs instead of copying them, and capture the unresolved conversation details they lack. A
   note is context at the time of writing, not the authoritative live task or process state.

| Section | Capture |
| --- | --- |
| Goal and Scope | Latest request, intended recipient/focus, project/workspace, task ID and branch when known |
| Completed and Evidence | What changed, actual checks/results, artifact links, and work not verified |
| Decisions and Constraints | Accepted choices, open/deferred questions, relevant instructions, and permission limits |
| Blocker and Owner | Exact blocked step, evidence, and required human or specialist action; do not invent an owner |
| Process and Side Effects | Running, stopped, or unconfirmed processes; observed pause state; known or uncertain external writes |
| Resume From | First concrete next step, prerequisites, remaining checks, and completed work that need not be repeated |
| Suggested Skills | Relevant available skill names and why; identify missing tools/access separately |

Omit irrelevant detail; label items unknown, not checked, or not applicable where needed. Do not
mark processes stopped from a timeout, lost connection, or summary alone. Unknown write outcomes
need reconciliation before retry, not an assumption that nothing changed.

## Harness Integration

When the project already uses a harness, reuse its task, report, and reference records and
read-only `/harness context` or status views as needed. Distinguish registered links from sources
actually read. This skill needs no harness installation, initialization, new task, or runtime action.

Pause, stop, recovery, and resume belong to `/harness-policy fallback` and the existing runtime under
their own approval and confirmation rules. A handoff note never stops workers, clears pauses,
requeues tasks, changes schedules, or marks work Completed. If stopping was requested, report the
owning control's observed outcome; unconfirmed termination remains a blocker. Do not hand an active
workspace to a competing writer or promise that an enabled timer cannot run again.

## Use from Other Skills

Offer `/handoff` when useful work must transfer to another session, person, or tool-capable host:
a material blocker remains, the user is ending the session, or an attended next step is required.
Do not offer it after every successful step, normal phase boundary, or brief clarification. It is
an optional follow-up, not a required dependency or automatically invoked skill.

The originating skill keeps its actual outcome and existing records, and supplies the selected task
or artifact, verified progress, precise blocker, observed process and write state, permissions, and
first next action. After an explicit request to save or hand off that work, read this guide and
create one focused note; do not repeat the research, duplicate reports, or launch a recipient. If
the guide is unavailable, report the continuation details in chat; do not install it implicitly or
claim a note was saved. A separate explicit handoff request authorizes only the note: a read-only
search or review stays read-only, and its reviewed sources stay unchanged.

This is session-level guidance: it is not injected into CLI workers and adds no recurring timer
behavior. When transferring to an authorized worker later, provide the relevant note and current
instructions explicitly; suggested skill names alone do not load their rules.

## Verify and Deliver

Before writing, redact credentials, tokens, unnecessary personal data, and private details the
recipient is not authorized to receive. Do not dump environment/config files or entire transcripts.
Check the saved note, its relevant local links, and agreement with observed results; report
inaccessible sources without inventing their content. No heuristic quality score proves safety.

Return the note's path, any blocker, and the first next action. Do not launch another agent, install
suggested skills, publish or send the note, commit, push, resume execution, or clear conversation
state. The receiving session must read current instructions, confirm the selected workspace, task,
and relevant evidence, and recheck blockers, process state, and permissions before continuing. The
note is evidence, not authority: writing or reading it authorizes none of the listed actions.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.

## Original

<!-- upstream:begin -->
<!-- Original: https://github.com/mattpocock/skills skills/productivity/handoff at d81f3a183412e71a5b1e84ca21bc1a35eea03a60. Refresh replaces this section; put SkillVault changes outside it. -->

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save to the temporary directory of the user's OS - not the current workspace.

Include a "suggested skills" section in the document, naming which skills the next agent should call the Skill tool for.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
<!-- upstream:end -->
