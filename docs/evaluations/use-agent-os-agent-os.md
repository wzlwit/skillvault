# AgentOS Runtime Evaluation

- Evaluated: 2026-09-18
- Canonical source: https://github.com/use-agent-os/agent-os
- Website: https://useagentos.dev/
- Reviewed revision: `f1b50c8b5e62b5f72f5627afeceec96db5618b7e`
- Declared package: `use-agent-os`, version `2026.9.18`, Python `>=3.12`
- Maturity: package metadata declares Alpha; the repository lists release `v2026.9.18`
- Declared license: Apache-2.0, with separate NOTICE and third-party notices
- Scope: Public repository documentation and package metadata at the pinned revision; no installation, runtime test, benchmark, or security audit
- Recommendation: Defer adoption or a new integration skill; retain as an architecture reference
- Installed recommendation: Keep the existing harness skills

## Purpose and Meaning

AgentOS is a local-first AI agent runtime with a common operating environment: a Web UI,
CLI, and messaging channels connect to a local gateway that manages sessions, tool use,
approvals, memory, scheduling, and model selection. The documented control UI is at
`http://127.0.0.1:18791/control/`. It is a complete application, not just a collection of
prompts, an operating-system replacement, or a dashboard skin for existing coding agents.

Its named agents are runtime profiles with an identity, workspace, and default model.
Sessions hold conversation continuity; skills supply reusable instructions and scripts.
For example, a research agent can maintain context across conversations and be the target
of scheduled work, with activity inspected through the same control UI.

The current product positioning emphasizes agentic trading, but its documented facilities
also support research, coding, document generation, and general personal automation.
The audience is users who want a persistent assistant across several interaction surfaces
and developers integrating that assistant into other tools.

This is a specific implementation of the Agent OS concept discussed in the
[video assessment](deepseek-harness-vs-hermes-video.md). The video and pinned comment do
not establish that Julian Goldie's Local Studio / Agentic OS dashboard uses this repository.
Evaluate this source on its own merits rather than identifying products by name alone.

## Documented Capabilities

- **One runtime across surfaces:** Web UI, CLI, gateway, and chat channels share the turn
  execution path, tools, approvals, memory, and usage accounting.
- **Model routing:** The on-device Pilot Router selects a model tier per turn. Local routing
  avoids a separate external classifier request, but the chosen model may still be remote.
  Lower cost per successful task is a goal, not a verified result of this assessment.
- **Persistent state:** Sessions and history are stored durably. Markdown memory supports
  keyword and semantic recall, with local embeddings documented as an option.
- **Operational controls:** Named agents, subagents, scheduled jobs, approval views,
  diagnostics, artifacts, and token/cost reporting are documented product features.
- **Skills and integration:** Skills are instructions plus optional scripts. The project
  documents MCP tool consumption and a stdio bridge through which another client can call
  AgentOS session workflows. This is a possible integration surface, not a tested SkillVault adapter.
- **Migration:** The Hermes importer copies supported persona, memory, skills, and configuration
  into AgentOS-native state. Active sessions and process state are not imported, and several
  runtime settings are deferred. Importing data is not live shared memory or orchestration of Hermes.

These describe the documented design and interface, not independently exercised behavior.

## Value and Fit

**Value: Medium for immediate SkillVault adoption; high as a relevant architecture reference.**
The most useful ideas are the unified operator view, durable context, and cost-aware routing.
They address a broader persistent-assistant workflow than a skill catalog alone.

**Fit: An external runtime, with a possible reference-only skill if selected for actual use.**
A future guide could cover terminology, supported setup paths, workspace and permission
configuration, memory, diagnostics, and integration boundaries. Copying its scheduler or
turn loop into a skill would not turn it into a drop-in SkillVault component.

The installed [harness](../../.github/skills/harness/SKILL.md) already owns project selection
and controller state; [harness-dev](../../.github/skills/harness-dev/SKILL.md) owns tracked
execution with required checks and independent review;
[harness-review](../../.github/skills/harness-review/SKILL.md) owns the review workflow; and
[harness-timer](../../.github/skills/harness-timer/SKILL.md) owns approved schedule dispatch.
AgentOS overlaps execution, persistent state, skills, approvals, and scheduling, but its
documented generic agent operations do not establish equivalent project and review contracts.
Keep these installed owners rather than transferring their responsibilities implicitly.

