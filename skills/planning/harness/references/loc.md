
# Harness Root

Read `/rules apply`, project instructions, and the installed `harness` runtime guide. Follow
Script Permissions and Agent Fallback before helpers. `root` means the parent location for the
`.harness_sv/` workspace, not the skill installation or a coding-repository link.
`/hn root` is shorthand for `/harness root`. `/harness loc` and `/hn loc` remain aliases,
not separate location concepts.

## Inspect Locations

`/harness root` only shows the selected parent root and its `<root>/.harness_sv/` directory,
alongside actual control/config and board paths and initialization state. Reuse the selected
Root without another location prompt and call the shared dispatcher:

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <selected-root> -Action Root
```

If no Root is selected, show the resolved current project folder as an unselected candidate;
read-only inspection does not select it or initialize state. No-argument `/harness` and `list`
are also read-only. Only the runtime Root action permits omitted `-ProjectPath`; the session
should supply the explicit path to avoid following an incidental terminal directory.

Newly initialized controllers keep their board, run evidence, and control files in `.harness_sv/`.
Harness-owned documents, logs, declarations, and local artifacts also default there unless the
user explicitly selected another destination. Follow [Artifact Storage](./runtime.md#artifact-storage).
Show any saved board override separately. Inspection does not move existing records. A root
change follows the move prompt and its displayed default below; selection alone creates nothing.
The runtime reuses a recognized legacy SkillVault `.harness` controller in place when no
`.harness_sv` directory exists. It does not adopt an unrelated `.harness` directory or merge
two controllers. Show the actual resolved paths; author new artifacts under that resolved control.

## Root Selection

`/harness root <path>` selects the parent/controller for this session. It can be a non-Git folder;
coding repositories are separate links registered through `/harness-link`. The requested valid
root becomes the session Root independently of whether existing data is moved. When the previously
selected harness was initialized, ask whether to move it after changing the selection. No
`--move` flag is required. Move is the default after that prompt, including no answer, unless
an explicit answer or applicable user instruction says otherwise.

1. For the first selection or a required selection during an explicitly requested action, always prompt
	to confirm the location: **Use this project root, use the current folder, or choose another
	path?** Resolve `./` to the user's current project directory and show its absolute path,
	plus a proposed path if supplied. Never substitute the skill installation, SkillVault source,
	or an incidental worker directory.
2. If there is no answer, the user is unavailable, or the question tool is unavailable, use the
	displayed `./` for session selection and report the fallback. Explicit rejection/cancellation
	is not an unanswered prompt. Invalid or inaccessible paths require correction; never replace
	them with another root. The fallback applies only to this selection prompt, not bare inspection.
3. For explicit reselection with an existing Root, save its absolute path as the previous root
	and resolve relative inputs against it. Inspect the target with `-Action Root -ProjectPath <new-root>`.
	An invalid target leaves the current Root unchanged; there is no silent fallback. If source
	and target are the same, retain Root without a move prompt. Otherwise select the valid new root
	before asking about moving data. Inspect the saved previous root for initialization, not the
	new selection. If the previous harness is not initialized, no move is needed and selection
	finishes without another confirmation prompt. Otherwise use [Confirm Relocation](#explicit-relocation).
	If the source cannot be inspected, keep the new Root and report that no move was performed.
	Do not create a directory, Git repository, or harness state merely to select a root.
4. Retain the selected absolute Root in session context. All subsequent harness actions, including
	`/harness init`, derive their project path from it without another location confirmation.
	The session supplies `-ProjectPath`; initialization additionally receives
	`-ConfirmLocation` automatically. Reconnects reuse Root, including an explicitly reported fallback.

Selection without an authorized move does not migrate records, change a terminal directory, or
retarget saved tasks, timers, other sessions, or coding repositories. Root selection alone starts
no work, installs nothing, changes no permissions, and does not initialize the target.

## Explicit Relocation

For `/harness root <new-parent>`, when the previously selected harness was initialized and the
target differs, ask **Move the existing harness to the new root? Default: Yes, move.** State that
no answer uses Move. The valid new Root is already selected. Retain the saved previous root as
the move source; never substitute the new selection
for that source. Both parents must already exist. No user-facing move flag is needed; the helper's
`-Move` and `-Apply` switches are internal execution controls.

Show the source/destination paths, initialization state, and that the new root is selected
regardless of whether the existing controller is moved. Use these choices:

| Choice | Data Action | Selected Root |
| --- | --- | --- |
| Yes: Move (default) | Preview the move from the saved previous root, then apply the requested relocation. | New root |
| No: Do Not Move | Leave the old controller, records, and schedules in place. | New root |

An explicit answer or applicable user instruction takes precedence over the default. Honor a
specified move or no-move choice without asking for it again; in particular, an explicit No,
cancel, or instruction not to move leaves the old data in place and keeps the new Root selected.
An ambiguous substantive answer needs clarification; do not treat it as no answer.

No answer, a skipped unanswered prompt, or an unavailable user/question tool uses Move after
displaying the prompt and default. Preview and apply the move using the saved previous root as
its source; report that the requested default was used, not that the user answered Yes.
The first-selection `./` fallback does not apply to this move question.
If the destination already contains a controller, explain that merging/overwriting is prohibited;
the new Root remains selected without merging. A blocked or failed move is reported separately:
the new Root remains selected, but never claim that data moved or silently initialize a replacement.
Preserve the source and any recovery evidence. Bare `root` remains inspection only and never asks to move.

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <previous-root> -Action Root -Move -DestinationPath <new-parent>
& <harness-folder>/scripts/harness.ps1 -ProjectPath <previous-root> -Action Root -Move -DestinationPath <new-parent> -Apply
```

