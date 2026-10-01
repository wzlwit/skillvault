# Email guide

Use with the [shared workflow](workflow.md).

## New message or reply

- New message: create a draft in the user's mailbox (`POST /me/messages`) with the subject,
  recipients, and body.
- Reply: find the thread by its exact subject, take the latest message that is not a draft, and create
  a reply-all draft (`POST /me/messages/{id}/createReplyAll`). This keeps the thread's To and CC and
  sends nothing. Leave To unchanged unless asked.
- Add newly involved owners to CC, and open the body with one line naming them and their roles, such
  as `+ Pat (checkout), Lee (billing)`.

## Body template

Adapt this to the thread and keep only what applies.

```text
+ <names> (<roles>)
Hi all,
**<Ask> by <deadline>** (<why this date>) and update your row in the **<tracker link>**.
Heads-up: <earlier event and its effect>.
**Sync-up: <day, date, time, and time zone>** (<join link>). If that time doesn't work, or you'd
like a separate session, let me know.

**Action or ask**
| Owner | Item | Action or ask |
| --- | --- | --- |
| <name> | <item> | Could you <specific ask>? |
| <name> | <item> | Same |
| Owner? | <item> | Is this <team A> or <team B>? |
| Me | <item> | My team will handle this. |

**No action needed:** <completed or confirmed items in one line>.
**Heads-up for <later phase>:** <what happens later and who acts then>.
<optional line to a leader or decision forum>
Thanks,
<name>
```

Bold only the lines that must not be missed. Keep asks as questions, group identical asks with
"Same", and use a question row when the owner is unknown.

## Insert and update the body

- In a reply, insert the new HTML right after `<body>` and before the `<hr>` that precedes the first
  quoted `From:` header. Keep the quoted thread unchanged.
- Build the fragment with inline styles, such as the font family and size, and a simple bordered
  table. Escape text and link values.
- Before each update, extract the part above the quoted thread and normalize it: remove tags (block
  tags become spaces), decode entities, and collapse whitespace. Compare the result with the text you
  last wrote. If it differs, the user edited the draft: stop, show the difference, and merge only with
  approval.
- Send the full body through an MCP tool call, not a command-line argument.

## Links

Estimate each link's value before adding it. Keep the tracker, the meeting, one how-to per kind of
ask, and the PR or change that a row asks about. Leave item names that owners already know unlinked,
link each target once, and leave background reading out; when unsure, skip the link. Before adding
one, check its target:

| Target | Check before linking |
| --- | --- |
| Pull request | State and base branch from the provider API; it may merge into a branch other than the default |
| File | Exists on the default branch, for example `git cat-file -e origin/<default>:<path>` |
| Guide section | The heading exists and its anchor slug matches |
| Tracker | The share link opens for the recipients (an organization edit link or named access) |
| Meeting | The join URL read back from the event |

Replace links to merged or deleted branches with default-branch links.

## Verify

Read the draft back after 30 to 60 seconds. Check `isDraft`, To and CC, the first lines, the link
count, and the intact quoted thread, and confirm that Sent Items has nothing new. Report the draft's link.
