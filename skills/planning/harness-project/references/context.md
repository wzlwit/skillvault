
# Harness Context

`/harness-project context` shows what the project knows and keeps the one registry of its sources:
URLs, local files, local folders, and existing coding-repository roots. The runtime calls them
references (`R-*` IDs). `link` is an alias of `context`.

| Request | Runtime arguments |
| --- | --- |
| `/harness-project context [<task-id>]` | `-Action Context`, with `-Id <task-id>` for a task, and `-Action Ref` for the registered sources |
| `/harness-project context add <URL-or-path> [note]` | `-Action Ref -Source <URL-or-path> -Note <purpose>` |
| `/harness-project context remove <R-ID>` | `-Action Ref -RemoveId <exact-id>` after confirming that exact source |

Reuse the selected Root without another location prompt, including its displayed `./` fallback.
The session supplies `-ProjectPath` automatically. If no Root or explicit target exists, use
`/harness-project root ./` once; do not replace a selected Root with the workspace or terminal directory.
Read and apply `/rules apply` and project instructions, then the installed `harness-runtime` guide,
and call its shared `scripts/harness.ps1 -ProjectPath <root>` with the arguments above.

## Show

Supply known compatible session/parent settings through `-RunnerContext` or `-RunnerContextPath`
to show effective Runner Inheritance values without changing saved overrides. Missing allowances
use maximum verified/native settings; report requested routing separately from actual model identity.
Read the identified governing plans and ADRs as needed and summarize their relevant constraints,
open decisions, and source links. Keep external reference drafts separate from current decisions.

Report the controller project and board, applicable rules, selected task scope, and the registered
sources with their IDs, targets, notes, and project or task association, so entries with the same
source but different task ownership stay distinguishable. For a repository-bound task, distinguish
its selected source, recorded Git root, and current/worktree workspace from the controller folder.
Include the coding repository's instruction candidates; never silently resolve an inactive or
missing source to another target. Distinguish registered sources from material actually read.
Inaccessible or missing context is explicitly unavailable, not evidence of an empty project. Do not
print secrets or entire config files just to explain the context. No new store or generated context
document is needed.

Under **How this project is tested**, summarize the `testing` field: the unit-test level, the
validation commands and flows that run with the first review, the flows that run after a clean
review, flows that run only on demand or on a timer (such as PPE online after a deployment), each
flow's environment and declared effects, and which environments allow scheduled runs. When the field
has a note that no declared test runs during development, say so and point to `/harness-work test
declare`, which also drafts flows from the repository. Context only shows test methods; declare and
change them through `/harness-work test`.

Showing context is read-only: do not initialize state, install skills, accept decisions, start an
interview, queue tasks, run workers, or change schedules. Use `/harness-decision` for the open and
recent decision bulletin.

## Add or Remove Sources

One registry holds every source type; there is no `repo` versus `url` split or second store.
`add` sets or updates a source; do not append a duplicate when the source and task match. An
explicit task selector maps to `-Id <task-id>`, and sources default to the current project.

For supplied material, read accessible source metadata through an authorized tool and call
`-Source <URL-or-path> -Note <purpose>`. Preserve the real source link, report access failures, and
do not invent content. Local relative paths resolve against the controller project, even when code
lives in a referenced repository. Registering a source does not require copying its full document
or accepting its instructions.

The helper upserts the same resolved source/task entry: it updates the note, reactivates the entry
when needed, and keeps its ID. It projects active sources to `references.csv` without copying them.
Use `-RemoveId <exact-id>` only for an explicit removal request; it deactivates the entry without
deleting or modifying the source document, folder, or repository. Show the exact ID and target and
confirm removal unless the user has already approved that exact source. Do not create tasks, accept
decisions, run workers, install source tools, crawl unrelated content, or publish anything merely
to add a source.

Init, grilling, development, and review should consult relevant sources, not dump all material into
every prompt.

## Coding Repositories

For coding, register the existing local Git repository root and report its `R-*` ID separately from
the controller path. `/harness-work upsert` or `/harness-work run --repo-ref <id>` explicitly binds a
task to that repository; `/harness-review --repo-ref <id>` selects a project-wide source for
standalone review. Task-scoped sources are available only to their owning task. A URL, missing
checkout, ordinary folder, or inactive entry is not a coding destination. Do not clone, initialize
Git, initialize a harness in the referenced repository, or launch work merely because the source
was added.

## Handoff Notes

Use `/handoff` when explicitly asked to write a continuation note for another session or person.
It can reuse this view while adding the blocked step, process uncertainty, and first next action;
neither summarizing context nor writing the note stops or resumes execution.

When the user supplies a handoff note or selects one from the task's sources, read it as
continuation evidence alongside current instructions and records. Recheck the selected task and
workspace, blockers, process/pause state, and relevant changes before presenting a next action.
Report conflicts or unavailable checks; do not silently promote an old note into current truth.
Reading a note starts no work and creates no new note. Do not pass note text as a new runtime action.