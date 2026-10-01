
# List PR Review Targets

Locate `pr-review`, read its runtime reference, and run its bundled
`scripts/pr-review.ps1 -Action List`. Always use the shared user-wide controller, not a new
project-local list. A missing list is empty; do not initialize it or invent current status.

Show each stable W- ID, PR or repository URL, kind, discovery limit/draft filter, and when it was
added. A repository entry selects its recently updated open PRs on each run; it is not a fixed PR
list. Review results, including ad-hoc and in-progress reviews, come from `/pr-review list`.

No provider/model call, refresh, list mutation, or scheduler write is implied. Use
`/harness-timer pr status` for explicit timer inspection and `/pr-review run` for remote review.