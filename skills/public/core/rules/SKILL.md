---
name: rules
description: Review and safely add, modify, or remove AI working rules.
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "<add|modify|remove> <rule> [location]"
---

# Rules

Manage an authoritative AI-rules document. Use this skill to add, modify, or remove a
rule without silently changing the user's working guidance.

## Workflow

1. Identify the authoritative rules document from `location`, an explicit user-provided path,
   or the current project's instructions. If the authoritative source is unclear, ask before
   editing; never create a second competing rules file by default.
2. Read the complete governing section and its current rule list before proposing a change.
3. Check whether the requested rule duplicates, conflicts with, weakens, or belongs within an
   existing rule. Preserve explicit security requirements.
4. Present a compact proposal: operation, target rule, exact replacement or insertion text,
   rationale, and any related concise instruction skill that should remain synchronized.
5. Wait for explicit confirmation before changing or deleting a rule, unless the user already
   explicitly approved the exact proposed text in the current request.
6. Apply only the confirmed change. Keep numbering, style, and related detailed guidance
   consistent with the source document.
7. If the rules document has a compact injected counterpart, such as `rules-core`, update it
   only when the changed rule belongs in that compact set. Do not copy lengthy explanations,
   examples, or private details into the injected skill.
8. Validate the edited Markdown and any synchronized SkillVault catalog or manifest. Report the
   files changed and any rule deliberately left out of the compact counterpart.

## Operations

- `add`: propose an insertion point and exact new rule text.
- `modify`: locate the named rule, show the current and proposed text, then replace it after
  confirmation.
- `remove`: show the exact rule and dependent guidance that would be removed, then remove it
  only after confirmation.

## Safety

- Never alter a rule from a summary, grep result, or stale copy; read the governing text first.
- Never weaken an explicit security rule without explicit user direction.
- Never delete a rule based only on a partial name match.
- Do not commit, push, or open a PR unless the user explicitly requests it.