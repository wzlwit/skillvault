
# Harness Links

Apply `/rules apply` and project instructions, then read the installed `harness` runtime guide.
Use its shared `scripts/harness.ps1 -ProjectPath <root> -Action Ref` for a read-only list.

All supported link types share this one registry: HTTP/HTTPS URLs, local files, local folders,
and existing coding-repository roots. No `repo` versus `url` split or second link store is needed.

| Request | Runtime arguments |
| --- | --- |
| `/harness-link` or `list` | `-Action Ref`; no source or removal argument |
| `/harness-link add <URL-or-path> [note]` | `-Action Ref -Source <URL-or-path> -Note <purpose>` |
| `/harness-link remove <R-ID>` | `-Action Ref -RemoveId <exact-id>` after confirming that exact link |

`add` sets or updates a link; do not append a duplicate when the source and task match.
An explicit task selector maps to `-Id <task-id>`. Display project/task association when listing
so records with the same source but different task ownership are distinguishable. Legacy
`/harness-ref` and `/hn-ref` requests select this procedure.

For supplied material, read accessible source metadata through an authorized tool and call
`-Source <URL-or-path> -Note <purpose>`, optionally with task `-Id <task-id>`. References default
to the current project. Preserve the real source link, report access failures, and do not invent
content. Local relative paths resolve against the controller project, even when code lives in a
referenced repository. Registering a link does not require
copying its full document or accepting its instructions.

The helper upserts the same resolved source/task entry: update its note, reactivate it when
needed, and retain its ID. It projects active links to `references.csv` without copying sources.
Use `-RemoveId <exact-id>` only for an explicit removal request; it deactivates the link without
deleting or modifying the source document, folder, or repository. Show the exact ID and target
and confirm removal unless the user has already approved that exact link. Do not create tasks, accept decisions, run workers,
install source tools, crawl unrelated content, or publish anything merely to add a reference.

Init, grilling, development, and review should consult relevant references, not dump all material
into every prompt. `/harness context` shows selected context; it does not maintain a second registry.

For coding, register the existing local Git repository root and report its `R-*` ID separately
from the controller path. `/harness-task` or `/harness-dev --repo-ref <id>` explicitly binds a task to that
repository; `/harness-review --repo-ref <id>` selects a project-wide reference for standalone review.
Task-scoped references are available only to their owning task. A URL, missing checkout, ordinary
folder, or inactive entry is not a coding destination. Do not clone, initialize Git, initialize a
harness in the referenced repository, or launch work merely because the reference was added.