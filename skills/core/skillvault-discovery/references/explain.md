
# SkillVault Explain

Help the user understand a skill, tool, or product without reading all its documentation first.
Explain the requested subject first, then its relationship to any relevant SkillVault guide.
This explanation does not replace reading the full instructions when later executing a skill.

## Lookup and Evidence

1. Resolve the subject from the supplied name, file, folder, or URL, using the current discussion
   when omitted. Ask only when the intended subject is genuinely ambiguous, including distinct
   products sharing a name. Resolve explicit sources directly; an inaccessible source is a
   limitation, not permission to silently replace it with another version or subject.
2. For a named skill, reuse `/skillvault-installation list` inventory: inspect the relevant
   project/global/session copy, then local SkillVault catalogs, then the official source if
   necessary. If installed copies differ, identify the copy; ask only if the intended one is unclear.
3. For a tool or product, use relevant local evidence and authoritative upstream documentation
   to explain that subject. Do not substitute a related skill for the requested tool or product.
   Read a related skill's instructions before describing what its guide adds.
4. For skills, read the actual SKILL.md, manifest, README, and any helper that controls behavior
   you will describe. Catalog text and search hits only locate evidence; they are not the explanation.
5. Distinguish the installed guide from upstream packages. For reference-only entries, read
   authoritative upstream guidance before claiming its workflow, and label unbundled capabilities
   and unverified runtime availability clearly. Do not run the subject to explain it.

## Output Order

1. **Purpose:** problem solved, intended user, and useful trigger situations.
2. **Core principles:** the main philosophy, constraints, trade-offs, and safety boundaries.
3. **Workflow:** the normal sequence, including important branches and stop conditions where relevant.
4. **How to use:** prerequisites, inputs, a real supported invocation, and numbered user steps.
5. **Expected results:** artifacts, save-location rules, scope, confirmations, and side effects.
6. **Limitations and source:** installed versus upstream capability, relevant version/scope, and
   links to the exact instructions. Do not invent defaults, aliases, algorithm guarantees, or tests.

Keep the explanation concise and scale the detail to the subject. Prefer one concrete example
over copying a guide. For `/skillvault-discovery explain playwright`, explain Playwright's
browser automation first, then describe how `webapp-testing` guides its use. Do not imply that
installing the guide installs Playwright or its browsers, or that their availability was checked.
`/skillvault-discovery evaluate` assesses adoption/upsert value; this command explains the
requested subject and how to use it without an adoption recommendation.

## Boundaries

Read-only: do not install, update, execute, rewrite, schedule, commit, or publish while explaining
a skill, tool, or product.
Command examples are examples, not authorization to run them. Do not expose secrets or private
source content in public examples. State what remains unverified.