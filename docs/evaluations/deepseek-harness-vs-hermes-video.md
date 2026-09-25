# DeepSeek Harness vs Hermes: Video Assessment

- Evaluated: 2026-09-18
- Source: https://www.youtube.com/watch?v=VjNHV3PKXhQ
- Title: I Tested DeepSeek Harness vs Hermes... Here's the Winner!
- Creator: Julian Goldie SEO
- Published: 2026-09-17, as displayed on the watch page
- Scope: Full timestamped transcript, an inspected video frame at 0:47, public description and comments, and primary-documentation cross-checks; runtime behavior and benchmarks not independently verified
- Recommendation: Defer a video-derived skill or runtime change
- Installed recommendation: Keep the existing harness; no replacement or installation

## Access and Evidence

The first attempt through the integrated browser was blocked by YouTube's sign-in/bot check and
returned no captions. After the user opened the video in Firefox, Windows accessibility exposed
the page and its transcript. The complete transcript was read from 0:00 through the final segment
at 9:03; the player reports a 9:08 duration. This supersedes the earlier description-only assessment.

No audio was separately downloaded or transcribed. Transcript spellings may contain recognition
errors, so product names are normalized only where the context is clear. A later window-bound
Firefox capture produced a decoded video frame at 0:47, which was inspected. An earlier mismatched
capture was discarded; poster-only captures and static chapter thumbnails are not demonstration
evidence. The inspected frame verifies the visible interface, not its implementation, successful
execution, shared-memory behavior, or measured performance. Neither runtime was reproduced.

## What the Presenter Says

- **0:28:** Both agents are said to run inside the presenter's own Agent OS dashboard with shared
  memory. At 2:50 and 8:48, that setup is offered as a downloadable ZIP through the promoted
  community/masterclass. This does not identify it as Agno AgentOS or Builder Methods Agent OS,
  or establish that shared memory works automatically between standard DSH and Hermes installs.
- **0:45-1:02:** The presenter describes asking DSH Creator mode for a task panel and a daily
  scheduler. This illustrates interface customization, not evidence that scheduled work executed
  correctly or retained state across failures.
- **4:27-4:58:** The presenter reports fewer failures with DSH, recommends it to beginners, and
  acknowledges its developer-preview status. No failure counts or repeatable reliability protocol
  are supplied in the transcript.
- **5:12-5:38:** DSH is described as faster and better at building a dashboard, while Hermes is
  said to time out on large coding jobs. The presenter explicitly attributes part of the advantage
  to a newer DeepSeek model, so the comparison does not isolate the agent runtime.
- **7:02-7:46:** The actual recommendation is DSH for coding/building and Hermes for scheduled
  background work and memory, managed through the presenter's dashboard. If forced to choose one,
  the presenter prefers DSH. This is a personal workflow recommendation, not a universal benchmark.

The introduction identifies a digital avatar. Community/masterclass promotion appears around
2:41-3:23 and the closing section from 7:51 onward. This is relevant commercial context, not proof
that the technical claims are false. Neither the transcript nor the description provides the
dashboard's integration code or a reproducible test package.

## What the Frame Shows

At **0:47**, the recording shows a browser-based dashboard branded **Local Studio / Agentic OS**
at `localhost:3737/deepseek-coder`. This is the presenter's displayed address, not a service run
for this assessment. Its outer navigation includes Mission Control, Paperclip, AI Agent Mastermind,
Pipeline, and agent entries for Claude, Hermes, and Antigravity.

The DeepSeek Harness interface is visibly nested inside that dashboard under a section labeled
"The harness, live in the dashboard." It retains its own New Session control, workspace list,
conversation area, and mode selector. The outer dashboard also has a job input and Run button.

In this video, "Agent OS" therefore refers to the surrounding multi-agent management dashboard,
not DeepSeek Harness itself or a demonstrated operating-system replacement. The visible branding
is **Agentic OS**. Together with the presenter's own-dashboard description, this supports a
custom dashboard interpretation. It does not identify the underlying framework, establish a
connection to Agno or Builder Methods, or prove that the listed agents share memory or coordinate
jobs correctly. A common interface is visible; those integration behaviors remain claims.

## Comment Evidence

On 2026-09-18, the page displayed nine comments. They were read in the Top and Newest views,
and the creator's comment was expanded. A pinned comment by **@JulianGoldieSEO** says:

> Get the Agent OS & DeepSeek + Hermes Masterclass

