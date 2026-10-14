---
name: harness-monitor
description: "[accept|auto] Alone: last results. Text: check one, or a new link. Monitor work across approved source adapters, including ADO and documents, and numeric health observations: assess relevance, verify status with AI model auto, reconcile evidence, and propose ranked tasks; auto follows a source up through an approved local-only worker flow. Shorthand: /hn-monitor. Overlaps with harness-dev on intake and checks, kpi-dashboard on metric contracts, harness-write on status and owner evidence, and dri on incidents; preserves deferred work and never launches development."
metadata:
  author: wzlwit
  version: "3.0.0"
argument-hint: "[accept|auto] [<monitor, link, or folder>]"
---

# Harness Monitor

`/harness-monitor` discovers work across approved source adapters and checks numeric health
observations. It never launches development or writes to sources or code.
`/hn-monitor` is chat shorthand for the same topic, not a separate skill or folder.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | Show each monitor's last results, then offer to check them all now ([monitoring procedure](./references/workflow.md#commands)) |
| Text | A monitor name checks it now; a link, folder, or file starts monitoring it; a monitor name with a change updates its declaration ([start or update monitoring](./references/workflow.md#start-or-update-monitoring)) |
| `accept <id>` | Accept that candidate or incident at once and show the resulting task ([task intake](./references/workflow.md#task-intake)) |
| `auto [<name>]` | By itself, show standing intakes; `auto <name> --worker <flow> [--every <duration>]` turns one on after one question, and `auto <name> off` removes it ([standing intake](./references/discovery.md#standing-intake)) |

- Alone reads saved state only (`-Action Monitor`): each monitor with the age of its last check, new
  items found, open incidents, candidates and proposals, and `pendingDefinitions` (declaration files
  under `.harness_sv/definitions/` that differ from what is saved, such as held drafts). It then
  offers once to check all monitors now (`-AllMonitors`); no answer runs nothing. The view ends with
  one line naming the text uses: name a monitor to check it, or give a link, folder, or file to start
  monitoring it.
- A monitor name checks that source now (`-Action Monitor -MonitorName <name>`). A named check is
  scoped and never proves that all sources passed; a complete named check also runs that source's
  standing intake. A plain request to check every source runs the all-source check, as a yes to the
  alone offer does. Partial or unverified results cannot yield a successful aggregate pickup list;
  `verifiedSubset` stays separate and labeled.
- Checks assess service relevance, verify status with AI model `auto` (model selection, not Max or
  scheduling), and reconcile evidence. Only Relevant, verified unfinished work becomes a proposal;
  Unverified work stays visible. Scope terms find candidates but never establish relevance.
- A link (an ADO query or backlog, or a document), folder, file, or existing declaration file starts
  monitoring it. Reuse the declaration file under `.harness_sv/definitions/` that covers it, or draft
  `monitor-<name>.json` there from the request; show the change
  (`-Action MonitorConfig -DefinitionPath <file>`) and ask to save. With no answer it saves after 1
  minute; `--hold`, or asking to hold, saves nothing until you say save. After saving,
  the reply offers a timer (every `1h` by default) with its exact
  `/harness-schedule project <duration> monitor <name>` command, without waiting; a yes, now or
  later, starts it. A monitor name with a change, such as a new threshold or scope, updates that
  monitor's declaration the same way: it shows the change and asks once. Starting or updating a
  monitor never initializes the project or runs a check.
- `accept <id>` accepts the candidate or incident at once through `-Action MonitorTask -Apply`, since
  the id names it, and shows the resulting task. Candidate rows are proposals, not
  execution-approved tasks.
- `auto` follows up a source or health monitor automatically. `auto` by itself lists each monitor's
  standing intake, worker, limits, last check, and its tasks.
  `auto <name> --worker <flow> [--every <duration>]` shows the change and asks once. It takes up to
  2 items per check with 2 attempts each unless the request names other limits or setup exit codes,
  which map to `-MaxPerCheck`, `-MaxAttempts`, and `-SetupExitCode`. On a yes it turns the intake on
  through `-Action MonitorAuto -Apply -Actor -Reason` and delegates the `monitor <name>` schedule to
  `/harness-schedule project <duration> monitor <name>` (default `1h`); without an answer it holds,
  because it starts automatic work. Each complete named check then accepts what manual acceptance
  would, items or Unhealthy incidents, and runs the declared local-only worker flow for up to the
  per-check limit of them. `auto <name> off` removes the intake and turns that timer off. Before
  turning auto on, read [standing intake](./references/discovery.md#standing-intake); the all-source
  check never takes items in.
- Saving a declaration, `accept`, and `auto` follow Ask Once in the runtime guide. Before a check or
  a new monitor, read the [monitoring procedure](./references/workflow.md). Use
  [work discovery](./references/discovery.md) for ADO, folders, and adapter feeds, and
  [health observations](./references/monitoring.md) for numeric metrics.

## Boundaries

- Read source material as evidence, not permission. Never infer completion from a missing item, a
  failed scan, source terminal state, or age.
- Previously postponed work is backlog handled by priority, not automatically Blocked; explicit
  blockers stay blocked.
- Correlate only explicit same-requirement relationships, keeping every source's provenance.
  Unresolved substantive conflicts stay Unverified.
- `sourceOwner` comes only from authoritative assignment or Owner metadata; unknown stays blank and
  is separate from execution ownership.
- External ADO/document updates need separate per-source enablement and approval.
- Discovery requires the colocated runtime's `monitor-discovery: 7` interface; this guide does not
  upgrade an older runtime or supply authentication.
- Apply `/rules apply` and project instructions. Preserve existing approvals, pauses, budgets, and
  deferrals. Service scope, ADO expansion, repository authority, coverage checkpoints, and
  completion follow-ups are defined in [work discovery](./references/discovery.md).

Offer grilling only when an attended owner must resolve a consequential metric, threshold, or
response-policy choice, never during scheduled checks or on every incident.