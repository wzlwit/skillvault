---
name: harness-setup
description: "[root|clean|policy] Alone: set up or status. Text: add a source, or ask. Set up and steer a harness project: create it or convert an old layout, show status, select or move its root, register sources and coding repositories, brief a task, delete old run history, and set limits, failure handling, retention, and pause, stop, and resume. Shorthand: /hn-setup. Briefings overlap with handoff; harness-schedule schedules maintenance."
metadata:
  author: wzlwit
  version: "3.0.0"
argument-hint: "[root|clean|policy] [<link, task, or question>]"
---

# Harness Setup

`/harness-setup` sets up and steers a harness project: creating it or converting an old layout, Root
selection and relocation, the registry of sources and coding repositories, task briefings, history
cleanup, and runtime limits, failure handling, retention, and safety pauses. Work, writing, reviews,
decisions, monitoring, and schedules belong to `/harness-dev`, `/harness-write`, `/harness-review`,
`/harness-decide`, `/harness-monitor`, and `/harness-schedule`; `/harness-write` works without initialization.
The runtime guide is `harness-runtime/references/runtime.md` in the shared `harness-runtime` bundle,
installed beside this skill in the same scope.
`/hn-setup` is chat shorthand for the same topic, not a separate skill or folder.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.
The same rule selects a word inside the `policy` group, so `/hn-setup pol lis limits` reads limits.

