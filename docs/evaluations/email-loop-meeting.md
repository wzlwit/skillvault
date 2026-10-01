# Email, Loop, and Meeting Coordination Evaluation

- Evaluated: 2026-09-28; updated 2026-09-29 after the owner's decision
- Requested name: `email/loop/meeting`, based on one private work session
- Candidate: native SkillVault guidance distilled from that session; there is no upstream package
- Evidence: the session's checkpoint summary, user requests, and tool-call metadata. Names, threads,
  dates, and other private content are left out of this record.
- Version/revision: Not applicable
- Skill recommendation: Upsert, implemented as [`harness-comms`](../../skills/planning/harness-comms/SKILL.md)
  per the [communications ADR](../plans/decisions/2026-09-29-harness-communications-adr.md)
- Installed recommendation: Keep `workiq`; `harness-comms` coexists and delegates to it

## Evidence

The session coordinated a cross-team platform migration. It drafted a status email, found a meeting
slot and drafted an invite, built a tracker page in Loop, updated a OneNote troubleshooting page, and
drafted a reply to the email thread with links. It made about 1,300 tool calls across 75 user requests.

- Mail and calendar: the WorkIQ command-line tool (`ask`, `fetch`, `do-action`, `create`), because
  the WorkIQ MCP tools were not connected. It used Graph paths for messages, events, `getSchedule`,
  and `createReplyAll`.
- Loop and OneNote: attended browser automation in the user's signed-in browser. The installed
  WorkIQ guides mention neither product.
- Invites with attendees: the Outlook web editor's **Save as draft**, then a read-back from the
  server to confirm nothing was sent.

That session then proposed a skill, and after the owner approved it, built `harness-comms`.

## Workflow Worth Keeping

1. Summarize status from source evidence and write a short email with clear asks for owners.
2. Find a meeting slot: check key contributors first and optional people separately; check time
   zones, lunch hours, and regional holidays; prefer the earliest good slot.
3. Draft the invite with agenda and links, save it as a draft, and send only after confirmation.
4. Create or update the tracker page in a workspace the user chooses. Share it or add members only
   after confirmation.
5. Draft the thread reply with the tracker and meeting, and send only after the user approves.

Lessons from the user's corrections:

- Check for an existing draft before creating another one.
- Remove placeholder notes once the thing they point to exists.
- When a protected reply cannot be fetched, use an `ask` summary and say so.
- Pass HTML bodies through a file, not inline shell quoting.

## Value, Fit, and Overlap

Value: Medium to high for this user. This kind of coordination repeats across projects, and a guide
would prevent the corrections seen in the session. The evidence is still one session.

Fit: one skill with procedure guidance, not three skills. The owner also chose a bundled offline
slot-ranking script, because time-zone, lunch, and holiday math is easy to get wrong by hand. The
Loop and OneNote steps stay attended guidance, not bundled automation, because they depend on web
UIs that change.

Overlap: the installed `workiq` plugin skill owns Microsoft 365 mechanics (mail, calendar, free/busy,
drafts) and says to prefer it for that data. The new skill should use it for every mail and calendar
action and add only workflow, audience, and confirmation steps. No SkillVault skill covers mail,
meetings, or Loop. `harness-link` can register the tracker or thread links; `harness-doc` owns
documentation, not messages.

Harness integration: the owner chose a harness topic, `/hn-comms`. Like `harness-doc`, it works in
the session without an initialized harness or a runtime action. When a harness root is initialized,
it offers to register the links with `harness-link`.

## Risks

- Private content: keep examples generic and never copy names, threads, or tenant data into the skill.
- Visible actions: sending mail or invites and sharing pages need explicit confirmation. Draft first
  and verify on the server.
- Brittle automation: 10 of the session's 12 failed tool calls were browser steps in Loop, Outlook,
  or OneNote. The user signs in; the agent never enters credentials.
- Overwrites: OneNote showed a "conflicting changes" banner, so page edits can overwrite others' work.
- Tool availability: the WorkIQ MCP connection may be missing, and the command-line fallback needs its
  EULA accepted once. Pin its version.
- Thin evidence: one session.

## Recommendation

- Skill recommendation: `upsert`, implemented as `harness-comms` in `skills/planning`, default scope
  `global`, as recorded in the [ADR](../plans/decisions/2026-09-29-harness-communications-adr.md).
  This record's earlier suggestion, a non-harness skill named `m365-coordination` without a script,
  is replaced by that decision.
- Standalone use: worth reusing now; the approach worked when each visible action was confirmed.
- Existing-skill improvements: None justified. This session's documentation lessons were already added
  to `harness-doc` in commit 0e19c09, and `workiq` is an external plugin.

## Limits and Reconsideration

This is a review of a session log, not a runtime test. No WorkIQ call, browser action, send, or share
was run for this evaluation, and Loop results were inferred from the session's later requests.

Reconsider after a second coordination session, or when WorkIQ adds Loop or OneNote write support
that would replace browser automation.
