
# Remove PR Review Target

1. Locate `pr-review` and its shared runtime reference. Resolve one exact watched URL or stable
   W- ID from the user-wide list, never a remembered display index or a broad keyword.
2. Preview through `scripts/pr-review.ps1 -Action Remove -Selector <URL-or-ID>`. Show the selected
   entry and list path. Ask for confirmation unless this exact removal is already authorized.
3. Repeat the same command with `-Apply`. Report the removed entry and that existing reports,
   checkouts, remote PRs, and the single timer were preserved.

Removal stops future discovery from that entry, not an already-running review. An explicitly
watched PR can still be selected by a remaining repository entry, and vice versa; explain the
remaining route rather than silently removing other entries. An empty list makes future ticks
no-ops. Do not close PRs, delete repositories/evidence, disable unrelated tasks, or publish.