The first call is read-only. Show source and destination control paths, retained execution root,
board override, file count, worktrees, and scheduler involvement. Apply after a Yes answer,
an explicit move instruction, or the displayed unanswered-prompt Move default for that exact
relocation. Do not add another Yes-only confirmation that defeats this default. If the preview
materially changes the displayed scope, resolve that difference before applying. Pass the existing runner context and
honor host permissions and declared working roots. This operation never widens an allowlist.
Scheduled ticks cannot initiate this root-change workflow; the unanswered-prompt default applies
only to a user-requested root change. The helper rejects scheduled use, active or unrecovered work, occupied/nested destinations, linked
filesystem entries, embedded repositories, and unregistered worktrees. Scheduled controllers
require the sibling `harness-timer` helper and a consistent registry. Enabled legacy OS timers
must first be disabled or migrated explicitly. External runner-context files retain their
original path and must have unambiguous absolute paths or an explicit original policy root.

The helper moves only the resolved control directory, including a recognized legacy `.harness`,
to `<new-parent>/.harness_sv`. It retains the project ID, task/link/decision IDs, queues, pauses,
and recorded outcomes. Registered worktrees retain uncommitted files and get Git metadata repair;
their source repositories stay put. `config.executionRoot` preserves the original implicit
coding/test target and project instruction lookup. Explicit repository references still win.
Relative policy, rules, monitor, and board paths retain their original targets unless those
targets are inside the moved directory. Workspace-relative test paths remain workspace-relative.

An external board stays in place; its owned views and decision links are updated without changing
decision history. Project schedules and their central registration follow the same controller,
keeping job IDs, enabled state, timezone, anchor, and next due time. The shared heartbeat and
unrelated schedules are not reconfigured. No agent, test, cleanup policy, or timer is started.
Application files, external documents, linked sources, installed skills, and user-wide PR/refresh
controllers are not relocated. Authored document text and captured historical evidence are not
blindly rewritten; only known structured path fields and decision references are updated.

Copy verification and runtime locks precede publication. Failure rolls back copied state,
worktree links, board projections, and scheduler registration. If recovery cannot finish,
`move.pending.json` blocks execution; preserve both locations and reconcile them explicitly.
`MovedCleanupPending` means the new location is authoritative but the blocked original still
needs inspection/removal. Never delete a retained copy before checking for late user edits.
After `Moved` or `MovedCleanupPending`, retain the returned new Root in this session. Other
sessions must explicitly reconnect to it; do not silently initialize the old location.

## Legacy Board Placement

The explicit compatibility form `/harness loc --board <path>` changes an empty board's location
on an initialized controller. It does not select the parent location. Require a selected Root;
if absent, use the Root Selection procedure once. Show the resolved board path
and invoke the existing Board action with `-BoardPath <path>`:

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <selected-root> -Action Board -BoardPath <path>
```

Relative board paths resolve against the selected controller. The helper refuses another
project's board, unrelated CSV files, or any board with task, reference, run, or decision records.
Project root and board root are different: board placement does not switch the coding repository,
move `.harness_sv`, select another Root, initialize state, or change the documentation root.
Physical migration of populated records is a separate reviewed operation, not a fallback.

## Legacy Routing

Old `/harness-root`, `/hn-root`, and management `root` commands select the Root Selection
procedure with the same move prompt and default as `/harness root`. `/hn-root <path>` and
`/hn root <path>` do not add a second location prompt when a Root is already selected.
Old `/harness-loc`, `/hn-loc`, or management `loc <path>`
commands keep their board-placement meaning; map the positional path to `--board`.
Explicit legacy `loc --root <path>` remains Root selection. Do not reinterpret an old board
path as a controller. Reject combined `--root` and `--board` requests. Board placement is a
compatibility route, not an additional advertised action. The spaced `/harness loc <path>`
aliases `/harness root <path>`; it is not the old `/harness-loc <path>` spelling.