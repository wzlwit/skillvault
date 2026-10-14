---
name: dri
description: "[investigate] Alone: DRI status. Text: investigate that incident. Investigate a production incident as a read-only copilot for the on-call DRI: gather evidence, separate facts from hypotheses, and draft next steps and updates. Also holds the proposed DRI-agent design (staged roles, preflight checks, evaluation) while it grows. Service specifics come from the project's private DRI profile. Never changes production or posts updates without explicit approval. Overlaps with harness-monitor on incidents: harness-monitor detects health breaches and proposes work; dri investigates one incident."
metadata:
  author: wzlwit
  version: "2.0.0"
argument-hint: "[investigate] [<incident ID or link>]"
---

# DRI Copilot

`/dri` helps the human DRI (directly responsible individual) on call investigate an incident. It
gathers evidence, keeps facts apart from guesses, and drafts the next step and the update. The DRI
stays accountable: every decision, mitigation, ticket change, transfer, and closure stays theirs.

This skill is a starting point. `investigate` works today and is read-only. The rest of the
DRI-agent design (staged roles, preflight checks, repair plans, and evaluation) is a
[proposal](./references/proposal.md), not yet commands.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | Show whether the project's DRI profile was found and the proposal's status, then ask which incident |
| Text | An incident ID or link: [investigate it](./references/investigate.md), read-only, the same as `investigate` |
| `investigate <incident>` | [Build a read-only, evidence-linked brief for one incident](./references/investigate.md); without an incident, ask which one |

- Alone shows whether the project's DRI profile was found, and where, and the proposal's status,
  then asks which incident to investigate. It queries nothing and writes nothing; no answer changes
  nothing.
- The alone view ends with one line naming the text uses: paste an incident ID or link to
  investigate it.
- Text that is an incident ID or link runs the same read-only investigation as `investigate`. When
  it is unclear whether the text names an incident, ask.
- Before `investigate`, read the [investigation procedure](./references/investigate.md). Before
  changing the design or adding a command, read the [proposal](./references/proposal.md).

## Project Profile

Service details never go in this skill: evidence sources and access, queries, success signals, the
error-signature catalog, owners and routing, runbooks, retention limits, and the operations a DRI may
approve. They live in the working project's DRI profile, which can stay private. Use the file the
user names, otherwise `dri-profile.md` at the project root or in its documentation folder. Without
one, ask for the sources and say what is missing. Never invent sources, queries, owners, signals,
or thresholds.

When the team already runs incident automation or DRI skills for an incident type, use those first
and treat `/dri` as the gap filler. Don't build a second agent for the same queue.

## Rules

- Read-only by default. Read tickets, telemetry, configuration, and code with the user's existing
  access; never broaden it.
- Every side effect needs the DRI's explicit approval of that exact action: a ticket comment or
  status change, a transfer, a mitigation, a configuration change, a rerun, or closure. Even then,
  run only operations the profile allows, show a dry run first, and verify the outcome afterward.
- Link each conclusion to its evidence. Label facts, hypotheses, and missing evidence; unknown
  stays Unknown. A failed, empty, or timed-out query is missing evidence, not a negative finding.
- Keep credentials, tokens, customer data, and sensitive log content out of prompts, briefs, and
  drafts. Cite identifiers and query names instead.
- Drafts stay drafts. On request, `/harness-write` can prepare a status email or tracker and
  `/handoff` a transfer note.
- Apply `/rules apply` and project instructions.
