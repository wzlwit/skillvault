# Rule Management

Manage the authoritative AI-rules document without silently changing working guidance.

## Lessons Proposed as Rules

When a correction or incident motivates a rule proposal, establish the relevant evidence and
cause first. Distinguish a genuine failure from an expected command result, a temporary access
problem, or an unrelated environment condition. Treat an unverified technical claim as a question,
not a standing instruction. A user's preference applies at the scope the user gave it.

Check whether the lesson belongs in working rules at all. Facts and preferences may belong in
existing host memory; a reusable procedure may belong in its owning skill; project behavior belongs
in that project's guidance. Do not create another rules or learning file to avoid that choice.
Selecting another destination does not grant permission to edit it.

For a justified rule, explain its evidence, intended scope, and expected effect. Check one nearby
valid case that the proposed wording must leave unchanged. Limit the rule to the affected workflow
instead of turning a local workaround into a universal restriction. Read existing exceptions and
settled decisions; leave deferred choices unresolved. Repeated incidents support investigation,
not automatic promotion or an invented occurrence threshold.

Use the confirmed edit procedure below. A lesson, recurrence count, or claim that a change is
low-risk does not waive confirmation. Do not remove stale guidance merely because it is old;
establish the contradiction and propose the exact scoped replacement. Keep the four shared core
rules compact, and do not copy incident narratives, confidence scores, or private evidence into them.

## Confirmed Edit Procedure

1. Identify the authoritative document from the explicit location or project instructions.
   Ask if it is unclear; never create a second competing rules file by default.
2. Read the complete governing section and current rules before proposing a change.
3. Check for duplication, conflict, weakened requirements, and the appropriate existing rule.
   Preserve explicit security requirements.
4. Present the operation, target, exact proposed insertion or replacement, rationale, and any
   compact guidance that must remain synchronized.
5. Wait for explicit confirmation unless the current request already approves the exact text.
6. Apply only the confirmed change. Keep numbering, style, and detailed guidance consistent.
7. Update the [compact core](./core.md) only when the changed rule belongs in that shared set.
   Do not copy lengthy explanations, examples, or private project details into it.
8. Validate the changed Markdown and any affected catalog/manifest. Report changed files and
   anything deliberately excluded from the compact core.

`add` proposes an insertion; `modify` shows current and replacement text; `remove` shows the
exact rule and dependent guidance to be removed. None is implied by `/rules apply` or a grilling
recommendation. Never edit from a summary or grep hit, weaken a security rule without explicit
direction, or delete by a partial name match. Commits, pushes, and PRs require separate requests.