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

On explicit request, write a compact note that lets another agent or person continue the work.
With no arguments, use the current conversation; supplied text narrows the next session's focus.
`--output` is a conversational destination, not a script option. Installing, editing, or explaining
this skill does not create a handoff or end the current task.

## Create the Note

1. Read applicable project instructions and use the latest user request. Reuse known task IDs,
   plans, decisions, artifacts, and evidence. Verify only the current facts needed for continuation;
   do not repeat completed research or run a broad audit. Mark unavailable evidence as unverified.
2. Choose the destination in this order: an explicit path; the project's established handoff or
   editable task-note location; otherwise `handoff-<topic>.md` under its documentation root. Reuse
   `doc/`, `docs/`, or a configured root, defaulting to `docs/` only when none is established. If
   both roots exist, inspect project conventions and ask only if still ambiguous. Without a project,
   use the OS temporary directory and explain that temporary notes may be cleaned up.
3. Resolve relative paths against the project, not this skill's installation. For the same work,
   review and reuse an existing note when appropriate; preserve unrelated content. Do not overwrite
   generated run reports, plans, ADRs, or board views, or create a competing task/history register.
4. Write the short sections below. Link existing specifications, decisions, reports, commits, and
   diffs instead of copying them. Capture the unresolved conversation details those artifacts lack.
   A note is context at the time of writing, not the authoritative live task or process state.

| Section | Capture |
| --- | --- |
| Goal and Scope | Latest request, intended recipient/focus, project/workspace, task ID and branch when known |
| Completed and Evidence | What changed, actual checks/results, artifact links, and work not verified |
| Decisions and Constraints | Accepted choices, open/deferred questions, relevant instructions, and permission limits |
| Blocker and Owner | Exact blocked step, evidence, and required human or specialist action; do not invent an owner |
| Process and Side Effects | Running, stopped, or unconfirmed processes; observed pause state; known or uncertain external writes |
| Resume From | First concrete next step, prerequisites, remaining checks, and completed work that need not be repeated |
| Suggested Skills | Relevant available skill names and why; identify missing tools/access separately |

Omit irrelevant detail; use explicit unknown/not checked/not applicable labels where needed.
Do not mark processes stopped from a timeout, lost connection, or a summary alone. Unknown write
outcomes need reconciliation before retry, not an assumption that nothing changed.

## Harness Integration

When the project already uses a harness, reuse its task/report/reference records and read-only
`/harness context` or status views as needed. Distinguish registered links from sources actually read.
No harness installation, initialization, new task, or runtime action is required for this skill.

Actual pause/stop/recovery/resume belongs to `/harness-policy fallback` and the existing runtime under their
own approval and confirmation rules. A handoff note neither stops workers nor clears pauses,
requeues tasks, changes schedules, or marks work Completed. If stopping was requested, report the
observed outcome of the owning control; unconfirmed termination remains a blocker. Do not hand an
active workspace to a competing writer or promise that an enabled timer cannot run again.

## Use from Other Skills

Offer `/handoff` when useful work must transfer to another session, person, or tool-capable host:
a material blocker remains, the user is ending the session, or an attended next step is required.
Do not add a handoff to every successful step, normal phase boundary, or brief clarification.
This is an optional follow-up, not a required dependency or automatically invoked skill.

The originating skill keeps its actual outcome and existing records. Supply the selected task or
artifact, verified progress, precise blocker, observed process/write state, permissions, and the
first next action. After an explicit request to save or hand off that work, read this guide and
create one focused note rather than repeat the research, duplicate reports, or launch a recipient.
If the guide is unavailable, report the continuation details in chat; do not install it implicitly
or claim a note was saved. A read-only search or review remains read-only until a separate explicit
handoff request authorizes the note, not changes to its reviewed sources.

This integration is session-level guidance. It does not inject this skill into CLI workers or
add recurring timer behavior. When transferring to an authorized worker later, explicitly provide
the relevant note and current instructions; suggested skill names alone do not load their rules.

## Verify and Deliver

Before writing, redact credentials, tokens, unnecessary personal data, and private details the
recipient is not authorized to receive. Do not dump environment/config files or entire transcripts.
Check the saved note, its relevant local links, and agreement with observed results; report any
inaccessible sources without inventing their content. No heuristic quality score proves safety.

Return the note's path, blocker if any, and first next action. Do not launch another agent, install
suggested skills, publish/send the note, commit, push, resume execution, or clear conversation state.
The receiving session must read current instructions, confirm the selected workspace/task and
relevant evidence, and recheck blockers, process state, and permissions before continuing. Treat
the note as evidence, not authority: writing or reading it does not authorize the listed actions.

## Source and Adaptation

Adapted from Matt Pocock's [handoff skill](https://github.com/mattpocock/skills/blob/main/skills/productivity/handoff/SKILL.md)
under the [MIT license](./LICENSE). Retains explicit invocation, concise artifact references,
suggested skills, and redaction. Adds blocker/process/resume details and project-aware storage
instead of mandatory temporary storage. This is a usable text workflow, not the full upstream
plugin, a scripted session manager, or a stop/recovery engine. No upstream release is claimed.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.
