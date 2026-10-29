# Extra Rules

Rules beyond the four [core rules](core.md), kept in the SkillVault repository so every machine with
the `rules` skill gets the same list. `/rules apply` puts them into effect with the core rules,
globally by default or in a project; `/rules apply core` leaves them out. Change this list only
with a `/rules` request that names `extra`, to add, change, or remove a rule; each rule is one bullet.

This file is public. A rule that needs private or work-specific details stays in your global
Personal rules or a project's own instructions: type it after `/rules`, adding `project` for the
project's instructions.

- **Link what you mention in chat.** In chat replies, make every file, folder, script, config,
  repository, wiki page, work item or incident, query, and tool you mention clickable: a file link
  for local items, the URL for online ones, and both when both exist. A name or path in backticks
  alone isn't enough. This applies to chat replies only: don't pile extra links into docs, and keep
  local paths out of text written for other people, such as emails, incident or review comments,
  and PR or commit text.
- **Run unit tests once the review is clean.** In review-and-fix rounds, fix findings without
  running unit tests or a full build between rounds. Once the review is clean, the Full pass included
  when it's on, run the unit tests and the final build; if either fails, fix it and send the fix
  through review again.
- **Put what the user must act on in the last message.** A prompt, command, or question left for
  the user goes in the turn's last message, which is the completion summary when the host shows
  one. Never point to an earlier message for it.
