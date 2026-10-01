# Meeting guide

Use with the [shared workflow](workflow.md).

## Compare slots

1. Build the attendee list from the thread's From, To, and CC, plus named owners. Required means the
   people who own open items or must decide. Managers, lists, FYI readers, and people in distant time
   zones are optional unless the user says otherwise. Show the split and let the user adjust it.
2. Fetch free/busy for everyone, including the organizer: `POST /me/calendar/getSchedule` with
   `Schedules`, `StartTime` and `EndTime` in the organizer's time zone, and
   `AvailabilityViewInterval: 30`, over one or two weeks. Save the JSON response as a
   [working file](workflow.md#save-drafts-safely), because it can include other people's meeting
   subjects and locations, and delete it once a slot is chosen.
3. Rank the slots with the bundled [script](../scripts/rank-slots.ps1) (PowerShell 5.1 or 7). Pass the
   same start, time zone, and interval that were sent to getSchedule:

   ```powershell
   & <skill-folder>/scripts/rank-slots.ps1 -SchedulePath <temp-folder>/schedule-<random>.json `
     -Start '2026-10-05T00:00:00' -TimeZone 'Eastern Standard Time' -Organizer me@example.com `
     -Required a@example.com, b@example.com -Optional c@example.com -Days Tue, Wed `
     -ExcludeDates 2026-10-07 -IgnoreOrganizerBusyAt 2026-10-06T16:30
   ```

   The script keeps slots where the organizer is free within working hours. It ranks them by required
   attendees who are free, then by hard conflicts (busy, out of office, or outside working hours), then
   by optional attendees who are free. Working hours and a 12:00 to 13:00 lunch are checked in each
   attendee's own time zone (`-LunchStart`, `-LunchEnd`, `-NoLunch`). Weekends are skipped unless
   `-Days` names them. Use `-IgnoreOrganizerBusyAt` for the organizer's own hold that is being moved,
   `-DurationMinutes` for longer meetings, `-SortBy time` for the earliest slots, and `-Format json`
   for further processing.
4. Exclude public holidays. Check the calendar's holiday entries for the organizer, and ask about
   holidays in attendees' regions when they are not visible. Pass them with `-ExcludeDates`.
5. Present a comparison table: the slot in the organizer's time zone and each attendee time zone,
   required attendees free out of the total, and who is busy, off hours, at lunch, or tentative, plus
   the optional attendees. Recommend the earliest workable slot and the best overall slot, name the
   trade-off (a key person busy, a late hour in another region), and honor stated preferences such as
   preferred weekdays.
6. Re-rank the saved data when constraints change. Fetch again only when the window changes or the
   data is stale.

If the script cannot run, apply the same rules by hand and say so.

## Create or move the draft

1. Search the calendar for an existing hold with the same subject and window, and update it instead
   of creating a duplicate.
2. Create an event with no attendees, so no invitation goes out: subject, start and end with the time
   zone, an online meeting (`isOnlineMeeting: true` with the organization's provider), and a body with
   the purpose, a time-boxed agenda, and pre-read links.
3. The service appends the join details to the body. Keep that block at the end whenever the body is
   replaced.
4. To move the draft, update `start` and `end`, then re-rank if the attendees changed.

## Add attendees without sending

Creating an event with attendees through Graph always sends invitations, and adding attendees to an
existing event can send them too, so use Outlook on the web:

1. Open the event from its `webLink` in the signed-in browser.
2. Type each address into the required or optional attendee field and press Enter to accept the
   suggestion; check every name that was added. If the optional field is hidden, the Scheduler view
   lists required and optional sections.
3. Open the Send menu and choose **Save as draft**. Never choose **Send**. Pressing Escape in the form
   asks whether to discard changes; cancel that prompt.
4. Read the event back: `isDraft` is now true (an event without attendees reads false), the attendee
   counts and types match, and Sent Items has no new invitation.

After edits, the calendar can briefly show two tiles for one draft. Check the server's event list
before calling anything a duplicate, and never delete a tile without matching its ID.

## After the user sends

A sent meeting has `isDraft: false`, and every later change to its time, body, or attendees sends
updates to all attendees. Ask before changing it. For a small correction, such as a fixed link,
suggest a note in the related thread instead.
