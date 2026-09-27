# Self Improving Evaluation

- Evaluated: 2026-09-26
- Requested name: `self improving`; multiple unrelated candidates use similar names
- Selected variant: `hueyexe/self-improving-ai`, skill `self-improving`, the exact-name directory match
- Canonical repository reported by the listing: https://github.com/hueyexe/self-improving-ai
- Inspected source: expanded skill instructions on https://skills.sh/hueyexe/self-improving-ai/self-improving
- Version/revision: Unknown; the repository page and contents API returned HTTP 404 during this assessment
- License: Unverified; an MIT field in an example template does not establish the package's license
- Skill recommendation: Defer adoption pending accessible authoritative source and licensing
- Installed recommendation: Keep the existing memory, rules, and SkillVault authoring workflows

## Identity and Evidence

The inspected global/current-project inventory and local/official SkillVault catalogs contained no
matching self-improvement skill. No optional source-cache catalog was present. Public lookup found
several variants. With no specific URL or clarified source selection, this assessment uses the
exact-name `self-improving` listing and does not treat other projects as interchangeable.

The registry's Show more section was expanded and its full displayed instructions read. The linked
GitHub repository was unavailable; this could reflect removal, renaming, or access restrictions.
It does not prove the repository never existed. Source files, revision, license, supporting assets,
and package integrity could not be checked. Registry audit badges were not independently verified.

The `zhaono1/agent-playbook` self-improving-agent listing and `pskoett/self-improving-agent` are
different candidates. The latter's current README and relocated skill entrypoint explicitly describe
an OpenClaw-only package and link a separate original multi-agent version. Neither substitutes for
the selected variant in this recommendation.

## Purpose and Workflow

The displayed skill improves future instructions and procedures from verified task experience.
It does not claim to retrain the underlying model. Its audience is coding-agent users who want
fewer repeated mistakes and less repeated steering across tasks.

- Near task completion, identify durable lessons from corrections, verified root causes, reusable
  workflows, or validation that caught a plausible mistake. Otherwise make no change.
- Choose the right destination: a skill for procedures, host memory for stable facts/preferences,
  repository guidance for local conventions, or nowhere for temporary or redundant observations.
- Read existing skill owners and edit canonical sources before creating new guidance. The text
  rejects parallel memory stores, raw logs, secrets, speculative lessons, and unnecessary new skills.
- Make a small change and validate its structure, triggering experience, and relevant behavior.
  It proposes candidate/validated/proven maturity metadata for newly extracted skills.
- Its default permits clear, low-risk global skill edits, but the Mutation Boundaries section
  explicitly preserves stronger host approval policies and forbids unrequested publication,
  dependency installation, or transmission of project content.

## Value, Fit, and Overlap

Value: Medium incremental value for this environment. The useful addition is a concise decision
about whether a lesson merits a procedural change, rather than recording every event or automatically
creating a skill. Reusing host memory and validating the proposed behavior are sensible principles.

Fit: A lightweight retrospective and promotion procedure, potentially within existing authoring
guidance. A new runtime, agent framework, memory database, or automatic worker is not necessary.

The installed [rules workflow](../../skills/core/rules/SKILL.md) already requires an authoritative
target and confirmation for persistent rule changes. Its
[management procedure](../../skills/core/rules/references/manage.md) checks duplication, conflicts,
and weakened requirements before promotion. [SkillVault authoring](../../skills/core/skillvault-authoring/SKILL.md)
already resolves canonical sources and validates skill changes; installed-copy updates belong to
the guarded installer. Host memory already supplies a place for non-procedural learning.

Keep these existing owners. The candidate's global-first fallback and direct skill-file workflow
would need to use SkillVault's catalog, source resolver, approval rules, and guarded copy updates.
Its instruction to honor stronger host policies is a mitigation, not evidence that it bypasses them.

## Risks and Recommendation

- Source availability and licensing are unresolved. Do not import or install a registry snapshot
  as though its current source, license, or package contents were verified.
- A single successful workaround can be overgeneralized. Require an observed cause, appropriate
  scope, and a useful check before turning it into durable guidance; preserve unresolved uncertainty.
- Global edits can affect unrelated repositories. Promotion must retain explicit permissions,
  project-specific constraints, canonical ownership, and existing validation requirements.
- Recurring notes can become stale or duplicate rules. Prefer an existing owner and remove or
  correct invalid guidance through its approved workflow, without creating another memory store.

Standalone use: The displayed decision checklist is worth considering manually; automatic editing
or installation is deferred. Skill recommendation: Defer this upstream bundle until the exact
source, revision, and license can be inspected. Harness integration: Reuse existing authoring and
rule-management routes rather than introducing a self-modifying controller or schedule.

## Applied Locally

After a separate request to improve repository skills, native guidance was added to
[SkillVault authoring](../../skills/core/skillvault-authoring/references/upsert.md#improve-from-task-experience)
and [rule management](../../skills/core/rules/references/manage.md#lessons-proposed-as-rules):

- Separate procedures, host-memory facts, repository conventions, rule proposals, and observations
  that merit no durable change. The destination does not grant writing permission.
- Verify the cause rather than treating every nonzero exit or successful workaround as a lesson.
- Prefer the existing owner and check both the triggering case and a nearby valid case before
  generalizing the guidance. Preserve deferred choices and rule-change confirmation.
- Keep the four core rules, canonical-source editing, and guarded installed-copy workflow unchanged.

These are original SkillVault instructions for its existing workflows, not an import of the upstream
package or its metadata template. No new skill, learning store, automatic writer, or schedule was
introduced. The upstream adoption recommendation remains Defer: its source, revision, and license
are still unverified. Reconsider it when an accessible canonical source or a different intended
variant is supplied.

The candidate, hooks, extraction helpers, and upstream installer were not executed. This remains
a provisional source review, not a runtime test or security audit of that package.

## Sources

- [Expanded Self Improving listing](https://skills.sh/hueyexe/self-improving-ai/self-improving)
- [Reported source repository, unavailable during review](https://github.com/hueyexe/self-improving-ai)
- [Distinct agent-playbook listing](https://skills.sh/zhaono1/agent-playbook/self-improving-agent)
- [Distinct OpenClaw package README](https://github.com/pskoett/self-improving-agent/blob/master/README.md)
- [Original multi-agent source linked by that README](https://github.com/pskoett/pskoett-ai-skills/tree/main/skills/self-improvement)