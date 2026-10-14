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
