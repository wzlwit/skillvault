
# List PR Review Targets

Locate `pr-review`, read its runtime reference, and run its bundled
`scripts/pr-review.ps1 -Action List`. Always use the shared user-wide controller, not a new
project-local list. A missing list is empty; do not initialize it or invent current status.

Show stable W- ID, PR/repository URL, discovery limit/draft filter, and latest recorded review
head, base, outcome, blocker, and report link when available. Distinguish a watched repository
from its discovered PRs, and a previous completed review from present remote state. A finding
result is not a clean PR; a blocked/stale result is pending. Unknown state stays unknown.

No provider/model call, refresh, list mutation, or scheduler write is implied. Use
`/harness-timer pr status` for explicit timer inspection and `/pr-review run` for remote review.