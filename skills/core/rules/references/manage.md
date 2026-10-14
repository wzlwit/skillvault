# Rule Management

Manage the authoritative AI-rules document without silently changing working guidance. A rule typed
after `/rules`, and `/rules remove <rule>`, follow this procedure.

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

1. Choose the target. An explicit location wins. `global`, the default, is the private
   **Personal rules** section of `~/.copilot/copilot-instructions.md`, after the generated block;
   create the file first with the [always-on helper](../scripts/always-on.ps1) if it is missing.
   `project` is the current project's instructions: the **Project rules** section of
   `.github/copilot-instructions.md`, or the file where the project already keeps its instructions,
   such as AGENTS.md. The SkillVault library changes only when the user names it: `extra` edits the
   [extra rules](./extra.md), one bullet per rule, and `core` the four core rules, both in the
   verified SkillVault checkout. The library is public, so a rule that needs private or work-specific
   details, such as internal system, customer, or person names, paths, or IDs, stays `global` or
   `project`. Ask if the target is still unclear; never create a second competing rules file.
2. Read the complete governing section and current rules before proposing a change.
3. Check for duplication, conflict, weakened requirements, and the appropriate existing rule.
   Preserve explicit security requirements. If the rule is a limit the harness can enforce, say
   that it belongs in `/hn-setup policy set limits` or `set fallback`, name the matching field, and
   continue only if the user still wants a written rule.
4. Present the operation, target, exact proposed insertion or replacement, rationale, and any
   compact guidance that must remain synchronized.
5. Wait for explicit confirmation unless the current request already approves the exact text.
6. Apply only the confirmed change. Keep numbering, style, and detailed guidance consistent.
7. For an `extra` or `core` change, edit the [extra rules](./extra.md) or the [compact core](./core.md)
   in the verified SkillVault checkout, which is public: no private or project details. Then update
   the installed `rules` copy and rerun the helper with `-Apply` for each scope where the rules are
   applied, starting with global; each block keeps its set. Committing and publishing need separate
   requests; another machine gets the change after it is pushed, its `rules` copy is updated, and
   `/rules apply` runs there.
8. Validate the changed Markdown and any affected catalog/manifest. Report changed files and
   anything deliberately excluded from the compact core.

Text proposes an insertion for a new rule or shows current and replacement text for an existing one; `remove` shows the
exact rule and dependent guidance to be removed. Neither is implied by `/rules apply` or a grilling
recommendation. Never edit from a summary or grep hit, weaken a security rule without explicit
direction, or delete by a partial name match. Commits, pushes, and PRs require separate requests.