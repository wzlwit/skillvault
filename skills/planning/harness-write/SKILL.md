---
name: harness-write
description: "[slots] Alone: your drafts. Text: write it. Draft and update writing for people: evidence-grounded feature docs, onboarding, and troubleshooting guides; stakeholder trackers, meeting invites, and email updates or thread replies; and dashboards, reports, and queries; slots ranks meeting times offline. Shorthand: /hn-write. Overlaps with architecture-decision-records on rationale, harness-monitor on status and owner evidence, harness-dev on report implementation, kpi-dashboard and jarvis-metrics on report design, and the office-documents and ppt-master references on document output. Drafts only: never sends, invites, shares, or publishes without explicit approval."
metadata:
  author: wzlwit
  version: "3.1.0"
argument-hint: "[slots] [<what to write>]"
---

# Harness Writing

`/harness-write` drafts and updates writing for people, directly in the session and without
requiring an initialized harness: feature doc sets, onboarding, and troubleshooting guides; status
trackers, meeting-slot comparisons and sync-up invites, and email updates or thread replies; and
dashboards, reports, and queries.
`/hn-write` is chat shorthand for the same topic, not a separate skill or folder.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | Confirms a writing target that is clear from the conversation, or shows your drafts and asks what to write |
| Text | Drafts what the words describe: a [doc set or focused page](./references/doc.md); a [tracker](./references/tracker.md), [meeting](./references/meeting.md), or [email](./references/email.md) through the [communications workflow](./references/comms.md); or a [dashboard, report, or query](./references/report.md) |
| `slots <thread or people>` | [Compares candidate meeting times](./references/meeting.md#compare-slots); read-only |

- **Alone.** When the conversation makes clear what to write, say what would be written and where,
  and ask to confirm before writing. Otherwise show known doc sets, communication drafts, and report
  artifacts with their last verified state, and ask whether to update one or start a new one; this
  view makes no writes, remote reads, or remote writes. No answer writes nothing.
- The alone view ends with one line naming the text uses: say what to write, such as "email the
  platform team about the outage" or "public docs for the monitor feature", or use `slots` with the
  people to meet.
- **Text.** Plain words carry the details: the kind (doc, tracker, meeting, email, or report), the
  audience (internal, partner, or public), the save location, the thread (its exact subject), the
  workspace, the meeting time, and the report platform. A request may start with the kind, as in
  "email the platform team ...". Ask only when a detail is unclear and changes the result, and load
  only that kind's guides. These are session instructions, not `harness.ps1` actions; installing or
  explaining the skill writes nothing.
- **`slots`.** Required and optional people (or a thread whose sender and recipients supply them),
  the days, the search window, and the meeting length come in plain words. They map to the
  getSchedule window and the [ranking script](./scripts/rank-slots.ps1) (`-Required`, `-Optional`,
  `-Days`, `-DurationMinutes`); nothing is written.
- Reuse an existing doc set, draft, or artifact before creating another; an ambiguous or
  inaccessible target is not absent, and never create a duplicate.
- Apply `/rules apply` and project instructions. Reuse an existing approved task when applicable,
  keeping its ownership, pause, repository, and permission controls; never start another writer.
- Ground claims, status, dates, owners, and links in current evidence, and label implemented,
  planned, and unverified behavior. Owners come from authoritative records, explicit statements, or
  the user; authorship and org charts only suggest candidates. Verify each write by reading it back
  and report Draft, Saved, Verified, or Validated honestly; missing evidence or checks leaves a Draft.
- In docs and communications, spell out each acronym in full where it first appears in the page,
  message, tracker, or invite, as in Azure DevOps (ADO), including in tables and diagram labels.
  Skip acronyms that readers know better than the full term: common ones such as URL, PDF, JSON,
  or HTML, and product or service names that go by their short form, such as DAS or PACS. Titles
  and headings may keep the short form, and quoted text stays as written. Never guess an
  expansion: ask, or leave it as a reviewer question.
- **Drafts only.** Never send mail, send or update invites, share pages, change link permissions,
  delete items, or publish without an explicit request naming that action. After an invite is sent,
  every edit notifies its attendees, so ask first. Moves, installs, commits, pushes, PRs, and review
  replies need separate authorization.
- Keep private names, addresses, tenants, and URLs out of this public bundle and its examples.

```text
/hn-write
/hn-write email the platform team about the outage, as a reply on the "Checkout outage" thread
/hn-write public docs for the monitor feature, saved to docs/guides/monitor
/hn-write tracker for the checkout migration in the Platform workspace
/hn-write meeting for the checkout migration on Tuesday at 10:00
/hn-write report: service-health dashboard in Grafana, design only
/hn-write slots Alice and Bob, Carol optional, Tuesday or Wednesday in the next two weeks, 45 minutes
```

## Docs

- Use the [page template](./references/doc-set.md) for a full set; focused requests update only the
  needed pages and navigation. Reader docs go in the selected coding repository's documentation tree
  unless the request names a save location; harness tracking stays controller-local.
- Read owning sections and functions; keywords only locate evidence. Run `humanizer` as the final
  prose pass, keeping every first-use acronym expansion, then validate. Missing guidance or checks leaves a Draft, never a silent skip or a
  Validated claim. Do not change application behavior, invent expansions or contacts, or leak
  restricted details to a broader audience.

## Communications

- An email that names an existing thread by its exact subject drafts a reply-all on that thread;
  otherwise it drafts a new message. Calendar meetings only: scheduled tasks and timers belong to
  `/harness-schedule` or `schedule-manage`.
- Use the host's Microsoft 365 tools (for example WorkIQ) for mail, calendars, people, and chats, and
  browser automation on the user's signed-in session for Loop and Outlook on the web; their own
  safety rules still apply. Without them, produce paste-ready content and say what was not done.
  Standalone questions about people or ownership, with no draft to update, belong to those tools.

## Reports

- Platforms: `powerbi`, `grafana`, `jarvis`, `web`, or `query`. Infer the platform only from an
  unambiguous request or existing artifact; otherwise ask. After choosing it, read its section of
  [report routes](./references/report-routes.md).
- Load only the selected platform specialist and preserve artifact IDs, source contracts, output
  destinations, validation, and publication approvals. Design, created, validated, and published are
  distinct outcomes; monitoring is optional. Tracked local implementation goes through `/harness-dev`.

## Boundaries

- `architecture-decision-records` owns decision history; reference its records without rewriting
  their status. `handoff` owns continuation notes, `harness-monitor` owns automated source
  monitoring, `grilling` can stress-test a draft, and `humanizer` polishes longer prose.
- `ppt-master` and `office-documents` reference separate presentation and PDF/Word/Excel guidance.
  They add no PPTX or XLSX route, renderer, or permission to copy proprietary tools; editability and
  workbook checks belong to the artifact's acceptance contract, not its file extension.
