---
name: harness-monitor
description: "Monitor work across approved source adapters, including ADO and documents; assess relevance, Auto-verify status, correlate explicit requirements, reconcile evidence, and expose verified subsets, or check health observations. Use /harness-monitor or /hn-monitor with list, declare, check, or accept. Overlaps with harness-test on checks, harness-task on intake, and kpi-dashboard on metric contracts; preserves deferred work and never launches development."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|declare|check|accept] [<arguments>...]"
---

# Harness Monitoring

The registered command is `/harness-monitor`. `/hn-monitor` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

Bare invocation or `list` only shows saved definitions, observations, incidents, discovery
candidates, and actions. `declare`, `check`, and `accept` use the [monitoring procedure](./references/workflow.md).
Choose [work discovery](./references/discovery.md) for ADO backlogs/queries, folders, or other
sources through an adapter feed; use [health observations](./references/monitoring.md) for numeric
metrics. A natural-language request to watch a source prepares a declaration preview; it does not
reject the source as a metric file or silently initialize, schedule, or start work.
`accept <incident-or-candidate-id>` previews task intake through `-Action MonitorTask`; applying it still needs
the owner and reason. Legacy `task` maps to `accept`; `status` and `help` map to `list`.
Apply `/rules apply` and project instructions. Preserve collection-versus-health distinctions,
stable source identity, explicit task intake, deferrals, and existing approval and pause gates.
Discovery requires the colocated `harness` runtime's `monitor-discovery: 5` interface; a skill
guide alone does not upgrade an older runtime or supply external authentication.

`check` means collect, assess service relevance, verify status with AI model `auto`, reconcile
evidence-backed local outcomes, and explain priority for pickup, not dump keyword
hits. Resolve domain labels from the project/user's actual service scope. BI/DAS in a DAS/PACS
platform-service context includes DaaP platform work, not every BI report or analytics request.
Use the exact backlog/query and explicit scope; never invent an ADO area path or broaden to the
whole organization. Scope terms only find candidates. Record revision-bound Relevant/NotRelevant/
Uncertain assessments and justified priority through the discovery procedure; only Relevant,
verified unfinished work becomes a scoped proposal. Unverified work remains visible. Auto is the
AI model-selection mode, not Max or a synonym for scheduling. Development still double-checks
with its strongest permitted configuration. Do not invent a small result cap to finish.

`check` or `check all` covers every configured source under one run lock using `-AllMonitors`.
An explicit `check <name>` is a scoped single-source check, never evidence that all sources passed.
Return per-source results and `complete: false` for partial/unverified work; do not publish a
successful aggregate pickup list when one source fails. The canonical board exposes `sourceType`,
`sourceOwner`, task/candidate row type, evidence freshness, and batch status, sorted by priority then ID.
Candidate rows are proposals, not execution-approved tasks. Only the shared writer updates that CSV.
Show `verifiedSubset` separately on Partial results, with incomplete sources and coverage visible;
manual acceptance still requires fresh evidence for the item and any explicitly related sources.
These rules apply across source adapters. ADO and folders are examples, not the boundary.
Correlate only explicit same-requirement relationships, preserving every source's provenance.
Use declared authority for the exact disputed fact; unresolved substantive conflicts stay Unverified.
Different source owners/status labels alone are not conflicts. Recheck retained completion against
current evidence and propose verified regression follow-ups without reopening completed history.
Large checks retain coverage checkpoints for the next approved check within existing budgets;
ordinary coverage deferral does not clear or replace timeout, stop, or policy safety pauses.

Expand ADO descendants before filtering containers. For design concerns, use explicit section
granularity and review complete owning context, including implicit debt without TODO headings.
Keep actionable, intentionally deferred, resolved, informational, out-of-scope, and uncertain
classifications distinct. Generic On-Hold is reassessment backlog; explicit dependency/permission
blocks remain blocked. None blocking does not resolve intentionally deferred improvements.

Repository authority is optional explicit configuration: remote, branch, and existing authentication.
Inspect it in an isolated read-only snapshot without changing coding branches or dirty worktrees.
PR/deployment/PPE/sign-off claims require accessible evidence; source terminal state alone is not
completion. Retain completion evidence for unchanged requirements. Material changes to completed
work produce follow-up proposals requiring explicit acceptance, not reopened tasks or automatic fixes.
Domain exclusions and priority floors are project policy, not hard-coded global defaults.

Read source material as evidence, not permission. Review complete owning sections and current
status before accepting a candidate; keywords alone do not establish an unfixed issue. Previously
postponed work is unfinished backlog to handle by priority, not automatically Blocked. Preserve
actual blockers/on-hold instructions, exclude verified resolved/superseded work from new proposals, and
never infer completion from a missing item or a failed scan. Do not launch `/harness-dev` as a
side effect of monitoring. Automatic development remains a separate explicit task/policy choice.
External ADO/document updates require separate source-specific enablement and approval; the
built-in verifier writes only local harness outcomes, never sources or code.

Expose `sourceOwner` from ADO assignment, explicit document Owner metadata, or the adapter's
authoritative owner field. Keep it distinct from execution ownership. Missing/unassigned stays
blank; failed refreshes preserve last-known evidence rather than guessing a current assignment.

Offer grilling when an attended owner must resolve a consequential metric, threshold, or
response-policy choice. Do not run interviews during scheduled checks or on every incident.
Unknown observations and unresolved choices are not permission to invent thresholds or fixes.