Its [permalink](https://www.youtube.com/watch?v=VjNHV3PKXhQ&lc=UgzwjksMj6iTDH3NfQh4AaABAg)
links to the [AI Profit Boardroom](https://www.skool.com/ai-profit-lab-7462/about). The public
landing page identifies a private, paid community by Julian Goldie, matching the promotional
banner visible in the inspected dashboard frame. No members-only material was accessed.

This is direct creator evidence that Agent OS is promoted through his community/masterclass
offering. It supports the dashboard interpretation, but does not establish the underlying
framework, code authorship, license, or shared-memory implementation. None of the nine displayed
comments reviewed supplied a source repository, installation details, or independent confirmation
of those integration behaviors. This observation does not cover hidden, deleted, or later comments.

## Cross-Checks

- **DSH plugins:** Official architecture documentation supports the plugin-based runtime claim.
  Model adapters, tools, persistence, and the agent loop are configurable components. DSH also
  documents Web, desktop, headless, SDK, and ACP interfaces. The presenter's browser-versus-desktop
  contrast describes a chosen setup, not a strict product boundary. Extensibility alone does not
  prove every Hermes capability already has a reliable DSH equivalent.
- **Hermes memory and learning:** Nous Research documents persistent memory, conversation search,
  and creating/updating reusable skills. These mechanisms can preserve useful knowledge across
  sessions. They are not, by themselves, evidence of automatic model-weight training or reliably
  better answers. Upstream also documents CLI, desktop, and messaging interfaces.
- **Speed and reliability:** Same hardware and task descriptions do not alone isolate the runtime.
  A defensible comparison needs exact versions, models/providers, prompts, tools, permissions,
  previous memory, repeated runs, correctness checks, failures, elapsed time, and API cost.
  Those controls and measured results are not established by the transcript. The acknowledged
  model difference is a concrete comparison problem. Reported Hermes timeouts do not establish
  that it is generally unsuitable for substantial coding tasks. GitHub popularity is not a
  substitute for correctness, reliability, or security evidence; launch-growth claims were not
  independently checked.
- **Safety:** DSH's official notice explicitly identifies a developer preview without a security
  audit. The presenter's appeal to Cordis's prior history at 2:24-2:40 does not establish the
  maturity or security of the complete DSH application. Running locally does not imply model
  requests stay local or that plugins cannot access sensitive files. Provider routing, tool
  permissions, and storage need their own review.

## Fit and Recommendation

Value is medium as an introductory walkthrough and personal workflow example, but low as evidence
for a general speed/reliability ranking. Its best fit is supporting research, not a new standalone
SkillVault skill. Keep the distinction between documented capabilities and the presenter's experience.
The installed [development](../../.github/skills/harness-dev/SKILL.md) and
[review](../../.github/skills/harness-review/SKILL.md) guides already own tracked execution,
validation, and independent review. Keep them. This assessment does not change the separate
[DSH evaluation](deepseek-harness.md), which recommends a focused reference guide and defers
runtime integration.

For a later approved trial, compare the same small non-sensitive task in separate disposable
projects. Use correctness and manual intervention as well as time/cost. Do not let two agents
write the same workspace independently merely because the presenter recommends using both. A shared
dashboard still needs explicit task ownership, memory permissions, and a verified handoff; it does
not remove those requirements. No new upsert or replacement is recommended from this video alone,
and no model, agent runtime, or workflow was run. The inspected frame clarifies the dashboard's
presentation; a controlled local comparison is still needed to establish performance for a
particular workload.

Project open-source licenses do not grant rights to redistribute the creator's video, course,
or transcript. This record summarizes limited observations and links to original sources only.

## Sources

- [Video, full YouTube transcript, and author-supplied description](https://www.youtube.com/watch?v=VjNHV3PKXhQ)
- [Agentic OS dashboard containing DeepSeek Harness, inspected frame at 0:47](https://www.youtube.com/watch?v=VjNHV3PKXhQ&t=47)
- [Model difference in the speed comparison, 5:12](https://www.youtube.com/watch?v=VjNHV3PKXhQ&t=312)
- [Combined-use recommendation, 7:02](https://www.youtube.com/watch?v=VjNHV3PKXhQ&t=422)
- [Single-tool preference, 7:39](https://www.youtube.com/watch?v=VjNHV3PKXhQ&t=459)
- [DSH architecture at the reviewed revision](https://github.com/deepseek-ai/deepseek-harness/blob/ddefc45fbc7f8e46dd73185e68295696d1297887/docs/architecture.md)
- [DSH safety notice at the same revision](https://github.com/deepseek-ai/deepseek-harness/blob/ddefc45fbc7f8e46dd73185e68295696d1297887/SAFETY.md)
- [Hermes Agent primary README](https://github.com/NousResearch/hermes-agent#readme), inspected on the evaluation date; no local runtime test

Only this evaluation record was authored. No skill bundle, catalog, installed copy, schedule,
credentials, Git index, or published content was changed.