---
name: dri
description: "[investigate] Investigate a production incident as a read-only copilot for the on-call DRI: gather evidence, separate facts from hypotheses, and draft next steps and updates. Also holds the proposed DRI-agent design (staged roles, preflight checks, evaluation) while it grows. Service specifics come from the project's private DRI profile. Never changes production or posts updates without explicit approval. Overlaps with harness-monitor on incidents: harness-monitor detects health breaches and proposes work; dri investigates one incident."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|investigate] [<arguments>...]"
---

# DRI Copilot

`/dri` helps the human DRI (directly responsible individual) on call investigate an incident. It
gathers evidence, keeps facts apart from guesses, and drafts the next step and the update. The DRI
stays accountable: every decision, mitigation, ticket change, transfer, and closure stays theirs.

This skill is a starting point. `investigate` works today and is read-only. The rest of the
DRI-agent design (staged roles, preflight checks, repair plans, and evaluation) is a
[proposal](./references/proposal.md), not yet commands.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Outcome |
| --- | --- |
| `list` | Show what `/dri` can do, the proposal's status, and the project's DRI profile |
| `investigate <incident>` | Build a read-only, evidence-linked brief for one incident |

- Bare invocation, `list`, `status`, and `help` show the actions, the proposal's status, and whether
  a DRI profile was found. They query nothing and write nothing. Unknown actions show help.
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
