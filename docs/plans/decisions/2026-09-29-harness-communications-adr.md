# ADR: Stakeholder Communications Drafting

- Date: 2026-09-29
- Status: Accepted
- Decision owner: Zhaolong Wang
- Scope: Status trackers, meeting-slot comparison, sync-up invites, and email updates or thread replies for tracked work.
- Related: [Topic contracts](../2026-09-16-topic-skill-refactor.md) and [documentation authoring](2026-09-26-harness-documentation-adr.md).

## Context

Shared work often stalls on coordination rather than code: owners need one tracker, a meeting time
that suits several time zones, and a short message that says who must do what by when. Doing this by
hand repeats the same risks: an invite sent too early, an overwritten draft, a guessed owner, a dead
link, or a slot that falls in someone's lunch hour or holiday. The documentation topic owns durable
reader guides, not these time-bound drafts.

## Decisions

1. Register one `harness-comms` skill, with `/hn-comms` as conversational shorthand. Bare invocation
   and `list` show known artifacts and actions; `slots` compares meeting times read-only; `upsert`
   creates or updates a `tracker`, `meeting`, or `email` draft, with `create` and `update` as aliases.
   Do not add separate meeting, email, or tracker bundles.
2. Work directly in the session without an initialized harness or runtime action. When a harness root
   exists, offer to register artifact links through `harness-link`.
3. Save drafts only. Sending mail, sending or updating invites, sharing pages, changing link
   permissions, and deleting items each need an explicit request. Add meeting attendees through
   Outlook on the web and save the event as a draft, because adding them through Graph can send
   invitations immediately.
4. Ground status, dates, owners, and links in current evidence. Owners come from authoritative records,
   explicit statements, or the user; authorship and org charts only suggest candidates, recorded as
   `TBD` and asked.
5. Re-read before overwriting a draft the user may be editing, and verify every write by reading it
   back after a short delay.
6. Rank slots with a bundled, offline PowerShell script over saved getSchedule data. It checks
   working hours and lunch in each attendee's time zone, excluded dates, and the organizer's own hold,
   and a fixture test covers it.
7. Keep working files, such as saved free/busy data and message bodies, in uniquely named OS temp
   files, never in a repository or `.harness_sv`, and delete them when done, because they can hold
   other people's meeting details or private mail.

## Alternatives

- Three standalone skills would duplicate the shared evidence, drafting, and verification rules.
- Extending `harness-report` would mix time-bound messages with dashboard and query authoring.
- A `send` action would make the most consequential step one command away; the user sends instead.
- Ranking slots by hand in every session repeats time-zone arithmetic that is easy to get wrong.

## Consequences

The bundle supplies procedures and one offline script, not a mail, calendar, or Loop client. It relies
on the host's Microsoft 365 tools and browser automation, and produces paste-ready content when they
are unavailable. Loop interface details are recorded as observations to confirm with a page snapshot.
Its public examples stay generic. Source development does not install the skill, create drafts,
change schedules, or publish anything.

## References

- [Skill entrypoint](../../../skills/planning/harness-comms/SKILL.md)
- [Shared workflow](../../../skills/planning/harness-comms/references/workflow.md)
- [Meeting guide](../../../skills/planning/harness-comms/references/meeting.md)
- [Slot ranking script](../../../skills/planning/harness-comms/scripts/rank-slots.ps1)
- [Current project plan](../2026-09-15-harness-command-and-record-contracts.md#communications-drafting)