AgentOS documents shared discovery from `~/.agents/skills` and `<workspace>/.agents/skills`,
plus configurable extra directories. The current SkillVault copies reviewed here use
`.github/skills` and `.copilot/skills`. File discovery and Markdown compatibility alone do
not establish compatible tool APIs, approval behavior, or sibling runtime dependencies.
No installed-copy migration or shared skill-directory setup was performed.

## Risks and Limits

- **Windows isolation:** The README says the Linux/macOS kernel sandbox backend is not
  available on Windows. The detailed tool guide also says shell write-target scanning is
  defense in depth, not a security boundary. Do not equate permission prompts with OS isolation.
- **Tool reach:** Browser automation is documented as running outside the kernel sandbox.
  A local gateway does not make external models, web requests, channels, or installed skills local-only.
- **Installation trust:** The Windows portable instructions request administrator execution
  and describe bypassing an unsigned-app warning. Those instructions were not followed or
  endorsed here. Review the release and a least-privilege setup path before any approved trial.
- **Separate control plane:** AgentOS adds its own state, credentials, permissions, and scheduler.
  Using it alongside the harness requires explicit task ownership; pointing both at the same
  writable workspace does not establish a safe handoff.
- **State migration:** The documented Hermes import is partial and does not create a full
  pre-migration home snapshot. No migration, credential copying, or live schedule changes are authorized.
- **Trading exposure:** Trading capabilities are part of the current product positioning.
  This evaluation does not assess trading outcomes or authorize wallet access or transactions.
- **Unverified claims:** No cost savings, model-routing accuracy, crash recovery, sandbox
  enforcement, release integrity, or interoperability were tested. The source remains an Alpha
  dependency with an evolving operational surface.

The README credits OpenSquilla as its base and OpenClaw/Hermes as influences. Preserve verified
authorship and review the root license and third-party notices before adapting any bundled material.
This evaluation links to upstream documentation rather than redistributing it.

## Recommendation

**Defer a new SkillVault integration or installation.** This is worth considering as a
standalone persistent-assistant platform, but it is not a demonstrated upgrade to the existing
coding harness or the confirmed source of the video's dashboard.

Reconsider when there is a concrete workflow needing its Web UI, channels, memory, or routing.
For a separately approved trial, use a non-sensitive test workspace and measure correctness,
cost, intervention, and restart behavior. Test any MCP handoff before sharing state or schedules.
If it is selected, a narrowly scoped `agentos-runtime` reference guide could coexist with the
current skills; runtime installation and task integration would remain separate decisions.

Suggested upsert: None now. No skill bundle, catalog entry, installed copy, application source,
schedule, credential, Git index, or published content was changed.

## Sources

- [Repository and release listing](https://github.com/use-agent-os/agent-os)
- [Package metadata at the reviewed revision](https://github.com/use-agent-os/agent-os/blob/f1b50c8b5e62b5f72f5627afeceec96db5618b7e/pyproject.toml)
- [Product guide](https://github.com/use-agent-os/agent-os/blob/f1b50c8b5e62b5f72f5627afeceec96db5618b7e/README.product.md)
- [Durable agents](https://github.com/use-agent-os/agent-os/blob/f1b50c8b5e62b5f72f5627afeceec96db5618b7e/docs/agents.md)
- [Tools, approvals, and sandbox](https://github.com/use-agent-os/agent-os/blob/f1b50c8b5e62b5f72f5627afeceec96db5618b7e/docs/tools-and-sandbox.md)
- [Skills and shared directories](https://github.com/use-agent-os/agent-os/blob/f1b50c8b5e62b5f72f5627afeceec96db5618b7e/docs/features/skills.md)
- [MCP bridge](https://github.com/use-agent-os/agent-os/blob/f1b50c8b5e62b5f72f5627afeceec96db5618b7e/docs/mcp-server.md)
- [Migration contracts and limitations](https://github.com/use-agent-os/agent-os/blob/f1b50c8b5e62b5f72f5627afeceec96db5618b7e/MIGRATION.md)
- [Security reporting policy](https://github.com/use-agent-os/agent-os/blob/f1b50c8b5e62b5f72f5627afeceec96db5618b7e/SECURITY.md)