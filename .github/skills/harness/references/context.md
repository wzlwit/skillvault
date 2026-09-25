
# Harness Context

Reuse the selected Root without another location prompt, including its displayed `./` fallback.
The session supplies `-ProjectPath` automatically. If no Root or explicit target exists, use
`/harness root ./` once; do not replace a selected Root with the workspace or terminal directory.

Read and apply `/rules apply` and project instructions. Locate the installed `harness` runtime
and call `scripts/harness.ps1 -ProjectPath <root> -Action Context`, optionally with `-Id <task-id>`.
Supply known compatible session/parent settings through `-RunnerContext` or `-RunnerContextPath`
to show effective Runner Inheritance values without changing saved overrides. Missing allowances
use maximum verified/native settings; report requested routing separately from actual model identity.
Read the identified governing plans and ADRs as needed and summarize their relevant constraints,
open decisions, and source links. Keep external reference drafts separate from current decisions.

Report the controller project and board, applicable rules, selected task scope, and relevant
references. For a repository-bound task, distinguish its selected reference, recorded Git root,
and current/worktree workspace from the controller folder. Include the coding repository's
instruction candidates; never silently resolve an inactive or missing reference to another target.
Distinguish registered links from material actually read. Inaccessible or missing context is
explicitly unavailable, not evidence of an empty project. Do not print secrets or entire config
files just to explain the context. No new store or generated context document is needed.

This command is read-only: do not initialize state, install skills, accept decisions, start
an interview, queue tasks, run workers, or change schedules. Use `/harness-link` to change supporting
links and `/harness-decision` for the open/recent decision bulletin.

Use `/handoff` when explicitly asked to write a continuation note for another session or person.
It can reuse this view while adding the blocked step, process uncertainty, and first next action;
neither summarizing context nor writing the note stops or resumes execution.

When the user supplies a handoff note or selects one from the task's references, read it as
continuation evidence alongside current instructions and records. Recheck the selected task and
workspace, blockers, process/pause state, and relevant changes before presenting a next action.
Report conflicts or unavailable checks; do not silently promote an old note into current truth.
Reading a note starts no work and creates no new note. Do not pass note text as a new runtime action.