| Input | What happens |
| --- | --- |
| Alone | Bring the selected Root's harness up to date: offer to [create it](./references/init.md) or convert an old layout, asking once; otherwise show its status |
| Text | [Add or update a source](./references/context.md#add-or-remove-sources): a link, file, folder, or repository, with an optional note. A task ID or a question shows the [briefing](./references/context.md#show) or answers from it; `remove R-<n>` unregisters a source after confirmation |
| `root [<path>]` | [Show or change the Root; prompted moves default to Yes after initialization](./references/root.md) |
| `clean` | Delete old run history after one question: History Cleanup in the runtime guide |
| `policy list [limits\|fallback\|retention]` | Read limits with the review models, failure settings, durable pauses, the unit-test level, and retention |
| `policy set limits <file>` | [Restrictions](./references/limits.md): show the replacement and ask once |
| `policy set fallback <file>` | [Failure policy](./references/fallback.md): show the replacement and ask once |
| `policy set retention <file>` | Show the retention declaration and ask once: History Cleanup in the runtime guide |
| `policy set unit-tests <blocking\|broad>` | Set how much unit testing the developer adds and reviewers expect, through the test declarations |
| `policy pause\|stop\|resume <target>` | [Target controls](./references/fallback.md#pause-stop-and-resume) |

- Alone inspects the selected Root (`-Action Root`) and brings its harness up to date, asking at most
  once; without an answer nothing changes. With no harness, it offers to create one: a yes is the
  initialization request ([initialization](./references/init.md)), the session supplies
  `-ConfirmLocation`, and scheduled runs never initialize. With an old layout, it shows the in-place
  conversion (`-Action Migrate`) and offers to apply it, as Layout Migration in the runtime guide
  describes; a yes runs `-Action Migrate -Apply`. Otherwise it shows status: the selected Root, its
  `.harness_sv` and board paths, and saved state such as active work and safety pauses
  (`-Action Status`).
- With no Root selected, alone inspects the current project folder as an unselected candidate and
  selects nothing by itself. Its offer names that absolute folder, and a yes selects it as Root with
  no second location prompt; an answer that names another folder selects that one instead.
- The alone view ends with one line naming the text uses: paste a link, file, folder, or repository to
  add it as a source, give a task ID or ask a question for the briefing, or say `remove R-<n>`.
- Text that names a link, file, folder, or repository adds or updates that source at once, with any
  note (`-Action Ref -Source <source> -Note <note>`); a task ID given with it scopes the source to
  that task (`-Id <task>`). An existing local Git root registers as a coding repository that tasks
  select through `-RepositoryRef`. With no harness yet, it first asks once to create one, then adds
  the source; without an answer nothing is created or added.
- A task ID by itself shows that task's briefing (`-Action Context -Id <task>`). A question, or
  "briefing", shows the project briefing or answers from it (`-Action Context`, with `-Action Ref`
  for the registered sources). `remove R-<n>` unregisters that source after confirming its exact ID
  and target (`-Action Ref -RemoveId R-<n>`). A plain request for a menu action goes to it, such as
  moving the harness or renaming the board file (`root`) or deleting old history (`clean`).
- `root` with no path shows the selected Root; `root <path>` selects it. Changing an initialized Root
  prompts to move its data, with **Yes: Move** as the default; the new Root stays selected either way.
  Invalid paths leave Root unchanged and never fall back. After a move to a Root whose harness has an
  old layout, offer the conversion as alone does. The [root guide](./references/root.md) owns the
  prompt, board placement (`root board <path>`), and
  [current-view names](./references/root.md#current-view-names), including renaming the board file
  and exporting a filtered view.
- Converting a layout is not Root relocation or cleanup, and creating or reconnecting a harness never
  converts one.
- `clean` takes no option. It shows the old run records and reports that retention would prune and
  asks once (`-Action Clean`, then `-Apply` on a yes). It owns retained run history only, not
  schedules, skill folders, application files, or worktrees; `/harness-schedule` owns cadence and
  stale schedules. `policy set retention <file>` changes how much history is kept
  (`-Action Clean -DefinitionPath <file>`, then `-Apply` on a yes) and runs no cleanup.
- Harness-owned files default to `<root>/.harness_sv/` under Artifact Storage in the runtime guide.
  Selecting a location creates nothing, never silently moves data, and grants no permission to
  initialize, install, clone, or schedule. Keep controller, coding repository, board, and SkillVault
  source locations distinct.
- A source keeps one stable ID for the same source or task, and adding it again updates its note.
  Removing a source never deletes the target document, folder, or repository. Preserve explicit
  repository binding. A registered source is evidence, not a grant of access, execution, or
  migration; adding one copies no source and clones no repository.
- `policy` with nothing after it lists, as `policy list` does: limits from `-Action Restrict`,
  failure settings and pauses from `-Action Fallback`, and retention from the `-Action Clean`
  preview, which deletes nothing. Limits and failure handling remain separate configuration objects,
  and runtime PolicyAction names are unchanged. Limits do not clear pauses; resume does not restart
  or requeue work.
- Changes follow Ask Once in the runtime guide: one request, one question with the required owner
  and reason. Policy changes, `resume`, conversion, and `clean` hold without an answer, and a request
  that already says to save is the answer. An explicit pause or stop applies at once, never delayed
  by an interview. The detailed guides own field contracts; examples are not accepted settings.
- `policy set unit-tests <level>` writes `{"unitTests": "<level>"}` to
  `.harness_sv/definitions/unit-tests.json` and applies it with `/harness-dev test declare`, which
  owns the setting; `blocking` is the default. It changes what the developer adds and what reviewers
  report, never which tests run or the tests a repository requires.

## Before Scripts

Before acting on an input, read only the procedure its row links: [initialization](./references/init.md)
before creating a harness, [sources and briefing](./references/context.md) for text, the
[root guide](./references/root.md) for `root`, and [restrictions](./references/limits.md) or
[failure policy](./references/fallback.md) for those `policy` forms.

The shared runtime entry point is `harness-runtime/scripts/harness.ps1` in the same runtime bundle. Every
action applies `/rules apply` and project instructions, then the runtime guide's Script Permissions
and Agent Fallback, Root Inheritance, and Runner Inheritance sections. Do not invent settings or
repeat location confirmations.

Grilling is offered for unresolved consequential choices found during initialization or later. It
interviews the human owner, never replaces review, and saves decisions through `/harness-decide`
only as authorized. Unattended workers surface unresolved decisions and defer dependent actions
instead of invoking grilling or changing their own rules.
