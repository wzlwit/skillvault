---
name: harness-write
description: "[upsert|slots] Draft and update writing for people: evidence-grounded feature docs, onboarding, and troubleshooting guides; stakeholder trackers, meeting invites, and email updates or thread replies; and dashboards, reports, and queries; rank meeting slots offline. Shorthand: /hn-write; upsert takes doc|tracker|meeting|email|report. Overlaps with architecture-decision-records on rationale, harness-monitor on status and owner evidence, harness-work on report implementation, kpi-dashboard and jarvis-metrics on report design, and the office-documents and ppt-master references on document output. Drafts only: never sends, invites, shares, or publishes without explicit approval."
metadata:
  author: wzlwit
  version: "2.0.0"
argument-hint: "[list|upsert|slots] [<arguments>...]"
---

# Harness Writing

`/harness-write` drafts and updates writing for people, directly in the session and without
requiring an initialized harness: feature doc sets, onboarding, and troubleshooting guides; status
trackers, meeting-slot comparisons and sync-up invites, and email updates or thread replies; and
dashboards, reports, and queries.
`/hn-write` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Result |
| --- | --- |
| `list` | Show known doc sets, communication drafts, and report artifacts with their last verified state; no writing, remote reads, or remote writes |
| `upsert doc <feature-or-doc-set> [<focused-request>]` | [Create or update a full feature doc set or focused page](./references/doc.md) |
| `upsert tracker\|meeting\|email <purpose>` | [Create or update a communication draft](./references/comms.md) with its [tracker](./references/tracker.md), [meeting](./references/meeting.md), or [email](./references/email.md) guide |
| `upsert report <artifact-or-purpose>` | [Coordinate dashboard, report, or query authoring](./references/report.md) |
| `slots <thread-or-people>` | Compare candidate meeting times with the [meeting guide](./references/meeting.md#compare-slots); read-only |

```text
/hn-write
/hn-write upsert doc <feature-or-doc-set> [<focused-request>] [--audience <internal|partner|public>] [--output <path>]
/hn-write upsert tracker <initiative> [--workspace <name>]
/hn-write upsert meeting <initiative> [--at <slot>] [--thread <subject>]
/hn-write upsert email <purpose> [--thread <subject>]
/hn-write upsert report <artifact-or-purpose> [--type <platform>] [--output <path>]
/hn-write slots <thread-or-people> [--required <people>] [--optional <people>] [--days <weekdays>] [--within <duration>] [--duration 30m]
```

- Bare invocation means `list`; `status` and `help` show the same read-only view, and `create` and
  `update` alias `upsert`. Unknown actions show help. These are session instructions, not
  `harness.ps1` actions; installing or explaining the skill writes nothing.
- The word after `upsert` selects the kind; when it is missing and not clear from the conversation,
  ask. Load only that kind's guides. Reuse an existing doc set, draft, or artifact before creating
  another; an ambiguous or inaccessible target is not absent, and never create a duplicate.
- Apply `/rules apply` and project instructions. Reuse an existing approved task when applicable,
  keeping its ownership, pause, repository, and permission controls; never start another writer.
- Ground claims, status, dates, owners, and links in current evidence, and label implemented,
  planned, and unverified behavior. Owners come from authoritative records, explicit statements, or
  the user; authorship and org charts only suggest candidates. Verify each write by reading it back
  and report Draft, Saved, Verified, or Validated honestly; missing evidence or checks leaves a Draft.
- **Drafts only.** Never send mail, send or update invites, share pages, change link permissions,
  delete items, or publish without an explicit request naming that action. After an invite is sent,
  every edit notifies its attendees, so ask first. Moves, installs, commits, pushes, PRs, and review
  replies need separate authorization.
- Keep private names, addresses, tenants, and URLs out of this public bundle and its examples.

## Docs

- Use the [page template](./references/doc-set.md) for a full set; focused requests update only the
  needed pages and navigation. Reader docs go in the selected coding repository's documentation tree
  unless an explicit output is supplied; harness tracking stays controller-local.
- Read owning sections and functions; keywords only locate evidence. Run `humanizer` as the final
  prose pass, then validate. Missing guidance or checks leaves a Draft, never a silent skip or a
  Validated claim. Do not change application behavior, invent expansions or contacts, or leak
  restricted details to a broader audience.

## Communications

- `email --thread` drafts a reply-all on that thread; without it, a new message. Calendar meetings
  only: scheduled tasks and timers belong to `/harness-timer` or `schedule-manager`.
- Use the host's Microsoft 365 tools (for example WorkIQ) for mail, calendars, people, and chats, and
  browser automation on the user's signed-in session for Loop and Outlook on the web; their own
  safety rules still apply. Without them, produce paste-ready content and say what was not done.
  Standalone questions about people or ownership, with no draft to update, belong to those tools.

## Reports

- Platforms: `powerbi`, `grafana`, `jarvis`, `web`, or `query`. Infer a type only from an unambiguous
  request or existing artifact; otherwise ask. After choosing the platform, read its section of
  [report routes](./references/report-routes.md).
- Load only the selected platform specialist and preserve artifact IDs, source contracts, output
  destinations, validation, and publication approvals. Design, created, validated, and published are
  distinct outcomes; monitoring is optional. Tracked local implementation goes through `/harness-work`.

## Boundaries

- `architecture-decision-records` owns decision history; reference its records without rewriting
  their status. `handoff` owns continuation notes, `harness-monitor` owns automated source
  monitoring, `grilling` can stress-test a draft, and `humanizer` polishes longer prose.
- `ppt-master` and `office-documents` reference separate presentation and PDF/Word/Excel guidance.
  They add no PPTX or XLSX route, renderer, or permission to copy proprietary tools; editability and
  workbook checks belong to the artifact's acceptance contract, not its file extension.
