---
name: harness-comms
description: "Draft stakeholder communications for tracked work: status trackers, meeting-slot comparisons and sync-up invites, and email updates or thread replies. Use /harness-comms or /hn-comms with list, slots, or upsert. Overlaps with harness-doc on reader-facing prose and harness-monitor on status and owner evidence; owns time-bound coordination artifacts and can register their links afterward through harness-link. Drafts only: never sends, invites, or shares without explicit approval."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|slots|upsert] [<arguments>...]"
---

# Harness Communications

`/harness-comms` drafts the messages and trackers that keep owners moving on shared work: a status
tracker, meeting-slot comparisons and sync-up invites, and email updates or thread replies. It
works directly in the session, without requiring an initialized harness.
`/hn-comms` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

| Action | Result |
| --- | --- |
| `list` | Show communication artifacts known in the conversation or registered through `/harness-link`, their last verified state, and available actions; no remote reads or writes |
| `slots` | Compare candidate meeting times for required and optional attendees with the [meeting guide](./references/meeting.md#compare-slots); read-only |
| `upsert` | Create or update a draft `tracker`, `meeting`, or `email` through the [shared workflow](./references/workflow.md) and that artifact's guide |

```text
/hn-comms
/hn-comms slots <thread-or-people> [--required <people>] [--optional <people>] [--days <weekdays>] [--within <duration>] [--duration 30m]
/hn-comms upsert tracker <initiative> [--workspace <name>]
/hn-comms upsert meeting <initiative> [--at <slot>] [--thread <subject>]
/hn-comms upsert email <purpose> [--thread <subject>]
```

- Bare invocation means `list`; `status` and `help` show the same read-only view, and `create` and
  `update` alias `upsert`. `email --thread` drafts a reply-all on that thread; without it, a new message.
- Load only the selected guide: [tracker](./references/tracker.md), [meeting](./references/meeting.md),
  or [email](./references/email.md), with the [shared workflow](./references/workflow.md). Apply
  `/rules apply` and project instructions. Reuse an existing artifact before creating another;
  an ambiguous or inaccessible target is not absent.
- **Drafts only.** Never send mail, send or update invites, share pages, change link permissions, or
  delete items without an explicit request naming that action. After an invite is sent, every edit
  notifies its attendees, so ask first.
- Ground status, dates, owners, and links in current evidence. Owners come from authoritative
  records, explicit statements, or the user; authorship and org charts only suggest candidates.
  Verify each write by reading it back, and report Draft, Saved, or Verified honestly.
- Use the host's Microsoft 365 tools (for example WorkIQ) for mail, calendars, people, and chats, and
  browser automation on the user's signed-in session for Loop and Outlook on the web; their own
  safety rules still apply. Without them, produce paste-ready content and say what was not done.
  Standalone questions about people or ownership, with no draft to update, belong to those tools.
- Calendar meetings only: scheduled tasks and timers belong to `/harness-timer` or `schedule-manager`.
  `harness-doc` owns durable reader guides, and `harness-monitor` owns automated source monitoring.
  `grilling` can stress-test a draft, and `humanizer` can polish longer prose.
- Keep private names, addresses, tenants, and URLs out of this public bundle and its examples.
