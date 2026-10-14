
# Watch a PR or Repository

1. Locate the installed `pr-review` dependency and read its runtime reference. Resolve one exact
   HTTPS GitHub PR or repository URL from the request; ask only when the target is missing or
   ambiguous.
2. Show the shared user-wide list location, target, and requested filters. Use its bundled
   `scripts/pr-review.ps1 -Action Add -Url <URL>`, mapping a PR count or drafts named in plain words
   to `-Limit`/`-IncludeDrafts`. Do not create a list based on the current working directory.
3. Repository entries default to five open, non-draft PRs ordered by recent updates. Exact PR
   entries select that PR, including a draft. Watching is idempotent by normalized URL: the same
   URL again changes only the filters the request mentions. Report the stable W- entry ID and
   stored filters.
4. Watching performs no provider or AI call and creates no timer. If the single timer is already
   enabled, the new target is eligible on a future tick under its existing approved settings.

Do not fetch code, configure models, change accounts, publish feedback, or enable scheduling as
a side effect. Unknown Enterprise hosts need explicit shared host configuration, not implicit
trust. Installing or discussing this skill is not an instruction to watch targets.
