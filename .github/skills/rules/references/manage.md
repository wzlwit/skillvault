# Rule Management

Manage the authoritative AI-rules document without silently changing working guidance.

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