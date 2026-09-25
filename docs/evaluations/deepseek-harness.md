# DeepSeek Harness

- Evaluated: 2026-09-18
- Canonical source: https://github.com/deepseek-ai/deepseek-harness
- Documentation: https://deepseek-harness.github.io/deepseek-harness/
- Reviewed revision: `ddefc45fbc7f8e46dd73185e68295696d1297887` on `master`
- Source package version: `0.1.6-alpha.2`; not a verified installed or published package version
- Author: DeepSeek AI; repository license: MIT, with separate third-party notices
- Recommendation: Upsert a reference-only guide; defer runtime integration
- Installed recommendation: Keep existing harness skills; coexist, not replace

## Purpose and Value

DeepSeek Harness (`dsh`) is an agent runtime, not a drop-in Copilot skill or a synonym for
SkillVault's harness. It targets developers building or customizing coding agents, model
integrations, and tools. Its Cordis-based plugin architecture makes the agent loop, tools,
model adapters, session persistence, and user interfaces replaceable through configuration.

Value is high for agent-runtime and plugin development, and medium as an incremental addition
to the current SkillVault setup. A focused guide would teach profile composition, provider
configuration, plugin extension points, and choosing an automation interface without duplicating
the existing task, validation, review, and scheduling procedures.

## Verified Capabilities

- Profiles include Web UI, one-shot headless, SDK JSON-RPC, minimal SDK, and ACP. TypeScript and
  Python SDK documentation describes clients using the same runtime/profile architecture.
- Profiles compose ordered bundles and configuration patches. Model adapters, tools, execution
  providers, and agent behavior are plugins; plugin management is executable package management,
  not simply loading a Markdown instruction file.
- Durable session events support history and resumption. Headless session adoption checks its
  recorded working directory, ownership, and compatible agent preset.
- The model guide covers DeepSeek and other providers, including custom OpenAI Chat Completions,
  OpenAI Responses, and Anthropic Messages endpoints. It is not limited to DeepSeek models.
- Headless mode accepts a positional task or stdin, prints final text, and exits. Its `--json`
  mode emits newline-delimited events, not one SkillVault result object. A final event can occur
  on a failed turn; consumers must check the process exit and turn-end reason.
- The reviewed root manifest requires Node `^22.19.0 || >=24.0.0` and declares `pnpm@11.7.0`
  for source development. These declarations are not proof of installation or Windows runtime
  behavior on this machine.

## Overlap and Integration

The installed [development guide](../../.github/skills/harness-dev/SKILL.md),
[review guide](../../.github/skills/harness-review/SKILL.md),
[policy guide](../../.github/skills/harness-policy/SKILL.md), and
[timer guide](../../.github/skills/harness-timer/SKILL.md) were inspected before this recommendation.
They already coordinate tasks, workspaces, independent checks, explicit permissions, durable
pauses, and schedules. Dsh overlaps in agent execution, delegation, tool policy, and session
management, but this assessment does not establish equivalent coordinator guarantees.

Keep those owners. A possible future design is SkillVault coordinating a separately approved
dsh worker, not two controllers independently scheduling or writing the same workspace.
The installed SkillVault worker constructs Copilot-specific flags and parses a single result
envelope. Changing only `runner.command` to `dsh` is not an integration: launcher arguments,
profile permissions, provider authorization, budgets, cancellation, and output parsing differ.

Before backend adoption, verify a dedicated adapter against a disposable local fixture: normal
completion, failed/aborted turns, startup failure, cancellation, read-only review, workspace
isolation, effective model/budget limits, and exact result-envelope extraction. Dsh finishing a
model turn must not substitute for SkillVault validation and independent review.

## Risks and Limits

- Upstream explicitly calls this a rapidly changing developer preview, warns of breaking
  changes, and says it has not undergone a security audit or become production-ready.
- Plugins and model-generated commands can access allowed files, credentials, processes, and
  networks. Upstream says sandboxing and approvals are not a sufficient standalone boundary
  for untrusted workloads; use a disposable or dedicated environment for an approved trial.
- The provider guide stores keys in `$DSH_HOME/.credentials.yaml` and returns redacted descriptors
  to the UI. Provider access requires its own approved credentials; existing Copilot access is
  not evidence of dsh/provider authorization. That guide does not support OAuth providers in
  its Models-page workflow yet.
- Headless default-mode reasoning goes to stderr; sessions and diagnostic logs can retain
  sensitive information. Its JSON event projection truncates non-final payloads and is not a
  lossless substitute for the session log.
- MIT permits adaptation subject to attribution/license terms; dependency notices and licenses
  still need review for any redistributed runtime or plugin. No upstream code is vendored here.
- This was a primary-documentation, metadata, and local-adapter source review, not a security
  audit, benchmark, installation test, model call, or end-to-end integration test.

## Suggested Skill

- Name: `deepseek-harness`
- Category: `skills/planning/`
- Default scope: `global`; availability does not grant execution permission
- Fit: URL-derived, reference-only guide, not a bundled runtime or automatic installer
- Description: "Configure DeepSeek Harness profiles, providers, and plugins and select headless,
  SDK, or ACP interfaces. Overlaps with harness-dev on execution; owns dsh-specific runtime
  guidance, not task orchestration or an installed backend."

Suggested authoring request: `/skillvault-authoring upsert https://github.com/deepseek-ai/deepseek-harness none`.
This is a recommendation only; no skill, adapter, provider, or runtime was created or installed.
Recheck the pinned documentation before authoring because the preview can change. Reconsider
runtime adoption when a concrete plugin/provider workflow justifies the adapter and its scoped
validation has passed.

## Sources and Verification

- [Official README](https://github.com/deepseek-ai/deepseek-harness/blob/master/README.md)
- [Safety notice](https://github.com/deepseek-ai/deepseek-harness/blob/ddefc45fbc7f8e46dd73185e68295696d1297887/SAFETY.md)
- [Architecture](https://github.com/deepseek-ai/deepseek-harness/blob/ddefc45fbc7f8e46dd73185e68295696d1297887/docs/architecture.md)
- [CLI modes](https://github.com/deepseek-ai/deepseek-harness/blob/ddefc45fbc7f8e46dd73185e68295696d1297887/apps/cli/README.md)
- [Headless contract](https://github.com/deepseek-ai/deepseek-harness/blob/ddefc45fbc7f8e46dd73185e68295696d1297887/packages/bundle/headless/README.md)
- [Provider configuration](https://github.com/deepseek-ai/deepseek-harness/blob/ddefc45fbc7f8e46dd73185e68295696d1297887/docs/user/guide/providers.md)
- [Source manifest](https://github.com/deepseek-ai/deepseek-harness/blob/ddefc45fbc7f8e46dd73185e68295696d1297887/package.json)
- [MIT license](https://github.com/deepseek-ai/deepseek-harness/blob/master/LICENSE)

The shared inventory checked 46 installed entries plus session locations; no DeepSeek entry
matched. The local and published SkillVault catalogs had no match, and no source-cache catalog
was present. No prior evaluation of this canonical source was found. The record destination was
verified through SkillVault's read-only source resolver. No internal content was used in public
queries, and no runtime, installation, schedule, catalog, or Git index changes were performed.